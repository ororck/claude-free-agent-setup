#!/usr/bin/env bash
# Lance toute la suite de tests du setup avec bats-core (sous-module bats/). Code 0 si tous les cas passent.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
BATS=./bats/bin/bats
[ -x "$BATS" ] || { echo "bats absent : git submodule update --init"; exit 1; }

sortie=$("$BATS" --tap ./*.bats 2>&1); code=$?
printf '%s\n' "$sortie" | grep -Ev '^ok ' # le detail des cas reussis est masque, les echecs et diagnostics restent
total=$(printf '%s\n' "$sortie" | grep -cE '^(not )?ok ')
echec=$(printf '%s\n' "$sortie" | grep -c '^not ok ')
echo "=== $total cas, $echec en echec"
[ "$code" -eq 0 ] && [ "$echec" -eq 0 ] && [ "$total" -ge 36 ]
