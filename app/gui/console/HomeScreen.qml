import QtQuick

// Écran d'accueil « Ambiant » : assemble le fond, la barre haute, le bloc héros,
// l'étagère et le panneau d'options, et règle leur mouvement d'ensemble (entrée
// en cascade, dérive du fond, effacement au lancement d'un jeu).
// Présentation pure : les données viennent de ConsoleHome (ou du harnais de
// docs/ui/ambiant/harness/). Aucune dépendance Moonlight.
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
    property alias playLabel: hero.playLabel        // « Télécharger »… ; vide = Jouer
    property alias favorite: hero.favorite          // épinglé : X le détache
    property alias backdrop: backdropLayer.source    // image de fond du jeu sélectionné
    // Teinte ambiante (couleur dominante du fond) : voile et soulignement. Par
    // défaut l'accent, sans teinte du voile.
    property color ambient: Theme.accent
    property bool ambientTint: false

    // --- PC hôte et état de la console ---
    property alias hostName: status.hostName
    property alias connected: status.connected
    property alias latencyMs: status.latencyMs
    property alias jitterMs: status.jitterMs
    property alias signalStrength: status.signalStrength
    property alias batteryPercent: status.batteryPercent
    property alias charging: status.charging
    property alias controllerBattery: status.controllerBattery
    // Le logotype de la barre haute (cible de l'animation de démarrage) et sa visibilité.
    readonly property alias statusLogo: status.logo
    property alias statusLogoShown: status.logoShown
    property alias timeText: status.timeText

    // --- Écrans de message (recherche du PC, appairage) : cf. MessageScreen ---
    // À poser dans `stage` (pixels du canevas, sous le panneau d'options). Tant que
    // `staged` est vrai, le héros et l'étagère s'effacent et la manette va à `stage`.
    readonly property alias stage: stage
    property bool staged: false

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
    // Place de la vignette du jeu sélectionné sur le canevas (agrandie, soulevée) :
    // l'écran de lancement en part.
    readonly property rect activeThumbRect: Qt.rect(
        Theme.margin,
        Theme.shelfBottom - Theme.shelfActiveLift - Theme.shelfThumbSize.height * Theme.shelfActiveScale,
        Theme.shelfThumbSize.width * Theme.shelfActiveScale,
        Theme.shelfThumbSize.height * Theme.shelfActiveScale)

    // --- Options (bouton Y) : cf. OptionsSheet ---
    readonly property alias options: sheet           // options.open(), options.opened…
    property alias optionTabs: sheet.tabs            // [{ label, rows }]
    readonly property alias optionRows: sheet.rows   // lignes de l'onglet affiché
    property alias optionsHost: sheet.hostName       // PC que le panneau propose d'oublier
    // Un autre panneau latéral (ConsoleDialog) est ouvert par-dessus l'accueil.
    property bool panelOpen: false

    signal launchRequested(int index)
    signal optionChanged(string key, int index)
    signal optionAction(string key)
    signal forgetRequested()
    signal favoriteRequested()                       // X sur l'étagère
    signal detailsRequested()                        // bas sur l'étagère : la fiche du jeu

    // Message bref au-dessus de l'étagère.
    function toast(message) { toastItem.show(message) }

    // À appeler quand l'utilisateur agit sans changer de jeu : relance la dérive.
    function wake() { idle.restart() }

    readonly property bool entered: ready && entryAllowed   // héros et étagère sont entrés
    property bool settled: false     // …et c'est fini : plus aucun délai par rang

    onEnteredChanged: {
        if (!entered) settled = false
        idle.restart()
    }
    onCurrentIndexChanged: idle.restart()

    Binding {
        target: Theme; property: "scale"
        value: root.height > 0 ? root.height / Theme.canvasHeight : 1
    }
    Timer { interval: Theme.enterSettle; running: root.entered; onTriggered: root.settled = true }
    Timer { id: idle; interval: Theme.driftIdleTimeout }

    Rectangle { anchors.fill: parent; color: Theme.background }

    Item {
        id: canvas
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        BackdropLayer {
            id: backdropLayer
            anchors.fill: parent
            driftEnabled: root.driftAllowed && idle.running && !root.launching && !sheet.opened
            opacity: root.entered ? 1 : 0
            zoom: root.launching ? Theme.launchBackdropZoom : 1
            unveiled: root.launching
            tint: root.ambientTint ? root.ambient : "transparent"
            Behavior on opacity {
                NumberAnimation {
                    duration: root.entered ? Theme.entryCardFade : 0
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmph
                }
            }
            Behavior on zoom { NumberAnimation { duration: Theme.backdropZoomDuration; easing.type: Theme.easeOut } }
        }

        // Chaque bloc est enveloppé deux fois : pour son entrée, puis pour son
        // effacement à chaque lancement d'un jeu. La barre haute fait entrer ses textes
        // elle-même (son logo arrive de l'animation de démarrage).
        Appear {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: status.implicitHeight
            shown: !root.launching
            hiddenY: 0
            hideDuration: Theme.launchHide
            animateInitially: false

            StatusBar {
                id: status
                anchors.fill: parent
                systemShown: !sheet.opened && !root.panelOpen
                contentShown: root.entryAllowed
            }
        }

        Appear {
            x: Theme.margin
            y: Theme.heroBottom - height
            width: hero.width; height: hero.implicitHeight
            shown: root.entered
            hiddenY: 0
            hideDuration: 0
            fadeDuration: Theme.entryTextFade
            fadeEasing: Easing.OutCubic

            Appear {
                anchors.fill: parent
                shown: !root.launching && !root.staged
                hiddenX: Theme.launchHeroShift
                hiddenY: 0
                hideDuration: Theme.launchHide
                animateInitially: false

                HeroBlock {
                    id: hero
                    anchors.bottom: parent.bottom
                    direction: shelf.direction
                    animated: root.entered
                    actionsShown: root.entered
                    onPlayRequested: root.launchRequested(shelf.currentIndex)
                    onOptionsRequested: sheet.open()
                    onFavoriteRequested: root.favoriteRequested()
                }
            }
        }

        Appear {
            y: Theme.shelfBottom - Theme.shelfThumbSize.height
            width: parent.width; height: shelf.implicitHeight
            shown: !root.launching && !root.staged
            hiddenY: Theme.launchShelfShift
            hideDuration: Theme.launchHide
            animateInitially: false

            GameShelf {
                id: shelf
                anchors.fill: parent
                // La manette va à l'étagère, à l'écran de message ou au panneau
                // ouvert : le focus suit ces liaisons, il revient seul à la fermeture.
                focus: !root.staged && !sheet.opened
                shown: root.entered
                enterStep: root.settled ? 0 : Theme.entryCardStagger
                accentColor: root.ambient
                onLaunchRequested: function(index) { root.launchRequested(index) }
                onDetailsRequested: root.detailsRequested()
                Keys.onMenuPressed: root.favoriteRequested()      // bouton X
            }
        }

        Toast { id: toastItem }

        FocusScope {
            id: stage
            anchors.fill: parent
            focus: root.staged && !sheet.opened
        }

        OptionsSheet {
            id: sheet
            anchors.fill: parent
            connected: status.connected
            onChanged: function(key, index) { root.optionChanged(key, index) }
            onActionRequested: function(key) { root.optionAction(key) }
            onForgetConfirmed: root.forgetRequested()
            onClosed: idle.restart()
        }
    }
}
