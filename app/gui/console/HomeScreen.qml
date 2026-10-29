import QtQuick

// Écran d'accueil CocoOS (AccueilCarrousel) : assemble le fond flouté, la barre haute et
// ses onglets de catégories, le carrousel 3D, le bloc titre, l'aide en bas et le panneau
// d'options, et règle leur mouvement d'ensemble (entrée, dérive du fond, effacement au
// lancement d'un jeu).
// Présentation pure : les données viennent de ConsoleHome (ou des harnais de
// docs/ui/ambiant/harness/ et docs/ui/cocoos/harness/). Aucune dépendance Moonlight.
//
// Remplit son parent. Tout le contenu est dessiné sur un canevas de 800 de haut
// (Theme.canvasHeight), mis à l'échelle de l'écran en une seule transformation ;
// la largeur du canevas suit le format de l'écran.
FocusScope {
    id: root

    // --- Jeux : le modèle (rôle `boxart`) et la sélection ---
    property alias model: shelf.model
    property alias currentIndex: shelf.currentIndex
    readonly property alias count: shelf.count

    // --- Jeu sélectionné ---
    property alias title: hero.title
    property alias logo: hero.logo
    property alias source: hero.source
    property alias lastPlayed: hero.lastPlayed
    property alias playtime: hero.playtime
    property alias updateNote: hero.updateNote
    property alias running: hero.running
    property alias runningGame: shelf.runningName   // son point sur l'étagère
    property alias playLabel: hero.playLabel        // « Télécharger »… ; vide = Jouer
    property alias favorite: hero.favorite          // épinglé : X le détache
    // Méta sous le titre (« Mojang Studios », « 2011 », « Bac à sable » : un absent n'y est
    // pas) et le PEGI (« PEGI 7 » ; vide : pas de pastille).
    property var meta: []
    property string pegi: ""
    property alias backdrop: backdropLayer.source    // image de fond du jeu sélectionné
    // Teinte ambiante (couleur dominante du fond) : le bas du voile. Par défaut
    // l'accent, sans teinte du voile.
    property color ambient: Theme.accent
    property bool ambientTint: false

    // --- PC hôte et état de la console ---
    property alias hostName: status.hostName
    property alias connected: status.connected
    property alias hostState: status.hostState       // "asleep", "offline", "waking", "online" (StatusBar)
    property alias waking: hero.waking               // le bouton Jouer suit le réveil du PC
    // PC hors ligne (EtatHorsLigne) : carrousel grisé, et son message à la place du bloc titre.
    property bool hostOffline: false
    // Un menu centré par-dessus (choix du PC, menu d'alimentation) : le carrousel s'assombrit sous
    // la barre haute, le bloc titre et l'aide s'effacent.
    property bool menuShown: false
    // Le retour de l'accueil (`launching` repasse à faux) : "game" (MotionQuitter), "wake"
    // (MotionVeille : plus vif, de moins loin) ou "idle" (MotionReveil : après l'écran de veille,
    // les jaquettes s'ouvrent en éventail depuis le centre).
    property string returnStyle: "game"
    // Ses minutages : délais, durées, décalages de chaque bloc (Theme.return*, wake*, idle*).
    readonly property var ret: returnStyle === "wake" ? {
            CoverDelay: 0, CoverStagger: Theme.wakeCoverStagger, CoverMove: Theme.wakeCoverMove,
            CoverFade: Theme.wakeCoverFade, CoverGather: Theme.wakeCoverGather, CoverScale: Theme.wakeCoverScale,
            TitleDelay: Theme.wakeTitleDelay, RiseFade: Theme.wakeRiseFade, RiseMove: Theme.wakeRiseMove,
            RiseShift: Theme.wakeRiseShift, BarDelay: Theme.wakeBarDelay, BarFade: Theme.wakeBarFade,
            BarMove: Theme.wakeBarMove, BarShift: Theme.wakeBarShift, HelpDelay: Theme.wakeBarDelay }
        : returnStyle === "idle" ? {
            CoverDelay: Theme.idleCoverDelay, CoverStagger: Theme.idleCoverStagger, CoverMove: Theme.idleCoverMove,
            CoverFade: Theme.idleCoverMove, CoverGather: 1, CoverScale: Theme.idleCoverScale,
            TitleDelay: Theme.idleTitleDelay, RiseFade: Theme.idleRise, RiseMove: Theme.idleRise,
            RiseShift: Theme.returnRiseShift, BarDelay: Theme.idleBarDelay, BarFade: Theme.idleBarMove,
            BarMove: Theme.idleBarMove, BarShift: Theme.returnBarShift, HelpDelay: Theme.idleHelpDelay }
        : {
            CoverDelay: Theme.returnCoverDelay, CoverStagger: Theme.returnCoverStagger, CoverMove: Theme.returnCoverMove,
            CoverFade: Theme.returnCoverFade, CoverGather: Theme.returnCoverGather, CoverScale: Theme.returnCoverScale,
            TitleDelay: Theme.returnTitleDelay, RiseFade: Theme.returnRiseFade, RiseMove: Theme.returnRiseMove,
            RiseShift: Theme.returnRiseShift, BarDelay: Theme.returnBarDelay, BarFade: Theme.returnBarFade,
            BarMove: Theme.returnBarMove, BarShift: Theme.returnBarShift, HelpDelay: Theme.returnBarDelay }
    // Le départ (`launching` passe à vrai) : "spread" (un jeu : les voisines s'écartent) ou
    // "collapse" (l'extinction : elles se replient vers le centre, en rapetissant).
    property string leaveStyle: "spread"
    readonly property bool collapseStyle: leaveStyle === "collapse"
    // Mise en veille (MotionVeille) : l'accueil recule et s'efface, un point s'allume au centre
    // puis s'éteint. Au réveil, `napping` repasse à faux et l'accueil revient (`launching`).
    property bool napping: false
    onNappingChanged: if (napping && !Theme.reducedMotion) sleepDot.restart()
    readonly property alias offline: offlineState
    property alias latencyMs: status.latencyMs
    property alias jitterMs: status.jitterMs
    property alias signalStrength: status.signalStrength
    property alias batteryPercent: status.batteryPercent
    property alias charging: status.charging
    property alias controllerBattery: status.controllerBattery
    property alias controllerCount: status.controllerCount
    property alias controllerFamily: status.controllerFamily
    // Icônes de droite de la barre haute (haut depuis l'étagère ou le héros) : leurs fiches,
    // et ce que fait A. Les réglages ouvrent le panneau d'options sur l'onglet Console.
    property alias wifi: status.wifi
    property alias batteryDetails: status.batteryDetails
    property alias wifiChangeable: status.wifiChangeable
    signal systemRequested(string key)               // "wifi"
    // Île de notification de la barre haute : permise une fois l'accueil entré (le logo de
    // démarrage a atterri), sans panneau ni lancement ; l'appelant y ajoute la veille.
    property bool notificationsAllowed: true
    readonly property alias notification: status.notification
    function notify(n) { status.notify(n) }
    function dismissNotification() { return status.dismiss() }
    // Le logotype de la barre haute (cible de l'animation de démarrage) et sa visibilité.
    readonly property alias statusLogo: status.logo
    property alias statusLogoShown: status.logoShown
    property alias timeText: status.timeText

    // --- Écrans de message (recherche du PC, appairage) : cf. MessageScreen ---
    // À poser dans `stage` (pixels du canevas, sous le panneau d'options). Tant que
    // `staged` est vrai, le héros et l'étagère s'effacent et la manette va à `stage`.
    readonly property alias stage: stage
    property bool staged: false
    // --- Fiche du jeu (GamePage) : à poser dans `detailStage` ; `detailOpen` fait glisser la
    //     jaquette centrale à gauche et efface le reste de l'accueil (MotionFiche). ---
    readonly property alias detailStage: detailStage
    property bool detailOpen: false
    readonly property real detail: shelf.detail
    // Favori ajouté ou retiré : la bannière (MotionFavori), sur l'accueil comme sur la fiche.
    function favoriteFeedback(added) {
        favBanner.show(added)
        Sounds.play(added ? "favorite_add" : "favorite_remove")
    }
    readonly property alias favoriteBanner: favBanner

    // L'accueil entre quand on le lui permet (`entryAllowed` : l'animation de démarrage
    // en est à sa sortie) : la barre haute d'emblée, le héros et l'étagère dès que
    // `ready` (les jeux sont chargés). Retirer la permission le masque d'un coup
    // (sortie de veille, qui le refait entrer).
    property bool ready: false
    property bool entryAllowed: true
    // Autorise la dérive lente du fond ; elle se coupe de toute façon d'elle-même
    // après Theme.driftIdleTimeout sans action.
    property bool driftAllowed: true

    // --- Lancement d'un jeu ---
    // `pressed` enfonce le bouton Jouer ; `launching` efface l'accueil (la barre
    // haute s'éteint, le héros part à gauche, l'étagère descend, le fond zoome sans
    // son voile) pendant que LaunchScreen prend l'écran. Tout revient quand il repasse à faux.
    property alias pressed: hero.pressed
    property bool launching: false
    // Place de la vignette du jeu sélectionné sur le canevas (agrandie) : l'écran de
    // lancement en part.
    readonly property rect activeThumbRect: shelf.activeRect

    // --- Options (bouton Y) : cf. OptionsSheet ---
    readonly property alias options: sheet           // options.open(), options.opened…
    readonly property alias shelf: shelf             // l'étagère (shelf.pressing : A tenu)
    readonly property alias hero: hero               // le héros (ses boutons, partie en cours)
    readonly property alias statusBar: status        // la barre haute (ses icônes de droite)
    // Partie en cours : haut depuis l'étagère donne la manette aux boutons du héros
    // (Reprendre, Quitter) ; bas ou B la rendent. Elle revient d'elle-même à l'étagère quand
    // la partie s'arrête ou qu'un lancement commence.
    property alias optionTabs: sheet.tabs            // [{ label, rows }]
    readonly property alias optionRows: sheet.rows   // lignes de l'onglet affiché
    property alias optionsSubtitle: sheet.subtitle   // « PC-Salon · connecté · 4 ms »
    // Un autre panneau latéral (ConsoleDialog) est ouvert par-dessus l'accueil.
    property bool panelOpen: false

    signal launchRequested(int index)
    signal quitRequested()                           // Quitter la partie, tenu jusqu'au bout
    signal optionChanged(string key, int index)
    signal optionAction(string key)
    signal forgetRequested()                         // « Oublier ce PC », maintenu jusqu'au bout
    signal favoriteRequested()                       // X sur l'étagère
    signal detailsRequested()                        // bas sur l'étagère : la fiche du jeu
    // Collections de l'étagère : leurs libellés (masquées s'il n'y en a qu'une) et celle
    // affichée ; collectionRequested(±1) : L1 / R1, Page préc. / suiv., ou un clic.
    property var collectionLabels: []
    property int collectionIndex: 0
    signal collectionRequested(int direction)
    // La catégorie affichée est « Favoris » et elle est vide : son état remplace le carrousel.
    property bool favoritesEmpty: false
    signal recentRequested()                         // le bouton « Voir les jeux récents »

        // À appeler juste AVANT de changer la collection affichée : LB / RB s'allument, le titre
    // suivant arrivera de côté (MotionCategories). Le carrousel, lui, entre par shelf.slideIn.
    property int categoryDirection: 0
    function categoryStart(direction) {
        categoryDirection = direction
        tabs.pressed(direction)
        categoryEnd.restart()
    }
    Timer { id: categoryEnd; interval: Theme.categoryEnterMove; onTriggered: root.categoryDirection = 0 }

    // Message bref au-dessus de l'étagère.
    function toast(message) { toastItem.show(message) }
    // Jouer est impossible : le bouton Jouer se secoue.
    function refusePlay() { hero.refusePlay() }

    // À appeler quand l'utilisateur agit sans changer de jeu : relance la dérive.
    function wake() { idle.restart() }

    property bool heroFocused: false
    property bool statusFocused: false               // la barre haute a la manette
    onRunningChanged: if (!running) heroFocused = false
    onLaunchingChanged: if (launching) heroFocused = statusFocused = false

    readonly property bool entered: ready && entryAllowed   // héros et étagère sont entrés
    property bool settled: false     // …et c'est fini : plus aucun délai par rang

    onEnteredChanged: {
        if (!entered) settled = false
        idle.restart()
    }
    onCurrentIndexChanged: {
        idle.restart()
        heroFocused = false
    }

    Binding {
        target: Theme; property: "scale"
        value: root.height > 0 ? root.height / Theme.canvasHeight : 1
    }
    Timer { interval: Theme.enterSettle; running: root.entered; onTriggered: root.settled = true }
    Timer { id: idle; interval: Theme.driftIdleTimeout }

    Rectangle { anchors.fill: parent; color: Theme.background }

    // S'efface au lancement d'un jeu (fondu, `leaveShift` vers le bas), revient au retour après
    // `returnDelay`, depuis `shift` (MotionLancement, MotionQuitter). Sans déplacement en
    // animations réduites.
    component LaunchFade: Item {
        id: fade
        property real shift: 0
        property real leaveShift: 0
        property int returnDelay: 0
        property int returnFade: 0
        property int returnMove: 0
        readonly property bool away: root.launching
        // Au départ, il glisse de `leaveShift` ; une fois effacé, il se place à `shift` pour revenir.
        property real dy: 0
        onAwayChanged: {
            leave.stop(); back.stop()
            if (away) leave.restart(); else back.restart()
        }
        ParallelAnimation {
            id: leave
            NumberAnimation { target: fade; property: "opacity"; to: 0; duration: Theme.launchHomeFade }
            SequentialAnimation {
                NumberAnimation {
                    target: fade; property: "dy"; to: Theme.reducedMotion ? 0 : fade.leaveShift; duration: Theme.launchHomeMove
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                }
                PropertyAction { target: fade; property: "dy"; value: Theme.reducedMotion ? 0 : fade.shift }
            }
        }
        SequentialAnimation {
            id: back
            PauseAnimation { duration: Theme.reducedMotion ? 0 : fade.returnDelay }
            ParallelAnimation {
                NumberAnimation { target: fade; property: "opacity"; to: 1; duration: Theme.reducedMotion ? Theme.reducedSpring.duration : fade.returnFade }
                NumberAnimation {
                    target: fade; property: "dy"; to: 0; duration: fade.returnMove
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                }
            }
        }
        transform: Translate { y: fade.dy }
    }

    Item {
        id: canvas
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        // L'accueil recule derrière la feuille d'options (MotionOptions) : il rétrécit autour
        // de Theme.recedeOrigin, s'assombrit et s'arrondit.
        Item {
            id: homeLayer
            anchors.fill: parent
            property real recede: sheet.opened ? 1 : 0
            Behavior on recede {
                NumberAnimation {
                    duration: Theme.reducedMotion ? Theme.reducedSpring.duration : sheet.opened ? Theme.recedeIn : Theme.recedeOut
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                }
            }
            transform: [
                Scale {
                    origin.x: homeLayer.width * Theme.recedeOrigin.x
                    origin.y: homeLayer.height * Theme.recedeOrigin.y
                    xScale: 1 - (1 - Theme.recedeScale) * homeLayer.recede * (Theme.reducedMotion ? 0 : 1)
                    yScale: xScale
                },
                // Mise en veille : il recule vers le centre en s'effaçant ; au réveil, il est déjà en place.
                Scale {
                    origin.x: homeLayer.width / 2; origin.y: homeLayer.height / 2
                    xScale: homeLayer.sleepScale; yScale: xScale
                }
            ]
            property real sleepScale: root.napping && !Theme.reducedMotion ? Theme.sleepScale : 1
            Behavior on sleepScale { enabled: root.napping; NumberAnimation { duration: Theme.sleepShrink; easing.type: Easing.InCubic } }
            opacity: root.napping ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: root.napping ? Theme.sleepFade : Theme.wakeFade
                    easing.type: root.napping ? Easing.InCubic : Easing.OutCubic
                }
            }

            BackdropLayer {
                id: backdropLayer
                anchors.fill: parent
                driftEnabled: root.driftAllowed && idle.running && !root.launching && !sheet.opened && !Theme.reducedMotion
                opacity: root.entered ? 1 : 0
                vignetteAt: Qt.point(Theme.vignetteAt.x + (Theme.vignetteAtFiche.x - Theme.vignetteAt.x) * root.detail,
                                     Theme.vignetteAt.y + (Theme.vignetteAtFiche.y - Theme.vignetteAt.y) * root.detail)
                vignetteIn: Theme.vignetteIn + (Theme.vignetteInFiche - Theme.vignetteIn) * root.detail
                vignetteOut: (root.hostOffline ? Theme.vignetteOutOffline : Theme.vignetteOut)
                             + (Theme.vignetteOutFiche - Theme.vignetteOut) * root.detail
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.entered ? Theme.entryCardFade : 0
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmph
                    }
                }
            }

            // Favoris vide : son état (et son fond) à la place du carrousel, sous la barre haute.
            EmptyFavorites {
                anchors.fill: parent
                visible: opacity > 0
                opacity: root.favoritesEmpty && root.entered && !root.staged ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.entryTextFade } }
                onRecentRequested: root.recentRequested()
            }

            // Au lancement d'un jeu, la barre haute s'efface ; au retour, elle revient la
            // dernière, de 10 px plus haut (MotionQuitter). Elle fait entrer ses textes
            // elle-même (son logo arrive de l'animation de démarrage).
            LaunchFade {
                z: 2
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: status.implicitHeight
                shift: root.ret.BarShift
                returnDelay: root.ret.BarDelay
                returnFade: root.ret.BarFade
                returnMove: root.ret.BarMove

                StatusBar {
                    id: status
                    anchors.fill: parent
                    focus: root.statusFocused && !root.staged && !sheet.opened
                    onLeaveRequested: {
                        root.statusFocused = false
                        Sounds.play("move")
                    }
                    onActivated: function(key) {
                        if (key === "settings") sheet.open(1)
                        else root.systemRequested(key)
                    }
                    systemShown: !sheet.opened && !root.panelOpen
                    contentShown: root.entryAllowed
                    notificationsAllowed: root.notificationsAllowed && root.settled && root.statusLogoShown
                                          && !sheet.opened && !root.panelOpen && !root.launching && !root.detailOpen
                    logoFade: 1 - root.detail
                }

                // Catégories, au centre de la barre haute.
                CategoryTabs {
                    id: tabs
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.tabsTop
                    labels: root.collectionLabels
                    currentIndex: root.collectionIndex
                    visible: labels.length > 1 && opacity > 0
                    opacity: (root.entryAllowed ? 1 : 0) * (1 - root.detail)
                    transform: Translate { y: -8 * root.detail }
                    Behavior on opacity { enabled: root.detail === 0; NumberAnimation { duration: Theme.entryTextFade } }
                    onRequested: function(delta) { root.collectionRequested(delta) }
                }
            }

            // Le carrousel (fondus des bords compris) : il descend sous un écran de message ;
            // au lancement d'un jeu, ses jaquettes s'écartent (CoverFlow.launching).
            Appear {
                width: parent.width; height: parent.height
                shown: !root.staged
                hiddenY: Theme.stageShelfShift
                hideDuration: Theme.stageHide
                animateInitially: false

                CoverFlow {
                    id: shelf
                    anchors.fill: parent
                    // La manette va au carrousel, à l'écran de message ou au panneau ouvert :
                    // le focus suit ces liaisons, il revient seul à la fermeture.
                    focus: !root.staged && !root.detailOpen && !sheet.opened && !root.heroFocused && !root.statusFocused
                    shown: root.entered
                    launching: root.launching
                    gatherDelay: root.ret.CoverDelay
                    gatherStagger: root.ret.CoverStagger
                    gatherMove: root.ret.CoverMove
                    gatherFade: root.ret.CoverFade
                    gatherAmount: root.collapseStyle ? 1 : root.ret.CoverGather
                    gatherScale: root.collapseStyle ? Theme.shutdownCoverScale : root.ret.CoverScale
                    leaveGather: root.collapseStyle
                    greyed: root.hostOffline
                    detailOpen: root.detailOpen
                    onLaunchRequested: function(index) { root.launchRequested(index) }
                    onDetailsRequested: root.detailsRequested()
                    onUpRequested: {
                        if (hero.running) root.heroFocused = true
                        else if (status.keys.length > 0) root.statusFocused = true
                        else return
                        Sounds.play("move")
                    }
                    Keys.onMenuPressed: root.favoriteRequested()      // bouton X
                    onCollectionRequested: function(direction) { root.collectionRequested(direction) }
                }
            }

            Appear {
                y: Theme.homeTitleTop
                width: parent.width; height: hero.implicitHeight
                shown: root.entered && !root.favoritesEmpty
                hiddenY: 0
                hideDuration: 0
                fadeDuration: Theme.entryTextFade
                fadeEasing: Easing.OutCubic

                Appear {
                    anchors.fill: parent
                    shown: !root.staged
                    hiddenX: Theme.stageHeroShift
                    hiddenY: 0
                    hideDuration: Theme.stageHide
                    animateInitially: false

                    LaunchFade {
                    anchors.fill: parent
                    shift: root.ret.RiseShift
                    leaveShift: Theme.launchHomeShift
                    returnDelay: root.ret.TitleDelay
                    returnFade: root.ret.RiseFade
                    returnMove: root.ret.RiseMove

                    HeroBlock {
                        id: hero
                        width: parent.width
                        // Fiche ouverte : le bloc titre part vers le haut en fondu (220 ms), et revient
                        // après 300 ms quand elle se referme (MotionFiche).
                        opacity: root.detailOpen || root.hostOffline || root.menuShown ? 0 : 1
                        property real lift: root.detailOpen ? -Theme.homeLeaveTravel : 0
                        transform: Translate { y: hero.lift }
                        Behavior on opacity {
                            SequentialAnimation {
                                PauseAnimation { duration: root.detailOpen ? 0 : Theme.homeReturnDelay }
                                NumberAnimation { duration: root.detailOpen ? Theme.ficheOut : Theme.homeReturn }
                            }
                        }
                        Behavior on lift {
                            SequentialAnimation {
                                PauseAnimation { duration: root.detailOpen ? 0 : Theme.homeReturnDelay }
                                NumberAnimation {
                                    duration: root.detailOpen ? Theme.ficheOut + 100 : Theme.homeReturnMove
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                                }
                            }
                        }
                        focus: root.heroFocused && !root.statusFocused && !root.staged && !sheet.opened
                        meta: root.meta
                        pegi: root.pegi
                        axis: root.categoryDirection !== 0 ? "x" : "y"
                        direction: root.categoryDirection !== 0 ? root.categoryDirection : shelf.direction
                        fast: shelf.fast
                        held: shelf.pressing
                        animated: root.entered
                        actionsShown: root.entered
                        onPlayRequested: root.launchRequested(shelf.currentIndex)
                        onQuitRequested: root.quitRequested()
                        onLeaveRequested: {
                            root.heroFocused = false
                            Sounds.play("move")
                        }
                        onUpRequested: {
                            root.statusFocused = true
                            Sounds.play("move")
                        }
                        onHoldHintRequested: root.toast(qsTr("Maintenez A pour quitter la partie"))
                        onOptionsRequested: sheet.open()
                        onFavoriteRequested: root.favoriteRequested()
                    }
                    }
                }
            }

            // Aide en bas : « ◀ ▶ Parcourir   ↓ Plus d'infos ».
            // (au retour d'un jeu, elle revient avec la barre haute)
            LaunchFade {
                anchors.fill: parent
                returnDelay: root.ret.HelpDelay
                returnFade: root.ret.BarFade
                returnMove: root.ret.BarMove
                HomeHelp {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.canvasHeight - Theme.helpBottom - height
                    lit: shelf.heldDirection
                    opacity: root.entered && !root.staged && !root.favoritesEmpty && !root.detailOpen
                             && !favBanner.shown && !root.hostOffline && !root.menuShown ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.entryTextFade } }
                }
            }

            // PC hors ligne : son message, ses boutons et sa légende.
            LaunchFade {
                anchors.fill: parent
                shift: root.ret.RiseShift
                leaveShift: Theme.launchHomeShift
                returnDelay: root.ret.TitleDelay
                returnFade: root.ret.RiseFade
                returnMove: root.ret.RiseMove
                OfflineState {
                    id: offlineState
                    anchors.fill: parent
                    hostName: status.hostName
                    pressing: shelf.pressing
                    visible: opacity > 0
                    opacity: root.hostOffline && root.entered && !root.staged && !root.favoritesEmpty && !root.detailOpen ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.offlineFade } }
                }
            }

            Toast { id: toastItem }

            // La fiche du jeu (GamePage), par-dessus le carrousel.
            FocusScope {
                id: detailStage
                anchors.fill: parent
                focus: root.detailOpen && !sheet.opened
            }

            FavoriteBanner {
                id: favBanner
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.canvasHeight - Theme.bannerBottom - height
            }

            FocusScope {
                id: stage
                anchors.fill: parent
                focus: root.staged && !sheet.opened
            }

            // Sous la barre haute, pendant le choix du PC.
            Rectangle {
                z: 1
                anchors.fill: parent
                color: Theme.pickerDim
                opacity: root.menuShown ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.pickerOut } }
            }

            // Assombri, et coins arrondis : un cadre noir dont le bord intérieur s'arrondit.
            Rectangle {
                z: 3
                anchors.fill: parent
                color: Theme.background
                opacity: Theme.recedeDim * homeLayer.recede
            }
            Rectangle {
                z: 3
                visible: homeLayer.recede > 0
                x: -Theme.recedeFrame; y: -Theme.recedeFrame
                width: parent.width + 2 * Theme.recedeFrame; height: parent.height + 2 * Theme.recedeFrame
                radius: Theme.recedeFrame + Theme.recedeRadius * homeLayer.recede
                color: "transparent"
                border.width: Theme.recedeFrame; border.color: Theme.background
            }
        }

        // Le point de la mise en veille : il s'allume au centre, puis s'éteint.
        Rectangle {
            id: dot
            x: (parent.width - width) / 2; y: Theme.canvasHeight / 2 - height / 2
            width: Theme.sleepDot; height: width; radius: width / 2
            color: Theme.accent
            opacity: 0
            Glow {
                anchors.centerIn: parent
                width: Theme.sleepGlow; height: width
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.sleepGlowAlpha)
                z: -1
            }
            SequentialAnimation {
                id: sleepDot
                PropertyAction { target: dot; property: "scale"; value: Theme.sleepDotFrom }
                PauseAnimation { duration: Theme.sleepDotDelay }
                ParallelAnimation {
                    NumberAnimation { target: dot; property: "opacity"; to: 1; duration: Theme.sleepDotIn; easing.type: Easing.OutCubic }
                    NumberAnimation {
                        target: dot; property: "scale"; to: 1; duration: Theme.sleepDotMove
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                    }
                }
                PauseAnimation { duration: Theme.sleepDotHold }
                ParallelAnimation {
                    NumberAnimation { target: dot; property: "opacity"; to: 0; duration: Theme.sleepDotOut; easing.type: Easing.InCubic }
                    NumberAnimation { target: dot; property: "scale"; to: Theme.sleepDotTo; duration: Theme.sleepDotOut; easing.type: Easing.InCubic }
                }
            }
        }

        OptionsSheet {
            id: sheet
            anchors.fill: parent
            backdrop: homeLayer
            connected: status.connected
            onChanged: function(key, index) { root.optionChanged(key, index) }
            onActionRequested: function(key) { root.optionAction(key) }
            onHoldCompleted: function(key) { if (key === "forget") root.forgetRequested() }
            onClosed: idle.restart()
        }
    }
}
