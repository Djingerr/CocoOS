import QtQuick

// Panneau « Options » (bouton Y) : glisse depuis la droite pendant que le reste de
// l'écran s'assombrit. Des onglets (L1 / R1) ; haut / bas choisissent une ligne,
// gauche / droite (ou A) changent sa valeur, B ou Y referment. Aucune dépendance
// Moonlight.
//
// Le panneau ne garde aucun réglage : il affiche `tabs` et signale les choix
// (`changed`, `actionRequested`), à l'appelant d'appliquer la valeur et de mettre
// `tabs` à jour.
FocusScope {
    id: root

    // Onglets : [{ label, rows }]. Une ligne est un réglage { key, label, options:
    // [libellés], index }, ou une action { key, label, value, action: true } (A la
    // déclenche ; `value` est affichée à droite). `bars` (0 à 4), facultatif, ajoute
    // une icône de signal devant la valeur (réseaux Wi-Fi). Un réglage `toggle: true` a
    // deux options [désactivé, activé] et s'affiche en interrupteur : → active, ← désactive.
    // Une valeur numérique (« 60 », « 40 % ») roule chiffre par chiffre. Un curseur
    // { key, label, slider: true, value, min, max, stops, format: "%1 Mb/s", auto } signale
    // la nouvelle valeur à la place d'un index (`auto` : valeur grisée, calculée ailleurs).
    // `checked` (vrai ou faux) réserve une coche devant le libellé, tracée si vrai (réseau
    // connecté) ; `locked` : la ligne refuse A (et ← / → pour un réglage) en se secouant.
    property string title: qsTr("Options")
    property var tabs: []
    property int tab: 0
    readonly property var rows: tabs.length > 0 ? tabs[Math.min(tab, tabs.length - 1)].rows : []
    // PC hôte, rappelé sous le titre. S'il est connu, la dernière ligne du premier
    // onglet propose de l'oublier.
    property string hostName
    property bool connected: false
    // Sous le titre, un point d'état (vert si `connected`) et ce texte.
    property string subtitle: hostName

    signal changed(string key, int index)
    signal actionRequested(string key)
    signal forgetConfirmed()
    signal closed()

    property bool opened: false
    property int current: 0              // ligne en focus ; rows.length = « Oublier ce PC »
    property bool confirming: false      // « Oublier ce PC » attend sa confirmation
    property int direction: 1            // sens du dernier changement de valeur
    // A enfoncé : la ligne d'action ou d'interrupteur en focus s'écrase (Pressable) ;
    // A agit au relâché.
    property bool pressing: false
    readonly property bool pressingRow: pressing && (current >= rows.length || rows[current].action === true
                                                     || rows[current].toggle === true)
    // Interrupteur poussé par ← / → : le pouce s'étire Theme.pressDuration, puis la
    // valeur change ({ row, key, index }). Poussé vers l'état déjà là : une butée.
    property var flick: null
    property real bump: 1                // 0 → 1 pendant la butée
    property int bumpDir: 0
    // Butée élastique d'une valeur ou du curseur en bout de course (px, signé).
    property real rubberX: 0
    // Curseur maintenu : répétitions comptées (le pas accélère), arrêt sur un cran.
    property int sliderRepeats: 0
    property double sliderHoldUntil: 0
    readonly property bool forgettable: tab === 0 && hostName !== ""
    readonly property int lineCount: rows.length + (forgettable ? 1 : 0)
    // 0 = fermé, 1 = ouvert ; le panneau et le voile en découlent.
    property real reveal: opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.sheetSlide; easing.type: Theme.easeQuint } }

    visible: reveal > 0 || dim.opacity > 0

    function open() {
        tab = 0
        current = 0
        confirming = false
        pressing = false
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        pad.stop()
        applyFlick()
        rubberAnim.complete()
        opened = false
        confirming = false
        pressing = false
        Sounds.play("close")
        closed()
    }

    function step(dir) {
        var next = current + dir
        if (next < 0 || next >= lineCount) {
            Sounds.play("edge")
            return
        }
        confirming = false
        pressing = false
        applyFlick()
        bumpAnim.complete()
        rubberAnim.complete()
        current = next
        Sounds.play("move")
    }
    // L1 / R1 : onglet voisin, la première ligne en focus.
    function switchTab(dir) {
        var next = tab + dir
        if (next < 0 || next >= tabs.length) {
            Sounds.play("edge")
            return
        }
        applyFlick()
        bumpAnim.complete()
        rubberAnim.complete()
        tab = next
        current = 0
        confirming = false
        pressing = false
        Sounds.play("move")
    }
    // Gauche / droite : valeur voisine, bute aux extrémités. A : valeur suivante, en boucle.
    function change(dir, wrap) {
        if (current >= rows.length) return
        var row = rows[current]
        if (row.locked && (wrap || !row.action)) {
            lineRepeater.itemAt(current).refuse()
            focusHighlight.refuse()             // (la ligne et son surlignage, ensemble)
            Sounds.play("edge")
            return
        }
        if (row.action) {
            if (wrap) {
                Sounds.play("select")
                actionRequested(row.key)
            } else {
                Sounds.play("edge")
            }
            return
        }
        if (row.slider) {
            if (wrap) Sounds.play("edge")       // A : rien à faire sur un curseur
            else slide(row, dir, pad.repeats > 0)
            return
        }
        if (row.toggle && !wrap) {
            var want = dir > 0 ? 1 : 0
            if (want === row.index) {
                bumpDir = dir
                bumpAnim.restart()
                Sounds.play("edge")
                return
            }
            applyFlick()
            Sounds.play("tick")
            flick = { row: current, key: row.key, index: want }
            flickWait.restart()
            return
        }
        var next = wrap ? (row.index + 1) % row.options.length : row.index + dir
        if (next < 0 || next >= row.options.length) {
            rubber(dir)
            Sounds.play("edge")
            return
        }
        direction = dir
        Sounds.play("tick")
        changed(row.key, next)
    }
    // Curseur : un cran, puis plus vite à l'appui maintenu (Theme.slider*), avec un arrêt
    // sur chaque cran marqué ; en bout de course, la butée élastique.
    function slide(row, dir, repeat) {
        var now = Date.now()
        sliderRepeats = repeat ? sliderRepeats + 1 : 0
        if (now < sliderHoldUntil) return
        if (dir > 0 ? row.value >= row.max : row.value <= row.min) {
            rubber(dir)
            Sounds.play("edge")
            return
        }
        var after = Theme.sliderStepAfter, steps = Theme.sliderSteps
        var step = sliderRepeats < after[0] ? steps[0] : sliderRepeats < after[1] ? steps[1] : steps[2]
        var next = Math.min(row.max, Math.max(row.min, row.value + dir * step))
        for (var i = 0; repeat && i < row.stops.length; i++) {
            var stop = row.stops[i]
            if (dir > 0 ? row.value < stop && next >= stop : row.value > stop && next <= stop) {
                next = stop
                sliderHoldUntil = now + Theme.sliderStopHold
                sliderRepeats = 0
                break
            }
        }
        Sounds.play("tick")
        changed(row.key, next)
    }
    function rubber(dir) {
        rubberPush.to = dir * Math.min(Math.abs(rubberX) + Theme.rubberStep, Theme.rubberMax)
        rubberAnim.restart()
    }
    SequentialAnimation {
        id: rubberAnim
        NumberAnimation {
            id: rubberPush
            target: root; property: "rubberX"; duration: Theme.rubberOut
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
        }
        PauseAnimation { duration: Theme.rubberHold - Theme.rubberOut }
        NumberAnimation {
            target: root; property: "rubberX"; to: 0; duration: Theme.springBouncy.duration
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springBouncy.curve
        }
    }
    // « 40 % » → { n: 40, suffix: " %" } ; null si ce n'est pas un nombre.
    function numberParts(label) {
        var m = /^(\d+)(\D.*)?$/.exec(label)
        return m ? { n: parseInt(m[1]), suffix: m[2] || "" } : null
    }
    // Lignes de hauteurs variables : un curseur est plus haut.
    function rowHeight(i) {
        return i < rows.length && rows[i].slider ? Theme.sheetSliderRowHeight : Theme.sheetRowHeight
    }
    function rowY(i) {
        var y = 0
        for (var k = 0; k < i; k++) y += rowHeight(k)
        return y
    }

    function applyFlick() {
        if (!flick) return
        var f = flick
        flick = null
        flickWait.stop()
        changed(f.key, f.index)
    }
    Timer { id: flickWait; interval: Theme.pressDuration; onTriggered: root.applyFlick() }
    NumberAnimation {
        id: bumpAnim
        target: root; property: "bump"; from: 0; to: 1
        duration: Theme.switchBumpDuration
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
    }
    function activate() {
        if (current < rows.length) {
            change(1, true)
        } else if (!confirming) {
            confirming = true
            Sounds.play("tick")
        } else {
            confirming = false
            Sounds.play("select")
            forgetConfirmed()
        }
    }

    PadRepeat {
        id: pad
        keys: [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right]
        onTriggered: function(key) {
            if (key === Qt.Key_Up) root.step(-1)
            else if (key === Qt.Key_Down) root.step(1)
            else root.change(key === Qt.Key_Left ? -1 : 1, false)
        }
    }
    Keys.onPressed: function(event) {
        if (pad.press(event)) return
        event.accepted = true    // panneau ouvert : rien ne traverse vers l'accueil
        if (event.isAutoRepeat) return
        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Hangup:
        case Qt.Key_Menu:
            close()
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            pressing = true
            break
        case Qt.Key_PageUp:          // L1 / R1 au clavier
        case Qt.Key_PageDown:
            switchTab(event.key === Qt.Key_PageUp ? -1 : 1)
            break
        }
    }
    Keys.onReleased: function(event) {
        pad.release(event)
        if (pressing && !event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            pressing = false
            activate()
        }
    }
    onActiveFocusChanged: if (!activeFocus) { pad.stop(); pressing = false }

    // Pointe de chevron (‹ ou ›) : deux traits arrondis qui partent de la pointe.
    // Tracé de l'icône 16 × 16 du prototype, rendue à 14 px au centre de sa case.
    component Chevron: Item {
        id: chevron
        property int dir: 1                      // -1 : ‹ ; +1 : ›
        readonly property real stroke: 1.575
        readonly property real arm: 5.57

        width: Theme.sheetChevronSize; height: width
        Repeater {
            model: [-1, 1]
            Rectangle {
                x: (chevron.dir < 0 ? 6.81 : 11.19) - chevron.stroke / 2
                y: 9 - chevron.stroke / 2
                width: chevron.arm + chevron.stroke; height: chevron.stroke
                radius: height / 2
                color: Theme.ink3
                antialiasing: true
                transform: Rotation {
                    origin.x: chevron.stroke / 2; origin.y: chevron.stroke / 2
                    angle: chevron.dir < 0 ? 45 * modelData : 180 - 45 * modelData
                }
            }
        }
    }

    // Interrupteur d'une ligne `toggle` : le pouce glisse avec le ressort « rebond » et
    // s'étire pendant l'appui ; l'orange se répand depuis la place du pouce éteint (le
    // disque du prototype, rogné à la piste).
    component Switch: Item {
        id: sw
        property bool checked: false
        property bool pressed: false
        property real nudge: 0               // butée, en px
        property string text                 // la valeur, pour les lecteurs d'écran
        property real spread: checked ? Theme.switchFillRadius : 0
        Behavior on spread {
            NumberAnimation {
                duration: Theme.switchFill
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
            }
        }

        width: Theme.switchSize.width; height: Theme.switchSize.height
        Accessible.role: Accessible.CheckBox
        Accessible.name: text
        Accessible.checked: checked

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: Theme.switchStroke; border.color: Theme.switchStrokeColor
            border.pixelAligned: false
        }
        Rectangle {
            readonly property real r: Math.min(sw.spread, sw.height / 2)
            visible: sw.spread > 0
            x: sw.height / 2 - r; y: sw.height / 2 - r
            width: r + Math.min(sw.spread, sw.width - sw.height / 2); height: 2 * r
            radius: r
            color: Theme.accent
        }
        Rectangle {
            y: Theme.switchInset
            width: sw.pressed ? Theme.switchThumbStretch : Theme.switchThumb
            height: Theme.switchThumb
            radius: height / 2
            x: sw.checked ? sw.width - Theme.switchInset - width : Theme.switchInset
            color: sw.checked ? Theme.inkOnAccent : Theme.ink2
            transform: Translate { x: sw.nudge }
            Behavior on x {
                NumberAnimation {
                    duration: Theme.springBouncy.duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springBouncy.curve
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Theme.switchStretch
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.switchInkFade
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
        }
    }

    // Coche du prototype (polyligne 4.5,12.5 → 9.3,17.3 → 19.5,7 sur 24 × 24) : tracée
    // trait après trait quand `checked` passe à vrai, effacée sinon (Theme.check*).
    component CheckMark: Item {
        id: check
        property bool checked: false
        property real drawn: 0
        readonly property real unit: width / 24
        readonly property var points: [Qt.point(4.5, 12.5), Qt.point(9.3, 17.3), Qt.point(19.5, 7)]
        readonly property var legs: [Math.hypot(points[1].x - points[0].x, points[1].y - points[0].y),
                                     Math.hypot(points[2].x - points[1].x, points[2].y - points[1].y)]

        states: State {
            name: "checked"; when: check.checked
            PropertyChanges { target: check; drawn: 1 }
        }
        transitions: [
            Transition {
                to: "checked"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.checkDelay }
                    NumberAnimation {
                        property: "drawn"; duration: Theme.checkDraw
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                    }
                }
            },
            Transition {
                from: "checked"
                NumberAnimation {
                    property: "drawn"; duration: Theme.checkErase
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
        ]
        Repeater {
            model: 2
            Rectangle {
                readonly property point from: check.points[index]
                readonly property point to: check.points[index + 1]
                readonly property real done: (check.drawn * (check.legs[0] + check.legs[1])
                                              - (index === 0 ? 0 : check.legs[0])) / check.legs[index]
                readonly property real stroke: Theme.checkStroke * check.unit
                visible: done > 0
                x: from.x * check.unit - stroke / 2; y: from.y * check.unit - stroke / 2
                width: Math.min(done, 1) * check.legs[index] * check.unit + stroke; height: stroke
                radius: stroke / 2
                color: Theme.accent
                antialiasing: true
                transform: Rotation {
                    origin.x: stroke / 2; origin.y: stroke / 2
                    angle: Math.atan2(to.y - from.y, to.x - from.x) * 180 / Math.PI
                }
            }
        }
    }

    component ValueText: Item {
        id: slot
        property string value
        property color color: Theme.ink2

        width: Theme.sheetValueBox.width; height: Theme.sheetValueBox.height
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: slot.value
            color: slot.color
            font.family: Theme.fontUi; font.pixelSize: Theme.sheetValueSize
        }
    }

    // --- Voile sur le reste de l'écran ---
    Rectangle {
        id: dim
        anchors.fill: parent
        color: Theme.background
        opacity: root.opened ? Theme.sheetDim : 0
        Behavior on opacity { NumberAnimation { duration: Theme.sheetDimFade } }
        MouseArea { anchors.fill: parent; enabled: root.opened; onClicked: root.close() }
    }

    // --- Panneau ---
    Rectangle {
        id: panel
        // Fermé, il attend juste au-delà du bord droit.
        x: root.width - width * root.reveal + width * 0.04 * (1 - root.reveal)
        width: Theme.sheetWidth; height: root.height
        color: Theme.sheetFill

        Rectangle { x: -1; width: 1; height: parent.height; color: Theme.sheetEdge }
        MouseArea { anchors.fill: parent }   // un clic dans le panneau ne le referme pas

        Text {
            id: title
            x: Theme.sheetPadSide; y: Theme.sheetPadTop
            text: root.title
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.sheetTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: Theme.sheetTitleSpacing
        }
        Row {
            id: host
            x: Theme.sheetPadSide
            y: title.y + title.height + Theme.sheetHostTop
            height: hostLabel.height
            spacing: Theme.sheetHostGap
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.subtitle !== ""
                width: Theme.hostDotSize; height: width; radius: width / 2
                color: root.connected ? Theme.ok : Theme.accent
            }
            Text {
                id: hostLabel
                text: root.subtitle
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.sheetHostSize
            }
        }

        // Onglets : [L1] Flux  Console [R1]
        Row {
            id: tabStrip
            x: Theme.sheetPadSide
            y: host.y + host.height + Theme.sheetTabsTop
            spacing: Theme.sheetTabGap
            visible: root.tabs.length > 1

            ButtonGlyph { anchors.verticalCenter: parent.verticalCenter; label: "LB"; ink: Theme.ink3 }
            Repeater {
                id: tabRepeater
                model: root.tabs
                Item {
                    id: tabItem
                    readonly property bool active: index === root.tab
                    anchors.verticalCenter: parent.verticalCenter
                    width: tabLabel.width; height: Theme.sheetTabHeight
                    Text {
                        id: tabLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.ink3
                        font.family: Theme.fontUi; font.pixelSize: Theme.sheetTabSize
                        font.weight: tabItem.active ? Font.DemiBold : Font.Medium
                        states: State {
                            name: "active"; when: tabItem.active
                            PropertyChanges { target: tabLabel; color: Theme.ink }
                        }
                        transitions: [
                            Transition {
                                to: "active"
                                SequentialAnimation {
                                    PauseAnimation { duration: Theme.tabInkDelay }
                                    ColorAnimation {
                                        duration: Theme.tabInkIn
                                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                                    }
                                }
                            },
                            Transition {
                                from: "active"
                                ColorAnimation {
                                    duration: Theme.sheetFocusFade
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                                }
                            }
                        ]
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.switchTab(index - root.tab) }
                }
            }
            ButtonGlyph { anchors.verticalCenter: parent.verticalCenter; label: "RB"; ink: Theme.ink3 }
        }
        // Un seul soulignement, qui passe d'un onglet à l'autre en s'étirant.
        ElasticIndicator {
            id: tabUnderline
            readonly property Item activeTab: tabRepeater.count > root.tab ? tabRepeater.itemAt(root.tab) : null
            visible: tabStrip.visible
            y: tabStrip.y + tabStrip.height - Theme.underlineHeight
            height: Theme.underlineHeight
            targetLeft: activeTab ? tabStrip.x + activeTab.x : 0
            targetRight: activeTab ? tabStrip.x + activeTab.x + activeTab.width : 0
            animated: root.opened
            Rectangle { anchors.fill: parent; radius: Theme.underlineRadius; color: Theme.accent }
        }

        Item {
            id: list
            x: Theme.sheetPadSide
            y: (tabStrip.visible ? tabStrip.y + tabStrip.height : host.y + host.height) + Theme.sheetRowsTop
            width: panel.width - 2 * Theme.sheetPadSide

            Pressable {
                id: focusHighlight
                x: -Theme.sheetFocusOutset
                y: root.rowY(root.current)
                width: parent.width + 2 * Theme.sheetFocusOutset
                height: root.rowHeight(root.current)
                down: root.pressingRow
                downScale: Theme.pressRowScale
                Behavior on y {
                    enabled: root.opened
                    NumberAnimation { duration: Theme.sheetFocusMove; easing.type: Theme.easeOut }
                }
                Behavior on height {
                    enabled: root.opened
                    NumberAnimation { duration: Theme.sheetFocusMove; easing.type: Theme.easeOut }
                }
                Rectangle { anchors.fill: parent; radius: Theme.sheetFocusRadius; color: Theme.sheetFocusFill }
            }

            // Un délégué par ligne, conservé quand `rows` est remplacé : c'est ce qui
            // permet à la valeur de glisser de l'ancienne à la nouvelle.
            Repeater {
                id: lineRepeater
                model: root.rows.length
                Pressable {
                    id: line
                    required property int index
                    readonly property var row: root.rows[index] || ({ label: "", options: [""], index: 0 })
                    readonly property bool focused: root.current === index
                    readonly property color ink: focused ? Theme.ink : Theme.ink2
                    readonly property bool checkable: row.checked !== undefined
                    readonly property string valueLabel: row.slider ? row.format.arg(row.value)
                                                       : row.action ? (row.value || "") : (row.options[row.index] || "")
                    // Valeur numérique (toutes les options sont des nombres) : elle roule.
                    readonly property bool numeric: row.slider === true
                        || !row.action && !row.toggle && row.options.every(function(o) { return root.numberParts(o) !== null })
                    readonly property var parts: numeric ? root.numberParts(valueLabel) : null
                    readonly property int digits: !numeric ? 1 : row.slider ? String(row.max).length
                        : Math.max.apply(null, row.options.map(function(o) { return String(root.numberParts(o).n).length }))

                    down: root.pressingRow && focused
                    downScale: Theme.pressRowScale
                    y: root.rowY(index)
                    width: list.width; height: root.rowHeight(index)

                    CheckMark {
                        visible: line.checkable
                        y: (Theme.sheetRowHeight - height) / 2
                        width: Theme.checkSize; height: width
                        checked: line.row.checked === true
                    }
                    Text {
                        x: line.checkable ? Theme.checkSize + Theme.checkGap : 0
                        y: (Theme.sheetRowHeight - height) / 2
                        width: parent.width - value.width - Theme.sheetRowGap - x
                        text: line.row.label
                        color: line.ink
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontUi; font.pixelSize: Theme.sheetLabelSize
                        Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }
                    }
                    Row {
                        id: value
                        anchors.right: parent.right
                        // (un interrupteur s'aligne sur les valeurs et le glyphe A, pas sur le chevron)
                        anchors.rightMargin: line.row.toggle === true ? Theme.sheetHintRight : 0
                        y: (Theme.sheetRowHeight - height) / 2
                        spacing: Theme.sheetValueGap
                        transform: Translate { x: line.focused && !line.row.slider ? root.rubberX : 0 }

                        // Signal d'un réseau : quatre barres, allumées selon `bars`.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: line.row.bars !== undefined
                            spacing: Theme.signalBarGap
                            Repeater {
                                model: 4
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: Theme.signalBarWidth
                                    height: Theme.signalBarStep * (index + 1)
                                    radius: width / 2
                                    color: (line.row.bars || 0) > index ? line.ink : Theme.inkOff
                                }
                            }
                        }
                        Switch {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: line.row.toggle === true
                            checked: line.row.index === 1
                            pressed: line.focused && (root.pressingRow || (root.flick !== null && root.flick.row === line.index))
                            nudge: line.focused ? root.bumpDir * Theme.switchBump * (1 - Math.abs(2 * root.bump - 1)) : 0
                            text: line.row.toggle === true ? line.row.options[line.row.index] : ""
                        }
                        Chevron {
                            dir: -1
                            visible: line.row.toggle !== true
                            opacity: line.focused && !line.row.action ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                        }
                        SwapBox {
                            visible: line.row.toggle !== true && !line.numeric
                            width: Theme.sheetValueBox.width; height: Theme.sheetValueBox.height
                            axis: "x"
                            distance: Theme.sheetValueTravel
                            duration: Theme.sheetValueSwap
                            direction: root.direction
                            animated: root.opened
                            key: line.valueLabel
                            value: key

                            ValueText { color: line.ink }
                            ValueText { color: line.ink }
                        }
                        Item {
                            visible: line.numeric
                            width: Theme.sheetValueBox.width; height: Theme.sheetValueBox.height
                            RollingNumber {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                value: line.parts ? line.parts.n : 0
                                suffix: line.parts ? line.parts.suffix : ""
                                digits: line.digits
                                color: line.row.auto === true ? Theme.ink3 : line.ink
                            }
                        }
                        Chevron {
                            dir: 1
                            visible: line.row.toggle !== true
                            opacity: line.focused ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                        }
                    }
                    // Curseur : la piste, ses crans, le remplissage jusqu'à la valeur.
                    Item {
                        id: slider
                        readonly property real at: line.row.slider
                            ? (line.row.value - line.row.min) / (line.row.max - line.row.min) * width : 0
                        readonly property real rubber: line.focused ? root.rubberX : 0
                        visible: line.row.slider === true
                        y: Theme.sliderTrackY
                        width: parent.width

                        Rectangle {
                            y: -height / 2
                            width: parent.width; height: Theme.sliderRailHeight
                            radius: height / 2
                            color: Theme.sliderRail
                        }
                        Rectangle {
                            y: -height / 2
                            width: Math.max(0, slider.at + slider.rubber); height: Theme.sliderRailHeight
                            radius: height / 2
                            color: line.row.auto === true ? Theme.ink3 : Theme.accent
                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.springSnappy.duration
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                                }
                            }
                        }
                        Repeater {
                            model: line.row.slider ? line.row.stops : []
                            Rectangle {
                                x: (modelData - line.row.min) / (line.row.max - line.row.min) * slider.width
                                y: Theme.sliderRailHeight / 2 + Theme.sliderTickGap
                                width: 1; height: Theme.sliderTickHeight
                                color: modelData <= line.row.value ? line.ink : Theme.inkOff
                            }
                        }
                        Rectangle {
                            x: slider.at + slider.rubber - width / 2
                            y: -height / 2
                            width: line.focused ? Theme.sliderThumbFocus.width : Theme.sliderThumb.width
                            height: line.focused ? Theme.sliderThumbFocus.height : Theme.sliderThumb.height
                            radius: width / 2
                            color: line.row.auto === true ? Theme.ink2 : Theme.ink
                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.springSnappy.duration
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.sliderThumbGrow
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                                }
                            }
                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.sliderThumbGrow
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                                }
                            }
                        }
                        Accessible.role: Accessible.Slider
                        Accessible.name: line.row.label
                        Accessible.description: line.valueLabel
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (line.focused) {
                                root.change(1, true)
                            } else {
                                root.confirming = false
                                root.current = line.index
                                Sounds.play("move")
                            }
                        }
                    }
                }
            }

            // « Oublier ce PC » : une première pression demande confirmation.
            Pressable {
                readonly property bool focused: root.current === root.rows.length
                down: root.pressingRow && focused
                downScale: Theme.pressRowScale
                visible: root.forgettable
                y: root.rowY(root.rows.length)
                width: list.width; height: Theme.sheetRowHeight

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.confirming ? qsTr("Confirmer : oublier %1 ?").arg(root.hostName)
                                          : qsTr("Oublier ce PC")
                    color: root.confirming ? Theme.accent : parent.focused ? Theme.ink : Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: Theme.sheetLabelSize
                    Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }
                }
                ButtonGlyph {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sheetHintRight
                    anchors.verticalCenter: parent.verticalCenter
                    label: "A"
                    ink: Theme.ink3
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (parent.focused) {
                            root.activate()
                        } else {
                            root.current = root.rows.length
                            Sounds.play("move")
                        }
                    }
                }
            }
        }

        ControllerLegend {
            x: Theme.sheetPadSide
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.sheetPadBottom
            hints: [ { glyph: "B", label: qsTr("Fermer") }, { glyph: "A", label: qsTr("Changer") } ]
        }
    }
}
