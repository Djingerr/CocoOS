---
name: next
description: Enchaîner la prochaine tâche CocoOS de bout en bout — choisir dans next_steps.md, planifier, coder dans app/gui/console, vérifier objectivement, mettre à jour next_steps.md, committer. Invoquer avec /next [tâche optionnelle].
disable-model-invocation: true
argument-hint: "[tâche précise, sinon la prochaine de next_steps.md]"
---

# /next — une tâche, de la sélection au commit

Tâche demandée : $ARGUMENTS (si vide : la prochaine tâche ouverte).

## 1. Choisir
- Lire la **dernière section** de `next_steps.md` (Grep des titres `^## `, puis Read de la plage utile)
  et le §9 de `CLAUDE.md`. Ne pas relire `docs/claude/HISTORY.md` en entier (Grep si besoin).
- Annoncer en une phrase la tâche retenue et le critère de fin vérifiable.
- **S'arrêter et demander** si : la tâche exige du matériel (Orange Pi, écran, manette réelle), un réglage
  au ressenti, une nouvelle couture upstream, ou si next_steps.md mentionne une porte non passée.

## 2. Planifier (court)
- Fichiers à créer / modifier (tous dans `app/gui/console/` sauf coutures listées dans `.claude/seams.txt`).
- Pour comprendre un comportement upstream : sous-agent `upstream-explorer`, pas de lecture massive ici.
- Skill `cocoos-ui` pour toute UI ; `boot-animation`, `cocoos-build` selon le sujet.

## 3. Coder
- Petits Edit ciblés ; jetons dans `Theme.qml` ; textes en `qsTr` ; test `tst_*.qml` pour tout comportement neuf.

## 4. Vérifier (obligatoire avant de dire « fini »)
- Sous-agent `verifier` (build embedded + tests + fumée).
- UI : capture du harnais (skill `ambiant-harness`) regardée avec Read, comparée au prototype si une référence existe.
- Sous-agent `qml-reviewer` sur le diff.
- Texte ajouté/modifié : `scripts/cc/i18n.sh` puis traduire, puis `scripts/cc/i18n.sh --release`.

## 5. Clore
- Mettre à jour `next_steps.md` : ce qui est fait (avec le résultat des vérifications), ce qui reste,
  ce qui attend Marco (manette, ressenti, matériel).
- `git add` des fichiers concernés seulement, commit en français (`console: …`, `idle: …`, `docs: …`).
- **Pas de push** sauf demande explicite. Résumer en 3 lignes : fait / vérifié / reste à valider par Marco.
