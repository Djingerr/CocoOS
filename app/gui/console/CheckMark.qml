import QtQuick

// Coche du prototype (polyligne 4.5,12.5 → 9.3,17.3 → 19.5,7 sur 24 × 24) : tracée trait
// après trait quand `checked` passe à vrai (drawDuration, après drawDelay), effacée sinon
// (Theme.checkErase). Aucune dépendance Moonlight.
Item {
    id: check
    property bool checked: false
    property color color: Theme.accent
    property int drawDelay: Theme.checkDelay
    property int drawDuration: Theme.checkDraw
    property real drawn: 0
    readonly property real unit: width / 24
    readonly property var points: [Qt.point(4.5, 12.5), Qt.point(9.3, 17.3), Qt.point(19.5, 7)]
    readonly property var legs: [Math.hypot(points[1].x - points[0].x, points[1].y - points[0].y),
                                 Math.hypot(points[2].x - points[1].x, points[2].y - points[1].y)]

    states: State {
        name: "checked"; when: check.checked
        PropertyChanges { target: check; drawn: 1 }
    }
    transitions: [
        Transition {
            to: "checked"
            SequentialAnimation {
                PauseAnimation { duration: check.drawDelay }
                NumberAnimation {
                    property: "drawn"; duration: check.drawDuration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
        },
        Transition {
            from: "checked"
            NumberAnimation {
                property: "drawn"; duration: Theme.checkErase
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
            }
        }
    ]
    Repeater {
        model: 2
        Rectangle {
            readonly property point from: check.points[index]
            readonly property point to: check.points[index + 1]
            readonly property real done: (check.drawn * (check.legs[0] + check.legs[1])
                                          - (index === 0 ? 0 : check.legs[0])) / check.legs[index]
            readonly property real stroke: Theme.checkStroke * check.unit
            visible: done > 0
            x: from.x * check.unit - stroke / 2; y: from.y * check.unit - stroke / 2
            width: Math.min(done, 1) * check.legs[index] * check.unit + stroke; height: stroke
            radius: stroke / 2
            color: check.color
            antialiasing: true
            transform: Rotation {
                origin.x: stroke / 2; origin.y: stroke / 2
                angle: Math.atan2(to.y - from.y, to.x - from.x) * 180 / Math.PI
            }
        }
    }
}
