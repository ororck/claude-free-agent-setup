#!/usr/bin/env python3
"""assert-k8s.py : verifie des valeurs attendues dans un rendu kustomize (stdin).
Usage : kustomize build k8s/overlays/prod | assert-k8s.py web=3 notifications=3"""
import sys, yaml
attendu = dict(a.split("=") for a in sys.argv[1:])
vu = {d["metadata"]["name"]: d["spec"].get("replicas") for d in yaml.safe_load_all(sys.stdin)
      if d and d.get("kind") == "Deployment"}
ko = [f"{n}: attendu {v}, trouve {vu.get(n)}" for n, v in attendu.items() if str(vu.get(n)) != v]
print("\n".join(ko) if ko else "OK replicas conformes"); sys.exit(1 if ko else 0)
