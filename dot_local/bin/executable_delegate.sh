#!/usr/bin/env bash
# delegate.sh v6 : worker isole dans un git worktree, lint, relances, recopie des seuls livrables
# Usage (racine du depot) : delegate.sh <worker|provider/modele> <consigne.md> <livrable> [livrable...]
set -uo pipefail

MAX_ESSAIS=${MAX_ESSAIS:-3}
DELAI=${DELAI:-900}
# COPIER=0 : valide et lint sans recopier ; en cas de reussite le worktree est conserve et son chemin est la derniere ligne affichee.
COPIER=${COPIER:-1}
# SUFFIXE (ex. .worker-a) : insere avant l'extension dans les fichiers ecrits dans $OUT, pour que des workers paralleles ne s'ecrasent pas.
SUFFIXE=${SUFFIXE:-}
OUT=.worker-out
LOG="$OUT/delegate$SUFFIXE.log"
SENSIBLE='^(secrets|infra)/|(^|/)\.env$|(^|/)\.env\.|\.tfstate|\.tfvars|\.pem$|\.key$|\.p12$|\.pfx$|(^|/)id_rsa|(^|/)id_ed25519|(^|/)kubeconfig$|(^|/)\.kube/'
SENSIBLE_OK='(^|/)(\.env\.example|\.envrc)$'

