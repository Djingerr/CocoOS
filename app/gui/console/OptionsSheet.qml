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
    // Un sélecteur { key, label, segments: true, options, index, stats: [{ label, value }],
    // description, note } montre ses choix côte à côte, puis ses chiffres (profil de flux) avec
    // les réglages avancés, sa description sinon ; ses choix `hiddenOptions` (index) se replient
    // et la manette les saute.
    // Réglages avancés : une ligne `advanced` n'apparaît que si l'interrupteur `revealsAdvanced`
    // de l'onglet est allumé ; une ligne `hidden` reste repliée. Repliées, elles gardent leur
    // place dans `rows` (aucune ligne ne prend celle d'une autre) ; la manette les saute.
    // `checked` (vrai ou faux) réserve une coche devant le libellé, tracée si vrai (réseau
    // connecté) ; `locked` : la ligne refuse A (et ← / → pour un réglage) en se secouant, et
    // son `hint`, s'il y en a un, se déplie sous la liste.
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
    // Vrai le temps d'un changement d'onglet : les lignes, réutilisées d'un onglet à
    // l'autre, prennent leurs nouvelles valeurs sans les animer (interrupteurs, chiffres,
    // curseur).
    property bool settling: false
    // Curseur maintenu : répétitions comptées (le pas accélère), arrêt sur un cran.
    property int sliderRepeats: 0
    property double sliderHoldUntil: 0
    // Curseur à la souris : tiré (les ressorts suivent sans délai), la butée au-delà des bouts.
    property bool dragging: false
    function dragTo(row, x, width) {
        rubberAnim.stop()
        rubberRelease.stop()
        var over = x < 0 ? x : x > width ? x - width : 0
        rubberX = (over < 0 ? -1 : 1) * Theme.sliderDragRubber * (1 - 1 / (Math.abs(over) / Theme.sliderDragSpan + 1))
        var value = row.min + Math.min(Math.max(x / width, 0), 1) * (row.max - row.min)
        for (var i = 0; i < row.stops.length; i++)
            if (Math.abs(value - row.stops[i]) < Theme.sliderSnap) value = row.stops[i]
        value = Math.round(value)
        if (value === row.value) return
        for (i = 0; i < row.stops.length; i++) {
            var stop = row.stops[i]
            if (Math.min(row.value, value) < stop && stop <= Math.max(row.value, value)
                    || value === stop) {
                pulseStop = stop                // un cran franchi (ou atteint) pulse
                pulseAnim.restart()
                Sounds.play("detent")
                break
            }
        }
        changed(row.key, value)
    }
    function dragEnd() {
        dragging = false
        rubberRelease.restart()
    }
    NumberAnimation {
        id: rubberRelease
        target: root; property: "rubberX"; to: 0
        duration: Theme.springBouncy.duration
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springBouncy.curve
    }
    // Cran du curseur qui vient d'être franchi (il pulse), et l'avancée de sa pulsation.
    property int pulseStop: -1
    property real pulse: 1
    NumberAnimation {
        id: pulseAnim
        target: root; property: "pulse"; from: 0; to: 1
        duration: Theme.sliderPulse
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
    }
    // 0 → 1 → 0 : la forme de la pulsation, pointe à Theme.sliderPulsePeak.
    readonly property real pulseShape: pulse < Theme.sliderPulsePeak ? pulse / Theme.sliderPulsePeak
                                                                      : (1 - pulse) / (1 - Theme.sliderPulsePeak)
    // Explication d'un refus, dépliée sous la liste quelques secondes.
    property string hint: ""
    property bool hintShown: false
    Timer { id: hintTimer; interval: Theme.sheetHintHold; onTriggered: root.hintShown = false }
    readonly property bool forgettable: tab === 0 && hostName !== ""
    readonly property bool showAdvanced: {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].revealsAdvanced) return rows[i].index === 1
        return true
    }
    function isHidden(i) {
        var r = rows[i]
        return r !== undefined && (r.hidden === true || r.advanced === true && !showAdvanced)
    }
    // Les lignes repliées en même temps : leur ordre, pour la cascade.
    readonly property int advancedCount: rows.filter(function(r) { return r.advanced === true }).length
    // Délai avant que les lignes ne glissent à leur nouvelle place : nul quand on ouvre les
    // réglages avancés (le dessous fait d'abord la place), le temps que les lignes repliées
    // s'effacent sinon. Posé AVANT de signaler le changement (cf. announce).
    property int glideDelay: 0
    function announce(row, next) {
        glideDelay = row && row.revealsAdvanced && next === 1 ? 0 : Theme.foldGlideDelay
    }
    // Défilement de la liste (px) : la ligne en focus reste visible.
    property real scroll: 0
    Behavior on scroll {
        enabled: root.opened && !root.settling
        NumberAnimation { duration: Theme.sheetFocusMove; easing.type: Theme.easeOut }
    }
    function revealCurrent() {
        var view = viewport.height - 2 * Theme.sheetViewportBleed
        var top = rowY(current) - Theme.sheetScrollMargin
        var bottom = rowY(current) + rowHeight(current) + Theme.sheetScrollMargin
        var next = scroll
        if (bottom > next + view) next = bottom - view
        if (top < next) next = top
        scroll = Math.max(0, Math.min(next, rowY(lineCount) - view))
    }
    onCurrentChanged: revealCurrent()
    onRowsChanged: Qt.callLater(function() {
        // La ligne en focus vient d'être repliée : on remonte à la ligne visible au-dessus.
        while (root.current > 0 && root.isHidden(root.current)) root.current--
        root.revealCurrent()
    })
    readonly property int lineCount: rows.length + (forgettable ? 1 : 0)
    // 0 = fermé, 1 = ouvert ; le panneau et le voile en découlent.
    property real reveal: opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.sheetSlide; easing.type: Theme.easeQuint } }

    visible: reveal > 0 || dim.opacity > 0

    function open() {
        tab = 0
        current = 0
        scroll = 0
        pressing = false
        hintShown = false
        forgetHold.reset()
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        pad.stop()
        applyFlick()
        rubberAnim.complete()
        rubberRelease.complete()
        opened = false
        pressing = false
        Sounds.play("close")
        closed()
    }

    function step(dir) {
        var next = current + dir
        while (next >= 0 && next < rows.length && isHidden(next)) next += dir
        if (next < 0 || next >= lineCount) {
            Sounds.play("edge")
            return
        }
        moveTo(next)
    }
    function moveTo(next) {
        pressing = false
        applyFlick()
        bumpAnim.complete()
        rubberAnim.complete()
        rubberRelease.complete()
        hintShown = false
        current = next
        Sounds.play("move")
    }
    // La souris bouge sur la ligne `i` : la sélection y vient (pas pendant un appui, ni en
    // tirant le curseur).
    function pointRow(i) {
        if (i !== current && !pressing && !dragging && !isHidden(i)) moveTo(i)
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
        rubberRelease.complete()
        hintShown = false
        settling = true
        tab = next
        current = 0
        scroll = 0
        settling = false
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
            Sounds.play("deny")
            if (row.hint) {
                hint = row.hint
                hintShown = true
                hintTimer.restart()
            }
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
            Sounds.play(want === 1 ? "toggle-on" : "toggle-off")
            flick = { row: current, key: row.key, index: want }
            flickWait.restart()
            return
        }
        var next = wrap ? (row.index + 1) % row.options.length : row.index + dir
        var hidden = row.hiddenOptions || []
        while (hidden.indexOf(next) >= 0)
            next = wrap ? (next + 1) % row.options.length : next + dir
        if (next < 0 || next >= row.options.length) {
            rubber(dir)
            Sounds.play("edge")
            return
        }
        direction = dir
        Sounds.play(row.toggle ? (next === 1 ? "toggle-on" : "toggle-off") : row.segments ? "segment" : "tick")
        announce(row, next)
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
        var crossed = false
        for (var i = 0; i < row.stops.length; i++) {
            var stop = row.stops[i]
            if (dir > 0 ? row.value < stop && next >= stop : row.value > stop && next <= stop) {
                if (repeat) {                   // maintenu : arrêt sur le cran
                    next = stop
                    sliderHoldUntil = now + Theme.sliderStopHold
                    sliderRepeats = 0
                }
                pulseStop = stop                // franchi : il pulse, et clique
                pulseAnim.restart()
                crossed = true
                break
            }
        }
        Sounds.play(crossed ? "detent" : "tick")
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
    // Lignes de hauteurs variables : un curseur, un sélecteur sont plus hauts.
    function rowHeight(i) {
        return i >= rows.length ? Theme.sheetRowHeight
             : isHidden(i) ? 0
             : rows[i].slider ? Theme.sheetSliderRowHeight
             : rows[i].segments ? Theme.sheetSegmentsRowHeight : Theme.sheetRowHeight
    }
    // Un choix du sélecteur de la ligne `line`, à la souris.
    function choose(line, index) {
        if (current !== line) {
            pressing = false
            current = line
        }
        var row = rows[line]
        if (index === row.index) return
        direction = index > row.index ? 1 : -1
        Sounds.play("segment")
        announce(row, index)
        changed(row.key, index)
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
        announce(rows.find(function(r) { return r.key === f.key }), f.index)
        changed(f.key, f.index)
    }
    Timer { id: flickWait; interval: Theme.pressDuration; onTriggered: root.applyFlick() }
    NumberAnimation {
        id: bumpAnim
        target: root; property: "bump"; from: 0; to: 1
        duration: Theme.switchBumpDuration
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
    }
    // A, au relâché. « Oublier ce PC » ne se valide pas ainsi : il se maintient (forgetHold).
    function activate() {
        if (current < rows.length) change(1, true)
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
        property bool clickable: false           // à la souris : clicked(), éclairé au survol
        signal clicked()
        readonly property real stroke: 1.575
        readonly property real arm: 5.57
        readonly property color ink: chevronMouse.containsMouse ? Theme.ink : Theme.ink3

        width: Theme.sheetChevronSize; height: width
        Repeater {
            model: [-1, 1]
            Rectangle {
                x: (chevron.dir < 0 ? 6.81 : 11.19) - chevron.stroke / 2
                y: 9 - chevron.stroke / 2
                width: chevron.arm + chevron.stroke; height: chevron.stroke
                radius: height / 2
                color: chevron.ink
                Behavior on color { ColorAnimation { duration: Theme.hoverFade } }
                antialiasing: true
                transform: Rotation {
                    origin.x: chevron.stroke / 2; origin.y: chevron.stroke / 2
                    angle: chevron.dir < 0 ? 45 * modelData : 180 - 45 * modelData
                }
            }
        }
        HoverArea {
            id: chevronMouse
            anchors.fill: parent
            anchors.margins: -Theme.chevronTouch
            enabled: chevron.clickable
            onClicked: chevron.clicked()
        }
    }

    // Interrupteur d'une ligne `toggle` : le pouce glisse avec le ressort « rebond » et
    // s'étire pendant l'appui ; l'orange se répand depuis la place du pouce éteint (le
    // disque du prototype, rogné à la piste).
    component Switch: Item {
        id: sw
        property bool animated: true
        property bool checked: false
        property bool focused: false
        property bool pressed: false
        property real nudge: 0               // butée, en px
        property string text                 // la valeur, pour les lecteurs d'écran
        property real spread: checked ? Theme.switchFillRadius : 0
        Behavior on spread {
            enabled: sw.animated
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
            color: sw.checked ? Theme.inkOnAccent : sw.focused ? Theme.switchThumbFocus : Theme.ink2
            transform: Translate { x: sw.nudge }
            Behavior on x {
                enabled: sw.animated
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
                enabled: sw.animated
                ColorAnimation {
                    duration: Theme.switchInkFade
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
        }
    }

    // Apparition en cascade (réglages avancés) : `shown` va de 0 à 1 quand `on` passe à vrai,
    // Theme.unfoldDelay puis `order` fois Theme.unfoldStagger après, en descendant ; il revient
    // à 0 du dernier des `count` éléments au premier, en remontant. D'emblée tant que
    // `animated` est faux (création, changement d'onglet, panneau fermé).
    component Reveal: Item {
        id: reveal
        property bool on: true
        property int order: 0
        property int count: 1
        property bool animated: true
        property real shown: 1
        opacity: shown
        visible: shown > 0
        transform: Translate { y: (reveal.shown - 1) * Theme.foldShift }
        states: State {
            name: "off"; when: !reveal.on
            PropertyChanges { target: reveal; shown: 0 }
        }
        transitions: [
            Transition {
                to: "off"
                enabled: reveal.animated
                SequentialAnimation {
                    PauseAnimation { duration: Math.max(0, reveal.count - 1 - reveal.order) * Theme.foldStaggerOut }
                    NumberAnimation {
                        property: "shown"; duration: Theme.foldOut
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                    }
                }
            },
            Transition {
                from: "off"
                enabled: reveal.animated
                SequentialAnimation {
                    PauseAnimation { duration: Theme.unfoldDelay + reveal.order * Theme.unfoldStagger }
                    NumberAnimation {
                        property: "shown"; duration: Theme.unfoldIn
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                    }
                }
            }
        ]
    }

    component ProfileText: Text {
        property var value
        width: parent ? parent.width : 0
        text: value || ""
        color: Theme.ink2
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeightMode: Text.FixedHeight; lineHeight: Theme.profileTextLineHeight
        font.family: Theme.fontUi; font.pixelSize: Theme.profileTextSize
    }

    component StatText: Text {
        property var value
        width: parent ? parent.width : 0
        height: Theme.statsValueHeight
        verticalAlignment: Text.AlignVCenter
        text: value || ""
        color: Theme.ink
        fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.segmentsLabelMin
        font.family: Theme.fontUi; font.pixelSize: Theme.statsValueSize; font.features: { "tnum": 1 }
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
            // Un onglet par place, conservé quand `tabs` est remplacé (à chaque réglage
            // changé) : recréé, il laisserait un instant le soulignement sans cible.
            Repeater {
                id: tabRepeater
                model: root.tabs.length
                Item {
                    id: tabItem
                    readonly property bool active: index === root.tab
                    anchors.verticalCenter: parent.verticalCenter
                    width: tabLabel.width; height: Theme.sheetTabHeight
                    scale: tabMouse.containsMouse && !active ? Theme.hoverScale : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.springSnappy.duration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                        }
                    }
                    Text {
                        id: tabLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tabs[index] ? root.tabs[index].label : ""
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
                    HoverArea { id: tabMouse; anchors.fill: parent; onClicked: root.switchTab(index - root.tab) }
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

        // La liste défile dans cette zone, qui s'arrête au-dessus de la légende (onglets longs,
        // réseaux Wi-Fi nombreux).
        Item {
            id: viewport
            x: Theme.sheetPadSide - Theme.sheetFocusOutset - Theme.sheetViewportBleed
            y: (tabStrip.visible ? tabStrip.y + tabStrip.height : host.y + host.height) + Theme.sheetRowsTop
               - Theme.sheetViewportBleed
            width: panel.width - 2 * x
            height: legend.y - y - Theme.sheetListBottom
            clip: true

            // Fondus aux bords, s'il reste des lignes à voir de ce côté.
            Rectangle {
                z: 1
                width: parent.width; height: Theme.sheetEdgeFade
                opacity: root.scroll > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.sheetFill }
                    GradientStop { position: 1; color: Qt.rgba(Theme.sheetFill.r, Theme.sheetFill.g, Theme.sheetFill.b, 0) }
                }
            }
            Rectangle {
                z: 1
                y: parent.height - height
                width: parent.width; height: Theme.sheetEdgeFade
                opacity: root.rowY(root.lineCount) - root.scroll > parent.height - 2 * Theme.sheetViewportBleed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Theme.sheetFill.r, Theme.sheetFill.g, Theme.sheetFill.b, 0) }
                    GradientStop { position: 1; color: Theme.sheetFill }
                }
            }
        }
        Item {
            id: list
            parent: viewport
            x: Theme.sheetFocusOutset + Theme.sheetViewportBleed
            y: Theme.sheetViewportBleed - root.scroll
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
                    width: list.width; height: root.rowHeight(index)
                    // Repliée (réglages avancés éteints, ou `hidden`) : elle s'efface en remontant ;
                    // dépliée, elle apparaît en descendant, à son tour dans la cascade. Sa place
                    // glisse au ressort « souple » (après root.glideDelay).
                    property bool ready: false
                    Component.onCompleted: ready = true
                    readonly property bool animated: ready && root.opened && !root.settling
                    Reveal {
                        id: fold
                        on: !root.isHidden(line.index)
                        order: { var n = 0; for (var i = 0; i < line.index; i++) if (root.rows[i] && root.rows[i].advanced) n++; return n }
                        count: root.advancedCount
                        animated: line.animated
                    }
                    opacity: fold.shown
                    visible: fold.shown > 0
                    liftY: (fold.shown - 1) * Theme.foldShift
                    y: root.rowY(index)
                    Behavior on y {
                        enabled: line.animated
                        SequentialAnimation {
                            PauseAnimation { duration: root.glideDelay }
                            NumberAnimation {
                                duration: Theme.springGentle.duration
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                            }
                        }
                    }

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
                    // Sélecteur : la note à droite du libellé (réseau), puis la piste et les chiffres.
                    Text {
                        visible: line.row.segments === true && text !== ""
                        anchors.right: parent.right
                        y: (Theme.sheetRowHeight - height) / 2
                        text: line.row.note || ""
                        color: Theme.ink3
                        font.family: Theme.fontUi; font.pixelSize: Theme.sheetNoteSize
                    }
                    Item {
                        id: segments
                        readonly property int count: line.row.segments === true ? line.row.options.length : 0
                        // Chaque case à la largeur de son libellé, plus une part égale de la place
                        // qui reste ; si les libellés ne tiennent pas tous, cases égales et texte réduit.
                        // Une case repliée (`hiddenOptions`) n'a plus de largeur.
                        readonly property var hidden: line.row.hiddenOptions || []
                        readonly property var cells: {
                            var inner = width - 2 * Theme.segmentsPad, widths = [], sum = 0, shown = 0
                            for (var i = 0; i < count; i++) {
                                var gone = hidden.indexOf(i) >= 0
                                widths.push(gone ? -1 : segmentMetrics.advanceWidth(line.row.options[i]))
                                if (gone) continue
                                sum += widths[i]
                                shown++
                            }
                            var cells = [], x = Theme.segmentsPad
                            for (i = 0; i < count; i++) {
                                var w = widths[i] < 0 ? 0 : sum <= inner ? widths[i] + (inner - sum) / shown : inner / shown
                                cells.push({ x: x, width: w })
                                x += w
                            }
                            return cells
                        }
                        readonly property var chosenCell: cells[line.row.index || 0] || ({ x: 0, width: 0 })
                        visible: count > 0
                        y: Theme.segmentsTop
                        z: 1                    // (au-dessus du clic de la ligne)
                        width: parent.width; height: Theme.segmentsHeight

                        FontMetrics {
                            id: segmentMetrics
                            font.family: Theme.fontUi; font.pixelSize: Theme.segmentsLabelSize; font.weight: Font.Medium
                        }
                        Rectangle { anchors.fill: parent; radius: Theme.segmentsRadius; color: Theme.segmentsTrack }
                        ElasticIndicator {
                            y: Theme.segmentsPad
                            height: parent.height - 2 * Theme.segmentsPad
                            targetLeft: segments.chosenCell.x
                            targetRight: segments.chosenCell.x + segments.chosenCell.width
                            animated: root.opened && !root.settling
                            Rectangle { anchors.fill: parent; radius: Theme.segmentsPillRadius; color: Theme.ink }
                        }
                        Repeater {
                            model: segments.count
                            Item {
                                id: segment
                                readonly property bool chosen: index === line.row.index
                                x: (segments.cells[index] || { x: 0 }).x
                                width: (segments.cells[index] || { width: 0 }).width
                                height: parent.height
                                clip: true              // (une case qui se replie)
                                opacity: segments.hidden.indexOf(index) >= 0 ? 0 : 1
                                Behavior on x {
                                    enabled: line.animated
                                    NumberAnimation {
                                        duration: Theme.springGentle.duration
                                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                                    }
                                }
                                Behavior on width {
                                    enabled: line.animated
                                    NumberAnimation {
                                        duration: Theme.springGentle.duration
                                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                                    }
                                }
                                Behavior on opacity {
                                    enabled: line.animated
                                    NumberAnimation {
                                        duration: Theme.foldOut
                                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                                    }
                                }
                                // Survolé (pas le choix en cours) : un fond discret.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Theme.segmentsPad
                                    radius: Theme.segmentsPillRadius
                                    color: Theme.hoverFill
                                    opacity: segmentMouse.containsMouse && !segment.chosen ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.hoverFade } }
                                }
                                Text {
                                    id: segmentLabel
                                    anchors.centerIn: parent
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: line.row.options[index] || ""
                                    color: Theme.ink2
                                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.segmentsLabelMin
                                    font.family: Theme.fontUi; font.pixelSize: Theme.segmentsLabelSize; font.weight: Font.Medium
                                    states: State {
                                        name: "chosen"; when: segment.chosen
                                        PropertyChanges { target: segmentLabel; color: Theme.inkOnAccent }
                                    }
                                    transitions: [
                                        Transition {
                                            to: "chosen"
                                            SequentialAnimation {
                                                PauseAnimation { duration: Theme.tabInkDelay }
                                                ColorAnimation {
                                                    duration: Theme.tabInkIn
                                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                                                }
                                            }
                                        },
                                        Transition {
                                            from: "chosen"
                                            ColorAnimation {
                                                duration: Theme.sheetFocusFade
                                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                                            }
                                        }
                                    ]
                                }
                                HoverArea {
                                    id: segmentMouse
                                    anchors.fill: parent
                                    onPointed: root.pointRow(line.index)
                                    onClicked: root.choose(line.index, index)
                                }
                            }
                        }
                    }
                    // Sous la piste : la description du profil, ou ses chiffres avec les réglages
                    // avancés ; l'une cède la place aux autres en cascade.
                    Reveal {
                        visible: segments.count > 0 && shown > 0
                        on: !root.showAdvanced
                        animated: line.animated
                        y: Theme.segmentsTop + Theme.segmentsHeight + Theme.statsTop
                        width: parent.width
                        height: 2 * Theme.profileTextLineHeight
                        SwapBox {
                            anchors.fill: parent
                            key: line.row.description || ""
                            value: key
                            direction: root.direction
                            animated: root.opened && !root.settling
                            duration: Theme.heroSwapIn; exitDuration: Theme.heroSwapOut
                            enterCurve: Theme.curveOut; exitCurve: Theme.curveExit

                            ProfileText {}
                            ProfileText {}
                        }
                    }
                    Row {
                        visible: segments.count > 0
                        y: Theme.segmentsTop + Theme.segmentsHeight + Theme.statsTop
                        width: parent.width
                        Repeater {
                            model: line.row.segments === true && line.row.stats ? line.row.stats.length : 0
                            Reveal {
                                readonly property var stat: (line.row.stats || [])[index] || ({ label: "", value: "" })
                                on: root.showAdvanced
                                order: index
                                count: line.row.stats ? line.row.stats.length : 1
                                animated: line.animated
                                width: parent.width * (Theme.statsWeights[index] || 0.25)
                                height: statColumn.height
                                Column {
                                    id: statColumn
                                    width: parent.width
                                    spacing: Theme.statsGap
                                    Text {
                                        text: parent.parent.stat.label
                                        color: Theme.ink3
                                        font.family: Theme.fontUi; font.pixelSize: Theme.statsLabelSize
                                    }
                                    SwapBox {
                                        width: parent.width; height: Theme.statsValueHeight
                                        key: parent.parent.stat.value
                                        value: key
                                        direction: root.direction
                                        animated: root.opened && !root.settling
                                        delay: index * Theme.statsStagger
                                        duration: Theme.heroSwapIn; exitDuration: Theme.heroSwapOut
                                        enterCurve: Theme.curveOut; exitCurve: Theme.curveExit

                                        StatText {}
                                        StatText {}
                                    }
                                }
                            }
                        }
                    }
                    Row {
                        id: value
                        visible: line.row.segments !== true
                        z: 1                    // (les chevrons, au-dessus du clic de la ligne)
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
                            animated: !root.settling
                            visible: line.row.toggle === true
                            checked: line.row.index === 1
                            focused: line.focused
                            pressed: line.focused && (root.pressingRow || (root.flick !== null && root.flick.row === line.index))
                            nudge: line.focused ? root.bumpDir * Theme.switchBump * (1 - Math.abs(2 * root.bump - 1)) : 0
                            text: line.row.toggle === true ? line.row.options[line.row.index] : ""
                        }
                        Chevron {
                            dir: -1
                            visible: line.row.toggle !== true
                            opacity: line.focused && !line.row.action ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                            clickable: line.focused && !line.row.action
                            onClicked: root.change(-1, false)
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

                            ValueText { color: line.row.auto === true ? Theme.ink3 : line.ink }
                            ValueText { color: line.row.auto === true ? Theme.ink3 : line.ink }
                        }
                        Item {
                            visible: line.numeric
                            width: Theme.sheetValueBox.width; height: Theme.sheetValueBox.height
                            RollingNumber {
                                animated: !root.settling
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
                            clickable: line.focused
                            onClicked: root.change(1, line.row.action === true)
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
                        z: 1                    // (au-dessus du clic de la ligne)
                        width: parent.width

                        // À la souris : cliquer place la poignée, tirer la déplace.
                        HoverArea {
                            x: -Theme.sliderHalo; y: -Theme.sliderTouch / 2
                            width: parent.width + 2 * Theme.sliderHalo; height: Theme.sliderTouch
                            enabled: line.row.slider === true
                            preventStealing: true
                            onPointed: root.pointRow(line.index)
                            onPressed: function(mouse) {
                                if (!line.focused) {
                                    root.current = line.index
                                    Sounds.play("move")
                                }
                                root.dragging = true
                                root.dragTo(line.row, mouse.x - Theme.sliderHalo, slider.width)
                            }
                            onPositionChanged: function(mouse) {
                                if (pressed) root.dragTo(line.row, mouse.x - Theme.sliderHalo, slider.width)
                            }
                            onReleased: root.dragEnd()
                            onCanceled: root.dragEnd()
                        }

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
                                enabled: !root.settling && !root.dragging
                                NumberAnimation {
                                    duration: Theme.springSnappy.duration
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                                }
                            }
                        }
                        Repeater {
                            model: line.row.slider ? line.row.stops : []
                            Rectangle {
                                id: tick
                                readonly property real pulse: modelData === root.pulseStop && root.pulse < 1 ? root.pulseShape : 0
                                x: (modelData - line.row.min) / (line.row.max - line.row.min) * slider.width
                                y: Theme.sliderRailHeight / 2 + Theme.sliderTickGap
                                width: 1; height: Theme.sliderTickHeight
                                color: Qt.tint(modelData <= line.row.value ? line.ink : Theme.inkOff,
                                               Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, pulse))
                                transform: Scale { yScale: 1 + (Theme.sliderPulseScale - 1) * tick.pulse }
                            }
                        }
                        Rectangle {
                            x: sliderThumb.x - Theme.sliderHalo; y: sliderThumb.y - Theme.sliderHalo
                            width: sliderThumb.width + 2 * Theme.sliderHalo
                            height: sliderThumb.height + 2 * Theme.sliderHalo
                            radius: width / 2
                            color: Theme.sliderHaloFill
                            opacity: line.focused ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.sliderThumbGrow
                                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                                }
                            }
                        }
                        Rectangle {
                            id: sliderThumb
                            x: slider.at + slider.rubber - width / 2
                            y: -height / 2
                            width: line.focused ? Theme.sliderThumbFocus.width : Theme.sliderThumb.width
                            height: line.focused ? Theme.sliderThumbFocus.height : Theme.sliderThumb.height
                            radius: width / 2
                            color: line.row.auto === true ? Theme.ink2 : Theme.ink
                            Behavior on x {
                                enabled: !root.settling && !root.dragging
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
                    HoverArea {
                        anchors.fill: parent
                        onPointed: root.pointRow(line.index)
                        onClicked: {
                            if (line.focused) {
                                root.change(1, true)
                            } else {
                                root.current = line.index
                                Sounds.play("move")
                            }
                        }
                    }
                }
            }

            // « Oublier ce PC » : A maintenu (HoldFill, ci-dessous).
            Pressable {
                readonly property bool focused: root.current === root.rows.length
                down: root.pressingRow && focused
                downScale: Theme.pressRowScale
                visible: root.forgettable
                y: root.rowY(root.rows.length)
                Behavior on y {
                    enabled: root.opened && !root.settling
                    SequentialAnimation {
                        PauseAnimation { duration: root.glideDelay }
                        NumberAnimation {
                            duration: Theme.springGentle.duration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                        }
                    }
                }
                width: list.width; height: Theme.sheetRowHeight

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Oublier ce PC")
                    color: parent.focused ? Theme.ink : Theme.ink2
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
                // À la souris : cliquer y amène, maintenir le clic oublie le PC.
                HoverArea {
                    anchors.fill: parent
                    onPointed: root.pointRow(root.rows.length)
                    onPressed: {
                        if (!parent.focused) {
                            root.current = root.rows.length
                            Sounds.play("move")
                        }
                        root.pressing = true
                    }
                    onReleased: root.pressing = false
                    onCanceled: root.pressing = false
                }
            }
            // Explication d'un refus : elle se déplie sous la liste (sa place, puis le texte).
            Item {
                y: root.rowY(root.lineCount) + Theme.sheetHintTop
                width: list.width
                height: root.hintShown ? hintBox.height : 0
                visible: height > 0
                clip: true
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.unfoldDuration
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                    }
                }
                Rectangle {
                    id: hintBox
                    y: root.hintShown ? 0 : -Theme.unfoldShift
                    width: parent.width
                    height: hintText.implicitHeight + 2 * Theme.sheetHintPadV
                    radius: Theme.sheetHintRadius
                    color: Theme.sheetHintFill
                    opacity: root.hintShown ? 1 : 0
                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.unfoldMove
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.unfoldFade
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                        }
                    }
                    Text {
                        id: hintText
                        x: Theme.sheetHintPadH; y: Theme.sheetHintPadV
                        width: parent.width - 2 * Theme.sheetHintPadH
                        text: root.hint
                        color: Theme.ink2
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontUi; font.pixelSize: Theme.sheetHintSize
                    }
                }
            }
            // A maintenu sur « Oublier ce PC » : le remplissage, par-dessus la ligne et son
            // surlignage (dont il suit l'écrasement).
            Item {
                x: focusHighlight.x; y: focusHighlight.y
                width: focusHighlight.width; height: focusHighlight.height
                scale: focusHighlight.scale
                visible: root.forgettable && root.current === root.rows.length
                HoldFill {
                    id: forgetHold
                    anchors.fill: parent
                    holding: root.pressing && parent.visible
                    label: qsTr("Oublier ce PC")
                    doneLabel: qsTr("PC oublié")
                    labelX: Theme.sheetFocusOutset
                    radius: Theme.sheetFocusRadius
                    onCompleted: root.forgetConfirmed()      // (« confirm » : joué par HoldFill)
                }
            }
        }

        ControllerLegend {
            id: legend
            x: Theme.sheetPadSide
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.sheetPadBottom
            hints: [ { glyph: "B", label: qsTr("Fermer") },
                     { glyph: "A", label: root.current === root.rows.length ? qsTr("Maintenir") : qsTr("Changer") } ]
            onTriggered: function(glyph) {
                if (glyph === "B") root.close()
                else if (root.current < root.rows.length) root.activate()   // (« Oublier ce PC » se maintient)
            }
        }
    }
}
