---
name: cocoos-i18n
description: Mettre à jour la traduction anglaise de l'UI console (lupdate/lrelease, qml_en.ts). À utiliser après tout ajout ou changement de texte affiché (qsTr/tr).
---

Raccourci : `scripts/cc/i18n.sh` (lupdate + compte des chaînes non traduites + lrelease).

## Traduction anglaise : la tenir à jour

Tout texte affiché passe par `qsTr("…")` (QML) ou `tr("…")` (C++ d'une classe `Q_OBJECT` ;
hors classe, une petite struct `Q_DECLARE_TR_FUNCTIONS(Contexte)`, cf `Text::tr` de
`streammenu.cpp` : un `tr()` libre est ignoré par lupdate). Source en français. Puis, depuis `app/` :

```bash
lupdate-qt6 gui/console -source-language fr -target-language en -no-obsolete -ts gui/console/languages/qml_en.ts
# traduire les <translation type="unfinished"> du .ts (Qt Linguist : linguist-qt6, ou à la main)
lrelease-qt6 gui/console/languages/qml_en.ts && touch qml.qrc   # .qm versionné, comme upstream
```

Voir l'interface en anglais dans le harnais : `qml-qt6 --translation ../../../../app/gui/console/languages/qml_en.qm -I stubs Harness.qml -- view=ConsoleHomeDemo do=options,tab`
(`PagesDemo` pose ses textes de démo en dur : ils restent en français).
