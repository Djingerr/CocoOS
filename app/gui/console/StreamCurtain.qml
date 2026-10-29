import QtQuick

// Rideau CocoOS entre un jeu et l'accueil (MotionQuitter). Posé noir dès que le flux démarre
// (cover) : pendant le flux, la fenêtre de l'accueil est cachée et Qt suspendu ; quand on
// quitte par le menu en jeu, elle réapparaît avant que la fenêtre du flux ne se ferme
// (StreamMenu::finishLeave) : ni trou, ni bureau. Dès qu'elle réapparaît, l'image du jeu,
// floutée et assombrie, prend l'écran (reveal) ; si l'on attend quelque chose (« Fermeture de
// … »), l'anneau, le nom du jeu et l'état s'y ajoutent. Puis le rideau se lève (dismiss) :
// l'image redevient nette en se réduisant jusqu'à la jaquette du carrousel, que l'accueil
// rejoint (`covering` retombe dès le début). Tant qu'il couvre, il garde la manette. Aucune
// dépendance Moonlight.
FocusScope {
    id: root

    property url image                   // image du jeu
    property url thumbnail               // sa jaquette, et sa place sur le canevas
    property rect origin: Qt.rect(0, 0, 0, 0)
    property string title
    property bool covering: false        // l'accueil est caché ; il revient à la levée du rideau
    property bool revealed: false        // image (et ligne d'état) visibles
    property string status: ""
    property bool waiting: false         // une opération est en cours, terminée par dismiss()
    property real revealedAt: 0

    signal lifted()                      // le rideau se lève : la manette revient à l'accueil

    property bool active: false
    property real grow: 1
    property real art: 1
    property real clear: 0               // 0 : floutée et assombrie ; 1 : nette
    visible: active

    function cover() {
        lift.stop(); shrink.stop()
        revealed = false
        status = ""
        waiting = false
        covering = true
        grow = 1; art = 1; clear = 0
        active = true
    }

    // `text` : ligne d'état ; `wait` : une opération en cours, terminée par dismiss().
    function reveal(text, wait) {
        if (!covering) return
        status = text || ""
        waiting = !!wait
        if (!revealed) revealedAt = Date.now()
        revealed = true
        forceActiveFocus()
    }

    // La fenêtre de l'accueil revient (fin du flux) : l'image paraît aussitôt, sans attendre
    // que l'accueil reprenne la main (returnedHome).
    Connections {
        target: root.Window.window
        function onVisibleChanged() {
            if (root.Window.window.visible) root.reveal(root.status, root.waiting)
        }
    }

    // L'image reste au moins Theme.curtainMinShow, pour ne pas clignoter.
    function dismiss() {
        if (!covering) return
        var wait = revealed ? revealedAt + Theme.curtainMinShow - Date.now() : 0
        if (wait > 0) {
            lift.interval = wait
            lift.restart()
        } else {
            liftNow()
        }
    }

    function liftNow() {
        if (!covering) return
        waiting = false
        covering = false
        revealed = true
        shrink.restart()
        lifted()
    }

    Timer {
        id: lift
        onTriggered: root.liftNow()
    }
    Timer {
        interval: Theme.curtainMaxWait
        running: root.waiting
        onTriggered: root.dismiss()
    }
    ParallelAnimation {
        id: shrink
        SequentialAnimation {
            PauseAnimation { duration: Theme.returnFrameDelay }
            NumberAnimation {
                target: root; property: "grow"; to: frame.fromThumb ? 0 : 1
                duration: Theme.motion(Theme.returnFrameShrink, Theme.curveMain).duration
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
            }
        }
        NumberAnimation { target: root; property: "clear"; to: 1; duration: Theme.returnArtClear }
        SequentialAnimation {
            PauseAnimation { duration: Theme.returnArtDelay }
            NumberAnimation { target: root; property: "art"; to: 0; duration: frame.fromThumb ? Theme.returnThumbFade : Theme.returnArtFade }
            ScriptAction { script: root.active = false }
        }
    }

    Keys.onPressed: function(event) { event.accepted = true }
    Keys.onReleased: function(event) { event.accepted = true }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        visible: root.covering
    }

    Item {
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft
        opacity: root.revealed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.curtainReveal } }

        LaunchFrame {
            id: frame
            origin: root.origin
            grow: root.grow
            thumbnail: root.thumbnail
            image: root.image
            // Sans jaquette où revenir, l'image s'efface sur l'accueil.
            art: frame.fromThumb ? root.art : 1
            opacity: frame.fromThumb ? 1 : root.art
            dim: Theme.returnArtDim * (1 - root.clear)
            blur: Theme.returnArtBlur * (1 - root.clear)
        }

        // « Fermeture de … » : l'anneau, le nom du jeu, l'état.
        Column {
            x: (parent.width - width) / 2
            y: Theme.launchColumnTop
            width: Theme.launchColumnWidth
            spacing: 0
            opacity: root.covering && root.status !== "" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.launchLoaderFade } }

            LoaderRing {
                anchors.horizontalCenter: parent.horizontalCenter
                spinning: root.waiting
            }
            Item { width: 1; height: Theme.launchTitleGap }
            Text {
                width: parent.width; height: Theme.launchTitleLine
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.title
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.launchTitleSize; font.weight: Font.DemiBold
                font.letterSpacing: -0.02 * Theme.launchTitleSize
            }
            Item { width: 1; height: Theme.launchStatusGap }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.status
                color: Theme.launchStatusInk
                font.family: Theme.fontUi; font.pixelSize: Theme.launchStatusSize; font.weight: Font.Medium
            }
        }
    }
}
