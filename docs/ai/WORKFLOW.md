# Travailler vite avec une IA sur CocoOS (Claude Code, Codex/ChatGPT, DeepSeek…)

Guide pour Coco. Vérifié contre la doc Claude Code d'octobre 2026 et les formats ouverts AGENTS.md /
Agent Skills (liens en bas).

## 0. Ce qui est en place dans le repo

### Commun à toutes les IA (la source de vérité)

| Élément | Où | Effet |
|---|---|---|
| Instructions du projet | `AGENTS.md` | lu nativement par Codex, Cursor, Copilot, OpenCode, Aider (via config)… ; Claude Code l'importe via `CLAUDE.md` |
| Skills (format ouvert Agent Skills) | `.agents/skills/<nom>/SKILL.md` | procédures (`next`, `verify`, `qml-review`, `upstream-explore`, `upstream-sync`) et références (`cocoos-ui`, `cocoos-build`, `ambiant-harness`, `cocoos-i18n`, `boot-animation`) |
| Garde-fou additif | `.githooks/pre-commit` + `scripts/dev/upstream-policy.sh` + `.agents/seams.txt` | **refuse au commit** tout fichier upstream hors coutures, et tout commit sur `master`, quelle que soit l'IA |
| Mise en place | `scripts/dev/setup.sh` | active les hooks git, `.git/info/exclude`, remote `upstream`, sous-modules |
| Reprise | `scripts/dev/status.sh` | branche, fichiers modifiés, dernière étape de `next_steps.md`, dernier build |
| Scripts filtrés | `scripts/dev/` | `build.sh`, `test.sh`, `smoke.sh`, `i18n.sh`, `worktree-init.sh`, `tmux-fleet.sh` |
| Contexte long | `docs/ai/HISTORY.md`, `docs/ai/HARDWARE.md` | lus à la demande seulement |

### En plus, propre à Claude Code

| Élément | Où | Effet |
|---|---|---|
| `CLAUDE.md` | racine | `@AGENTS.md` + quelques lignes propres à Claude |
| Skills | `.claude/skills` → lien vers `.agents/skills` | mêmes fichiers ; `/next`, `/upstream-sync` en commandes |
| Sous-agents | `.claude/agents/` | `upstream-explorer` (Haiku), `qml-reviewer` (Sonnet), `verifier` (Haiku) : enveloppes des skills du même nom, contexte séparé |
| Hooks | `.claude/settings.json` | garde **avant** l'édition (même politique que le pre-commit), `setup.sh` + `status.sh` au démarrage, erreurs qmllint après édition QML |
| Barre d'état | `.claude/statusline.sh` | `worktree@branche · modèle · ctx % · build`, alerte « /compact » à 60 % |
| Permissions | `.claude/settings.json` | build/tests/git lecture sans confirmation ; push/rebase/reset sur confirmation ; force-push interdit |

À faire une fois sur le Fedora : `sudo dnf install jq ccache tmux`, puis `scripts/dev/setup.sh`.

## Utiliser une autre IA

| Outil | Ce qu'il lit tout seul | À faire |
|---|---|---|
| **Codex CLI / ChatGPT (agent Codex)** | `AGENTS.md`, `.agents/skills/` | rien |
| **Cursor**, **GitHub Copilot** | `AGENTS.md` | demander « applique le skill X » → il lit `.agents/skills/X/SKILL.md` |
| **Gemini CLI** | `.gemini/settings.json` → `AGENTS.md` | rien |
| **Aider** (DeepSeek, GPT, Claude, local…) | `.aider.conf.yml` → `AGENTS.md` en lecture | `/read .agents/skills/<nom>/SKILL.md` au besoin |
| **OpenCode, Cline, Kilo…** (souvent avec DeepSeek) | `AGENTS.md` en général | sinon : « lis AGENTS.md d'abord » |
| **Chat web sans accès au dépôt** (chat.deepseek.com, chatgpt.com) | rien | coller `AGENTS.md` + le SKILL.md utile + les fichiers concernés |

