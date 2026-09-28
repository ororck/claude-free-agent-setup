#!/usr/bin/env python3
"""run-stats.py : anatomie d'une session Claude Code a partir de son .jsonl
Usage : run-stats.py <session.jsonl>
Compte les reponses (dedupliquees par message.id), les tokens, et les appels d'outils par nom."""
import json, sys, collections

vus, blocs_vus = set(), set()
outils, modeles = collections.Counter(), collections.Counter()
tok = collections.Counter()
chars = collections.Counter()
bash_cmds = collections.Counter()
compactions = 0
for n, ligne in enumerate(open(sys.argv[1], encoding="utf-8")):
    try:
        e = json.loads(ligne)
    except json.JSONDecodeError:
        continue
    if e.get("subtype") == "compact_boundary" or e.get("isCompactSummary"):
        compactions += 1
    if e.get("type") != "assistant":
        continue
    m = e.get("message", {})
    mid = m.get("id") or f"_sans_id_{n}"   # sans id, la ligne est unique : jamais dedupliquee
    # Une reponse est ecrite en plusieurs lignes qui se COMPLETENT (texte puis tool_use),
    # elles ne se repetent pas : on parcourt toutes les lignes et on deduplique par bloc.
    for i, bloc in enumerate(m.get("content", []) or []):
        t = bloc.get("type")
        cle = bloc.get("id") or f"{mid}:{i}:{t}:{len(str(bloc))}"
        if cle in blocs_vus:
            continue
        blocs_vus.add(cle)
        if t == "tool_use":
            outils[bloc.get("name", "?")] += 1
            if bloc.get("name") == "Bash":
                cmd = (bloc.get("input", {}).get("command") or "").split()
                bash_cmds[cmd[0] if cmd else "?"] += 1
        elif t == "thinking":
            chars["reflexion"] += len(bloc.get("thinking", ""))
        elif t == "text":
            chars["texte"] += len(bloc.get("text", ""))
    if mid in vus:      # usage cumulatif sur l'id : compte une seule fois
        continue
    vus.add(mid)
    modeles[m.get("model", "?")] += 1
    u = m.get("usage", {}) or {}
    for k in ("output_tokens", "input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"):
        tok[k] += u.get(k, 0) or 0

print(f"Reponses (tours) : {len(vus)}")
print(f"Compactions : {compactions}")
print("Modeles :", dict(modeles))
for k, v in tok.items():
    print(f"{k:30} {v:>12,}")
if vus:
    print(f"{'sortie moyenne par tour':30} {tok['output_tokens']//len(vus):>12,}")
    print(f"{'contexte relu moyen par tour':30} {tok['cache_read_input_tokens']//len(vus):>12,}")
print("Caracteres visibles :", dict(chars), "(la reflexion peut etre resumee, indicatif seulement)")
print("Appels d'outils :", dict(outils.most_common()))
print("Commandes Bash (1er mot) :", dict(bash_cmds.most_common(10)))
