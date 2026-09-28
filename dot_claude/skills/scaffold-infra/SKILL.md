---
name: scaffold-infra
description: Genere sans LLM les Dockerfiles, manifestes Kubernetes (deployment, service), kustomize base/overlays et workflows GitHub Actions de services, a partir d'une spec YAML. Utiliser avant toute delegation de ces fichiers.
---

# scaffold-infra

Ces fichiers ne s'ecrivent jamais a la main ni par un worker : ils se generent.

## Etapes
1. Ecrire `.worker-out/spec.yaml` a partir du brief, sur le modele de `~/.claude/skills/scaffold-infra/exemple.yaml`.
   - `langage` : go, python, node ou nginx. Autre langage : le signaler a l'utilisateur, ne pas improviser.
   - Valeur absente du brief (port par exemple) : `null`. Le generateur ecrit `PORT MANQUANT` et le bilan le signale.
   - Valeur differente en production : `replicas_prod`.
2. Depuis la racine du depot : `python3 ~/.claude/skills/scaffold-infra/gen.py .worker-out/spec.yaml`
   Code 3 : des fichiers existent deja, rien n'est ecrase sans `--force`.
3. Lancer la verification mecanique du projet (make lint ou equivalent).

## Choix figes par les gabarits
- Images epinglees en version x.y.z, utilisateur UID 10001.
- nginx : image non-root ecoutant sur 8080, le Service expose le port du brief vers 8080.
- Kustomize : base dans `k8s/base/`, `k8s/kustomization.yaml` pointe `base`, overlays dans `k8s/overlays/{dev,prod}` pointant `../../base`.
- Workflows : lint hadolint + build, `push: false`.

Ce qui reste hors generateur : README, documentation, Makefile, scripts. Ceux-la passent par le skill delegation.
