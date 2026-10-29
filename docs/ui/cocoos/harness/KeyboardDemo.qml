import QtQuick
import "../../../../app/gui/console"

// Le clavier à l'écran (OnScreenKeyboard) des maquettes :
//
//   ./shot.sh /tmp/a.png view=KeyboardDemo delay=1500            (ClavierWifi : « soirée24 », focus sur r)
//   ./filmstrip.sh /tmp/k.png 11000 view=KeyboardDemo motion=1     (MotionClavier)
//
// Arguments :
//   motion   1 : la séquence de MotionClavier (déplacements, frappes, accents, effacement, validation)
//   qwerty   1 : disposition anglaise
//   reveal   1 : mot de passe en clair (R3)
Item {
    id: demo
    property var args: ({})
    width: 1280; height: 800
    focus: true

    OnScreenKeyboard {
        id: kb
        anchors.fill: parent
        prompt: "Mot de passe de « Livebox-7A3C »"
        context: "Première configuration · 1 sur 3"
        minLength: 8
        qwerty: demo.args.qwerty === "1"
    }

    // Une touche par son caractère, sur la couche des lettres.
    function goTo(ch) {
        for (var r = 1; r < kb.keys.length; r++)
            for (var c = 0; c < kb.keys[r].length; c++)
                if (kb.keys[r][c].t === ch) { kb.row = r; kb.col = c; Sounds.play("tick"); return }
    }

    Component.onCompleted: {
        Sounds.enabled = demo.args.out === undefined && demo.args.sound !== "0"
        if (demo.args.motion === "1") {
            kb.minLength = 0                // (la planche valide « soiré » : la suite est la configuration)
            // MotionClavier (renderVals) : instants absolus, en ms.
            timeline.steps = [
                [600, "open"], [1150, "go:s"], [1450, "a"], [1850, "go:o"], [2150, "a"], [2550, "go:i"],
                [2800, "a"], [3150, "go:r"], [3400, "a"], [3800, "go:e"], [3990, "hold"], [4850, "right"],
                [5100, "release"], [5650, "a"], [6050, "a"], [6500, "x"], [7100, "ok"] ]
            kb.row = 2; kb.col = 4          // « g »
            Qt.callLater(function() { timeline.t0 = Date.now(); timeline.next() })
            return
        }
        kb.open("soirée24")
        kb.lastTyped = 7                    // le « 4 » vient d'être tapé
        kb.revealed = demo.args.reveal === "1"
        goTo("r")
    }

    QtObject {
        id: timeline
        property var steps: []
        property double t0: 0
        property int i: 0
        function next() {
            if (i >= steps.length) return
            tick.interval = Math.max(0, steps[i][0] - (Date.now() - t0))
            tick.restart()
        }
        function run(action) {
            if (action === "open") { kb.open(""); kb.row = 2; kb.col = 4 }
            else if (action.indexOf("go:") === 0) demo.goTo(action.slice(3))
            else if (action === "a") { kb.pressA(); release.restart() }
            else if (action === "hold") kb.pressA()
            else if (action === "release") kb.releaseA()
            else if (action === "right") kb.moveCol(1)
            else if (action === "x") kb.backspace()
            else if (action === "ok") kb.submit()
        }
    }
    Timer { id: release; interval: Theme.kbPressMove; onTriggered: kb.releaseA() }
    Timer {
        id: tick
        onTriggered: { timeline.run(timeline.steps[timeline.i][1]); timeline.i++; timeline.next() }
    }
}
