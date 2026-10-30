---
name: cocoos-build
description: Compiler CocoOS (qmake6/make, mode embedded vs vanilla), diagnostiquer une erreur de build ou d'exécution, pièges MOC/qmake/rcc/QML connus, dépendances Fedora, logs Qt. À charger dès qu'un build échoue ou avant de toucher app.pro/qml.qrc/main.cpp.
---

# Build CocoOS — référence

## Raccourcis (préférer ces scripts : sortie filtrée, économe en tokens)

```bash
scripts/dev/build.sh              # build embedded (UI console) ; gère le piège subdirs et touch qml.qrc
scripts/dev/build.sh vanilla      # build Moonlight vanilla (doit rester intact)
scripts/dev/build.sh --clean      # make distclean d'abord
scripts/dev/test.sh               # tous les tst_*.qml du harnais (XDG_CONFIG_HOME vierge, offscreen)
scripts/dev/test.sh GameShelf     # un seul test
scripts/dev/smoke.sh 8            # lance ./app/moonlight 8 s hors réseau, ne remonte que les erreurs
scripts/dev/check.sh              # syntaxe shell + régressions outillage isolées (sans SDK)
scripts/dev/check.sh --qml app/gui/console/ButtonGlyph.qml # qmllint Qt6 ciblé
scripts/dev/i18n.sh --check        # lecture seule TS/QM/QRC
```
Log complet du dernier build : `.dev/last-build.log` (ne le lire qu'en cas de besoin, par recherche ciblée, jamais en entier).
Tous les scripts acceptent `--help` sans effet secondaire. Un outil/sous-module absent,
aucun test sélectionné ou isolation `unshare` interdite donne BLOCKED, pas PASS.
La sortie des étapes est conservée intégralement ; un échec qmake/distclean/make arrête
la chaîne sans être masqué. Build embedded et vanilla partagent le même log et binaire :
archiver `.dev/last-build.{log,status}` avant le mode suivant, et revenir en embedded
avant smoke. Ne pas construire simultanément les deux modes dans un même worktree.
Les imports C++ de ConsoleHome ne sont pas tous analysables statiquement : qmllint
les rapporte BLOCKED plutôt que de prétendre à un défaut QML. Voir `docs/ai/QUALITY.md`.

## Comment compiler en mode `embedded` (UI maison)

```bash
qmake6 "CONFIG+=embedded" moonlight-qt.pro && make release -j$(nproc) && ./app/moonlight
```

L'app doit démarrer directement sur `ConsoleHome`. Un `qmake6` sans `embedded` doit
produire le Moonlight vanilla intact.


## Dépendance de build `embedded` : QtWebSockets

Le build `embedded` ajoute `QT += websockets` (WebSocket `/v1/events` du `CompanionClient`).
Sur Fedora, installer **`qt6-qtwebsockets-devel`** (`sudo dnf install -y qt6-qtwebsockets-devel`).
La lib runtime seule (`qt6-qtwebsockets`) ne suffit pas : sans le `-devel` il manque les
en-têtes, le symlink `libQt6WebSockets.so` et le module qmake `qt_lib_websockets.pri`, et
`qmake6` échoue (`Unknown module(s) in QT: websockets`). Le build vanilla n'en a pas besoin
(module dans le scope `embedded` uniquement).


## Piège MOC : les types d'arguments de slots/signaux doivent être COMPLETS (Qt6)

En Qt6, le MOC génère un `QMetaType` pour chaque type d'argument de signal/slot. Un type
seulement **forward-déclaré** (`class Foo;`) qui apparaît dans une signature — même en
`const QList<Foo>&` — fait échouer `moc_*.cpp` : `invalid use of incomplete type 'class Foo'`
(+ erreurs `has_ostream_operator<QDebug, Foo, void>`). Vécu au premier build de `CompanionClient`
sur `onSslErrors(QNetworkReply*, const QList<QSslError>&)` : il a fallu **`#include <QSslError>`**
dans le header au lieu du forward-declare. Règle : tout type figurant dans une signature d'un
`Q_OBJECT` doit être inclus complètement dans le header (seuls les pointeurs `Foo*` tolèrent le
forward-declare).


## Piège qmake `subdirs` (à connaître)

Si un précédent `qmake6` (sans `embedded`) a déjà généré les Makefiles des sous-projets,
relancer `qmake6 "CONFIG+=embedded" moonlight-qt.pro` au niveau racine **ne régénère pas**
les sous-Makefiles — le scope `embedded { ... }` reste inactif et `CONSOLE_UI` n'est pas
défini.

Symptômes : pas de `Project MESSAGE: Embedded build` au qmake, pas de `-DCONSOLE_UI` dans
la ligne `g++ -c ... main.cpp`, l'app démarre sur `PcView` malgré tout.

Deux contournements :
- `make distclean` avant le `qmake6` racine (propre mais recompile tout) ;
- ou régénérer directement le Makefile du sous-projet : `cd app && qmake6 "CONFIG+=embedded" app.pro`
  (rapide, recompile uniquement ce qui dépend du nouveau define).

`scripts/dev/build.sh` applique systématiquement le second : qmake racine **puis app**
dans le mode demandé (`CONFIG+=embedded` ou `CONFIG-=embedded`), vérifie CONSOLE_UI,
puis touche QRC avant make. Objets/MOC/RCC/UI de l'app sont séparés dans
`.dev/build/<mode>/` (make ne suit pas les changements de defines). Les dépendances
communes restent partagées. Il ne déclenche jamais distclean sauf `--clean`.

### Worktree neuf / préparation offline

`scripts/dev/setup.sh` ne fait aucun fetch ni init de sous-module par défaut.
Avec accord réseau explicite : `scripts/dev/setup.sh --submodules` et, séparément,
`--fetch-upstream` (jamais shallow). Aucun téléchargement SDK/sudo automatique.
Setup préserve `.claude/skills`, ne touche pas skip-worktree et ne change pas le
hooksPath commun. Les hooks sont configurés avec `--worktree` seulement après examen
des paramètres communs core.bare/core.worktree ; configuration sensible = BLOCKED,
migration à faire valider. Détails et limites dans `docs/ai/QUALITY.md`.


## Piège ComputerModel/AppModel : initialiser AVANT d'assigner aux vues

`ComputerModel::initialize()` et `AppModel::initialize()` remplissent le modèle **sans
émettre de reset** (`beginResetModel`). Si une vue (ListView, Instantiator…) est liée au
modèle avant l'appel à `initialize()`, elle le considère **vide pour toujours** — symptôme :
« Recherche… » permanent alors que le host est en ligne. Le pattern correct (celui de
`PcView.qml` et de `ConsoleHome.qml`) :

```qml
var m = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
m.initialize(ComputerManager)   // d'abord initialiser…
computerModel = m               // …puis assigner la propriété liée aux vues
```


## Piège AppModel/ComputerModel : pas de propriété `count` en QML

Ces modèles C++ (QAbstractListModel) n'exposent **pas** de `count` : en QML,
`appModel.count` vaut `undefined`, donc `appModel.count > 0` est **toujours faux**
(symptôme : « Chargement de vos jeux… » infini alors que les données sont là).
Pour compter/observer les éléments, passer par un `Instantiator` lié au modèle et
utiliser **son** `count` (vraie propriété notifiée) — pattern des `hostScanner` /
`appViewer` de `ConsoleHome.qml`.


## Propriétés attachées : l'import compte

`StackView.onActivated` & co exigent `import QtQuick.Controls` dans le fichier qui les
utilise. Sans lui : « Non-existent attached object » au push, et la vue ne charge pas.


## Logs Qt invisibles sur Fedora (journald)

Quand stderr n'est pas un TTY, Qt envoie ses logs vers **journald** au lieu de la console
(`qml-qt6` n'affiche alors rien) → les lire avec `journalctl --user`. Le binaire
`moonlight` n'est pas concerné : il installe son propre handler (`qtLogToDiskHandler`)
qui écrit sur stdout. Attention : ce handler **supprime le niveau debug** (`console.log`
QML) — utiliser `console.info` pour qu'une trace QML apparaisse dans le log.


## rcc ne dépend que de `qml.qrc`, pas des `.qml`

Modifier un `.qml` ne suffit pas toujours à régénérer `qrc_qml.cpp` : faire
`touch qml.qrc` avant `make` pour forcer le réembarquement des ressources.


## Dépendances d'exécution de l'UI console

- **QtMultimedia** (module QML) pour les sons : `qt6-qtmultimedia` sur Fedora,
  `qml6-module-qtmultimedia` sur Debian/Ubuntu. Absent, l'interface marche sans son
  (`Sounds.qml` charge `SoundBank.qml` à part). Il faut un serveur de son (PipeWire/PulseAudio)
  pour que ces sons cohabitent avec l'audio du flux. Qt les déclare en rôle PipeWire
  « Notification » (coupé par les « Sons de notification » de Plasma) : `main.cpp` pose
  `PIPEWIRE_PROPS={ media.role = Game }` au démarrage, sauf si la variable existe déjà.
- **NetworkManager** pour l'icône Wi-Fi et le choix du réseau ; sans lui (ou sans Wi-Fi associé)
  l'icône est masquée et la ligne Wi-Fi des options n'apparaît pas. La session de la console
  doit être « active » pour que polkit la laisse créer un profil Wi-Fi et régler la luminosité
  (cas d'une session kiosk en connexion automatique).
- Une batterie système dans `/sys/class/power_supply` pour l'icône batterie ; sinon masquée
  (ce sera le cas du proto sur power bank). Relue toutes les 10 s (l'éclair de charge peut
  mettre ce temps à apparaître).
- Cache du Companion : `QStandardPaths::CacheLocation` + `/companion/` (sous Linux
  `~/.cache/Moonlight Game Streaming Project/Moonlight/companion/`) : `library.json` (dernière
  bibliothèque) et `bg-<sha1>` (images de fond). Il ne fait que grandir : à purger s'il pèse trop.


## Ignorer les artefacts de build sans toucher au `.gitignore` upstream

Le `.gitignore` upstream ne couvre pas les builds in-source de qmake (`Makefile*`,
`release/`, `*.o`, `*.a`, `.qmake.*`, `app/moonlight`, `config.log`…). Plutôt que de le
modifier (cf §4), on les ignore **localement à ce clone** via `.git/info/exclude` — fichier
non versionné, donc à **recréer après un `git clone`**. Contenu :

```
# qmake / make in-source build artifacts
Makefile
Makefile.Debug
Makefile.Release
release/
debug/
.qmake.cache
.qmake.stash

# Object files & static libs
*.o
*.a

# Build outputs / logs
config.log
app/moonlight
config.tests/*/EGL
```
