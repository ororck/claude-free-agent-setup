# setup-tests

Suite de tests des garde-fous du setup orchestrateur, avec bats-core 1.13.0 (copie dans `bats/`). Aucun appel LLM, aucun token.

## Lancer

    ~/lab/setup-tests/run-all.sh

Code de sortie 0 si tout passe, 1 sinon. Le script affiche les cas en echec et un total. Il echoue aussi si moins de 36 cas sont trouves.

bats-core v1.13.0 est vendorise en copie simple dans `bats/` (version dans `bats/VERSION`). Aucun sous-module, `chezmoi apply` restitue tout.

## Ce qui est teste

- `guard-secrets.bats`, 23 cas. Un faux evenement PreToolUse sur l'entree standard du hook Bash, code attendu 2 (refus) ou 0 (passage). Dont les deux contournements fermes le 28 septembre, `git diff && ./rotate-secrets.sh` et `cp .env .env.example`
- `guard-secrets-files.bats`, 13 cas. Meme principe pour les outils natifs Read, Grep et Glob
- `shellcheck.bats`, un cas par script du setup (delegate.sh, delegate-round.sh, delegate-boN.sh, les deux hooks, run-all.sh, helpers et fichiers .bats)
- `delegate-retour.bats`, delegate.sh avec un faux `opencode` : retour arriere sur le meilleur essai, COPIER, SUFFIXE
- `delegate-boN.bats`, delegate-boN.sh avec un faux `delegate.sh` en tete de PATH : un seul gagnant, raffinement du moins mauvais, plafond MAX_PAR

`helpers.bash` contient les fonctions communes aux deux derniers fichiers.

## Quand le lancer

- Apres un `chezmoi apply` sur une nouvelle machine, pour verifier que les hooks fonctionnent dans cet environnement
- Apres toute modification d'un motif dans un hook, pour detecter la reouverture d'un contournement
- Apres toute modification de delegate.sh ou delegate-boN.sh

## Ajouter un cas

Dans `guard-secrets.bats`, un bloc suffit.

    @test "refuse : commande a bloquer" {
      verifie 2 'commande a bloquer'
    }

Pour `guard-secrets-files.bats`, `verifie 2 Read '{"file_path":"chemin/sensible"}'`.

## Fichiers couverts

    ~/.claude/hooks/guard-secrets.sh          commandes Bash
    ~/.claude/hooks/guard-secrets-files.sh    outils natifs Read, Grep, Glob
    ~/.local/bin/delegate.sh
    ~/.local/bin/delegate-round.sh
    ~/.local/bin/delegate-boN.sh

## Installation sur une machine neuve

bats-core n'est pas versionne dans chezmoi, seulement les tests. Apres un
`chezmoi apply`, installe le moteur.

    git clone --depth 1 --branch v1.13.0 https://github.com/bats-core/bats-core.git ~/lab/setup-tests/bats

Verifie ensuite avec `~/lab/setup-tests/run-all.sh`.