[ $# -ge 3 ] || { echo "Usage : delegate.sh <worker> <consigne.md> <livrable>..."; exit 1; }
worker="$1"; consigne="$2"; shift 2
case "$worker" in */*) modele="$worker" ;; *) modele="litellm/$worker" ;; esac
tache="$(basename "$consigne" .md)"; tache="${tache%.prompt}"
RUN_LOG="$OUT/$tache.run$SUFFIXE.log"; ERR_FILE="$OUT/$tache.erreurs$SUFFIXE.txt"; DIFF_FILE="$OUT/$tache$SUFFIXE.diff"
mkdir -p "$OUT"
journal() { printf '%s %s %s %s\n' "$(date +%T)" "$worker" "$tache" "$1" >> "$LOG"; }

livrables=()
for f in "$@"; do livrables+=("$(realpath -m --relative-to=. "$f")"); done
for f in "${livrables[@]}"; do
  case "$f" in ../*) echo "REFUS $tache : chemin hors depot $f"; exit 1 ;; esac
  if ! printf '%s' "$f" | grep -Eq "$SENSIBLE_OK" && printf '%s' "$f" | grep -Eq "$SENSIBLE"; then echo "REFUS $tache : chemin interdit $f"; exit 1; fi
done
[ -f "$consigne" ] || { echo "ECHEC $tache : consigne introuvable"; exit 1; }
for outil in git opencode realpath timeout yamllint hadolint actionlint shellcheck kubeconform kube-linter kubectl ruff; do
  command -v "$outil" >/dev/null || { echo "ECHEC $tache : outil manquant $outil"; exit 1; }
done
git rev-parse --verify -q HEAD >/dev/null || { echo "ECHEC $tache : depot sans commit, faire un commit initial"; exit 1; }

# Etat courant a copier dans le worktree : fichiers suivis + non suivis NON ignores.
# Un fichier sensible dans cette liste = il n'est pas dans .gitignore : on refuse.
liste=$(git ls-files -co --exclude-standard)
if sens=$(printf '%s\n' "$liste" | grep -Ev "$SENSIBLE_OK" | grep -E "$SENSIBLE"); then
  echo "REFUS $tache : fichiers sensibles non ignores par git : $(echo "$sens" | tr '\n' ' ')"; exit 1
fi

racine=$(pwd)
WT="${TMPDIR:-/tmp}/delegate-wt/$(basename "$racine")-$tache-$$"
# shellcheck disable=SC2329  # appelee par trap
nettoyer() { [ "${garder:-0}" = 1 ] && return 0; git -C "$racine" worktree remove --force "$WT" >/dev/null 2>&1; git -C "$racine" worktree prune >/dev/null 2>&1; }
trap nettoyer EXIT
mkdir -p "$(dirname "$WT")"
git worktree add -q --detach "$WT" HEAD 2>/dev/null || { echo "ECHEC $tache : creation du worktree impossible"; exit 1; }
printf '%s\n' "$liste" | grep -v '^$' | while IFS= read -r f; do [ -e "$f" ] && cp --parents -p "$f" "$WT/"; done
mkdir -p "$WT/$OUT" && cp "$consigne" "$WT/$OUT/$tache.consigne.md"
git -C "$WT" add -A >/dev/null && git -C "$WT" -c user.name=delegate -c user.email=delegate@local commit -qm base --allow-empty
base_sha=$(git -C "$WT" rev-parse HEAD)

KC_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/kubeconform"; mkdir -p "$KC_CACHE"
KL_CHECKS="run-as-non-root,unset-cpu-requirements,unset-memory-requirements,latest-tag"
# Erreurs reelles uniquement, pas de style : pyflakes, imports, bugbear, pieges courants.
RUFF_REGLES="F,E9,B,PLE"
lint() {
  # Cumule les erreurs de toutes les couches au lieu de s'arreter a la premiere.
  # Exception : si la couche de parsing echoue (yamllint, hadolint), les couches
  # suivantes ne peuvent rien produire d'utile, on court-circuite.
  local f="$1" err="" sortie=""
  ajoute() { sortie="$1"; shift; if ! out=$("$@" 2>&1); then err+="$sortie :"$'\n'"$out"$'\n'; return 1; fi; return 0; }
  case "$f" in
    *Dockerfile)
      ajoute "hadolint" hadolint "$f" || { printf '%s' "$err"; return 1; }
      grep -Eq '^USER [0-9]+(:[0-9]+)?$' "$f" || err+="USER doit etre un UID numerique"$'\n'
      if grep -Ei '^FROM ' "$f" | grep -Evqi '(@sha256:[0-9a-f]{64}|:[^ ]*[0-9]+\.[0-9]+[^ ]*)( |$)'; then
        err+="FROM : image non epinglee (version x.y ou digest attendu)"$'\n'
      fi ;;
    .github/workflows/*)
      ajoute "yamllint" yamllint "$f" || { printf '%s' "$err"; return 1; }
      ajoute "actionlint" actionlint "$f"
      if grep -nE '^[[:space:]]*push:[[:space:]]*(true|\$\{\{)|docker (image )?push|podman push|crane push|skopeo copy' "$f" >/dev/null; then
        err+="push d'image interdit"$'\n'
      fi ;;
    *kustomization.yaml)
      ajoute "yamllint" yamllint "$f" || { printf '%s' "$err"; return 1; }
      if ! out=$(kubectl kustomize "$(dirname "$f")" 2>&1 | kubeconform -strict -summary -cache "$KC_CACHE" - 2>&1); then
        err+="kubeconform :"$'\n'"$out"$'\n'
      fi ;;
    services/*/k8s/*.yaml|k8s/*.yaml)
      ajoute "yamllint" yamllint "$f" || { printf '%s' "$err"; return 1; }
      ajoute "kubeconform" kubeconform -strict -summary -cache "$KC_CACHE" "$f"
      ajoute "kube-linter" kube-linter lint --do-not-auto-add-defaults --include "$KL_CHECKS" "$f" ;;
    *.yml|*.yaml)
      ajoute "yamllint" yamllint "$f" ;;
    *.sh)
      ajoute "shellcheck" shellcheck "$f" ;;
    *.py)
      ajoute "ruff" ruff check --no-cache --select "$RUFF_REGLES" "$f" ;;
    *) return 0 ;;
  esac
  [ -z "$err" ] && return 0
  printf '%s' "$err"; return 1
}

msg="Execute la consigne jointe. Ecris uniquement les fichiers demandes."
fichiers=(--file "$WT/$OUT/$tache.consigne.md")

# Retour arriere : on garde le meilleur essai (moins de livrables en echec, puis moins de lignes d'erreurs).
# Un essai strictement pire est annule avant le suivant, et la sortie recopie toujours depuis le meilleur.
best_sha=""; best_score=""; best_erreurs=""
sur_meilleur() { [ "$(git -C "$WT" rev-parse HEAD)" = "$best_sha" ] || git -C "$WT" checkout -q --detach "$best_sha"; }
recopier_meilleur() {
  sur_meilleur
  [ "$COPIER" = 0 ] && return 0
  for f in "${livrables[@]}"; do
    [ -s "$WT/$f" ] || continue
    mkdir -p "$(dirname "$f")"; cp -p "$WT/$f" "$f"
  done
  git diff --no-color -- "${livrables[@]}" > "$DIFF_FILE" 2>/dev/null
}

for essai in $(seq 1 "$MAX_ESSAIS"); do
  ( cd "$WT" && timeout -k 30 "$DELAI" opencode run -m "$modele" "$msg" "${fichiers[@]}" ) >> "$RUN_LOG" 2>&1
  code=$?
  if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
    journal "TIMEOUT essai $essai"; echo "ECHEC $tache : delai depasse (essai $essai)"; exit 12
  fi
  erreurs=""; nb_ko=0
  for f in "${livrables[@]}"; do
    if [ ! -s "$WT/$f" ]; then erreurs+="$f : fichier absent ou vide"$'\n'; nb_ko=$((nb_ko+1)); continue; fi
    [ -n "$(tail -c1 "$WT/$f")" ] && echo >> "$WT/$f"
    sortie="$(cd "$WT" && lint "$f" 2>&1)" || { erreurs+="$f :"$'\n'"$sortie"$'\n'; nb_ko=$((nb_ko+1)); }
  done
  erreurs=$(printf '%s' "$erreurs" | head -40)
  score=$((nb_ko * 1000 + $(printf '%s' "$erreurs" | grep -c '')))
  git -C "$WT" add -A >/dev/null && git -C "$WT" -c user.name=delegate -c user.email=delegate@local commit -qm "essai $essai" --allow-empty
  if [ -z "$best_sha" ] || [ "$score" -le "$best_score" ]; then
    best_sha=$(git -C "$WT" rev-parse HEAD); best_score=$score; best_erreurs=$erreurs
  else
    journal "ANNULE essai $essai (score $score, meilleur $best_score)"
    sur_meilleur
  fi
  if [ -z "$erreurs" ]; then
    recopier_meilleur
    jetes=$(git -C "$WT" diff --name-only "$base_sha" HEAD | grep -v "^$OUT/" | grep -vxF -f <(printf '%s\n' "${livrables[@]}") | tr '\n' ' ')
    journal "OK essai $essai${jetes:+ (jetes: $jetes)}"
    echo "OK $tache ($essai essai(s))${jetes:+ | hors livrables jetes : $jetes}"
    [ "$COPIER" = 0 ] && { garder=1; echo "$WT"; }
    exit 0
  fi
  printf '%s\n' "$best_erreurs" > "$ERR_FILE"; cp "$ERR_FILE" "$WT/$OUT/$tache.erreurs.txt"
  journal "ERREURS essai $essai"
  msg="Corrige uniquement les erreurs du fichier joint $tache.erreurs.txt. Ne change aucune valeur fonctionnelle (port, replicas, image, version) pour satisfaire un linter. Si une correction exige une valeur absente de la consigne, laisse l'erreur."
  fichiers=(--file "$WT/$OUT/$tache.consigne.md" --file "$WT/$OUT/$tache.erreurs.txt")
  for f in "${livrables[@]}"; do [ -s "$WT/$f" ] && fichiers+=(--file "$WT/$f"); done
done
recopier_meilleur
journal "ECHEC apres $MAX_ESSAIS essais"
echo "ECHEC $tache apres $MAX_ESSAIS essais : voir $ERR_FILE"
exit 2
