#!/usr/bin/env bats
# Analyse statique de tous les scripts du setup.

verifie() { # <fichier> [option shellcheck...]
  [ -f "$1" ]
  run shellcheck "${@:2}" "$1"
  [ "$status" -eq 0 ] || echo "$output"
  [ "$status" -eq 0 ]
}

@test "shellcheck : delegate.sh" { verifie "$HOME/.local/bin/delegate.sh"; }
@test "shellcheck : delegate-round.sh" { verifie "$HOME/.local/bin/delegate-round.sh"; }
@test "shellcheck : delegate-boN.sh" { verifie "$HOME/.local/bin/delegate-boN.sh"; }
@test "shellcheck : guard-secrets.sh" { verifie "$HOME/.claude/hooks/guard-secrets.sh"; }
@test "shellcheck : guard-secrets-files.sh" { verifie "$HOME/.claude/hooks/guard-secrets-files.sh"; }
@test "shellcheck : run-all.sh" { verifie "$HOME/lab/setup-tests/run-all.sh"; }
@test "shellcheck : helpers.bash" { verifie "$HOME/lab/setup-tests/helpers.bash" --shell=bash; }
@test "shellcheck : guard-secrets.bats" { verifie "$HOME/lab/setup-tests/guard-secrets.bats" --shell=bats; }
@test "shellcheck : guard-secrets-files.bats" { verifie "$HOME/lab/setup-tests/guard-secrets-files.bats" --shell=bats; }
@test "shellcheck : delegate-retour.bats" { verifie "$HOME/lab/setup-tests/delegate-retour.bats" --shell=bats; }
@test "shellcheck : delegate-boN.bats" { verifie "$HOME/lab/setup-tests/delegate-boN.bats" --shell=bats; }
@test "shellcheck : shellcheck.bats" { verifie "$HOME/lab/setup-tests/shellcheck.bats" --shell=bats; }
