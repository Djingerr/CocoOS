# Brief Claude Code — Refonte CocoOS (interface complète)

> Point d'entrée. Lis ce fichier en entier, puis `SPEC.md`, `DESIGN_SYSTEM.md` et `tokens.json`,
> avant d'écrire du code. Le `CLAUDE.md` du dépôt reste la loi pour l'architecture, les coutures
> upstream, git et les conventions : ce brief ne l'assouplit jamais.
> Travaille phase par phase. Une phase n'est terminée que lorsque sa **porte** est passée.
> Note l'avancement dans `next_steps.md` (le créer s'il n'existe pas).

## Mission

Faire passer l'interface console de la direction « Ambiant » à la direction **CocoOS** validée par
Coco (canevas « CocoOS — Interface », 67 planches), **écran par écran**, en gardant tout ce qui
marche déjà : backends C++ (`CompanionClient`, `SystemStatus`, `WifiSetup`, `InputStatus`,
`StreamMenu`, `AmbientColor`), logique de `ConsoleHome`, harnais, tests, traduction.

Ce n'est pas une réécriture : les composants existants changent d'apparence et de mouvement, et
de nouveaux écrans s'ajoutent (configuration, réglages, recherche, menu d'alimentation, choix du
PC, états vides). La carte de navigation (`reference/png/CarteNavigation.png`) dit comment ils
s'enchaînent.

Variantes retenues (les autres planches du canevas sont abandonnées et ne sont pas fournies) :

| Zone | Retenue |
|---|---|
| Accueil | Carrousel 3D façon Cover Flow (`AccueilCarrousel`) |
| Fiche jeu (↓) | Éditoriale (`FicheEditoriale`) |
| Options (Y) | Feuille groupée (`OptionsFeuille`) |
| Menu en jeu | Centre de contrôle (`JeuControle`) |
| Écran de veille | Les 4 états finaux 1280 × 800 (`Veille*`), qui remplacent ceux de la branche `feat/idle-screen` |

## Où mettre ce dossier

Copier ce dossier dans le dépôt sous **`docs/ui/cocoos/`** (hors build, comme `docs/ui/ambiant/`).
Ce qui doit être embarqué (sons, ombres, grain, polices déjà présentes) est **copié** dans
`app/gui/console/` et déclaré dans le `.qrc` ; le code ne lit jamais `docs/` à l'exécution.

## Contenu du dossier

| Chemin | Rôle |
|---|---|
| `SPEC.md` | Écran par écran : références, composant à modifier ou créer, données, commandes, sons et vibrations, cas particuliers. |
| `DESIGN_SYSTEM.md` + `tokens.json` | Le système de design publié (couleurs, verres, typo, rayons, ombres, courbes, durées, ton des textes). |
| `reference/png/<id>.png` | Rendu cible 1280 × 800 de chaque planche (les animations : dernière image du cycle). |
| `reference/video/<id>.mp4` | Un cycle complet de chaque planche animée, à 1280 × 800. |
| `reference/filmstrip/<id>.png` | 12 images régulières du cycle, pour juger le rythme d'un coup d'œil. |
| `reference/html/<id>.html` | Maquettes autonomes ouvrables dans Chromium (`?now=2026-10-28T21:42:00`). |
| `reference/dc-source/<id>.dc.html` | Sources originales (HTML/CSS + logique de minutage dans `renderVals`). **Toute valeur absente de la spec se lit ici.** |
| `motion/cues.json` | Pour chaque animation : à quel instant (ms) part quel son et quelle vibration. |
| `motion/haptics.json` | Les 14 motifs de vibration (deux moteurs, impulsions en ms et amplitude 0..1) et les 3 niveaux (Off, Légères, Fortes). |
| `sounds/` | 68 sons WAV 48 kHz (62 ponctuels, 6 boucles), `manifest.json`, `SoundBank.qml` de référence. |
| `mock/library.mock.json` | 3 PC (en ligne, en veille, introuvable), une bibliothèque avec cas limites, pour le harnais. |
| `assets/` | `grain_256.png`, `cover_shadow_626x760.png`, `placeholder_cover_600x848.png`. |
| `tools/compare.py` | Compare une capture du harnais à une référence (écart global, par zone, carte de chaleur). |
| `tools/capture_reference.py`, `dc_to_standalone.py`, `boards.json` | Ont produit `reference/` ; à relancer seulement si les maquettes changent. |

**En cas de contradiction :** PNG / vidéo de référence > `dc-source` > `SPEC.md` > `DESIGN_SYSTEM.md` /
`tokens.json` > comportement actuel « Ambiant ».

