#!/usr/bin/env python3
"""assert-k8s.py : verifie des valeurs attendues dans un rendu kustomize (stdin).
Usage : kustomize build k8s/overlays/prod | assert-k8s.py web=3 notifications=3"""
import sys, yaml

USAGE = "Usage : ... | assert-k8s.py <nom>=<replicas> [<nom>=<replicas>...]"
KINDS = ("Deployment", "StatefulSet")

if len(sys.argv) < 2:
    print(USAGE, file=sys.stderr); sys.exit(2)

attendu = {}
for a in sys.argv[1:]:
    nom, sep, val = a.partition("=")
    if not sep or not nom or not val:
        print(f"argument invalide : {a}\n{USAGE}", file=sys.stderr); sys.exit(2)
    if nom in attendu and attendu[nom] != val:
        print(f"argument en doublon avec deux valeurs : {nom}", file=sys.stderr); sys.exit(2)
    attendu[nom] = val

try:
    docs = list(yaml.safe_load_all(sys.stdin))
except yaml.YAMLError as e:
    print(f"YAML illisible sur stdin : {e}", file=sys.stderr); sys.exit(2)

vu = {}
for d in docs:
    if not isinstance(d, dict) or d.get("kind") not in KINDS:
        continue
    nom = (d.get("metadata") or {}).get("name")
    if nom is None:
        continue
    vu[nom] = (d.get("spec") or {}).get("replicas")

ko = [f"{n}: attendu {v}, trouve {vu.get(n)}" for n, v in attendu.items() if str(vu.get(n)) != v]
print("\n".join(ko) if ko else "OK replicas conformes")
sys.exit(1 if ko else 0)
