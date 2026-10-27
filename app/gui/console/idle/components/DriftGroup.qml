pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Groupe de contenu qui dérive lentement contre le marquage de l'OLED (SPEC §2) : (0,0) →
// (6,−4) → (−5,5) → (4,6) à 0 / 33 / 66 / 100 % de 90 s, aller-retour, chaque segment en
// ease-in-out (comme une animation CSS par images clés).
Item {
    id: root

    property bool running: true
    property real driftX: 0
    property real driftY: 0

    width: parent ? parent.width : IdleTheme.reference.width
    height: parent ? parent.height : IdleTheme.reference.height
    transform: Translate { x: root.driftX; y: root.driftY }

    component Leg: ParallelAnimation {
        id: leg
        property real toX
        property real toY
        property real share
        NumberAnimation {
            target: root; property: "driftX"; to: leg.toX
            duration: leg.share * IdleTheme.driftPeriod
            easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
        }
        NumberAnimation {
            target: root; property: "driftY"; to: leg.toY
            duration: leg.share * IdleTheme.driftPeriod
            easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
        }
    }
    SequentialAnimation {
        running: root.running
        loops: Animation.Infinite
        Leg { toX: 6; toY: -4; share: 0.33 }
        Leg { toX: -5; toY: 5; share: 0.33 }
        Leg { toX: 4; toY: 6; share: 0.34 }
        Leg { toX: -5; toY: 5; share: 0.34 }
        Leg { toX: 6; toY: -4; share: 0.33 }
        Leg { toX: 0; toY: 0; share: 0.33 }
    }
}
