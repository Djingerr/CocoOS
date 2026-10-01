import QtQuick

// Enveloppe qui fait apparaître ou disparaître son contenu : un fondu, plus un
// glissement depuis (ou vers) un décalage. Sert à l'entrée en cascade de l'écran
// d'accueil et à son effacement au lancement d'un jeu.
Item {
    id: root

    property bool shown: false
    property real hiddenX: 0                        // décalage du contenu tant qu'il est masqué
    property real hiddenY: Theme.enterShift
    property int delay: 0                           // attente avant d'apparaître
    property int hideDuration: Theme.enterFade      // durée de la disparition
    // Un élément créé alors qu'il doit déjà être visible joue-t-il son apparition ?
    // Non pour ce qui est créé après coup (vignettes qui arrivent en défilant).
    property bool animateInitially: true

    property bool live: false
    Component.onCompleted: live = true

    opacity: 0
    transform: Translate { id: shift; x: root.hiddenX; y: root.hiddenY }

    states: State {
        name: "shown"
        when: root.shown
        PropertyChanges { root.opacity: 1; shift.x: 0; shift.y: 0 }
    }
    transitions: [
        Transition {
            to: "shown"
            enabled: root.live || root.animateInitially
            SequentialAnimation {
                PauseAnimation { duration: root.delay }
                ParallelAnimation {
                    NumberAnimation { target: root; property: "opacity"; duration: Theme.enterFade }
                    NumberAnimation {
                        target: shift; properties: "x,y"
                        duration: Theme.enterMove; easing.type: Theme.easeQuint
                    }
                }
            }
        },
        Transition {
            from: "shown"
            NumberAnimation { target: root; property: "opacity"; duration: root.hideDuration }
            NumberAnimation {
                target: shift; properties: "x,y"
                duration: root.hideDuration; easing.type: Theme.easeQuint
            }
        }
    ]
}
