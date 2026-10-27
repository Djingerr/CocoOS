import QtQuick
import ".."

// Barre de progression fine de l'écran 11 (SPEC §2.3) : 420 × 2, remplissage accent qui
// suit la valeur en 1 s, reflet blanc qui le parcourt toutes les 2,4 s.
Rectangle {
    id: root

    property real progress: 0
    property bool animated: true
    property real sheenX: -1          // en largeurs de reflet

    width: 420; height: 2
    radius: 1
    color: IdleTheme.track
    clip: true

    Rectangle {
        id: fill
        height: parent.height
        width: root.width * Math.max(0, Math.min(1, root.progress))
        radius: 1
        color: IdleTheme.accent
        clip: true
        Behavior on width { NumberAnimation { duration: IdleTheme.progressUpdate; easing.type: Easing.Linear } }

        Rectangle {
            width: 0.30 * fill.width
            height: fill.height
            x: root.sheenX * width
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.7) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }
    NumberAnimation on sheenX {
        running: root.animated
        loops: Animation.Infinite
        from: -1; to: 3.5; duration: IdleTheme.barSheenPeriod
        easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
    }
}
