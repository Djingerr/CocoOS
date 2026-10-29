import QtQuick

// Le clavier de verre CocoOS (ClavierWifi, Recherche), sans son écran : une rangée de
// raccourcis puis les touches, AZERTY ou QWERTY, sur trois couches (lettres, 123, #+=). Il garde
// le texte saisi (`text`, `cursor`). Croix : touche voisine (une tache blanche glisse de l'une à
// l'autre) ; A tape au relâché, maintenu il ouvre les accents de la touche ; X efface ; Y espace ;
// ≡ valide (submitted) ; B annule (cancelled) ; LT majuscule et LB / RB curseur, routés par
// l'écran (shift, moveCursor). Un vrai clavier marche aussi. Aucune dépendance Moonlight.
//
// Deux gabarits : `compact` (Recherche : plus bas, sans @ ni point, espace plus large).
FocusScope {
    id: root

    property bool compact: false
    readonly property var m: compact ? Theme.kbCompact : Theme.kbFull
    property string text: ""
    property int cursor: 0              // place du curseur dans `text`
    property bool qwerty: false         // disposition anglaise (le globe la change)
    // Rangée du haut : des raccourcis (`chips`), puis à droite la disposition et le globe
    // (`globe`), ou une indication (`chipsHint`, glyphe `chipsGlyph`).
    property var chips: []
    property bool globe: false
    property string chipsHint: ""
    property string chipsGlyph: ""
    property string okLabel: qsTr("Valider")
    property var hints: []               // légende sous les touches
    // Vrai si la touche Key_Hangup qui arrive vient de Start (≡ : valider) et non de Y (espace).
    property var startDown: null
    property bool live: true             // animations (faux : touches posées d'emblée)

    signal submitted()
    signal cancelled()
    signal chipChosen(string chip)       // un raccourci : à l'écran de l'insérer ou de le prendre
    signal upRequested()                 // haut depuis la rangée du haut
    signal glyphTriggered(string glyph)  // la légende cliquée, pour ce que l'écran y ajoute

    property bool caps: false           // une majuscule (LT, ⇧), comme sur un téléphone
    property string keyLayer: "abc"     // abc, 123, sym
    property int row: 1                 // 0 : les raccourcis ; 1 à 4 : les touches
    property int col: 0
    property bool pressing: false       // A enfoncé
    property bool holding: false        // …assez longtemps : la touche s'enfonce moins (accents)
    property int accent: -1             // accent choisi dans la bulle (-1 : bulle fermée)
    property int lastTyped: -1          // place du dernier caractère tapé, visible un instant

    function reset(initialText) {
        text = initialText || ""
        cursor = text.length
        keyLayer = "abc"
        caps = false
        row = 1; col = 0
        pressing = holding = false
        accent = -1
        lastTyped = -1
        pad.stop()
        holdTimer.stop()
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
        var K = Theme.kbKeyWidth, F = Theme.kbFnKey
        var chars = function(line) {
            return line.split("").map(function(c) {
                return { t: caps && keyLayer === "abc" ? c.toUpperCase() : c, w: K }
            })
        }
        var lines = keyLayers[keyLayer]
        var symbols = keyLayer !== "abc"
        var top = chips.map(function(c) { return { t: c, chip: true } })
        if (globe) top.push({ cmd: "globe", label: qwerty ? qsTr("Anglais · QWERTY") : qsTr("Français · AZERTY") })
        return [
            top,
            chars(lines[0]),
            chars(lines[1]),
            [{ cmd: "shift", icon: "shift", glyph: compact ? undefined : "LT", w: F, on: caps }].concat(chars(lines[2]),
                [{ cmd: "back", icon: "delete", glyph: compact ? undefined : "X", w: F }]),
            [{ cmd: "layer", label: symbols ? "abc" : "123", w: F },
             { cmd: "symbols", label: keyLayer === "sym" ? "123" : "#+=", w: K },
             { cmd: "space", label: qsTr("espace"), glyph: compact ? undefined : "Y", w: m.space }]
            .concat(compact ? [] : [{ t: "@", w: K }, { t: ".", w: K }],
                    [{ cmd: "ok", label: okLabel, glyph: compact ? undefined : "≡", w: Theme.kbOkKey }])
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
    // Tout le texte, d'un coup (une suggestion, une recherche récente).
    function setText(s) {
        text = s
        cursor = s.length
        lastTyped = -1
    }
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
        Sounds.play("tick")
    }
    function moveCursor(dir) {
        var next = cursor + dir
        if (next < 0 || next > text.length) {
            Sounds.play("edge")
            return
        }
        cursor = next
        Sounds.play("tick")
    }
    function press(key) {
        if (!key) return
        if (key.chip) chipChosen(key.t)
        else if (key.t !== undefined) insert(key.t)
        else if (key.cmd === "shift") shift()
        else if (key.cmd === "layer") { keyLayer = keyLayer === "abc" ? "123" : "abc"; Sounds.play("tick") }
        else if (key.cmd === "symbols") { keyLayer = keyLayer === "sym" ? "123" : "sym"; Sounds.play("tick") }
        else if (key.cmd === "space") space()
        else if (key.cmd === "back") backspace()
        else if (key.cmd === "ok") submitted()
        else if (key.cmd === "globe") { qwerty = !qwerty; Sounds.play("tick") }
        col = Math.min(col, Math.max(0, keys[row].length - 1))
    }

    // --- Croix : touche voisine ; haut / bas, la plus proche dans la rangée voisine ---
    function keyX(r, c) {
        var x = 0
        for (var i = 0; i < c; i++) x += keyWidth(keys[r][i]) + Theme.kbGap
        return x
    }
    function keyWidth(k) {
        return k.w !== undefined ? k.w : k.cmd === "globe" ? 0 : Math.ceil(chipFont.advanceWidth(k.t)) + 2 * Theme.kbChipPad
    }
    function moveRow(dir) {
        var next = row + dir
        while (next >= 0 && next < keys.length && keys[next].length === 0) next += dir
        if (next < 0 || next >= keys.length) {
            if (dir < 0) upRequested()
            else Sounds.play("edge")
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
        } else {
            press(focusedKey)
        }
    }
    // Y (espace) ou Start (valider) : la même touche Qt.
    function hangup() {
        if (startDown && startDown()) submitted()
        else space()
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
        if (pad.press(event)) return
        if (event.isAutoRepeat && event.key !== Qt.Key_Backspace) return
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // A sur la manette (touche sans texte, cf. SdlGamepadKeyNavigation) : la touche en
            // focus, au relâché. Entrée d'un vrai clavier : valide.
            if (event.text === "") pressA()
            else submitted()
            break
        case Qt.Key_Escape:                       // B
            if (accent >= 0) {                    // la bulle seule
                accent = -1
                pressing = holding = false
                Sounds.play("close")
            } else {
                cancelled()
            }
            break
        case Qt.Key_Menu:                         // X
        case Qt.Key_Backspace:
            backspace()
            break
        case Qt.Key_Hangup:
            hangup()
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

    width: Theme.kbWidth; height: m.height

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: root.m.radius
        color: root.m.fill
        border.width: 1; border.color: Theme.kbStroke

        // Raccourcis, puis les touches.
        Repeater {
            id: rows
            model: root.keys.length
            Item {
                id: keyRow
                required property int index
                readonly property var line: root.keys[index]
                x: Theme.kbPad
                y: index === 0 ? root.m.chipsTop : root.m.rowsTop + (index - 1) * root.m.rowStep
                z: index === root.row ? 3 : 1     // (la rangée en focus : son libellé sur la tache)
                width: panel.width - 2 * Theme.kbPad
                height: index === 0 ? root.m.chipHeight : root.m.keyHeight
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
                        width: k.cmd === "globe" ? globeRow.width + 2 * Theme.kbChipPad : root.keyWidth(k)
                        height: keyRow.height
                        z: focused ? 3 : 1
                        scale: ok && root.pressing && focused ? Theme.kbPressScale : 1
                        Behavior on scale { NumberAnimation { duration: Theme.kbPressMove } }
                        Rectangle {
                            anchors.fill: parent
                            radius: key.chip ? height / 2 : root.m.keyRadius
                            visible: key.k.cmd !== "globe"
                            color: key.ok ? Theme.accent : key.k.on ? Theme.kbShiftOn
                                 : key.chip ? Theme.glassPill : key.fn ? Theme.keyFn : Theme.keyChar
                        }
                        Row {
                            id: globeRow
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
                                font.pixelSize: key.chip ? Theme.kbChipSize : key.k.t !== undefined ? root.m.charSize : root.m.fnSize
                                font.weight: key.chip || key.k.t !== undefined ? Font.Medium : Font.DemiBold
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
        // À droite des raccourcis : une indication (« ↑ Suggestions »).
        Row {
            visible: root.chipsHint !== ""
            anchors.right: parent.right; anchors.rightMargin: Theme.kbPad
            y: root.m.chipsTop + (root.m.chipHeight - height) / 2
            spacing: Theme.legendGlyphGapCoco
            ButtonGlyph { anchors.verticalCenter: parent.verticalCenter; label: root.chipsGlyph; ink: Theme.ink3; size: Theme.kbGlyph }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.chipsHint
                color: Theme.ink3
                font.family: Theme.fontUi; font.pixelSize: Theme.listSectionSize; font.weight: Font.DemiBold
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
            visible: root.activeFocus && target !== null && root.focusedKey !== null && root.focusedKey.cmd !== "ok"
            z: 2
            x: target ? target.parent.x + target.x : 0
            y: target ? target.parent.y : 0
            width: target ? target.width : 0
            height: target ? target.height : 0
            radius: root.row === 0 ? height / 2 : root.m.keyRadius
            color: Theme.ink
            opacity: root.accent >= 0 ? Theme.kbSpotDim : 1
            scale: root.pressing ? (root.holding ? Theme.kbHoldScale : Theme.kbPressScale) : Theme.kbFocusScale
            Behavior on x { enabled: root.live; NumberAnimation { duration: Theme.kbSpotMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.kbSpotMove.curve } }
            Behavior on y { enabled: root.live; NumberAnimation { duration: Theme.kbSpotMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.kbSpotMove.curve } }
            Behavior on width { enabled: root.live; NumberAnimation { duration: Theme.kbSpotMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.kbSpotMove.curve } }
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
            readonly property int count: Math.max(1, root.bubble.length)
            z: 5
            width: count * Theme.kbAccentKey.width + (count - 1) * Theme.kbAccentGap + 2 * Theme.kbAccentPad
            height: Theme.kbAccentKey.height + 2 * Theme.kbAccentPad
            x: Math.max(Theme.kbAccentInset, Math.min(panel.width - width - Theme.kbAccentInset,
                                                     spot.x + spot.width / 2 - width / 2))
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
            y: panel.height - root.m.legendBottom - height
            spacing: Theme.kbLegendGap
            textSize: Theme.legendSizeCoco
            glyphGap: Theme.legendGlyphGapCoco
            pressing: root.pressing
            hints: root.hints
            // Les mêmes gestes qu'à la manette (cf. Keys.onPressed).
            onTriggered: function(glyph) {
                if (glyph === "A") root.press(root.focusedKey)
                else if (glyph === "X") root.backspace()
                else if (glyph === "Y") root.space()
                else if (glyph === "B") root.cancelled()
                else root.glyphTriggered(glyph)
            }
        }
    }
}
