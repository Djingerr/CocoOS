import QtQuick

// Clavier à l'écran, à la manette : saisie d'un mot de passe Wi-Fi, sans bureau.
// Un panneau en bas de l'écran (le reste s'assombrit) : la question, le texte saisi
// (masqué sauf le dernier caractère), puis les touches en AZERTY, sur quatre couches
// (abc, ABC, 123, #+=). Flèches : touche voisine ; A tape ; B efface (ou ferme si
// rien n'est saisi) ; X : majuscules / autres symboles ; Y (Start) valide. Un vrai
// clavier marche aussi. Remplit son parent et se dessine, comme ConsoleDialog, sur
// le canevas mis à l'échelle. Aucune dépendance Moonlight.
FocusScope {
    id: root

    property string prompt: ""          // « Mot de passe de Freebox-172425 »
    property string text: ""
    property bool masked: true
    property int minLength: 0           // OK ne valide qu'à partir de cette longueur

    signal accepted(string text)
    signal cancelled()

    property bool opened: false
    property string keyLayer: "abc"     // abc, ABC, 123, sym
    property int row: 0
    property int col: 0
    property real reveal: opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.sheetSlide; easing.type: Theme.easeQuint } }

    visible: reveal > 0

    function open(initialText) {
        text = initialText || ""
        keyLayer = "abc"
        row = 0; col = 0
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        opened = false
        Sounds.play("close")
    }

    // Touches : `t` est tapé ; les autres sont des commandes. `w` : largeur en unités.
    readonly property var keyLayers: ({
        abc: ["azertyuiop", "qsdfghjklm", "wxcvbn,.'-"],
        ABC: ["AZERTYUIOP", "QSDFGHJKLM", "WXCVBN;:?!"],
        "123": ["1234567890", "@#$%&*+=_/", "!?:;\"()[]\\"],
        sym: ["{}<>|~^`€£", "°§µ²«»¿¡¨¤", "àâçéèêëîôù"]
    })
    readonly property var keys: {
        var rows = keyLayers[keyLayer].map(function(line) {
            return line.split("").map(function(c) { return { t: c, w: 1 } })
        })
        var symbols = keyLayer === "123" || keyLayer === "sym"
        rows.push([
            { cmd: "shift", label: symbols ? (keyLayer === "sym" ? "123" : "#+=") : (keyLayer === "ABC" ? "abc" : "ABC"), w: 1.5 },
            { cmd: "layer", label: symbols ? "abc" : "123", w: 1.5 },
            { cmd: "space", label: qsTr("Espace"), w: 3 },
            { cmd: "back", label: "⌫", w: 1.5 },
            { cmd: "ok", label: qsTr("OK"), w: 2.5 }
        ])
        return rows
    }

    function press(key) {
        if (key.t !== undefined) {
            text += key.t
            Sounds.play("tick")
            if (keyLayer === "ABC") keyLayer = "abc"      // une majuscule, comme sur un téléphone
        } else if (key.cmd === "shift") {
            keyLayer = keyLayer === "abc" ? "ABC" : keyLayer === "ABC" ? "abc" : keyLayer === "123" ? "sym" : "123"
            Sounds.play("move")
        } else if (key.cmd === "layer") {
            keyLayer = keyLayer === "123" || keyLayer === "sym" ? "abc" : "123"
            Sounds.play("move")
        } else if (key.cmd === "space") {
            text += " "
            Sounds.play("tick")
        } else if (key.cmd === "back") {
            backspace()
        } else if (key.cmd === "ok") {
            submit()
        }
        col = Math.min(col, keys[row].length - 1)
    }
    function backspace() {
        if (text.length === 0) {
            Sounds.play("edge")
            return
        }
        text = text.slice(0, -1)
        Sounds.play("tick")
    }
    function submit() {
        if (text.length < minLength) {
            Sounds.play("edge")
            return
        }
        opened = false
        Sounds.play("select")
        accepted(text)
    }

    // Haut / bas : la touche de la rangée voisine la plus proche horizontalement.
    function center(r, c) {
        var x = 0
        for (var i = 0; i < c; i++) x += keys[r][i].w
        return x + keys[r][c].w / 2
    }
    function moveRow(dir) {
        var next = row + dir
        if (next < 0 || next >= keys.length) {
            Sounds.play("edge")
            return
        }
        var x = center(row, col), best = 0
        for (var i = 1; i < keys[next].length; i++)
            if (Math.abs(center(next, i) - x) < Math.abs(center(next, best) - x)) best = i
        row = next
        col = best
        Sounds.play("move")
    }
    function moveCol(dir) {
        var next = col + dir
        if (next < 0 || next >= keys[row].length) {
            Sounds.play("edge")
            return
        }
        col = next
        Sounds.play("move")
    }

    PadRepeat {
        id: pad
        keys: [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right]
        onTriggered: function(key) {
            if (key === Qt.Key_Up) root.moveRow(-1)
            else if (key === Qt.Key_Down) root.moveRow(1)
            else root.moveCol(key === Qt.Key_Left ? -1 : 1)
        }
    }
    Keys.onPressed: function(event) {
        event.accepted = true                     // modal : rien ne traverse
        if (!opened || pad.press(event)) return
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // A sur la manette (touche sans texte, cf. SdlGamepadKeyNavigation) : la
            // touche en focus. Entrée d'un vrai clavier : valide.
            if (event.text === "") press(keys[row][col])
            else submit()
            break
        case Qt.Key_Escape:                       // B
            if (text.length > 0) backspace()
            else { close(); cancelled() }
            break
        case Qt.Key_Backspace:
            backspace()
            break
        case Qt.Key_Menu:                         // X
            press({ cmd: "shift" })
            break
        case Qt.Key_Hangup:                       // Y / Start
            submit()
            break
        default:
            // Un vrai clavier : le caractère tapé.
            if (event.text.length === 1 && event.text >= " ") {
                text += event.text
                Sounds.play("tick")
            }
        }
    }
    Keys.onReleased: function(event) { pad.release(event) }
    onActiveFocusChanged: if (!activeFocus) pad.stop()

    Item {
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            opacity: Theme.sheetDim * root.reveal
            MouseArea { anchors.fill: parent; enabled: root.opened }
        }

        Rectangle {
            id: panel
            width: parent.width
            height: Theme.keyboardHeight
            y: parent.height - height * root.reveal
            color: Theme.sheetFill
            Rectangle { width: parent.width; height: 1; color: Theme.sheetEdge }

            Column {
                id: header
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.keyboardPadTop
                width: keyGrid.width
                spacing: Theme.keyboardFieldGap

                Text {
                    text: root.prompt
                    color: Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: Theme.keyboardPromptSize
                }
                Rectangle {
                    width: parent.width; height: Theme.keyboardFieldHeight
                    radius: Theme.sheetFocusRadius
                    color: Theme.sheetFocusFill
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.keyboardFieldPad
                        width: parent.width - 2 * Theme.keyboardFieldPad
                        elide: Text.ElideLeft
                        // Masqué, sauf le dernier caractère tapé.
                        text: (root.masked && root.text.length > 0
                               ? "•".repeat(root.text.length - 1) + root.text.charAt(root.text.length - 1)
                               : root.text) + "│"
                        color: Theme.ink
                        font.family: Theme.fontUi; font.pixelSize: Theme.keyboardFieldSize
                    }
                }
            }

            Column {
                id: keyGrid
                anchors.horizontalCenter: parent.horizontalCenter
                y: header.y + header.height + Theme.keyboardKeysTop
                width: 10 * Theme.keyboardKeySize.width + 9 * Theme.keyboardKeyGap
                spacing: Theme.keyboardKeyGap

                Repeater {
                    model: root.keys
                    Row {
                        id: keyRow
                        required property var modelData
                        required property int index
                        spacing: Theme.keyboardKeyGap
                        Repeater {
                            model: keyRow.modelData
                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool focused: root.row === keyRow.index && root.col === index
                                readonly property bool ok: modelData.cmd === "ok"
                                width: modelData.w * Theme.keyboardKeySize.width
                                       + (modelData.w - 1) * Theme.keyboardKeyGap
                                height: Theme.keyboardKeySize.height
                                radius: Theme.keyboardKeyRadius
                                color: focused ? (ok ? Theme.accent : Theme.ink)
                                     : ok ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                                     : Theme.keyboardKeyFill
                                Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.t !== undefined ? parent.modelData.t : parent.modelData.label
                                    color: parent.focused ? Theme.inkOnAccent : Theme.ink
                                    font.family: Theme.fontUi; font.pixelSize: Theme.keyboardKeyTextSize
                                    font.weight: Font.Medium
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.row = keyRow.index
                                        root.col = parent.index
                                        root.press(parent.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ControllerLegend {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.sheetPadBottom
                hints: [ { glyph: "A", label: qsTr("Taper") }, { glyph: "B", label: qsTr("Effacer") },
                         { glyph: "X", label: qsTr("Majuscules") }, { glyph: "Y", label: qsTr("Valider") } ]
            }
        }
    }
}
