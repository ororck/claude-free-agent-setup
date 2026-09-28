# setup-tests

Suite de tests des garde-fous du setup orchestrateur. Aucun appel LLM, aucun token.

## Lancer

    ~/lab/setup-tests/run-all.sh

Code de sortie 0 si tout passe, 1 sinon. Chaque cas en echec est affiche avec le code attendu et le code obtenu.

## Ce qui est teste

`test-guard-secrets.sh`, 36 cas. Chaque cas envoie un faux evenement PreToolUse sur l'entree standard du hook et compare son code de sortie a la valeur attendue, 2 pour un refus, 0 pour un passage.

- 15 commandes Bash qui doivent etre refusees, lecture de secrets, recherche recursive sans exclusion, execution de `rotate-secrets.sh`, et les deux contournements fermes le 28 septembre, `git diff && ./rotate-secrets.sh` et `cp .env .env.example`
- 8 commandes Bash qui doivent passer, dont `cat .env.example` et `grep` cible sur un dossier
- 8 appels d'outils natifs Read, Grep et Glob qui doivent etre refuses
- 5 appels d'outils natifs qui doivent passer

`test-shellcheck.sh`, shellcheck sur les cinq scripts du setup, les deux hooks, `delegate.sh`, `delegate-round.sh` et la suite elle-meme.

## Quand le lancer

- Apres un `chezmoi apply` sur une nouvelle machine, pour verifier que les hooks fonctionnent dans cet environnement
- Apres toute modification d'un motif dans un hook, pour detecter la reouverture d'un contournement

## Ajouter un cas

Dans `test-guard-secrets.sh`, une ligne suffit.

    cas_bash 2 'commande qui doit etre refusee'
    cas_bash 0 'commande qui doit passer'
    cas_file 2 Read '{"file_path":"chemin/sensible"}'

## Fichiers couverts

    ~/.claude/hooks/guard-secrets.sh          commandes Bash
    ~/.claude/hooks/guard-secrets-files.sh    outils natifs Read, Grep, Glob
    ~/.local/bin/delegate.sh
    ~/.local/bin/delegate-round.sh
