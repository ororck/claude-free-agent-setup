#!/usr/bin/env bash
# Lance toute la suite de tests du setup.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
ko=0
for t in test-guard-secrets.sh test-shellcheck.sh; do
  echo "=== $t"
  ./"$t" || ko=$((ko+1))
done
echo "=== suites en echec : $ko"
[ "$ko" -eq 0 ]
