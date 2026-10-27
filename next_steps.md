# Prochaines étapes

## Écran de veille — reconnaissance (phase 0, 2026-10-27)

Brief : `docs/design/idle/CLAUDE_BRIEF.md`. Branche : `feat/idle-screen` (depuis `console-ui`).

### Versions
| | Poste de dev (Fedora 43) | Image de l'Orange Pi 5B |
|---|---|---|
| Qt | **6.10.3** (`qmake6 -query QT_VERSION`) | **inconnue** : pas d'image installée ni de carte joignable depuis le laptop |

Repères (paquets des distributions, à confirmer sur la carte) : Ubuntu 24.04 et Debian 12 → Qt 6.4.2 ;
Debian 13 → Qt 6.8.

### Modules et outils (poste de dev)
| Élément | État |
|---|---|
| `QtQuick.Effects` (`MultiEffect`, Qt ≥ 6.5) | présent ; déjà utilisé par la console (`SwapBox`, `GameShelf`, `Toast`) |
| `QtQuick.Shapes` | présent ; déjà utilisé (`ButtonGlyph`) |
| `qsb` (Qt Shader Tools) | présent (`/usr/bin/qsb-qt6`) ; la console a déjà `shaders/build-shaders.sh` (SPIR-V + GLSL 100 es / 120 / 150 / 300 es, pour la Mali) |
| `font.features` (Qt ≥ 6.6) | utilisé par 3 fichiers de la console (`tnum`) |
| Qt SVG | présent (`qt6-qtsvg`) ; la console affiche déjà des SVG (`icons/`) |
| `qmllint`, `qmltestrunner` | présents |
| Python : Pillow 11.3, NumPy 2.3 | présents (pour `tools/compare.py`) |

### Existant dans le dépôt
- **Sora** : `app/gui/console/fonts/Sora-{Regular,Medium,SemiBold,Bold}.ttf` (400 à 700, instances
  statiques), chargée par `Theme.qml` (`Theme.fontUi`). Les quatre fichiers ont la fonction `tnum`.
- **Thème** : `app/gui/console/Theme.qml` (singleton, `qmldir`), écrit à la main d'après les prototypes
  (pas synchronisé depuis Figma). Valeurs communes : `accent` `#F2802A` identique, police Sora.
  `textPrimary` de la veille (`#F5F5F7`) diffère de `Theme.ink` (`#F2F0EC`).
- **`ConsoleHome`** : `app/gui/console/ConsoleHome.qml` (logique), `HomeScreen.qml` (présentation).
- **`.qrc`** : la console n'a pas de `.qrc` propre ; ses fichiers sont dans `app/qml.qrc` (70 entrées
  `gui/console/…`), couture déjà admise (CLAUDE.md §4).
- **Manette → interface** : confirmé, `app/gui/sdlgamepadkeynavigation.cpp` envoie des touches :
  croix → flèches, A → `Key_Return` (ou `Key_Space` en mode `UiNavMode`), B → `Key_Escape`,
  X → `Key_Menu`, Y / Start → `Key_Hangup`. Le bouton Home est lu à part par `InputStatus`
  (`homePressed`).
- **Veille déjà en place** : `SleepScreen.qml` (noir, une phrase qui s'efface) après
  `ConsoleUi/sleepMinutes` (5 min par défaut, réglable dans Options › Console), minuterie `idleTimer`
  de `ConsoleHome` réarmée par `InputStatus.activity`. À articuler avec la nouvelle veille en phase 5
  (le brief prévoit 120 s par défaut).
- **Captures** : le rendu `offscreen` de Qt ne fait pas `MultiEffect` ; le harnais de l'accueil capture
  avec un mutter « headless » (`docs/ui/ambiant/harness/shot.sh`). Même méthode prévue en phase 4.

### Choix technique
**Chemin `MultiEffect`** (+ `ShaderEffect` maison précompilé par `qsb` pour la composition du fond).
Raison : l'interface console exige déjà Qt ≥ 6.6 (`font.features`, `MultiEffect`, `FrameAnimation`) ;
l'image de l'Orange Pi devra donc fournir Qt ≥ 6.6 de toute façon, et la veille n'ajoute aucune
exigence. Le repli `Qt5Compat.GraphicalEffects` n'aurait de sens que si toute la console devait
redescendre sous Qt 6.5.

### Porte de la phase 0
✅ **Passée** (2026-10-27, décision de Marco) : on continue sur l'hypothèse « Qt ≥ 6.6 sur la cible »,
déjà imposée par la console ; la version de l'image sera relevée au transfert sur l'Orange Pi, plus tard.

### Décisions de Marco
- La nouvelle veille **remplace** `SleepScreen` (phase 5).
- L'Orange Pi n'est pas un sujet pour le moment (transfert quand le projet sera plus avancé).
