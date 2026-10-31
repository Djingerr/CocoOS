# Prochaines étapes

<!-- memory:current:start -->
## État courant — 2026-10-31

Portée : `tooling/environment-finalisation`, déployée par fast-forwards autorisés dans les branches ai/* ; clone principal inchangé.
Statuts : À faire / En cours / Terminée (preuve requise) / Bloquée / À vérifier.

| Chantier | Statut | Preuve / prochaine porte |
|---|---|---|
| Industrialisation OpenCode | Terminée localement | `230e5aa5`, preuves `docs/ai/TOOLING-REPORT.md` ; CI non exécutée |
| Mémoire universelle | Terminée localement | 22 tests mémoire PASS ; `docs/ai/MEMORY-REPORT.md` ; autres CLI/fournisseurs non éprouvés |
| Cockpit console-diy | Terminée, mise en service | 13 tests + --verify/réouvertures PASS ; --check signale SDK/plugin BLOCKED ; `docs/ai/ENVIRONMENT-AUDIT.md` |
| Build/tests Fedora | À vérifier pour la stabilité | Embedded/smoke PASS sur tooling ; dernière passe QML 17/17 PASS, premier passage test_9o en échec puis timeout |
| Plugin sous-agents / téléphone | Bloquée | Dépendances plugin incompatibles ; SSH arrêté ; aucune exposition distante activée |
| Companion E2E + manette | Bloquée | Deux appareils simultanés, dont host Windows ; pas validé par Fedora |
| Veille/netteté/format | À vérifier sur matériel | Code/tests historiques ci-dessous ; 60 fps, manette, Orange Pi non prouvés |
| Kiosk et décodage RK3588S | À faire | Carte puis mesures réelles ; pas de nouvelle couture sans accord |
| Optimisation du flux | À vérifier | Phases/gates dans `docs/stream/STREAM-OPTIMISATION.md` ; audit d'abord |

Prochaine action environnement : décider SDK Windows/plugin compatible et activer SSH/Tailscale uniquement après accord ; guide COCKPIT.md.
Prochaine action produit : organiser la validation croisée à deux appareils, sans refaire l'UI.
Décisions : `docs/ai/decisions/README.md`. Dernière passation : `docs/ai/HANDOFF.md`.
L'historique ci-dessous est conservé ; il ne prouve pas l'état des autres branches.
<!-- memory:current:end -->

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

## Écran de veille — phase 4, parité visuelle (2026-10-27)

Outils : `idle/preview/parity.sh [ms] [final|entree]` capture les quatre états (`grab.sh`, mutter headless,
`--now 2026-10-27T21:46:00 --no-drift`), lance `docs/design/idle/tools/compare.py` et, pour la finale,
`idle/preview/layout_check.py` (boîte de chaque texte, écrite par l'aperçu avec `--layout`, contre
`reference/layout/*.json`). Captures, cartes d'écart et journaux : `docs/design/idle/captures/`.

| Écran | t = 3 s : écart global | zone max | textes à ±2 px | t = 0,45 s : écart global | zone max |
|---|---|---|---|---|---|
| 09 jeu | 3,31 | 6,8 | 16/16 | 3,17 | 6,7 |
| 10 jeu + téléchargement | 3,37 | 6,8 | 18/18 | 3,18 | 6,7 |
| 11 téléchargement | 3,33 | 6,8 | 14/14 | 3,17 | 6,7 |
| 12 repos | 0,89 | 2,9 | 13/13 | 0,83 | 4,6 |

Corrections faites pendant la boucle :
- **Lueur de l'écran 12** : opacité 0,7 ↔ 1, sans le facteur 0,22 de la spec. Dans la maquette, l'animation
  CSS `cocoGlow` remplace l'opacité écrite sur l'élément ; la référence le confirme (écart 7,28 → 0,89).
- **Durée** : l'écart de 6 px de la maquette s'applique aussi après la marge de 14 px qui suit « h ».
- **Capsule** : 78 px de haut en tout (76 + contour, `box-sizing: content-box`).
- **Premier écran** : `IdleScreen` choisissait l'écran avant que le mock ait rempli ses données (ordre des
  `Component.onCompleted`), d'où le repos puis un fondu vers le jeu ; il choisit maintenant après
  (`Qt.callLater`, test `test_firstScreenWaitsForTheData`).
- **Flou d'entrée** : `MultiEffect` à `blurMax: 32` (écart type mesuré 7,8 px à `blur: 1`, à peu près
  proportionnel), au lieu de 16 (3,1 px).

Écarts restants connus (sous les seuils) :
- Bords des glyphes : lissage de Chromium ≠ celui de Qt (le gros de l'écart de 09 à 11, sur les textes).
- Fond de 09 à 11 : la maquette peint des dégradés CSS sur la boîte de 1480 × 920 ; la veille recadre la
  jaquette PNG (ce que fera une vraie jaquette). Voile faible sur le fond (≤ 6,8 par zone).
- À t = 0,45 s, la capture est en avance d'environ une image sur la maquette : le minuteur de capture et le
  rendu de `grabToImage` ne tombent pas exactement sur l'instant d'animation.

### Porte de la phase 4
✅ **Passée** : écart global ≤ 6/255 sur chaque écran à t = 3 s, aucune zone au-dessus de 15, tous les
textes à ±2 px de `layout/*.json` (même taille, même graisse).

## Écran de veille — phase 5, intégration (2026-10-27)

- **Remplace `SleepScreen`** (supprimé, ainsi que ses jetons de `Theme.qml`) : `idle/IdleOverlay.qml` garde son
  interface (`asleep`, `sleep()`, `wake()`, `woke`), d'où une seule ligne changée dans `ConsoleHome` et ses
  tests intacts. Fondu d'entrée de 600 ms au-dessus de l'accueil ; la touche qui réveille n'atteint pas
  l'accueil, qui reprend la main tout de suite pendant la sortie (320 ms). Une fois la veille opaque,
  l'accueil est caché (`covering`) : rien à dessiner dessous.
- **Minuterie** : celle de `ConsoleHome` (réarmée par toute entrée, `InputStatus.activity`), délai
  `ConsoleUi/sleepMinutes`, **2 min par défaut** (`Theme.sleepMinutes`, avant 5), réglable dans
  Options › Console › Veille de l'écran (2, 5, 10, 30 min, jamais).
- **Données réelles** (`ConsoleHome`, `liveIdleStatus`) : PC (nom, en ligne, jeu en cours), réseau
  (Wi-Fi de `SystemStatus.wifi`, force NetworkManager convertie en dBm ≈ % / 2 − 100 ; latence de
  `SystemStatus`), batterie (niveau, charge, autonomie de `batteryDetails`), jeu qui tourne sur le PC (nom,
  jaquette Apollo de l'étagère, éditeur et genre du Companion, durée depuis son dernier lancement d'ici),
  dernier jeu (`ConsoleUi/lastGame` + `recentGames`). Sans donnée, l'élément est masqué : latence inconnue,
  autonomie inconnue, durée inconnue (partie lancée sur le PC), pas de dernier jeu.
- **TODO(HostCompanion)** : téléchargements (toujours inactifs en réel), jaquettes Playnite, début réel de
  la partie. `COCOOS_IDLE_MOCK=1` (+ `COCOOS_IDLE_STATE=game|gameDownload|download|rest`) remplace les données
  par celles des maquettes, pour voir les quatre écrans sur la console. Je n'ai pas branché le mock par
  défaut en réel, contrairement à la lettre du brief : il afficherait « Minecraft, 1 h 24, [Autre jeu] » sur
  la vraie console.
- Journal : `[console-ui] Veille après 2 min d'inactivité (rest)`.
- Textes en anglais : `languages/qml_en.ts` (dates « Tuesday, October 27 », « Press (A) to resume »…).

### Porte de la phase 5
✅ **Passée** : build `embedded` (`qmake6 "CONFIG+=embedded"`) OK ; le binaire, lancé hors écran sans
réseau et sur une configuration vierge, passe en veille à 2 min pile (journal ci-dessus), sans erreur QML ;
`tst_ConsoleHome` 47/47 (le test des options attend 2 → 5 min au lieu de 5 → 10), autres suites du harnais
et de la veille vertes. `git diff --stat console-ui` : hors `app/gui/console/`, seulement `app/qml.qrc`
(couture admise) et de la documentation (`docs/`, `next_steps.md`) ; aucun fichier upstream touché.

## Écran de veille — phase 6, validation sur l'appareil (à faire au transfert sur l'Orange Pi)

Marco a repoussé l'Orange Pi : cette phase attend la carte. Procédure, une fois CocoOS lancé en kiosk :

1. **Lancer la veille** sans attendre : régler Options › Console › Veille de l'écran sur 2 min, ou, pour voir
   chaque écran, lancer avec `COCOOS_IDLE_MOCK=1 COCOOS_IDLE_STATE=game` (puis `gameDownload`, `download`,
   `rest`). Le journal note « [console-ui] Veille après … ».
2. **Temps de rendu** : lancer avec `QSG_RENDER_TIMING=1` et relever, pendant l'entrée (les 2 premières
   secondes) puis au repos (dérive, inclinaison, reflet), les lignes « Frame rendered … » : aucune au-dessus
   de 16,6 ms (60 i/s).
3. **Flou d'entrée** : refaire la mesure avec le flou d'entrée coupé. Il n'y a pas encore de réglage dans
   l'interface : passer `property bool entryBlur: true` à `false` dans `idle/IdleTheme.qml` (ou, sur le laptop,
   touche B dans l'aperçu). Comparer les deux relevés et l'effet à l'œil.
4. **Charge GPU** : pendant la veille, `cat /sys/class/devfreq/*gpu*/load` (ou `…/cur_freq`) toutes les
   secondes, et `top` pour le processus `moonlight`.
5. **À l'œil** : luminosité d'une vraie jaquette (0,92, `IdleTheme.coverBrightnessReal`), noirs de l'OLED
   (le grain ne doit jamais les lever), sortie à la manette.

Rapporter ces chiffres avant toute optimisation.

## Écran de veille — compte rendu (livrable du brief)

- **Fichiers créés** : `app/gui/console/idle/` (`IdleScreen`, `IdleOverlay`, `IdleTheme`, `IdleStatus`,
  `IdleStatusMock`, `IdleFormat.js`, `mock/`, `screens/` ×6, `components/` ×16, `shaders/` ×5 + `.qsb`,
  `assets/`, `preview/` (aperçu, `grab.sh`, `parity.sh`, `layout_check.py`), `tests/` ×2) ;
  `docs/design/idle/captures/` (captures, cartes d'écart, boîtes des textes).
- **Coutures touchées** : `app/qml.qrc` seulement (déclaration des fichiers, retrait de `SleepScreen.qml`).
  Côté console (pas upstream) : `ConsoleHome.qml` (données de la veille, `IdleOverlay` à la place de
  `SleepScreen`, accueil caché sous la veille), `Theme.qml` (2 min par défaut, jetons de l'ancienne veille
  retirés).
- **compare.py** : cf. tableau de la phase 4 (≤ 3,37/255, zone max 6,8, 61/61 textes à ±2 px).
- **Écarts connus** : lissage des glyphes Chromium ≠ Qt ; fond de 09 à 11 dessiné par la maquette en dégradés
  CSS, recadré depuis la jaquette ici ; capture d'entrée en avance d'environ une image ; liseré de jaquette
  extérieur (maquette) et non intérieur (spec) ; opacité de la lueur 0,7 ↔ 1 (maquette) et non 0,22 × (spec).
- **Questions pour Marco** : « Appuyez sur A pour reprendre » réveille la console sur l'accueil, il ne
  reprend pas la partie (le brief ne prévoit que `wakeRequested()`). Faut-il qu'A relance directement le jeu
  en cours ? Libellés d'une installation (absente des maquettes) ; cas 4G/5G (pas de maquette) ; le glyphe
  « A » ne suit pas encore la manette (✕ sur PlayStation) comme le reste de l'interface.

## Écran de veille — demandes de Marco (2026-10-27, après la phase 5)

- **A relance le flux** quand un jeu tourne sur le PC (écrans 09 et 10) : `IdleOverlay` émet `woke(true)`
  (A = Entrée, ou Espace en mode navigation), `ConsoleHome` lance le jeu en cours (`launchApp`) au lieu de
  l'animation de sortie de veille. Une autre touche, ou A sans partie : simple réveil.
  Test `tst_ConsoleHome::test_9k_aResumesTheRunningGame`.
- **Glyphe du bouton** : `KeyHint` dessine ✕ sur une manette PlayStation, B sur une Nintendo (le bouton du
  bas), A sinon (`IdleTheme.buttonLayout` = `Theme.buttonLayout`). Aperçu : `--pad playstation`.
- **4G / 5G** : `network.kind` accepte "4g" / "5g" ("lte" = "4g") ; la ligne d'état montre « 5G » (texte,
  `components/NetworkBadge`) à la place de l'icône Wi-Fi, avec la qualité (« Excellent ») ; la capsule de
  l'écran 12 : « 5G excellente » / « 4G bonne »… (`IdleFormat.networkItem`, testé). Pas de maquette : le
  badge prend la place et la couleur de l'icône. Source réelle : TODO(module 5G), ModemManager (technologie
  d'accès, qualité) ; en attendant, `COCOOS_IDLE_NETWORK=5g` avec le mock, ou `--network 5g` dans l'aperçu.
- **Délai** : nouvelle clé `ConsoleUi/idleSeconds`, **120 s** par défaut (l'ancienne `sleepMinutes`, à 5 dans
  la conf du laptop, est ignorée), réglable dans Options › Console › **Mise en veille après** : 30 s, 1 min,
  2 min, 5 min, 10 min, 30 min, jamais. Vérifié : binaire lancé avec une copie de la conf du laptop, veille
  à 120 s (« [console-ui] Veille après 120 s d'inactivité (rest) »).
- Parité inchangée (09 à 12 : 3,31 / 3,37 / 3,33 / 0,89, 61/61 textes) ; `tst_ConsoleHome` 48/48.

## Écran de veille — netteté et format de l'écran (2026-10-27, demande de Marco)

- **Texte pixellisé** (l'heure de l'écran 12) : les couches étaient rendues à la taille de la grille
  1280 × 720 puis agrandies par sa mise à l'échelle (× 2 sur le laptop). Toutes les couches de la veille
  (heure en dégradé, jaquette et son libellé, reflet au sol, vignette du dernier jeu, entrée floue) ont
  maintenant `layer.textureSize` = taille × `IdleTheme.textureScale` (échelle × `Screen.devicePixelRatio`)
  et `layer.smooth` ; les SVG sont décodés à cette taille ; le grain garde un texel par pixel de l'écran.
- **Format** : `IdleScreen` étire la grille au format de l'écran au lieu de poser des bandes noires
  (1280 × 800 en 16:10, 2520 × 1080 → 2240 × 960 en 21:9). Bloc central (jaquette et colonne ; date, heure
  et capsule) centré, heure / batterie et indication collées aux bords, fond flou et vignettage sur tout
  l'écran, lueur de l'écran 12 à 250 px du bas comme dans la maquette. En 16:9 rien ne change : parité
  3,30 / 3,36 / 3,32 / 0,88, 61/61 textes. Aperçu : `--size 2560x1600` ; test `test_scaleKeepsTheGrid`
   (1920 × 1200 → grille 1280 × 800).

## Outillage IA — industrialisation OpenCode (2026-10-30)

Branche isolée `tooling/opencode-industrialisation`, base `9188d78b` (`claude-tooling`).
Worktree `.ai-worktrees/CocoOS-tooling` dans le parent des deux clones ; le clone
`feat/cocoos-ui` et ses trois fichiers non suivis restent intacts. Aucun push/merge.

- **Fait** : configuration OpenCode 2.2.4 locale, six rôles et cinq commandes,
  whitelist abonnements, permissions testées, flotte tmux/worktrees, scripts/hooks
  fiabilisés, CI d'outillage et guides. Détails/preuves : `docs/ai/TOOLING-REPORT.md`.
- **Vérifié** : builds vanilla/embedded, 17 suites QML, smoke hors réseau,
  i18n check (368 chaînes), qmllint ciblé, vrais hooks en fixtures et flotte
  tmux/Git avec faux OpenCode. Rôles/skills/commandes et permissions évalués par
  le serveur réel ; skill verify réellement chargé dans OpenCode sans exécuter sa procédure.
  Passe finale : **59 tests d'outillage**, **8 scénarios flotte sans skip**,
  **19 permissions serveur**, découverte depuis racine et `scripts/dev/`.
- **Modèles** : Sol/Luna répondent via OpenAI connecté ; Claude Pro authentifié
  mais quota hebdomadaire épuisé jusqu'au 2026-11-02 01:00 Europe/Paris. GPT-5.5
  listé mais refusé pour ce compte ; pas de fallback API/crédit payant.
- **Limites** : analyse statique de ConsoleHome BLOCKED sur imports C++ runtime ;
  Windows/Companion E2E, manette, Orange Pi et performances streaming non éprouvés.
  CI GitHub configurée, pas exécutée. Pas de fonctionnalités métier modifiées.
- **Reprise** : `scripts/dev/status.sh`, `docs/ai/OPENCODE.md`, puis
  `scripts/dev/check.sh` et `python3 scripts/dev/opencode-check.py --permissions`.
- **Prochaine tâche produit** (non faite par cet outillage) : organiser deux
  appareils pour valider la console à la manette contre le portable Windows de
  test. La veille/netteté ci-dessus conserve ses validations matérielles en attente.
