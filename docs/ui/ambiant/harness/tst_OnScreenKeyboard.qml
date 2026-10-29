import QtQuick
import QtTest
import "../../../../app/gui/console"

// Clavier à l'écran CocoOS (ClavierWifi, MotionClavier) : déplacement dans la grille, A au
// relâché, accents à l'appui maintenu, X efface, Y espace et Start valide (même touche Qt),
// curseur (LB / RB), majuscule unique (LT), couches, longueur minimale, B annule.
Item {
    width: Theme.canvasWidth; height: Theme.canvasHeight

    property bool start: false
    OnScreenKeyboard {
        id: keyboard
        anchors.fill: parent
        minLength: 3
        startDown: function() { return start }
    }
    SignalSpy { id: accepted; target: keyboard; signalName: "accepted" }
    SignalSpy { id: cancelled; target: keyboard; signalName: "cancelled" }

    TestCase {
        name: "OnScreenKeyboard"
        when: windowShown

        function init() {
            Sounds.enabled = false
            accepted.clear(); cancelled.clear()
            keyboard.open("")
        }
        // A de la manette (Key_Return sans texte ; keyClick en pose un : l'Entrée d'un clavier).
        function typeFocused() { keyboard.pressA(); keyboard.releaseA() }

        function test_typeMoveEraseAndSubmit() {
            compare([keyboard.row, keyboard.col], [1, 0])       // « a »
            keyboard.pressA()
            compare(keyboard.text, "")                          // rien tant que A est enfoncé
            keyboard.releaseA()
            compare(keyboard.text, "a")
            keyClick(Qt.Key_Right); typeFocused()               // z
            compare(keyboard.text, "az")
            keyboard.shift()                                    // LT : une majuscule…
            keyClick(Qt.Key_Down); typeFocused()                // S (rangée 2, sous le « z »)
            compare(keyboard.text, "azS")
            verify(!keyboard.caps)                              // …puis retour aux minuscules
            keyClick(Qt.Key_Menu)                               // X : efface
            compare(keyboard.text, "az")
            keyClick(Qt.Key_Hangup)                             // Y : espace
            compare(keyboard.text, "az ")
            keyboard.moveCursor(-1); keyboard.moveCursor(-1)    // LB : curseur entre a et z
            compare(keyboard.cursor, 1)
            keyClick(Qt.Key_9)                                  // un vrai clavier tape aussi, au curseur
            compare(keyboard.text, "a9z ")
            start = true                                        // Start (≡) : valide
            keyClick(Qt.Key_Hangup)
            start = false
            compare(accepted.count, 1)
            compare(accepted.signalArguments[0][0], "a9z ")
            verify(!keyboard.opened)
        }

        // A maintenu sur une lettre à accents : la bulle s'ouvre, → choisit, relâcher tape.
        function test_accentsOnHold() {
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)      // « e »
            keyboard.pressA()
            tryCompare(keyboard, "accent", 0, Theme.kbAccentHold + 300)
            compare(keyboard.bubble, "eéèêë€")
            keyClick(Qt.Key_Right)                              // é
            keyboard.releaseA()
            compare(keyboard.text, "é")
            compare(keyboard.accent, -1)
        }

        function test_layersRefusalAndCancel() {
            keyboard.press({ cmd: "layer" })                    // 123
            compare(keyboard.keys[1][0].t, "1")
            keyboard.press({ cmd: "symbols" })                  // #+=
            compare(keyboard.keys[1][0].t, "[")
            keyboard.press({ cmd: "layer" })                    // abc
            compare(keyboard.keys[1][0].t, "a")
            keyboard.press({ cmd: "globe" })                    // QWERTY
            compare(keyboard.keys[1][1].t, "w")
            keyboard.press({ cmd: "globe" })
            typeFocused()
            keyboard.submit()                                   // 1 caractère : trop court
            verify(keyboard.opened)
            compare(accepted.count, 0)
            keyClick(Qt.Key_Escape)                             // B : annule
            verify(!keyboard.opened)
            compare(cancelled.count, 1)
        }
    }
}
