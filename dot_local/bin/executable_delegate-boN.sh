#!/usr/bin/env bash
# delegate-boN.sh : best-of-N. Meme tache sur plusieurs workers en parallele, on garde le premier qui passe le lint.
# Si aucun ne passe, une seule passe de raffinement sur celui qui a le moins de lignes d'erreurs.
# Usage (racine du depot) : delegate-boN.sh "<worker1,worker2,worker3>" <consigne.md> <livrable> [livrable...]
set -uo pipefail
set -m   # un groupe de processus par worker, pour pouvoir tuer worker + opencode d'un coup

OUT=.worker-out
MAX_PAR=${MAX_PAR:-3}
LOG="$OUT/delegate.log"

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
tuer_restants() {
  local w
  for w in "${workers[@]}"; do
    [ -n "${pid[$w]:-}" ] && kill -TERM -- "-${pid[$w]}" 2>/dev/null
  done
  wait 2>/dev/null
}
# shellcheck disable=SC2329  # appelee par trap
sortie() { tuer_restants; nettoyer_wt; }
trap sortie EXIT

cherche_gagnant() {
  local w
  for w in "${workers[@]}"; do
    [ "$(cat "$(exitf "$w")" 2>/dev/null)" = 0 ] && { gagnant="$w"; return 0; }
  done
  return 1
}

for w in "${workers[@]}"; do
  [ -z "$w" ] && continue
  while [ "$(jobs -rp | wc -l)" -ge "$MAX_PAR" ]; do wait -n 2>/dev/null; cherche_gagnant && break 2; done
  ( SUFFIXE=".$(tag "$w")" MAX_ESSAIS=1 COPIER=0 delegate.sh "$w" "$consigne" "${livrables[@]}" > "$(resumef "$w")" 2>&1
    echo $? > "$(exitf "$w")" ) &
  pid[$w]=$!
  journal "LANCE $w"
  cherche_gagnant && break
done
while [ -z "$gagnant" ] && [ "$(jobs -rp | wc -l)" -gt 0 ]; do wait -n 2>/dev/null; cherche_gagnant; done
[ -z "$gagnant" ] && cherche_gagnant

if [ -n "$gagnant" ]; then
  tuer_restants
  wt=$(tail -1 "$(resumef "$gagnant")")
  case "$wt" in "$WTROOT"/*) ;; *) journal "ECHEC gagnant $gagnant : worktree introuvable"; echo "ECHEC $tache : worktree du gagnant $gagnant introuvable"; exit 1 ;; esac
  for f in "${livrables[@]}"; do
    [ -s "$wt/$f" ] || { journal "ECHEC gagnant $gagnant : livrable absent $f"; echo "ECHEC $tache : livrable absent $f dans le worktree de $gagnant"; exit 1; }
  done
  for f in "${livrables[@]}"; do mkdir -p "$(dirname "$f")"; cp -p "$wt/$f" "$f"; done
  git diff --no-color -- "${livrables[@]}" > "$OUT/$tache.diff" 2>/dev/null
  journal "OK gagnant $gagnant"
  echo "OK $tache (best-of-${#workers[@]}, gagnant $gagnant)"
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
