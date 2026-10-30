---
name: cocoos-ui
description: Direction artistique, carte des fichiers et pièges QML de l'interface console CocoOS (app/gui/console). À charger avant de créer ou modifier un .qml, Theme.qml, un écran, une animation ou un backend de app/gui/console/.
---

# Interface console CocoOS — référence

Règles d'or (rappel) :
- Tout le code console vit dans `app/gui/console/` ; **aucune valeur en dur** : tout passe par `Theme.qml`
  (canevas de 800 px de haut mis à l'échelle par `HomeScreen`).
- Police : **Sora uniquement** (`Theme.fontUi`) — ne jamais choisir une autre police.
- Tout texte affiché : `qsTr("…")` en français, puis mise à jour de la traduction (skill `cocoos-i18n`).
- 100 % navigable à la manette ; jamais d'élément « bureau ».
- Les prototypes HTML font foi (`docs/ui/ambiant/`, `docs/ui/micro-interactions/`,
  `docs/boot-animation/`, `docs/design/idle/`). Vérifier visuellement avec le skill `ambiant-harness`.

## L'interface custom (direction artistique validée)

> **Source de vérité de l'UI d'accueil : l'écran « Ambiant »** —
> `docs/ui/ambiant/AMBIANT-BRIEF.md` et `docs/ui/ambiant/ambiant-prototype.html`
> (version n° 2 « Ambiant », touche `2`). En cas de doute, le prototype gagne.
> Accueil, options et lancement sont implémentés (cf §2). Les écrans d'attente,
> d'appairage et les dialogs, absents du prototype, en reprennent le langage :
> `MessageScreen` (même ancrage et même titre que le héros) et `ConsoleDialog` (même
> panneau que les options).

Sombre et immersif, **100 % navigable à la manette**, jamais d'élément "bureau". Choix
esthétiques arrêtés :
- **L'illustration du jeu sélectionné devient le décor** (plein écran, sous un voile de
  lisibilité), le titre prend toute la place en bas à gauche.
- **Étagère de vignettes portrait 3:4** (les jaquettes, depuis le 2026-10-23 ; 16:9 dans le
  prototype) en bas, en carrousel (prototype des micro-interactions) : le jeu sélectionné est
  agrandi et cerné d'un **anneau fixe** à gauche, sous lequel la piste défile (demande de Marco,
  2026-10-23) ; un reflet balaie la vignette active après chaque déplacement.
- **Accent orange chaud** (`#F2802A`) pour le bouton Jouer et le soulignement ; fond noir pur.
- **État de connexion au PC host affiché en permanence** en haut (pastille : point vert + nom
  du host), pour que l'utilisateur voie d'un coup d'œil que tout marche — sans jamais voir
  d'IP ni de réglage réseau.
- **Glyphes manette dans le bloc héros** (A Jouer · Y Options) ; ailleurs, une légende discrète
  en bas à gauche (`ControllerLegend`).
- **Aucune valeur en dur dans les composants** : tout passe par `Theme.qml`, en pixels d'un
  canevas de 800 de haut que `HomeScreen` met à l'échelle de l'écran.

Fichiers (dans `app/gui/console/`) :
- `ConsoleHome.qml` — l'écran d'accueil côté logique (hosts, appairage, lancement, overlays)
- `HomeScreen.qml` — l'écran d'accueil côté présentation : assemble fond, barre haute, héros,
  étagère et panneau d'options ; règle l'entrée (quand `entryAllowed` : sortie de l'animation
  de démarrage), la dérive du fond, l'effacement au lancement. `stage` reçoit les écrans de message (`staged` efface héros et étagère et leur
  donne la manette)
- `OptionsSheet.qml` — panneau « Options » (bouton Y) en onglets (Flux, Console), sans état propre
- `LaunchScreen.qml` — écran de lancement d'un jeu (remplace l'ancien `LaunchOverlay`)
- `Sounds.qml`, `SoundBank.qml`, `sounds/` — sons de l'interface (singleton `Sounds.play("move")`)
- `PadRepeat.qml` — répétition des flèches à l'appui prolongé (étagère, options)
- `Pressable.qml` — élément qui s'écrase tant que `down` (A enfoncé) et revient avec le ressort
  « rebond » ; l'action part au relâché, chez l'appelant ; grandit au survol (`hovered`)
