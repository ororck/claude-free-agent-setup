---
name: delegation
description: Protocole pour deleguer une tache a des workers gratuits (OpenCode via LiteLLM, isoles en git worktree) et la pre-verifier. Utiliser avant toute delegation.
---

# Delegation

Objectif : economiser les tokens de l'orchestrateur. Deleguer est la regle, pas l'exception : toute tache qui remplit les criteres de "Quoi deleguer" part chez un worker. Garder pour toi les decisions, les taches critiques et la verification finale.

## Avant tout : generer au lieu de deleguer
Dockerfiles, manifestes Kubernetes, kustomize et workflows CI se generent avec le skill `scaffold-infra`, jamais par un worker ni a la main.

## Couches, par ordre de preference
1. Workers externes gratuits : OpenCode en headless via `delegate.sh`, modele via LiteLLM local.
2. Sous-agents natifs, seulement si les workers externes sont indisponibles : Explore, spec-writer, doc-writer (haiku), implementer (sonnet).

## Avant de deleguer
- `curl -sf http://localhost:4000/health/liveliness`. Si LiteLLM ne repond pas, prevenir l'utilisateur (`litellm-up`) et ne pas deleguer.
- Si `~/.litellm/new-models.log` contient des entrees recentes, le signaler.
- Noter le nombre de lignes de `~/.litellm/degraded.log`.
- Le depot doit avoir au moins un commit, et `secrets/`, `*.tfstate*`, `.env*`, `.worker-out/` dans `.gitignore`. Sinon `delegate.sh` refuse.

## Quoi deleguer
Uniquement une tache autonome, avec une specification complete, dont le resultat se verifie mecaniquement. Si tu ne peux pas ecrire ce que le worker doit produire, fais-le toi-meme.
Jamais : decision d'architecture, arbitrage, operation irreversible, action sur une infra.
Jamais de code, configuration ou nom venant d'une entreprise ou d'un client (PFMP comprise) : les fournisseurs gratuits peuvent lire et reutiliser ce qu'ils recoivent.
Kustomize : la base va dans `k8s/base/`, `k8s/kustomization.yaml` pointe `base`, les overlays pointent `../../base`.

## Choix du worker
- worker-c : code, YAML, configs
- worker-a : taches multi-fichiers ou multi-etapes
- worker-d : tests, README, changelog
- worker-b : redaction, documentation, le reste
Quatre taches maximum par round, une par worker. Jamais deux taches pour le meme worker dans un round, jamais plus de quatre lignes dans plan.txt. Taches restantes : rounds suivants.

## Lancement
1. Regles communes dans un seul fichier de spec. Dans chaque consigne `.worker-out/<tache>.prompt.md`, uniquement ce qui est propre a la tache.
2. Ecrire `.worker-out/plan.txt`, une tache par ligne : `<worker> <consigne.md> <livrable> [livrable...]`. Puis lancer en UNE commande Bash avec `run_in_background: true`, depuis la racine du projet :
   `delegate-round.sh .worker-out/plan.txt`
   Un pane herdr s'ouvre par worker et se ferme a la fin de sa tache. Le script rend une ligne par tache.
   Un livrable qui depend des fichiers produits par une autre tache du meme round est impossible : chaque worker travaille dans un worktree isole qui ne contient que l'etat du depot avant le round. Ces fichiers (kustomization.yaml agregeant plusieurs composants, index, sommaire) se font dans un round suivant ou par toi.
   Lister TOUS les fichiers attendus. Seuls les livrables listes sont recopies dans le depot, tout le reste est jete.
3. Attendre la notification de fin, sans consulter l'etat entre-temps. Lire la sortie de la tache de fond (une ligne par tache).
4. Apres une compaction, les identifiants de taches de fond peuvent etre perdus : lire `.worker-out/delegate.log`.

`delegate.sh` isole chaque worker dans un git worktree ou les fichiers ignores (secrets, tfstate) n'existent pas, ajoute le saut de ligne final, lint chaque livrable, relance le worker avec les erreurs jusqu'a 3 essais, puis recopie uniquement les livrables.

Codes de sortie : 0 livrables recopies et lint OK (la ligne signale les fichiers hors livrables jetes), 1 refus (chemin interdit, fichier sensible non ignore, depot sans commit, outil manquant), 2 echec apres 3 essais (erreurs dans `.worker-out/<tache>.erreurs.txt`), 12 delai depasse. 0 prouve la forme, pas le fond.
Ne lire `.worker-out/<tache>.run.log` que pour diagnostiquer un code 2 ou 12.

## Ce que les workers peuvent faire
Lire et ecrire des fichiers du projet, hors fichiers sensibles. Bash, web, grep, glob et acces hors du projet leur sont interdits par configuration. Ne leur demande jamais d'executer une commande. Ne jamais lancer OpenCode avec `--auto` ni `--dangerously-skip-permissions`.

## Securite, non negociable
- Aucun secret dans un prompt : ni cle, jeton, mot de passe, kubeconfig, identifiant d'abonnement, nom de ressource reel, ni donnee personnelle.
- Fichiers intermediaires dans `.worker-out/`, ignore par git.
- Demande de permission d'un worker : valider seul uniquement si elle porte sur un fichier du projet. Sinon, arreter et demander a l'utilisateur.

## Pre-verification
- Seulement si le rendu depasse environ 100 lignes ou plusieurs fichiers.
- Jamais sur une tache critique : verification complete par toi.
- Lancer le verificateur : `timeout 900 opencode run --agent verifier 'Verifie les fichiers produits contre la specification jointe. Tache: <tache>.' --file <spec> --file <fichier> ...`. Il ecrit `.worker-out/<tache>.verif.md`. Si ce fichier est absent, le verificateur a echoue.
- Lire toi-meme le chemin attendu, jamais celui renvoye par le verificateur.
- Controle anti-complaisance : verifier toi-meme au moins une exigence marquee OK.

## Verification finale
- Tache critique (securite, secrets, irreversible, infra de production) : sous-agent `critical-reviewer`.
- Ne pas relinter chaque tache : `delegate.sh` l'a fait. Verification mecanique complete une seule fois, en fin de projet, plus `assert-k8s.py` pour les valeurs par overlay (ex. `kubectl kustomize k8s/overlays/prod | assert-k8s.py notifications=3`).
- Controler toi-meme le fond (valeurs du contexte, contradictions).
- Si `degraded.log` a augmente, verifier plus strictement et le signaler.
- Code 2 : lire `.worker-out/<tache>.erreurs.txt`. Valeur absente du contexte : la signaler sans l'inventer. Sinon redecouper ou reprendre toi-meme. Deux codes 2 sur le meme type de tache : ne plus deleguer ce type pour la session.
- Pour le bilan, le nombre d'essais par tache est dans `.worker-out/delegate.log`.
