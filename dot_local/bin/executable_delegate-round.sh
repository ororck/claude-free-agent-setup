#!/usr/bin/env bash
# delegate-round.sh : lance un round de workers en parallele, un pane herdr d'affichage par worker.
# Le controle passe UNIQUEMENT par les processus et leurs codes de sortie. Les panes n'affichent rien d'autre
# que le journal du worker : si herdr echoue, le round se termine quand meme.
# Usage (racine du depot) : delegate-round.sh <plan.txt>
#   plan.txt, une tache par ligne : <worker> <consigne.md> <livrable> [livrable...]
set -uo pipefail

OUT=.worker-out
MAX_PAR=${MAX_PAR:-3}
plan="${1:-}"
[ -f "$plan" ] || { echo "Usage : delegate-round.sh <plan.txt>"; exit 1; }
command -v delegate.sh >/dev/null || { echo "ECHEC : delegate.sh introuvable"; exit 1; }
mkdir -p "$OUT"

# herdr est optionnel : toute erreur est ignoree, elle ne doit jamais casser un round
hdr() { [ -n "${HERDR_ENV:-}" ] && command -v herdr >/dev/null && herdr "$@" >/dev/null 2>&1; return 0; }
hdr_ids() {     # identifiants de tous les panes, un par ligne
  herdr pane list 2>/dev/null | python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit()
for p in d.get("result",{}).get("panes",[]): print(p.get("pane_id",""))' 2>/dev/null
}
hdr_split() {   # cree un pane et rend son identifiant, par difference de listes
  [ -n "${HERDR_ENV:-}" ] && command -v herdr >/dev/null || return 0
  local avant apres
  avant=$(hdr_ids)
  herdr pane split --current --direction "$1" --cwd "$PWD" --no-focus >/dev/null 2>&1 || return 0
  apres=$(hdr_ids)
  comm -13 <(printf '%s\n' "$avant" | sort) <(printf '%s\n' "$apres" | sort) | head -1
}

taches=(); i=0
declare -A vu=()
while read -r worker consigne livrables; do
  [ -z "${worker:-}" ] && continue
  case "$worker" in \#*) continue ;; esac
  tache="$(basename "$consigne" .md)"; tache="${tache%.prompt}"
  if [ -n "${vu[$tache]:-}" ]; then
    echo "ECHEC : nom de tache en doublon dans le plan : $tache"; exit 1
  fi
  vu[$tache]=1
  log="$OUT/$tache.run.log"; : > "$log"
  dir=$([ $((i % 2)) -eq 0 ] && echo right || echo down)
  while [ "$(jobs -rp | wc -l)" -ge "$MAX_PAR" ]; do wait -n; done
  # shellcheck disable=SC2086  # les livrables sont volontairement decoupes en arguments
  ( delegate.sh "$worker" "$consigne" $livrables > "$OUT/$tache.resume" 2>&1; echo $? > "$OUT/$tache.exit" ) &
  pid=$!
  pane=$(hdr_split "$dir")
  if [ -n "$pane" ]; then
    hdr pane report-metadata "$pane" --source delegate --title "$tache" --display-agent "$worker"
    hdr pane report-agent "$pane" --source delegate --agent "$worker" --state working --message "$tache"
    # --pid : le tail s'arrete de lui-meme quand le worker se termine
    hdr pane run "$pane" "tail -n +1 --pid $pid -F $log"
  fi
  taches+=("$tache|$worker|$pane|$pid")
  i=$((i + 1))
done < "$plan"

wait
code_round=0
for t in "${taches[@]}"; do
  IFS='|' read -r tache worker pane _ <<< "$t"
  code=$(cat "$OUT/$tache.exit" 2>/dev/null || echo 1)
  resume=$(cat "$OUT/$tache.resume" 2>/dev/null | tail -1)
  [ "$code" -ne 0 ] && code_round=1
  if [ -n "$pane" ]; then
    hdr pane report-agent "$pane" --source delegate --agent "$worker" --state idle --message "${resume:-fin}"
    sleep 2
    hdr pane close "$pane"
  fi
  printf '%s\n' "${resume:-$tache : pas de resume (code $code)}"
done
hdr notification --title "Round termine" --message "$(printf '%s taches, code %s' "${#taches[@]}" "$code_round")"
exit "$code_round"
