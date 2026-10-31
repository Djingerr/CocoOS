# Mémoire universelle — rapport de validation (2026-10-31)

## Livré et conservé

Branche locale `tooling/universal-memory`, worktree `.ai-worktrees/CocoOS-memory`
dans le parent des clones. Base `230e5aa5` (industrialisation existante), pas de
push/merge. La mémoire n'est donc **pas encore dans le clone produit**.

Conservés : roadmap `next_steps.md` (historique complet), skills existants, lien
`.claude/skills` vers `.agents/skills` sous Linux, `.opencode/`, flotte tmux,
six rôles/modèles/permissions, build qmake, hooks Git et garde-fous upstream.
Les anciennes sections AGENTS §0 à la fin sont conservées **à l'identique** dans
`PROJECT-REFERENCE.md` ; anciens renvois §N toujours interprétables. Aucun fichier
métier `app/`, tiers, couture, protocole ou hook Git modifié.

Ajoutés : `HANDOFF.md`, `MEMORY.md`, ce rapport, index ADR + décision majeure mémoire,
skill `session-memory`, scripts `memory.py` et `test_memory.py` autonomes.
Modifiés : AGENTS réduit de 312 à **59 lignes**, CLAUDE, bloc courant de la roadmap,
skill `next`, OpenCode (`instructions`, `/task-resume`, `/task-handoff`, rappel next),
hook **Claude** SessionStart (lecture seule, plus de setup implicite), status, guide
OpenCode et CI d'outillage (étape mémoire). Le lien skills n'est pas remplacé.

## Fonctionnement

AGENTS = règles ; roadmap = direction/statuts ; HANDOFF = dernière session de sa
branche ; ADR = décisions majeures ; Git = historique. `resume` charge seulement
AGENTS, bloc courant et passation, puis résumés Git. Aucun chargement intégral des
archives/skills. HANDOFF <100 lignes ; règles des deux projets restent distinctes.

Passation : l'agent examine diff indexé/non indexé et non-suivis ciblés, consigne
les preuves, actualise roadmap et HANDOFF. Le générateur fournit une trame marquée
NON EXÉCUTÉ/TODO, jamais un verdict inféré du code. `check` ne valide que la structure.
`/task-resume` et `/task-handoff` ne sélectionnent ni rôle ni modèle différent.

Un écrivain par worktree ; locale dans son **git-dir propre**, création exclusive.
Projet/branche contrôlés ; une locale étrangère n'est pas chargée. Un intégrateur
réconcilie les documents après intégration humaine autorisée. Les commits d'une
branche ne modifient pas les autres ; la locale ne voyage pas vers une autre machine.
Deux roadmaps, contrat unique HostCompanion `docs/protocol.md` inchangé ; ADR mémoire
homologue dans HostCompanion, base `1e7220e`, pas de dépendance runtime nouvelle.

## Vérifications réellement exécutées sous Fedora

| Commande / contrôle | Résultat et portée |
|---|---|
| `python3 scripts/dev/test_memory.py` | **22/22 PASS**, code 0, dépôts temporaires |
| `scripts/dev/check.sh` | PASS : syntaxe shell et **59 tests outillage** |
| `python3 scripts/dev/opencode-check.py --permissions` | PASS serveur **2.2.4**, 11 skills canoniques, 6 commandes, **19 permissions** synthétiques ; aucun appel LLM |
| Même checker depuis `scripts/dev/tests/` | PASS découverte imbriquée ; pas de nouvelle évaluation permissions pour cet appel |
| `python3 scripts/dev/memory.py check` | PASS structure de la passation finale, code 0 ; pas une certification des faits |
| `memory.py resume` et hook SessionStart lancé directement | PASS sur le vrai worktree ; comparaison des fichiers suivis/status avant-après inchangée |
| Ancien AGENTS vs référence | PASS comparaison exacte §0→fin |
| Git diff base sur métier/tiers/coutures/protocole/hooks Git | Vide, code 0 |
| Scripts/skill/guide communs comparés entre dépôts | Identiques ; copies autonomes, pas de dépendance au dossier frère |

Scénarios : reprise même dépôt et sous-dossier, nouveau processus à contexte réduit,
modification fictive avec passation, index/non-index/non-suivis préservés, tests
non exécutés non inventés, deux worktrees avec marqueurs locaux réciproques,
commit propre à une branche non visible dans l'autre, changement de branche,
passation du mauvais projet, documents symboliques refusés, filtre Git piège non exécuté.
Snapshots de tous les fichiers des fixtures, y compris `.git`, comparés.

Reprise **par une session IA indépendante à contexte réduit** effectuée sur les deux
worktrees : règles et prochaine tâche retrouvées sans historique de chat. Elle a
trouvé trois améliorations : neutralisation des filtres Git, contrôle du projet
canonique au démarrage, assertions d'isolation renforcées. Corrections couvertes
par la passe finale 22/22 ; ce n'est **pas un test d'un autre fournisseur**.
Contre-revue : les trois findings sont confirmés résolus ; reprise finale des deux
projets réussie. Logs locaux : `.dev/last-memory-test.log`, `.dev/last-tooling-test.log`
et `.dev/memory-permissions.log` (non versionnés ; les résultats ci-dessus restent suivis).

## Compatibilité et limites honnêtes

- Versions lues : OpenCode 2.2.4, Claude Code 2.1.314, Codex 0.164.0.
- OpenCode : découverte et permissions testées réellement ; conventions V2 officielles
  pour AGENTS/instructions. Le catalogue `/api/command` ne retourne que nom/description :
  une tentative de vérifier les templates par cette API ne peut pas les valider.
  Templates vérifiés statiquement ; slash commands non soumises à un fournisseur.
- Claude : import `@AGENTS.md` et hook configurés, script hook testé directement ;
  **pas de session Claude exécutée**, pas de quota consommé ni de chargement revendiqué.
- Codex : convention AGENTS documentée, CLI/version présents ; **pas de session Codex**.
- DeepSeek/Kimi/Gemini : Markdown accessible et reprise explicite documentée ;
  **aucun essai fournisseur**. Whitelist/cost controls conservés, pas d'ajout automatique.
- CI configurée, **non exécutée sur GitHub**. Pas de nouveau build Qt, test QML,
  Windows, matériel, manette ou E2E : aucune fonctionnalité métier modifiée.
- Pas de garantie d'obéissance d'un modèle. Pas de récupération de contenu de secrets ;
  Git calcule ses métadonnées à partir des fichiers suivis. Filtres/fsmonitor neutralisés,
  sous-modules ignorés : état filtré indicatif, pas une sandbox de dépôt hostile.

## Usage et suite

```bash
python3 scripts/dev/memory.py resume
python3 scripts/dev/memory.py handoff
python3 scripts/dev/memory.py check
python3 scripts/dev/memory.py local-path
python3 scripts/dev/memory.py handoff --save-local
python3 scripts/dev/memory.py check --local
```

OpenCode : `/task-resume`, puis demande de travail, puis `/task-handoff`.
Tout CLI : lire/appliquer `.agents/skills/session-memory/SKILL.md`.
Guide complet et recherche ADR : `MEMORY.md` et `decisions/README.md`.

Prochaine amélioration : intégration Git revue et **autorisée** vers les branches
utilisées au quotidien, puis essai réel d'un second CLI sur abonnement/quota autorisé.
Ne pas lancer un merge ni un fournisseur automatiquement pour terminer ce rapport.
