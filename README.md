# Setup orchestrateur, Claude Code et workers gratuits

Configuration versionnee par chezmoi. Claude Code orchestre et decide, des workers
gratuits executent les taches specifiables. Les cles sont chiffrees avec age.

## 1. Principe

Claude Code ne sert qu'aux decisions, aux taches critiques et a la verification finale.
Tout ce qui a une specification complete et un resultat verifiable mecaniquement part
chez un worker gratuit. L'objectif est de rendre viables des projets qui couteraient
trop cher en tokens Claude.

Trois couches.

- Generation sans LLM, le skill `scaffold-infra` produit Dockerfiles, manifestes,
  kustomize et workflows depuis une spec YAML. Zero token. A preferer toujours.
- Workers gratuits, OpenCode en headless, modele fourni par une passerelle LiteLLM locale.
- Sous-agents Claude natifs, seulement si les workers sont indisponibles.

## 2. Architecture

    herdr (multiplexeur, WSL2)
     |- pane litellm-up      passerelle LiteLLM sur 127.0.0.1:4000
     |- pane claude          orchestrateur, model sonnet et advisorModel opus
     |- panes d'affichage    ouverts et fermes par delegate-round.sh

Chaine d'un round.

1. Claude ecrit une consigne par tache dans `.worker-out/<tache>.prompt.md`
2. Claude ecrit `.worker-out/plan.txt`, une ligne par tache,
   `<worker> <consigne.md> <livrable> [livrable...]`
3. Claude lance `delegate-round.sh .worker-out/plan.txt` en tache de fond
4. Le script lance un `delegate.sh` par tache, trois en parallele au maximum,
   ouvre un pane d'affichage par tache, recupere les codes de sortie, ferme les panes
5. `delegate.sh` isole chaque worker dans un git worktree, lint le livrable,
   relance le worker avec ses erreurs jusqu'a trois essais, recopie uniquement
   les livrables declares

Le controle passe par les processus, les codes de sortie et les fichiers.
Jamais par ce qui s'affiche a l'ecran. Les panes servent uniquement a afficher.

## 3. Remise en route sur une machine neuve

Prerequis, WSL2 avec Ubuntu, Docker Engine natif, node 22 avec npm en prefixe
`~/.npm-global`.

### 3.1 Outillage

    npm install -g opencode-ai @qwen-code/qwen-code
    pip install --break-system-packages litellm ruff yamllint

Binaires a installer separement, chezmoi, herdr, shellcheck, hadolint, actionlint,
kubeconform, kube-linter, kubectl, terraform, kind, azure-cli.

### 3.2 Cle age

Sans elle rien n'est dechiffrable. Elle n'est pas dans le depot et ne doit jamais y etre.

1. Copier a la main `~/.config/chezmoi/key.txt` depuis la machine source
2. Droits 600 sur le fichier

### 3.3 Configuration

    chezmoi init --apply ororck/claude+free-agent-setup

Si `gh` renvoie une erreur 401, un `GITHUB_TOKEN` invalide traine dans l'environnement.

    unset GITHUB_TOKEN && gh auth login

### 3.4 Cles API

Generer les cles chez chaque fournisseur, section 4, puis les ecrire dans
`~/.litellm/.env`. Ne jamais coller une cle dans une conversation avec un agent,
l'ecrire directement dans le fichier.

### 3.5 Verification

    curl -sf http://localhost:4000/health/liveliness
    ~/lab/setup-tests/run-all.sh

## 4. Fournisseurs et generation des cles

Aucune valeur de cle ne figure dans ce depot en clair. Les fichiers `.env` sont
chiffres par age.

| Fournisseur | Variable | Page de generation |
|---|---|---|
| Kilo Gateway | `KILO_API_KEY` | https://app.kilo.ai |
| Groq | `GROQ_API_KEY` | https://console.groq.com/keys |
| Ollama Cloud | `OLLAMA_API_KEY` | https://ollama.com/settings/keys |
| Google Gemini | `GEMINI_API_KEY` | https://aistudio.google.com/app/apikey |
| OpenRouter | `OPENROUTER_API_KEY` | https://openrouter.ai/settings/keys |
| Cloudflare Workers AI | `CLOUDFLARE_API_TOKEN` et `CLOUDFLARE_ACCOUNT_ID` | https://dash.cloudflare.com/profile/api-tokens |
| Z.AI | `ZAI_API_KEY` | https://z.ai/manage-apikey/apikey-list |
| Mistral | `MISTRAL_API_KEY` | https://console.mistral.ai/api-keys |
| Cohere | `COHERE_API_KEY` | https://dashboard.cohere.com/api-keys |
| NVIDIA NIM | `NVIDIA_API_KEY` | https://build.nvidia.com |

Pour Cloudflare, le jeton a besoin des permissions Workers AI en lecture et en ecriture,
et l'identifiant de compte se lit sur la page Workers AI du tableau de bord.

### Recommandations et reserves

