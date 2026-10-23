import QtQuick
import QtQuick.Effects

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
    // Style du prototype des micro-interactions (swapText), si `enterCurve` est donnée :
    // l'entrant glisse et apparaît ensemble sur `duration` (enterCurve), le sortant part de
    // toute la course et s'efface ensemble sur `exitDuration` (exitCurve).
    property var enterCurve: null
    property var exitCurve: null
    property int exitDuration: 0
    // Flou (px) de l'exemplaire qui entre ou sort, plein quand il est invisible, nul une fois
    // posé (le flou du swapText). À fixer à la création ; 0 : pas de flou. Le calque n'existe
    // que pendant la transition : posé, le texte est rendu net, en direct. Rendu GPU seulement (le rendu logiciel, celui des tests, n'a pas de calques).
    property real blur: 0
    readonly property bool blurred: blur > 0 && GraphicsInfo.api !== GraphicsInfo.Unknown
                                    && GraphicsInfo.api !== GraphicsInfo.Software

    property int front: 0
    // Les deux exemplaires, relevés à la création (les calques de flou s'ajoutent ensuite
    // parmi les enfants de `holder`).
    property var items: [null, null]
    readonly property Item currentItem: items[front]
    property bool completed: false

    clip: true

    Item { id: holder; width: parent.width; height: parent.height }

    Component.onCompleted: {
        items = [holder.children[0], holder.children[1]]
        items[0].value = value
        items[1].opacity = 0
        if (blur > 0) {
            blurLayer(items[0])
            blurLayer(items[1])
        }
        completed = true
    }
    // Un calque à la taille de l'exemplaire à l'écran (le canevas est mis à l'échelle).
    function blurLayer(slot) {
        slot.layer.textureSize = Qt.binding(function() {
            return Qt.size(Math.ceil(slot.width * Theme.scale), Math.ceil(slot.height * Theme.scale))
        })
        slot.layer.smooth = true
        slot.layer.effect = blurEffect
        slot.layer.enabled = Qt.binding(function() { return root.blurred && slot.opacity < 1 })
    }
    // Le flou suit l'opacité de l'exemplaire (même courbe, même durée, comme dans le
    // prototype) : seul le mélange final change pendant le glissement, rien n'est recalculé.
    Component {
        id: blurEffect
        MultiEffect {
            blurEnabled: true
            blurMax: Math.ceil(root.blur * Theme.scale * Theme.swapBlurSpread)
            blur: 1 - opacity
        }
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
        var outgoing = items[front]
        front = 1 - front
        var incoming = items[front]
        incoming.value = value
        enterMove.target = enterFade.target = incoming
        exitMove.target = exitFade.target = outgoing
        var size = axis === "x" ? "width" : "height"
        var swift = enterCurve !== null
        enterMove.property = exitMove.property = axis
        enterMove.from = direction * (distance > 0 ? distance : incoming[size] * Theme.swapTravel)
        exitMove.to = -direction * (distance > 0 ? distance : outgoing[size] * Theme.swapTravel)
                      * (swift ? 1 : Theme.swapExitTravel)
        enterMove.duration = duration
        enterFade.duration = swift ? duration : duration * Theme.swapEnterFade
        exitMove.duration = swift ? exitDuration : duration * Theme.swapExitDuration
        exitFade.duration = swift ? exitDuration : duration * Theme.swapExitFade
        ease(enterMove, swift ? enterCurve : null, Theme.easeQuint)
        ease(enterFade, swift ? enterCurve : null, Easing.Linear)
        ease(exitMove, swift ? exitCurve : null, Theme.easeOut)
        ease(exitFade, swift ? exitCurve : null, Easing.Linear)
        motion.start()
    }
    function ease(animation, curve, type) {
        animation.easing.type = curve ? Easing.BezierSpline : type
        if (curve) animation.easing.bezierCurve = curve
    }

    ParallelAnimation {
        id: motion
        NumberAnimation { id: enterMove; to: 0 }
        NumberAnimation { id: enterFade; property: "opacity"; from: 0; to: 1 }
        NumberAnimation { id: exitMove }
        NumberAnimation { id: exitFade; property: "opacity"; to: 0 }
    }
}
