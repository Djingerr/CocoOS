pragma Singleton
import QtQuick

// Jetons de design de l'UI console (écran « Ambiant »).
// Source de vérité : docs/ui/ambiant/AMBIANT-BRIEF.md + ambiant-prototype.html.
// Aucune valeur en dur dans les composants : couleurs, tailles, durées et
// courbes passent toutes par ce fichier.
//
// Unités : pixels du canevas de référence 1280 × 800. La racine de l'écran
// applique `scale` UNE fois (transformation) ; les composants utilisent donc ces
// valeurs telles quelles, sans jamais les multiplier eux-mêmes.
QtObject {
    // --- Canevas ---
    readonly property int canvasWidth: 1280
    readonly property int canvasHeight: 800
    // Pixels écran par pixel de canevas (hauteur de l'écran / canvasHeight).
    // Écrit par la racine de l'écran ; sert aussi au sourceSize des images.
    property real scale: 1
    readonly property int margin: 72                 // marge latérale commune

    // --- Couleurs ---
    readonly property color accent: "#F2802A"
    // Jeton `onAccent` du brief : QML réserve les noms `on<Majuscule>` aux
    // gestionnaires de signal, d'où ce nom.
    readonly property color inkOnAccent: "#160B03"
    readonly property color ink: "#F2F0EC"
    readonly property color ink2: "#A19D97"
    readonly property color ink3: "#7C7973"          // indications discrètes (chevrons, glyphes d'aide)
    readonly property color ok: "#69D08E"            // hôte connecté, réseau bon
    readonly property color fair: "#E8C547"          // réseau moyen (latence ou gigue)
    readonly property color poor: "#E5574F"          // réseau mauvais
    readonly property color background: "#000000"    // noir pur (OLED)

    // --- Courbes ---
    readonly property int easeOut: Easing.OutCubic
    readonly property int easeQuint: Easing.OutQuint
    readonly property int easeExpo: Easing.OutExpo

    // --- Polices ---
    // Embarquées (la console est hors ligne), en graisses statiques : un fichier
    // par graisse fonctionne sur tout Qt 6, contrairement aux polices variables.
    // Une seule famille, comme sur une console : pas de police à chasse fixe, les
    // chiffres qui changent (latence) prennent les chiffres tabulaires de Sora (tnum).
    readonly property string fontUi: "Sora"              // 400 / 500 / 600
    readonly property list<FontLoader> fontFiles: [
        FontLoader { source: "fonts/Sora-Regular.ttf" },
        FontLoader { source: "fonts/Sora-Medium.ttf" },
        FontLoader { source: "fonts/Sora-SemiBold.ttf" }
    ]

    // --- Fond (BackdropLayer) ---
    readonly property int backdropDebounce: 140      // attente après le dernier déplacement
    readonly property int backdropFade: 560          // fondu croisé, easeOut
    readonly property int backdropHold: 700          // délai avant de vider l'ancien calque
    // Dérive lente : de driftScaleFrom à driftScaleTo + décalage, puis retour.
    readonly property real driftScaleFrom: 1.03
    readonly property real driftScaleTo: 1.09
    readonly property point driftShift: Qt.point(-0.01, -0.006)   // fraction de la taille du fond
    readonly property point driftOrigin: Qt.point(0.60, 0.45)     // centre du zoom, idem
    readonly property int driftDuration: 30000       // un aller, InOutSine
    // Voile de lisibilité : trois dégradés noirs superposés.
    readonly property Gradient scrimLeft: Gradient {         // de gauche à droite
        orientation: Gradient.Horizontal
        GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.84) }
        GradientStop { position: 0.30; color: Qt.rgba(0, 0, 0, 0.58) }
        GradientStop { position: 0.58; color: Qt.rgba(0, 0, 0, 0.10) }
        GradientStop { position: 0.72; color: Qt.rgba(0, 0, 0, 0) }
    }
    readonly property Gradient scrimBottom: Gradient {       // de bas en haut
        GradientStop { position: 0.56; color: Qt.rgba(0, 0, 0, 0) }
        GradientStop { position: 0.78; color: Qt.rgba(0, 0, 0, 0.50) }
        GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.92) }
    }
    // Teinte ambiante (couleur dominante du fond) : elle colore le bas du voile et le
    // soulignement de la vignette active, en fondu d'un jeu à l'autre.
    readonly property real ambientTintBottom: 0.20   // opacité de la teinte au bas de l'écran
    readonly property real ambientTintStart: 0.55    // hauteur (part de l'écran) où elle commence
    readonly property int ambientFade: 700
    readonly property Gradient scrimTop: Gradient {          // de haut en bas
        GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.50) }
        GradientStop { position: 0.16; color: Qt.rgba(0, 0, 0, 0) }
    }

    // --- Barre haute (StatusBar) ---
    readonly property int topBarY: 26
    readonly property int topBarHeight: 40
    // Pastille de l'hôte : point d'état, nom, puis détail (latence ou « connexion… »).
    readonly property color hostPillFill: Qt.rgba(0, 0, 0, 0.42)
    readonly property color hostPillStroke: Qt.rgba(1, 1, 1, 0.12)   // filet intérieur 1 px
    readonly property int hostPillPadLeft: 12
    readonly property int hostPillPadRight: 14
    readonly property int hostPillPadV: 8
    readonly property int hostPillGap: 10
    readonly property int hostDotSize: 7
    readonly property int hostDotBlink: 1100         // période du clignotement « connexion… »
    readonly property real hostDotBlinkMin: 0.2
    readonly property int hostNameSize: 14           // Sora 500
    readonly property int hostDetailSize: 12         // ink2, chiffres tabulaires
    // Horloge, Wi-Fi, batterie
    readonly property int clockSize: 17              // Sora 500
    readonly property int sysGap: 14
    readonly property int wifiSize: 18
    readonly property size batterySize: Qt.size(27, 14)
    readonly property int batteryLow: 20             // en dessous (hors charge), l'icône passe en orange
    // Manette sans fil : silhouette, puis trois barres de charge (orange à une barre).
    readonly property size padIconSize: Qt.size(24, 16)
    readonly property int padBarsGap: 3
    readonly property real boltStroke: 1.8           // éclair de la charge, sur sa grille 10 × 16
    readonly property int boltGap: 4                 // entre l'éclair et la batterie
    readonly property color inkOff: Qt.rgba(1, 1, 1, 0.28)           // segment éteint d'une icône

    // --- Glyphe de bouton de manette (ButtonGlyph) ---
    readonly property int glyphSize: 22
    readonly property real glyphBorder: 1.5
    readonly property real glyphFontSize: 10.5       // 500
    readonly property real glyphSymbolScale: 0.42    // symboles PlayStation, part du diamètre
    readonly property real glyphPillScale: 1.5       // gâchettes (LB, L1…) : largeur / hauteur
    // Glyphes à dessiner : "xbox", "playstation" ou "nintendo" (posé par ConsoleHome
    // d'après la manette branchée ou le réglage « Boutons »).
    property string buttonLayout: "xbox"

    // --- Bloc héros (HeroBlock), ancré par le bas : il grandit vers le haut ---
    readonly property int heroBottom: 586
    readonly property int heroWidth: 660
    // Méta : source | dernière session
    readonly property color heroMetaColor: Qt.rgba(1, 1, 1, 0.78)
    readonly property int heroMetaSize: 14           // Sora 500
    readonly property int heroMetaHeight: 20
    readonly property int heroMetaGap: 12
    readonly property color heroSeparatorColor: Qt.rgba(1, 1, 1, 0.36)
    readonly property int heroSeparatorHeight: 12    // filet vertical de 1 px
    // Titre
    readonly property int heroTitleSize: 64          // Sora 600
    readonly property real heroTitleLineHeight: 66.56    // interligne 1.04
    readonly property real heroTitleSpacing: -1.792      // -0.028 em
    readonly property int heroTitleMaxLines: 2
    readonly property int heroTitleTopMargin: 12
    readonly property int heroTitlePadBottom: 6
    readonly property int heroTitleResize: 460       // easeQuint, quand le nombre de lignes change
    // Sous-titre : temps de jeu, puis mise à jour éventuelle
    readonly property color heroSubColor: Qt.rgba(1, 1, 1, 0.76)
    readonly property int heroSubSize: 15            // Sora 400
    readonly property int heroSubHeight: 22
    readonly property int heroSubTopMargin: 10
    readonly property int heroSubGap: 18
    readonly property int heroUpdateDotSize: 6       // puce carrée orange, rayon 1
    readonly property int heroUpdateDotGap: 10
    // Actions : bouton « Jouer », puis « Options »
    readonly property int heroActionsTopMargin: 26
    readonly property int heroActionsGap: 26
    readonly property int playHeight: 52
    readonly property int playPadLeft: 10
    readonly property int playPadRight: 26
    readonly property int playGap: 12
    readonly property int playLabelSize: 17          // Sora 600
    readonly property int playGlyphSize: 32
    readonly property int playGlyphFontSize: 12
    readonly property color optionsColor: Qt.rgba(1, 1, 1, 0.86)
    readonly property int optionsLabelSize: 16       // Sora 500
    readonly property int optionsGap: 10

    // --- Étagère de vignettes (GameShelf) ---
    readonly property int shelfBottom: 736           // bord bas des vignettes
    readonly property size shelfThumbSize: Qt.size(176, 99)      // 16:9
    readonly property int shelfGap: 14
    readonly property int shelfThumbRadius: 8
    readonly property color shelfThumbFill: "#111111"            // sous l'image, pendant son chargement
    readonly property real shelfActiveScale: 1.18    // vignette du jeu sélectionné
    readonly property int shelfActiveLift: 8
    readonly property real shelfRestOpacity: 0.5     // vignettes non sélectionnées
    readonly property real shelfExitFade: 1.6        // estompage des vignettes qui sortent par la gauche
    // Coins arrondis des vignettes : un masque GPU par vignette visible. Passer à
    // false (coins droits) si la carte cible ne tient pas ses 60 images par seconde.
    readonly property bool shelfRounded: true
    readonly property int thumbFadeIn: 260           // la jaquette chargée apparaît en fondu
    // Jeu sans jaquette : dégradé teinté d'après son nom, le nom au centre.
    readonly property real placeholderSaturation: 0.28
    readonly property real placeholderLightTop: 0.22
    readonly property real placeholderLightBottom: 0.10
    readonly property int placeholderTextSize: 15    // Sora 600, deux lignes au plus
    readonly property int placeholderPad: 12
    readonly property color placeholderInk: Qt.rgba(1, 1, 1, 0.82)
    // Jeu épinglé : pastille orange (punaise) dans le coin haut droit de la vignette.
    readonly property int pinBadgeSize: 20
    readonly property int pinBadgeInset: 6
    readonly property int pinIconSize: 13
    readonly property int underlineY: 750            // soulignement orange sous la vignette active
    readonly property int underlineHeight: 3
    readonly property int underlineRadius: 2

    // --- Mouvement de l'étagère : un seul ressort, sur la position (en index) ---
    // Mêmes paramètres que le réglage « T » du prototype. epsilon doit rester
    // petit : la position est un index, l'animation s'arrêterait visiblement trop tôt.
    readonly property real springStrength: 2.2
    readonly property real springDamping: 0.30
    readonly property real springMass: 1
    readonly property real springEpsilon: 0.0005

    // --- Entrées manette ---
    readonly property int repeatDelay: 360           // appui prolongé : délai avant répétition
    readonly property int repeatInterval: 120        // puis intervalle, réduit de repeatStep…
    readonly property int repeatStep: 10             // …à chaque répétition…
    readonly property int repeatMin: 55              // …jusqu'à ce plancher
    readonly property real edgeBump: 0.12            // rebond (en index) aux extrémités de la liste
    readonly property int edgeBumpHold: 90

    // --- Changement de jeu : les textes du héros se remplacent en glissant (SwapBox) ---
    // Le nouveau entre sur `durée` (easeQuint), l'ancien sort plus vite (easeOut).
    readonly property real swapTravel: 0.7           // distance : part de la hauteur du champ
    readonly property real swapEnterFade: 0.7        // fondu d'entrée : part de la durée
    readonly property real swapExitTravel: 0.8       // l'ancien va moins loin…
    readonly property real swapExitDuration: 0.8     // …en moins de temps…
    readonly property real swapExitFade: 0.45        // …et s'efface plus tôt
    readonly property int heroMetaSwap: 300
    readonly property int heroMetaSwapDelay: 0
    readonly property int heroTitleSwap: 460
    readonly property int heroTitleSwapDelay: 40
    readonly property int heroSubSwap: 300
    readonly property int heroSubSwapDelay: 90

    // --- Entrée de l'écran (une seule fois) : chaque bloc apparaît en cascade ---
    readonly property int enterFade: 460             // opacité 0 → 1, linéaire
    readonly property int enterMove: 720             // glissement vers sa place, easeQuint
    readonly property int enterShift: 18             // décalage vertical de départ
    readonly property int enterStagger: 60           // délai par rang :
    readonly property int enterRankHero: 1           //   barre haute 0, héros 1,
    readonly property int enterRankShelf: 2          //   vignettes 2 + index…
    readonly property int enterRankShelfSpan: 5      //   …(au plus 5 rangs d'écart),
    readonly property int enterRankUnderline: 3      //   soulignement 3
    readonly property int enterSettle: 1300          // après quoi plus rien n'est décalé
    // Le fond entre avec un léger zoom arrière et un fondu.
    readonly property real backdropEnterZoom: 1.06
    readonly property int backdropZoomDuration: 1100 // easeOut
    readonly property int backdropEnterFade: 900
    readonly property point backdropZoomOrigin: Qt.point(0.62, 0.46)   // fraction de l'écran
    // La dérive du fond s'arrête après ce délai sans action (économie de batterie).
    readonly property int driftIdleTimeout: 10000

    // --- Message bref (Toast), centré au-dessus de l'étagère ---
    readonly property int toastTop: 650
    readonly property int toastMaxWidth: 760
    readonly property int toastPadH: 20
    readonly property int toastPadV: 12
    readonly property color toastFill: Qt.rgba(24 / 255, 24 / 255, 26 / 255, 0.96)
    readonly property color toastStroke: Qt.rgba(1, 1, 1, 0.10)
    readonly property int toastSize: 15              // Sora 400
    readonly property int toastShadowOffset: 20
    readonly property int toastShadowBlur: 40
    readonly property color toastShadow: Qt.rgba(0, 0, 0, 0.5)
    readonly property int toastFade: 220             // linéaire
    readonly property int toastMove: 340             // easeQuint
    readonly property int toastShift: 10             // il monte de cette distance en apparaissant
    readonly property int toastDuration: 2600

    // --- Écran de démarrage (BootSplash), comme le thème Plymouth ---
    readonly property int splashSize: 72             // Sora 600, « Coco » en encre, « OS » en accent
    readonly property real splashSpacing: -2
    readonly property int splashHold: 1100           // puis il s'efface pendant que l'accueil entre
    readonly property int splashFade: 600

    // --- Veille de l'écran (SleepScreen, « .sleep » du prototype) ---
    readonly property int sleepMinutes: 5            // inactivité avant la veille, par défaut
    readonly property int sleepFade: 520             // linéaire
    readonly property int wakeFade: 320
    readonly property int sleepTextDelay: 900        // la phrase apparaît…
    readonly property int sleepTextFade: 400
    readonly property int sleepTextHold: 8000        // …puis s'efface : noir complet (OLED)
    readonly property int sleepTextSize: 14          // Sora 400, ink3
    // Bouton Home ignoré juste après le retour d'un jeu : il peut être encore enfoncé.
    readonly property int homeGuard: 1500

    // --- Réveil du PC (Wake-on-LAN) ---
    readonly property int autoWakeDelay: 4000        // PC hors ligne au démarrage : réveil d'office après…
    readonly property int wakeTimeout: 90000         // …puis abandon s'il ne répond pas (démarrage à froid)
    readonly property int companionWait: 8000        // PC réveillé : délai laissé au Companion pour se reconnecter
    readonly property real wakeStepProgress: 0.35    // avancement affiché de l'étape « Réveil » tant qu'il dort

    readonly property int wifiRescan: 10000          // liste des réseaux rafraîchie pendant qu'elle est ouverte

    // --- Clavier à l'écran (OnScreenKeyboard), en bas de l'écran ---
    readonly property int keyboardHeight: 430
    readonly property int keyboardPadTop: 28
    readonly property int keyboardPromptSize: 15     // Sora 400, ink2
    readonly property int keyboardFieldGap: 10
    readonly property int keyboardFieldHeight: 48
    readonly property int keyboardFieldPad: 18
    readonly property int keyboardFieldSize: 20
    readonly property int keyboardKeysTop: 22
    readonly property size keyboardKeySize: Qt.size(64, 48)
    readonly property int keyboardKeyGap: 8
    readonly property int keyboardKeyRadius: 10
    readonly property color keyboardKeyFill: Qt.rgba(1, 1, 1, 0.07)
    readonly property int keyboardKeyTextSize: 18    // Sora 500

    // --- Panneau d'options (OptionsSheet), bouton Y ---
    readonly property int sheetWidth: 472
    readonly property color sheetFill: Qt.rgba(18 / 255, 18 / 255, 20 / 255, 0.95)
    readonly property color sheetEdge: Qt.rgba(1, 1, 1, 0.08)        // filet sur son bord gauche
    readonly property int sheetSlide: 440            // glissement depuis la droite, easeQuint
    readonly property real sheetDim: 0.62            // assombrissement du reste de l'écran
    readonly property int sheetDimFade: 320
    readonly property int sheetPadTop: 44
    readonly property int sheetPadSide: 44
    readonly property int sheetPadBottom: 34
    readonly property int sheetTitleSize: 26         // Sora 600
    readonly property real sheetTitleSpacing: -0.26  // -0.01 em
    readonly property int sheetHostTop: 8            // point d'état + nom de l'hôte, sous le titre
    readonly property int sheetHostGap: 8
    readonly property int sheetHostSize: 14
    readonly property int sheetTabsTop: 24           // onglets, sous le nom de l'hôte
    readonly property int sheetTabGap: 18
    readonly property int sheetTabHeight: 28         // libellé + soulignement orange
    readonly property int sheetTabSize: 16           // Sora 600 (actif) / 500
    readonly property int sheetRowsTop: 34
    readonly property int sheetRowHeight: 60
    readonly property int sheetRowGap: 16            // entre le libellé et la valeur
    readonly property int sheetLabelSize: 17
    readonly property color sheetFocusFill: Qt.rgba(1, 1, 1, 0.10)   // surlignage de la ligne en focus
    readonly property int sheetFocusRadius: 14
    readonly property int sheetFocusOutset: 16       // il déborde de la ligne de chaque côté
    readonly property int sheetFocusMove: 220        // easeOut
    readonly property int sheetFocusFade: 160        // couleur du libellé, chevrons
    readonly property int sheetValueSize: 14
    readonly property size sheetValueBox: Qt.size(136, 20)   // « Natif 2560×1600 » : 119 px
    readonly property int sheetValueGap: 6           // entre la valeur et ses chevrons
    readonly property int sheetValueSwap: 260        // l'ancienne valeur sort, la nouvelle entre…
    readonly property int sheetValueTravel: 36       // …en glissant de cette distance
    readonly property int sheetChevronSize: 18
    readonly property int signalBarWidth: 3          // signal d'un réseau Wi-Fi : 4 barres
    readonly property int signalBarStep: 3           // hauteur ajoutée par barre
    readonly property int signalBarGap: 2
    readonly property int sheetHintRight: 24         // retrait du glyphe (A) de la ligne « Oublier ce PC »

    // --- Légende des boutons (ControllerLegend) : panneaux et écrans de message ---
    readonly property int legendSize: 14
    readonly property int legendGap: 24
    readonly property int legendGlyphGap: 10

    // --- Demande de confirmation (ConsoleDialog) : un panneau comme celui des options ---
    readonly property int dialogMessageTop: 14
    readonly property int dialogMessageSize: 15
    readonly property real dialogMessageLineHeight: 1.45
    readonly property int dialogChoicesTop: 30

    // --- Écrans de message (MessageScreen) : recherche du PC, appairage ---
    // À la place du héros : même ancrage (heroBottom), même titre, puis le texte
    // dans le style du sous-titre, un code éventuel et une ligne d'état.
    readonly property int messageTextTop: 14
    readonly property int messageBlockTop: 30        // code, puis ligne d'état
    readonly property int messageSwap: 260           // l'écran sortant s'efface, puis le suivant entre
    readonly property size codeCellSize: Qt.size(64, 84)
    readonly property int codeCellGap: 12
    readonly property int codeCellRadius: 14
    readonly property color codeCellFill: Qt.rgba(1, 1, 1, 0.06)
    readonly property color codeCellFocusFill: Qt.rgba(1, 1, 1, 0.12)   // case en cours de saisie
    readonly property int codeDigitSize: 40          // 500
    readonly property int codeUnderlineInset: 16     // soulignement orange de la case en cours de saisie
    // Attente sans durée connue : un segment orange parcourt la piste de lancement.
    readonly property real waitBarSpan: 0.28         // part de la piste
    readonly property int waitBarSweep: 1400         // un passage, InOutCubic

    // --- Lancement d'un jeu : l'accueil s'efface, LaunchScreen prend l'écran ---
    // C'est la seule animation « signature » de l'interface.
    readonly property real launchPressScale: 0.95    // le bouton Jouer s'enfonce…
    readonly property int launchPress: 120           // …puis l'écran de lancement s'ouvre
    readonly property int launchHide: 260            // barre haute, héros et étagère s'effacent
    readonly property int launchHeroShift: -28       // le héros part vers la gauche
    readonly property int launchShelfShift: 26       // l'étagère descend
    readonly property real launchBackdropZoom: 1.12  // le fond zoome (backdropZoomDuration)…
    readonly property int launchScrimFade: 700       // …et son voile disparaît
    // L'illustration du jeu apparaît en plein écran, avec un léger zoom arrière.
    readonly property int launchGrow: 620            // la vignette grandit jusqu'au plein écran, easeQuint
    readonly property int launchImageDelay: 180
    readonly property int launchImageFade: 560
    readonly property real launchImageZoom: 1.12
    readonly property int launchImageSettle: 1200    // easeQuint
    // Puis un voile noir la calme, et la progression apparaît.
    readonly property real launchShade: 0.64
    readonly property int launchShadeDelay: 420
    readonly property int launchShadeFade: 420
    readonly property int launchProgressDelay: 640
    readonly property int launchProgressFade: 240
    readonly property int launchProgressMove: 360    // easeQuint
    readonly property int launchProgressShift: 8
    readonly property int launchProgressWidth: 420   // bloc centré
    readonly property int launchProgressY: 568
    readonly property int launchStageSize: 13        // ligne d'étape
    readonly property int launchStageHeight: 22
    readonly property int launchStageSwap: 340
    readonly property int launchTrackTop: 12
    readonly property int launchTrackHeight: 2
    readonly property color launchTrackColor: Qt.rgba(1, 1, 1, 0.16)
    readonly property int launchStep: 680            // la barre avance d'une étape, InOutCubic
    readonly property int launchMessageTop: 10       // message d'erreur, sous la ligne d'étape
    readonly property int launchMessageSize: 14
    // Ouverture terminée (l'écran couvre tout, la progression est en place) : c'est
    // seulement alors que Moonlight démarre le flux, qui fige l'interface un instant.
    readonly property int launchOpened: 1000
    readonly property int launchStreamStages: 10     // étapes de connexion de Moonlight, environ
    readonly property int launchClose: 560           // retour à l'accueil (annulation, erreur)
    // Indication en bas d'écran (« B Annuler »)
    readonly property int hintBottom: 26
    readonly property int hintPadV: 8
    readonly property int hintPadH: 14
    readonly property int hintGap: 10
    readonly property int hintSize: 13
    readonly property color hintFill: Qt.rgba(0, 0, 0, 0.5)
    readonly property real hintOpacity: 0.8

    // --- Sons (Sounds) ---
    // 0,125 redonne le niveau du prototype (les fichiers sont enregistrés 8 fois
    // plus fort, cf. make-sounds.py) ; monter pour des sons plus présents.
    readonly property real soundVolume: 0.125
}
