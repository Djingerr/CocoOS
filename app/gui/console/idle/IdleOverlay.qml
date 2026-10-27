pragma ComponentBehavior: Bound
import QtQuick

// Veille de l'écran au-dessus de l'accueil (remplace SleepScreen, même interface) : après
// l'inactivité, l'écran de veille (IdleScreen) entre en fondu. Une touche ou un clic le fait
// sortir ; cette première action n'atteint pas l'accueil, qui reprend la main tout de suite
// (`woke`) pendant que la veille s'efface (320 ms).
FocusScope {
    id: root

    property IdleStatus status
    property bool asleep: false
    // La veille couvre tout l'écran (fondu d'entrée fini) : l'accueil dessous peut être caché.
    readonly property bool covering: asleep && opacity === 1
    signal woke()

    function sleep() {
        if (asleep) return
        asleep = true
        loader.active = true
        forceActiveFocus()
        fadeIn.restart()
    }
    function wake() {
        if (!asleep) return
        fadeIn.stop()
        asleep = false
        if (loader.item as IdleScreen) (loader.item as IdleScreen).exit()
        woke()
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
        if (!event.isAutoRepeat) root.wake()
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.asleep
        onPressed: root.wake()
    }
}
