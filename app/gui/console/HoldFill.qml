import QtQuick

// Remplissage d'un appui maintenu (action destructive) : tant que `holding`, il se
// remplit de gauche à droite en Theme.holdDuration ; lâché avant la fin, il se vide en
// Theme.holdDrain. Affiché : progression^Theme.holdCurve (il démarre lentement, contre
// les accidents). Le libellé y est repris en inkOnAccent, découpé par le remplissage.
// Plein : un petit rebond, puis completed(). À poser par-dessus la ligne, à la taille de
// son surlignage. Aucune dépendance Moonlight.
Item {
    id: root

    property bool holding: false
    property string label
    property real labelX: 0                  // place du libellé de la ligne, dessous
    property real radius: 0
    property real progress: 0
    property bool done: false
    property real bump: 1                    // 0 → 1 pendant le rebond final
    signal completed()

    function reset() {
        run.stop()
        finish.stop()
        progress = 0
        bump = 1
        done = false
    }

    onHoldingChanged: {
        if (done) return
        run.stop()
        run.to = holding ? 1 : 0
        run.duration = (holding ? 1 - progress : progress) * (holding ? Theme.holdDuration : Theme.holdDrain)
        run.start()
    }
    NumberAnimation {
        id: run
        target: root; property: "progress"
        onFinished: if (root.holding && root.progress >= 1) { root.done = true; finish.start() }
    }
    SequentialAnimation {
        id: finish
        NumberAnimation {
            target: root; property: "bump"; from: 0; to: 1
            duration: Theme.springBouncy.duration
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
        }
        ScriptAction { script: root.completed() }
    }

    scale: 1 + (Theme.holdBounce - 1) * (1 - Math.abs(2 * bump - 1))

    Item {
        width: root.width * Math.pow(root.progress, Theme.holdCurve)
        height: root.height
        visible: width > 0
        clip: true
        Rectangle { width: root.width; height: root.height; radius: root.radius; color: Theme.accent }
        Text {
            x: root.labelX
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.inkOnAccent
            font.family: Theme.fontUi; font.pixelSize: Theme.sheetLabelSize
        }
    }
}
