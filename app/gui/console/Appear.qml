import QtQuick

// Enveloppe qui fait apparaître ou disparaître son contenu : un fondu, plus un
// glissement depuis (ou vers) un décalage et, au besoin, une échelle. Sert à
// l'entrée de l'écran d'accueil (après l'animation de démarrage) et à son
// effacement au lancement d'un jeu.
Item {
    id: root

    property bool shown: false
    property real hiddenX: 0                        // décalage du contenu tant qu'il est masqué
    property real hiddenY: Theme.enterShift
    property real hiddenScale: 1                    // échelle tant qu'il est masqué
    property int delay: 0                           // attente avant d'apparaître
    property int hideDuration: Theme.enterFade      // durée de la disparition
    // Apparition : durée et courbe du fondu, puis du mouvement (glissement, échelle).
    // Courbe Easing.BezierSpline : les points de `bezier`.
    property int fadeDuration: Theme.enterFade
    property int fadeEasing: Easing.Linear
    property int moveDuration: Theme.enterMove
    property int moveEasing: Theme.easeQuint
    property var bezier: Theme.curveEmph
    // Un élément créé alors qu'il doit déjà être visible joue-t-il son apparition ?
    // Non pour ce qui est créé après coup (vignettes qui arrivent en défilant).
    property bool animateInitially: true

    property bool live: false
    Component.onCompleted: live = true

    opacity: 0
    scale: hiddenScale
    transform: Translate { id: shift; x: root.hiddenX; y: root.hiddenY }

    states: State {
        name: "shown"
        when: root.shown
        PropertyChanges { root.opacity: 1; root.scale: 1; shift.x: 0; shift.y: 0 }
    }
    transitions: [
        Transition {
            to: "shown"
            enabled: root.live || root.animateInitially
            SequentialAnimation {
                PauseAnimation { duration: root.delay }
                ParallelAnimation {
                    NumberAnimation {
                        target: root; property: "opacity"; duration: root.fadeDuration
                        easing.type: root.fadeEasing; easing.bezierCurve: root.bezier
                    }
                    NumberAnimation {
                        target: root; property: "scale"; duration: root.moveDuration
                        easing.type: root.moveEasing; easing.bezierCurve: root.bezier
                    }
                    NumberAnimation {
                        target: shift; properties: "x,y"; duration: root.moveDuration
                        easing.type: root.moveEasing; easing.bezierCurve: root.bezier
                    }
                }
            }
        },
        Transition {
            from: "shown"
            NumberAnimation { target: root; properties: "opacity,scale"; duration: root.hideDuration }
            NumberAnimation {
                target: shift; properties: "x,y"
                duration: root.hideDuration; easing.type: Theme.easeQuint
            }
        }
    ]
}
