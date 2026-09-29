#!/usr/bin/env bats
# Hook guard-secrets.sh (commandes Bash). Chaque cas envoie un faux evenement PreToolUse sur l'entree standard.
# Code attendu : 2 = refus, 0 = passage.

HB="$HOME/.claude/hooks/guard-secrets.sh"

verifie() { # <attendu> <commande>
  local payload
  payload=$(python3 -c 'import json,sys;print(json.dumps({"tool_input":{"command":sys.argv[1]}},separators=(",",":")))' "$2")
  run "$HB" <<< "$payload"
  [ "$status" -eq "$1" ]
}

@test "refuse : cat secrets/db.txt" {
  verifie 2 'cat secrets/db.txt'
}

@test "refuse : cat .env" {
  verifie 2 'cat .env'
}

@test "refuse : cat app/.env" {
  verifie 2 'cat app/.env'
}

@test "refuse : cat terraform.tfstate" {
  verifie 2 'cat terraform.tfstate'
}

@test "refuse : cat ~/.litellm/.env" {
  verifie 2 'cat ~/.litellm/.env'
}

@test "refuse : cat ~/.ssh/id_rsa" {
  verifie 2 'cat ~/.ssh/id_rsa'
}

@test "refuse : cat id_ed25519" {
  verifie 2 'cat id_ed25519'
}

@test "refuse : cat kubeconfig" {
  verifie 2 'cat kubeconfig'
}

@test "refuse : grep -r token ." {
  verifie 2 'grep -r token .'
}

@test "refuse : ./rotate-secrets.sh" {
  verifie 2 './rotate-secrets.sh'
}

@test "refuse : bash rotate-secrets.sh" {
  verifie 2 'bash rotate-secrets.sh'
}

@test "refuse : git diff && ./rotate-secrets.sh" {
  verifie 2 'git diff && ./rotate-secrets.sh'
}

@test "refuse : cat README.md; ./rotate-secrets.sh" {
  verifie 2 'cat README.md; ./rotate-secrets.sh'
}

@test "refuse : cp .env .env.example" {
  verifie 2 'cp .env .env.example'
}

@test "refuse : cat .env > x.env.example" {
  verifie 2 'cat .env > x.env.example'
}

@test "autorise : cat .env.example" {
  verifie 0 'cat .env.example'
}

@test "autorise : cat README.md" {
  verifie 0 'cat README.md'
}

@test "autorise : git status" {
  verifie 0 'git status'
}

@test "autorise : shellcheck rotate-secrets.sh" {
  verifie 0 'shellcheck rotate-secrets.sh'
}

@test "autorise : cat rotate-secrets.sh" {
  verifie 0 'cat rotate-secrets.sh'
}

@test "autorise : grep -rn token services/" {
  verifie 0 'grep -rn token services/'
}

@test "autorise : grep -rn token . --exclude-dir=secrets" {
  verifie 0 'grep -rn token . --exclude-dir=secrets'
}

@test "autorise : ls -la" {
  verifie 0 'ls -la'
}
