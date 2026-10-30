---
name: qml-review
description: Relire un diff de l'interface console (app/gui/console) contre les règles CocoOS — jetons Theme.qml, Sora, qsTr, navigation manette, pièges QML connus, stratégie additive. À faire après une modification d'UI, avant de committer.
---

# Revue d'un diff d'UI

Partir de `git diff --stat` puis `git diff` (ou la plage de commits indiquée), limité à ce qui a changé.
Référence : skill `cocoos-ui` (carte des fichiers et pièges QML).
Avec le reviewer OpenCode sans shell, lire le diff préparé dans `.dev/review.patch`
ou fourni par l'appelant ; signaler les fichiers non suivis absents du diff.

Vérifier :
- **Aucune valeur en dur** (couleur, taille, durée, police) hors `Theme.qml` / `IdleTheme.qml`.
- Police Sora uniquement ; aucun élément « bureau » (Material/Controls par défaut visibles, curseur, fenêtre).
- Tout texte affiché en `qsTr("…")` (QML) / `tr("…")` (C++) ; signaler si `qml_en.ts` n'a pas suivi.
- Navigation 100 % manette : focus, `Keys`, retour B, aucune cible atteignable seulement à la souris.
- Pièges connus (modèles initialisés avant assignation, `count` absent des modèles, focus par liaisons,
  `BezierSpline` ≤ 10 segments, `layer.textureSize`, imports des propriétés attachées…).
- Stratégie additive : aucun fichier upstream hors `.agents/seams.txt` ; coutures sous `#ifdef CONSOLE_UI`.
- Nouveau composant ou comportement sans test `tst_*.qml` (`docs/ui/ambiant/harness/` ou `idle/tests/`).

Rapport court : **Bloquant** / **À corriger** / **Suggestions**, chaque point avec `fichier:ligne` et la
correction en une ligne. Rien à redire : le dire en une phrase. Ne modifier aucun fichier pendant la revue.

## Tests ciblés et références Qt

Sélection auditée : `docs/ai/QT-SKILLS.md` (Qt Quick Test, sans migration CMake).
Pour un test neuf : parent visuel dimensionné, `when: windowShown` si entrée,
focus explicite, événements clavier/manette simulés, assertion de résultat après
l'action et `tryCompare`/`tryVerify` plutôt qu'un délai arbitraire. Vérifier le retour
B et le focus après fermeture d'un overlay. Les tests au clavier ne prouvent pas
le comportement d'une vraie manette ni la latence du streaming sur le matériel.
