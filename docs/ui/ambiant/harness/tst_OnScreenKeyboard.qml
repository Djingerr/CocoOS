import QtQuick
import QtTest
import "../../../../app/gui/console"

// Clavier à l'écran : déplacement dans la grille, couches (majuscule unique,
// chiffres), effacement, longueur minimale avant de valider.
Item {
    width: Theme.canvasWidth; height: Theme.canvasHeight

    OnScreenKeyboard { id: keyboard; anchors.fill: parent; minLength: 3 }
    SignalSpy { id: accepted; target: keyboard; signalName: "accepted" }

    TestCase {
        name: "OnScreenKeyboard"
        when: windowShown

        function pressFocused() { keyboard.press(keyboard.keys[keyboard.row][keyboard.col]) }

        function test_typeShiftDigitsAndSubmit() {
            Sounds.enabled = false
            keyboard.open("")
            pressFocused()                                  // a
            keyboard.moveCol(1); pressFocused()             // z
            compare(keyboard.text, "az")
            keyboard.press({ cmd: "shift" })                // une majuscule…
            keyboard.moveRow(1); pressFocused()             // S (rangée 2, sous le « z »)
            compare(keyboard.text, "azS")
            compare(keyboard.keyLayer, "abc")                  // …puis retour aux minuscules
            keyboard.moveRow(1); keyboard.moveRow(1)        // rangée du bas : la touche la plus proche
            compare(keyboard.keys[keyboard.row][keyboard.col].cmd, "shift")
            keyboard.press({ cmd: "layer" })
            compare(keyboard.keys[0][0].t, "1")
            keyboard.backspace()
            compare(keyboard.text, "az")
            keyboard.submit()                               // 2 caractères : trop court
            verify(keyboard.opened)
            keyClick(Qt.Key_9)                              // un vrai clavier tape aussi
            keyClick(Qt.Key_Return)                         // Entrée d'un vrai clavier : valide
            compare(accepted.count, 1)
            compare(accepted.signalArguments[0][0], "az9")
            verify(!keyboard.opened)
        }
    }
}