Ce qui ne dépend d'aucun outil : le pre-commit (garde-fou), les scripts, `next_steps.md` comme journal de
passation. Une IA qui reprend lit `AGENTS.md`, lance `scripts/dev/status.sh`, puis suit le skill `next`.
**Toujours finir une session en mettant `next_steps.md` à jour** : c'est ce qui permet de changer d'IA sans
rien perdre.

Exemple DeepSeek avec Aider : `aider --model deepseek/deepseek-chat` (clé `DEEPSEEK_API_KEY`), puis
« fais la prochaine tâche selon .agents/skills/next/SKILL.md ».

## 1. La boucle de base (une session)

```
/next                       → choisit, planifie, code, vérifie, met à jour next_steps.md, commit
/next fiche jeu : défilement de la description   → idem sur une tâche précise
```
- **Plan mode** (Shift+Tab) avant tout ce qui touche plus de 2-3 fichiers.
- `/effort low` pour le mécanique (traductions, renommages), `/effort high` pour l'archi ou un bug coriace.
- `/clear` entre deux tâches sans lien ; `/compact Garde : …` quand la barre d'état passe 60 %.
- `/rename <nom>` pour retrouver une session ; `claude --resume` pour la reprendre.

## 2. Plusieurs IA en parallèle (tmux + worktrees)

Chaque session travaille dans **son propre worktree** (dossier + branche à part) : aucune collision de fichiers.

```bash
scripts/dev/tmux-fleet.sh idle stream-optim i18n   # 1 fenêtre main + 3 sessions `claude -w <nom>`
scripts/dev/tmux-fleet.sh --tool codex doc         # ou un autre outil, dans .worktrees/doc
scripts/dev/tmux-fleet.sh --tool "aider --model deepseek/deepseek-chat" i18n
# premier build dans un worktree neuf (setup.sh y est déjà lancé) :
scripts/dev/build.sh                               # rapide si ccache est chaud
tmux attach -t cocoos                             # revenir plus tard ; Ctrl-b w pour naviguer
```

Règles qui rendent le parallélisme rentable :
- **Des tâches indépendantes** : pas deux sessions sur le même fichier, et surtout **pas deux sessions sur
  une couture** (`app.pro`, `qml.qrc`, `main.cpp`…) → conflits garantis. `qml.qrc` est le point chaud :
  regrouper les ajouts de fichiers QML dans une seule session, ou les faire à l'intégration.
- **3 sessions max** pour commencer : au-delà, c'est toi qui deviens le goulot (relire, tester à la manette).
- Une fenêtre `main` sert à **intégrer** : `git merge worktree-idle` (ou PR GitHub), puis `verifier`.
- Bons découpages pour CocoOS : UI d'un écran / backend C++ d'un autre / traduction + tests / docs.
- Schéma « écrivain + relecteur » : une session code, une autre lance `qml-reviewer` sur sa branche.

Variante intégrée : `/bg <tâche>` détache une tâche en agent d'arrière-plan (`claude agents` pour les suivre).
Les *agent teams* existent (expérimental, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, mode `tmux`), mais
consomment beaucoup plus de tokens : à réserver à un gros chantier découpable.

## 3. Continuer quand tu n'es pas devant l'écran

| Mode | Ordi fermé/éteint ? | Pour quoi |
|---|---|---|
| **Remote Control** (`claude --rc`, ou `/rc` dans une session) | ordi **allumé** requis | piloter depuis le téléphone une session qui tourne chez toi, avec ton Qt et ton harnais |
| **Session cloud** (`claude --cloud "tâche"`, ou claude.ai/code) | **oui** | tâches sans écran : C++ / logique / docs / HostCompanion ; reprise locale avec `claude --teleport` |
| **Tâche planifiée cloud** (`/schedule`) | **oui** | routines : veille upstream, rapport hebdo, tri d'issues |
| `claude -p` / tmux sur ta machine | ordi allumé requis | lots non interactifs (ex. traduire les chaînes manquantes) |

