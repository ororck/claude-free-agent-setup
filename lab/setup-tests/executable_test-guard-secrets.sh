#!/usr/bin/env bash
# Suite de tests des hooks guard-secrets. Code 0 si tous les cas passent.
set -uo pipefail
HB="$HOME/.claude/hooks/guard-secrets.sh"
HF="$HOME/.claude/hooks/guard-secrets-files.sh"
ok=0; ko=0

cas_bash() { # <attendu> <commande>
  local att="$1" cmd="$2" got
  printf '{"tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$cmd")" \
    | "$HB" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$att" ]; then ok=$((ok+1)); else ko=$((ko+1)); echo "KO bash attendu=$att obtenu=$got : $cmd"; fi
}
cas_file() { # <attendu> <tool_name> <json tool_input>
  local att="$1" tool="$2" ti="$3" got
  printf '{"tool_name":"%s","tool_input":%s}' "$tool" "$ti" | "$HF" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$att" ]; then ok=$((ok+1)); else ko=$((ko+1)); echo "KO file attendu=$att obtenu=$got : $tool $ti"; fi
}

# --- bloques (2)
cas_bash 2 'cat secrets/db.txt'
cas_bash 2 'cat .env'
cas_bash 2 'cat app/.env'
cas_bash 2 'cat terraform.tfstate'
cas_bash 2 'cat ~/.litellm/.env'
cas_bash 2 'cat ~/.ssh/id_rsa'
cas_bash 2 'cat id_ed25519'
cas_bash 2 'cat kubeconfig'
cas_bash 2 'grep -r token .'
cas_bash 2 './rotate-secrets.sh'
cas_bash 2 'bash rotate-secrets.sh'
cas_bash 2 'git diff && ./rotate-secrets.sh'
cas_bash 2 'cat README.md; ./rotate-secrets.sh'
cas_bash 2 'cp .env .env.example'
cas_bash 2 'cat .env > x.env.example'
# --- autorises (0)
cas_bash 0 'cat .env.example'
cas_bash 0 'cat README.md'
cas_bash 0 'git status'
cas_bash 0 'shellcheck rotate-secrets.sh'
cas_bash 0 'cat rotate-secrets.sh'
cas_bash 0 'grep -rn token services/'
cas_bash 0 'grep -rn token . --exclude-dir=secrets'
cas_bash 0 'ls -la'

# --- outils natifs, bloques (2)
cas_file 2 Read '{"file_path":"/home/mohamed/lab/app/secrets/db.txt"}'
cas_file 2 Read '{"file_path":"/home/mohamed/lab/app/.env"}'
cas_file 2 Read '{"file_path":"/home/mohamed/.ssh/id_rsa"}'
cas_file 2 Read '{"file_path":"certs/tls.pem"}'
cas_file 2 Read '{"file_path":"terraform.tfstate"}'
cas_file 2 Grep '{"pattern":"token","path":".kube/"}'
cas_file 2 Grep '{"pattern":"token","path":"secrets/"}'
cas_file 2 Glob '{"pattern":"**/*.pem"}'
# --- outils natifs, autorises (0)
cas_file 0 Read '{"file_path":"/home/mohamed/lab/app/.env.example"}'
cas_file 0 Read '{"file_path":"README.md"}'
cas_file 0 Grep '{"pattern":"token","path":"services/"}'
cas_file 0 Glob '{"pattern":"**/*.yaml"}'
cas_file 0 Read '{"file_path":"docs/kubeconfig.md"}'

echo "resultat : $ok ok, $ko ko"
[ "$ko" -eq 0 ]
