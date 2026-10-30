# Industrialisation IA — CocoOS — 2026-10-30

## A. État initial et isolation

Clone principal : branche `feat/cocoos-ui`, HEAD `407355e5`. Non suivis préservés :
`STREAM-OPTIMISATION.md`, `optimisation-flux.patch`, `readme-english.patch`.
Remotes : origin Djingerr/CocoOS et upstream moonlight-stream/moonlight-qt.
`claude-tooling` existait sur origin mais pas dans les références locales ; fetch
ciblé sans tags, aucun push. Base outillage : `9188d78b`.

Branche créée : `tooling/opencode-industrialisation`, dans
`.ai-worktrees/CocoOS-tooling` depuis le parent des clones (chemin réel :
`/home/marco/Documents/Projets/CONSOLE DIY/.ai-worktrees/CocoOS-tooling`).
Le clone principal n'a été ni checkout, réinitialisé, nettoyé, mergé ni modifié.

Existant conservé : règles/skills communs, adaptations Claude, hooks, scripts
filtrés, qmake, tests/harness QML et CI upstream. Pas de changement métier,
couture, version tierce ou système de build.

## B. Fondations et productivité

- `opencode.json` V2 natif : six rôles, cinq commandes, permissions, whitelist
  openai/claude-agent, compaction, warming désactivé et sorties bornées.
- `scripts/dev/opencode-check.py` : contrôle des rôles/modèles/skills/commandes
  effectivement chargés et tests de permissions serveur sans appel LLM.
  Les réponses API volumineuses sont capturées dans un fichier temporaire privé :
  le CLI 2.2.4 peut tronquer son JSON sur un pipe (défaut reproduit et détecté).
- `scripts/dev/{tmux-fleet.sh,fleet.py,fleet-test.py}` : un worktree/branche/session
  par tâche, argv échappés, choix de dépôt/modèle, limite entre dépôts frères,
  inspection, arrêt et nettoyage sur confirmation ; aucune intégration automatique.
- `AGENTS.md` allégé par retrait de contexte obsolète/redondant ; règles conservées.
  Guides `OPENCODE.md`, `QUALITY.md`, `QT-SKILLS.md`, liens `WORKFLOW.md` et skill
  `qml-review` actualisés. Pas de nouveau skill redondant de workflow/token.

## C. Qualité et sécurité

Hook fail-closed : suppressions/renommages upstream compris, coutures additives,
gardes sensibles, master protégé. Liste de coutures inchangée. La revue du scope
CONSOLE_UI/embedded reste humaine ; un hook n'est pas une sandbox.

Setup hors ligne, réseau sur option explicite, skills préservés et hooks locaux
au worktree. Le drapeau Git commun `extensions.worktreeConfig` est activé après
examen des paramètres sensibles ; le hooksPath du clone principal reste absent.
Seules des exclusions d'artefacts sont partagées via `info/exclude`.

qmake et étapes intermédiaires propagent leurs erreurs ; objets/MOC/RCC/UI séparés
par mode dans `.dev/build/`. Ccache réutilisé, aucune installation. Traductions
vérifiables sans réécriture. Smoke isolé du réseau, sans fallback connecté.
CI `tooling.yml` ajoutée sans modifier les workflows upstream de compilation.

## D. Vérifications réellement exécutées

