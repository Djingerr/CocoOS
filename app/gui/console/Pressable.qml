import QtQuick

// Élément qui répond à l'appui : tant que `down` est vrai (A enfoncé), il s'écrase en
// Theme.pressDuration ; relâché, il revient avec le ressort « rebond ». L'action part
// au relâché, chez l'appelant. Aucune dépendance Moonlight.
Item {
    id: root

    property bool down: false
    property real downScale: Theme.pressScale

    states: State {
        name: "down"; when: root.down
        PropertyChanges { target: root; scale: root.downScale }
    }
    transitions: [
        Transition {
            to: "down"
            NumberAnimation {
                property: "scale"; duration: Theme.pressDuration
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
            }
        },
        Transition {
            from: "down"
            NumberAnimation {
                property: "scale"; duration: Theme.springBouncy.duration
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springBouncy.curve
            }
        }
    ]
}
