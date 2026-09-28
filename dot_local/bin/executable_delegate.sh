#!/usr/bin/env bash
# delegate.sh v5 : worker isole dans un git worktree, lint, relances, recopie des seuls livrables
# Usage (racine du depot) : delegate.sh <worker|provider/modele> <consigne.md> <livrable> [livrable...]
set -uo pipefail

MAX_ESSAIS=${MAX_ESSAIS:-3}
DELAI=${DELAI:-900}
OUT=.worker-out
LOG="$OUT/delegate.log"
SENSIBLE='(^|/)(secrets|infra)/|\.env$|\.env\.|(^|/)\.env|\.tfstate|\.tfvars|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa|id_ed25519|kubeconfig|(^|/)\.kube/'

[ $# -ge 3 ] || { echo "Usage : delegate.sh <worker> <consigne.md> <livrable>..."; exit 1; }
worker="$1"; consigne="$2"; shift 2
case "$worker" in */*) modele="$worker" ;; *) modele="litellm/$worker" ;; esac
tache="$(basename "$consigne" .md)"; tache="${tache%.prompt}"
mkdir -p "$OUT"
journal() { printf '%s %s %s %s\n' "$(date +%T)" "$worker" "$tache" "$1" >> "$LOG"; }

livrables=()
for f in "$@"; do livrables+=("$(realpath -m --relative-to=. "$f")"); done
for f in "${livrables[@]}"; do
  case "$f" in ../*) echo "REFUS $tache : chemin hors depot $f"; exit 1 ;; esac
  if printf '%s' "$f" | grep -Eq "$SENSIBLE"; then echo "REFUS $tache : chemin interdit $f"; exit 1; fi
done
[ -f "$consigne" ] || { echo "ECHEC $tache : consigne introuvable"; exit 1; }
for outil in git opencode realpath timeout yamllint hadolint actionlint shellcheck kubeconform kube-linter kubectl; do
  command -v "$outil" >/dev/null || { echo "ECHEC $tache : outil manquant $outil"; exit 1; }
done
git rev-parse --verify -q HEAD >/dev/null || { echo "ECHEC $tache : depot sans commit, faire un commit initial"; exit 1; }

# Etat courant a copier dans le worktree : fichiers suivis + non suivis NON ignores.
# Un fichier sensible dans cette liste = il n'est pas dans .gitignore : on refuse.
liste=$(git ls-files -co --exclude-standard)
if sens=$(printf '%s\n' "$liste" | grep -E "$SENSIBLE"); then
  echo "REFUS $tache : fichiers sensibles non ignores par git : $(echo "$sens" | tr '\n' ' ')"; exit 1
fi

racine=$(pwd)
WT="${TMPDIR:-/tmp}/delegate-wt/$(basename "$racine")-$tache-$$"
# shellcheck disable=SC2329  # appelee par trap
nettoyer() { git -C "$racine" worktree remove --force "$WT" >/dev/null 2>&1; git -C "$racine" worktree prune >/dev/null 2>&1; }
trap nettoyer EXIT
mkdir -p "$(dirname "$WT")"
git worktree add -q --detach "$WT" HEAD 2>/dev/null || { echo "ECHEC $tache : creation du worktree impossible"; exit 1; }
printf '%s\n' "$liste" | grep -v '^$' | while IFS= read -r f; do [ -e "$f" ] && cp --parents -p "$f" "$WT/"; done
mkdir -p "$WT/$OUT" && cp "$consigne" "$WT/$OUT/$tache.consigne.md"
git -C "$WT" add -A >/dev/null && git -C "$WT" -c user.name=delegate -c user.email=delegate@local commit -qm base --allow-empty

KC_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kubeconform"; mkdir -p "$KC_CACHE"
KL_CHECKS="run-as-non-root,unset-cpu-requirements,unset-memory-requirements,latest-tag"
lint() {
  local f="$1"
  case "$f" in
    *Dockerfile)           hadolint "$f" \
                             && { grep -Eq '^USER [0-9]+(:[0-9]+)?$' "$f" || { echo "USER doit etre un UID numerique"; false; }; } \
                             && { ! grep -Ei '^FROM ' "$f" | grep -Evqi '(@sha256:[0-9a-f]{64}|:[^ ]*[0-9]+\.[0-9]+[^ ]*)( |$)' || { echo "FROM : image non epinglee (version x.y ou digest attendu)"; false; }; } ;;
    .github/workflows/*)   yamllint "$f" && actionlint "$f" \
                             && { ! grep -nE '^[[:space:]]*push:[[:space:]]*(true|\$\{\{)|docker (image )?push|podman push|crane push|skopeo copy' "$f" || { echo "push d'image interdit"; false; }; } ;;
    *kustomization.yaml)   yamllint "$f" && kubectl kustomize "$(dirname "$f")" | kubeconform -strict -summary -cache "$KC_CACHE" - ;;
    services/*/k8s/*.yaml) yamllint "$f" && kubeconform -strict -summary -cache "$KC_CACHE" "$f" \
                             && kube-linter lint --do-not-auto-add-defaults --include "$KL_CHECKS" "$f" ;;
    *.yml|*.yaml)          yamllint "$f" ;;
    *.sh)                  shellcheck "$f" ;;
    *)                     return 0 ;;
  esac
}

msg="Execute la consigne jointe. Ecris uniquement les fichiers demandes."
fichiers=(--file "$WT/$OUT/$tache.consigne.md")
for essai in $(seq 1 "$MAX_ESSAIS"); do
  ( cd "$WT" && timeout -k 30 "$DELAI" opencode run -m "$modele" "$msg" "${fichiers[@]}" ) >> "$OUT/$tache.run.log" 2>&1
  code=$?
  if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
    journal "TIMEOUT essai $essai"; echo "ECHEC $tache : delai depasse (essai $essai)"; exit 12
  fi
  erreurs=""
  for f in "${livrables[@]}"; do
    if [ ! -s "$WT/$f" ]; then erreurs+="$f : fichier absent ou vide"$'\n'; continue; fi
    [ -n "$(tail -c1 "$WT/$f")" ] && echo >> "$WT/$f"
    sortie="$(cd "$WT" && lint "$f" 2>&1)" || erreurs+="$f :"$'\n'"$sortie"$'\n'
  done
  if [ -z "$erreurs" ]; then
    for f in "${livrables[@]}"; do mkdir -p "$(dirname "$f")"; cp -p "$WT/$f" "$f"; done
    jetes=$(git -C "$WT" status --porcelain --untracked-files=all | awk '{print $NF}' | grep -v "^$OUT/" | grep -vxF -f <(printf '%s\n' "${livrables[@]}") | tr '\n' ' ')
    journal "OK essai $essai${jetes:+ (jetes: $jetes)}"
    echo "OK $tache ($essai essai(s))${jetes:+ | hors livrables jetes : $jetes}"; exit 0
  fi
  printf '%s' "$erreurs" | head -40 > "$OUT/$tache.erreurs.txt"; cp "$OUT/$tache.erreurs.txt" "$WT/$OUT/"
  journal "ERREURS essai $essai"
  msg="Corrige uniquement les erreurs du fichier joint $tache.erreurs.txt. Ne change aucune valeur fonctionnelle (port, replicas, image, version) pour satisfaire un linter. Si une correction exige une valeur absente de la consigne, laisse l'erreur."
  fichiers=(--file "$WT/$OUT/$tache.consigne.md" --file "$WT/$OUT/$tache.erreurs.txt")
  for f in "${livrables[@]}"; do [ -s "$WT/$f" ] && fichiers+=(--file "$WT/$f"); done
done
journal "ECHEC apres $MAX_ESSAIS essais"
echo "ECHEC $tache apres $MAX_ESSAIS essais : voir $OUT/$tache.erreurs.txt"
exit 2
