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
    // Un mouvement CocoOS { curve, duration } ; avec « Réduire les animations » : reducedSpring.
    function motion(duration, curve) { return reducedMotion ? reducedSpring : { curve: curve, duration: duration } }

    // --- Couleurs ---
    // L'accent : celui de la marque, l'accent choisi, ou celui du jeu sélectionné (MotionAccent,
    // posé par ConsoleHome) ; il passe de l'un à l'autre en 900 ms. Ses dérivés le suivent.
    readonly property color brand: "#F2802A"
    property color accent: brand
    Behavior on accent {
        ColorAnimation {
            duration: Theme.reducedMotion ? Theme.reducedSpring.duration : Theme.accentShift
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
        }
    }
    readonly property int accentShift: 900
    // Jeton `onAccent` du brief : QML réserve les noms `on<Majuscule>` aux
    // gestionnaires de signal, d'où ce nom.
    readonly property color inkOnAccent: "#1B0E04"   // accent-ink
    readonly property color ink: "#F5F5F7"
    readonly property color ink2: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.6)   // ink-secondary : métadonnées, valeurs
    readonly property color ink3: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.5)   // ink-tertiary : libellés, aides (12 px au moins)
    readonly property color inkOnLight: "#000000"    // texte posé sur ink (pastille Jouer, ligne au focus)
    readonly property color inkDark: "#1C1C1E"       // icônes sur une surface claire (curseurs remplis)
    readonly property color ok: "#69D08E"            // réseau bon (statistiques en jeu seulement, SPEC §1)
    readonly property color fair: "#E8C547"          // réseau moyen (latence ou gigue)
    readonly property color poor: "#FF453A"          // réseau mauvais
    readonly property color danger: poor             // hors ligne, batterie critique : toujours avec un mot
    readonly property color background: "#000000"    // noir pur (OLED)
    readonly property color blue: "#6E9BFF"          // accent alternatif, halos d'ambiance
    readonly property color accentTrack: Qt.rgba(accent.r, accent.g, accent.b, 0.25)  // piste sous une progression
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.22)   // fond des badges « Prêt »

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
        FontLoader { source: "fonts/Sora-Bold.ttf" },
        // こんにちは de Bonjour (SetupHello) : Noto Sans CJK JP en 600, réduite à ces cinq
        // caractères (OFL, 5 Ko), pour ne rien attendre des polices du système.
        FontLoader { source: "fonts/NotoSansJP-Hello.otf" }
    ]
    readonly property string fontHelloJp: "CocoOS Hello JP"
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
    readonly property real statusLogoScale: 0.173    // dans la barre haute : « CocoOS » de 20 px (AccueilCarrousel)
    readonly property int statusLogoGap: 20          // entre le logo et la pastille de l'hôte
    // Animation de démarrage : étape en cours sous le logo pendant le chargeur
    // (repère 720), délai laissé à la découverte du PC avant de conclure « aucun PC »,
    // volume de ses deux sons (enregistrés 4 fois plus fort, cf. make-sounds.py).
    readonly property int bootStepTop: 62
    readonly property int bootStepSize: 13           // Sora 400
    readonly property color bootStepInk: "#6E6E6E"
    readonly property int bootDiscoveryGrace: 3000
    // Rideau entre un jeu et l'accueil (StreamCurtain) : l'image du jeu, floutée, puis
    // l'anneau pendant une attente (fermeture du jeu sur le PC).
    readonly property int curtainReveal: 320         // image et ligne d'état, en fondu
    readonly property int curtainMinShow: 700        // l'image reste au moins ce temps
    readonly property int curtainMaxWait: 8000       // le PC ne répond pas : on lève quand même

    // --- Fond (BackdropLayer) : l'art du jeu flouté (AccueilCarrousel, MotionNavigation) ---
    readonly property int backdropDebounce: 140      // attente après le dernier déplacement
    readonly property int backdropFade: 900          // fondu croisé d'un jeu à l'autre
    readonly property int backdropHold: 700          // délai avant de vider l'ancien calque
    readonly property int backdropInset: 100         // l'image déborde de l'écran (inset : -100px)
    // Copie réduite de l'image (écran + débord, 1480 × 1000 → 1/10), floutée une fois : le
    // blur(100px) de la maquette y vaut une dizaine de pixels.
    readonly property size backdropBlurSize: Qt.size(148, 100)
    readonly property int backdropBlurMax: 32
    // Dérive lente (cocoBgPan) : de backdropPanScaleFrom à To et décalage (px), aller-retour.
    readonly property real backdropPanScaleFrom: 1.25
    readonly property real backdropPanScaleTo: 1.34
    readonly property point backdropPanShift: Qt.point(-30, 16)
    readonly property int driftDuration: 60000       // un aller, InOutSine
    // Vignettage radial vers le noir (ellipse à 50 % 40 %) et grain en « overlay ».
    readonly property real vignetteIn: 0.25
    readonly property real vignetteOut: 0.85
    readonly property real vignetteOutEmpty: 0.9     // état vide (EtatFavorisVide)
    readonly property point vignetteAt: Qt.point(0.5, 0.4)       // centre (ellipse à 50 % 40 %)
    readonly property point vignetteAtFiche: Qt.point(0.26, 0.5) // fiche : vers la jaquette
    readonly property real vignetteInFiche: 0.3
    readonly property real vignetteOutFiche: 0.84
    readonly property real grainOpacity: 0.07
    readonly property int grainSize: 256             // côté de images/grain.png

    // --- Carrousel 3D (CoverFlow ; AccueilCarrousel, MotionNavigation, MotionJaquettes) ---
    // Emplacement par distance k au centre : [largeur, hauteur, décalage x, luminosité] ;
    // au-delà de 3, la jaquette s'efface (k = 4). Rotation : coverAngles[k], vers le centre.
    readonly property var coverSlots: [[240, 340, 0, 1], [190, 269, 250, 0.6], [160, 227, 430, 0.38],
                                       [140, 198, 580, 0.2], [140, 198, 720, 0.2]]
    readonly property var coverAngles: [0, 38, 44, 50, 56]
    readonly property int coverFloor: 436            // bas des jaquettes, px du canevas
    readonly property int coverPerspective: 900
    readonly property int coverAreaHeight: 560       // hauteur du carrousel (fondus des bords)
    readonly property int coverEdgeFade: 160         // fondus noirs des bords…
    readonly property real coverEdgeFadeAlpha: 0.75  // …à 75 % contre le bord
    // Déplacement d'un cran : ressort léger ; maintenu (pas de navFastStep), plus vif et sans rebond.
    readonly property int coverMove: 640
    readonly property var curveCoverMove: [0.3, 1.12, 0.4, 1, 1, 1]
    readonly property int coverMoveFast: 230
    readonly property var curveCoverFast: [0.25, 0.1, 0.25, 1, 1, 1]
    readonly property int navFastStep: 190           // flèche maintenue : une jaquette toutes les 190 ms
    readonly property real coverFastBlur: 3          // …les jaquettes floutées pendant ce défilement
    readonly property int coverFastBlurFade: 160
    readonly property int coverBump: 34              // butée : tout le carrousel recule de 34 px…
    readonly property int coverBumpOut: 200
    readonly property int coverBumpBack: 170         // …puis revient
    // Dessin d'une jaquette (shaders/Cover.frag).
    readonly property real coverGloss: 0.12          // reflet en biais, blanc à 12 %
    readonly property real coverShade: 0.55          // dégradé bas des latérales (lisibilité du titre)
    readonly property real coverRing: 0.12           // filet clair de la jaquette centrale
    readonly property int coverReflectGap: 6         // reflet au sol : sous la jaquette, à 6 px…
    readonly property real coverReflectAlpha: 0.24   // …24 % contre elle…
    readonly property real coverReflectSpan: 0.18    // …et effacé sur 18 % de sa hauteur
    readonly property int coverShadowPad: 150        // débord de shadows/cover.png (jaquette de 240)
    readonly property int coverSideShadowPad: 70     // …et de shadows/coverSide.png (jaquette de 190)
    readonly property int coverTitleSize: 12         // titre des latérales, Sora 600, deux lignes
    readonly property int coverTitleInset: 10
    readonly property real coverTitleLineHeight: 1.15
    // Balayage de la jaquette centrale (cocoSheen) : toutes les 10 s, la bande traverse
    // entre 55 % et 85 % du cycle.
    readonly property int sheenPeriod: 10000
    // Chargement (MotionJaquettes) : squelette de verre balayé (shimmerPeriod), puis l'image
    // apparaît (fondu coverRevealFade, échelle coverRevealZoom → 1 et flou coverRevealBlur → 0).
    readonly property int shimmerPeriod: 1500
    readonly property int coverRevealFade: 500
    readonly property int coverRevealMove: 700
    readonly property real coverRevealZoom: 1.04
    readonly property real coverRevealBlur: 8
    // Jaquette composée (pas d'image) : dégradé sourd d'une teinte (celle du fond du jeu, sinon
    // une des six de secours choisie par le nom), éditeur en libellé, titre en Sora 600. Tailles
    // de CasLimites (jaquette de 96 de large), à l'échelle de la jaquette.
    readonly property var composedHues: [30, 90, 150, 210, 270, 330]
    readonly property var composedLevels: [[0.22, 0.29], [0.24, 0.13], [0.25, 0.06]]   // [saturation, luminosité] haut, milieu, bas
    readonly property real composedLabelSize: 7 / 96
    readonly property real composedTitleSize: 14 / 96
    readonly property real composedInset: 10 / 96
    // Changement de catégorie (MotionCategories) : le carrousel qui arrive glisse de 140 px,
    // flou de 8 px, et apparaît (fondu après categoryEnterDelay).
    readonly property int categorySlide: 140
    readonly property real categoryBlur: 8
    readonly property int categoryEnterMove: 640     // curveMain
    readonly property int categoryEnterDelay: 110
    readonly property int categoryEnterFade: 380
        // Saut alphabétique (CasLimites) : au-delà de coverJumpMin jeux, RT / LT.
    readonly property int coverJumpMin: 31
    readonly property int letterBoxSize: 88
    readonly property int letterBoxRadius: 24
    readonly property int letterSize: 46
    readonly property int letterShow: 900            // la lettre reste, le carrousel flou
    readonly property real letterBlur: 3

    // --- Onglets de catégories (CategoryTabs ; AccueilCarrousel, MotionCategories) ---
    readonly property int tabsTop: 28                // haut de la rangée, px du canevas
    readonly property int tabsPad: 4                 // marge de la pastille de verre
    readonly property int tabsLabelPadH: 18
    readonly property int tabsLabelPadV: 7
    readonly property int tabsSize: 14               // 500 ; 600 sur l'onglet actif
    readonly property color tabsInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.72)
    readonly property int tabsInkFade: 260
    readonly property int tabsMove: 520              // la pastille blanche glisse…
    readonly property var curveTabs: [0.3, 1.2, 0.4, 1, 1, 1]   // …avec un léger rebond
    readonly property int tabsSquashDelay: 100       // à l'appui de LB / RB, elle s'écrase…
    readonly property real tabsSquash: 1.06
    readonly property int tabsSquashMove: 40
    readonly property int tabsSquashHold: 80
    readonly property int tabsGlyphGap: 10           // LB / RB de part et d'autre
    readonly property int tabsGlyphHeight: 22
    readonly property int tabsGlyphPad: 7
    readonly property int tabsGlyphSize: 10          // Sora 600
    readonly property color tabsGlyphStroke: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.3)
    readonly property int tabsGlyphFlash: 450        // glyphe allumé après l'appui
    readonly property int tabsGlyphFade: 150

    // --- Bloc titre de l'accueil (HeroBlock ; AccueilCarrousel, CasLimites) ---
    readonly property int homeTitleTop: 516          // haut du titre, px du canevas
    readonly property int homeTitleSize: 48          // Sora 600 (la planche ; tokens.json dit 40)
    readonly property int homeTitleSmallSize: 36     // titre trop long même sur deux lignes
    readonly property real homeTitleSpacing: -0.04   // em
    readonly property real homeTitleLineHeight: 1.05
    readonly property int homeTitleWidth: 640        // colonne centrale (DESIGN_SYSTEM : 560 à 640)
    readonly property int homeTitleTravel: 12        // le nouveau titre monte (ou descend) de 12 px…
    readonly property int homeTitleMove: 520         // …en 520 ms (curveMain), en fondu flou…
    readonly property int homeTitleFast: 200         // …ou 200 ms, flèche maintenue
    readonly property real homeTitleBlur: 6
    readonly property int homeMetaTop: 10
    readonly property int homeMetaGap: 10
    readonly property int homeMetaSize: 15           // Sora 500
    readonly property color homeMetaInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.62)
    readonly property int pegiHeight: 20             // pastille « PEGI 7 »
    readonly property int pegiPad: 7
    readonly property int pegiRadius: 5
    readonly property int pegiSize: 11               // Sora 600
    readonly property color pegiStroke: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.35)
    readonly property int homeActionsTop: 26         // des boutons sous la méta
    readonly property int homeButtonsGap: 12
    readonly property int optionsPadRight: 22        // bouton Options (verre)
    readonly property int optionsGlyphSize: 28
    readonly property int optionsGlyphFontSize: 12
    readonly property color optionsGlyphInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.5)

    // --- Aide en bas de l'accueil (HomeHelp) ---
    readonly property int helpBottom: 40             // du bas du canevas au bas de la rangée
    readonly property int helpGap: 28
    readonly property int helpInnerGap: 8
    readonly property int helpArrowGap: 8
    readonly property int helpGlyphSize: 22
    readonly property color helpGlyphStroke: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.45)
    readonly property real helpArrowStroke: 1.5
    readonly property int helpSize: 13               // Sora 500
    readonly property color helpInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55)
    readonly property int helpNudge: 3               // ↓ oscille de 3 px (cocoNudge)…
    readonly property int helpNudgePeriod: 1800      // …en 1,8 s

    // --- État « Aucun favori » (EmptyFavorites ; EtatFavorisVide) ---
    readonly property color emptyTop: "#3A2A50"      // fond : dégradé sourd…
    readonly property color emptyBottom: "#0A0810"
    // Emplacements vides : [bord gauche depuis le centre, haut, rotateY, opacité du trait].
    readonly property var emptySlots: [[-550, 178, 60, 0.08], [-320, 164, 30, 0.12],
                                       [140, 164, -30, 0.12], [370, 178, -60, 0.08]]
    readonly property size emptySlotSize: Qt.size(180, 255)
    readonly property real emptySlotStroke: 1.5
    readonly property var emptySlotDash: [3, 3]      // en largeurs de trait
    readonly property int emptyStarTop: 200
    readonly property int emptyStarDisk: 110
    readonly property int emptyStarSize: 40
    readonly property int emptyTextTop: 344
    readonly property int emptyTextWidth: 520
    readonly property int emptyButtonTop: 2          // + deux espacements de homeMetaTop : 22 px
    readonly property int emptyButtonPadRight: 24
    readonly property int emptyButtonSize: 16        // Sora 600
    readonly property int emptyHelpBottom: 34
    readonly property int emptyHelpGap: 26
    readonly property int emptyHelpGlyphSize: 11

    // --- Fiche jeu éditoriale (GamePage ; FicheEditoriale, MotionFiche) ---
    // La jaquette centrale du carrousel devient celle de la fiche : elle glisse en ficheCover
    // et s'incline (ficheTilt, qui oscille lentement), assombrie à ficheCoverBrightness ; les
    // autres s'écartent de ficheSpread px en s'effaçant.
    readonly property rect ficheCover: Qt.rect(96, 150, 300, 424)
    readonly property real ficheCoverBrightness: 0.66
    readonly property var ficheTilt: [9, 3]          // rotateY (°), aller-retour en ficheTiltPeriod
    readonly property int ficheTiltPeriod: 18000
    readonly property int ficheSpread: 340
    readonly property real ficheGloss: 0.10
    readonly property real ficheRing: 0.07
    readonly property real ficheReflectAlpha: 0.22
    readonly property real ficheReflectSpan: 0.28
    readonly property int ficheOpen: 780             // la jaquette va en place (curveMain)…
    readonly property int ficheClose: 520            // …et revient, plus vite
    // Texte : colonne à droite, en cascade (cocoIn : 18 px plus bas, flou de 8, 1 s curveMain).
    readonly property point ficheText: Qt.point(476, 140)
    readonly property int ficheTextWidth: 720
    readonly property var ficheCascade: [150, 220, 290, 360, 440, 520, 600]   // ms, du libellé aux boutons
    readonly property int ficheIn: 1000
    readonly property int ficheInTravel: 18
    readonly property real ficheInBlur: 8
    readonly property int ficheOut: 220              // sortie : tout part ensemble
    readonly property int homeLeaveTravel: 14        // le bloc titre de l'accueil part de 14 px vers le haut…
    readonly property int homeReturnDelay: 300       // …et revient 300 ms après la fermeture
    readonly property int homeReturn: 420
    readonly property int homeReturnMove: 600
    readonly property int ficheLabelSize: 12         // éditeur, capitales, Sora 600, 0,08 em
    readonly property color ficheLabelInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.58)
    readonly property int ficheTitleSize: 64         // Sora 600, −0,045 em, interligne 1,05
    readonly property int ficheGap: 12
    readonly property int ficheMetaSize: 15
    readonly property int ficheTagHeight: 22         // pastilles PEGI, modes
    readonly property int ficheTagPad: 8
    readonly property int ficheTagRadius: 6
    readonly property color ficheTagStroke: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.32)
    readonly property color ficheTagInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.8)
    readonly property int ficheTextTop: 20           // description
    readonly property int ficheTextSize: 16          // Sora 400, interligne 1,6
    readonly property real ficheTextLineHeight: 1.6
    readonly property int ficheTextLines: 3          // lignes visibles ; bas fait défiler
    readonly property int ficheTextMaxWidth: 600
    readonly property color ficheTextInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.74)
    readonly property int ficheStatsTop: 32          // chiffres : 44 px + unité 20 px + libellé 13 px
    readonly property int ficheStatsGap: 56
    readonly property int ficheStatSize: 44
    readonly property int ficheStatUnitSize: 20
    readonly property int ficheStatLabelSize: 13
    readonly property int ficheFactsTop: 30          // grille de faits sous un filet
    readonly property int ficheFactsWidth: 660
    readonly property int ficheFactsPad: 18
    readonly property int ficheFactLabelSize: 12
    readonly property int ficheFactSize: 15
    readonly property int ficheButtonsTop: 32
    readonly property int ficheHelpBottom: 36        // « Appuyez sur B ou ↑ pour revenir »
    // Bouton « ↑ Bibliothèque » à la place du logo.
    readonly property int backPillHeight: 36
    readonly property int backPillPadLeft: 10
    readonly property int backPillPadRight: 16
    readonly property color backPillFill: Qt.rgba(1, 1, 1, 0.1)
    readonly property int backPillShift: 10          // il arrive de 10 px à gauche

    // --- Favoris (MotionFavori) : pastille cœur sur la jaquette, anneau, bannière ---
    readonly property int favBadgeSize: 38
    readonly property int favBadgeInset: 12
    readonly property color favBadgeFill: Qt.rgba(28 / 255, 28 / 255, 30 / 255, 0.72)
    readonly property color favBadgeStroke: Qt.rgba(1, 1, 1, 0.14)
    readonly property int favHeartSize: 18
    readonly property var curveFavIn: [0.3, 1.7, 0.4, 1, 1, 1]
    readonly property int favBadgeIn: 560
    readonly property int favBadgeOut: 240
    readonly property real favRingScale: 2.4         // l'anneau s'élargit en s'effaçant
    readonly property int favRingMove: 650
    readonly property int bannerHeight: 44
    readonly property int bannerBottom: 36
    readonly property color bannerFill: Qt.rgba(28 / 255, 28 / 255, 30 / 255, 0.78)
    readonly property int bannerHold: 1500
    readonly property int bannerTravel: 14           // elle monte de 14 px
    readonly property var curveBannerIn: [0.3, 1.3, 0.4, 1, 1, 1]
    readonly property int bannerIn: 560
    readonly property int bannerOut: 300

    // --- Barre haute (StatusBar) ---
    readonly property int topBarY: 26
    readonly property int topBarHeight: 40
    // Pastille de l'hôte : point d'état, nom, puis détail (latence ou « connexion… »).
    readonly property color hostPillFill: glassPill
    readonly property color hostPillStroke: Qt.rgba(1, 1, 1, 0.1)    // filet intérieur 1 px
    readonly property int hostPillPadLeft: 14
    readonly property int hostPillPadRight: 14
    readonly property int hostPillPadV: 8
    readonly property int hostPillGap: 8
    readonly property int hostDotSize: 6
    readonly property int hostDotBreath: 2400        // point « en ligne » qui respire (cocoLive)…
    readonly property real hostDotBreathMin: 0.35    // …de 35 % à 100 %
    readonly property int hostDotBlink: 1100         // période du clignotement « connexion… »
    readonly property real hostDotBlinkMin: 0.2
    readonly property int hostNameSize: 13           // Sora 600
    readonly property int hostDetailSize: 13         // Sora 500, chiffres tabulaires
    readonly property color hostDetailInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55)
    // États du PC (MotionReveilPC, EtatHorsLigne) : point gris en veille, rouge hors ligne ; au
    // réveil, roue et « Réveil de … », puis coche et « … est en ligne » (pastille éclairée, qui
    // rebondit). Chaque calque arrive en fondu après 140 ms ; la largeur suit au ressort.
    readonly property color hostDotAsleep: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.4)
    readonly property color hostPillOnlineFill: Qt.rgba(1, 1, 1, 0.16)
    readonly property int hostPillResize: 560
    readonly property var curveHostPill: [0.3, 1.15, 0.4, 1, 1, 1]
    readonly property int hostLayerFade: 260
    readonly property int hostLayerDelay: 140
    readonly property real hostSpinnerSize: 13
    readonly property real hostSpinnerStroke: 1.9
    readonly property real hostSpinnerArc: 12 / 44
    readonly property int hostSpinnerSpin: 1000
    readonly property real hostOnlineScale: 1.06
    readonly property int hostOnlineBump: 240
    readonly property int hostOnlineShow: 1100       // « … est en ligne », puis la pastille habituelle
    readonly property real heroWakeSpinner: 16       // roue du bouton Jouer pendant le réveil
    readonly property real heroWakeStroke: 2.1
    readonly property color heroWakeTrack: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.25)
    readonly property int statusRight: marginStatus  // bord droit de la barre (pastille, heure, icônes)
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
    readonly property int clockSize: 15              // Sora 600, chiffres tabulaires
    readonly property int sysGap: 18
    readonly property int wifiSize: 17
    readonly property size batterySize: Qt.size(25, 12)
    readonly property int batteryLow: 20             // en dessous (hors charge), l'icône passe en orange
    readonly property int batteryCritical: 5         // à 5 % (hors charge) : l'île le dit, puis la veille…
    readonly property int batteryCriticalSleep: 120000   // …au bout de 2 min (dans le jeu : streammenu)
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
    readonly property real glyphPillScale: 1.5       // gâchettes (LB, L1…) : largeur / hauteur…
    readonly property int glyphPillPad: 7            // …au moins ; « LB RB » : le texte et cette marge
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
    readonly property int playPadLeft: 11
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
    readonly property int playGap: 10
    readonly property int playLabelSize: 17          // Sora 600
    readonly property int playGlyphSize: 30
    readonly property int playGlyphFontSize: 13
    readonly property color optionsColor: Qt.rgba(1, 1, 1, 0.86)
    readonly property int optionsLabelSize: 15       // Sora 600
    readonly property int optionsGap: 10

    // --- Vignette de l'étagère « Ambiant » : seule la taille de décodage de la jaquette de
    //     LaunchScreen s'en sert encore (l'écran de lancement est refait en phase 5) ---
    readonly property size shelfThumbSize: Qt.size(108, 144)
    readonly property real shelfActiveScale: 1.08
    // Soulignement orange (onglets du panneau d'options, code de liaison).
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
    readonly property int reachRetry: 1300           // PC injoignable : « Nouvelle tentative… », puis l'échec

    readonly property int wifiRescan: 10000          // liste des réseaux rafraîchie pendant qu'elle est ouverte

    // --- Listes groupées CocoOS (SettingsList) : cartes de lignes sous un intitulé ---
    // Trois gabarits : la feuille d'options (OptionsFeuille), le contenu des réglages
    // (Reglages*) et leur menu à gauche. Hauteurs : ligne simple, curseur à libellé
    // (`slider`), curseur à icônes (`icons`), ligne à sous-titre, carte d'information.
    readonly property var listSheet: ({
        row: 48, slider: 76, iconSlider: 56, twoLine: 64, info: 80, padH: 16, radius: 18,
        fill: Qt.rgba(1, 1, 1, 0.06), stroke: "transparent", label: 15, value: 15,
        valueInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55), sepInset: 16, sep: hairline,
        focusFill: Qt.rgba(1, 1, 1, 0.12), focusWeight: Font.DemiBold, valueFocusInk: true,
        sectionInset: 16, cardGap: 22, tile: 30, tileRadius: 8, gap: 12 })
    readonly property var listSettings: ({
        row: 52, slider: 76, iconSlider: 56, twoLine: 64, info: 80, padH: 18, radius: 20,
        fill: glassGroup, stroke: Qt.rgba(1, 1, 1, 0.06), label: 16, value: 14,
        valueInk: ink2, sepInset: 18, sep: hairline,
        focusFill: focusRow, focusWeight: Font.DemiBold, valueFocusInk: false,
        sectionInset: 18, cardGap: 22, tile: 30, tileRadius: 8, gap: 12 })
    readonly property var listMenu: ({
        row: 44, slider: 76, iconSlider: 56, twoLine: 64, info: 80, padH: 14, radius: 16,
        fill: Qt.rgba(1, 1, 1, 0.06), stroke: "transparent", label: 15, value: 13,
        valueInk: ink3, sepInset: 56, sep: Qt.rgba(1, 1, 1, 0.07),
        focusFill: Qt.rgba(1, 1, 1, 0.16), focusWeight: Font.DemiBold, valueFocusInk: false,
        sectionInset: 14, cardGap: 14, tile: 30, tileRadius: 8, gap: 12, chevron: false })
    readonly property int listSectionSize: 12        // intitulé : Sora 600, capitales, 0,06 em, ink3
    readonly property real listSectionSpacing: 0.72
    readonly property int listSectionHeight: 15
    readonly property int listSectionBelow: 8        // entre l'intitulé et sa carte
    readonly property int listNoteTop: 8             // note sous une carte : 12 px, interligne 1,4, ink3
    readonly property int listNoteSize: 12
    readonly property real listNoteLineHeight: 1.4
    readonly property int listFocusFade: 220         // fond de la ligne en focus, couleur de la valeur
    readonly property int listSubSize: 12            // sous-titre d'une ligne à deux étages (ink 0,55)
    readonly property int listSubGap: 3
    readonly property int listChevronGap: 8          // valeur ›
    readonly property size listChevron: Qt.size(8, 13)
    readonly property color listTileDark: "#3A3A3C"  // tuile d'une manette
    readonly property int listIconGap: 10            // cadenas, signal d'un réseau
    readonly property color listSubInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55)
    readonly property size listValueBox: Qt.size(240, 20)
    readonly property int listSliderLabelTop: 14     // curseur à libellé : libellé et valeur en haut
    readonly property int listIconSlot: 20           // curseur à icônes : la place de chaque icône
    readonly property int listSpinner: 13            // roue d'une recherche, à côté d'un intitulé
    readonly property real listSpinnerStroke: 1.8
    readonly property color listSpinnerTrack: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.2)
    readonly property int listSpinTurn: 900
    readonly property color knob: "#FFFFFF"          // pouce d'un interrupteur, poignée d'un curseur
    // Interrupteur CocoOS (51 × 31, pouce 27) : le pouce glisse au ressort (.3, 1.35, .4, 1).
    readonly property size toggleSize: Qt.size(51, 31)
    readonly property int toggleThumb: 27
    readonly property int toggleInset: 2
    readonly property var toggleMove: motion(420, [0.3, 1.35, 0.4, 1, 1, 1])
    readonly property int toggleFill: 250
    // Curseur de la feuille : piste 4 px orange, poignée blanche de 20 qui grossit (×1,2) en focus.
    readonly property int listTrackTop: 14           // sous le libellé
    readonly property int listTrack: 4
    readonly property color listRail: Qt.rgba(1, 1, 1, 0.14)
    readonly property int listKnob: 20
    readonly property real listKnobFocus: 1.2
    readonly property var listKnobGrow: motion(260, [0.3, 1.4, 0.4, 1, 1, 1])
    // Curseur à icônes des réglages : piste 6 px blanche, poignée de 24.
    readonly property int listIconTrack: 6
    readonly property int listIconKnob: 24
    readonly property int listIconSliderGap: 14
    // Contrôle segmenté : la piste grise, la case choisie blanche à texte noir.
    readonly property color segmentTrackProfile: Qt.rgba(118 / 255, 118 / 255, 128 / 255, 0.2)
    readonly property int segmentInlineCell: 92      // une case d'un choix en ligne (Glyphes, Vibrations)
    readonly property int segmentInlineHeight: 30
    readonly property int segmentInlineSize: 13
    readonly property color segmentInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.72)
    readonly property var segmentMove: motion(320, curveMain)
    // Carte du profil de flux : sélecteur à 5 cases, puis 4 chiffres.
    readonly property int profilePadV: 14
    readonly property int profileSegHeight: 30
    readonly property int profileSegCellRadius: 7
    readonly property int profileStatsTop: 14
    readonly property int profileStatsGap: 12
    readonly property int profileStatLabel: 11       // ink 0,55
    readonly property int profileStatValue: 15       // Sora 600
    readonly property int profileHeight: 112
    // Carte d'information (réseau connecté) : tuile de 44, chiffres à droite.
    readonly property int infoTile: 44
    readonly property int infoTileRadius: 12
    readonly property int infoTitleSize: 17
    readonly property int infoSubSize: 13
    readonly property int infoStatsGap: 22
    readonly property int infoStatLabel: 11
    readonly property int infoStatValue: 15

    // --- Feuille d'options CocoOS (OptionsFeuille, MotionOptions) ---
    readonly property int optWidth: 492
    readonly property int optMargin: 16              // collée à droite, en haut et en bas
    readonly property int optPad: 28
    readonly property int optTitleSize: 30           // Sora 600, −0,03 em, interligne 1,2
    readonly property int optHostTop: 6              // point + « PC-Salon · connecté · 4 ms » (13 px, ink 0,58)
    readonly property int optHostSize: 13
    readonly property int optTabsTop: 20
    readonly property int optTabsHeight: 40          // piste : 3 + 34 + 3
    readonly property int optTabsRadius: 12
    readonly property int optTabRadius: 9
    readonly property int optTabSize: 14
    readonly property color optTabInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.6)
    readonly property var optTabMove: motion(480, [0.3, 1.2, 0.4, 1, 1, 1])
    readonly property int optTabInkFade: 240
    readonly property int optGlyphFlash: 400         // LB / RB s'allument à l'appui
    readonly property int optContentTop: 24          // premier intitulé, sous les onglets
    readonly property int optPaneShift: 24           // l'onglet qui part glisse de 24 px…
    readonly property int optPaneFade: 260           // …en s'effaçant (260 ms) ; mouvement 420 ms curveMain
    readonly property int optPaneMove: 420
    readonly property int optLegendGap: 22
    readonly property int optListBottom: 12          // entre la liste et la légende
    readonly property color optFadeColor: "#161618"  // le verre sur l'accueil assombri (fondus de la liste)
    readonly property real optClosedOpacity: 0.6     // fermée, elle s'efface jusque-là en glissant
    readonly property int optFadeIn: 200
    readonly property int optFadeOut: 300
    readonly property int optFadeOutDelay: 60
    readonly property int optGlyphFade: 150
    readonly property real optBlurScale: 0.25        // flou du verre (blur 40) : copie au quart, floutée…
    readonly property int optBlurMax: 40             // …de 40 px
    readonly property real optBlurSaturation: 0.6    // saturate(1.6)
    readonly property int legendSizeCoco: 13         // légende CocoOS : Sora 500, ink2
    readonly property int legendGlyphGapCoco: 8
    readonly property int optSlide: 540              // fermée, elle attend 540 px à droite
    readonly property var optOpen: motion(620, [0.3, 1.08, 0.4, 1, 1, 1])
    readonly property var optClose: motion(360, [0.4, 0, 1, 1, 1, 1])
    // L'accueil recule derrière la feuille : ×0,94 autour de (30 %, 50 %), assombri de moitié,
    // coins arrondis.
    readonly property real recedeScale: 0.94
    readonly property point recedeOrigin: Qt.point(0.3, 0.5)
    readonly property real recedeDim: 0.5
    readonly property int recedeRadius: 28
    readonly property int recedeFrame: 48            // cadre noir qui arrondit ses coins (au-delà de l'écran)
    readonly property int recedeIn: 600              // curveMain (assombri en 500)
    readonly property int recedeOut: 420             // curveMain (380)

    // --- Clavier à l'écran CocoOS (ClavierWifi, MotionClavier) ---
    readonly property int kbContextTop: 52           // « PREMIÈRE CONFIGURATION · 1 SUR 3 »
    readonly property int kbTitleTop: 78
    readonly property int kbTitleSize: 34            // Sora 600, −0,03 em
    readonly property int kbFieldTop: 160
    readonly property size kbField: Qt.size(640, 64)
    readonly property color kbFieldFill: Qt.rgba(1, 1, 1, 0.1)
    readonly property real kbFieldStroke: 1.5        // contour orange…
    readonly property int kbFieldRing: 5             // …et son halo (accent à 22 %)
    readonly property color kbFieldRingFill: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property int kbFieldPadLeft: 26
    readonly property int kbFieldPadRight: 20
    readonly property int kbFieldGap: 14
    readonly property int kbFieldSize: 24            // Sora 600
    readonly property int kbCharWidth: 14            // un caractère masqué (« • » à 0,18 em)
    readonly property real kbCharSpacing: 4.3        // 0,18 em, en clair
    readonly property int kbDot: 5
    readonly property int kbCaretHeight: 28
    readonly property int kbCaretGap: 3
    readonly property int kbCaretBlink: 500
    readonly property int kbClearHold: 800           // le dernier caractère reste lisible…
    readonly property int kbClearFade: 220           // …puis devient un point
    readonly property int kbRevealTouch: 120         // « R3 Afficher » cliquable
    readonly property int kbHintTop: 240             // « 8 caractères minimum · 8 saisis »
    readonly property int kbTop: 344
    readonly property int kbWidth: 1180
    // Deux gabarits : le mot de passe (ClavierWifi) et la recherche (Recherche, plus bas).
    readonly property var kbFull: ({
        height: 428, radius: 36, fill: Qt.rgba(28 / 255, 28 / 255, 30 / 255, 0.78), chipsTop: 22, chipHeight: 34,
        rowsTop: 72, rowStep: 74, keyHeight: 62, keyRadius: radiusKey, charSize: 26, fnSize: 16, space: 380,
        legendBottom: 22 })
    readonly property var kbCompact: ({
        height: 344, radius: 32, fill: Qt.rgba(28 / 255, 28 / 255, 30 / 255, 0.8), chipsTop: 18, chipHeight: 32,
        rowsTop: 62, rowStep: 60, keyHeight: 52, keyRadius: 13, charSize: 24, fnSize: 15, space: 604,
        legendBottom: 16 })
    readonly property color kbStroke: Qt.rgba(1, 1, 1, 0.1)
    readonly property int kbTravel: 460              // il monte de 460 px…
    readonly property var kbIn: motion(640, [0.3, 1.15, 0.4, 1, 1, 1])
    readonly property var kbOut: motion(380, [0.4, 0, 1, 1, 1, 1])
    readonly property int kbFadeIn: 240
    readonly property int kbFadeOut: 300
    readonly property int kbFadeOutDelay: 80
    readonly property int kbPad: 36
    readonly property int kbChipPad: 16
    readonly property int kbChipSize: 14
    readonly property var kbChips: [".com", ".fr", "@gmail.com", "@free.fr"]
    readonly property int kbKeyWidth: 100
    readonly property int kbGap: 12
    readonly property int kbFnKey: 156               // ⇧, ⌫, 123
    readonly property int kbOkKey: 212
    readonly property int kbCharSize: 26             // Sora 500 (bulle des accents)
    readonly property color kbShiftOn: Qt.rgba(1, 1, 1, 0.32)
    readonly property int kbGlyph: 20                // LT, X, Y, ≡ dans les touches
    readonly property color kbGlyphLight: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.4)
    readonly property color kbGlyphDark: Qt.rgba(0, 0, 0, 0.45)
    readonly property real kbFocusScale: 1.08        // la tache blanche de la touche en focus
    readonly property real kbPressScale: 0.9         // A enfoncé (110 ms)…
    readonly property real kbHoldScale: 0.94         // …maintenu
    readonly property int kbPressMove: 110
    readonly property var kbSpotGrow: motion(420, [0.3, 1.6, 0.4, 1, 1, 1])
    readonly property var kbSpotMove: motion(210, [0.3, 1.25, 0.4, 1, 1, 1])
    readonly property int kbSpotFade: 200
    readonly property real kbSpotDim: 0.35           // bulle des accents ouverte
    readonly property int kbInkFade: 120
    readonly property int kbAccentHold: 450          // A maintenu : la bulle des accents
    readonly property size kbAccentKey: Qt.size(84, 62)
    readonly property int kbAccentGap: 8
    readonly property int kbAccentPad: 10
    readonly property int kbAccentRadius: 22
    readonly property color kbAccentFill: Qt.rgba(58 / 255, 58 / 255, 62 / 255, 0.96)
    readonly property int kbAccentAbove: 10          // au-dessus de la touche
    readonly property int kbAccentInset: 12          // dans le clavier, à tant du bord
    readonly property real kbAccentFrom: 0.4         // elle naît petite, 30 px plus bas
    readonly property int kbAccentTravel: 30
    readonly property int kbAccentFade: 160
    readonly property var kbAccentIn: motion(420, [0.3, 1.3, 0.4, 1, 1, 1])
    readonly property var kbAccentOut: motion(220, [0.4, 0, 1, 1, 1, 1])
    readonly property real kbAccentChosen: 1.06
    readonly property int kbLegendGap: 26
    // Lueurs : orange en bas (décalage du centre de l'écran), bleue en haut à droite.
    readonly property rect kbGlowLow: Qt.rect(-130, 400, 900, 520)
    readonly property rect kbGlowHigh: Qt.rect(60, -60, 600, 420)
    readonly property color kbGlowAccent: Qt.rgba(accent.r, accent.g, accent.b, 0.34)
    readonly property color kbGlowBlue: Qt.rgba(110 / 255, 155 / 255, 1, 0.16)

    // --- Recherche (Recherche) ---
    readonly property int srchSuggestions: 3         // suggestions au-dessus du clavier
    readonly property real srchBackdropOpacity: 0.75 // fond : le premier résultat, flouté
    readonly property color srchVeilTop: Qt.rgba(0, 0, 0, 0.35)
    readonly property color srchVeilBottom: Qt.rgba(0, 0, 0, 0.8)
    readonly property real srchVeilAt: 0.7
    readonly property int srchFieldTop: 86
    readonly property size srchField: Qt.size(720, 56)
    readonly property color srchFieldStroke: Qt.rgba(1, 1, 1, 0.14)
    readonly property int srchFieldPadLeft: 20
    readonly property int srchFieldPadRight: 18
    readonly property int srchQuerySize: 19          // Sora 500
    readonly property int srchCaret: 24
    readonly property int srchClear: 22              // effacer la recherche
    readonly property color srchClearFill: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.3)
    readonly property int srchHeaderTop: 166         // « 4 résultats  titres, éditeurs et genres »
    readonly property int srchCountSize: 20
    readonly property int srchResultsTop: 200
    readonly property size srchCover: Qt.size(120, 170)
    readonly property int srchCoverRadius: 10
    readonly property int srchGap: 24
    readonly property int srchCaptionGap: 10         // titre sous la jaquette…
    readonly property int srchWhyTop: 18             // …puis pourquoi elle est là (11 px)
    readonly property int srchCaption: 46
    readonly property color srchTitleInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.86)
    readonly property color srchWhyInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.45)
    readonly property int srchWhySize: 11
    readonly property real srchFocusScale: 1.05      // le résultat qui a la manette
    readonly property int srchRecentTop: 206
    readonly property int srchRecentWidth: 300
    readonly property int srchColumnGap: 40
    readonly property int srchRecentRow: 36
    readonly property color srchRecentInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.78)
    readonly property int srchRecentSize: 14
    readonly property int srchKeyboardBottom: 16

    // --- Réglages plein écran (Reglages*) ---
    readonly property int setMenuX: 40
    readonly property int setTop: 34
    readonly property int setMenuWidth: 380
    readonly property int setTitleSize: 32           // « Réglages » : Sora 600, −0,03 em, interligne 40
    readonly property int setMenuTop: 18             // la carte de la console, sous le titre
    readonly property int setCardHeight: 72
    readonly property int setCardIcon: 44
    readonly property int setDividerX: 444
    readonly property int setContentX: 476
    readonly property int setContentTop: 96
    readonly property int setContentRight: 56
    readonly property int setPageTitleSize: 26       // Sora 600, −0,025 em
    readonly property int setLegendBottom: 26
    readonly property int setLegendGap: 24
    readonly property color setGlow: Qt.rgba(110 / 255, 155 / 255, 1, 0.08)   // lueur en haut à gauche
    readonly property rect setGlowRect: Qt.rect(-200, -260, 900, 700)
    readonly property int setLineHeight: 40          // titres « Réglages » et de la page
    readonly property color setCardIconFill: "#1C1C1E"
    readonly property int setDividerInset: 24        // filet vertical entre le menu et la page
    readonly property color setDivider: Qt.rgba(1, 1, 1, 0.06)
    readonly property int setStatusTop: 30           // l'heure, le Wi-Fi, la batterie
    readonly property int setStatusHeight: 32
    readonly property int setStatusGap: 18
    readonly property int setContentHeight: 640      // la page défile au-delà, fondue en bas
    readonly property int setFade: 260               // ouverture / fermeture, en fondu
    readonly property int setPageFade: 200           // une autre rubrique : sa page en fondu
    readonly property int confWriteDelay: 700        // Settings (QtCore) écrit la conf un peu après (500 ms)
    // Tuiles du menu (couleurs des maquettes).
    readonly property color setTileWifi: "#2F7CF6"
    readonly property color setTilePads: "#5E5CE6"
    readonly property color setTileScreen: "#0A84FF"
    readonly property color setTileBattery: "#30D158"
    readonly property color setTileSleep: "#5856D6"
    readonly property color setTileGeneral: "#8E8E93"
    readonly property color setBadge: "#FF453A"

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
    readonly property int sheetHostGap: 8
    // Un seul soulignement passe d'onglet en onglet (ElasticIndicator) : le bord avant au
    // ressort springSnappy, le bord arrière elasticTrail ms (curveOut) après elasticTrailDelay.
    readonly property int elasticTrail: 420
    readonly property int elasticTrailDelay: 40
    readonly property int sheetRowHeight: 60
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
    readonly property int sheetValueSwap: 260        // l'ancienne valeur sort, la nouvelle entre…
    readonly property int sheetValueTravel: 36       // …en glissant de cette distance
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
    // Interrupteur (SettingsList) : le pouce s'étire pendant l'appui ; poussé vers l'état déjà
    // là, il bute.
    readonly property int switchThumbStretch: 28     // pendant l'appui…
    readonly property int switchStretch: 150         // …en tant de ms, curveOut
    readonly property int switchBump: 3              // butée : aller-retour de tant de px…
    readonly property int switchBumpDuration: 260    // …en tant de ms, curveOut
    // Coche tracée devant la valeur choisie d'une liste (réseau Wi-Fi connecté) : le glyphe
    // 24 × 24 du prototype, tracé en checkDraw ms (curveOut) après checkDelay, effacé en checkErase.
    readonly property real checkStroke: 2.4          // sur la grille 24 × 24 du glyphe
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
    // Contrôle segmenté : un libellé trop long se réduit jusque-là. Chiffres du profil de
    // flux : remplacés en cascade (statsStagger d'écart, comme le swapText du prototype).
    readonly property int segmentsLabelMin: 10
    readonly property int statsValueHeight: 20
    readonly property int statsStagger: 45
    readonly property int profileTextSize: 13        // description du profil (sans les réglages avancés), ink2
    readonly property int profileTextLineHeight: 18  // deux lignes au plus : la hauteur des chiffres
    readonly property int sliderHalo: 5              // la zone de clic d'un curseur déborde d'autant
    // Un cran franchi pulse : il s'allonge jusqu'à sliderPulseScale (à sliderPulsePeak de la
    // durée) en passant à l'orange, puis revient, en sliderPulse ms (curveOut).
    readonly property int sliderPulse: 440
    readonly property real sliderPulseScale: 1.9
    readonly property real sliderPulsePeak: 0.3
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

    // Écran de message (HomeScreen.staged) : le bloc titre part à gauche, le carrousel descend.
    readonly property int stageHide: 260
    readonly property int stageHeroShift: -28
    readonly property int stageShelfShift: 26

    // --- Lancement d'un jeu (MotionLancement) : la jaquette grandit jusqu'au plein écran ---
    // Écrans d'attente (MessageScreen) : ligne d'état et piste.
    readonly property int launchProgressWidth: 420   // bloc centré
    readonly property int launchStageSize: 13        // ligne d'état
    readonly property int launchTrackTop: 12
    readonly property int launchTrackHeight: 2
    readonly property color launchTrackColor: Qt.rgba(1, 1, 1, 0.16)
    // A relâché : le bouton Jouer reste enfoncé, puis tout part.
    readonly property int launchPress: 120
    // L'accueil s'efface (opacité, 14 px vers le bas : curveMain), les jaquettes voisines
    // s'écartent de 360 px en s'effaçant, de rang en rang.
    readonly property int launchHomeFade: 320
    readonly property int launchHomeShift: 14
    readonly property int launchHomeMove: 420
    readonly property int launchCoverSpread: 360
    readonly property int launchCoverMove: 650       // curveMain
    readonly property int launchCoverFade: 450
    readonly property int launchCoverStagger: 40
    // La jaquette grandit jusqu'au plein écran (curveMain), coins de radiusCover à 0 ; l'image
    // du jeu (assombrie, qui dérive lentement) remplace la jaquette en fondu.
    readonly property int launchFrameDelay: 120
    readonly property int launchFrameGrow: 950
    readonly property int launchArtDelay: 250
    readonly property int launchArtFade: 800
    readonly property real launchDim: 0.58
    readonly property int launchDrift: 14000         // aller ou retour, InOutSine
    readonly property real launchDriftFrom: 1.02
    readonly property real launchDriftTo: 1.1
    readonly property point launchDriftShift: Qt.point(-20, 8)
    // Puis l'anneau, le nom du jeu et l'état (en fondu, d'une échelle de 0,88).
    readonly property int launchLoaderAt: 800
    readonly property int launchLoaderFade: 450
    readonly property int launchLoaderMove: 650      // curveMain
    readonly property real launchLoaderFrom: 0.88
    readonly property real launchLoaderExitScale: 1.18   // le flux arrive : il grandit en se floutant
    readonly property int launchLoaderExitBlur: 8
    // Le flux de Moonlight ne démarre qu'une fois l'anneau à l'écran (il fige l'interface).
    readonly property int launchOpened: 1100
    readonly property int launchColumnTop: 296       // haut de l'anneau
    readonly property int launchColumnWidth: 400
    readonly property int launchTitleGap: 26
    readonly property int launchTitleSize: 22        // 600
    readonly property int launchStatusGap: 8
    readonly property int launchStatusSize: 14       // 500, ink 62 %
    readonly property int launchStatusHeight: 20
    readonly property color launchStatusInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.62)
    readonly property int launchStatusFade: 300      // un état remplace l'autre : fondu…
    readonly property int launchStatusMove: 400      // …et 8 px de glissement (curveMain)
    readonly property int launchStatusShift: 8
    // Anneau de chargement : piste accent à 30 %, arc de 34 sur 127 qui tourne en 1,1 s ;
    // prêt, il se remplit depuis le haut (480 ms curveMain).
    readonly property real ringSize: 49.3
    readonly property real ringStroke: 8.8
    readonly property color ringTrack: Qt.rgba(accent.r, accent.g, accent.b, 0.3)
    readonly property real ringArc: 34 / 127.23
    readonly property int ringSpin: 1100
    readonly property int ringSpinFade: 200
    readonly property int ringFill: 480

    // --- Échec du lancement (MotionEchec) : « PC-Salon ne répond pas » ---
    readonly property real failDim: 0.78             // l'image s'assombrit (600 ms)
    readonly property int failDimFade: 600
    readonly property int failColumnTop: 250         // la colonne remonte pour les boutons
    readonly property int failColumnWidth: 600
    readonly property int failRise: 450              // curveMain
    readonly property int failShake: 520             // l'anneau secoue (cocoShake)
    readonly property var failShakeKeys: [0, -10, 9, -7, 5, -3, 1, 0]
    readonly property var failShakeCurve: [0.36, 0.07, 0.19, 0.97, 1, 1]
    readonly property color failRingTrack: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.22)
    readonly property int failRingFade: 400
    readonly property int failBangSize: 20           // « ! » au centre de l'anneau (700)
    readonly property real failBangFrom: 0.4
    readonly property int failBangDelay: 150
    readonly property int failBangMove: 500
    readonly property var curveFailBang: [0.3, 1.5, 0.4, 1, 1, 1]
    readonly property int failShift: 10              // le nom du jeu monte, le titre de l'échec arrive d'en bas
    readonly property int failMove: 450              // curveMain
    readonly property int failTitleDelay: 80
    readonly property int failTitleSize: 26          // 600
    readonly property int failTitleHeight: 34
    readonly property int launchTitleLine: 28        // hauteur de ligne du nom du jeu
    readonly property int failBodySize: 15           // explication, interligne 1,5
    readonly property color failBodyInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.7)
    readonly property int failBodyHeight: 44
    readonly property int failBodyDelay: 140
    readonly property int failButtonsGap: 34
    readonly property int failButtonsDelay: 200
    readonly property int failButtonsShift: 16
    readonly property int failButtonsMove: 500       // curveMain
    readonly property int failPrimarySize: 16        // « Réessayer »
    readonly property int pillPadRight: 24           // bouton clair d'une pilule (PillButton)

    // --- PC hors ligne (EtatHorsLigne) : carrousel grisé, disque de verre, message, boutons ---
    readonly property real offlineCovers: 0.55        // jaquettes à 55 %, en gris, assombries
    readonly property real offlineCoverDim: -0.1      // (luminosité de MultiEffect)
    readonly property int offlineFade: 400
    readonly property real vignetteOutOffline: 0.92
    readonly property int offlineIconTop: 150
    readonly property int offlineIconDisc: 96
    readonly property size offlineIconSize: Qt.size(44, 36)
    readonly property color offlineShadow: Qt.rgba(0, 0, 0, 0.5)
    readonly property int offlineShadowY: 30
    readonly property int offlineTitleTop: 452
    readonly property int offlineGap: 10
    readonly property int offlineTitleSize: 30        // 600
    readonly property int offlineTextSize: 15         // 500, ink2
    readonly property int offlineButtonsTop: 22
    readonly property int offlineButtonsGap: 14
    readonly property int offlineSecondarySize: 16    // « Choisir un autre PC »
    readonly property int offlineLegendGap: 26
    readonly property int legendBottomCoco: 34        // légende centrée en bas (EtatHorsLigne, ChoixPC)

    // --- Choix du PC (ChoixPC) : menu de verre sous la pastille du PC ---
    readonly property color pickerDim: Qt.rgba(0, 0, 0, 0.35)
    readonly property int pickerRight: 214           // du bord droit du canevas
    readonly property int pickerTop: 74
    readonly property int pickerWidth: 380
    readonly property int pickerRadius: 26
    readonly property int pickerIn: 420              // curveSpring, depuis 0,96 (coin haut droit)
    readonly property int pickerOut: 200
    readonly property real pickerFrom: 0.96
    readonly property int pickerHeaderTop: 16        // « JOUER DEPUIS » : 12 px 600, ink3
    readonly property int pickerHeaderBottom: 10
    readonly property int pickerHeaderLeft: 18
    readonly property int pickerHeaderSize: 12
    readonly property int pickerRowHeight: 64
    readonly property int pickerAddHeight: 52
    readonly property int pickerPad: 16
    readonly property int pickerGap: 12
    readonly property int pickerDot: 8
    readonly property int pickerLineGap: 3
    readonly property int pickerNameSize: 15         // 500 (600 sous la manette)
    readonly property int pickerDetailSize: 12       // 500, hostDetailInk
    readonly property int pickerCheck: 16
    readonly property int pickerPlus: 14
    readonly property int pickerSeparatorLeft: 36
    readonly property color pickerFocus: Qt.rgba(1, 1, 1, 0.14)

    // --- Volume (MotionHud) : capsule en haut (aussi dans le jeu, streampainter) ---
    readonly property int hudWidth: 220
    readonly property int hudTop: 14
    readonly property int hudSide: 120               // de son bord d'écran (à gauche, à droite)
    readonly property int hudHiddenShift: 40
    readonly property int hudThin: 10
    readonly property int hudThick: 48
    readonly property color hudFill: Qt.rgba(40 / 255, 40 / 255, 42 / 255, 0.62)
    readonly property int hudShow: 160
    readonly property int hudHide: 260
    readonly property int hudMove: 520               // curveSpring
    readonly property int hudExpand: 420             // curveHudExpand
    readonly property int hudCollapse: 300           // curveMain
    readonly property var curveHudExpand: [0.3, 1.3, 0.4, 1, 1, 1]
    readonly property int hudLevelMove: 260          // curveMain
    readonly property int hudBumpRise: 140           // en butée : elle s'étire…
    readonly property int hudBumpBack: 520           // …et revient au ressort
    readonly property var curveHudBump: [0.3, 1.5, 0.4, 1, 1, 1]
    readonly property real hudBumpWidth: 0.07
    readonly property int hudBumpHeight: 6
    readonly property int hudHold: 1400              // sans appui : elle s'amincit…
    readonly property int hudLinger: 600             // …puis part
    readonly property int hudIconLeft: 14
    readonly property int hudIconFade: 180
    readonly property int hudIconMove: 300

    // --- Mise en veille et réveil (MotionVeille) ---
    readonly property int sleepFade: 340             // l'accueil s'efface (InCubic)…
    readonly property int sleepShrink: 380           // …en reculant vers le centre
    readonly property real sleepScale: 0.94
    readonly property int sleepDot: 10               // le point : il s'allume après 120 ms…
    readonly property int sleepGlow: 54
    readonly property real sleepGlowAlpha: 0.55
    readonly property int sleepDotDelay: 120
    readonly property int sleepDotIn: 140
    readonly property int sleepDotMove: 260          // (curveMain, depuis 2,4)
    readonly property real sleepDotFrom: 2.4
    readonly property int sleepDotHold: 70           // …puis s'éteint en rétrécissant
    readonly property int sleepDotOut: 420
    readonly property real sleepDotTo: 0.4
    readonly property int sleepAfter: 1000           // la veille du système, une fois tout noir
    readonly property int wakeFade: 600              // le fond revient (OutCubic)…
    readonly property int wakeCoverStagger: 45       // …les jaquettes, rang par rang, du centre
    readonly property int wakeCoverMove: 640
    readonly property int wakeCoverFade: 360
    readonly property real wakeCoverGather: 0.6
    readonly property real wakeCoverScale: 0.9
    readonly property int wakeTitleDelay: 140        // le texte monte de 16 px
    readonly property int wakeRiseFade: 420
    readonly property int wakeRiseMove: 600
    readonly property int wakeRiseShift: 16
    readonly property int wakeBarDelay: 260          // la barre haute descend de 8 px
    readonly property int wakeBarFade: 400
    readonly property int wakeBarMove: 500
    readonly property int wakeBarShift: -8

    // --- Recharge console éteinte (MotionRecharge) ---
    readonly property int chargeIn: 500
    readonly property int chargeOut: 700
    readonly property int chargeMove: 700            // curveMain, depuis 0,9
    readonly property real chargeFrom: 0.9
    readonly property int chargeFill: 1100           // l'anneau se remplit jusqu'au niveau
    readonly property int chargeShow: 4000           // puis l'écran s'éteint
    readonly property int chargeBreath: 3200
    readonly property int chargeRing: 120
    readonly property int chargeStroke: 20
    readonly property color chargeTrack: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property size chargeBolt: Qt.size(26, 40)
    readonly property int chargeRingTop: 284
    readonly property int chargeTextTop: 34
    readonly property int chargeLevelSize: 34        // 600, chiffres tabulaires
    readonly property int chargeDetailSize: 14
    readonly property color chargeDetailInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55)
    // --- Mode salon (MotionSalon) ---
    readonly property int tvIn: 600
    readonly property int tvOut: 700
    readonly property int tvMove: 750                // curveMain
    readonly property real tvFrom: 0.7
    readonly property int tvTop: 270
    readonly property size tvSize: Qt.size(160, 100)
    readonly property int tvRadius: 14
    readonly property int tvBorder: 3
    readonly property int tvTextTop: 420
    readonly property int tvTitleSize: 30
    readonly property int tvSubSize: 15
    readonly property int tvNoteTop: 22
    readonly property int tvNoteSize: 13
    readonly property color tvNoteInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.45)
    readonly property int tvDimAfter: 1600           // puis l'écran de la console s'assombrit
    readonly property real tvDim: 0.3
    readonly property int tvDimFade: 900

    // --- Mise à jour (MotionMiseAJour) : le O sert de barre de progression ---
    readonly property int updateIn: 600
    readonly property int updateOut: 550
    readonly property int updateStep: 140            // l'arc suit l'avancement
    readonly property int updateGlowSize: 160
    readonly property real updateGlowLow: 0.18
    readonly property real updateGlowHigh: 0.55
    readonly property int updateGlowFade: 500
    readonly property int updateTextTop: 476
    readonly property int updateTextGap: 6
    readonly property int updateShift: 10
    readonly property int updateTextFade: 360
    readonly property int updateTextMove: 520        // curveMain
    readonly property int updateTitleSize: 16        // 600
    readonly property int updateSubSize: 14          // 500, ink2, chiffres tabulaires
    readonly property int updateNoteTop: 10
    readonly property int updateNoteSize: 12
    readonly property color updateNoteInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.4)

    // --- Sortie du démarrage (Demarrage) : le O devient l'anneau, se déplie en jaquette ---
    readonly property int bootWordFade: 600          // « Coco » et « S » s'effacent…
    readonly property int bootUnfoldMove: 800        // …le O glisse au centre, puis se déplie (curveMain)
    readonly property int bootBlackDelay: 400        // le noir se lève sur l'accueil
    readonly property int bootBlackFade: 1800
    readonly property int bootHandover: 150          // la jaquette du carrousel, dessous, prend le relais
    readonly property int bootCoverDelay: 400        // éventail : + 200 ms par rang, 1,2 s, depuis 0,8
    readonly property int bootCoverStagger: 200
    readonly property int bootCoverMove: 1200
    readonly property real bootCoverScale: 0.8
    readonly property int bootTitleDelay: 1400       // le titre monte (1 s)…
    readonly property int bootRise: 1000
    readonly property int bootBarDelay: 2000         // …la barre haute descend…
    readonly property int bootHelpDelay: 2400        // …l'aide paraît

    // --- Sortie de l'écran de veille (MotionReveil) : les jaquettes s'ouvrent en éventail ---
    readonly property int idleCoverDelay: 380        // + 70 ms par rang, depuis le centre
    readonly property int idleCoverStagger: 70
    readonly property int idleCoverMove: 800         // (curveMain ; fondu de même durée)
    readonly property real idleCoverScale: 0.84
    readonly property int idleTitleDelay: 520        // le titre monte de 18 px
    readonly property int idleRise: 650
    readonly property int idleBarDelay: 450          // la barre haute descend de 10 px
    readonly property int idleBarMove: 600
    readonly property int idleHelpDelay: 760

    // --- Extinction et redémarrage (MotionExtinction) ---
    readonly property int shutdownBlack: 700         // le noir monte pendant que l'accueil se replie
    readonly property int shutdownCollapse: 700      // puis la jaquette devient l'anneau…
    readonly property real shutdownCoverScale: 0.7   // (les voisines, repliées au centre)
    readonly property int shutdownMove: 820          // (curveMain)
    readonly property int shutdownRingY: 266         // …au centre, à cette hauteur…
    readonly property int shutdownArtFade: 420
    readonly property int shutdownWordY: 400         // …puis glisse à la place du O du mot
    readonly property real shutdownOShift: 65.65     // (le mot est centré, pas le O)
    readonly property int shutdownWordSize: 64       // « Coco » et « S », 600
    readonly property real shutdownGapLeft: 3.05
    readonly property real shutdownGapRight: 1.75
    readonly property int shutdownWordDelay: 280
    readonly property int shutdownWordFade: 600
    readonly property int shutdownUnwindDelay: 160   // l'anneau se vide…
    readonly property int shutdownUnwind: 1400
    readonly property var curveUnwind: [0.65, 0, 0.35, 1, 1, 1]
    readonly property int shutdownSpread: 18         // …le mot s'écarte en s'effaçant…
    readonly property int shutdownSpreadMove: 700
    readonly property int shutdownDot: 10            // …l'anneau se resserre en un point…
    readonly property int shutdownDotMove: 700
    readonly property int shutdownDotEnd: 6
    readonly property int shutdownDotFade: 800       // …qui s'éteint
    readonly property int shutdownBlackHold: 300
    readonly property int shutdownStatusTop: 476     // « Redémarrage… » sous le mot (14 px, 500)
    readonly property int shutdownStatusSize: 14
    readonly property color shutdownStatusInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55)
    readonly property int shutdownFallback: 10000    // toujours là (logind a refusé) : retour à l'accueil

    // --- Menu d'alimentation (MenuAlimentation, MotionAlimentation) ---
    readonly property int powerIn: 360
    readonly property int powerOut: 260
    readonly property int powerTop: 220
    readonly property int powerWidth: 600
    readonly property int powerHeight: 330
    readonly property int powerRadius: 36
    readonly property int powerFade: 240
    readonly property int powerSpring: 560           // curveSpring, depuis 0,9
    readonly property int powerShrink: 320           // curveExit
    readonly property real powerFrom: 0.9
    readonly property real powerLeaveScale: 0.96     // une action part : la carte recule moins
    readonly property int powerPadTop: 36
    readonly property int powerPadBottom: 28
    readonly property int powerHeaderSize: 13        // 600, ink3, capitales
    readonly property int powerItemsTop: 83          // 36 + ligne de 17 + 30
    readonly property int powerItem: 150
    readonly property int powerGap: 22
    readonly property int powerDisc: 92
    readonly property real powerDiscFocus: 1.08
    readonly property real powerPress: 0.92
    readonly property int powerIcon: 30
    readonly property int powerLabelGap: 14
    readonly property int powerLabelSize: 15
    readonly property color powerLabelInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.7)
    readonly property int powerFocusFade: 200
    readonly property int powerFocusMove: 420
    readonly property var curvePowerFocus: [0.3, 1.5, 0.4, 1, 1, 1]
    readonly property int powerNoteSize: 13
    readonly property color powerNoteInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55)
    // Appui long sur power : la pastille « Maintenir le bouton » se remplit, puis le menu.
    readonly property int powerHold: 1200
    readonly property int powerChipLinger: 300
    readonly property int powerChipRight: 32
    readonly property int powerChipTop: 76
    readonly property int powerChipShift: 8
    readonly property int powerChipHeight: 40
    readonly property int powerChipPadLeft: 7
    readonly property int powerChipPadRight: 16
    readonly property int powerChipGap: 10
    readonly property int powerChipRing: 28
    readonly property real powerChipStroke: 2.4
    readonly property color powerChipTrack: Qt.rgba(1, 1, 1, 0.18)
    readonly property int powerChipIcon: 14
    readonly property int powerChipSize: 13
    readonly property color powerChipFill: Qt.rgba(30 / 255, 30 / 255, 32 / 255, 0.7)
    readonly property int powerChipFade: 200
    readonly property int powerChipMove: 300

    // --- Retour d'un jeu (MotionQuitter) : l'image se réduit en jaquette, l'accueil revient ---
    readonly property int returnFrameDelay: 80
    readonly property int returnFrameShrink: 900     // curveMain
    readonly property int returnArtBlur: 36          // image du jeu floutée et à 60 % au départ…
    readonly property real returnArtDim: 0.4
    readonly property int returnArtClear: 400        // …nette en 400 ms
    readonly property int returnArtDelay: 380        // puis la jaquette la remplace
    readonly property int returnArtFade: 450
    readonly property int returnThumbFade: 500
    // Les jaquettes voisines arrivent du centre (70 % du chemin, échelle 0,88, à plat).
    readonly property int returnCoverDelay: 700
    readonly property int returnCoverStagger: 60
    readonly property int returnCoverMove: 700       // curveMain
    readonly property int returnCoverFade: 420
    readonly property real returnCoverGather: 0.7
    readonly property real returnCoverScale: 0.88
    // Bloc titre (18 px plus bas), puis barre haute (10 px plus haut).
    readonly property int returnTitleDelay: 1050
    readonly property int returnRiseFade: 450
    readonly property int returnRiseMove: 620        // curveMain
    readonly property int returnRiseShift: 18
    readonly property int returnBarDelay: 1200
    readonly property int returnBarFade: 500
    readonly property int returnBarMove: 600
    readonly property int returnBarShift: -10
    readonly property int returnSettle: 1800         // tout est en place

    // --- Sons (Sounds, pack CocoOS) ---
    // Niveau commun des sons de l'interface (celui du SoundBank de référence) : les
    // fichiers sont déjà mastérisés, de −27 à −6 dBFS en crête.
    readonly property real soundVolume: 0.8
    readonly property int navFastInterval: 90        // nav_move_fast : 11 par seconde au plus
    readonly property int ambianceFadeIn: 1800       // fondu croisé des ambiances
    readonly property int ambianceFadeOut: 900

    // --- Listes : pastilles de couleur, pastille d'état, coche (SettingsList) ---
    readonly property int swatchSize: 22
    readonly property int swatchGap: 10
    readonly property int swatchRing: 4              // la choisie : un anneau de 2 px, 2 px plus loin
    readonly property int swatchStroke: 2
    readonly property int listPillHeight: 26
    readonly property int listPillPad: 10
    readonly property int listPillSize: 12
    readonly property int listPillDot: 6
    readonly property int listPillDotGap: 6
    readonly property color listPillFill: Qt.rgba(1, 1, 1, 0.08)
    readonly property color listPillInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.65)
    readonly property int listCheck: 16

    // --- Première configuration (SetupBonjour, SetupLangue, SetupWifi, SetupPC,
    //     MotionAppairage, SetupBibliotheque, MotionSetupFin) ---
    // Lueurs : l'orange en bas, un bleu en haut à droite (x depuis le centre de l'écran).
    readonly property rect setupGlowLow: Qt.rect(-520, 420, 1000, 560)
    readonly property rect setupGlowHigh: Qt.rect(120, -80, 640, 460)
    readonly property color setupGlowAccent: Qt.rgba(accent.r, accent.g, accent.b, 0.30)
    readonly property color setupGlowBlue: Qt.rgba(110 / 255, 155 / 255, 1, 0.16)
    // Bonjour : la lueur orange monte plus haut et plus fort, une autre en haut à gauche.
    readonly property rect helloGlowLow: Qt.rect(-520, 280, 1000, 600)
    readonly property rect helloGlowCorner: Qt.rect(-80, -80, 520, 380)
    readonly property color helloGlowAccent: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property color helloGlowCornerInk: Qt.rgba(accent.r, accent.g, accent.b, 0.12)
    readonly property int setupDrift: 24000          // les lueurs dérivent (cocoAurora, aller-retour)
    readonly property point setupDriftBy: Qt.point(-80, 40)
    readonly property real setupDriftScale: 1.15
    // En-tête « PREMIÈRE CONFIGURATION · n SUR 3 » : trois points, l'étape en cours étirée.
    readonly property int setupDotsTop: 46
    readonly property int setupDot: 6
    readonly property int setupDotActive: 22
    readonly property int setupDotGap: 6
    readonly property color setupDotDone: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.7)
    readonly property color setupDotTodo: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.22)
    readonly property int setupStepGap: 12
    readonly property int setupStepSize: 12          // Sora 600, 0,08 em, ink 0,5
    // Titre (36 px, Sora 600, −0,03 em) et explication (15 px, ink 0,6, interligne 1,5).
    readonly property int setupTitleTop: 108
    readonly property int setupTitleTopBare: 96      // sans en-tête (Langue)
    readonly property int setupTitleSize: 36
    readonly property int setupTextGap: 52           // du haut du titre au haut du texte
    readonly property int setupTextWidth: 700
    readonly property int setupTextSize: 15
    // Listes : leur haut, leur largeur.
    readonly property int setupListTop: 222
    readonly property int setupListTopBare: 214
    readonly property int setupLanguageWidth: 560
    readonly property int setupWifiWidth: 600
    readonly property int setupPcWidth: 620
    readonly property int setupPcRow: 72             // ligne d'un PC (nom, détail)
    readonly property int setupPcIcon: 22
    readonly property int setupNoteGap: 16           // « Région France · clavier AZERTY · format 24 h »
    readonly property int setupNoteSize: 13
    readonly property color setupNoteInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55)
    // Passage d'une étape à l'autre : l'ancienne s'efface, la nouvelle monte de 12 px.
    readonly property int setupSwapOut: 220
    readonly property int setupSwapIn: 520           // curveMain
    readonly property int setupSwapShift: 12
    // Bonjour : un mot toutes les 1,7 s ; il entre flou, petit et bas, sort flou et vers le haut.
    readonly property int helloTop: 300
    readonly property int helloLine: 140
    readonly property int helloSize: 112
    readonly property int helloStart: 500
    readonly property int helloStep: 1700
    readonly property int helloLeave: 450            // avant la fin de son tour, il sort
    readonly property int helloInFade: 700
    readonly property int helloInBlur: 800
    readonly property int helloInMove: 1100          // curveMain
    readonly property int helloOutFade: 380
    readonly property int helloOutMove: 420          // curveExit
    readonly property int helloBlur: 14
    readonly property int helloBelow: 18
    readonly property int helloAbove: -14
    readonly property real helloScaleIn: 0.96
    readonly property real helloScaleOut: 1.02
    readonly property real helloTrackOn: -0.045      // espacement des lettres (em)
    readonly property real helloTrackOff: 0.06
    readonly property int helloCtaBottom: 96
    readonly property int helloCtaGap: 18
    readonly property int helloDisc: 52
    readonly property int helloDiscFont: 20
    readonly property int helloBreath: 2400          // le A respire (×1,04, halo de 8 px)
    readonly property real helloBreathScale: 1.04
    readonly property int helloBreathRing: 8
    readonly property color helloBreathInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.08)
    readonly property int helloCtaSize: 15
    readonly property int helloCornerSide: 56
    readonly property int helloCornerBottom: 40
    readonly property int helloLogoSize: 13
    readonly property int helloPadSize: 12
    readonly property color helloCornerInk: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.4)
    // Code PIN (MotionAppairage) : cases de 88 × 108, chiffres de 56 px.
    readonly property int pairStepTop: 150
    readonly property int pairTitleTop: 180
    readonly property int pairTitleSize: 32
    readonly property int pairTextGap: 10
    readonly property int pairBoxesTop: 300
    readonly property int pairBox: 88
    readonly property int pairBoxHeight: 108
    readonly property int pairBoxGap: 16
    readonly property int pairBoxRadius: 20
    readonly property color pairBoxFill: Qt.rgba(1, 1, 1, 0.07)
    readonly property color pairBoxStroke: Qt.rgba(1, 1, 1, 0.12)
    readonly property int pairDigitSize: 56
    readonly property int pairBoxIn: 600             // les cases entrent (curveMain), 60 ms d'écart
    readonly property int pairBoxFade: 400
    readonly property int pairBoxStagger: 60
    readonly property real pairBoxFrom: 0.92
    readonly property int pairDigitDelay: 400        // puis les chiffres, 110 ms d'écart
    readonly property int pairDigitStagger: 110
    readonly property int pairDigitMove: 520         // ressort (.3, 1.25, .4, 1)
    readonly property int pairDigitFade: 360
    readonly property int pairDigitShift: 14
    readonly property int pairDigitBlur: 8
    // Associé : les cases se rejoignent au centre (520 ms, 40 ms d'écart du centre), la coche
    // apparaît (620 ms, ressort fort) et se trace (420 ms), puis « Continuer ».
    readonly property int pairGather: 520
    readonly property int pairGatherFade: 360
    readonly property int pairGatherStagger: 40
    readonly property real pairGatherScale: 0.6
    readonly property int pairCheckDelay: 220
    readonly property int pairCheck: 96
    readonly property int pairCheckTop: 306
    readonly property int pairCheckPop: 620
    readonly property var curvePairCheck: [0.3, 1.4, 0.4, 1, 1, 1]
    readonly property int pairCheckFade: 250
    readonly property real pairCheckFrom: 0.4
    readonly property int pairCheckDraw: 420
    readonly property int pairCheckDrawDelay: 500
    readonly property int pairCheckGlow: 45          // ombre orange (0 20 60, accent 45 %)
    readonly property int pairWaitTop: 450
    readonly property int pairWaitSize: 14
    readonly property int pairWaitSpinner: 18
    readonly property int pairWaitDelay: 1000
    readonly property int pairCtaTop: 500
    readonly property int pairCtaDelay: 800
    readonly property int pairCtaFade: 420
    readonly property int pairCtaMove: 600
    readonly property int pairCtaShift: 16
    readonly property int pairSwapFade: 380          // titre : l'ancien monte, le nouveau arrive
    readonly property int pairSwapMove: 520
    readonly property int pairSwapShift: 12
    readonly property int pairSwapBlur: 6
    readonly property int pairSwapDelay: 160
    // Bibliothèque : 18 jaquettes (82 × 116, 3 × 6), la progression, les préférences.
    readonly property int libGridLeft: 96
    readonly property int libGridTop: 236
    readonly property size libTile: Qt.size(82, 116)
    readonly property int libTileGapX: 10
    readonly property int libTileGapY: 16
    readonly property int libTileRadius: 8
    readonly property int libColumns: 6
    readonly property int libTiles: 18
    readonly property color libSkeleton: Qt.rgba(1, 1, 1, 0.07)
    readonly property color libShimmer: Qt.rgba(1, 1, 1, 0.08)
    readonly property int libShimmerSweep: 1600
    readonly property int libShimmerStagger: 100
    readonly property int libTileFade: 500
    readonly property int libProgressTop: 640
    readonly property int libProgressWidth: 540
    readonly property int libProgressSize: 13
    readonly property int libBarGap: 10
    readonly property int libBar: 4
    readonly property color libBarTrack: Qt.rgba(1, 1, 1, 0.12)
    readonly property int libBarMove: 600
    readonly property int libPrefsLeft: 700
    readonly property int libPrefsWidth: 484
    readonly property int libStartGap: 26
    // Accents proposés (SetupBibliotheque) ; l'accent choisi suit en phase 9.
    // Code QR de l'installation (hors maquette) : carte blanche, 4 modules de marge.
    readonly property int qrTopGap: 10
    readonly property int qrCard: 260
    readonly property int qrRadius: 20
    readonly property int qrQuiet: 18
    readonly property int qrUrlGap: 18
    readonly property var accentChoices: ["#F2802A", "#F5F5F7", "#6E9BFF", "#7BD88F", "#FF6B8B"]
    // Fin (MotionSetupFin) : la configuration s'efface, l'anneau se trace, « Tout est prêt. ».
    readonly property int finPress: 110
    readonly property int finPressBack: 520
    readonly property var curveFinPress: [0.3, 1.6, 0.4, 1, 1, 1]
    readonly property int finLeave: 80               // après l'appui…
    readonly property int finFade: 420               // …la configuration s'efface en se floutant (12 px, ×0,96)
    readonly property int finShrink: 520             // curveExit
    readonly property int finBlur: 12
    readonly property real finScale: 0.96
    readonly property int finRingDelay: 430           // (depuis l'appui)
    readonly property int finRingSize: 120
    readonly property int finRingTop: 260
    readonly property int finRingStroke: 20
    readonly property int finRingPop: 640            // ressort (.3, 1.25, .4, 1)
    readonly property real finRingFrom: 0.7
    readonly property int finRingDraw: 1300          // trait tracé (.65, 0, .35, 1)
    readonly property int finRingDrawDelay: 100
    readonly property var curveFinDraw: [0.65, 0, 0.35, 1, 1, 1]
    readonly property int finGlow: 200
    readonly property int finGlowTop: 220
    readonly property real finGlowRest: 0.3
    readonly property real finGlowPeak: 0.8
    readonly property int finGlowPeakAt: 1250        // depuis l'anneau
    readonly property int finTextDelay: 650          // depuis l'anneau
    readonly property int finTextTop: 420
    readonly property int finTitleSize: 44
    readonly property int finSubSize: 16
    readonly property int finTextGap: 10
    readonly property int finTextOutAt: 1950         // depuis l'anneau : le texte part…
    readonly property int finRingOutAt: 2050         // …puis l'anneau
    readonly property int finOut: 360                // (anneau : ×0,2)
    readonly property real finRingTo: 0.2
    readonly property int finHomeDelay: 100          // l'accueil revient (en éventail)
}
