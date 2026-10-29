import QtQuick

// Clavier à l'écran CocoOS (ClavierWifi, MotionClavier) : saisie d'un mot de passe Wi-Fi à la
// manette, sans bureau. Plein écran : la question, le champ (masqué, le dernier caractère
// visible un instant ; R3 affiche tout), puis le clavier en verre, AZERTY ou QWERTY (globe),
// sur trois couches (lettres, 123, #+=). Croix : touche voisine (une tache blanche glisse de
// l'une à l'autre) ; A tape au relâché, maintenu il ouvre les accents de la touche ; X efface ;
// Y espace ; LT majuscule ; LB / RB déplacent le curseur ; ≡ valide ; B annule. Un vrai
// clavier marche aussi. Remplit son parent et se dessine sur le canevas mis à l'échelle.
// Aucune dépendance Moonlight : l'appelant route LB / RB, LT et R3 (moveCursor, shift,
// toggleReveal) et dit si Key_Hangup vient de Start (`startDown`).
FocusScope {
    id: root

    property string prompt: ""          // « Mot de passe de « Livebox-7A3C » »
    property string context: ""         // au-dessus, en capitales (première configuration)
    property string text: ""
    property bool masked: true
    property int minLength: 0           // Valider ne passe qu'à partir de cette longueur
    property bool qwerty: false         // disposition anglaise (le globe la change)
    // Vrai si la touche Key_Hangup qui arrive vient de Start (≡ : valider) et non de Y (espace).
    property var startDown: null

    signal accepted(string text)
    signal cancelled()

    property bool opened: false
    property int cursor: 0              // place du curseur dans `text`
    property bool revealed: false       // R3 : tout le mot de passe en clair
    property bool caps: false           // une majuscule (LT, ⇧), comme sur un téléphone
    property string keyLayer: "abc"     // abc, 123, sym
    property int row: 1                 // 0 : les raccourcis ; 1 à 4 : les touches
    property int col: 0
    property bool pressing: false       // A enfoncé
    property bool holding: false        // …assez longtemps : la touche s'enfonce moins (accents)
    property int accent: -1             // accent choisi dans la bulle (-1 : bulle fermée)
    property int lastTyped: -1          // place du dernier caractère tapé, visible un instant

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
        text = initialText || ""
        cursor = text.length
        keyLayer = "abc"
        caps = false
        revealed = false
        row = 1; col = 0
        pressing = holding = false
        accent = -1
        lastTyped = -1
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        opened = false
        pad.stop()
        Sounds.play("close")
    }
    function cancel() {
        close()
        cancelled()
    }

    // --- Touches : `t` est tapé ; les autres sont des commandes. `w` : largeur (px). ---
    readonly property var letters: qwerty
        ? ["qwertyuiop", "asdfghjkl-", "zxcvbnm"]
        : ["azertyuiop", "qsdfghjklm", "wxcvbn’"]
    readonly property var keyLayers: ({
        abc: letters,
        "123": ["1234567890", "-/:;()€&@\"", ".,?!'_%"],
        sym: ["[]{}#%^*+=", "_\\|~<>$£¥•", ".,?!'`°"]
    })
    readonly property var keys: {
        var K = Theme.kbKey.width, F = Theme.kbFnKey
        var chars = function(line) {
            return line.split("").map(function(c) {
                return { t: caps && keyLayer === "abc" ? c.toUpperCase() : c, w: K }
            })
        }
        var lines = keyLayers[keyLayer]
        var symbols = keyLayer !== "abc"
        return [
            Theme.kbChips.map(function(c) { return { t: c, chip: true } })
                .concat([{ cmd: "globe", label: qwerty ? qsTr("Anglais · QWERTY") : qsTr("Français · AZERTY") }]),
            chars(lines[0]),
            chars(lines[1]),
            [{ cmd: "shift", icon: "shift", glyph: "LT", w: F, on: caps }].concat(chars(lines[2]),
                [{ cmd: "back", icon: "delete", glyph: "X", w: F }]),
            [{ cmd: "layer", label: symbols ? "abc" : "123", w: F },
             { cmd: "symbols", label: keyLayer === "sym" ? "123" : "#+=", w: K },
             { cmd: "space", label: qsTr("espace"), glyph: "Y", w: Theme.kbSpaceKey },
             { t: "@", w: K }, { t: ".", w: K },
             { cmd: "ok", label: qsTr("Valider"), glyph: "≡", w: Theme.kbOkKey }]
        ]
    }
    // Accents proposés à l'appui maintenu (la lettre d'abord).
    readonly property var accents: ({
        a: "aàâäæá", c: "cç", e: "eéèêë€", i: "iîïí", n: "nñ", o: "oôöœó", u: "uùûüú", y: "yÿ"
    })
    function accentsOf(key) {
        if (!key || key.t === undefined || key.chip) return ""
        var list = accents[key.t.toLowerCase()] || ""
        return key.t !== key.t.toLowerCase() ? list.toUpperCase() : list
    }
    readonly property var focusedKey: keys[row] ? keys[row][col] : null
    readonly property string bubble: accentsOf(focusedKey)

    // --- Saisie ---
    function insert(s) {
        text = text.slice(0, cursor) + s + text.slice(cursor)
        cursor += s.length
        lastTyped = s.length === 1 ? cursor - 1 : -1
        typedFade.restart()
        if (caps && keyLayer === "abc") caps = false
        Sounds.play("nav_move_fast")
    }
    Timer { id: typedFade; interval: Theme.kbClearHold; onTriggered: root.lastTyped = -1 }
    function backspace() {
        if (cursor === 0) {
            Sounds.play("edge")
            return
        }
        text = text.slice(0, cursor - 1) + text.slice(cursor)
        cursor--
        lastTyped = -1
        Sounds.play("back")
    }
    function space() { insert(" ") }
    function shift() {
        if (keyLayer !== "abc") keyLayer = "abc"
        caps = !caps
        Sounds.play("move")
    }
    function moveCursor(dir) {
        var next = cursor + dir
        if (next < 0 || next > text.length) {
            Sounds.play("edge")
            return
        }
        cursor = next
        Sounds.play("move")
    }
    function toggleReveal() {
        revealed = !revealed
        Sounds.play("move")
    }
    function submit() {
        if (text.length < minLength) {
            field.refuse()
            Sounds.play("deny")
            return
        }
        close()
        Sounds.play("select")
        accepted(text)
    }
    function press(key) {
        if (key.t !== undefined) insert(key.t)
        else if (key.cmd === "shift") shift()
        else if (key.cmd === "layer") { keyLayer = keyLayer === "abc" ? "123" : "abc"; Sounds.play("move") }
        else if (key.cmd === "symbols") { keyLayer = keyLayer === "sym" ? "123" : "sym"; Sounds.play("move") }
        else if (key.cmd === "space") space()
        else if (key.cmd === "back") backspace()
        else if (key.cmd === "ok") submit()
        else if (key.cmd === "globe") { qwerty = !qwerty; Sounds.play("move") }
        col = Math.min(col, keys[row].length - 1)
    }

    // --- Croix : touche voisine ; haut / bas, la plus proche dans la rangée voisine ---
    function keyX(r, c) {
        var x = 0
        for (var i = 0; i < c; i++) x += keyWidth(keys[r][i]) + Theme.kbGap
        return x
    }
    function keyWidth(k) { return k.w !== undefined ? k.w : chipMetrics.width(k) }
    function moveRow(dir) {
        var next = row + dir
        if (next < 0 || next >= keys.length) {
            Sounds.play("edge")
            return
        }
        var x = keyX(row, col) + keyWidth(keys[row][col]) / 2, best = 0
        for (var i = 1; i < keys[next].length; i++) {
            var center = keyX(next, i) + keyWidth(keys[next][i]) / 2
            if (Math.abs(center - x) < Math.abs(keyX(next, best) + keyWidth(keys[next][best]) / 2 - x)) best = i
        }
        row = next
        col = best
        Sounds.play("tick")
    }
    function moveCol(dir) {
        if (accent >= 0) {                      // bulle ouverte : l'accent voisin
            var next = accent + dir
            if (next < 0 || next >= bubble.length) Sounds.play("edge")
            else { accent = next; Sounds.play("tick") }
            return
        }
        next = col + dir
        if (next < 0 || next >= keys[row].length) {
            Sounds.play("edge")
            return
        }
        col = next
        Sounds.play("tick")
    }
    // A : enfoncé, la touche s'écrase ; tenu sur une lettre à accents, la bulle s'ouvre ;
    // relâché, la touche (ou l'accent choisi) est tapée.
    Timer {
        id: holdTimer
        interval: Theme.kbAccentHold
        onTriggered: {
            root.holding = true
            if (root.bubble.length > 1) {
                root.accent = 0
                Sounds.play("segment")
            }
        }
    }
    function pressA() {
        pressing = true
        holdTimer.restart()
    }
    function releaseA() {
        if (!pressing) return
        pressing = holding = false
        holdTimer.stop()
        if (accent >= 0) {
            var chosen = bubble.charAt(accent)
            accent = -1
            insert(chosen)
        } else if (focusedKey) {
            press(focusedKey)
        }
    }

    PadRepeat {
        id: pad
        keys: [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right]
        onTriggered: function(key) {
            if (key === Qt.Key_Up && root.accent < 0) root.moveRow(-1)
            else if (key === Qt.Key_Down && root.accent < 0) root.moveRow(1)
            else if (key === Qt.Key_Left || key === Qt.Key_Right) root.moveCol(key === Qt.Key_Left ? -1 : 1)
        }
    }
    Keys.onPressed: function(event) {
        event.accepted = true                     // plein écran : rien ne traverse
        if (!opened || pad.press(event)) return
        if (event.isAutoRepeat && event.key !== Qt.Key_Backspace) return
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // A sur la manette (touche sans texte, cf. SdlGamepadKeyNavigation) : la touche en
            // focus, au relâché. Entrée d'un vrai clavier : valide.
            if (event.text === "") pressA()
            else submit()
            break
        case Qt.Key_Escape:                       // B
            if (accent >= 0) {                    // la bulle seule
                accent = -1
                pressing = holding = false
                Sounds.play("close")
            } else {
                cancel()
            }
            break
        case Qt.Key_Menu:                         // X
        case Qt.Key_Backspace:
            backspace()
            break
        case Qt.Key_Hangup:                       // Y (espace) ou Start (valider)
            if (startDown && startDown()) submit()
            else space()
            break
        case Qt.Key_PageUp:                       // LB / RB au clavier
        case Qt.Key_PageDown:
            moveCursor(event.key === Qt.Key_PageUp ? -1 : 1)
            break
        case Qt.Key_Home:
            cursor = 0
            break
        case Qt.Key_End:
            cursor = text.length
            break
        default:
            // Un vrai clavier : le caractère tapé.
            if (event.text.length === 1 && event.text >= " ") insert(event.text)
        }
    }
    Keys.onReleased: function(event) {
        pad.release(event)
        if (!event.isAutoRepeat && event.text === "" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
            releaseA()
    }
    onActiveFocusChanged: if (!activeFocus) { pad.stop(); holdTimer.stop(); pressing = holding = false; accent = -1 }

    FontMetrics {
        id: chipFont
        font.family: Theme.fontUi; font.pixelSize: Theme.kbChipSize; font.weight: Font.Medium
    }
    QtObject {
        id: chipMetrics
        function width(k) {
            return k.cmd === "globe" ? 0 : Math.ceil(chipFont.advanceWidth(k.t)) + 2 * Theme.kbChipPad
        }
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
                    model: root.text.length + 1          // la dernière place : le curseur au bout
                    Item {
                        readonly property bool caretBefore: index === root.cursor
                        readonly property string ch: index < root.text.length ? root.text.charAt(index) : ""
                        readonly property bool clear: root.revealed || !root.masked || index === root.lastTyped
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
                   qsTr("%1 saisis").arg(root.text.length)].filter(Boolean).join(" · ")
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.optHostSize; font.weight: Font.Medium
        }

        // Le clavier, en verre ; il monte du bas.
        Rectangle {
            id: panel
            x: (canvas.width - width) / 2
            y: Theme.kbTop + Theme.kbTravel * (1 - root.reveal)
            width: Theme.kbSize.width; height: Theme.kbSize.height
            radius: Theme.kbRadius
            color: Theme.kbFill
            border.width: 1; border.color: Theme.kbStroke
            opacity: root.opened ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.opened ? 0 : Theme.kbFadeOutDelay }
                    NumberAnimation { duration: root.opened ? Theme.kbFadeIn : Theme.kbFadeOut }
                }
            }

            // Raccourcis (.com, @gmail.com…) et la disposition (globe), puis les touches.
            Repeater {
                id: rows
                model: root.keys.length
                Item {
                    id: keyRow
                    required property int index
                    readonly property var line: root.keys[index]
                    x: Theme.kbPad
                    y: index === 0 ? Theme.kbChipsTop : Theme.kbRowsTop + (index - 1) * Theme.kbRowStep
                    z: index === root.row ? 3 : 1     // (la rangée en focus : son libellé sur la tache)
                    width: panel.width - 2 * Theme.kbPad
                    height: index === 0 ? Theme.kbChipHeight : Theme.kbKey.height
                    Repeater {
                        model: keyRow.line.length
                        Item {
                            id: key
                            required property int index
                            readonly property var k: keyRow.line[index] || ({})
                            readonly property bool focused: root.row === keyRow.index && root.col === index
                            readonly property bool chip: keyRow.index === 0
                            readonly property bool ok: k.cmd === "ok"
                            readonly property bool fn: k.cmd !== undefined && !ok
                            x: k.cmd === "globe" ? keyRow.width - width : root.keyX(keyRow.index, index)
                            width: k.cmd === "globe" ? globe.width + 2 * Theme.kbChipPad : root.keyWidth(k)
                            height: keyRow.height
                            z: focused ? 3 : 1
                            scale: ok && root.pressing && focused ? Theme.kbPressScale : 1
                            Behavior on scale { NumberAnimation { duration: Theme.kbPressMove } }
                            Rectangle {
                                anchors.fill: parent
                                radius: key.chip ? height / 2 : Theme.radiusKey
                                visible: key.k.cmd !== "globe"
                                color: key.ok ? Theme.accent : key.k.on ? Theme.kbShiftOn
                                     : key.chip ? Theme.glassPill : key.fn ? Theme.keyFn : Theme.keyChar
                            }
                            Row {
                                id: globe
                                anchors.centerIn: parent
                                visible: key.k.cmd === "globe"
                                spacing: Theme.legendGlyphGapCoco
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: key.k.label || ""
                                    color: key.focused ? Theme.inkOnLight : Theme.ink3
                                    font.family: Theme.fontUi; font.pixelSize: Theme.listSectionSize; font.weight: Font.DemiBold
                                }
                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "icons/globe.svg"
                                    width: 15; height: 15
                                    sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
                                    opacity: key.focused ? 0 : 0.5
                                }
                            }
                            Row {
                                anchors.centerIn: parent
                                visible: key.k.cmd !== "globe"
                                spacing: Theme.legendGlyphGapCoco
                                readonly property color ink: key.focused || key.ok ? Theme.inkOnLight : Theme.ink
                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: key.k.icon !== undefined
                                    source: key.k.icon ? "icons/" + key.k.icon + (key.focused ? "-dark" : "") + ".svg" : ""
                                    width: 24; height: 20
                                    sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: text !== ""
                                    text: key.k.t !== undefined ? key.k.t : (key.k.label || "")
                                    color: parent.ink
                                    Behavior on color { ColorAnimation { duration: Theme.kbInkFade } }
                                    font.family: Theme.fontUi
                                    font.pixelSize: key.chip ? Theme.kbChipSize : key.k.t !== undefined ? Theme.kbCharSize : Theme.kbFnSize
                                    font.weight: key.chip ? Font.Medium : key.k.t !== undefined ? Font.Medium : Font.DemiBold
                                }
                                ButtonGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: key.k.glyph !== undefined
                                    label: key.k.glyph || ""
                                    ink: key.focused || key.ok ? Theme.kbGlyphDark : Theme.kbGlyphLight
                                    size: Theme.kbGlyph
                                }
                            }
                            HoverArea {
                                anchors.fill: parent
                                onPointed: if (!key.focused) {
                                    root.row = keyRow.index
                                    root.col = key.index
                                    Sounds.play("tick")
                                }
                                onClicked: {
                                    root.row = keyRow.index
                                    root.col = key.index
                                    root.press(key.k)
                                }
                            }
                        }
                    }
                }
            }

            // La touche en focus : une tache blanche qui glisse de touche en touche, s'écrase à
            // l'appui, s'efface quand la bulle des accents s'ouvre.
            Rectangle {
                id: spot
                readonly property Item target: {
                    var r = rows.count > root.row ? rows.itemAt(root.row) : null
                    if (!r) return null
                    for (var i = 0; i < r.children.length; i++)
                        if (r.children[i].focused === true) return r.children[i]
                    return null
                }
                visible: target !== null && root.focusedKey && root.focusedKey.cmd !== "ok"
                z: 2
                x: target ? target.parent.x + target.x : 0
                y: target ? target.parent.y : 0
                width: target ? target.width : 0
                height: target ? target.height : 0
                radius: root.row === 0 ? height / 2 : Theme.radiusKey
                color: Theme.ink
                opacity: root.accent >= 0 ? Theme.kbSpotDim : 1
                scale: root.pressing ? (root.holding ? Theme.kbHoldScale : Theme.kbPressScale) : Theme.kbFocusScale
                Behavior on x { NumberAnimation { duration: Theme.kbSpotMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.kbSpotMove.curve } }
                Behavior on y { NumberAnimation { duration: Theme.kbSpotMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.kbSpotMove.curve } }
                Behavior on width { NumberAnimation { duration: Theme.kbSpotMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.kbSpotMove.curve } }
                Behavior on opacity { NumberAnimation { duration: Theme.kbSpotFade } }
                Behavior on scale {
                    NumberAnimation {
                        duration: root.pressing ? Theme.kbPressMove : Theme.kbSpotGrow.duration
                        easing.type: root.pressing ? Easing.OutQuad : Easing.BezierSpline
                        easing.bezierCurve: Theme.kbSpotGrow.curve
                    }
                }
            }

            // Bulle des accents, au-dessus de la touche.
            Rectangle {
                id: bubbleBox
                readonly property Item target: spot.target
                readonly property int count: Math.max(1, root.bubble.length)
                z: 5
                width: count * Theme.kbAccentKey.width + (count - 1) * Theme.kbAccentGap + 2 * Theme.kbAccentPad
                height: Theme.kbAccentKey.height + 2 * Theme.kbAccentPad
                x: target ? Math.max(Theme.kbAccentInset, Math.min(panel.width - width - Theme.kbAccentInset,
                                                             spot.x + spot.width / 2 - width / 2)) : 0
                y: spot.y - height - Theme.kbAccentAbove
                radius: Theme.kbAccentRadius
                color: Theme.kbAccentFill
                border.width: 1; border.color: Theme.hairlineStrong
                transformOrigin: Item.Bottom
                property bool shown: root.accent >= 0
                opacity: shown ? 1 : 0
                visible: opacity > 0
                scale: shown ? 1 : Theme.kbAccentFrom
                transform: Translate { y: bubbleBox.shown ? 0 : Theme.kbAccentTravel }
                Behavior on opacity { NumberAnimation { duration: Theme.kbAccentFade } }
                Behavior on scale {
                    NumberAnimation {
                        duration: bubbleBox.shown ? Theme.kbAccentIn.duration : Theme.kbAccentOut.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: bubbleBox.shown ? Theme.kbAccentIn.curve : Theme.kbAccentOut.curve
                    }
                }
                Row {
                    x: Theme.kbAccentPad; y: Theme.kbAccentPad
                    spacing: Theme.kbAccentGap
                    Repeater {
                        model: root.bubble.length
                        Rectangle {
                            readonly property bool chosen: index === root.accent
                            width: Theme.kbAccentKey.width; height: Theme.kbAccentKey.height
                            radius: Theme.radiusKey
                            color: chosen ? Theme.ink : Theme.glassPill
                            scale: chosen ? Theme.kbAccentChosen : 1
                            Behavior on color { ColorAnimation { duration: Theme.kbInkFade } }
                            Behavior on scale { NumberAnimation { duration: Theme.kbSpotMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.kbSpotMove.curve } }
                            Text {
                                anchors.centerIn: parent
                                text: root.bubble.charAt(index)
                                color: parent.chosen ? Theme.inkOnLight : Theme.ink
                                font.family: Theme.fontUi; font.pixelSize: Theme.kbCharSize; font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            ControllerLegend {
                anchors.horizontalCenter: parent.horizontalCenter
                y: panel.height - Theme.kbLegendBottom - height
                spacing: Theme.kbLegendGap
                textSize: Theme.legendSizeCoco
                glyphGap: Theme.legendGlyphGapCoco
                pressing: root.pressing
                hints: [ { glyph: "X", label: qsTr("Effacer") }, { glyph: "Y", label: qsTr("Espace") },
                         { glyph: "LT", label: qsTr("Majuscule") }, { glyph: "LB RB", label: qsTr("Curseur") },
                         { glyph: "A", label: qsTr("Maintenir pour les accents") },
                         { glyph: "≡", label: qsTr("Valider") }, { glyph: "B", label: qsTr("Annuler") } ]
                // Les mêmes gestes qu'à la manette (cf. Keys.onPressed).
                onTriggered: function(glyph) {
                    if (glyph === "A") root.press(root.focusedKey)
                    else if (glyph === "X") root.backspace()
                    else if (glyph === "Y") root.space()
                    else root.cancel()
                }
            }
        }
    }
}
