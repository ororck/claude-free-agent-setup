#!/usr/bin/env bash
# Hook PreToolUse (matchers Read, Grep, Glob) : bloque l'acces aux chemins sensibles
# via les outils natifs. Complement de guard-secrets.sh qui ne couvre que Bash.
# Echec de lecture du JSON = refus (fail-closed).
cibles=$(python3 -c '
import sys, json
d = json.load(sys.stdin)
t = d.get("tool_name", "")
i = d.get("tool_input", {})
out = []
if t == "Read":
    out.append(i.get("file_path", ""))
elif t in ("Grep", "Glob"):
    out.append(i.get("path", ""))
    out.append(i.get("pattern", ""))
    out.append(i.get("glob", ""))
print("\n".join(x for x in out if x))
') || { journal outils entree-illisible "-"; echo "guard-secrets-files : entree illisible, appel refuse." >&2; exit 2; }
[ -z "$cibles" ] && exit 0
AUDIT="$HOME/.claude/hooks/guard-secrets.audit.log"
# Journal d'audit : horodatage, hook, motif, cible. Rotation simple a 2000 lignes.
journal() {
  printf '%s\t%s\t%s\t%s\n' "$(date -Is)" "$1" "$2" "$3" >> "$AUDIT" 2>/dev/null
  if [ "$(wc -l < "$AUDIT" 2>/dev/null || echo 0)" -gt 2000 ]; then
    tail -n 1000 "$AUDIT" > "$AUDIT.tmp" 2>/dev/null && mv "$AUDIT.tmp" "$AUDIT"
  fi
}
motif='(^|/)secrets/|(^|/)\.env($|\.)|\.tfstate|(^|/)id_rsa|(^|/)id_ed25519|(^|/)kubeconfig($|/)|(^|/)\.kube/|\.pem$|\.key$|(^|/)\.ssh/'
cibles_scrub=$(printf '%s' "$cibles" | sed -E 's#[^[:space:]]*\.env\.example##g')
if printf '%s' "$cibles_scrub" | grep -Eq "$motif"; then
  journal outils chemin-sensible "$(printf '%s' "$cibles" | tr '\n' ' ')"; echo "Bloque par guard-secrets-files : cet appel vise un chemin sensible." >&2; exit 2
fi
exit 0