- Les endpoints gratuits NVIDIA portent la mention d'usage d'essai uniquement.
  Ne jamais y envoyer de code d'entreprise ni de donnee client.
- Aucun fournisseur gratuit ne convient pour du code d'entreprise. La regle du skill
  `delegation` est stricte, jamais de code, configuration ou nom venant d'une entreprise
  ou d'un client.
- Z.AI en direct n'accepte qu'une requete simultanee, utilisable pour un outil pilote
  a la main comme Qwen Code, pas pour les workers.
- Cerebras, cinq requetes par minute, contexte incertain.
- DeepSeek, serveurs chinois, tarif reduit hors pointe, a eviter pour tout code sensible.

### Ecartes, ne pas reproposer

Hetzner, carte bancaire et piece d'identite exigees. Gemini CLI, connexion par compte
Google supprimee. Tier gratuit Qwen OAuth, supprime. Omnara et yagura, ne gerent pas
OpenCode. opencode-monitor, projet peu maintenu. ccboard, ne demarre pas sous WSL2.
Callback Prometheus LiteLLM, fonctionnalite Enterprise. Modele local, environ huit
tokens par seconde pour un 7B sur processeur portable.

## 5. Modeles en vigueur

| Worker | Usage | Primaire |
|---|---|---|
| worker-a | taches multi-fichiers ou multi-etapes | Kilo Nemotron Ultra |
| worker-b | redaction, documentation | Groq Qwen |
| worker-c | code, YAML, configs | Ollama Cloud Gemma |
| worker-d | tests, README, changelog | Kilo stepfun |
| verifier | pre-verification | Gemini Flash-Lite |

Chaque entree a une chaine de replis dans `~/.litellm/config.yaml`. LiteLLM n'anticipe
pas les limites, il attend le 429 puis applique `cooldown_time`, fixe a 600 secondes.
`check-models.sh` detecte les nouveaux modeles gratuits mais ne les teste pas, un appel
reel est necessaire pour valider une entree.

## 6. Garde-fous

La vraie frontiere de securite est l'isolation par worktree. Les fichiers ignores par git
n'existent pas dans le worktree du worker, et seuls les livrables declares sont recopies.

Par dessus, deux hooks PreToolUse et une liste de refus.

- `~/.claude/hooks/guard-secrets.sh`, commandes Bash. Refuse la lecture de fichiers
  sensibles, la recherche recursive sans exclusion, l'execution des scripts de production.
  Evalue chaque segment d'une commande chainee, pas seulement le premier.
- `~/.claude/hooks/guard-secrets-files.sh`, outils natifs Read, Grep et Glob.
- `permissions.deny` dans `~/.claude/settings.json`, la seule application dure. Un hook
  PreToolUse ne se declenche pas sur un fichier insere par reference arobase dans un
  prompt, une regle deny sur Read si.
- Journal d'audit dans `~/.claude/hooks/guard-secrets.audit.log`, droits 600,
  exclu de chezmoi car il enregistre les commandes bloquees.

Les deux hooks sont best-effort. L'obfuscation par variables ou concatenation n'est pas
couverte, c'est assume, ils elevent la barre sans etre etanches.

## 7. Verifier le setup

    ~/lab/setup-tests/run-all.sh

36 cas sur les hooks, plus shellcheck sur les cinq scripts. A lancer apres tout
`chezmoi apply` et apres toute modification d'un motif dans un hook.

## 8. Pieges connus

1. L'interface OpenCode plante sous herdr. Les workers tournent en `opencode run`.
2. `opencode run --file`, mettre le message AVANT `--file`.
3. Les workers resolvent mal les chemins, joindre le contenu avec `--file`.
4. Un code de sortie 0 ne prouve pas la reussite, seulement la forme.
5. Le verificateur peut inventer le chemin qu'il renvoie, lire soi-meme le chemin attendu.
6. `opencode run` peut ne jamais sortir, `timeout -k 30` obligatoire.
7. Pane pollue apres un plantage, taper `reset`.
8. `herdr pane split` ne renvoie rien sur sa sortie standard.
9. Les workers gratuits ne depassent pas une centaine de lignes en redaction longue.
10. `chezmoi cd` ouvre un sous-shell, une commande chainee derriere avec deux esperluettes
    n'est pas executee.
11. Un processus bloque qui n'ecrit rien rend tout diagnostic par pipe impossible.
12. AgentHUD surveille les sessions Claude Code, pas OpenCode. Il ne voit donc que
    l'orchestrateur, jamais les workers.

## 9. Regles de travail

- Tout travail dans `~/lab`, jamais a sa racine directe, un sous-dossier par projet.
- Un depot sans commit initial ou sans `.worker-out/`, `.env*`, `secrets/`, `*.tfstate*`
  dans `.gitignore` est refuse par `delegate.sh`.
- `.claude/settings.json` d'un depot s'exclut par `.git/info/exclude`, jamais par
  `.gitignore` qui est lui-meme versionne.
- Aucune trace de l'outillage d'assistance dans un depot de projet.
