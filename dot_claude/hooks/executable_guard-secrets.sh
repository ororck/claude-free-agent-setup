#!/usr/bin/env bash
# Hook PreToolUse (matcher Bash) : bloque les commandes qui visent des fichiers sensibles
# ou qui fouillent tout le depot sans exclusion. Code 2 = refus, stderr renvoye a Claude.
# Echec de lecture du JSON = refus (fail-closed).
cmd=$(python3 -c 'import sys,json; print(json.load(sys.stdin)["tool_input"].get("command",""))') \
  || { echo "guard-secrets : entree illisible, commande refusee." >&2; exit 2; }
motif='(^|[[:space:]/"'"'"'=~\\(])(secrets/|\.env([.[:space:]"'"'"')\\]|$)|[^[:space:]]*\.tfstate|\.litellm/\.env|id_rsa|id_ed25519|kubeconfig)'
if printf '%s' "$cmd" | grep -Eq "$motif" && ! printf '%s' "$cmd" | grep -Eq '\.env\.example'; then
  echo "Bloque par guard-secrets : la commande vise un fichier sensible." >&2; exit 2
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])(grep|rg|ag)[[:space:]]' \
   && printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])rg[[:space:]]|[[:space:]]-[a-zA-Z]*[rR]|--recursive' \
   && ! printf '%s' "$cmd" | grep -Eq -- '--exclude-dir|--glob|[[:space:]]-g[[:space:]]|--type|[[:space:]](services|k8s|docs|scripts|src|\.github)/?([[:space:]]|$)'; then
  echo "Bloque par guard-secrets : recherche recursive sur tout le depot. Cible un dossier ou ajoute --exclude-dir=secrets --exclude-dir=infra." >&2; exit 2
fi
# Scripts de production marques "ne jamais executer" : lecture et lint permis, execution refusee
if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])(bash|sh|zsh|source|\.|exec|sudo)[[:space:]]+[^;&|]*rotate-secrets|(^|[;&|[:space:]])\.?/?[^[:space:]]*rotate-secrets\.sh([[:space:]]|$)' \
   && ! printf '%s' "$cmd" | grep -Eq '^[[:space:]]*(shellcheck|cat|less|head|tail|git (add|diff|status)|chmod 644|stat|ls)[[:space:]]'; then
  echo "Bloque par guard-secrets : ce script de production ne doit jamais etre execute." >&2; exit 2
fi
exit 0
