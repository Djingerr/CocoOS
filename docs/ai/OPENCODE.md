# Fedora — OpenCode, worktrees et revue contrôlée

Mémoire inter-modèles/CLI : **[MEMORY.md](MEMORY.md)**. Reprise `/task-resume`,
passation `/task-handoff` → skill canonique `session-memory` et `HANDOFF.md`.
Ces deux commandes conservent le modèle courant ; les rôles historiques ci-dessous
restent épinglés. Résultats réellement vérifiés : [MEMORY-REPORT.md](MEMORY-REPORT.md).

Configuration locale vérifiée avec **OpenCode 2.2.4**, Fedora 43, Qt 6.10.3.
Les règles architecturales restent dans `AGENTS.md` ; les procédures restent dans
`.agents/skills/`. Ce guide ne remplace ni ces règles ni `docs/ai/QUALITY.md`.

## Démarrage et modèles

Depuis le clone ou worktree contenant cet outillage :

```bash
scripts/dev/setup.sh
scripts/dev/status.sh
opencode
opencode auth list
opencode models
python3 scripts/dev/opencode-check.py --permissions
```

Dans le TUI, `/models` choisit un modèle et `/reload` force le rechargement local
(pas de redémarrage du service nécessaire). Ne pas lancer `/init` : `AGENTS.md`
est déjà maintenu. Pour un choix explicite au lancement :

```bash
opencode mini --agent developer --model openai/gpt-6.1-sol
opencode mini --agent explorer --model claude-agent/claude-haiku-4-5-20251001
opencode mini --agent developer --model claude-agent/claude-sonnet-4-6
```

Le TUI complet 2.2.4 **n'a pas** `--model` ni `--agent`. `mini` et `run` les ont.
Un agent primaire ne remplace pas nécessairement le modèle d'une session déjà
ouverte : choisir explicitement via `/models` ou `mini --model`.

| Rôle | Préférence configurée | Accès |
|---|---|---|
| architect | `openai/gpt-6.1-sol` | lecture, plan court, pas de shell |
| developer | `openai/gpt-6.1-sol` | code ciblé, shell sur confirmation |
| explorer | `openai/gpt-6-luna` | lecture/recherche, pas de shell |
| reviewer | `openai/gpt-6.1-sol` | lecture seulement, diff fourni |
| verifier | Luna ci-dessus | pas d'édition, scripts sur confirmation |
| documentation | Luna ci-dessus | docs/passation, pas de shell |

Les identifiants viennent du catalogue connecté, pas d'exemples génériques.
Tests d'inférence du 2026-10-30 : Sol et Luna répondent ; `gpt-5.5` est listé mais
refusé avec ce compte ChatGPT, donc non retenu. Claude Agent est connecté à Claude
Pro mais le quota hebdomadaire est épuisé jusqu'au **2026-11-02 01:00 Europe/Paris**.
Les rôles légers préfèrent donc Luna actuellement ; après rétablissement du quota,
Haiku pour explorer/verifier/documentation et Sonnet pour reviewer sont des choix
explicites possibles, pas un fallback payant automatique. La consommation relative
de quota de Luna/Sol n'a pas été mesurée.
Leur disponibilité peut changer : relancer `opencode models` et le contrôle.
Claude Agent utilise Claude Code installé sur le serveur, mais **ne charge pas
ses hooks/réglages** : `opencode.json`, les hooks Git et les scripts fournissent
les protections indépendantes. Claude Code classique conserve son adaptation.

### Coûts et nouveaux fournisseurs

Seuls `openai` et `claude-agent` sont autorisés localement. Aucun endpoint,
clé, plugin tiers, MCP ou crédit automatique n'est ajouté. Le warming est désactivé.
`claude auth status` vérifie la connexion Claude sans ouvrir les credentials ;
OpenAI doit rester connecté par **Sign in with ChatGPT**, pas par clé API.
Le catalogue et une connexion enregistrée ne prouvent pas à eux seuls qu'une
inférence réussira. Les quotas dépendent des abonnements et plusieurs sessions
les consomment simultanément. Il n'existe pas ici de plafond monétaire universel.
Ne jamais accepter une proposition de crédit/fallback payant.

