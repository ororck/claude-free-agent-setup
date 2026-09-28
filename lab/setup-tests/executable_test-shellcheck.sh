#!/usr/bin/env bash
# Shellcheck sur tous les scripts du setup. Code 0 si tous passent.
set -uo pipefail
cibles=(
  "$HOME/.local/bin/delegate.sh"
  "$HOME/.local/bin/delegate-round.sh"
  "$HOME/.claude/hooks/guard-secrets.sh"
  "$HOME/.claude/hooks/guard-secrets-files.sh"
  "$HOME/lab/setup-tests/test-guard-secrets.sh"
)
ko=0
for f in "${cibles[@]}"; do
  if [ ! -f "$f" ]; then echo "ABSENT $f"; ko=$((ko+1)); continue; fi
  if shellcheck "$f"; then echo "ok $f"; else ko=$((ko+1)); fi
done
echo "scripts en echec : $ko"
[ "$ko" -eq 0 ]
