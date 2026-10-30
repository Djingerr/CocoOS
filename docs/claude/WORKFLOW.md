# Travailler vite avec Claude Code sur CocoOS

Guide pour Coco. Vérifié contre la doc Claude Code d'octobre 2026 (liens en bas).

## 0. Ce qui est déjà en place dans le repo

| Élément | Où | Effet |
|---|---|---|
| `CLAUDE.md` allégé (90 Ko → ~19 Ko) | racine | ~17K tokens de moins **à chaque tour** ; le détail est chargé à la demande |
| Skills | `.claude/skills/` | `cocoos-ui`, `cocoos-build`, `ambiant-harness`, `cocoos-i18n`, `boot-animation` (auto) ; `/next`, `/upstream-sync` (manuels) |
| Sous-agents | `.claude/agents/` | `upstream-explorer` (Haiku, lecture seule), `qml-reviewer` (Sonnet), `verifier` (Haiku) |
| Garde upstream | `.claude/hooks/upstream-guard.sh` + `.claude/seams.txt` | refuse les fichiers upstream hors coutures, demande pour les coutures, bloque `main.qml` et la branche `master` |
| Démarrage de session | `.claude/hooks/session-start.sh` | recrée `.git/info/exclude`, ajoute le remote `upstream`, donne branche / fichiers modifiés / dernière étape |
| Contrôle QML | `.claude/hooks/qml-check.sh` | après chaque édition de `.qml`, renvoie à Claude les **erreurs** de qmllint (pas les warnings) |
| Scripts filtrés | `scripts/cc/` | `build.sh`, `test.sh`, `smoke.sh`, `i18n.sh`, `worktree-init.sh`, `tmux-fleet.sh` |
| Barre d'état | `.claude/statusline.sh` | `worktree@branche · modèle · ctx % · build OK/FAILED`, alerte « /compact » à 60 % |
| Permissions | `.claude/settings.json` | build/tests/git en lecture sans confirmation ; push/rebase/reset sur confirmation ; force-push interdit ; sous-modules non lus |

À faire une fois sur le Fedora : `sudo dnf install jq ccache tmux` (jq est requis par les hooks ; ccache
divise les temps de recompilation, surtout avec plusieurs worktrees).

## 1. La boucle de base (une session)

```
/next                       → choisit, planifie, code, vérifie, met à jour next_steps.md, commit
/next fiche jeu : défilement de la description   → idem sur une tâche précise
```
- **Plan mode** (Shift+Tab) avant tout ce qui touche plus de 2-3 fichiers.
- `/effort low` pour le mécanique (traductions, renommages), `/effort high` pour l'archi ou un bug coriace.
- `/clear` entre deux tâches sans lien ; `/compact Garde : …` quand la barre d'état passe 60 %.
- `/rename <nom>` pour retrouver une session ; `claude --resume` pour la reprendre.

## 2. Plusieurs Claude en parallèle (tmux + worktrees)

Chaque session travaille dans **son propre worktree** (dossier + branche à part) : aucune collision de fichiers.

```bash
scripts/cc/tmux-fleet.sh idle stream-optim i18n   # 1 fenêtre main + 3 sessions `claude -w <nom>`
# dans chaque nouvelle fenêtre, la 1re fois :
scripts/cc/worktree-init.sh                       # sous-modules + premier build (rapide avec ccache)
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
2. `scripts/cc/tmux-fleet.sh --rc idle stream-optim` → chaque session est pilotable depuis l'app Claude
   du téléphone ; tmux garde tout vivant si le terminal se ferme.

**Limite des sessions cloud** : l'environnement cloud est un Ubuntu générique. Son Qt (6.4 via apt) est
trop vieux pour la console (Qt ≥ 6.6 requis, cf. `next_steps.md`). Le build `embedded` et les tests QML n'y
passeront pas sans installer un Qt récent (ex. `pip install aqtinstall` puis `aqt install-qt linux desktop 6.8.3`
dans le script d'environnement). Donc : cloud pour le C++ hors UI, l'analyse, la doc et HostCompanion ;
local (ou Remote Control) pour l'UI.

Idées de tâches planifiées (cloud, sans build) :
- chaque lundi : « liste les commits moonlight-qt depuis la dernière synchro qui touchent un fichier de
  `.claude/seams.txt` et ouvre une issue récapitulative » ;
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

Ce dépôt n'était pas accessible depuis la session qui a préparé cet outillage. Pour lui appliquer le même
traitement : même découpage (CLAUDE.md court + skills + `scripts/cc/` filtrés + sous-agent `verifier`), avec
une garde **no-fork** à la place de la garde upstream (refuser toute édition dans un répertoire vendored
d'Apollo / Playnite ; versions épinglées dans le lockfile seulement).
Côté console, `CLAUDE.md` renvoie déjà à `../HostCompanion/CLAUDE.md` : garder les deux repos côte à côte
(`~/dev/CocoOS`, `~/dev/HostCompanion`) pour qu'une session puisse lire le contrat d'API de l'autre.

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
