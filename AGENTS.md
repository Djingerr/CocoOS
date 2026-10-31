# CocoOS — instructions communes à toutes les IA

Console portable de streaming, fork GPLv3 de moonlight-qt. Objectif : « j'allume,
je joue », sans bureau Linux visible ; le PC rend les jeux. Répondre en français.

## Contraintes non négociables

- Couche maison dans `app/gui/console/`. **Additive-only sur les coutures upstream**,
  minuscules et sous `CONSOLE_UI` / `embedded` ; vanilla inchangé. Garder **qmake**.
- Avant toute édition hors couche maison : `scripts/dev/upstream-policy.sh <fichier>`.
  `upstream` / `forbidden` : interdit ; `seam` / `guard` : accord humain préalable.
  Ne pas toucher `app/gui/main.qml`, les tiers, ni coder sur `master` (miroir upstream).
- Montrer les diffs proposés avant application. Préserver tout travail existant.
  Aucun push, merge, reset destructif, contournement de hooks (`--no-verify`) ou
  installation système sans accord. Aucune dépense API/fallback payant implicite.
- Ne lire ni copier secrets, credentials ou conversations privées dans la mémoire.
- UX Ambiant : 100 % manette, Sora, jetons `Theme.qml`, chaînes `qsTr` ; consulter
  `cocoos-ui` avant toute UI. GPLv3 ; produit hardware + service, pas de fermeture du fork.
- Companion connecté : `POST /v1/launch` → `READY` avant Moonlight ; repli Apollo
  seulement si Companion absent. Contrat canonique : **HostCompanion `docs/protocol.md`**.
  Demander le chemin du bon worktree frère ; ne jamais présumer sa branche intégrée.

## Reprendre une session (tout modèle / CLI)

1. Depuis le worktree demandé : `python3 scripts/dev/memory.py resume`.
   Lecture seule : identité Git, ces instructions, bloc courant de `next_steps.md`,
   `docs/ai/HANDOFF.md`, éventuelle passation locale, commits et état Git.
2. Vérifier branche/portée/date ; une passation d'une autre branche est du contexte,
   pas la tâche locale. Examiner les diffs ciblés **sans secrets**, index et non-index,
   et les fichiers non suivis pertinents sans les écraser.
3. Lire seulement les sections de roadmap et skills nécessaires ; résumer fait,
   tâche en cours, blocages et prochaine action. Continuer la demande sans refaire l'existant.
4. Fin de tâche : lire `.agents/skills/session-memory/SKILL.md`, actualiser la
   roadmap et la passation avec des preuves. Code écrit ≠ validé. **PASS / FAIL /
   BLOCKED / NON EXÉCUTÉ** ; tests Linux ≠ manette, Orange Pi ou E2E Companion.

## Sources et commandes

| Besoin | Source canonique |
|---|---|
| Direction / progression | `next_steps.md` (bloc courant en tête ; historique conservé) |
| Dernière passation de branche | `docs/ai/HANDOFF.md` |
| Guide quotidien / worktrees | `docs/ai/MEMORY.md` |
| Décisions | `docs/ai/decisions/README.md` ; ancien historique `docs/ai/HISTORY.md` |
| Architecture détaillée / anciens §N | `docs/ai/PROJECT-REFERENCE.md` (sections utiles seulement) |
| Procédures spécialisées | `.agents/skills/<id>/SKILL.md` ; index détaillé dans la référence |
| Qualité / outillage / flotte | `docs/ai/QUALITY.md`, `OPENCODE.md`, `WORKFLOW.md` |
| Cockpit quotidien / audit / téléphone | `docs/ai/COCKPIT.md`, `docs/ai/ENVIRONMENT-AUDIT.md` |
| Matériel / flux | `docs/ai/HARDWARE.md`, `docs/stream/STREAM-OPTIMISATION.md` |

Setup explicite une fois/worktree : `scripts/dev/setup.sh` (hors ligne par défaut).
Validation : `scripts/dev/check.sh`, `scripts/dev/build.sh embedded`,
`scripts/dev/build.sh vanilla`, `scripts/dev/test.sh`, `scripts/dev/smoke.sh 3` ;
skill `verify` et capture regardée pour l'UI, `scripts/dev/i18n.sh` pour les textes.
Mémoire : `python3 scripts/dev/memory.py check` ; tests :
`python3 scripts/dev/test_memory.py`. Aucun script mémoire ne modifie la roadmap.

Un agent écrivain par worktree ; passation locale via `memory.py local-path`,
dans le répertoire Git **propre au worktree**. Un intégrateur désigné consolide
roadmap/ADR/HANDOFF après intégration autorisée ; rien n'est synchronisé entre branches.
