#!/usr/bin/env bash
# delegate-boN.sh : best-of-N. Meme tache sur plusieurs workers en parallele, on garde le premier qui passe le lint.
# Si aucun ne passe, une seule passe de raffinement sur celui qui a le moins de lignes d'erreurs.
# MIN_LIGNES (vide par defaut) : critere de conformite optionnel. Pose, un candidat en code 0 dont un livrable compte moins de
# MIN_LIGNES lignes n'est pas gagnant et on attend les autres ; si aucun n'atteint le seuil, le plus long gagne (code 0, journal SOUS LE SEUIL).
# DELAI_BON (300 s) : borne l'attente uniquement quand MIN_LIGNES est pose, sinon le premier valide gagne aussitot.
# Usage (racine du depot) : delegate-boN.sh "<worker1,worker2,worker3>" <consigne.md> <livrable> [livrable...]
set -uo pipefail
set -m   # un groupe de processus par worker, pour pouvoir tuer worker + opencode d'un coup

OUT=.worker-out
MAX_PAR=${MAX_PAR:-3}
GRACE=${GRACE:-5}   # secondes entre le SIGTERM et le SIGKILL aux workers restants
LOG="$OUT/delegate.log"
MIN_LIGNES=${MIN_LIGNES:-}
DELAI_BON=${DELAI_BON:-300}
case "$MIN_LIGNES" in ''|*[!0-9]*) [ -z "$MIN_LIGNES" ] || { echo "ECHEC : MIN_LIGNES doit etre un entier"; exit 1; } ;; esac
limite_bon=$((SECONDS + DELAI_BON))

