import QtQuick

// Remplissage d'un appui maintenu (action destructive) : tant que `holding`, il se
// remplit de gauche à droite en Theme.holdDuration ; lâché avant la fin, il se vide en
// Theme.holdDrain. Affiché : progression^Theme.holdCurve (il démarre lentement, contre
// les accidents). Le libellé y est repris en inkOnAccent, découpé par le remplissage.
// Plein : le libellé laisse la place à une coche et à `doneLabel`, un petit rebond, puis
// completed(). À poser par-dessus la ligne, à la taille de son surlignage. Aucune
// dépendance Moonlight.
Item {
    id: root

    property bool holding: false
    property string label
    property string doneLabel                // une fois plein ; vide : le libellé reste
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
            readonly property bool gone: root.done && root.doneLabel !== ""
            x: root.labelX
            y: (root.height - height) / 2 - (gone ? height * Theme.holdSwapShift : 0)
            opacity: gone ? 0 : 1
            text: root.label
            color: Theme.inkOnAccent
            font.family: Theme.fontUi; font.pixelSize: Theme.sheetLabelSize
            Behavior on y { NumberAnimation { duration: Theme.holdSwapMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut } }
            Behavior on opacity { NumberAnimation { duration: Theme.holdSwapFade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut } }
        }
        Row {
            x: root.labelX
            y: (root.height - height) / 2 + (root.done ? 0 : height * Theme.holdSwapShift)
            opacity: root.done ? 1 : 0
            visible: root.doneLabel !== ""
            spacing: Theme.holdCheckGap
            Behavior on y { NumberAnimation { duration: Theme.holdSwapMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut } }
            Behavior on opacity { NumberAnimation { duration: Theme.holdSwapFade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut } }
            CheckMark {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.holdCheckSize; height: width
                color: Theme.inkOnAccent
                checked: root.done
                drawDelay: Theme.holdCheckDelay; drawDuration: Theme.holdCheckDraw
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.doneLabel
                color: Theme.inkOnAccent
                font.family: Theme.fontUi; font.pixelSize: Theme.sheetLabelSize
            }
        }
    }
}