- `HoverArea.qml` + `Pointer.js` — zone de clic à survol (curseur en main) ; `pointed()` quand la
  souris bouge vraiment dessus (une liste y amène sa sélection)
- `Spring.js` — ressorts physiques du prototype des micro-interactions, en courbes
  `Easing.BezierSpline` (jetons `Theme.spring*`)
- `RollingNumber.qml` — nombre dont chaque chiffre roule dans sa colonne 0–9 (options)
- `StreamProfiles.js` — profils de flux : ce que chacun demande au lancement selon l'écran et le
  réseau (fonctions pures)
- `CheckMark.qml` — coche tracée trait après trait (liste Wi-Fi, fin d'un appui maintenu)
- `ElasticIndicator.qml` — indicateur dont les deux bords rejoignent la cible séparément (le
  soulignement des onglets s'étire en changeant d'onglet)
- `HoldFill.qml` — remplissage d'un appui maintenu (actions destructives : `ConsoleDialog`
  `holdToConfirm`, « Oublier ce PC », « Quitter la partie » du héros) ; libellés centrés
  (`centered`) et rebond laissé à l'appelant (`bounces: false`) pour un bouton
- `Theme.qml` (+ `qmldir`) — singleton des jetons de design : couleurs, tailles, durées, ressort
- `fonts/` — Sora embarquée (OFL, instances statiques de Google Fonts, 400 à 700), chargée par
  `Theme.qml` (`Theme.fontsReady`) ; seule famille de l'interface (pas de mono)