Ajouter DeepSeek, Kimi, Gemini ou un modèle local plus tard ne demande pas de
refonte : après accord explicite sur les coûts, connecter le fournisseur dans
l'UI, vérifier son catalogue, puis ajouter une exception `provider.use` et choisir
les modèles par rôle. Ne pas recopier de secrets dans Git. Les politiques
globales/système peuvent être plus restrictives que celles du dépôt.

## Une tâche, un worktree, une session tmux

**Commiter l'outillage sur une branche de travail sûre avant la première tâche** :
une flotte part d'un commit, jamais de modifications non commitées.

```bash
scripts/dev/tmux-fleet.sh --help
scripts/dev/tmux-fleet.sh --tool opencode --model openai/gpt-6.1-sol \
  --goal 'Objectif précis ; critères de fin vérifiables' navigation
scripts/dev/tmux-fleet.sh --role reviewer --base ai/navigation revue-navigation
scripts/dev/tmux-fleet.sh list
scripts/dev/tmux-fleet.sh inspect navigation
scripts/dev/tmux-fleet.sh attach navigation
```

Depuis l'autre dépôt, utiliser son propre script, ou `--repo '/chemin/HostCompanion'`.
La branche est `ai/<tâche>`, le dossier `<clone principal>/.worktrees/<tâche>`.
Le registre est dans le répertoire Git commun (`ai-fleet/`), partagé entre ses
worktrees ; les sessions tmux ont un préfixe unique au clone. Deux développeurs
et un reviewer actifs maximum **au total entre les dépôts frères**, grâce à un
verrou/registre `.ai-fleet/` dans leur répertoire parent. Ce registre ne contient
que les chemins des registres de tâches, aucun prompt ni credential.
Pas d'orchestrateur ni de processus IA lancé dans le clone principal.

Les autres outils (`--tool claude`, `codex`, `aider`) restent possibles s'ils sont
déjà installés ; modèle choisi dans leur interface. Ne pas passer une chaîne
shell dans `--tool`. Seul OpenCode prend en charge `--model` dans cette flotte.

Chaque agent écrit **uniquement dans son worktree**. Avant de répartir, attribuer
les fichiers concernés ; une couture, le protocole ou un fichier de versions a
un seul propriétaire. Le reviewer lit la branche du développeur dans un autre
worktree. Les sous-agents natifs de lecture seule évitent les gros contextes ;
ne pas déléguer deux écritures dans le même worktree.

### Arrêt et nettoyage

Quitter l'agent proprement (`/exit` ou Ctrl-C selon l'outil), puis détacher tmux
avec `Ctrl-b d`. Le shell reste ouvert pour consulter les résultats.

```bash
scripts/dev/tmux-fleet.sh stop navigation
scripts/dev/tmux-fleet.sh clean navigation
```

Chaque opération demande de saisir le nom de tâche dans un terminal interactif.
`stop` refuse un agent encore actif. `clean` refuse une session active, toute
modification/non-suivi, un changement de branche et **les fichiers ignorés**
(logs/builds inclus). Archiver les résultats avant de les retirer explicitement.
La branche et ses commits sont conservés, jamais supprimés/mergés automatiquement.
Un échec de création conserve les fichiers déjà créés pour diagnostic.

## Boucle quotidienne et revue

```text
/task-plan <objectif et critères d'acceptation>
/task-next <tâche précise>
/task-verify
/task-review <chemin du diff ou référence de tâche>
/task-handoff
```

