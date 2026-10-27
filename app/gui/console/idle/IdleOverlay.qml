pragma ComponentBehavior: Bound
import QtQuick

// Veille de l'écran au-dessus de l'accueil (remplace SleepScreen, même interface) : après
// l'inactivité, l'écran de veille (IdleScreen) entre en fondu. Une touche ou un clic le fait
// sortir ; cette première action n'atteint pas l'accueil, qui reprend la main tout de suite
// (`woke`) pendant que la veille s'efface (320 ms). A, quand un jeu tourne sur le PC (« Appuyez
// sur A pour reprendre ») : `woke(true)`, à l'appelant de relancer le flux.
FocusScope {
    id: root

    property IdleStatus status
    property bool asleep: false
    // La veille couvre tout l'écran (fondu d'entrée fini) : l'accueil dessous peut être caché.
    readonly property bool covering: asleep && opacity === 1
    signal woke(bool resuming)

    function sleep() {
        if (asleep) return
        asleep = true
        loader.active = true
        forceActiveFocus()
        fadeIn.restart()
    }
    function wake(resuming) {
        if (!asleep) return
        fadeIn.stop()
        asleep = false
        if (loader.item as IdleScreen) (loader.item as IdleScreen).exit()
        woke(resuming === true)
    }

    visible: loader.active
    opacity: 0
    NumberAnimation {
        id: fadeIn
        target: root; property: "opacity"; from: 0; to: 1
        duration: IdleTheme.stateCrossfade
        easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.appleOut
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: false
        sourceComponent: IdleScreen {
            status: root.status
            onWakeRequested: {
                loader.active = false
                root.opacity = 0
            }
        }
    }

    Keys.onPressed: function(event) {
        event.accepted = true
        if (event.isAutoRepeat) return
        // A : Entrée, ou Espace quand la navigation upstream est en mode interface.
        var a = event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space
        root.wake(a && root.status !== null && root.status.session.active === true)
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.asleep
        onPressed: root.wake()
    }
}
