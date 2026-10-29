import QtQuick

// Clavier à l'écran CocoOS (ClavierWifi, MotionClavier) : saisie d'un mot de passe Wi-Fi à la
// manette, sans bureau. Plein écran : la question, le champ (masqué, le dernier caractère
// visible un instant ; R3 affiche tout), puis le clavier de verre (KeyboardPanel), qui monte du
// bas. Remplit son parent et se dessine sur le canevas mis à l'échelle. Aucune dépendance
// Moonlight : l'appelant route LB / RB, LT et R3 (moveCursor, shift, toggleReveal) et dit si
// Key_Hangup vient de Start (`startDown`).
FocusScope {
    id: root

    property string prompt: ""          // « Mot de passe de « Livebox-7A3C » »
    property string context: ""         // au-dessus, en capitales (première configuration)
    property bool masked: true
    property int minLength: 0           // Valider ne passe qu'à partir de cette longueur
    property alias qwerty: panel.qwerty // disposition anglaise (le globe la change)
    property alias startDown: panel.startDown

    signal accepted(string text)
    signal cancelled()

    property bool opened: false
    property bool revealed: false       // R3 : tout le mot de passe en clair
    // Le clavier : sa saisie et ses gestes (aussi pour les harnais).
    readonly property alias panel: panel
    readonly property alias text: panel.text
    readonly property alias cursor: panel.cursor
    property alias lastTyped: panel.lastTyped
    property alias row: panel.row
    property alias col: panel.col
    readonly property alias keys: panel.keys
    readonly property alias accent: panel.accent
    readonly property alias bubble: panel.bubble
    readonly property alias caps: panel.caps
    readonly property alias pressing: panel.pressing
    function pressA() { panel.pressA() }
    function releaseA() { panel.releaseA() }
    function moveCol(dir) { panel.moveCol(dir) }
    function moveRow(dir) { panel.moveRow(dir) }
    function moveCursor(dir) { panel.moveCursor(dir) }
    function shift() { panel.shift() }
    function backspace() { panel.backspace() }
    function press(key) { panel.press(key) }

    property real reveal: opened ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.opened ? Theme.kbIn.duration : Theme.kbOut.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.opened ? Theme.kbIn.curve : Theme.kbOut.curve
        }
    }
    visible: reveal > 0 || panel.opacity > 0

    function open(initialText) {
        panel.reset(initialText)
        revealed = false
        opened = true
        panel.forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        opened = false
        Sounds.play("close")
    }
    function cancel() {
        close()
        cancelled()
    }
    function toggleReveal() {
        revealed = !revealed
        Sounds.play("tick")
    }
    function submit() {
        if (panel.text.length < minLength) {
            field.refuse()
            Sounds.play("deny")
            return
        }
        close()
        Sounds.play("select")
        accepted(panel.text)
    }

    // --- Dessin, sur le canevas ---
    Item {
        id: canvas
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft
        opacity: Math.min(1, root.reveal * 2)

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            MouseArea { anchors.fill: parent; enabled: root.opened }
        }
        // Lueurs : l'orange en bas, un bleu en haut à droite.
        Glow {
            x: (canvas.width - width) / 2 + Theme.kbGlowLow.x; y: Theme.kbGlowLow.y
            width: Theme.kbGlowLow.width; height: Theme.kbGlowLow.height
            color: Theme.kbGlowAccent
        }
        Glow {
            x: canvas.width / 2 + Theme.kbGlowHigh.x; y: Theme.kbGlowHigh.y
            width: Theme.kbGlowHigh.width; height: Theme.kbGlowHigh.height
            color: Theme.kbGlowBlue
        }

        Text {
            visible: root.context !== ""
            width: parent.width
            y: Theme.kbContextTop
            horizontalAlignment: Text.AlignHCenter
            text: root.context
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.listSectionSize; font.weight: Font.DemiBold
            font.letterSpacing: 0.08 * Theme.listSectionSize; font.capitalization: Font.AllUppercase
        }
        Text {
            width: parent.width
            y: Theme.kbTitleTop
            horizontalAlignment: Text.AlignHCenter
            text: root.prompt
            color: Theme.ink
            elide: Text.ElideMiddle
            font.family: Theme.fontUi; font.pixelSize: Theme.kbTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: -0.03 * Theme.kbTitleSize
        }

        // Le champ : cadenas, caractères (masqués), curseur, « R3 Afficher ».
        Pressable {
            id: field
            x: (canvas.width - width) / 2; y: Theme.kbFieldTop
            width: Theme.kbField.width; height: Theme.kbField.height
            Rectangle {                       // halo orange autour
                anchors.fill: parent
                anchors.margins: -Theme.kbFieldRing
                radius: height / 2
                color: "transparent"
                border.width: Theme.kbFieldRing; border.color: Theme.kbFieldRingFill
            }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.kbFieldFill
                border.width: Theme.kbFieldStroke; border.color: Theme.accent
                border.pixelAligned: false
            }
            Image {
                x: Theme.kbFieldPadLeft; anchors.verticalCenter: parent.verticalCenter
                source: "icons/lock.svg"
                width: 13; height: 16
                sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
                opacity: 0.55
            }
            Row {
                id: chars
                x: Theme.kbFieldPadLeft + 13 + Theme.kbFieldGap
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.kbCaretHeight
                spacing: 0
                Repeater {
                    model: panel.text.length + 1          // la dernière place : le curseur au bout
                    Item {
                        readonly property bool caretBefore: index === panel.cursor
                        readonly property string ch: index < panel.text.length ? panel.text.charAt(index) : ""
                        readonly property bool clear: root.revealed || !root.masked || index === panel.lastTyped
                        width: (ch === "" ? 0 : root.revealed || !root.masked ? letter.implicitWidth + Theme.kbCharSpacing
                                                                             : Theme.kbCharWidth) + (caretBefore ? Theme.kbCaretGap : 0)
                        height: parent.height
                        Rectangle {                     // le curseur, avant ce caractère
                            visible: parent.caretBefore
                            width: 2; height: Theme.kbCaretHeight; radius: 1
                            color: Theme.accent
                            SequentialAnimation on opacity {
                                running: root.opened; loops: Animation.Infinite
                                PropertyAction { value: 1 }
                                PauseAnimation { duration: Theme.kbCaretBlink }
                                PropertyAction { value: 0 }
                                PauseAnimation { duration: Theme.kbCaretBlink }
                            }
                        }
                        Item {
                            x: parent.caretBefore ? Theme.kbCaretGap : 0
                            width: parent.width - x; height: parent.height
                            visible: parent.ch !== ""
                            Text {
                                id: letter
                                anchors.centerIn: parent
                                text: parent.parent.ch
                                color: Theme.ink
                                opacity: parent.parent.clear ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.kbClearFade } }
                                font.family: Theme.fontUi; font.pixelSize: Theme.kbFieldSize; font.weight: Font.DemiBold
                            }
                            Rectangle {                 // le point du masque
                                anchors.centerIn: parent
                                width: Theme.kbDot; height: width; radius: 1
                                color: Theme.ink
                                opacity: parent.parent.clear ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: Theme.kbClearFade } }
                            }
                        }
                    }
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: Theme.kbFieldPadRight
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.legendGlyphGapCoco
                visible: root.masked
                ButtonGlyph { anchors.verticalCenter: parent.verticalCenter; label: "R3"; ink: Theme.ink2 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.revealed ? qsTr("Masquer") : qsTr("Afficher")
                    color: Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: Theme.listSubSize; font.weight: Font.DemiBold
                }
                HoverArea { width: 1; height: 1 }
            }
            HoverArea {
                x: parent.width - Theme.kbRevealTouch; width: Theme.kbRevealTouch; height: parent.height
                visible: root.masked
                onClicked: root.toggleReveal()
            }
        }
        Text {
            width: parent.width
            y: Theme.kbHintTop
            horizontalAlignment: Text.AlignHCenter
            text: [root.minLength > 0 ? qsTr("%1 caractères minimum").arg(root.minLength) : "",
                   qsTr("%1 saisis").arg(panel.text.length)].filter(Boolean).join(" · ")
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.optHostSize; font.weight: Font.Medium
        }

        // Le clavier, en verre ; il monte du bas.
        KeyboardPanel {
            id: panel
            x: (canvas.width - width) / 2
            y: Theme.kbTop + Theme.kbTravel * (1 - root.reveal)
            focus: true
            live: root.opened
            chips: Theme.kbChips
            globe: true
            hints: [ { glyph: "X", label: qsTr("Effacer") }, { glyph: "Y", label: qsTr("Espace") },
                     { glyph: "LT", label: qsTr("Majuscule") }, { glyph: "LB RB", label: qsTr("Curseur") },
                     { glyph: "A", label: qsTr("Maintenir pour les accents") },
                     { glyph: "≡", label: qsTr("Valider") }, { glyph: "B", label: qsTr("Annuler") } ]
            opacity: root.opened ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.opened ? 0 : Theme.kbFadeOutDelay }
                    NumberAnimation { duration: root.opened ? Theme.kbFadeIn : Theme.kbFadeOut }
                }
            }
            onSubmitted: root.submit()
            onCancelled: root.cancel()
            onChipChosen: function(chip) { panel.insert(chip) }
            onUpRequested: Sounds.play("edge")
        }
    }
}
