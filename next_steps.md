# Prochaines étapes

## Refonte CocoOS — reconnaissance (phase 0, 2026-10-28)

Brief : `docs/ui/cocoos/CLAUDE_BRIEF.md` (+ `SPEC.md`, `DESIGN_SYSTEM.md`, `tokens.json`).
Branche : `feat/cocoos-ui`, créée depuis `console-ui` (`c9ba4bf6`), rebasée sur `console-ui` après la
fusion de `feat/idle-screen` (`17a7882d`). Aucun code écrit.

### Ce qui a été fait
- Lu `CLAUDE.md`, le brief, la spec, le design system, `tokens.json`, `manifest.json`, `haptics.json`,
  `cues.json`, `mock/library.mock.json`, et les sources `dc-source` qu'il fallait pour trancher.
- Regardé les 59 planches de `reference/png/` (la carte de navigation d'abord). Pour les animations, la
  dernière image dit peu (`MotionClavier`, `MotionExtinction`, `MotionVeille` sont noires) : les phases
  suivantes travailleront sur `filmstrip/` et `video/`.
- Harnais Ambiant (`docs/ui/ambiant/harness/`) : **15 suites, 140 tests, tous verts** (`tst_ConsoleHome`
  47 tests en 64 s, `tst_GameShelf` 15, `tst_StatusBar` 8…). `shot.sh` capture bien en 1280 × 800 ;
  `docs/ui/cocoos/tools/compare.py` marche (accueil Ambiant contre `AccueilCarrousel` : 35,8 / 255, écart
  attendu, ce sont deux directions différentes).

### Versions et modules
| | Poste (Fedora 43) | Orange Pi 5B |
|---|---|---|
| Qt | 6.10.3 | inconnue (carte pas installée) ; on suppose ≥ 6.6, déjà exigé par la console |
| `QtQuick.Effects` (`MultiEffect`) | présent, déjà utilisé (4 fichiers) | à vérifier au transfert |
| `QtQuick.Shapes` | présent, déjà utilisé | idem |
| `QtMultimedia` (`SoundEffect`) | présent, déjà utilisé | idem (`qml6-module-qtmultimedia`) |
| `QtQuick3D` | présent, **inutile** : le carrousel se fait en `Matrix4x4` (SPEC §5.1) | — |
| `qsb` | `/usr/lib64/qt6/bin/qsb` | — |

Repères : Ubuntu 24.04 / Debian 12 livrent Qt 6.4 (pas de `MultiEffect`), Debian 13 livre 6.8. Rien de
bloquant ici (décision du 2026-10-27 : l'Orange Pi plus tard).

### Contradictions dans le pack (ordre du brief appliqué : PNG > dc-source > SPEC > tokens)
| Point | Valeurs | Retenu |
|---|---|---|
| Titre sous le carrousel | `tokens.json` `title-xl` 40 px ; SPEC et `AccueilCarrousel.dc.html` 48 px | 48 px (jeton `textTitleXl` à 48 pour l'accueil, à confirmer) |
| Transition de l'accent du jeu | SPEC 600 ms ; `MotionAccent.dc.html` 900 ms | 900 ms |
| Nombre de sons | `DESIGN_SYSTEM.md` 59 + 6 ; `manifest.json` 68 (62 + 6) | le manifest |
| Délai de l'écran de veille | SPEC « 5 min » ; Marco le 2026-10-27 : 120 s par défaut | **question** |
| X à l'accueil | carte : X → Recherche ; SPEC §4 : rien ; `MotionFavori` : bouton « Favori » à l'accueil ; aujourd'hui X épingle | **question** |
| Quitter le jeu (menu en jeu) | `MotionQuitter` : dialogue Annuler / Quitter ; Marco le 2026-10-23 : appui maintenu, sans page de confirmation | **question** |
| Menu d'alimentation | `MenuAlimentation` : A confirme ; aujourd'hui redémarrer / éteindre demandent l'appui maintenu | **question** |
| Réseau en cours de partie | `MotionReseau` : « Wi-Fi retrouvé · Retour en 1080p · 20 Mb/s » ; `CLAUDE.md` §12 : aucune renégociation en cours de partie | **question** |
| Code d'appairage | `MotionAppairage` : « Dans Apollo, sur PC-Salon, saisissez ce code » (PIN Moonlight, saisi sur le PC) ; Companion : code affiché par le PC, saisi sur la console | **question** |

### Plan fichier par fichier
Tout reste dans `app/gui/console/` sauf mention. « Couture » = fichier upstream.

| Zone (phase) | Fichiers | Jetons / ressources manquants | Données manquantes | Couture |
|---|---|---|---|---|
| **Jetons** (1) | `Theme.qml` modifié | valeurs changées : `ink` `#F5F5F7`, `ink2` / `ink3` en rgba 0,6 / 0,5, `inkOnAccent` `#1B0E04`, `poor` `#FF453A` + alias `danger`, `pressDuration` 90 → 110. Nouveaux : `glassPill/Group/Raised/Sheet/Dialog/Hud`, `hairline`, `hairlineStrong`, `focusRow`, `keyChar`, `keyFn`, `toggleOff`, `segmentTrack`, `segmentActive`, `accentTrack`, `accentSoft`, `blue`, `inkOnLight`, `radiusCoverS…radiusPill`, `blurPill/Sheet/Backdrop`, `durPress/Focus/Exit/Enter/Scene`, `curveMain/Spring/SpringStrong` (`curveExit` existe déjà, même valeur), styles `textDisplay…textGlyph`, marges `marginScreen` 72 / `marginStatus` 56 | — | non |
| Ombres (1) | `shadows/*.png` + `harness/make-shadows.py` étendu | `shadow-cover`, `shadow-glass`, `shadow-focus` ; `grain_256.png`, `cover_shadow_626x760.png`, `placeholder_cover_600x848.png` copiés | — | ajout de lignes au `.qrc` (cf. question ressources) |
| **Sons** (1) | `Sounds.qml` (table d'alias SPEC §2, rotation `nav_move_1/2/3`, `nav_move_fast` ≤ 11/s), `SoundBank.qml` (préchargement après `BootSplash`, ambiances en boucle avec fondu 1,8 s / 0,9 s), `sounds/` (68 WAV) | — | — | `.qrc` (cf. question : 57 Mo) |
| Sons dans le flux (1 ou 6) | `backend/streammenu.cpp` | les sons SDL ne sont chargés que s'ils sont en **44,1 kHz mono** (`loadSounds`) : le nouveau pack (48 kHz stéréo) serait ignoré en silence → ouvrir le périphérique SDL en 48 kHz stéréo, nouveaux noms (`ingame_menu_*`, `focus_tick`, `slider_*`, `volume_*`, `capture`, alertes) | — | non (fichier maison) |
| **Vibrations** (1) | `backend/inputstatus.{h,cpp}`, `backend/streammenu.cpp` (`StreamMenu::rumble` : table fixe à remplacer par le lecteur de motifs), `motion/haptics.json` embarqué | réglage `ConsoleUi/rumble` (booléen) → Off / Légères / Fortes, en gardant l'ancienne clé comme valeur par défaut | moteurs de la manette intégrée (GP2040-CE) inconnus | non |
| Harnais (1) | `docs/ui/cocoos/harness/` : `Harness.qml`, `shot.sh`, démos ; **réutilise** `docs/ui/ambiant/harness/stubs/` par `-I` au lieu de les copier | jaquettes de remplacement depuis `mock/` | — | non |
| **Accueil** (2) | `HomeScreen.qml` (refondu), nouveaux `CoverFlow.qml` et `CategoryTabs.qml` (réutilise `ElasticIndicator`), `HeroBlock.qml` réduit (titre centré, méta, PEGI, A Jouer / Y Options), `StatusBar.qml` (logo, onglets au centre, pastille PC à point `accent` qui respire, heure, Wi-Fi, batterie), `BackdropLayer.qml` (fond flouté 100 px une fois sur image réduite, vignettage, grain 7 %), `ControllerLegend.qml` (aide en bas), `Library.js` (catégorie **Apps** = les utilitaires aujourd'hui écartés ; saut alphabétique au-delà de 30 jeux), `GameShelf.qml` **retiré** à la fin de la phase (et `tst_GameShelf` adapté à `CoverFlow`) | `cocoLive` 2,4 s, `cocoSheen` 10 s, géométrie des emplacements du carrousel | **jaquettes 600 × 848** : la Companion sert `cover` (Playnite) ; aujourd'hui seuls les jeux absents d'Apollo l'utilisent, les autres prennent la jaquette Apollo 600 × 800 (recadrée à 0,706) ; **éditeur** (`publishers[0]`) déjà là, **PEGI** (`ageRatings`) déjà là | non. Note : L2 / R2 sautent aujourd'hui de dix vignettes (`InputStatus.triggerPressed`), ils deviennent le saut alphabétique |
| États vides (2, 5) | `MessageScreen.qml` restylé ; « Aucun favori » et « PC hors ligne » posés sur le carrousel (pas à la place du héros) | — | — | non |
| **Fiche** (3) | `GamePage.qml` refondu (jaquette 3D à gauche, texte à droite), transition depuis `CoverFlow` | sons `fiche_open/close`, `favorite_add/remove` | voir « Données manquantes » | non |
| **Options** (4) | `OptionsSheet.qml` (1 400 lignes) : restylé, pas réécrit — feuille 492 px, onglets segmentés Stream / Console, profil en segments, ligne « Tous les réglages » | — | « Priorité : Image » et « Écran virtuel » de la maquette n'existent ni dans `StreamProfiles.js` ni dans `StreamingPreferences` | non |
| **Réglages** (4) | nouveau `settings/SettingsScreen.qml` + une page par rubrique (`WifiPage`, `ControllersPage`, `DisplaySoundPage`, `GeneralPage`) ; icônes SVG extraites des `dc-source` dans `icons/` | tuiles de couleur des rubriques | voir « Questions » (5G, Bluetooth, luminosité auto, couleurs, chaleur le soir, sortie audio, mise à jour, nom de la console) | non pour l'interface ; **backends neufs** pour Bluetooth (BlueZ par D-Bus), sortie audio (`wpctl`), bande Wi-Fi et débit du lien (NetworkManager, déjà là), stockage (`QStorageInfo`) |
| Clavier (4) | `OnScreenKeyboard.qml` restylé ; accents à l'appui long, curseur LB/RB, dernier caractère visible 1 s, R3 affiche | — | — | non |
| **Recherche** (4) | nouveau `SearchScreen.qml` (filtre en JS sur titres, éditeurs, genres ; recherches récentes dans `ConsoleUi/recentSearches`) | — | — | non |
| **Lancement / quitter** (5) | `LaunchScreen.qml`, `StreamCurtain.qml`, `ConsoleHome.qml` (enchaînement, retour de la jaquette dans le carrousel) | `connecting_loop` | — | non |
| **PC injoignable, réveil, choix du PC** (5) | `ConsoleHome.qml`, nouveau `HostPicker.qml` (menu sous la pastille du PC) | — | **plusieurs PC** : `CompanionClient` ne suit qu'un seul host ; nombre de jeux par PC ; état « en veille » vs « introuvable » (Moonlight ne distingue que en ligne / hors ligne + MAC connue) | non |
| **Par-dessus le jeu** (6) | `backend/streampainter.{h,cpp}` (nouveaux dessins : tuiles, curseurs verticaux, statistiques détaillées / compactes, HUD, alertes), `backend/streammenu.cpp` (navigation 2D dans la grille de tuiles, au lieu de la liste) ; `harness/streammenu-shot.cpp`, `streammenu-rows.cpp` | flou du fond déjà là | **minutes de jeu** (« En pause · 1 h 24 min ») : durée depuis le lancement d'ici, déjà connue de l'accueil | **risque** : touches volume / power pendant le flux (cf. questions) ; tout le reste passe par les coutures existantes |
| **Démarrage** (7) | `BootSplash.qml`, `BootTimeline.js` (+ `tst_BootTimeline` étendu) : nouvelle sortie (O → jaquette du carrousel, éventail) | — | — | non |
| Veille / réveil / extinction / alimentation (7) | `SleepScreen.qml` → remplacé, nouveau `PowerMenu.qml`, `SystemStatus.power()` existant | sons `sleep`, `wake`, `shutdown` | — | **risque** : appui court / long sur power (cf. questions) |
| Écran de veille (7) | rebaser `feat/idle-screen` (`idle/`), écrans mis aux références `Veille*` 1280 × 800 ; `amb_veille` / `amb_repos` | — | téléchargements (désormais dans le protocole : `DOWNLOAD_STATE`) | non |
| Mise à jour, recharge, mode salon, LED (7) | interfaces derrière un signal du harnais seulement | — | mécanisme de mise à jour, matériel | à définir |
| **Première configuration** (8) | nouveau `setup/` (Bonjour, Langue, Wi-Fi, PC, code, Bibliothèque, Tout est prêt), réutilise `WifiSetup`, `OnScreenKeyboard`, `CompanionPairing` ; marqueur `ConsoleUi/setupDone` existant | code QR | URL d'installation d'Apollo + HostCompanion ; progression « 132 / 214 » des jaquettes (connue côté console : médias en cache / jeux) | non. Le code QR demande un générateur (fichier unique `qrcodegen`, MIT) ou une image fixe |
| **Accent** (9) | `backend/ambientcolor.cpp` (bornes de luminance et saturation de `MotionAccent`), `Theme.accent` qui suit le jeu ; accent choisi (orange, blanc, bleu, vert, rose) dans `ConsoleUi/accent` | — | — | non |
| Traduction (chaque phase) | `languages/qml_en.ts` / `.qm` | — | — | non |

### Données manquantes côté Companion (`GameInfo`, `../HostCompanion/docs/protocol.md` §4)
Présent et déjà lu par `CompanionClient.games()` : nom, description (HTML), développeurs, éditeurs, date
de sortie, genres, temps de jeu (s), dernière partie, installé, `ageRatings` (PEGI), `installSizeBytes`,
`source` (store), médias `cover` / `bg` / `logo` / `icon`.

| Affiché dans les maquettes | Où | Dans Playnite | Dans l'API |
|---|---|---|---|
| Note critique « 93 / 100 » | Fiche | `CriticScore` (et `CommunityScore`) | **absent** |
| Modes « Solo · Multijoueur · Manette » | Fiche | `Features` | **absent** |
| Plateformes « Xbox · PC » (ligne « Bibliothèque ») | Fiche | `Platforms` (+ `Source`) | `source` seulement |
| Favori, écrit aussi dans Playnite | Fiche, onglet Favoris | `Favorite` | **absent** : les favoris sont locaux (`ConsoleUi`, `Library.js`), rien n'est écrit dans Playnite aujourd'hui (la SPEC dit « comme aujourd'hui » : c'est faux) |
| Progression « 38 % du jeu terminé », « 62 % des succès » | `MotionAccent` | `CompletionStatus` (sans pourcentage) ; succès via extension | **absent** |
| Nombre de jeux par PC « 214 jeux » | `ChoixPC`, `SetupPC` | — | calculable (`games.length`) pour le PC appairé seulement |
| Jeux non installés (préférence de la configuration) | `SetupBibliotheque` | `IsInstalled` | présent |

Sans réponse, ces champs restent **masqués** (règle « on retire, on ne remplace pas » de `CasLimites`).

### Questions pour Coco
**Organisation**
1. `feat/idle-screen` n'est pas fusionnée dans `console-ui`, et `next_steps.md` n'existe que sur elle :
   ce fichier-ci (nouveau sur `feat/cocoos-ui`) entrera en conflit avec le sien. Les deux branches touchent
   aussi `ConsoleHome.qml` (l'écran de veille y remplace `SleepScreen`). Je propose de fusionner
   `feat/idle-screen` dans `console-ui` puis de rebaser `feat/cocoos-ui` dessus **avant la phase 1**.
   D'accord ?
2. Le pack fait 92 Mo (`sounds/` 55 Mo, `reference/` 37 Mo). Je propose de versionner `docs/ui/cocoos/`
   sauf `reference/video/` (ou tout, si le poids ne te gêne pas). Lequel ?
3. Les fichiers de la console sont déclarés dans `app/qml.qrc`, embarqué **aussi par le build vanilla**.
   Ajouter 57 Mo de sons (dont 38 Mo d'ambiances) y alourdirait Moonlight vanilla. Je propose un
   `gui/console/console.qrc` à part, ajouté par une ligne dans le scope `embedded` de `app.pro` (couture
   existante), pour les nouveaux sons et images seulement. D'accord ? Et les ambiances : embarquées, ou
   installées à côté du binaire ?

**Décisions qui contredisent l'existant**
4. Écran de veille : 120 s par défaut (ta décision du 27/10) ou 5 min (SPEC) ?
5. X à l'accueil : Recherche (carte de navigation), Favori (`MotionFavori`), ou rien (SPEC §4) ? Et comment
   ouvre-t-on la Recherche sinon ?
6. Quitter le jeu depuis le menu en jeu : dialogue Annuler / Quitter (`MotionQuitter`) ou ton appui
   maintenu sans confirmation (23/10) ?
7. Menu d'alimentation : A suffit (`MenuAlimentation`) ou appui maintenu pour Redémarrer / Éteindre ?
8. `MotionReseau` montre la qualité qui remonte en cours de partie (« Retour en 1080p · 20 Mb/s »), ce
   qu'Apollo non modifié ne permet pas sans couper le flux (§12). On garde la bannière sans ce détail ?
9. Configuration, étape « code » : la maquette fait saisir un code **dans Apollo** (PIN Moonlight).
   Avec le Companion, le PC affiche le code et la console le saisit, puis le PIN Moonlight part tout seul.
   Quel écran : celui de la maquette (cas sans Companion) et `CompanionPairing` restylé (cas normal) ?
10. Le carrousel affiche des jaquettes 600 × 848 : on prend la jaquette Playnite du Companion pour tous les
    jeux (et celle d'Apollo seulement à défaut), d'accord ?

**Données (côté HostCompanion)**
11. Ajouter à `GameInfo` : `criticScore`, `features`, `platforms`, `favorite` (+ une route pour écrire le
    favori dans Playnite) ? Sinon ces éléments restent masqués. La progression (`MotionAccent`) : on
    l'abandonne ?

**Matériel et système**
12. Appui court / long sur power : logind (`HandlePowerKey=ignore` + inhibiteur, la console lit la touche)
    ou firmware GP2040-CE ? Pendant un flux, la touche arrive à SDL : la router vers le menu demanderait
    d'étendre la couture `keyboard.cpp`.
13. Touches de volume sur le dessus : quel périphérique (GP2040-CE, gpio-keys) ? Même question de couture
    pendant le flux. La luminosité / le volume par logind et `wpctl` (déjà là) suffisent-ils ?
14. Veille (power court) pendant un jeu : « stream en pause côté PC » n'existe pas dans Moonlight ; une
    suspension coupe la session. On ferme le flux proprement, ou on éteint seulement l'écran ?
15. Manette déconnectée : « jeu en pause » = carte par-dessus le flux et entrées bloquées (le jeu continue
    sur le PC) ?
16. Moteurs de vibration sur la manette intégrée ? Mécanisme de mise à jour de CocoOS (paquet, image A/B) ?
    Recharge console éteinte, mode salon, LED : l'interface seulement, derrière un signal du harnais ?

**Réglages présents dans les maquettes mais sans fonction aujourd'hui** (à garder, masquer ou faire)
17. Réseau mobile 5G (et « Basculer en 5G si le Wi-Fi tombe ») — pas de modem : masqué ?
18. Bluetooth : liste et association de manettes (backend BlueZ à écrire), « Tester les boutons et les
    sticks » (aucune maquette de l'écran de test).
19. Écran : luminosité automatique (capteur ?), couleurs Naturelles / Vives, chaleur le soir (demande le
    compositeur, gamescope) ; Son : sortie audio (`wpctl`, faisable).
20. Général : mise à jour logicielle (dépend de 16), nom de la console (« Console de Coco »), version
    « CocoOS 1.2 » (d'où vient le numéro ?), vider le cache des jaquettes (faisable).
21. Rubriques sans maquette : Notifications, Batterie, Accessibilité (réduire les animations y irait),
    Confidentialité, PC et streaming, Bibliothèque. Je propose : Batterie, Accessibilité, PC et streaming et
    Bibliothèque avec les réglages qui existent déjà ; Notifications et Confidentialité masquées.
22. Options › Stream : « Priorité : Image » et « Écran virtuel » n'existent pas. Masqués ?
23. Configuration : 7 langues dans la maquette, la console n'a que français et anglais. On n'affiche que ces
    deux-là ? « Installer Apollo et HostCompanion » : quelle URL dans le code QR ?
24. `amb_accueil` (fond musical de l'accueil, « désactivé par défaut ») n'a pas de réglage dans les
    maquettes : on l'oublie ?

### Réponses de Coco (2026-10-28)
- **Q1** : `feat/idle-screen` fusionnée dans `console-ui` (avance rapide, `eb72a861`), puis
  `feat/cocoos-ui` rebasée dessus. L'écran de veille de la phase 7 part donc de ce qui est déjà là.
- **Q4** : veille après **5 min** par défaut (`Theme.idleSeconds` 300, commit `17a7882d` sur
  `console-ui`) ; réglable dans les options.
- **Q6** : quitter le jeu reste à l'**appui maintenu**, sans dialogue (on ne reprend pas celui de
  `MotionQuitter`).
- **Q7** : menu d'alimentation : **A suffit** (comme `MenuAlimentation`).
- **Q8** : **pas de changement de qualité en cours de partie** pour l'instant ; les bannières réseau de
  `MotionReseau` restent sans « Retour en 1080p · 20 Mb/s ». À reprendre plus tard (chantier §12).
- **Q5** (X à l'accueil) : pas d'avis. Par défaut, **X reste « Favori »** (comportement actuel, bouton de
  `MotionFavori`) ; l'accès à la Recherche se tranchera en phase 4 (proposition : ≡, libre à l'accueil).

Restent ouvertes : Q2 et Q3 (bloquent la phase 1), Q9 à Q24 (phases suivantes).

### Porte de la phase 0
✅ **Passée** (2026-10-28) : réponses de Coco ci-dessus, plus Q2 (le pack est versionné en entier,
vidéos comprises) et Q3 (`console.qrc` à part, ajouté par le scope `embedded` d'`app.pro`).

## Refonte CocoOS — phase 1, fondations (2026-10-28)

Un commit par sous-étape :
- **Jetons** (`Theme.qml`) : tout `tokens.json` (verres, contours, rayons, espacements, styles de
  texte `text*` = { size, weight, lineHeight, spacing }, durées `dur*`, courbes `curveMain`,
  `curveSpring`, `curveSpringStrong`) ; `ink` `#F5F5F7`, `ink2` / `ink3` en rgba 0,6 / 0,5,
  `inkOnAccent` `#1B0E04`, `poor` `#FF453A` + `danger`, `pressDuration` = `durPress` (110 ms).
  L'interface Ambiant prend donc déjà les nouvelles encres.
- **Sons** : les 68 WAV du pack dans `app/gui/console/sounds/`, déclarés dans
  `app/gui/console/console.qrc` (préfixe `/gui/console`, chemins inchangés pour le QML et SDL),
  ajouté par `RESOURCES +=` dans le scope `embedded` d'`app.pro` ; les anciens sons sortent de
  `qml.qrc` (le vanilla passe de 0,7 Mo de sons à rien). `Sounds.qml` : table d'alias SPEC §2,
  `played(nom du pack)`, `ambiance(nom)`. `SoundBank.qml` : préchargement des sons ponctuels,
  rotation `nav_move_1/2/3`, `nav_move_fast` ≤ 11/s, **`connecting_loop` en boucle** (oublié par le
  SoundBank de référence, attrapé par `tst_Sounds`), ambiances `amb_*` lues à la demande en fondu
  croisé 1,8 s / 0,9 s. Niveau commun `Theme.soundVolume` 0,8 (celui de la référence) ; corrections
  `brightness_tick` −3 dB, `slider_tick` −2 dB. Menu en jeu (SDL) : 48 kHz stéréo et noms du pack
  (`ingame_menu_*`, `focus_tick`, `volume_*`, `brightness_tick`, `slider_limit`, `hold_*`, `select`,
  `nav_edge`). `make-sounds.py` retiré. Démarrage : `boot-open` → `boot`, `boot-close` muet, sortie
  de veille du `BootSplash` → `wake` (calage fin en phase 7).
- **Vibrations** : `backend/haptics.{h,cpp}` (Qt seul) découpe les 14 motifs en pas de 10 ms ;
  `StreamMenu::rumble(son, intensité)` les joue par un minuteur SDL, à l'accueil comme en jeu (un
  nouveau motif coupe le précédent). `category_prev` prend le motif de `category_next`. Réglage
  « Vibrations » : Off / Légères (défaut) / Fortes → `ConsoleUi/haptics` 0 / 0,6 / 1 ; l'ancienne
  clé `rumble` est ignorée. Conséquence du pack : `deny` et `launch_start` ne vibrent plus
  (`launch_ready` si).
- **Harnais** `docs/ui/cocoos/harness/` : `shot.sh` (passe par celui d'Ambiant, `base=`), `Mock.js`
  (mock → `GameInfo`, grande bibliothèque de A à Z), `make-art.py` + `art/` (jaquettes 600 × 848
  et fonds abstraits, Factorio sans), vue de contrôle `LibraryDemo`.
- Traduction : « Off », « Légères », « Fortes » → Off, Light, Strong.

### Porte de la phase 1
- Build `embedded` : ✅ (binaire 48 → 105 Mo, les sons), démarre sans erreur QML (hors réseau).
- Build vanilla : ✅ hors source, sans `CONSOLE_UI`, sans sons ni `haptics` (39 Mo), démarre
  (avertissements upstream habituels de `main.qml`).
- Tests : ✅ les 17 suites existantes (Ambiant + veille), `tst_Sounds` 6/6, `tst_Mock` 6/6,
  `tst_haptics` « ok » (et il échoue bien sur un découpage faux).
- Reportés à la phase où ils servent : ombres pré-rendues CocoOS (`shadow-cover`…), copie de
  `grain_256.png` et de la jaquette de secours.
- ⚠️ **À écouter / sentir par Coco** : le niveau du nouveau pack (0,8) à l'accueil et dans le menu en
  jeu, et les vibrations Légères / Fortes à la manette (aucune n'a été ressentie).

## Refonte CocoOS — phase 2, accueil (2026-10-28)

Décision de Coco : jaquette Playnite (Companion) d'abord, celle d'Apollo à défaut ; à revoir
dans les phases suivantes si besoin.

Commits : fond flouté et carrousel (`8972077c`), accueil assemblé (`15d5deac`), puis séquences,
traduction et notes.
- **Fond** (`BackdropLayer`, `shaders/Backdrop.frag`) : l'image floutée une fois en 148 × 100
  (MultiEffect), puis un seul passage de shader : cadrage `inset: -100px`, dérive cocoBgPan
  (1,25 → 1,34, 60 s), saturation 1,1, vignettage radial 0,25 → 0,85, grain 7 % en overlay
  (`images/grain.png`). Fondu croisé de 900 ms.
- **Carrousel** (`CoverFlow`, `shaders/Cover.frag`) : emplacements et rotations de
  `AccueilCarrousel` interpolés par une seule valeur `position` (animée, interruptible) ;
  perspective 900 px par `Matrix4x4` ; chaque jaquette en un passage (coins, reflet en biais,
  dégradé des latérales, assombrissement, balayage toutes les 10 s, squelette de chargement) et son
  reflet au sol ; ombres pré-rendues (`shadows/cover*.png`, `make-shadows.py`) ; titre des
  latérales ; déplacement 640 ms à léger rebond, maintenu 190 ms par pas (230 ms) avec flou ;
  butée de 34 px ; saut de lettre RT / LT au-delà de 30 jeux (lettre dans un carré de verre,
  carrousel flouté, `tab_switch` + vibration « category ») ; jaquette composée (dégradé d'une des
  six teintes, éditeur, titre) ; apparition des jaquettes (500 / 700 ms). `GameShelf` retirée
  (et `tst_GameShelf`, 54 jetons morts, `shadows/thumb.png`).
- **Barre haute** : logo 20 px, onglets `CategoryTabs` au centre (pastille blanche 520 ms à léger
  rebond, écrasement, LB / RB allumés), pastille du PC à droite (point accent qui respire),
  heure 15 px tabulaire, Wi-Fi, batterie. **Engrenage masqué** (absent de la maquette).
- **Bloc titre** (`HeroBlock` réécrit, même interface) : titre 48 px centré, deux lignes
  équilibrées, puis 36 px, puis points de suspension ; méta « studio · année · genre » (Récents :
  dernière partie · temps de jeu) et pastille PEGI ; A Jouer (blanc) et Y Options (verre) ;
  Reprendre / Quitter maintenu inchangés. Changement de jeu : fondu flou de 12 px vers le haut ou
  le bas (520 ms, 200 maintenu) ; de catégorie : de côté.
- **Catégories** (`Library.js`) : Tout et Favoris toujours, Récents et Apps s'ils ont quelque
  chose ; les utilitaires d'Apollo (Desktop, Steam Big Picture…) vont dans Apps (« A Ouvrir »).
- **Aide** (`HomeHelp`) : flèches au trait, allumées à l'appui, ↓ qui oscille.
- **Favoris vide** (`EmptyFavorites`) : cadres en pointillés en perspective, étoile, message,
  « RB Voir les jeux récents », aide LB / RB / Y.
- **Sons et vibrations** : `category_next` / `category_prev`, `nav_move_fast` vibre comme
  `nav_move` (cues.json), `library_ready` quand la bibliothèque du Companion arrive accueil
  affiché, `Sounds.play(nom, vibration)`.
- Harnais : `HomeDemo` (mock, `script=t:action`, `loading=1`), `filmstrip.sh` (12 images),
  `tst_CoverFlow` (7 tests). `Format.meta / publisher / pegi` (+ test).

### Porte de la phase 2
- **Écrans fixes** (`tools/compare.py`) : `AccueilCarrousel` **3,2 / 255** (aucune zone > 7,3),
  `EtatFavorisVide` **3,8 / 255** (le gros de l'écart : la phrase retirée, cf. écarts).
  `CasLimites` (planche d'explication, pas un écran) : les quatre cas vérifiés en capture (titre
  long, jaquette composée, méta incomplète, saut de lettre).
- **Séquences** : `MotionNavigation` capturée aux 12 instants de son filmstrip, calée sur
  la maquette pour les déplacements simples (1,7 s et 3,4 s : mêmes titres en plein fondu).
  `MotionCategories` et `MotionJaquettes` : même comportement ; leurs filmstrips de référence ne
  suivent pas le minutage de leur propre source (cycle de 10 s au lieu de 8 ou 7), la comparaison
  se fait au comportement, pas image par image. Commandes dans `CLAUDE.md` §11.
- **Tests** : 19 suites vertes (dont `tst_ConsoleHome` 48, `tst_CoverFlow` 7). Build `embedded` :
  démarre sans avertissement de la console.
- Sons et vibrations aux instants de `cues.json` : les déclencheurs sont à leur place (mêmes
  événements) ; pas de journal horodaté comparé à 30 ms près (le harnais coupe les sons en capture).
- **Écarts restants** (à accepter ou trancher) :
  1. Engrenage de la barre haute masqué (`StatusBar.settingsShown`) : on le garde caché ?
  2. « Vos favoris sont aussi enregistrés dans Playnite. » retiré du message des favoris vides :
     faux tant que le Companion n'écrit pas les favoris (Q11).
  3. Squelette du titre de `MotionJaquettes` non fait : chez nous le titre (Apollo) est toujours
     connu avant l'entrée de l'accueil.
  4. Images noires de `MotionNavigation` à 5,1 s et 7,65 s (fonds à mi-fondu dans la capture de
     la maquette) : non reproduites.
  5. Accueil : plus de logo du jeu à la place du titre, plus de point « en cours » sur la jaquette
     (absents des maquettes) ; Reprendre / Quitter restent dans le bloc titre.
  6. Apps : pas de méta (la maquette écrit « Bureau virtuel sur PC-Salon », sans source de donnée).
- ⚠️ **À valider à la manette par Coco** : parcourir (appui, maintien, butée), LB / RB, saut de
  lettre (bibliothèque de plus de 30 jeux), Favoris vide puis RB, A Jouer / Ouvrir, les sons et
  vibrations ; la fluidité (perspective, flou maintenu) sur l'Orange Pi, plus tard.

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