Ces commandes réutilisent les skills existants. Elles ne lancent pas de shell
par expansion cachée de template. Pour une revue indépendante, préparer le diff
avant de sélectionner le reviewer (celui-ci n'a aucun shell) :

```bash
mkdir -p .dev
git diff --no-ext-diff --no-textconv origin/claude-tooling > .dev/review.patch
git status --short
scripts/dev/check.sh
```

Le diff inclut les changements suivis depuis la base ; **les fichiers non suivis
n'y figurent pas** : les signaler et les joindre/lire séparément avant revue.
Dans le worktree reviewer démarré depuis `ai/navigation`, produire le diff contre
la base d'intégration depuis le shell humain, puis demander de lire
`.dev/review.patch`. Les résultats doivent donner gravité, preuve, chemin:ligne
et distinguer les hypothèses. Ensuite : tests adaptés, passation, puis proposition
de merge. Aucun merge vers `master`/`main`, rebase ou push automatique.

## Sécurité et limites

Les permissions demandent confirmation hors workspace et pour le shell, bloquent
les opérations Git dangereuses usuelles et les lectures de credentials évidentes.
Les fichiers upstream CocoOS sont non éditables par les outils d'édition OpenCode,
y compris les coutures : une exception ne s'ouvre qu'après accord humain.
La politique Git classe les chemins, traite aussi suppressions/renommages et reste
la barrière commune à tous les outils. Exécuter `setup.sh` dans chaque worktree.
Le clone principal n'est pas activé implicitement ; il conserve ses réglages.

**Ce n'est pas une sandbox** : un shell approuvé, un script modifié, un alias Git,
un autre outil ou un humain peut contourner une reconnaissance de commandes.
Ne pas approuver globalement `*`, `bash *`, `python *`, ni utiliser `--auto`.
Les contrôles déterministes + revue/CI sont complémentaires, pas une garantie
contre un utilisateur malveillant. Les motifs de secrets sont heuristiques.

## Contexte et mesure sans chiffres inventés

Une session par objectif ; plan court, recherches ciblées `rg`, lectures partielles,
diffs et skills à la demande. Logs complets dans `.dev/`, extraits pertinents
seulement dans le contexte. Compaction automatique, 12 000 tokens récents conservés,
buffer 16 000 ; sortie outils limitée à 160 lignes/18 000 octets. Ce sont des
paramètres, **pas des économies mesurées**. Ccache et builds incrémentaux restent
activés lorsqu'ils sont disponibles. Pas de nouveau skill de workflow redondant.

Consigner par tâche dans la passation : objectif, modèles, début/fin, itérations
(cycle correction→vérification), commandes et résultats, interventions humaines,
blocages. Relever l'usage **visible** dans OpenCode/chez le fournisseur s'il existe ;
sinon écrire « tokens/coût non disponibles ». Ne pas convertir les tokens visibles
en facture supposée. Comparer des tâches comparables ; aucun pourcentage déduit
d'une seule tâche. Faire une passation puis une nouvelle session pour changer de sujet.

## Continuer à distance

PC Fedora **allumé et joignable**, avec SSH déjà configuré par l'utilisateur :

```bash
ssh marco@<adresse-du-PC>
cd '/chemin/du/worktree'
scripts/dev/tmux-fleet.sh list
scripts/dev/tmux-fleet.sh attach navigation
```

Tmux survit à la fermeture du terminal/SSH, **pas à l'arrêt du PC**, et ne prévient
pas sa veille. Aucun service SSH, pare-feu ou réglage de veille n'est modifié ici.
PC éteint : il faut une autre machine/VM allumée et configurée avec les mêmes
outils, accès et limites d'abonnement ; ce n'est pas du SSH vers le PC éteint.
Un hébergement cloud peut coûter de l'argent : non configuré sans accord.
Claude Agent doit être installé/connecté sur le serveur qui exécute OpenCode.

## Sources officielles

- https://opencode.ai/v2/docs/config
- https://opencode.ai/v2/docs/permissions
- https://opencode.ai/v2/docs/policies (`mcp.use` etc. requièrent 2.3+, non utilisés ici)
- https://opencode.ai/v2/docs/agents
- https://opencode.ai/v2/docs/skills
- https://opencode.ai/v2/docs/commands
- https://opencode.ai/v2/docs/providers
- https://opencode.ai/v2/docs/cli

Le CLI installé et les évaluations serveur priment sur un exemple plus récent.
