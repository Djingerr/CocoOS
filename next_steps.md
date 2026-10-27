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

## Écran de veille — phase 1, fondations (2026-10-27)

Fichiers (`app/gui/console/idle/`, déclarés dans `app/qml.qrc`) : `IdleTheme.qml` (singleton, `qmldir` ;
accent et police repris de `Theme.qml`), `IdleStatus.qml` (interface du brief, `state` dérivé, `fixedNow`
pour les captures), `IdleStatusMock.qml`, `IdleFormat.js` (SPEC §5, textes en `qsTr`), `mock/IdleMockData.js`,
`assets/` (copie de `docs/design/idle/assets/`), `tests/tst_format.qml`.

Écarts au brief :
- `Format.js` → `IdleFormat.js` (la console a déjà un `Format.js`, un dossier plus haut).
- Mock copié en module JS (`mock/IdleMockData.js`, mêmes données) : QML refuse de lire un `.json` local
  sans `QML_XHR_ALLOW_FILE_READ=1`, ce qui casserait l'aperçu et les tests lancés depuis le disque.
- Formats que la spec ne fixe pas : autonomie au-delà d'1 h arrondie à 10 min (« Environ 3 h 20 ») ;
  débit en Mo/s sans décimale (« 850 Mo/s »), en ko/s en dessous ; « Il y a N h » seulement le même jour.
- Libellé d'un téléchargement `install` (absent des maquettes) : à décider quand il servira.

Outils : `qmllint` à prendre dans `/usr/lib64/qt6/bin/qmllint` (celui de `/usr/bin` est un autre outil,
« qmllint 1.0 », muet).

### Porte de la phase 1
✅ **Passée** : build `embedded` sans erreur ; `/usr/lib64/qt6/bin/qmllint -I .. --max-warnings 0
*.qml tests/*.qml` (depuis `idle/`) sans avertissement ; `tst_format.qml` 14/14
(`QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input app/gui/console/idle/tests/tst_format.qml`).

## Écran de veille — phase 2, composants (2026-10-27)

`idle/components/` : `EntryReveal`, `GaussianBlur`, `BlurredBackdrop` (aussi la lueur de l'écran 12),
`CoverCard`, `StatusIcon`, `StatusLine`, `KeyHint`, `TopRightClock`, `DurationText`, `ProgressRing`,
`HairlineProgress`, `GlassCapsule`, `GradientText`. `idle/shaders/` (`build-shaders.sh`, `.qsb` versionnés) :
`blur` (gaussien séparable), `glowsource`, `backdrop` (pan + saturation + vignettage + grain overlay, un
passage), `card` (coins arrondis, fondu du reflet au sol), `textgradient`. `idle/preview/IdlePreview.qml`
(`--component X`, `--grab-after`, `--grab`) et `preview/grab.sh` (mutter headless : le rendu offscreen
ne fait pas MultiEffect).

Choix et pièges :
- **Flou** : la source est dessinée une fois en basse résolution (12 px de toile par écart type du flou
  CSS), entourée de 4 écarts types de vide (le `filter: blur()` CSS fond les bords vers le transparent),
  floutée par deux passages gaussiens exacts ; seule sa place (pan, pulsation) change ensuite, dans le
  passage de composition.
- **Inclinaison** : `Matrix4x4` = T(c)·P(1400)·Ry·Rx·T(−c), **ligne z mise à zéro** : Qt Quick rogne en
  profondeur tout ce qui sort de z ∈ [−1, 1] (la carte se réduisait à une bande de 30 px).
- Les uniformes d'un `ShaderEffect` ne peuvent pas s'appeler `top` / `bottom` (propriétés de `Item`).
- `grabToImage` du `contentItem` ne contient pas la couleur de la fenêtre : l'aperçu pose un fond noir.
- Le liseré de la jaquette est **extérieur** (`box-shadow 0 0 0 1px` de la maquette) ; la spec dit
  « intérieur », la maquette fait foi.

### Porte de la phase 2
✅ **Passée** : les 12 composants (et la lueur) s'affichent seuls dans `IdlePreview`, journal QML vide
(`grab.sh --component X --grab-after 3000 --grab …`) ; `qmllint --max-warnings 0` sans avertissement ;
build `embedded` OK.

## Écran de veille — phase 3, écrans et machine d'état (2026-10-27)

`idle/IdleScreen.qml` (état → écran, fondu enchaîné 600 ms puis entrée du nouvel écran, grille
1280 × 720 mise à l'échelle avec bandes noires, `IdleTheme.scale`, sortie 320 ms sur toute touche ou un
clic puis `wakeRequested()`). `idle/screens/` : `CoverScreen` (structure commune de 09 à 11 : fond, dérive,
heure, jaquette, colonne, indication), `IdleGameScreen` (09, 10 avec `showDownload`), `IdleDownloadScreen`
(11), `IdleRestScreen` (12), `Eyebrow`, `GameInfo`. `components/IdleText` (texte posé par sa ligne de base
comme Chromium : ascendante et descendante de Sora arrondies au pixel, demi-interligne CSS) et
`components/DriftGroup`. L'aperçu montre l'écran complet par défaut (`--state`, `--no-drift`, touches 1 à 4,
R, B ; toute autre touche fait sortir).

Écarts / décisions :
- Le titre passe sur deux lignes au plus (élision) : un vrai titre long ne doit pas déborder.
- Réseau autre que Wi-Fi (`lte`) : l'item de qualité Wi-Fi (09 à 11) et le segment Wi-Fi de la capsule
  (12) sont masqués (pas de maquette pour la 4G/5G). Batterie absente, ou pas de dernier jeu : leur segment
  de capsule est masqué.
- Libellés `install` provisoires (« Installation de … », « Installation »), pas dans les maquettes.
- Piège : `baseline`, `top`, `bottom` sont des propriétés finales d'`Item` (« Cannot override FINAL
  property ») ; `qmllint` ne le signale pas.

### Porte de la phase 3
✅ **Passée** : les quatre états s'affichent depuis le mock (captures `grab.sh --state …`, journal vide) ;
`tests/tst_idlescreen.qml` 6/6 (écran par état, fondu puis entrée, échelle, sortie au clavier et au clic,
une seule sortie) ; `qmllint` sans avertissement ; build `embedded` OK.
