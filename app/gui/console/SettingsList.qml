import QtQuick

// Liste groupée CocoOS (OptionsFeuille, MotionOptions, Reglages*) : des cartes de lignes,
// chacune sous son intitulé, une note dessous. Haut / bas choisissent une ligne, gauche /
// droite (ou A) changent sa valeur, A déclenche une action ; une ligne `hold` se valide en
// maintenant A. La liste ne garde aucun réglage : elle affiche `rows` et signale les choix
// (`changed`, `actionRequested`, `holdCompleted`), à l'appelant d'appliquer la valeur et de
// mettre `rows` à jour. B, Y, LB / RB sont laissés au parent. Aucune dépendance Moonlight.
//
// Une ligne : { key, label }, et pour la ranger `group` (les lignes voisines d'un même
// groupe partagent une carte), `section` (intitulé au-dessus de la carte, pris à sa première
// ligne ; `sectionBusy` : une roue tourne à côté), `footnote` (note sous la carte).
// Sortes de ligne :
// - réglage { options: [libellés], index } : « valeur › » ; `choice: true` : les options en
//   contrôle segmenté à droite ; `toggle: true` (deux options [désactivé, activé]) : un
//   interrupteur (→ active, ← désactive) ; une valeur numérique roule chiffre par chiffre.
// - action { action: true, value } : A la déclenche ; `value` à droite.
// - curseur { slider: true, value, min, max, stops, format: "%1 Mb/s", auto } : signale la
//   nouvelle valeur à la place d'un index ; `icons: [gauche, droite]` (fichiers de icons/) :
//   sans libellé, une icône à chaque bout (Écran et son).
// - profil { segments: true, options, index, hiddenOptions, stats: [{ label, value }],
//   description } : la carte du profil de flux ; ses chiffres avec les réglages avancés, sa
//   description sinon ; ses choix `hiddenOptions` (index) se replient et la manette les saute.
// - appui maintenu { hold: true, doneLabel } : A maintenu jusqu'au bout, puis holdCompleted.
// - information { info: true, sub, stats: [{ label, value }] } : grande tuile, titre,
//   sous-titre et chiffres à droite (réseau connecté).
// Ornements : `tile: { color, icon }` (tuile de couleur, icône blanche), `sub` (sous-titre :
// ligne à deux étages), `lock` (cadenas), `bars` (0 à 4 : signal d'un réseau), `badge`
// (pastille rouge), `valueAccent` (valeur en orange), `battery` (0 à 100, après la valeur),
// `auto` (valeur grisée : choisie ailleurs), `chevron: false` (pas de › après la valeur).
// États : `advanced` (montrée seulement si l'interrupteur `revealsAdvanced` est allumé),
// `hidden` (repliée) — repliées, elles gardent leur place dans `rows` et la manette les
// saute —, `locked` (refuse en se secouant ; son `hint` se déplie sous la liste).
FocusScope {
    id: root

    property var rows: []
    property var metrics: Theme.listSheet            // gabarit : Theme.listSheet, listSettings, listMenu
    property color fadeColor: Theme.background       // couleur sous la liste (fondus des bords)
    // Faux le temps d'un changement d'onglet ou de page : les lignes, réutilisées, prennent
    // leurs nouvelles valeurs sans les animer.
    property bool live: true
    property bool settling: false
    // La ligne en focus est surlignée (le menu des réglages garde la sienne sans la manette).
    property bool highlighted: activeFocus
    // ← / → sur une ligne sans valeur : sideRequested(dir) plutôt que la butée (menu des
    // réglages : → passe au contenu).
    property bool sideExits: false
    readonly property real contentHeight: layout.height

    signal changed(string key, int index)
    signal actionRequested(string key)
    signal holdCompleted(string key)
    signal sideRequested(int dir)

    property int current: 0
    property int direction: 1            // sens du dernier changement de valeur
    // A enfoncé : la ligne d'action, d'interrupteur ou d'appui maintenu s'écrase (Pressable) ;
    // A agit au relâché.
    property bool pressing: false
    readonly property var currentRow: rows[current]
    readonly property bool pressingRow: pressing && currentRow !== undefined
        && (currentRow.action === true || currentRow.toggle === true || currentRow.hold === true)
    // Interrupteur poussé par ← / → : le pouce s'étire Theme.pressDuration, puis la valeur
    // change ({ row, key, index }). Poussé vers l'état déjà là : une butée.
    property var flick: null
    property real bump: 1                // 0 → 1 pendant la butée
    property int bumpDir: 0
    property real rubberX: 0             // butée élastique d'une valeur ou d'un curseur (px)
    property int sliderRepeats: 0        // curseur maintenu : le pas accélère…
    property double sliderHoldUntil: 0   // …et marque un arrêt sur un cran
    property bool dragging: false        // curseur tiré à la souris
    property int pulseStop: -1           // cran qui vient d'être franchi (il pulse)
    property real pulse: 1
    readonly property real pulseShape: pulse < Theme.sliderPulsePeak ? pulse / Theme.sliderPulsePeak
                                                                      : (1 - pulse) / (1 - Theme.sliderPulsePeak)
    property string hint: ""             // explication d'un refus, dépliée sous la liste
    property bool hintShown: false

    // Remet la liste à son début (ouverture, autre onglet, autre page).
    function reset() {
        pad.stop()
        stopAll()
        settling = true
        current = firstShown(0, 1)
        scroll = 0
        settling = false
        pressing = false
        hintShown = false
        holdFill.reset()
    }
    // Termine ce qui est en cours : interrupteur poussé, butées (pas la répétition des flèches :
    // une ligne qui défile à l'appui maintenu passe par ici).
    function stopAll() {
        applyFlick()
        bumpAnim.complete()
        rubberAnim.complete()
        rubberRelease.complete()
    }

    // --- Réglages avancés : les lignes `advanced` suivent l'interrupteur `revealsAdvanced` ---
    readonly property bool showAdvanced: {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].revealsAdvanced) return rows[i].index === 1
        return true
    }
    function isHidden(i) {
        var r = rows[i]
        return r !== undefined && (r.hidden === true || r.advanced === true && !showAdvanced)
    }
    function firstShown(from, dir) {
        for (var i = from; i >= 0 && i < rows.length; i += dir)
            if (!isHidden(i)) return i
        return 0
    }
    readonly property int advancedCount: rows.filter(function(r) { return r.advanced === true }).length
    // Délai avant que les lignes ne glissent à leur nouvelle place : nul quand on ouvre les
    // réglages avancés (le dessous fait d'abord la place), le temps que les lignes repliées
    // s'effacent sinon. Posé AVANT de signaler le changement (cf. announce).
    property int glideDelay: 0
    function announce(row, next) {
        glideDelay = row && row.revealsAdvanced && next === 1 ? 0 : Theme.foldGlideDelay
    }

    // --- Mise en page : chaque ligne, ses cartes, leurs intitulés et leurs notes ---
    function heightOf(r) {
        return r.segments ? Theme.profileHeight
             : r.info ? metrics.info
             : r.slider ? (r.icons ? metrics.iconSlider : metrics.slider)
             : r.sub ? metrics.twoLine : metrics.row
    }
    readonly property real noteHeight: Math.ceil(Theme.listNoteSize * Theme.listNoteLineHeight)
    readonly property var layout: {
        var items = [], cards = [], sections = [], notes = []
        var y = 0, card = null
        var close = function() {
            if (!card) return
            card.height = y - card.y
            cards.push(card)
            if (card.note) {
                notes.push({ y: y + Theme.listNoteTop, text: card.note })
                y += Theme.listNoteTop + noteHeight
            }
        }
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i], hidden = isHidden(i)
            if (!hidden && (card === null || r.group !== card.group)) {
                close()
                if (card) y += metrics.cardGap
                // (l'intitulé peut venir d'une ligne repliée juste avant, du même groupe)
                var section = r.section, busy = r.sectionBusy === true
                for (var k = i - 1; !section && k >= 0 && isHidden(k) && rows[k].group === r.group; k--) {
                    section = rows[k].section
                    busy = rows[k].sectionBusy === true
                }
                if (section) {
                    sections.push({ y: y, text: section, busy: busy })
                    y += Theme.listSectionHeight + Theme.listSectionBelow
                }
                card = { group: r.group, y: y, height: 0, first: i, last: i, note: "" }
            }
            var h = hidden ? 0 : heightOf(r)
            items.push({ y: y, height: h, first: false, last: false })
            if (!hidden) {
                if (card.first === i) items[i].first = true
                card.last = i
                if (r.footnote) card.note = r.footnote
                y += h
            }
        }
        close()
        cards.forEach(function(c) { if (items[c.last]) items[c.last].last = true })
        return { items: items, cards: cards, sections: sections, notes: notes, height: y }
    }
    function rowY(i) { return layout.items[i] ? layout.items[i].y : 0 }
    function rowHeight(i) { return layout.items[i] ? layout.items[i].height : 0 }

    // --- Défilement : la ligne en focus reste visible ---
    property real scroll: 0
    Behavior on scroll {
        enabled: root.live && !root.settling
        NumberAnimation { duration: Theme.sheetFocusMove; easing.type: Theme.easeOut }
    }
    function revealCurrent() {
        var top = rowY(current) - Theme.sheetScrollMargin
        var bottom = rowY(current) + rowHeight(current) + Theme.sheetScrollMargin
        // (la première ligne d'une carte montre aussi son intitulé)
        if (layout.items[current] && layout.items[current].first)
            top -= Theme.listSectionHeight + Theme.listSectionBelow
        var next = scroll
        if (bottom > next + height) next = bottom - height
        if (top < next) next = top
        scroll = Math.max(0, Math.min(next, layout.height + (hintShown ? hintBox.height + Theme.sheetHintTop : 0) - height))
    }
    onCurrentChanged: revealCurrent()
    onHeightChanged: revealCurrent()
    onRowsChanged: Qt.callLater(function() {
        // La ligne en focus vient d'être repliée : on remonte à la ligne visible au-dessus.
        while (root.current > 0 && root.isHidden(root.current)) root.current--
        if (root.current >= root.rows.length) root.current = Math.max(0, root.rows.length - 1)
        root.revealCurrent()
    })

    // --- Navigation ---
    function step(dir) {
        var next = current + dir
        while (next >= 0 && next < rows.length && isHidden(next)) next += dir
        if (next < 0 || next >= rows.length) {
            Sounds.play("edge")
            return
        }
        moveTo(next)
    }
    function moveTo(next) {
        pressing = false
        stopAll()
        hintShown = false
        current = next
        Sounds.play("move")
    }
    // La souris bouge sur la ligne `i` : la sélection y vient (pas pendant un appui, ni en
    // tirant un curseur).
    function pointRow(i) {
        if (i !== current && !pressing && !dragging && !isHidden(i)) moveTo(i)
    }
    function refuse(row) {
        var line = lineRepeater.itemAt(current)
        if (line) line.refuse()
        Sounds.play("deny")
        if (row.hint) {
            hint = row.hint
            hintShown = true
            hintTimer.restart()
        }
    }
    // Gauche / droite : valeur voisine, bute aux extrémités. A (`wrap`) : valeur suivante, en
    // boucle ; action.
    function change(dir, wrap) {
        var row = currentRow
        if (!row) return
        if (row.locked && (wrap || !row.action)) {
            refuse(row)
            return
        }
        if (row.hold) {
            if (!wrap) Sounds.play("edge")          // (A se maintient : cf. holdFill)
            return
        }
        if (row.action || row.info || row.options === undefined && !row.slider) {
            if (wrap && row.action) {
                Sounds.play("select")
                actionRequested(row.key)
            } else if (!wrap && sideExits) {
                sideRequested(dir)
            } else if (!wrap) {
                Sounds.play("edge")
            }
            return
        }
        if (row.slider) {
            if (wrap) Sounds.play("edge")           // A : rien à faire sur un curseur
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
        Sounds.play(row.toggle ? (next === 1 ? "toggle-on" : "toggle-off")
                    : row.segments || row.choice ? "segment" : "tick")
        announce(row, next)
        changed(row.key, next)
    }
    // Une case d'un contrôle segmenté de la ligne `line`, à la souris.
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
    // A, au relâché (une ligne `hold` se maintient : cf. holdFill).
    function activate() {
        if (currentRow && !currentRow.hold) change(1, true)
    }

    // Curseur : un cran, puis plus vite à l'appui maintenu (Theme.slider*), avec un arrêt sur
    // chaque cran marqué ; en bout de course, la butée élastique.
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
        var stops = row.stops || []
        for (var i = 0; i < stops.length; i++) {
            var stop = stops[i]
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
    // À la souris : cliquer place la poignée, tirer la déplace ; au-delà des bouts, la butée
    // s'étire avec résistance.
    function dragTo(row, x, width) {
        rubberAnim.stop()
        rubberRelease.stop()
        var over = x < 0 ? x : x > width ? x - width : 0
        rubberX = (over < 0 ? -1 : 1) * Theme.sliderDragRubber * (1 - 1 / (Math.abs(over) / Theme.sliderDragSpan + 1))
        var value = row.min + Math.min(Math.max(x / width, 0), 1) * (row.max - row.min)
        var stops = row.stops || []
        for (var i = 0; i < stops.length; i++)
            if (Math.abs(value - stops[i]) < Theme.sliderSnap) value = stops[i]
        value = Math.round(value)
        if (value === row.value) return
        for (i = 0; i < stops.length; i++) {
            var stop = stops[i]
            if (Math.min(row.value, value) < stop && stop <= Math.max(row.value, value) || value === stop) {
                pulseStop = stop
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
    function rubber(dir) {
        rubberPush.to = dir * Math.min(Math.abs(rubberX) + Theme.rubberStep, Theme.rubberMax)
        rubberAnim.restart()
    }
    function applyFlick() {
        if (!flick) return
        var f = flick
        flick = null
        flickWait.stop()
        announce(rows.find(function(r) { return r.key === f.key }), f.index)
        changed(f.key, f.index)
    }
    // « 40 % » → { n: 40, suffix: " %" } ; null si ce n'est pas un nombre.
    function numberParts(label) {
        var m = /^(\d+)(\D.*)?$/.exec(label)
        return m ? { n: parseInt(m[1]), suffix: m[2] || "" } : null
    }

    Timer { id: hintTimer; interval: Theme.sheetHintHold; onTriggered: root.hintShown = false }
    Timer { id: flickWait; interval: Theme.pressDuration; onTriggered: root.applyFlick() }
    NumberAnimation {
        id: bumpAnim
        target: root; property: "bump"; from: 0; to: 1
        duration: Theme.switchBumpDuration
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
    }
    NumberAnimation {
        id: pulseAnim
        target: root; property: "pulse"; from: 0; to: 1
        duration: Theme.sliderPulse
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
    }
    NumberAnimation {
        id: rubberRelease
        target: root; property: "rubberX"; to: 0
        duration: Theme.springBouncy.duration
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springBouncy.curve
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
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return
        event.accepted = true
        if (!event.isAutoRepeat) pressing = true
    }
    Keys.onReleased: function(event) {
        pad.release(event)
        if (pressing && !event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            event.accepted = true
            pressing = false
            activate()
        }
    }
    onActiveFocusChanged: if (!activeFocus) { pad.stop(); pressing = false }

    // --- Composants ---
    // Interrupteur CocoOS : piste orange ou grise, pouce blanc qui glisse au ressort et
    // s'étire pendant l'appui.
    component Toggle: Item {
        id: sw
        property bool checked: false
        property bool animated: true
        property bool pressed: false
        property real nudge: 0               // butée, en px
        property string text                 // la valeur, pour les lecteurs d'écran
        width: Theme.toggleSize.width; height: Theme.toggleSize.height
        Accessible.role: Accessible.CheckBox
        Accessible.name: text
        Accessible.checked: checked
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sw.checked ? Theme.accent : Theme.toggleOff
            Behavior on color { enabled: sw.animated; ColorAnimation { duration: Theme.toggleFill } }
        }
        Rectangle {
            y: Theme.toggleInset
            width: sw.pressed ? Theme.switchThumbStretch + Theme.toggleInset * 2 : Theme.toggleThumb
            height: Theme.toggleThumb
            radius: height / 2
            x: (sw.checked ? sw.width - Theme.toggleInset - width : Theme.toggleInset) + sw.nudge
            color: Theme.knob
            Behavior on x {
                enabled: sw.animated
                NumberAnimation {
                    duration: Theme.toggleMove.duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.toggleMove.curve
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Theme.switchStretch
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
        }
    }

    // Contrôle segmenté : une piste grise, la case choisie blanche (texte noir) qui glisse.
    component Segments: Item {
        id: seg
        property var options: []
        property int index: 0
        property var hiddenOptions: []
        property real cell: 0                // largeur d'une case (0 : à parts égales)
        property int cellHeight: Theme.segmentInlineHeight
        property int cellRadius: 8
        property int textSize: Theme.segmentInlineSize
        property color track: Theme.segmentTrack
        property bool animated: true
        signal picked(int index)
        signal pointed()
        readonly property var shown: {
            var list = []
            for (var i = 0; i < options.length; i++)
                if (hiddenOptions.indexOf(i) < 0) list.push(i)
            return list
        }
        readonly property real cellWidth: cell > 0 ? cell : (width - 6) / Math.max(1, shown.length)
        function cellX(i) { return 3 + Math.max(0, shown.indexOf(i)) * cellWidth }
        implicitWidth: cell * shown.length + 6
        height: cellHeight + 6
        Rectangle { anchors.fill: parent; radius: seg.cellRadius + 3; color: seg.track }
        Rectangle {
            x: seg.cellX(seg.index); y: 3
            width: seg.cellWidth; height: seg.cellHeight
            radius: seg.cellRadius
            color: Theme.ink
            Behavior on x {
                enabled: seg.animated
                NumberAnimation {
                    duration: Theme.segmentMove.duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.segmentMove.curve
                }
            }
            Behavior on width {
                enabled: seg.animated
                NumberAnimation {
                    duration: Theme.segmentMove.duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.segmentMove.curve
                }
            }
        }
        Repeater {
            model: seg.options.length
            Item {
                readonly property bool chosen: index === seg.index
                readonly property bool gone: seg.hiddenOptions.indexOf(index) >= 0
                x: seg.cellX(index); y: 3
                width: gone ? 0 : seg.cellWidth; height: seg.cellHeight
                visible: !gone
                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: seg.options[index] || ""
                    color: parent.chosen ? Theme.inkOnLight : Theme.segmentInk
                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: Theme.segmentsLabelMin
                    font.family: Theme.fontUi; font.pixelSize: seg.textSize
                    font.weight: parent.chosen ? Font.DemiBold : Font.Medium
                    Behavior on color { enabled: seg.animated; ColorAnimation { duration: Theme.optTabInkFade } }
                }
                HoverArea {
                    anchors.fill: parent
                    onPointed: seg.pointed()
                    onClicked: seg.picked(index)
                }
            }
        }
    }

    component Icon: Image {
        property string name
        property real size: 16
        source: name !== "" ? "icons/" + name + ".svg" : ""
        sourceSize: Qt.size(size * Theme.scale * 2, size * Theme.scale * 2)
        width: size; height: size
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // Une valeur qui glisse quand elle change (texte) — les nombres roulent (RollingNumber).
    component ValueText: Item {
        id: slot
        property string value
        property color color: Theme.ink2
        property int size: Theme.sheetValueSize
        property int weight: Font.Medium
        width: Theme.listValueBox.width; height: Theme.listValueBox.height
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: slot.value
            color: slot.color
            font.family: Theme.fontUi; font.pixelSize: slot.size; font.weight: slot.weight
        }
    }

    component SectionText: Text {
        color: Theme.ink3
        font.family: Theme.fontUi; font.pixelSize: Theme.listSectionSize; font.weight: Font.DemiBold
        font.letterSpacing: Theme.listSectionSpacing; font.capitalization: Font.AllUppercase
    }

    // --- Contenu ---
    clip: true

    Item {
        id: content
        y: -root.scroll
        width: root.width
        height: root.layout.height

        // Les cartes, sous les lignes.
        Repeater {
            model: root.layout.cards.length
            Rectangle {
                readonly property var card: root.layout.cards[index] || ({ y: 0, height: 0 })
                y: card.y
                width: content.width; height: card.height
                radius: root.metrics.radius
                color: root.metrics.fill
                border.width: root.metrics.stroke === "transparent" ? 0 : 1
                border.color: root.metrics.stroke
                Behavior on y {
                    enabled: root.live && !root.settling
                    SequentialAnimation {
                        PauseAnimation { duration: root.glideDelay }
                        NumberAnimation {
                            duration: Theme.springGentle.duration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                        }
                    }
                }
                Behavior on height {
                    enabled: root.live && !root.settling
                    SequentialAnimation {
                        PauseAnimation { duration: root.glideDelay }
                        NumberAnimation {
                            duration: Theme.springGentle.duration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                        }
                    }
                }
            }
        }
        Repeater {
            model: root.layout.sections.length
            Row {
                readonly property var section: root.layout.sections[index] || ({ y: 0, text: "" })
                x: root.metrics.sectionInset
                y: section.y
                height: Theme.listSectionHeight
                spacing: Theme.listIconGap
                SectionText { anchors.verticalCenter: parent.verticalCenter; text: parent.section.text }
                // Une recherche en cours (réseaux) : une roue.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.section.busy === true
                    width: Theme.listSpinner; height: width
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: Theme.listSpinTurn
                        loops: Animation.Infinite; running: parent.visible
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: Theme.listSpinnerStroke; border.color: Theme.listSpinnerTrack
                    }
                    Item {                      // le quart allumé, en haut à droite
                        x: parent.width / 2
                        width: parent.width / 2; height: parent.height / 2
                        clip: true
                        Rectangle {
                            x: -parent.width
                            width: Theme.listSpinner; height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: Theme.listSpinnerStroke; border.color: Theme.ink
                        }
                    }
                }
            }
        }
        Repeater {
            model: root.layout.notes.length
            Text {
                readonly property var note: root.layout.notes[index] || ({ y: 0, text: "" })
                x: root.metrics.sectionInset
                y: note.y
                width: content.width - 2 * root.metrics.sectionInset
                text: note.text
                color: Theme.ink3
                elide: Text.ElideRight
                lineHeightMode: Text.FixedHeight; lineHeight: root.noteHeight
                font.family: Theme.fontUi; font.pixelSize: Theme.listNoteSize; font.weight: Font.Medium
            }
        }

        // Un délégué par ligne, conservé quand `rows` est remplacé : c'est ce qui permet à la
        // valeur de glisser (ou de rouler) de l'ancienne à la nouvelle.
        Repeater {
            id: lineRepeater
            model: root.rows.length
            Pressable {
                id: line
                required property int index
                readonly property var row: root.rows[index] || ({ label: "", options: [""], index: 0 })
                readonly property var place: root.layout.items[index] || ({ y: 0, height: 0, first: false, last: false })
                readonly property bool focused: root.current === index
                readonly property bool lit: focused && root.highlighted
                readonly property var m: root.metrics
                readonly property color ink: Theme.ink
                readonly property color valueInk: row.auto === true ? Theme.ink3
                    : row.valueAccent === true ? Theme.accent
                    : lit && m.valueFocusInk ? Theme.ink : m.valueInk
                readonly property int valueWeight: lit && m.valueFocusInk ? m.focusWeight : Font.Medium
                readonly property string valueLabel: row.slider ? row.format.arg(row.value)
                    : row.action || row.info || row.options === undefined ? (row.value || "")
                    : (row.options[row.index] || "")
                // Valeur numérique (toutes les options sont des nombres) : elle roule.
                readonly property bool numeric: row.slider === true && !row.icons
                    || row.options !== undefined && !row.action && !row.toggle && !row.choice && row.options.length > 0
                       && row.options.every(function(o) { return root.numberParts(o) !== null })
                readonly property var parts: numeric ? root.numberParts(valueLabel) : null
                readonly property int digits: !numeric ? 1 : row.slider ? String(row.max).length
                    : Math.max.apply(null, row.options.map(function(o) { return String(root.numberParts(o).n).length }))
                readonly property bool plain: !row.segments && !row.info && !(row.slider && row.icons)
                readonly property bool live: ready && root.live && !root.settling
                property bool ready: false
                Component.onCompleted: ready = true
                TextMetrics {
                    id: valueMetrics
                    text: line.valueLabel
                    font.family: Theme.fontUi; font.pixelSize: line.m.value; font.weight: line.valueWeight
                }

                down: root.pressingRow && focused
                downScale: Theme.pressRowScale
                width: content.width; height: place.height
                // Repliée (réglages avancés éteints, ou `hidden`) : elle s'efface en remontant ;
                // dépliée, elle apparaît en descendant, à son tour dans la cascade. Sa place
                // glisse au ressort « souple » (après root.glideDelay).
                Reveal {
                    id: fold
                    on: !root.isHidden(line.index)
                    order: { var n = 0; for (var i = 0; i < line.index; i++) if (root.rows[i] && root.rows[i].advanced) n++; return n }
                    count: root.advancedCount
                    animated: line.live
                }
                opacity: fold.shown
                visible: fold.shown > 0
                liftY: (fold.shown - 1) * Theme.foldShift
                y: place.y
                Behavior on y {
                    enabled: line.live
                    SequentialAnimation {
                        PauseAnimation { duration: root.glideDelay }
                        NumberAnimation {
                            duration: Theme.springGentle.duration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                        }
                    }
                }

                // Fond de la ligne en focus, aux coins de sa carte.
                Rectangle {
                    anchors.fill: parent
                    color: line.m.focusFill
                    topLeftRadius: line.place.first ? line.m.radius : 0
                    topRightRadius: line.place.first ? line.m.radius : 0
                    bottomLeftRadius: line.place.last ? line.m.radius : 0
                    bottomRightRadius: line.place.last ? line.m.radius : 0
                    opacity: line.lit ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.listFocusFade } }
                }
                // Séparateur, au-dessus de toute ligne qui n'ouvre pas sa carte.
                Rectangle {
                    visible: !line.place.first
                    x: line.m.sepInset
                    width: parent.width - x; height: 1
                    color: line.m.sep
                }

                // --- À gauche : tuile, libellé, sous-titre ---
                Rectangle {
                    id: tile
                    readonly property bool big: line.row.info === true
                    readonly property real size: big ? Theme.infoTile : line.m.tile
                    visible: line.row.tile !== undefined
                    x: line.m.padH
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? size : 0; height: size
                    radius: big ? Theme.infoTileRadius : line.m.tileRadius
                    color: line.row.tile ? line.row.tile.color : "transparent"
                    Icon {
                        anchors.centerIn: parent
                        name: line.row.tile ? line.row.tile.icon : ""
                        size: tile.big ? 22 : 16
                    }
                }
                Column {
                    id: labels
                    visible: line.plain || line.row.info === true
                    x: tile.visible ? tile.x + tile.width + (tile.big ? 16 : line.m.gap) : line.m.padH
                    y: line.row.slider ? Theme.listSliderLabelTop : (parent.height - height) / 2
                    width: parent.width - x - line.m.padH - right.width - line.m.gap
                    spacing: line.row.info ? 4 : Theme.listSubGap
                    Text {
                        width: parent.width
                        text: line.row.label || ""
                        color: line.ink
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: line.row.info ? Theme.infoTitleSize : line.m.label
                        font.weight: line.row.info ? Font.DemiBold : line.lit ? line.m.focusWeight : Font.Medium
                    }
                    Text {
                        visible: text !== ""
                        width: parent.width
                        text: line.row.sub || ""
                        color: line.row.info ? Theme.ink2 : Theme.listSubInk
                        elide: Text.ElideRight
                        font.family: Theme.fontUi; font.weight: Font.Medium
                        font.pixelSize: line.row.info ? Theme.infoSubSize : Theme.listSubSize
                    }
                }

                // --- À droite : la valeur (ou l'interrupteur, le choix, les chiffres) ---
                Row {
                    id: right
                    visible: line.plain || line.row.info === true
                    anchors.right: parent.right
                    anchors.rightMargin: line.m.padH
                    y: line.row.slider ? Theme.listSliderLabelTop + (Theme.listValueBox.height - height) / 2 - 2
                       : (parent.height - height) / 2
                    spacing: line.row.info ? Theme.infoStatsGap : Theme.listChevronGap
                    transform: Translate {
                        x: line.focused && !line.row.slider ? root.rubberX : 0
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.row.lock === true
                        name: "lock"; size: 13
                        opacity: 0.55
                    }
                    // Signal d'un réseau : l'icône Wi-Fi, ses arcs allumés selon `bars`.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.row.bars !== undefined
                        width: 18; height: 13
                        Icon { anchors.fill: parent; size: 18; name: (line.row.bars || 0) >= 3 ? "wifi" : "wifi-weak" }
                    }
                    // Chiffres d'une carte d'information.
                    Repeater {
                        model: line.row.info ? (line.row.stats || []) : []
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                anchors.right: parent.right
                                text: modelData.label
                                color: Theme.ink3
                                font.family: Theme.fontUi; font.pixelSize: Theme.infoStatLabel; font.weight: Font.Medium
                            }
                            Text {
                                anchors.right: parent.right
                                text: modelData.value
                                color: Theme.ink
                                font.family: Theme.fontUi; font.pixelSize: Theme.infoStatValue; font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.row.toggle === true
                        animated: line.live
                        checked: line.row.index === 1
                        pressed: line.focused && (root.pressingRow || (root.flick !== null && root.flick.row === line.index))
                        nudge: line.focused ? root.bumpDir * Theme.switchBump * (1 - Math.abs(2 * root.bump - 1)) : 0
                        text: line.row.toggle === true ? line.row.options[line.row.index] : ""
                    }
                    Segments {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.row.choice === true
                        width: implicitWidth
                        cell: Theme.segmentInlineCell
                        options: line.row.choice === true ? line.row.options : []
                        index: line.row.index || 0
                        animated: line.live
                        onPointed: root.pointRow(line.index)
                        onPicked: function(i) { root.choose(line.index, i) }
                    }
                    SwapBox {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !line.row.toggle && !line.row.choice && !line.row.info && !line.row.hold
                                 && !line.numeric && line.valueLabel !== ""
                        width: valueMetrics.advanceWidth; height: Theme.listValueBox.height
                        axis: "x"
                        distance: Theme.sheetValueTravel
                        duration: Theme.sheetValueSwap
                        direction: root.direction
                        animated: line.live
                        key: line.valueLabel
                        value: key
                        ValueText { width: valueMetrics.advanceWidth; size: line.m.value; weight: line.valueWeight; color: line.valueInk }
                        ValueText { width: valueMetrics.advanceWidth; size: line.m.value; weight: line.valueWeight; color: line.valueInk }
                    }
                    RollingNumber {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.numeric
                        animated: line.live
                        value: line.parts ? line.parts.n : 0
                        suffix: line.parts ? line.parts.suffix : ""
                        digits: line.digits
                        pixelSize: line.m.value
                        color: line.valueInk
                    }
                    // Batterie d'une manette, après sa valeur.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.row.battery !== undefined
                        width: 22; height: 11
                        Rectangle {
                            width: 19; height: 11; radius: 3
                            color: "transparent"
                            border.width: 1; border.color: Theme.listSubInk
                        }
                        Rectangle {
                            x: 2; y: 2; height: 7; radius: 2
                            width: 15 * Math.max(0, Math.min(100, line.row.battery || 0)) / 100
                            color: Theme.ink
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.row.badge !== undefined && line.row.badge !== ""
                        width: Math.max(height, badgeText.implicitWidth + 12); height: 20
                        radius: height / 2
                        color: Theme.setBadge
                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: line.row.badge || ""
                            color: Theme.knob
                            font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                        }
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.m.chevron !== false && line.row.chevron !== false && (line.row.action === true && !line.row.info
                                 || line.row.options !== undefined && !line.row.toggle && !line.row.choice)
                        name: "chevron"
                        width: Theme.listChevron.width; height: Theme.listChevron.height
                        size: Theme.listChevron.height
                        opacity: line.lit && line.m.valueFocusInk ? 1 : 0.4
                    }
                }

                // --- Curseur à libellé : la piste sous le libellé ---
                Item {
                    id: slider
                    readonly property bool iconic: line.row.icons !== undefined
                    readonly property real at: line.row.slider
                        ? (line.row.value - line.row.min) / (line.row.max - line.row.min) * width : 0
                    readonly property real rubber: line.focused ? root.rubberX : 0
                    visible: line.row.slider === true
                    x: iconic ? line.m.padH + Theme.listIconSlot + Theme.listIconSliderGap : line.m.padH
                    y: iconic ? parent.height / 2 : Theme.listSliderLabelTop + Theme.listValueBox.height + Theme.listTrackTop
                    width: parent.width - 2 * line.m.padH - (iconic ? 2 * (Theme.listIconSlot + Theme.listIconSliderGap) : 0)
                    z: 1

                    Icon {
                        visible: slider.iconic
                        x: -Theme.listIconSliderGap - Theme.listIconSlot + (Theme.listIconSlot - width) / 2
                        y: -height / 2
                        name: slider.iconic ? line.row.icons[0] : ""
                        size: 14
                        opacity: 0.55
                    }
                    Icon {
                        visible: slider.iconic
                        x: slider.width + Theme.listIconSliderGap + (Theme.listIconSlot - width) / 2
                        y: -height / 2
                        name: slider.iconic ? line.row.icons[1] : ""
                        size: 20
                    }
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
                        width: parent.width; height: slider.iconic ? Theme.listIconTrack : Theme.listTrack
                        radius: height / 2
                        color: Theme.listRail
                    }
                    Rectangle {
                        y: -height / 2
                        width: Math.max(0, slider.at + slider.rubber); height: slider.iconic ? Theme.listIconTrack : Theme.listTrack
                        radius: height / 2
                        color: line.row.auto === true ? Theme.ink3 : slider.iconic ? Theme.ink : Theme.accent
                        Behavior on width {
                            enabled: line.live && !root.dragging
                            NumberAnimation {
                                duration: Theme.springSnappy.duration
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                            }
                        }
                    }
                    Rectangle {
                        readonly property real size: slider.iconic ? Theme.listIconKnob : Theme.listKnob
                        x: slider.at + slider.rubber - width / 2
                        y: -height / 2
                        width: size; height: size
                        radius: size / 2
                        color: line.row.auto === true ? Theme.ink2 : Theme.knob
                        scale: line.lit && !slider.iconic ? Theme.listKnobFocus : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.listKnobGrow.duration
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.listKnobGrow.curve
                            }
                        }
                        Behavior on x {
                            enabled: line.live && !root.dragging
                            NumberAnimation {
                                duration: Theme.springSnappy.duration
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                            }
                        }
                    }
                    Accessible.role: Accessible.Slider
                    Accessible.name: line.row.label || ""
                    Accessible.description: line.valueLabel
                }

                // --- Carte du profil : sélecteur, puis chiffres ou description ---
                Segments {
                    id: profileSeg
                    visible: line.row.segments === true
                    z: 1
                    x: line.m.padH; y: Theme.profilePadV
                    width: parent.width - 2 * line.m.padH
                    cellHeight: Theme.profileSegHeight
                    cellRadius: Theme.profileSegCellRadius
                    textSize: Theme.listSubSize
                    track: Theme.segmentTrackProfile
                    options: line.row.segments === true ? line.row.options : []
                    index: line.row.index || 0
                    hiddenOptions: line.row.hiddenOptions || []
                    animated: line.live
                    onPointed: root.pointRow(line.index)
                    onPicked: function(i) { root.choose(line.index, i) }
                }
                Reveal {
                    visible: line.row.segments === true && shown > 0
                    on: !root.showAdvanced
                    animated: line.live
                    x: line.m.padH
                    y: profileSeg.y + profileSeg.height + Theme.profileStatsTop
                    width: parent.width - 2 * line.m.padH
                    height: parent.height - y - Theme.profilePadV
                    SwapBox {
                        anchors.fill: parent
                        key: line.row.description || ""
                        value: key
                        direction: root.direction
                        animated: line.live
                        duration: Theme.heroSwapIn; exitDuration: Theme.heroSwapOut
                        enterCurve: Theme.curveOut; exitCurve: Theme.curveExit
                        ProfileText {}
                        ProfileText {}
                    }
                }
                Row {
                    visible: line.row.segments === true
                    x: line.m.padH
                    y: profileSeg.y + profileSeg.height + Theme.profileStatsTop
                    width: parent.width - 2 * line.m.padH
                    spacing: Theme.profileStatsGap
                    Repeater {
                        model: line.row.segments === true && line.row.stats ? line.row.stats.length : 0
                        Reveal {
                            readonly property var stat: (line.row.stats || [])[index] || ({ label: "", value: "" })
                            on: root.showAdvanced
                            order: index
                            count: line.row.stats ? line.row.stats.length : 1
                            animated: line.live
                            width: (parent.width - 3 * Theme.profileStatsGap) / 4
                            height: statColumn.height
                            Column {
                                id: statColumn
                                width: parent.width
                                spacing: Theme.listSubGap
                                Text {
                                    text: parent.parent.stat.label
                                    color: Theme.listSubInk
                                    font.family: Theme.fontUi; font.pixelSize: Theme.profileStatLabel; font.weight: Font.Medium
                                }
                                SwapBox {
                                    width: parent.width; height: Theme.statsValueHeight
                                    key: parent.parent.stat.value
                                    value: key
                                    direction: root.direction
                                    animated: line.live
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

                HoverArea {
                    anchors.fill: parent
                    onPointed: root.pointRow(line.index)
                    onPressed: if (line.row.hold && line.focused) root.pressing = true
                    onReleased: if (line.row.hold) root.pressing = false
                    onCanceled: if (line.row.hold) root.pressing = false
                    onClicked: {
                        if (line.row.hold) return
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

        // Une ligne `hold` : A maintenu remplit la ligne, par-dessus son fond.
        Item {
            readonly property var place: root.layout.items[root.current] || ({ y: 0, height: 0, first: false, last: false })
            readonly property Item line: lineRepeater.count > root.current ? lineRepeater.itemAt(root.current) : null
            visible: root.currentRow !== undefined && root.currentRow.hold === true
            y: place.y
            width: content.width; height: place.height
            scale: line ? line.scale : 1
            HoldFill {
                id: holdFill
                anchors.fill: parent
                holding: root.pressing && parent.visible
                label: root.currentRow && root.currentRow.hold ? root.currentRow.label : ""
                doneLabel: root.currentRow && root.currentRow.hold ? (root.currentRow.doneLabel || "") : ""
                labelX: root.metrics.padH
                labelSize: root.metrics.label
                labelWeight: Font.Medium
                radius: root.metrics.radius
                onCompleted: root.holdCompleted(root.currentRow.key)    // (« confirm » : joué par HoldFill)
            }
        }

        // Explication d'un refus : elle se déplie sous la liste (sa place, puis le texte).
        Item {
            y: root.layout.height + Theme.sheetHintTop
            width: content.width
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
    }

    // Fondus aux bords, s'il reste des lignes à voir de ce côté.
    Rectangle {
        width: parent.width; height: Theme.sheetEdgeFade
        opacity: root.scroll > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
        gradient: Gradient {
            GradientStop { position: 0; color: root.fadeColor }
            GradientStop { position: 1; color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0) }
        }
    }
    Rectangle {
        y: parent.height - height
        width: parent.width; height: Theme.sheetEdgeFade
        opacity: root.layout.height - root.scroll > root.height + 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0) }
            GradientStop { position: 1; color: root.fadeColor }
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
        font.family: Theme.fontUi; font.pixelSize: Theme.profileStatValue; font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