| Commande / contrôle | Résultat |
|---|---|
| `opencode --version`, `/api/info` | CLI et serveur 2.2.4 |
| `opencode auth list` | OpenAI et Claude Agent enregistrés ; aucun credential lu |
| `claude --version`, `claude auth status` | 2.1.314, connexion claude.ai / abonnement Pro |
| Inférence `openai/gpt-6.1-sol` | PASS : CONNECTION_OK |
| Inférence `openai/gpt-6-luna` | PASS : CONNECTION_OK |
| Inférence `openai/gpt-5.5` | FAIL : catalogue listé mais modèle non supporté avec ce compte ChatGPT ; exclu des rôles |
| Inférence Claude Agent Haiku | BLOCKED : quota hebdomadaire, rétablissement annoncé 2026-11-02 01:00 Europe/Paris ; aucun fallback payant |
| `python3 scripts/dev/opencode-check.py --permissions` | PASS : 6 rôles, 10 skills canoniques, 5 commandes, 19 évaluations synthétiques |
| Chargement réel du skill `verify` par explorer/Luna | PASS : appel outil skill observé, commande CocoOS correcte ; aucun build/édition demandé à ce test |
| `python3 scripts/dev/fleet-test.py` | PASS : 8 scénarios avec vrais Git/worktrees/tmux et faux OpenCode sans inférence, aucun skip |
| `scripts/dev/check.sh` | PASS : syntaxe Bash et 59 tests d'outillage/hooks dans des dépôts temporaires |
| `scripts/dev/build.sh vanilla` puis `embedded` | PASS réels ; retours incrémentaux 6 s / 6 s au contrôle parent, pas une mesure comparative de performance |
| `scripts/dev/test.sh` | PASS : 17/17 suites QML, logs individuels |
| `scripts/dev/smoke.sh 8` | PASS : timeout attendu, marqueur console, réseau isolé |
| `scripts/dev/check.sh --qml app/gui/console/ButtonGlyph.qml app/gui/console/CheckMark.qml app/gui/console/ElasticIndicator.qml` | PASS : 3 fichiers, 29 avis non bloquants conservés |
| Même contrôle sur `ConsoleHome.qml` | BLOCKED : imports C++ enregistrés runtime, pas un PASS sémantique |
| `scripts/dev/i18n.sh --check` | PASS : 368 chaînes, zéro unfinished ; pas de changement TS/QM/QRC |

Les premiers builds de ce worktree ont aussi réussi (vanilla 31 s, embedded
21 s, constat agent de vérification, ccache disponible, pas un benchmark à froid) ;
ne pas en déduire de gain reproductible.
Logs détaillés locaux dans `.dev/`. Le build touche l'horodatage QRC sans changer
son contenu ; vérifier le diff, pas seulement la date.

Revue indépendante : huit défauts corrigés avant livraison (modes indexés des hooks,
configs Git dormantes, wrapper exécutable, temporaires, exclusions, crash qmllint,
bump SDK HostCompanion et status). Tests ajoutés ; les temporaires restent utilisables
sans `/tmp/opencode`. L'aide de tous les scripts Bash a été exécutée hors dépôt.
Les quatre scripts flotte/contrôle OpenCode sont identiques dans les deux projets.
La découverte des définitions a aussi été vérifiée depuis `scripts/dev/`.
Contre-revue en lecture seule : **8/8 constats résolus**, aucun nouveau P1/P2
certain dans le périmètre examiné. Hook exécuté sur le vrai index préparé : PASS.
Scan heuristique des **29 blobs indexés** : aucun binaire ou secret évident
détecté ; contrôle non exhaustif, sans afficher les valeurs. Diff whitespace : PASS.

## E. Limites, coûts et reprise

- **P1** : Claude authentifié mais quota épuisé. Les rôles opérationnels utilisent
  Sol/Luna déjà connectés ; Claude reste sélectionnable après rétablissement.
- **P1** : manette, Orange Pi, décodage/latence du streaming et E2E HostCompanion
  non testés ici. Les tests offscreen ne les remplacent pas.
- **P2** : analyse statique QML complète bloquée sur les types C++ runtime ; garder
  tests runtime/build et revue ciblée plutôt que prétendre un qmllint intégral vert.
- CI ajoutée mais non exécutée sur GitHub ; aucun push ni release.
- Aucun SDK/plugin/MCP/fournisseur payant installé, aucune clé lue/écrite, aucun
  coût ou pourcentage d'économie inventé. Inferences de connexion effectuées dans
  les routes d'abonnement existantes uniquement.

Utilisation et protocole de mesure : `docs/ai/OPENCODE.md`. Prochaine tâche
concrète après revue de l'outillage : préparer la validation manette/Companion sur
deux appareils avec le host de test Windows, jamais sur « djing ».
