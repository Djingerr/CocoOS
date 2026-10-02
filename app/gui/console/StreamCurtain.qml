import QtQuick

// Rideau CocoOS entre un jeu et l'accueil. Posé noir, sans rien, dès que le flux
// démarre (cover) : pendant le flux, la fenêtre de l'accueil est cachée et Qt
// suspendu ; quand on quitte par le menu en jeu, elle réapparaît avant que la
// fenêtre du flux ne se ferme (StreamMenu::finishLeave) : ni trou, ni bureau. Dès
// qu'elle réapparaît, le logo apparaît (reveal) ; au retour sur l'accueil, une ligne
// d'état s'y ajoute si l'on attend quelque chose, puis le rideau se lève (dismiss)
// et l'accueil rentre. Tant qu'il couvre, il garde la manette. Aucune dépendance
// Moonlight.
FocusScope {
    id: root

    property bool covering: false        // l'accueil est caché ; il rentre à la levée du rideau
    property bool revealed: false        // logo (et ligne d'état) visibles
    property string status: ""
    property bool waiting: false         // une opération est en cours : le O respire
    property real revealedAt: 0
    readonly property real k: height / Theme.bootRefHeight

    signal lifted()                      // le rideau se lève : la manette revient à l'accueil

    visible: opacity > 0
    opacity: 0

    function cover() {
        fade.stop()
        lift.stop()
        revealed = false
        status = ""
        waiting = false
        covering = true
        opacity = 1
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

    // La fenêtre de l'accueil revient (fin du flux) : le logo paraît aussitôt, sur
    // le noir, sans attendre que l'accueil reprenne la main (returnedHome).
    Connections {
        target: root.Window.window
        function onVisibleChanged() {
            if (root.Window.window.visible) root.reveal(root.status, root.waiting)
        }
    }

    // Le logo reste au moins Theme.curtainMinShow, pour ne pas clignoter.
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
        waiting = false
        covering = false
        fade.restart()
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
    NumberAnimation {
        id: fade
        target: root; property: "opacity"; to: 0
        duration: Theme.curtainFade; easing.type: Theme.easeOut
    }

    Keys.onPressed: function(event) { event.accepted = true }
    Keys.onReleased: function(event) { event.accepted = true }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Logotype {
        id: logo
        fontSize: Theme.logoSize * root.k
        width: implicitWidth; height: implicitHeight
        // Centré comme le logo au repos de l'animation de démarrage.
        x: Math.round((root.width - geo.w) / 2)
        y: Math.round((root.height - height) / 2)
        opacity: root.revealed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.curtainReveal } }

        SequentialAnimation on oScale {
            running: root.waiting && root.revealed
            loops: Animation.Infinite
            NumberAnimation { to: Theme.curtainBreathScale; duration: Theme.curtainBreath / 2; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: Theme.curtainBreath / 2; easing.type: Easing.InOutSine }
            onStopped: logo.oScale = 1
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: logo.y + logo.height + Theme.bootStepTop * root.k - height / 2
        text: root.status
        color: Theme.bootStepInk
        font.family: Theme.fontUi; font.pixelSize: Theme.bootStepSize * root.k
        opacity: root.revealed && root.status !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.curtainReveal } }
    }
}
