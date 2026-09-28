---
name: herdr-lite
description: "Deleguer une tache a un agent de code dans un pane Herdr voisin. Utiliser uniquement quand l'utilisateur demande de deleguer a un worker, ou mentionne Herdr explicitement. Requiert HERDR_ENV=1."
---

# Herdr, deleguer a un worker

Avant toute commande, verifier :

```bash
test "${HERDR_ENV:-}" = 1
```

Si le test echoue, dire que tu ne tournes pas dans Herdr et t'arreter.

Ne jamais lancer `herdr` seul, cela ouvre la TUI. Pour la syntaxe exacte d'un groupe, lancer le groupe sans sous-commande :

```bash
herdr pane
herdr agent
```

Les commandes renvoient du JSON. Lire les identifiants dans la reponse, ne jamais les deviner.

## 1. Creer le pane

Pane voisin dans l'onglet courant, meme repertoire, sans voler le focus :

```bash
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Utiliser `down` si le pane appelant est etroit ou haut. Eviter les splits repetes dans la meme direction.
Lire le nouvel identifiant dans `.result.pane.pane_id`.

## 2. Demarrer l'agent

Le pane doit etre a son invite interactive, sans commande ni agent en cours. `agent start` ne cree ni ne deplace aucun pane.

```bash
herdr agent start worker1 --kind opencode --pane <pane-id>
```

Le nom doit respecter `[a-z][a-z0-9_-]{0,31}` et etre unique parmi les agents vivants.
Arguments natifs de l'agent uniquement apres `--`.
Demarrage limite a 30 secondes par defaut. Si la commande renvoie `agent_not_ready`, le nom reste utilisable pour `agent read` : attendre que l'agent soit idle avant de le prompter.

## 3. Envoyer la tache

```bash
herdr agent prompt worker1 "<instruction>" --wait --timeout 120000
```

`--wait` attend le premier etat stabilise `idle`, `done` ou `blocked`. Ne pas ajouter `--until` pour ces valeurs par defaut.

Reponses d'erreur et ce qu'elles signifient :
- `agent_blocked` : l'agent attend deja une validation. Inspecter avant de repondre, ne pas repondre a l'aveugle.
- `agent_prompt_stalled` : aucune activite observee dans les cinq secondes suivant l'envoi.
- `timeout` : le delai de l'appelant a expire, submission incluse.

Un timeout ou un stall ne prouve pas que le prompt n'a pas ete delivre. Relire l'agent avant de le renvoyer, sinon risque de double soumission.

## 4. Lire le rendu

```bash
herdr agent get worker1
herdr agent read worker1 --source recent-unwrapped --lines 120
```

Si une lecture plus large ne revele toujours pas la reponse complete, demander a l'agent d'ecrire son rendu en Markdown dans un repertoire temporaire et de ne repondre que le chemin du fichier, puis lire ce fichier. Repli uniquement, ne pas demander la sortie fichier dans le prompt initial.

## 5. Lancer une commande dans un pane

```bash
herdr pane run <pane-id> "<commande>"
herdr pane wait-output <pane-id> --match "<texte>" --timeout 900000
herdr pane read <pane-id> --source recent-unwrapped --lines 120
```

`pane run` envoie la commande et Entree. `pane wait-output` cherche aussi dans la sortie deja affichee.

## Regles

- Toujours `--no-focus`, sauf demande explicite de changer de contexte.
- Cibler par `--current`, un pane ID explicite, ou un nom d'agent unique. Jamais le pane focalise d'un autre client.
- Parser les identifiants depuis le JSON, jamais depuis l'ordre de la sidebar.
- Ne fermer aucun pane que tu n'as pas cree toi-meme.
- Ne jamais lancer `herdr server stop`, ne jamais tuer le processus Herdr principal.
- Erreurs serveur en JSON sur stderr, code 1. Erreurs de syntaxe, code 2.
