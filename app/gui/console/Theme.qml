pragma Singleton
import QtQuick
import "Spring.js" as Spring

// Jetons de design de l'UI console. Direction CocoOS (docs/ui/cocoos/tokens.json,
// SPEC.md §1) par-dessus l'« Ambiant » d'origine (docs/ui/ambiant/) : un jeton qui désigne
// la même chose garde son nom, seule sa valeur suit CocoOS.
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
    // « Réduire les animations » (onglet Console, écrit par ConsoleHome) : pas de ressort
    // (une courbe simple et courte à la place), ni flou des textes, ni ombres, ni dérive
    // du fond, ni reflet des vignettes. Pour qui supporte mal le mouvement, et pour une
    // carte qui ne tiendrait pas ses 60 images par seconde.
    property bool reducedMotion: false
    readonly property var reducedSpring: ({ curve: curveOut, duration: 200 })

    // --- Couleurs ---
    readonly property color accent: "#F2802A"
    // Jeton `onAccent` du brief : QML réserve les noms `on<Majuscule>` aux
    // gestionnaires de signal, d'où ce nom.
    readonly property color inkOnAccent: "#1B0E04"   // accent-ink
    readonly property color ink: "#F5F5F7"
    readonly property color ink2: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.6)   // ink-secondary : métadonnées, valeurs
    readonly property color ink3: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.5)   // ink-tertiary : libellés, aides (12 px au moins)
    readonly property color inkOnLight: "#000000"    // texte posé sur ink (pastille Jouer, ligne au focus)
    readonly property color ok: "#69D08E"            // réseau bon (statistiques en jeu seulement, SPEC §1)
    readonly property color fair: "#E8C547"          // réseau moyen (latence ou gigue)
    readonly property color poor: "#FF453A"          // réseau mauvais
    readonly property color danger: poor             // hors ligne, batterie critique : toujours avec un mot
    readonly property color background: "#000000"    // noir pur (OLED)
    readonly property color blue: "#6E9BFF"          // accent alternatif, halos d'ambiance
    readonly property color accentTrack: Qt.rgba(242 / 255, 128 / 255, 42 / 255, 0.25)  // piste sous une progression
    readonly property color accentSoft: Qt.rgba(242 / 255, 128 / 255, 42 / 255, 0.22)   // fond des badges « Prêt »

    // --- Verres CocoOS : toujours avec le flou blur* correspondant et un contour hairlineStrong ---
    readonly property color glassPill: Qt.rgba(1, 1, 1, 0.08)      // barre du haut, onglets (blurPill)
    readonly property color glassGroup: Qt.rgba(1, 1, 1, 0.07)     // listes groupées
    readonly property color glassRaised: Qt.rgba(1, 1, 1, 0.12)    // bouton secondaire, touches de fonction
    readonly property color glassSheet: Qt.rgba(30 / 255, 30 / 255, 32 / 255, 0.82)   // feuilles (blurSheet)
    readonly property color glassDialog: Qt.rgba(44 / 255, 44 / 255, 46 / 255, 0.84)  // dialogues centrés, menus
    readonly property color glassHud: Qt.rgba(40 / 255, 40 / 255, 42 / 255, 0.62)     // au-dessus du jeu
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.08)       // séparateurs, décalés de space4
    readonly property color hairlineStrong: Qt.rgba(1, 1, 1, 0.12) // contour des verres
    readonly property color focusRow: Qt.rgba(1, 1, 1, 0.14)       // ligne au focus (texte en 600)
    readonly property color keyChar: Qt.rgba(1, 1, 1, 0.11)        // touches de caractères
    readonly property color keyFn: Qt.rgba(1, 1, 1, 0.055)         // touches de fonction
    readonly property color toggleOff: Qt.rgba(120 / 255, 120 / 255, 128 / 255, 0.36)
    readonly property color segmentTrack: Qt.rgba(118 / 255, 118 / 255, 128 / 255, 0.24)
    readonly property color segmentActive: "#636366"
    // Flous (px du canevas), faits une fois sur une image réduite (MultiEffect.blurMax adapté).
    readonly property int blurPill: 30
    readonly property int blurSheet: 40
    readonly property int blurBackdrop: 100

    // --- Rayons et espacements CocoOS ---
    readonly property int radiusCoverS: 8            // petites jaquettes en grille
    readonly property int radiusCover: 12            // jaquettes du carrousel et de la fiche
    readonly property int radiusKey: 14              // touches du clavier
    readonly property int radiusGroup: 20            // listes groupées, cartes
    readonly property int radiusSheet: 32            // feuilles, clavier
    readonly property int radiusDialog: 36           // dialogues centrés
    readonly property int radiusPill: 999            // pastilles, boutons, onglets
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 18                 // retrait intérieur des lignes et séparateurs
    readonly property int space5: 22                 // entre deux groupes
    readonly property int space6: 28                 // marge intérieure des feuilles
    readonly property int marginScreen: 72           // marge gauche (logo, titres)
    readonly property int marginStatus: 56           // marge droite de la barre d'état, aides

    // --- Typographie CocoOS (Sora) : { size, weight, lineHeight, spacing } ; spacing en px
    //     à cette taille (interlettrage em × taille) ---
    function textStyle(size, weight, lineHeight, em) {
        return { size: size, weight: weight, lineHeight: lineHeight, spacing: em * size }
    }
    readonly property var textDisplay: textStyle(76, 600, 1.05, -0.045)   // titre sur la fiche, la veille
    readonly property var textTitleXl: textStyle(40, 600, 1.1, -0.035)
    readonly property var textTitleL: textStyle(36, 600, 1.2, -0.03)      // étape de la configuration
    readonly property var textTitleM: textStyle(30, 600, 1.2, -0.03)      // en-tête de feuille, état vide
    readonly property var textTitleS: textStyle(20, 600, 1.3, -0.02)      // logo texte, titres de bloc
    readonly property var textButton: textStyle(17, 600, 1.2, 0)
    readonly property var textRow: textStyle(16, 500, 1.3, 0)             // 600 au focus
    readonly property var textBody: textStyle(15, 500, 1.5, 0)
    readonly property var textCaption: textStyle(13, 500, 1.4, 0)         // barre du haut, aides
    readonly property var textLabel: textStyle(12, 600, 1.3, 0.06)        // section, en capitales
    readonly property var textMicro: textStyle(11, 500, 1.3, 0.04)        // légendes, unités
    readonly property var textGlyph: textStyle(11, 700, 1, 0)             // lettre d'un glyphe

    // --- Durées et courbes CocoOS (MotionCourbes). Une sortie est plus courte que l'entrée. ---
    readonly property int durPress: 110              // appui (échelle 0,92 à 0,94)
    readonly property int durFocus: 210              // déplacement du focus
    readonly property int durExit: 260               // fermer une feuille, une bannière
    readonly property int durEnter: 560              // ouvrir une feuille, un dialogue
    readonly property int durScene: 900              // changer de scène
    readonly property var curveMain: [0.32, 0.72, 0, 1, 1, 1]         // par défaut : déplacements, fondus, panneaux
    readonly property var curveSpring: [0.3, 1.25, 0.4, 1, 1, 1]      // ce qui arrive : dialogues, bannières, focus
    readonly property var curveSpringStrong: [0.3, 1.6, 0.4, 1, 1, 1] // relâchement d'un bouton

    // --- Courbes ---
    readonly property int easeOut: Easing.OutCubic
    readonly property int easeQuint: Easing.OutQuint
    readonly property int easeExpo: Easing.OutExpo

    // --- Micro-interactions (docs/ui/micro-interactions/ : pour les durées et les
    //     courbes, le prototype fait foi) ---
    readonly property var curveOut: [0.22, 1, 0.36, 1, 1, 1]      // fondus, remplissages (BezierSpline)
    readonly property var curveInOut: [0.65, 0, 0.35, 1, 1, 1]    // reflet
    readonly property var curveExit: [0.4, 0, 1, 1, 1, 1]         // ce qui part (ease-exit CocoOS)
    // Ressorts physiques du prototype (raideur, amortissement, masse 1), en courbe pour
    // Easing.BezierSpline et durée (cf. Spring.js) : { curve, duration }.
    readonly property var springSnappy: reducedMotion ? reducedSpring : Spring.make(380, 28)   // ≈ 394 ms, dépasse de 4 % : focus, chiffres
    readonly property var springBouncy: reducedMotion ? reducedSpring : Spring.make(300, 18)   // ≈ 613 ms, 15 % : relâchement, interrupteurs
    readonly property var springGentle: reducedMotion ? reducedSpring : Spring.make(220, 24)   // ≈ 460 ms, 1 % : île, formes
    // Appui (Pressable) : A enfoncé, l'élément s'écrase en pressDuration (curveOut) ;
    // relâché, il revient avec springBouncy, et l'action part.
    readonly property int pressDuration: durPress
    readonly property real pressScale: 0.955         // bouton (Jouer)
    readonly property real pressRowScale: 0.985      // ligne d'un panneau (options, dialog)
    // Survol à la souris (HoverArea) : une liste y amène sa sélection ; un bouton grandit à
    // hoverScale (ressort « vif ») et s'éclaire en hoverFade (curveOut) ; une vignette de
    // l'étagère grandit à shelfHoverScale et remonte à shelfHoverOpacity ; un choix du
    // sélecteur de profil se pose sur un fond hoverFill.
    readonly property real hoverScale: 1.04
    readonly property int hoverFade: 160
    readonly property real shelfHoverScale: 1.04
    readonly property real shelfHoverOpacity: 0.8
    readonly property color hoverFill: Qt.rgba(1, 1, 1, 0.08)
    readonly property int chevronTouch: 8            // marge de clic autour d'un chevron ‹ ›
    // Appui maintenu (HoldFill : actions destructives) : A tenu holdDuration ms remplit la
    // ligne (affiché : progression^holdCurve) ; lâché avant, elle se vide en holdDrain ms.
    // Pleine : un rebond jusqu'à holdBounce (springBouncy.duration, curveOut), puis l'action.
    readonly property int holdDuration: 900
    readonly property int holdDrain: 280
    readonly property real holdCurve: 1.4
    readonly property real holdBounce: 1.035
    // …et, pleine, le libellé monte en s'effaçant (holdSwapShift fois sa hauteur, holdSwapMove /
    // holdSwapFade, curveOut) : une coche tracée (holdCheckDraw après holdCheckDelay) et le
    // libellé de fin prennent sa place, comme « Stream terminé » dans le prototype.
    readonly property real holdSwapShift: 0.8
    readonly property int holdSwapMove: 300
    readonly property int holdSwapFade: 200
    readonly property int holdCheckSize: 18
    readonly property int holdCheckGap: 8
    readonly property int holdCheckDelay: 140
    readonly property int holdCheckDraw: 280
    // Refus (Pressable.refuse : action indisponible, code faux) : secousse horizontale, les
    // positions du prototype réparties sur shakeDuration, courbe « ease-out » de CSS.
    readonly property int shakeDuration: 440
    readonly property var shakeKeys: [0, -9, 8, -5, 3, -1, 0]
    readonly property var shakeCurve: [0, 0, 0.58, 1, 1, 1]
    // Message qui apparaît en dépliant (ligne d'état d'un écran de message) : sa place en
    // unfoldDuration (curveOut), le texte en fondu (unfoldFade) en descendant de unfoldShift
    // px (unfoldMove).
    readonly property int unfoldDuration: 340
    readonly property int unfoldFade: 200
    readonly property int unfoldMove: 300
    readonly property int unfoldShift: 4

    // --- Polices ---
    // Embarquées (la console est hors ligne), en graisses statiques : un fichier
    // par graisse fonctionne sur tout Qt 6, contrairement aux polices variables.
    // Une seule famille, comme sur une console : pas de police à chasse fixe, les
    // chiffres qui changent (latence) prennent les chiffres tabulaires de Sora (tnum).
    readonly property string fontUi: "Sora"              // 400 / 500 / 600 / 700 (logotype)
    readonly property list<FontLoader> fontFiles: [
        FontLoader { source: "fonts/Sora-Regular.ttf" },
        FontLoader { source: "fonts/Sora-Medium.ttf" },
        FontLoader { source: "fonts/Sora-SemiBold.ttf" },
        FontLoader { source: "fonts/Sora-Bold.ttf" }
    ]
    // Toutes les polices sont chargées : avant, les métriques (logotype) seraient
    // celles d'une police de repli.
    readonly property bool fontsReady: {
        for (var i = 0; i < fontFiles.length; i++)
            if (fontFiles[i].status !== FontLoader.Ready) return false
        return true
    }

    // --- Logotype « CocoOS » (Logotype) : animation de démarrage, barre haute ---
    // Le prototype de démarrage (docs/boot-animation/) est dessiné sur un repère de
    // 1280 × 720 : ses tailles sont en pixels de ce repère.
    readonly property real bootRefHeight: 720
    readonly property real logoSize: 104             // Sora 700, « Coco » blanc, « OS » accent
    readonly property color logoBright: "#FFB076"    // le O, plus clair, pendant son tracé
    readonly property real statusLogoScale: 0.2      // dans la barre haute
    readonly property int statusLogoGap: 20          // entre le logo et la pastille de l'hôte
    // Animation de démarrage : étape en cours sous le logo pendant le chargeur
    // (repère 720), délai laissé à la découverte du PC avant de conclure « aucun PC »,
    // volume de ses deux sons (enregistrés 4 fois plus fort, cf. make-sounds.py).
    readonly property int bootStepTop: 62
    readonly property int bootStepSize: 13           // Sora 400
    readonly property color bootStepInk: "#6E6E6E"
    readonly property int bootDiscoveryGrace: 3000
    // Rideau entre un jeu et l'accueil (StreamCurtain) : le logo au repos de
    // l'animation de démarrage, la même ligne d'état (bootStep*), le O qui respire
    // pendant une attente (fermeture du jeu sur le PC).
    readonly property int curtainReveal: 320         // logo et ligne d'état, en fondu
    readonly property int curtainMinShow: 700        // le logo reste au moins ce temps
    readonly property int curtainFade: 420           // levée du rideau, easeOut
    readonly property int curtainMaxWait: 8000       // le PC ne répond pas : on lève quand même
    readonly property int curtainBreath: 1400        // période de la respiration du O
    readonly property real curtainBreathScale: 1.08

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
    // Teinte ambiante (couleur dominante du fond) : elle colore le bas du voile, en fondu
    // d'un jeu à l'autre.
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
    // Île de notification : la pastille de l'hôte s'ouvre pour un événement système (manette,
    // batterie, PC perdu ou retrouvé, réseau mauvais), puis se referme seule après islandHold.
    // Taille au ressort springGentle, rayon en islandRadiusMove (curveOut) ; contenu en fondu
    // (islandFade, curveOut) islandContentDelay après l'ouverture, islandStagger d'écart entre
    // éléments, en montant de islandShift px depuis l'échelle islandContentScale, sans flou ;
    // sortie en islandOut, forme refermée islandCloseDelay après. Une nouvelle notification
    // remplace l'ancienne sans refermer : contenu changé après islandSwap, rebond d'échelle
    // islandBounce (islandBounceDuration, curveOut). Le contenu de la pastille s'efface en
    // islandIdleOut à l'ouverture, revient en islandIdleIn après islandIdleDelay.
    readonly property size islandSize: Qt.size(340, 72)
    readonly property int islandRadius: 28
    readonly property int islandRadiusMove: 380
    // Ombre de l'île ouverte (prototype : 0 14px 34px -8px, noir à 80 %) : shadows/island.png
    // (make-shadows.py), qui déborde de islandShadowPad.
    readonly property int islandShadowPad: 65
    readonly property color islandFill: Qt.rgba(0, 0, 0, 0.88)
    readonly property int islandPadLeft: 16
    readonly property int islandPadRight: 20
    readonly property int islandGap: 12
    readonly property int islandIconSize: 40
    readonly property color islandIconFill: Qt.rgba(1, 1, 1, 0.08)
    readonly property real islandIconAccent: 0.13    // fond de l'icône d'une alerte : l'accent à tant
    readonly property int islandTitleSize: 14        // Sora 600
    readonly property int islandTextSize: 11         // ink2
    readonly property int islandValueSize: 13        // chiffres tabulaires
    readonly property int islandTextGap: 2
    readonly property int islandHostDot: 12          // point d'état, dans l'icône « PC »
    readonly property int islandContentDelay: 110
    readonly property int islandStagger: 45
    readonly property int islandFade: 340
    readonly property int islandShift: 6
    readonly property real islandContentScale: 0.96
    readonly property int islandOut: 120
    readonly property int islandCloseDelay: 110
    readonly property int islandSwap: 100
    readonly property real islandBounce: 1.025
    readonly property int islandBounceDuration: 360
    readonly property int islandIdleOut: 100
    readonly property int islandIdleIn: 160
    readonly property int islandIdleDelay: 200
    readonly property int islandHold: 2800
    readonly property int islandPoorDelay: 10000     // réseau mauvais tant de temps : notifié
    // Horloge, Wi-Fi, batterie
    readonly property int clockSize: 17              // Sora 500
    readonly property int sysGap: 14
    readonly property int wifiSize: 18
    readonly property size batterySize: Qt.size(27, 14)
    readonly property int batteryLow: 20             // en dessous (hors charge), l'icône passe en orange
    // Icônes de droite (Wi-Fi, batterie, réglages), qu'on choisit à la manette (haut depuis
    // l'étagère ou le héros), au clavier ou à la souris : une pastille de sysButtonHeight qui
    // déborde de sysButtonPad de part et d'autre de l'icône (fond hoverFill, anneau de focus
    // collé). L'icône choisie ou survolée ouvre sa fiche sous la barre (sysCardGap plus bas,
    // calée à droite) : fondu islandFade (curveOut) en descendant de sysCardShift depuis
    // l'échelle islandContentScale (ressort « souple »), sortie en islandOut. La souris a
    // sysCardHoverGrace pour passer de l'icône à la fiche.
    readonly property int sysButtonHeight: 32
    readonly property int sysButtonPad: 7
    readonly property int settingsIconSize: 20
    readonly property int sysCardWidth: 300
    readonly property int sysCardGap: 12
    readonly property int sysCardRadius: 22
    readonly property int sysCardPad: 18
    readonly property int sysCardShift: -8
    readonly property int sysCardHoverGrace: 220
    readonly property int sysCardSectionGap: 14      // entre l'en-tête, les lignes et la légende
    readonly property int sysCardLineGap: 9
    readonly property int sysCardLabelSize: 12       // ink3
    readonly property int sysCardValueSize: 13       // ink, chiffres tabulaires
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
    readonly property int heroBottom: 532            // au-dessus de l'anneau de la vignette active
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
    // Logo du jeu (Companion) à la place du titre : au plus deux lignes de haut.
    readonly property int heroLogoLines: 2
    readonly property int heroLogoMaxWidth: 460
    readonly property int heroLogoFade: 260
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
    // Partie en cours : à côté de « Reprendre la partie », « Quitter la partie » (prototype des
    // micro-interactions, bouton « Quitter le stream ») : contour de quitBorderWidth, s'écrase à
    // quitPressScale tant que A est tenu (appui maintenu, cf. HoldFill). Plein, il montre sa coche
    // quitResetDelay ms puis se vide en quitResetFade (si le jeu tourne encore).
    readonly property int quitPad: 22
    readonly property real quitBorderWidth: 1.5
    readonly property color quitBorder: "#323236"
    readonly property real quitPressScale: 0.97
    readonly property int quitResetDelay: 1700
    readonly property int quitResetFade: 260
    // Anneau de focus d'un bouton (prototype : .ring::after) : un trait de focusRingWidth à
    // focusRingInset du bouton ; il paraît en focusRingFade (curveOut) en se resserrant depuis
    // focusRingFrom (ressort « vif »).
    readonly property int focusRingInset: 5
    readonly property int focusRingWidth: 2
    readonly property int focusRingFade: 140
    readonly property real focusRingFrom: 1.025
    readonly property int playGap: 12
    readonly property int playLabelSize: 17          // Sora 600
    readonly property int playGlyphSize: 32
    readonly property int playGlyphFontSize: 12
    readonly property color optionsColor: Qt.rgba(1, 1, 1, 0.86)
    readonly property int optionsLabelSize: 16       // Sora 500
    readonly property int optionsGap: 10

    // --- Étagère de vignettes (GameShelf) ---
    readonly property int shelfBottom: 736           // bord bas des vignettes
    // Portrait 3:4 : le format des jaquettes d'Apollo / Sunshine (600 × 800), affichées entières.
    readonly property size shelfThumbSize: Qt.size(108, 144)
    readonly property int shelfGap: 14
    readonly property int shelfThumbRadius: 10
    readonly property color shelfThumbFill: "#111111"            // sous l'image, pendant son chargement
    // Carrousel du prototype des micro-interactions : avec la manette, la vignette active grandit
    // depuis son centre (ressort « vif »), les autres s'estompent (shelfFocusFade, curveOut) ;
    // A tenu, elle redescend à shelfTapScale. Sans la manette (panneau, héros), toutes reviennent.
    readonly property real shelfActiveScale: 1.08
    readonly property real shelfTapScale: 1.02
    readonly property real shelfRestOpacity: 0.48    // vignettes non sélectionnées
    readonly property int shelfFocusFade: 220        // opacité, ombre et filet
    // Un seul anneau glisse d'une vignette à l'autre (ressort « vif ») : shelfRingGap autour de
    // la vignette agrandie, un trait de shelfRingWidth puis un halo de shelfRingHalo
    // (box-shadow 0 0 0 2px, 0 0 0 7px). Sans la manette, il s'efface (shelfRingFade) en
    // rétrécissant à shelfRingHiddenScale.
    readonly property int shelfRingGap: 6
    readonly property int shelfRingRadius: 17
    readonly property int shelfRingWidth: 2
    readonly property int shelfRingHalo: 5
    readonly property color shelfRingHaloColor: "#12F2F0EC"     // ink à 7 %
    readonly property int shelfRingFade: 160
    readonly property real shelfRingHiddenScale: 0.94
    // Coins arrondis des vignettes : un masque GPU par vignette visible. Passer à
    // false (coins droits) si la carte cible ne tient pas ses 60 images par seconde.
    readonly property bool shelfRounded: true
    // Ombre portée de la vignette active (prototype : 0 18px 40px -12px, noir à 90 %) : une
    // image pré-calculée (shadows/thumb.png, harness/make-shadows.py, à relancer si la taille
    // change), qui déborde de shelfShadowPad tout autour. Un filet clair intérieur borde
    // chaque vignette (shelfEdge), plus net sur l'active (shelfEdgeActive).
    readonly property int shelfShadowPad: 78
    readonly property real shelfEdge: 0.06
    readonly property real shelfEdgeActive: 0.10
    readonly property int thumbFadeIn: 260           // la jaquette chargée apparaît en fondu
    // Jaquette en cours de chargement : une bande claire (shimmerColor, shimmerSpan de la
    // largeur) traverse la case vide en shimmerDuration, en boucle.
    readonly property color shimmerColor: Qt.rgba(1, 1, 1, 0.07)
    readonly property real shimmerSpan: 0.7
    readonly property int shimmerDuration: 1300
    // Jeu sans jaquette : dégradé teinté d'après son nom, le nom au centre.
    readonly property real placeholderSaturation: 0.28
    readonly property real placeholderLightTop: 0.22
    readonly property real placeholderLightBottom: 0.10
    readonly property int placeholderTextSize: 15    // Sora 600…
    readonly property int placeholderLines: 3        // …sur tant de lignes au plus
    readonly property int placeholderPad: 12
    readonly property color placeholderInk: Qt.rgba(1, 1, 1, 0.82)
    // Jeu épinglé : pastille orange (punaise) dans le coin haut droit de la vignette.
    readonly property int pinBadgeSize: 20
    readonly property int pinBadgeInset: 6
    readonly property int pinIconSize: 13
    // Collections (Tous, Favoris, Récents) : des onglets alignés à droite au-dessus de
    // l'étagère (L1 / R1), soulignés d'orange comme ceux du panneau ; changer de collection
    // fait glisser la piste de collectionSlide px en fondu (collectionSlideDuration). L2 / R2
    // sautent de shelfJump vignettes.
    readonly property int collectionsBottom: 30      // au-dessus des vignettes (l'anneau, son halo)
    readonly property int collectionsHeight: 24
    readonly property int collectionsGap: 18
    readonly property int collectionsSize: 14        // Sora 600 (active) / 500
    readonly property int collectionSlide: 28
    readonly property int collectionSlideDuration: 280
    readonly property int shelfJump: 10
    // Jeu en cours sur le PC : un point orange en haut à gauche de sa vignette, cerclé de
    // sombre, d'où part une onde (runningPulse ms, de 1 à runningRipple fois sa taille, en
    // s'effaçant) ; immobile avec « Réduire les animations ».
    readonly property int runningDotSize: 10
    readonly property int runningDotRing: 2
    readonly property color runningDotRingColor: Qt.rgba(0, 0, 0, 0.55)
    readonly property int runningPulse: 1600
    readonly property real runningRipple: 2.6
    // Jeu pas encore installé (fin d'étagère) : vignette estompée ; en téléchargement, fine
    // barre de progression en bas, dans les marges de la pastille.
    readonly property real shelfPendingOpacity: 0.6
    readonly property int shelfProgressHeight: 4
    readonly property color shelfProgressTrack: Qt.rgba(0, 0, 0, 0.55)
    // Reflet de la vignette active : une bande claire la balaie une fois, sheenDelay
    // après chaque déplacement (sheenDuration, curveInOut). Géométrie du prototype
    // (.tile::after) : une boîte qui déborde de 20 % de chaque côté (sheenOversize), un
    // dégradé incliné de sheenAngle sur la verticale, clair sur sheenSpan de sa longueur,
    // poussé de -sheenTravel à +sheenTravel de la largeur de la boîte.
    readonly property int sheenDelay: 520
    readonly property int sheenDuration: 950
    readonly property color sheenColor: Qt.rgba(1, 1, 1, 0.16)
    readonly property real sheenOversize: 1.4
    readonly property real sheenAngle: 15
    readonly property real sheenSpan: 0.16
    readonly property real sheenTravel: 0.75
    readonly property int underlineHeight: 3         // soulignement orange (onglets, code)
    readonly property int underlineRadius: 2

    // --- Entrées manette ---
    readonly property int repeatDelay: 360           // appui prolongé : délai avant répétition
    readonly property int repeatInterval: 120        // puis intervalle, réduit de repeatStep…
    readonly property int repeatStep: 10             // …à chaque répétition…
    readonly property int repeatMin: 55              // …jusqu'à ce plancher
    readonly property real edgeBump: 0.12            // l'anneau bute (en index) aux extrémités de la liste
    readonly property int edgeBumpHold: 90

    // --- Remplacement d'un texte en glissant (SwapBox) : valeurs des options, lancement ---
    // Le nouveau entre sur `durée` (easeQuint), l'ancien sort plus vite (easeOut).
    readonly property real swapTravel: 0.7           // distance : part de la hauteur du champ
    readonly property real swapEnterFade: 0.7        // fondu d'entrée : part de la durée
    readonly property real swapExitTravel: 0.8       // l'ancien va moins loin…
    readonly property real swapExitDuration: 0.8     // …en moins de temps…
    readonly property real swapExitFade: 0.45        // …et s'efface plus tôt
    // Changement de jeu : les textes du héros, eux, se remplacent comme dans le prototype des
    // micro-interactions (swapText) : le nouveau entre de heroSwapTravel px
    // dans le sens du déplacement (heroSwapIn, curveOut), l'ancien sort de l'autre côté
    // (heroSwapOut, curveExit) ; le sous-titre part heroSubSwapDelay après.
    readonly property int heroSwapTravel: 14
    readonly property int heroSwapIn: 380
    readonly property int heroSwapOut: 220
    readonly property int heroSubSwapDelay: 30
    // Flou du texte qui entre ou sort (blur(3px) du prototype). Rendu par un calque par texte,
    // à passer à 0 si la carte cible ne tient pas ses 60 images par seconde. swapBlurSpread :
    // rayon de MultiEffect pour cet écart type CSS.
    readonly property real swapBlur: reducedMotion ? 0 : 3
    readonly property real swapBlurSpread: 2

    // --- Réapparition d'un bloc (Appear), au retour d'un lancement ---
    readonly property int enterFade: 460             // opacité 0 → 1, linéaire
    readonly property int enterMove: 720             // glissement vers sa place, easeQuint
    readonly property int enterShift: 18             // décalage vertical de départ

    // --- Entrée de l'accueil, après l'animation de démarrage (BOOT_ANIMATION.md §7) ---
    // Courbe « emphasized » du prototype de démarrage (E_EMPH), pour Easing.BezierSpline.
    readonly property var curveEmph: [0.2, 0, 0, 1, 1, 1]
    readonly property int entryTextFade: 350         // textes (barre haute, héros) : OutCubic
    readonly property int entryLegendDelay: 300      // glyphes du héros (« légende ») : après…
    readonly property int entryCardFade: 500         // vignettes : fondu + échelle, E_EMPH…
    readonly property int entryCardDelay: 60         // …après ce délai…
    readonly property int entryCardStagger: 45       // …décalées d'autant chacune…
    readonly property int entryCardSpan: 6           // …(au plus 6 rangs d'écart)
    readonly property real entryCardScale: 0.97      // …depuis cette échelle
    readonly property int enterSettle: 1100          // après quoi plus rien n'est décalé
    readonly property int backdropZoomDuration: 1100 // easeOut (lancement)
    readonly property point backdropZoomOrigin: Qt.point(0.62, 0.46)   // fraction de l'écran
    // La dérive du fond s'arrête après ce délai sans action (économie de batterie).
    readonly property int driftIdleTimeout: 10000

    // --- Message bref (Toast), centré au-dessus de l'étagère ---
    readonly property int toastTop: 571              // sur le haut de l'étagère
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

    // --- Veille de l'écran (idle/, docs/design/idle/) ---
    readonly property int idleSeconds: 300           // inactivité avant la veille, par défaut
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
    // Un seul soulignement passe d'onglet en onglet (ElasticIndicator) : le bord avant au
    // ressort springSnappy, le bord arrière elasticTrail ms (curveOut) après elasticTrailDelay.
    readonly property int elasticTrail: 420
    readonly property int elasticTrailDelay: 40
    readonly property int tabInkIn: 220              // libellé qui devient actif (curveOut)…
    readonly property int tabInkDelay: 90            // …après ce délai ; il s'éteint en sheetFocusFade
    readonly property int sheetRowsTop: 34
    readonly property int sheetRowHeight: 60
    readonly property int sheetRowGap: 16            // entre le libellé et la valeur
    // Liste plus haute que le panneau : elle défile (sheetFocusMove, easeOut) pour garder la
    // ligne en focus visible, à sheetScrollMargin près, et s'arrête sheetListBottom au-dessus
    // de la légende ; la zone déborde de sheetViewportBleed (secousse, rebond).
    readonly property int sheetScrollMargin: 8
    readonly property int sheetListBottom: 20
    readonly property int sheetViewportBleed: 12
    readonly property int sheetEdgeFade: 28          // fondu au bord de la liste, s'il reste à voir
    // Réglages avancés (lignes `advanced`) et lignes repliées (`hidden`) : à l'ouverture, les
    // lignes du dessous glissent faire la place (springGentle), puis les nouvelles apparaissent
    // en cascade, du haut vers le bas (unfoldDelay, puis unfoldStagger d'écart, unfoldIn ms en
    // curveOut, en descendant de foldShift px) ; à la fermeture, elles s'effacent du bas vers le
    // haut (foldStaggerOut d'écart, foldOut ms) et les lignes du dessous remontent foldGlideDelay
    // après. Le texte du profil et ses chiffres se relaient de la même façon.
    readonly property int unfoldDelay: 90
    readonly property int unfoldStagger: 40
    readonly property int unfoldIn: 300
    readonly property int foldShift: 12
    readonly property int foldStaggerOut: 18
    readonly property int foldOut: 140
    readonly property int foldGlideDelay: 110
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
    // Explication d'un refus (ligne `locked` avec `hint`), dépliée sous la liste (unfold*) le
    // temps de sheetHintHold ms.
    readonly property int sheetHintTop: 10
    readonly property int sheetHintPadH: 12
    readonly property int sheetHintPadV: 10
    readonly property int sheetHintRadius: 10
    readonly property int sheetHintSize: 13
    readonly property color sheetHintFill: Qt.rgba(1, 1, 1, 0.06)
    readonly property int sheetHintHold: 3000
    // Interrupteur d'une ligne à deux états (HDR, Sons) : piste à contour fin, pouce qui
    // glisse avec springBouncy et s'étire pendant l'appui, orange qui se répand depuis la
    // place du pouce éteint (prototype « Interrupteurs »).
    readonly property size switchSize: Qt.size(48, 28)
    readonly property real switchStroke: 1.5
    readonly property color switchStrokeColor: Qt.rgba(1, 1, 1, 0.18)
    readonly property int switchInset: 3             // entre la piste et le pouce
    readonly property int switchThumb: 22
    readonly property color switchThumbFocus: "#B6B2AC"   // pouce éteint, ligne en focus : plus clair
    readonly property int switchThumbStretch: 28     // pendant l'appui…
    readonly property int switchStretch: 150         // …en tant de ms, curveOut
    readonly property int switchFillRadius: 62       // disque orange centré sur le pouce éteint…
    readonly property int switchFill: 320            // …qui grandit en tant de ms, curveOut
    readonly property int switchInkFade: 220         // couleur du pouce, curveOut
    readonly property int switchBump: 3              // butée : aller-retour de tant de px…
    readonly property int switchBumpDuration: 260    // …en tant de ms, curveOut
    // Coche tracée devant la valeur choisie d'une liste (réseau Wi-Fi connecté) : le glyphe
    // 24 × 24 du prototype, tracé en checkDraw ms (curveOut) après checkDelay, effacé en checkErase.
    readonly property int checkSize: 22
    readonly property real checkStroke: 2.4          // sur la grille 24 × 24 du glyphe
    readonly property int checkGap: 16               // entre la coche et le libellé
    readonly property int checkDraw: 300
    readonly property int checkDelay: 60
    readonly property int checkErase: 120
    // Valeur numérique (RollingNumber) : chaque chiffre roule avec springSnappy ; un
    // chiffre de tête apparaît / s'efface en rollFade (curveOut).
    readonly property int rollFade: 220
    // Butée élastique d'une valeur ou du curseur, en bout de course : elle avance dans le
    // sens poussé de rubberStep px par poussée (rubberMax au plus) en rubberOut ms
    // (curveOut), puis revient avec springBouncy, rubberHold ms après la poussée.
    readonly property int rubberStep: 5
    readonly property int rubberMax: 16
    readonly property int rubberOut: 80
    readonly property int rubberHold: 130
    // Curseur (ligne `slider` : le débit), plus haut qu'une ligne : sa piste sous le
    // libellé. Remplissage et curseur suivent la valeur avec springSnappy.
    readonly property int sheetSliderRowHeight: 100
    // Sélecteur de profil (ligne `segments`, prototype « Sélecteur de profil ») : une piste, une
    // pastille (ElasticIndicator) qui passe d'un choix à l'autre en s'étirant, puis les chiffres
    // du profil, remplacés en cascade (statsStagger d'écart, comme le swapText du prototype).
    readonly property int sheetSegmentsRowHeight: 154
    readonly property int segmentsTop: 50            // la piste, sous le libellé
    readonly property int segmentsHeight: 40
    readonly property int segmentsPad: 4
    readonly property int segmentsRadius: 14
    readonly property color segmentsTrack: Qt.rgba(1, 1, 1, 0.06)
    readonly property int segmentsPillRadius: 10
    readonly property int segmentsLabelSize: 13      // Sora 500 ; chaque case à la largeur de son libellé…
    readonly property int segmentsLabelMin: 10       // …et, s'ils ne tiennent pas tous, le texte se réduit jusque-là
    readonly property int statsTop: 12               // les chiffres, sous la piste
    readonly property int statsGap: 2                // entre l'intitulé et la valeur
    readonly property int statsLabelSize: 11         // ink3
    readonly property int statsValueSize: 14         // chiffres tabulaires
    readonly property int statsValueHeight: 20
    readonly property int statsStagger: 45
    readonly property var statsWeights: [0.22, 0.2, 0.24, 0.34]   // largeur de chaque chiffre (la priorité, plus longue)
    readonly property int profileTextSize: 13        // description du profil (sans les réglages avancés), ink2
    readonly property int profileTextLineHeight: 18  // deux lignes au plus : la hauteur des chiffres
    readonly property int sheetNoteSize: 12          // note à droite du libellé (réseau), ink3
    readonly property int sliderTrackY: 66           // centre de la piste, depuis le haut de la ligne
    readonly property int sliderRailHeight: 6
    readonly property color sliderRail: Qt.rgba(1, 1, 1, 0.12)
    readonly property size sliderThumb: Qt.size(4, 24)
    readonly property size sliderThumbFocus: Qt.size(6, 32)
    readonly property int sliderThumbGrow: 220       // curveOut
    readonly property int sliderHalo: 5              // halo de la poignée quand la ligne a le focus
    readonly property color sliderHaloFill: Qt.rgba(1, 1, 1, 0.10)
    // Un cran franchi pulse : il s'allonge jusqu'à sliderPulseScale (à sliderPulsePeak de la
    // durée) en passant à l'orange, puis revient, en sliderPulse ms (curveOut).
    readonly property int sliderPulse: 440
    readonly property real sliderPulseScale: 1.9
    readonly property real sliderPulsePeak: 0.3
    readonly property int sliderTickHeight: 10       // crans (stops), sous la piste
    readonly property int sliderTickGap: 14          // sous la piste, au-delà de la poignée (qui y passe)
    // Maintenu, le pas accélère : sliderSteps[i] à partir de sliderStepAfter[i - 1]
    // répétitions ; il marque un arrêt de sliderStopHold ms sur chaque cran.
    readonly property var sliderSteps: [1, 2, 5]
    readonly property var sliderStepAfter: [5, 14]
    readonly property int sliderStopHold: 260
    // À la souris : la poignée suit le pointeur dans une bande de sliderTouch px de haut,
    // accrochée à un cran à moins de sliderSnap Mb/s ; au-delà des bouts, la butée s'étire
    // avec résistance (sliderDragRubber px au plus, à moitié à sliderDragSpan px du bout).
    readonly property int sliderTouch: 34
    readonly property real sliderSnap: 1.6
    readonly property int sliderDragRubber: 18
    readonly property int sliderDragSpan: 60

    // --- Légende des boutons (ControllerLegend) : panneaux et écrans de message ---
    readonly property int legendSize: 14
    readonly property int legendGap: 24
    readonly property int legendGlyphGap: 10

    // --- Demande de confirmation (ConsoleDialog) : un panneau comme celui des options ---
    readonly property int dialogMessageTop: 14
    readonly property int dialogMessageSize: 15
    readonly property real dialogMessageLineHeight: 1.45
    readonly property int dialogChoicesTop: 30

    // --- Fiche du jeu (GamePage), bas du pad : à la place du héros, sur le fond du jeu ---
    readonly property int gamePageTop: 108           // sous la barre haute
    readonly property int gamePageLogoHeight: 96
    readonly property int gamePageTitleSize: 48      // Sora 600
    readonly property int gamePageLineGap: 6
    readonly property int gamePageFactsTop: 8        // les faits, sous le titre
    readonly property int gamePageTextTop: 24        // la description, sous les studios
    readonly property int gamePageTextSize: 16
    readonly property real gamePageTextLineHeight: 1.5
    readonly property int gamePageScrollLines: 3     // lignes de description par appui
    readonly property int gamePageScroll: 220        // easeOut
    readonly property int gamePageButtonBottom: 24   // entre le bouton et la légende
    readonly property color gamePageButtonFill: Qt.rgba(1, 1, 1, 0.06)
    readonly property color gamePageButtonFocusFill: Qt.rgba(1, 1, 1, 0.16)

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
    readonly property color codeCellHoverFill: Qt.rgba(1, 1, 1, 0.09)   // survolée à la souris
    readonly property int codeDigitSize: 40          // 500
    readonly property int codeUnderlineInset: 16     // soulignement orange de la case en cours de saisie
    // Attente sans durée connue : un segment orange parcourt la piste de lancement.
    readonly property real waitBarSpan: 0.28         // part de la piste
    readonly property int waitBarSweep: 1400         // un passage, InOutCubic

    // --- Lancement d'un jeu : l'accueil s'efface, LaunchScreen prend l'écran ---
    // C'est la seule animation « signature » de l'interface.
    readonly property int launchPress: 120           // le bouton Jouer reste enfoncé, puis l'écran de lancement s'ouvre
    readonly property int launchHide: 260            // barre haute, héros et étagère s'effacent
    readonly property int launchHeroShift: -28       // le héros part vers la gauche
    readonly property int launchShelfShift: 26       // l'étagère descend
    readonly property real launchBackdropZoom: 1.12  // le fond zoome (backdropZoomDuration)…
    readonly property int launchScrimFade: 700       // …et son voile disparaît
    // L'illustration du jeu apparaît en plein écran, avec un léger zoom arrière.
    // La vignette grandit jusqu'au plein écran (prototype : ressort « souple » étiré de 80 ms).
    readonly property int launchGrow: springGentle.duration + 80
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
    readonly property int launchClose: 560           // retour à l'accueil (annulation, erreur), en fondu
    // …ou, parti de la vignette, il y retourne : la progression s'efface, puis le cadre rétrécit
    // jusqu'à elle (launchShrink après launchShrinkDelay, curveShrink) en rendant la jaquette.
    readonly property int launchShrink: 420
    readonly property int launchShrinkDelay: 90
    readonly property var curveShrink: [0.32, 0.72, 0, 1, 1, 1]
    // Indication en bas d'écran (« B Annuler »)
    readonly property int hintBottom: 26
    readonly property int hintPadV: 8
    readonly property int hintPadH: 14
    readonly property int hintGap: 10
    readonly property int hintSize: 13
    readonly property color hintFill: Qt.rgba(0, 0, 0, 0.5)
    readonly property real hintOpacity: 0.8

    // --- Sons (Sounds, pack CocoOS) ---
    // Niveau commun des sons de l'interface (celui du SoundBank de référence) : les
    // fichiers sont déjà mastérisés, de −27 à −6 dBFS en crête.
    readonly property real soundVolume: 0.8
    readonly property int navFastInterval: 90        // nav_move_fast : 11 par seconde au plus
    readonly property int ambianceFadeIn: 1800       // fondu croisé des ambiances
    readonly property int ambianceFadeOut: 900
}