[ $# -ge 3 ] || { echo 'Usage : delegate-boN.sh "<worker1,worker2,...>" <consigne.md> <livrable>...'; exit 1; }
liste="$1"; consigne="$2"; shift 2
[ -f "$consigne" ] || { echo "ECHEC : consigne introuvable"; exit 1; }
command -v delegate.sh >/dev/null || { echo "ECHEC : delegate.sh introuvable"; exit 1; }
tache="$(basename "$consigne" .md)"; tache="${tache%.prompt}"
mkdir -p "$OUT"
journal() { printf '%s %s %s %s\n' "$(date +%T)" boN "$tache" "$1" >> "$LOG"; }

livrables=()
for f in "$@"; do
  r="$(realpath -m --relative-to=. "$f")"
  case "$r" in ../*) echo "REFUS $tache : chemin hors depot $f"; exit 1 ;; esac
  livrables+=("$r")
done

IFS=',' read -ra workers <<< "$liste"
[ "${#workers[@]}" -ge 1 ] && [ -n "${workers[0]}" ] || { echo "ECHEC : aucun worker"; exit 1; }
tag() { local t="${1//\//_}"; printf '%s' "$t"; }              # nom de worker utilisable dans un nom de fichier
exitf() { printf '%s/%s.bo.%s.exit' "$OUT" "$tache" "$(tag "$1")"; }
resumef() { printf '%s/%s.bo.%s.resume' "$OUT" "$tache" "$(tag "$1")"; }
errf() { printf '%s/%s.erreurs.%s.txt' "$OUT" "$tache" "$(tag "$1")"; }
rm -f "$OUT/$tache".bo.*.exit "$OUT/$tache".bo.*.resume

WTROOT="${TMPDIR:-/tmp}/delegate-wt"
declare -A pid=()
gagnant=""

# Supprime les worktrees de cette tache, quel que soit le worker.
nettoyer_wt() {
  local p
  while IFS= read -r p; do
    case "$p" in "$WTROOT/$(basename "$PWD")-$tache-"*) git worktree remove --force "$p" >/dev/null 2>&1 ;; esac
  done < <(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
  rm -rf "$WTROOT/$(basename "$PWD")-$tache-"*
  git worktree prune >/dev/null 2>&1
}
# Le sous-shell d'un worker peut mourir avant son opencode : le groupe de
# processus vit encore avec des orphelins, que jobs/wait ne voient pas.
groupe_vivant() {
  local w
  for w in "${workers[@]}"; do
    [ -n "${pid[$w]:-}" ] && kill -0 -- "-${pid[$w]}" 2>/dev/null && return 0
  done
  return 1
}
tuer_restants() {
  local w limite
  for w in "${workers[@]}"; do
    [ -n "${pid[$w]:-}" ] && kill -TERM -- "-${pid[$w]}" 2>/dev/null
  done
  limite=$((SECONDS + GRACE))
  while [ "$SECONDS" -lt "$limite" ] && groupe_vivant; do sleep 0.2; done
  for w in "${workers[@]}"; do
    [ -n "${pid[$w]:-}" ] && kill -0 -- "-${pid[$w]}" 2>/dev/null && kill -KILL -- "-${pid[$w]}" 2>/dev/null
  done
  wait 2>/dev/null
}
# shellcheck disable=SC2329  # appelee par trap
sortie() { tuer_restants; nettoyer_wt; }
trap sortie EXIT

# Lignes d'un candidat (code 0) : "<min sur les livrables> <total>". Worktree ou livrable absent = 0.
lignes_de() {
  local wt f n min="" tot=0
  wt=$(tail -1 "$(resumef "$1")" 2>/dev/null)
  for f in "${livrables[@]}"; do
    n=0; [ -f "$wt/$f" ] && n=$(wc -l < "$wt/$f")
    tot=$((tot + n)); if [ -z "$min" ] || [ "$n" -lt "$min" ]; then min=$n; fi
  done
  echo "${min:-0} $tot"
}
cherche_gagnant() {
  local w min tot
  for w in "${workers[@]}"; do
    [ "$(cat "$(exitf "$w")" 2>/dev/null)" = 0 ] || continue
    if [ -n "$MIN_LIGNES" ]; then
      read -r min tot < <(lignes_de "$w")
      [ "$min" -ge "$MIN_LIGNES" ] || continue
    fi
    gagnant="$w"; return 0
  done
  return 1
}
# Attend la fin d'un worker. Avec MIN_LIGNES, on scrute pour pouvoir respecter DELAI_BON (wait -n ne peut pas expirer).
attendre_fin() {
  if [ -z "$MIN_LIGNES" ]; then wait -n 2>/dev/null; return 0; fi
  local avant; avant=$(jobs -rp | wc -l)
  while [ "$(jobs -rp | wc -l)" -ge "$avant" ] && [ "$SECONDS" -lt "$limite_bon" ]; do sleep 0.2; done
}
delai_bon_ecoule() { [ -n "$MIN_LIGNES" ] && [ "$SECONDS" -ge "$limite_bon" ]; }

for w in "${workers[@]}"; do
  [ -z "$w" ] && continue
  while [ "$(jobs -rp | wc -l)" -ge "$MAX_PAR" ]; do attendre_fin; cherche_gagnant && break 2; delai_bon_ecoule && break 2; done
  ( SUFFIXE=".$(tag "$w")" MAX_ESSAIS=1 COPIER=0 delegate.sh "$w" "$consigne" "${livrables[@]}" > "$(resumef "$w")" 2>&1
    echo $? > "$(exitf "$w")" ) &
  pid[$w]=$!
  journal "LANCE $w"
  cherche_gagnant && break
done
while [ -z "$gagnant" ] && [ "$(jobs -rp | wc -l)" -gt 0 ] && ! delai_bon_ecoule; do attendre_fin; cherche_gagnant; done
[ -z "$gagnant" ] && cherche_gagnant

# MIN_LIGNES : personne n'atteint le seuil (tous finis, ou DELAI_BON ecoule). On departage les candidats deja arrives : le plus de lignes.
sous_seuil=0
if [ -z "$gagnant" ] && [ -n "$MIN_LIGNES" ]; then
  tuer_restants
  n_max=-1
  for w in "${workers[@]}"; do
    [ "$(cat "$(exitf "$w")" 2>/dev/null)" = 0 ] || continue
    read -r _ tot < <(lignes_de "$w")
    if [ "$tot" -gt "$n_max" ]; then n_max=$tot; gagnant="$w"; sous_seuil=1; fi
  done
fi

if [ -n "$gagnant" ]; then
  tuer_restants
  wt=$(tail -1 "$(resumef "$gagnant")")
  case "$wt" in "$WTROOT"/*) ;; *) journal "ECHEC gagnant $gagnant : worktree introuvable"; echo "ECHEC $tache : worktree du gagnant $gagnant introuvable"; exit 1 ;; esac
  for f in "${livrables[@]}"; do
    [ -s "$wt/$f" ] || { journal "ECHEC gagnant $gagnant : livrable absent $f"; echo "ECHEC $tache : livrable absent $f dans le worktree de $gagnant"; exit 1; }
  done
  for f in "${livrables[@]}"; do mkdir -p "$(dirname "$f")"; cp -p "$wt/$f" "$f"; done
  git diff --no-color -- "${livrables[@]}" > "$OUT/$tache.diff" 2>/dev/null
  info=""; msg_seuil=""
  if [ -n "$MIN_LIGNES" ]; then
    read -r _ tot < <(lignes_de "$gagnant")
    info=" ($tot lignes)"
    if [ "$sous_seuil" = 1 ]; then
      journal "SOUS LE SEUIL gagnant $gagnant $tot lignes sur $MIN_LIGNES"
      msg_seuil=", SOUS LE SEUIL : $tot lignes sur $MIN_LIGNES"
    fi
  fi
  journal "OK gagnant $gagnant$info"
  echo "OK $tache (best-of-${#workers[@]}, gagnant $gagnant$msg_seuil)"
  exit 0
fi

# Aucun ne passe : le moins mauvais = le moins de lignes dans son fichier d'erreurs.
meilleur=""; meilleur_n=""
for w in "${workers[@]}"; do
  [ -s "$(errf "$w")" ] || continue
  n=$(wc -l < "$(errf "$w")")
  if [ -z "$meilleur" ] || [ "$n" -lt "$meilleur_n" ]; then meilleur="$w"; meilleur_n=$n; fi
done
if [ -z "$meilleur" ]; then
  journal "ECHEC aucun worker n'a produit de fichier d'erreurs"
  echo "ECHEC $tache : aucun worker n'a passe le lint et aucun fichier d'erreurs a raffiner"; exit 1
fi
tuer_restants; nettoyer_wt
journal "RAFFINEMENT sur $meilleur ($meilleur_n lignes d'erreurs)"
# Le nouveau delegate.sh repart du depot : les erreurs sont donc injectees dans la consigne.
mkdir -p "$OUT/raffine"
rconsigne="$OUT/raffine/$(basename "$consigne")"
{
  cat "$consigne"
  printf '\n\n## Erreurs de la tentative precedente\nUne tentative precedente a produit des fichiers qui echouent au lint avec ces erreurs. Ecris les fichiers demandes en les corrigeant. Ne change aucune valeur fonctionnelle (port, replicas, image, version) pour satisfaire un linter.\n\n'
  cat "$(errf "$meilleur")"
} > "$rconsigne"
MAX_ESSAIS=1 COPIER=1 delegate.sh "$meilleur" "$rconsigne" "${livrables[@]}"
code=$?
journal "RAFFINEMENT $meilleur code $code"
exit "$code"
