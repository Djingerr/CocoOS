pragma ComponentBehavior: Bound
import QtQuick
import "screens"

// Écran de veille (docs/design/idle/) : affiche l'état de `status` (jeu en cours, jeu +
// téléchargement, téléchargement, repos) sur la grille 1280 × 720 mise à l'échelle de
// l'écran (bandes noires si le format diffère). Quand l'état change : fondu enchaîné de
// 600 ms, puis l'entrée du nouvel écran. Toute touche ou un clic : sortie (320 ms), puis
// wakeRequested().
FocusScope {
    id: root

    property IdleStatus status
    property bool drift: true
    property bool animated: true
    signal wakeRequested()

    readonly property bool leaving: exitAnim.running || exited
    property bool exited: false
    property Item current: null

    function exit() {
        if (leaving) return
        exitAnim.start()
    }

    Rectangle { anchors.fill: parent; color: IdleTheme.background }

    Item {
        id: canvas
        anchors.centerIn: parent
        width: IdleTheme.reference.width
        height: IdleTheme.reference.height
        scale: Math.min(root.width / width, root.height / height)
        clip: true
    }
    Binding { target: IdleTheme; property: "scale"; value: canvas.scale }

    Component { id: gameScreen; IdleGameScreen {} }
    Component { id: downloadScreen; IdleDownloadScreen {} }
    Component { id: restScreen; IdleRestScreen {} }

    function show(state) {
        if (!status) return
        crossfade.complete()
        var first = current === null
        var props = { status: root.status, drift: root.drift, animated: root.animated, entryStarted: first }
        var next
        if (state === "game" || state === "gameDownload") {
            props.showDownload = state === "gameDownload"
            next = gameScreen.createObject(canvas, props)
        } else if (state === "download") {
            next = downloadScreen.createObject(canvas, props)
        } else {
            next = restScreen.createObject(canvas, props)
        }
        next.drift = Qt.binding(function() { return root.drift })
        next.animated = Qt.binding(function() { return root.animated })
        if (first) {
            current = next
            return
        }
        previous = current
        current = next
        next.opacity = 0
        crossfade.start()
    }
    property Item previous: null
    SequentialAnimation {
        id: crossfade
        ParallelAnimation {
            NumberAnimation {
                target: root.current; property: "opacity"; to: 1; duration: IdleTheme.stateCrossfade
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.appleOut
            }
            NumberAnimation {
                target: root.previous; property: "opacity"; to: 0; duration: IdleTheme.stateCrossfade
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.appleOut
            }
        }
        ScriptAction {
            script: {
                if (root.previous) root.previous.destroy()
                root.previous = null
                root.current.entryStarted = true
            }
        }
    }
    Connections {
        target: root.status
        enabled: root.current !== null
        function onStateChanged() { root.show(root.status.state) }
    }
    // Le premier écran est choisi une fois tout construit : le fournisseur de `status` peut
    // remplir ses données dans son propre Component.onCompleted.
    Component.onCompleted: Qt.callLater(function() { root.show(root.status ? root.status.state : "rest") })

    // Sortie : opacité → 0, échelle → 1,02.
    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation {
                target: canvas; property: "opacity"; to: 0; duration: IdleTheme.exitDuration
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.appleOut
            }
            NumberAnimation {
                target: canvas; property: "scale"; to: canvas.scale * IdleTheme.exitScale
                duration: IdleTheme.exitDuration
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.appleOut
            }
        }
        ScriptAction { script: { root.exited = true; root.wakeRequested() } }
    }

    Keys.onPressed: function(event) {
        event.accepted = true
        if (!event.isAutoRepeat) root.exit()
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.exit()
    }
}
