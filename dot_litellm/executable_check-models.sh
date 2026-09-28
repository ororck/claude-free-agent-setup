#!/usr/bin/env bash
set -a; source ~/.litellm/.env; set +a
D="$HOME/.litellm/catalog"; LOG="$HOME/.litellm/new-models.log"; mkdir -p "$D"

list_openrouter() { curl -s -m 20 https://openrouter.ai/api/v1/models | grep -o '"id":"[^"]*:free"'; }
list_kilo()       { curl -s -m 20 https://api.kilo.ai/api/gateway/models -H "Authorization: Bearer $KILO_API_KEY" | grep -o '"id":"[^"]*:free"'; }
list_groq()       { curl -s -m 20 https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GROQ_API_KEY" | grep -o '"id":"[^"]*"'; }
list_ollama()     { curl -s -m 20 https://ollama.com/v1/models -H "Authorization: Bearer $OLLAMA_API_KEY" | grep -o '"id":"[^"]*"'; }
list_gemini()     { curl -s -m 20 "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" | grep -o '"name": "models/[^"]*"'; }
list_mistral()    { curl -s -m 20 https://api.mistral.ai/v1/models -H "Authorization: Bearer $MISTRAL_API_KEY" | grep -o '"id":"[^"]*"'; }

found=0
for p in openrouter kilo groq ollama gemini mistral; do
  new=$("list_$p" | sort -u)
  [ -z "$new" ] && continue
  if [ -f "$D/$p.txt" ]; then
    added=$(comm -13 "$D/$p.txt" <(printf '%s\n' "$new"))
    if [ -n "$added" ]; then
      found=1
      while read -r m; do
        echo "$(date +%F) $p NOUVEAU $m" >> "$LOG"
        echo -e "\033[1;33mNOUVEAU chez $p : $m\033[0m"
      done <<< "$added"
    fi
  fi
  printf '%s\n' "$new" > "$D/$p.txt"
done
[ "$found" = 0 ] && echo "Aucun nouveau modele gratuit"
exit 0