- `BackdropLayer.qml` — fond en fondu croisé (deux calques) + voile + dérive lente
- `HeroBlock.qml` — méta, titre, sous-titre, boutons Jouer / Options ; partie en cours, Reprendre /
  Quitter la partie à la manette (haut depuis l'étagère)
- `GameShelf.qml` — l'étagère de vignettes en carrousel : anneau fixe, piste qui défile, focus,
  répétition manette
- `SwapBox.qml`, `Appear.qml`, `ButtonGlyph.qml` — remplacement de texte en glissant (et en se
  floutant, `blur`, rendu GPU seulement), apparition en fondu-glissé, glyphe de bouton
- `Format.js` — mise en forme des données Companion (source, dernière session, temps de jeu)
- `Library.js` — l'étagère : utilitaires écartés, ordre (favoris, récents, nom), synchronisation
  du `ListModel` sans recréer les vignettes
- `Toast.qml` — message bref au-dessus de l'étagère (`homeScreen.toast(texte)`)
- `StreamCurtain.qml` — rideau CocoOS (logo de démarrage, ligne d'état) entre un jeu et
  l'accueil : posé au début du flux, levé au retour (cf §2)
- `idle/` — écran de veille (`docs/design/idle/`) : `IdleOverlay` (la veille au-dessus de l'accueil ; la
  touche qui réveille n'atteint pas l'accueil), `IdleScreen` (état → écran, fondu enchaîné, échelle de la
  grille 1280 × 720, sortie), `IdleStatus` (données ; `IdleStatusMock` + `mock/`), `IdleTheme` (jetons),
  `IdleFormat.js` (textes), `screens/` (09 à 12), `components/` (fond flou, jaquette inclinée, textes posés
  comme Chromium : `IdleText`…), `shaders/` (`build-shaders.sh`), `preview/` (aperçu, captures, parité),
  `tests/`
- `OnScreenKeyboard.qml` — clavier à l'écran, à la manette (mot de passe Wi-Fi)
- `BootSplash.qml` — animation de démarrage « le O » (`docs/boot-animation/BOOT_ANIMATION.md`,
  le prototype fait foi), pilotée par un temps `t` avancé par `FrameAnimation` ; A accélère ×4.
  Sortie : le logo vole jusqu'au `Logotype` de la barre haute (`statusBarLogo`, `mapToItem`) ;
  `exitStarted` ouvre l'entrée de l'accueil, `finished` passe le relais au vrai logo. `mode:
  "wake"` (sortie de veille) : 80 ms de noir, puis il anime le logo de la barre haute.
  Tant que `ConsoleHome.bootReady` est faux (ni jeux, ni écran de message définitif), le O de OS
  fait le chargeur (au moins 600 ms). Ses sons : `boot-close` / `boot-open`. `SystemStatus` et
  `WifiSetup` ne font leurs premiers relevés D-Bus (synchrones) qu'à sa fin (`start()`).
- `BootTimeline.js` — port pur du JavaScript du prototype de démarrage (easings, ressorts,
  chargeur, sortie), testé contre des valeurs tirées du prototype lui-même
- `shaders/` — `ConicMask.frag` (tracé du O, chargeur) et `EllipseMask.frag` (lettres qui sortent
  de derrière le O) ; les `.qsb` embarqués se régénèrent avec `shaders/build-shaders.sh` (qsb :
  SPIR-V + GLSL 100 es / 120 / 150 / 300 es, ces deux derniers pour la Mali)
- `Logotype.qml` — le logotype « CocoOS » lettre par lettre (Sora Bold), géométrie du prototype
  de `docs/boot-animation/` ; sert à la barre haute (réduit) et à l'animation de démarrage
- `icons/` — icônes SVG (punaise des favoris, engrenage des réglages)
- `shadows/` — ombres portées pré-calculées (vignette active, île), régénérées par
  `harness/make-shadows.py` si une taille change (les tests vérifient leurs dimensions)
- `languages/qml_en.ts` (+ `.qm` compilé, embarqué) — traduction anglaise de tous les textes
  console, QML et C++ (cf §11 pour la mettre à jour)
- `StatusBar.qml` — barre haute : logotype, pastille de l'hôte + horloge / Wi-Fi / batterie (éclair en
  charge, orange sous `Theme.batteryLow`) / réglages ; la pastille s'ouvre en île de notification
  (`notify`, `dismiss`) sur les événements système qu'elle détecte elle-même. Wi-Fi, batterie et
  réglages se choisissent (focus `HomeScreen.statusFocused`, souris) et ouvrent leur fiche
  (`SysCard`) ; A → `activated(key)`
- `FocusRing.qml` — anneau de focus d'un bouton (héros, icônes de la barre haute)
- `ControllerLegend.qml` — légende des boutons (glyphe + libellé), panneaux et écrans de message
- `GamePage.qml` — fiche du jeu sélectionné (bas du pad sur l'étagère), posée dans `stage` comme
  un écran de message, sur le fond du jeu : logo ou titre, faits (`Format.facts` : genres, année,
  PEGI, + taille), studios (`Format.credits`), description (`Format.plainText` : HTML Playnite →
  texte) qui défile par lignes entières, puis « Désinstaller » (jeux Steam, Companion :
  `POST /v1/games/{id}/uninstall`, confirmé). Haut une fois en haut, ou B, la referme
- `MessageScreen.qml` — écran de message à la place du héros : titre, texte, code en grandes
  cases, ligne d'état, piste d'attente. Sert à la recherche du PC, au chargement et à la
  liaison Moonlight (code à saisir sur le PC), instanciés dans `ConsoleHome`
- `ConsoleDialog.qml` — confirmation dans un panneau latéral (Annuler par défaut ; A/B, flèches)
- `CompanionPairing.qml` — saisie du code d'appairage Companion à 6 chiffres (host→console),
  sur un `MessageScreen`
- `backend/companionclient.{h,cpp}` — pont C++ vers le HostCompanion (Companion API). Build
  `embedded` uniquement. Découverte mDNS, appairage 6 chiffres, bibliothèque (copie disque),
  images de fond 16:9 en cache disque (`games()[i].background`, URL `file://` : l'`Image` QML
  ne sait pas poser le Bearer), WebSocket events (cf §2). Nécessite `QT += websockets`.
- `backend/systemstatus.{h,cpp}` — batterie, charge et autonomie (`/sys/class/power_supply`), signal
  et détails du réseau Wi-Fi (NetworkManager par D-Bus) pour la barre haute et ses fiches ; veille / redémarrage /
  extinction par systemd-logind (D-Bus, `powerActions` + `power()`). Build `embedded`
  uniquement ; `QT += dbus`.
- `backend/wifisetup.{h,cpp}` — réseaux Wi-Fi visibles, connexion (profil NetworkManager créé
  par `AddAndActivateConnection`, WPA2 ou WPA3), état « en ligne ». Build `embedded` uniquement.
- `backend/ambientcolor.{h,cpp}` — couleur dominante d'une image, pour la teinte ambiante.
  Build `embedded` uniquement.
- `backend/inputstatus.{h,cpp}` — activité de l'utilisateur (filtre d'événements sur l'app,
  pour la veille), bouton Home de la manette (état SDL lu toutes les 50 ms, la navigation
  upstream ne le traduit pas en touche), famille et batterie de la manette, et le pont QML du
  menu en jeu (`prepareStreamMenu` avant chaque flux, `takeStreamExit` au retour). Build
  `embedded` uniquement.
- `backend/streammenu.{h,cpp}` — menu en jeu et statistiques du flux (état, manette, chiffres,
  capture et flou de l'image, animations, sons par SDL), sur l'overlay de Moonlight. Build
  `embedded` uniquement.
- `backend/streampainter.{h,cpp}` — leur dessin en QPainter, jetons de `Theme.qml` recopiés ;
  sans SDL ni Moonlight (le harnais le dessine seul : `streammenu-shot.cpp`).

`ConsoleHome.qml` est **branché sur le vrai backend Moonlight** (imports
`ComputerModel`/`AppModel`/`ComputerManager`/`StreamingPreferences`/`CompanionClient`). Tout
le reste est de la présentation pure, sans dépendance Moonlight. Les deux se testent hors de
l'application dans le harnais `docs/ui/ambiant/harness/` (cf §11) : `HomeScreen` avec des jeux
de démo, et le vrai `ConsoleHome` sur de faux modules Moonlight (`stubs/`).


## Pièges QML rencontrés pendant la refonte

- `Easing.BezierSpline` : Qt (`QEasingCurve`) ne garde que **10 segments** ; au-delà il écrit hors
  de son tableau et l'interface se bloque (vu avec 12). `Spring.js` s'y tient.
- Un enfant de `card` (`GameShelf` : calque invisible qui sert de source au masque) dont `visible`
  repasse à vrai **n'est pas redessiné** : Qt ne le marque à redessiner que si sa visibilité
  effective change, et elle reste fausse sous un parent invisible. Le créer à la demande (`Loader`,
  cf. le reflet) ou jouer sur l'opacité.
- `AnimationController` déclaré dans un `TestCase` fait planter qmltestrunner : le créer dans le
  test (`Qt.createQmlObject`). Il tronque le temps en ms entières (`progress = (ms + 0,5) / durée`).
- Une propriété ne peut pas s'appeler `on<Majuscule>…` (prise pour un gestionnaire de signal) :
  le jeton `onAccent` du brief s'appelle `Theme.inkOnAccent`.
- `Rectangle.border.width` est **arrondi à l'entier** (1,5 → 2) sauf `border.pixelAligned: false`.
- `ListView.count` n'est mis à jour qu'à la mise en page suivante ; et il vaut 0 tant que le
  modèle charge : ne jamais y borner la sélection sans tester `count > 0`.
- Un composant en ligne (`component X: …`) voit les `id` du fichier tant qu'il y est instancié.
- Une couche (`layer.enabled`) est rendue à la taille de l'élément × le rapport de pixels, **sans tenir
  compte d'un `scale` d'un parent** : sous une grille agrandie, son texte est pixellisé. Poser
  `layer.textureSize` (taille × échelle × rapport de pixels) et `layer.smooth: true` (cf. `idle/`,
  `IdleTheme.textureScale`) ; même chose pour le `sourceSize` des SVG.
- Un `State` à `when:` joue sa transition **dès la création** de l'élément s'il est déjà vrai :
  les vignettes créées en défilant rejouaient leur entrée (cf. `Appear.animateInitially`).
- Relancer une animation depuis un `onXChanged` alors que sa cible (`to:`) est liée à la même
  propriété : l'ordre n'est pas garanti, l'animation peut partir avec l'ancienne cible. Poser
  `to` dans le gestionnaire (cf. `LaunchScreen.advanceBar`).
- `QT_QPA_PLATFORM=offscreen unshare -rn ./app/moonlight` : test de fumée sans réseau (aucun
  risque d'appairage ou de lancement sur le vrai PC) ; le bus D-Bus système y est injoignable.
  Rediriger la sortie vers un fichier (`> log 2>&1`) : à travers un pipe, rien n'apparaît.
- Dans `HomeScreen`, le focus suit des **liaisons** (`focus: !staged && !sheet.opened` sur
  l'étagère, `staged && !sheet.opened` sur `stage`) : il revient tout seul à la fermeture du
  panneau d'options ou d'un écran de message. Ne pas rappeler `shelf.forceActiveFocus()` en dur.
