import QtQuick

// Élément qui répond à l'appui : tant que `down` est vrai (A enfoncé), il s'écrase en
// Theme.pressDuration ; relâché, il revient avec le ressort « rebond ». L'action part
// au relâché, chez l'appelant. refuse() le secoue (action indisponible, code faux).
// Aucune dépendance Moonlight.
Item {
    id: root

    property bool down: false
    property real downScale: Theme.pressScale
    property real liftY: 0                   // décalage vertical (apparition d'une ligne)

    function refuse() { shake.restart() }
    property real shakeProgress: 1
    NumberAnimation {
        id: shake
        target: root; property: "shakeProgress"; from: 0; to: 1
        duration: Theme.shakeDuration
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.shakeCurve
    }
    transform: Translate {
        y: root.liftY
        x: {
            var keys = Theme.shakeKeys, at = root.shakeProgress * (keys.length - 1)
            var i = Math.min(Math.floor(at), keys.length - 2)
            return keys[i] + (keys[i + 1] - keys[i]) * (at - i)
        }
    }

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
