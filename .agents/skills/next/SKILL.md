---
name: next
description: Enchaîner la prochaine tâche CocoOS de bout en bout — choisir dans next_steps.md, planifier, coder dans app/gui/console, vérifier objectivement, mettre à jour next_steps.md, committer. Sous Claude Code /next [tâche] ; avec une autre IA, demander « fais la prochaine tâche selon .agents/skills/next/SKILL.md ».
disable-model-invocation: true
argument-hint: "[tâche précise, sinon la prochaine de next_steps.md]"
---

# next — une tâche, de la sélection au commit

Tâche demandée : celle que l'utilisateur a donnée (sous Claude Code : $ARGUMENTS) ; si aucune, la
prochaine tâche ouverte.

## 1. Choisir
- Suivre la Reprise de `session-memory` : bloc courant de `next_steps.md`, HANDOFF et Git.
  Ancien §9 : `docs/ai/PROJECT-REFERENCE.md`, seulement si pertinent. Pas de lecture intégrale d'HISTORY.
- Annoncer en une phrase la tâche retenue et le critère de fin vérifiable.
- **S'arrêter et demander** si : la tâche exige du matériel (Orange Pi, écran, manette réelle), un réglage
  au ressenti, une nouvelle couture upstream, ou si next_steps.md mentionne une porte non passée.

## 2. Planifier (court)
- Fichiers à créer / modifier (tous dans `app/gui/console/` sauf coutures listées dans `.agents/seams.txt`).
- Pour comprendre un comportement upstream : skill `upstream-explore` (dans un sous-agent si ton outil
  en a, pour garder le contexte principal propre).
- Skill `cocoos-ui` pour toute UI ; `boot-animation`, `cocoos-build` selon le sujet.

## 3. Coder
- Petites modifications ciblées plutôt que des réécritures ; jetons dans `Theme.qml` ; textes en `qsTr` ;
  test `tst_*.qml` pour tout comportement neuf.

## 4. Vérifier (obligatoire avant de dire « fini »)
- Skill `verify` (build embedded + tests + fumée).
- UI : capture du harnais (skill `ambiant-harness`), regardée, comparée au prototype si une référence existe.
- Skill `qml-review` sur le diff.
- Texte ajouté/modifié : `scripts/dev/i18n.sh`, traduire, puis `scripts/dev/i18n.sh --release`.

## 5. Clore
- Appliquer la Passation de `.agents/skills/session-memory/SKILL.md` avant interruption/fin ;
  sous OpenCode, rappeler `/task-handoff` si elle n'est pas persistée. Canonique ou locale selon portée.
- Mettre à jour `next_steps.md` : ce qui est fait (avec le résultat des vérifications), ce qui reste,
  ce qui attend Marco (manette, ressenti, matériel).
- `git add` des fichiers concernés seulement, commit en français (`console: …`, `idle: …`, `docs: …`).
  Le hook git `pre-commit` refuse les fichiers upstream hors coutures : ne pas le contourner.
- **Pas de push** sauf demande explicite. Résumer en 3 lignes : fait / vérifié / reste à valider par Marco.
