#!/usr/bin/env bash
# Hook PreToolUse (matcher Bash) : bloque les commandes qui visent des fichiers sensibles
# ou qui fouillent tout le depot sans exclusion. Code 2 = refus, stderr renvoye a Claude.
# Echec de lecture du JSON = refus (fail-closed).
cmd=$(python3 -c 'import sys,json; print(json.load(sys.stdin)["tool_input"].get("command",""))') \
  || { journal bash entree-illisible "-"; echo "guard-secrets : entree illisible, commande refusee." >&2; exit 2; }
AUDIT="$HOME/.claude/hooks/guard-secrets.audit.log"
# Journal d'audit : horodatage, hook, motif, cible. Rotation simple a 2000 lignes.
journal() {
  printf '%s\t%s\t%s\t%s\n' "$(date -Is)" "$1" "$2" "$3" >> "$AUDIT" 2>/dev/null
  if [ "$(wc -l < "$AUDIT" 2>/dev/null || echo 0)" -gt 2000 ]; then
    tail -n 1000 "$AUDIT" > "$AUDIT.tmp" 2>/dev/null && mv "$AUDIT.tmp" "$AUDIT"
  fi
}
motif='(^|[[:space:]/"'"'"'=~\\(])(secrets/|\.env([.[:space:]"'"'"')\\]|$)|[^[:space:]]*\.tfstate|\.litellm/\.env|id_rsa|id_ed25519|kubeconfig)'
cmd_scrub=$(printf '%s' "$cmd" | sed -E 's#[^[:space:]]*\.env\.example##g')
if printf '%s' "$cmd_scrub" | grep -Eq "$motif"; then
  journal bash fichier-sensible "$cmd"; echo "Bloque par guard-secrets : la commande vise un fichier sensible." >&2; exit 2
fi
if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])(grep|rg|ag)[[:space:]]' \
   && printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])rg[[:space:]]|[[:space:]]-[a-zA-Z]*[rR]|--recursive' \
   && ! printf '%s' "$cmd" | grep -Eq -- '--exclude-dir|--glob|[[:space:]]-g[[:space:]]|--type|[[:space:]](services|k8s|docs|scripts|src|\.github)/?([[:space:]]|$)'; then
  journal bash recherche-recursive "$cmd"; echo "Bloque par guard-secrets : recherche recursive sur tout le depot. Cible un dossier ou ajoute --exclude-dir=secrets --exclude-dir=infra." >&2; exit 2
fi
# Scripts de production marques "ne jamais executer" : lecture et lint permis, execution refusee
exec_pat='(^|[;&|[:space:]])(bash|sh|zsh|source|\.|exec|sudo)[[:space:]]+[^;&|]*rotate-secrets|(^|[;&|[:space:]])\.?/?[^[:space:]]*rotate-secrets\.sh([[:space:]]|$)'
allow_pat='^[[:space:]]*(shellcheck|cat|less|head|tail|git (add|diff|status)|chmod 644|stat|ls)[[:space:]]'
while IFS= read -r seg; do
  if printf '%s' "$seg" | grep -Eq "$exec_pat" && ! printf '%s' "$seg" | grep -Eq "$allow_pat"; then
    journal bash script-production "$seg"; echo "Bloque par guard-secrets : ce script de production ne doit jamais etre execute." >&2; exit 2
  fi
done < <(printf '%s\n' "$cmd" | sed -E 's/&&|\|\||[;&|]/\n/g')
exit 0