Les maquettes utilisent des **dégradés abstraits** à la place des vraies jaquettes et des vrais fonds
(droits d'auteur). Dans l'appli, ce sont les images Playnite servies par `CompanionClient`.

## Contraintes non négociables

1. **Tout le `CLAUDE.md` du dépôt s'applique**, en particulier §4 (fichiers neufs plutôt que
   réécriture, coutures upstream listées et rien d'autre, `main.qml` intouchable), §10 (français,
   montrer les diffs avant d'appliquer) et §11 (pièges QML, harnais, traduction).
2. **Aucune nouvelle couture upstream** sans l'accord explicite de Coco. Si un écran semble en
   exiger une (ex. appui long sur power, luminosité pendant le stream), l'écrire dans
   `next_steps.md` sous « Questions pour Coco » et passer à la suite.
3. **Jetons uniquement** : toutes les valeurs passent par `Theme.qml`. Les nouveaux jetons de
   `tokens.json` y sont ajoutés en gardant les noms existants quand ils désignent la même chose
   (table dans `SPEC.md` §1). Aucune valeur en dur dans un composant.
4. **Sora seulement**, déjà embarquée (`fonts/`). Noir pur `#000000` en fond (OLED).
5. **Pas d'invention.** Aucun élément, texte, effet ou écran absent des références. Les textes sont
   ceux des maquettes, en français, via `qsTr()`, et `qml_en.ts` est mis à jour à chaque phase.
6. **Manette d'abord.** Chaque écran se pilote entièrement à la croix, A, B, X, Y, LB/RB, LT/RT,
   ≡ ; souris et tactile restent un bonus (comportements `HoverArea` existants).
7. **Animations interruptibles.** Une touche n'attend jamais la fin d'une animation : l'animation
   repart de sa position courante vers la nouvelle cible (planche `MotionInterruption`). Utiliser
   des `Behavior`/animations relancées depuis la valeur courante, jamais des `SequentialAnimation`
   bloquantes sur une navigation.
8. **Réduire les animations** (`Theme.reducedMotion`, déjà là) : chaque nouvelle animation a sa
   variante de la planche `MotionReduite` (fondus de 200 ms, pas de ressort ni de déplacement).
9. **Matériel** : cible RK3588S (Mali-G610, Panthor), 60 fps. Les flous se font une fois sur une
   image réduite puis se déplacent ; jamais de flou animé plein écran par image. Tout jugement de
   fluidité sur l'Orange Pi reste humain.
10. Branche : partir de `console-ui`, créer `feat/cocoos-ui`. Un commit par sous-étape, messages en
    français comme l'historique.

## Correspondance existant → cible

| Existant (`app/gui/console/`) | Devient | Planches |
|---|---|---|
| `Theme.qml` | Mêmes jetons + ceux de `tokens.json` (verres, rayons, ombres, courbes CocoOS) | `MotionCourbes` |
| `HomeScreen.qml` + `GameShelf.qml` + `HeroBlock.qml` | Accueil carrousel 3D : nouveau `CoverFlow.qml`, bloc titre centré sous le carrousel, `HeroBlock` réduit au titre / méta / boutons | `AccueilCarrousel`, `MotionNavigation`, `MotionJaquettes`, `CasLimites` |
| `StatusBar.qml` | Logo à gauche, onglets de catégories au centre (nouveau `CategoryTabs.qml`, réutilise `ElasticIndicator`), pastille du PC + heure + Wi-Fi + batterie à droite | `AccueilCarrousel`, `MotionCategories`, `MotionReseau` |
| `BackdropLayer.qml` | Fond = art du jeu flouté (100 px), vignettage radial, grain overlay 7 % | toutes |
| `GamePage.qml` | Fiche éditoriale : jaquette 3D à gauche, texte et chiffres à droite | `FicheEditoriale`, `MotionFiche`, `MotionFavori` |
| `OptionsSheet.qml` | Feuille groupée 492 px à droite, onglets Stream / Console, entrée « Tous les réglages » | `OptionsFeuille`, `MotionOptions` |
| *(nouveau)* `settings/` | Réglages plein écran : menu à gauche, contenu à droite | `Reglages*` |
| `OnScreenKeyboard.qml` | Clavier AZERTY/QWERTY en verre, accents à l'appui long | `ClavierWifi`, `MotionClavier` |
| *(nouveau)* `SearchScreen.qml` | Recherche dans la bibliothèque | `Recherche` |
| *(nouveau)* `setup/` | Première configuration en 5 écrans | `Setup*`, `MotionAppairage`, `MotionSetupFin` |
| `CompanionPairing.qml`, `MessageScreen.qml` | Appairage au style CocoOS ; états vides et erreurs | `MotionAppairage`, `EtatHorsLigne`, `EtatFavorisVide`, `MotionEchec` |
| `LaunchScreen.qml`, `StreamCurtain.qml` | Lancement : la jaquette grandit, le PC se connecte, l'image du jeu prend l'écran ; retour inverse | `MotionLancement`, `MotionQuitter`, `MotionReveilPC` |
| `backend/streammenu` + `streampainter` (QPainter) | Menu en jeu « centre de contrôle », statistiques, HUD volume, alertes et capture **redessinés en QPainter** (même architecture, nouveaux dessins) | `JeuControle`, `MotionMenuJeu`, `StatsOverlay`, `MotionHud`, `MotionCapture`, `MotionAlertes`, `MotionReseau` |
| `BootSplash.qml` + `BootTimeline.js` | Même animation du O ; **nouvelle sortie** : le O glisse au centre et se déplie en jaquette du carrousel | `Demarrage` |
| `SleepScreen.qml` + mode `wake` | Mise en veille / réveil (appui court) et extinction | `MotionVeille`, `MotionExtinction` |
| branche `feat/idle-screen` (`idle/`) | Écran de veille aux 4 états finaux 1280 × 800, sortie en éventail de jaquettes | `Veille*`, `MotionReveil` |
| *(nouveau)* `PowerMenu.qml`, `HostPicker.qml` | Menu d'alimentation (appui long), choix d'un autre PC | `MenuAlimentation`, `MotionAlimentation`, `ChoixPC` |
| `Sounds.qml`, `SoundBank.qml`, `sounds/` | Nouveau pack ; les anciens noms restent valides par alias | `sounds/manifest.json` |
| `InputStatus` (vibrations tirées de `Sounds.played`) | Motifs de `motion/haptics.json`, 3 niveaux | `Vibrations` |
| `AmbientColor` | Accent du jeu sélectionné (option), sinon `#F2802A` | `MotionAccent` |

## Phases

### Phase 0 — Reconnaissance (aucun code)
- Lire `CLAUDE.md` du dépôt, `SPEC.md`, toutes les planches de `reference/png/`.
- Faire tourner le harnais existant (`docs/ui/ambiant/harness/`) et noter ce qui marche.
- Pour chaque ligne du tableau ci-dessus : fichiers touchés, jetons manquants, données manquantes
  côté backend (ex. note critique, taille installée, modes de jeu : sont-ils dans la bibliothèque
  Companion ?), risque de nouvelle couture.
- Vérifier : Qt sur le poste et sur l'image de l'Orange Pi, `QtQuick.Effects` (`MultiEffect`),
  `QtQuick.Shapes`, `QtMultimedia`.

**Porte :** une section « Refonte CocoOS — reconnaissance » dans `next_steps.md` : plan fichier par
fichier, données manquantes, liste « Questions pour Coco ». **S'arrêter et attendre la réponse de
Coco avant la phase 1.**

### Phase 1 — Fondations
- `Theme.qml` : ajouter les jetons (SPEC §1), sans casser les anciens noms.
- Sons : copier `sounds/wav/` dans `app/gui/console/sounds/`, adapter `SoundBank.qml` (préchargement,
  rotation `nav_move_1/2/3`, limite de `nav_move_fast`, ambiances en boucle avec fondu) et ajouter
  dans `Sounds.qml` la table d'alias des anciens noms (SPEC §2) pour que rien ne casse.
- Vibrations : un lecteur de motifs (`motion/haptics.json` embarqué en ressource) dans
  `InputStatus`, déclenché par `Sounds.played(name)` comme aujourd'hui, avec le réglage Off /
  Légères / Fortes.
- Harnais : `docs/ui/cocoos/harness/` sur le modèle d'Ambiant (`Harness.qml`, `shot.sh`), avec
  `mock/library.mock.json` et les jaquettes de remplacement.

**Porte :** build `embedded` et vanilla propres ; tous les tests existants verts ; nouveaux tests
`tst_Sounds` (chaque nom de `manifest.json` et chaque alias se résout vers un fichier) et
`tst_Haptics` (chaque motif se charge, durées = `total_ms`).

### Phase 2 — Accueil
`CoverFlow.qml`, `CategoryTabs.qml`, `StatusBar`, `BackdropLayer`, bloc titre, aide en bas, cas
limites (titres longs, jaquette composée, métadonnées absentes, saut alphabétique RT/LT),
chargement des jaquettes, état « Aucun favori ».

**Porte :** captures du harnais comparées à `AccueilCarrousel`, `EtatFavorisVide`, `CasLimites` ;
séquences de `MotionNavigation`, `MotionCategories`, `MotionJaquettes` capturées aux mêmes instants
que les `filmstrip` et validées à l'œil par Coco ; sons et vibrations aux instants de `cues.json`.

### Phase 3 — Fiche jeu et favoris
`GamePage` éditoriale, transition ↓ / ↑, favori (Y), défilement de la description.

**Porte :** `FicheEditoriale`, `MotionFiche`, `MotionFavori`.

### Phase 4 — Options, réglages, clavier, recherche
`OptionsSheet` groupée, pages `settings/`, `OnScreenKeyboard`, `SearchScreen`.

**Porte :** `OptionsFeuille`, `MotionOptions`, les 4 `Reglages*`, `ClavierWifi`, `Recherche`,
`MotionClavier` ; réglages relus après redémarrage (conf `ConsoleUi/…`).

### Phase 5 — Lancer, quitter, erreurs, PC
`LaunchScreen`, `StreamCurtain`, PC injoignable, réveil du PC, `HostPicker`, état « PC hors ligne ».

**Porte :** `MotionLancement`, `MotionQuitter`, `MotionEchec`, `MotionReveilPC`, `ChoixPC`,
`EtatHorsLigne` ; un vrai lancement contre le PC de Coco (validation humaine).

### Phase 6 — Par-dessus le jeu (C++ / QPainter)
Redessiner dans `streampainter` : centre de contrôle, statistiques (détaillé / compact), HUD volume
en haut de l'écran, capture, alertes (batterie, manette, réseau). Pas de nouvelle couture : tout
passe par l'overlay et les coutures déjà listées en §4 du `CLAUDE.md`.

**Porte :** `streammenu-shot` comparé à `JeuControle`, `StatsOverlay`, et aux images clés de
`MotionMenuJeu`, `MotionHud`, `MotionCapture`, `MotionAlertes`, `MotionReseau`.

### Phase 7 — Système
Sortie de `BootSplash` vers le carrousel, veille / réveil, extinction, `PowerMenu`, écran de veille
(rebaser `feat/idle-screen` puis passer aux 4 états finaux), mise à jour, recharge, mode salon.

**Porte :** `Demarrage`, `MotionVeille`, `MotionExtinction`, `MotionAlimentation`, `MenuAlimentation`,
`VeilleJeu`, `VeilleJeuTelechargement`, `VeilleTelechargement`, `VeilleRepos`, `MotionReveil`,
`MotionMiseAJour`. `MotionRecharge`, `MotionSalon` et `LedConsole` dépendent du matériel : interface
seulement, derrière un signal de test du harnais, et la question posée à Coco.

### Phase 8 — Première configuration
`setup/` : Bonjour → Langue → Wi-Fi (+ clavier) → Choix du PC → code PIN → Bibliothèque → accueil.
Marqueur de première fois dans la conf ; « Réinitialiser la console » y ramène.

**Porte :** `SetupBonjour`, `SetupLangue`, `SetupWifi`, `SetupPC`, `SetupBibliotheque`,
`MotionAppairage`, `MotionSetupFin` ; un parcours complet sur une conf vierge dans le harnais.

### Phase 9 — Finitions
Accent tiré de la jaquette, interruptions vérifiées écran par écran, variantes réduites, passe de
cohérence (rayons, ombres, durées), anglais complet, mesure 60 fps sur l'Orange Pi (Coco).

**Porte :** `MotionInterruption`, `MotionReduite`, `MotionAccent` ; une liste « écarts restants »
dans `next_steps.md`, vide ou acceptée par Coco.

## Comment vérifier

- **Écrans fixes** : capture du harnais à 1280 × 800 puis
  `tools/compare.py capture.png reference/png/<id>.png -o diff.png`. Les zones d'art (jaquettes,
  fonds) diffèrent forcément : juger texte, verres, boutons, positions. Viser un écart moyen
  < 3 % hors zones d'art, et regarder la carte de chaleur.
- **Animations** : capturer le harnais aux instants des 12 images de `reference/filmstrip/<id>.png`
  (instant k = k × cycle / 12) et les mettre côte à côte. Le minutage exact (ms, courbes) est dans le
  `renderVals()` de `dc-source/<id>.dc.html`.
- **Sons et vibrations** : journaliser `Sounds.played` avec l'horodatage et comparer à `cues.json`
  (tolérance 30 ms).
- **Ressenti** : la manette en main reste la vérité. Chaque porte se termine par « à valider à la
  manette par Coco » avec la liste de ce qu'il doit essayer.