**Capot fermé mais machine allumée (le plus utile pour CocoOS, car le harnais et Qt ≥ 6.6 sont chez toi)** :
1. Sur secteur, empêcher la veille au rabat : dans `/etc/systemd/logind.conf`,
   `HandleLidSwitchExternalPower=ignore`, puis `sudo systemctl restart systemd-logind`
   (ou ponctuellement : `systemd-inhibit --what=handle-lid-switch:sleep tmux attach -t cocoos`).
2. `scripts/dev/tmux-fleet.sh --rc idle stream-optim` → chaque session est pilotable depuis l'app Claude
   du téléphone ; tmux garde tout vivant si le terminal se ferme.

**Limite des sessions cloud** : l'environnement cloud est un Ubuntu générique. Son Qt (6.4 via apt) est
trop vieux pour la console (Qt ≥ 6.6 requis, cf. `next_steps.md`). Le build `embedded` et les tests QML n'y
passeront pas sans installer un Qt récent (ex. `pip install aqtinstall` puis `aqt install-qt linux desktop 6.8.3`
dans le script d'environnement). Donc : cloud pour le C++ hors UI, l'analyse, la doc et HostCompanion ;
local (ou Remote Control) pour l'UI.

Idées de tâches planifiées (cloud, sans build) :
- chaque lundi : « liste les commits moonlight-qt depuis la dernière synchro qui touchent un fichier de
  `.agents/seams.txt` et ouvre une issue récapitulative » ;
- chaque soir : « relis les commits du jour sur console-ui avec les règles de qml-reviewer et poste un
  commentaire de revue ».

## 4. MCP : peu, mais les bons

Chaque serveur MCP ajoute des définitions d'outils au contexte : n'activer que ce qui sert **dans ce repo**.
- **Figma** (design → QML) : `claude plugin install figma@claude-plugins-official`, ou à la main
  `claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp`, puis `/mcp` → Authenticate.
  Le désactiver (`/mcp`) dans les sessions qui ne font pas de design.
- **GitHub** : pas de MCP, le CLI `gh` suffit (moins de tokens) et il est déjà autorisé en lecture.
- Mesurer : `/context` montre ce que coûtent les outils MCP. Si un serveur pèse lourd et sert peu, le couper.

## 5. HostCompanion

Même outillage, adapté au .NET et à la règle no-fork : voir `HostCompanion/docs/ai/WORKFLOW.md`.
Garder les deux repos côte à côte (`~/dev/CocoOS`, `~/dev/HostCompanion`) : `AGENTS.md` de chaque côté
renvoie à l'autre, et un changement de protocole se fait dans les deux (`docs/protocol.md` d'abord).

## Sources
- Hooks : https://code.claude.com/docs/en/hooks
- Sous-agents : https://code.claude.com/docs/en/sub-agents
- Skills : https://code.claude.com/docs/en/skills
- Permissions : https://code.claude.com/docs/en/permissions
- Worktrees : https://code.claude.com/docs/en/worktrees — Agent teams : https://code.claude.com/docs/en/agent-teams
- Remote Control : https://code.claude.com/docs/en/remote-control
- Sessions cloud / teleport : https://code.claude.com/docs/en/claude-code-on-the-web
- Tâches planifiées : https://code.claude.com/docs/en/routines
- Barre d'état : https://code.claude.com/docs/en/statusline — Effort : https://code.claude.com/docs/en/model-config
- Figma MCP : https://developers.figma.com/docs/figma-mcp-server/remote-server-installation
- Portabilité AGENTS.md / CLAUDE.md : https://codex.danielvaughan.com/2026/05/27/agent-instruction-files-agents-md-claude-md-cross-tool-portability-codex-cli/
- Format ouvert Agent Skills : https://codex.danielvaughan.com/2026/05/05/agent-skills-open-standard-portable-skills-codex-cli-cross-agent/
