import QtQuick

// Saisie du code d'appairage Companion à 6 chiffres, sur un écran de message.
// ⚠️ Sens INVERSE de l'appairage Moonlight (ConsoleHome, `pinScreen`) : ici le HOST
// affiche le code (notification du HostCompanion) et l'utilisateur le SAISIT sur la
// console (décision 2026-06-28).
// 100 % navigable manette : ←/→ change de case, ↑/↓ change le chiffre, A valide.
// Le clavier 0-9 / Retour arrière marche aussi (confort dev).
// Aucune dépendance Moonlight — piloté par ConsoleHome (`busy` : vérification en cours).
MessageScreen {
    id: root

    property string hostName: ""
    property string errorText: ""

    signal submitted(string code)

    // 6 chiffres, case active soulignée.
    property var digits: [0, 0, 0, 0, 0, 0]
    property int active: 0

    title: qsTr("Liaison avec %1").arg(hostName !== "" ? hostName : qsTr("votre PC"))
    text: qsTr("Saisissez le code à 6 chiffres affiché sur votre PC.")
    code: digits.join("")
    codeFocus: busy ? -1 : active
    status: errorText !== "" ? errorText : busy ? qsTr("Vérification…") : ""
    error: errorText !== ""
    hints: [ { glyph: "↕", label: qsTr("Chiffre") },
             { glyph: "↔", label: qsTr("Case") },
             { glyph: "A", label: qsTr("Valider") } ]

    function reset() {
        digits = [0, 0, 0, 0, 0, 0]
        active = 0
        errorText = ""
        busy = false
    }

    function setDigit(i, v) {
        var d = digits.slice()
        d[i] = ((v % 10) + 10) % 10
        digits = d
    }

    function moveTo(i) {
        if (i < 0 || i > 5) {
            Sounds.play("edge")
            return
        }
        active = i
        Sounds.play("move")
    }

    function submit() {
        if (busy) return
        busy = true
        Sounds.play("select")
        root.submitted(code)
    }

    Keys.onLeftPressed: moveTo(active - 1)
    Keys.onRightPressed: moveTo(active + 1)
    Keys.onUpPressed: { setDigit(active, digits[active] + 1); Sounds.play("tick") }
    Keys.onDownPressed: { setDigit(active, digits[active] - 1); Sounds.play("tick") }
    Keys.onReturnPressed: submit()
    Keys.onEnterPressed: submit()
    Keys.onPressed: function(event) {
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            setDigit(active, event.key - Qt.Key_0)
            if (active < 5) active = active + 1
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            active = Math.max(0, active - 1)
            event.accepted = true
        }
    }
}
