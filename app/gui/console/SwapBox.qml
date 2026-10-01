import QtQuick

// Boîte dont le contenu se remplace en glissant : l'ancien sort, le nouveau entre,
// dans le sens donné par `direction`, verticalement ou horizontalement (`axis`).
// Elle contient exactement DEUX exemplaires du même élément, chacun doté d'une
// propriété `value` ; ils servent à tour de rôle.
Item {
    id: root

    default property alias slots: holder.data
    property string key              // identité du contenu : tout changement lance la transition
    property var value               // donné à l'exemplaire qui entre
    property int direction: 1        // +1 : le nouveau arrive par le bas (ou la droite) ; -1 : l'inverse
    property string axis: "y"        // "y" ou "x"
    property real distance: 0        // course en pixels ; 0 : Theme.swapTravel × la taille du contenu
    property int duration: 300
    property int delay: 0
    property bool animated: true     // false : remplacement immédiat, sans glissement

    property int front: 0
    readonly property Item currentItem: holder.children[front]
    property bool completed: false

    clip: true

    Item { id: holder; width: parent.width; height: parent.height }

    Component.onCompleted: {
        holder.children[0].value = value
        holder.children[1].opacity = 0
        completed = true
    }
    onKeyChanged: if (completed) wait.restart()

    // Toujours différé, même à 0 ms : plusieurs propriétés qui changent au même
    // instant ne donnent ainsi qu'une seule transition.
    Timer { id: wait; interval: root.delay; onTriggered: root.swap() }

    function swap() {
        if (!animated) {
            currentItem.value = value
            return
        }
        motion.stop()   // une transition en cours repart de là où elle en est
        var outgoing = holder.children[front]
        front = 1 - front
        var incoming = holder.children[front]
        incoming.value = value
        enterMove.target = enterFade.target = incoming
        exitMove.target = exitFade.target = outgoing
        var size = axis === "x" ? "width" : "height"
        enterMove.property = exitMove.property = axis
        enterMove.from = direction * (distance > 0 ? distance : incoming[size] * Theme.swapTravel)
        exitMove.to = -direction * (distance > 0 ? distance : outgoing[size] * Theme.swapTravel)
                      * Theme.swapExitTravel
        motion.start()
    }

    ParallelAnimation {
        id: motion
        NumberAnimation {
            id: enterMove; to: 0
            duration: root.duration; easing.type: Theme.easeQuint
        }
        NumberAnimation {
            id: enterFade; property: "opacity"; from: 0; to: 1
            duration: root.duration * Theme.swapEnterFade
        }
        NumberAnimation {
            id: exitMove
            duration: root.duration * Theme.swapExitDuration; easing.type: Theme.easeOut
        }
        NumberAnimation {
            id: exitFade; property: "opacity"; to: 0
            duration: root.duration * Theme.swapExitFade
        }
    }
}
