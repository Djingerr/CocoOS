import QtQuick

// Anneau de focus d'un bouton qui a la manette (prototype : .ring::after) : un trait posé
// à `inset` autour de son parent, qui paraît en se resserrant. Aucune dépendance Moonlight.
Rectangle {
    property bool shown: false
    property real inset: Theme.focusRingInset
    anchors.fill: parent
    anchors.margins: -(inset + Theme.focusRingWidth)
    radius: height / 2
    color: "transparent"
    border.width: Theme.focusRingWidth; border.color: Theme.ink
    opacity: shown ? 1 : 0
    scale: shown ? 1 : Theme.focusRingFrom
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.focusRingFade
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.springSnappy.duration
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
        }
    }
}
