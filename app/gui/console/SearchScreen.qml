import QtQuick
import QtQuick.Effects
import "Search.js" as Search

// Recherche dans la bibliothèque (Recherche) : plein écran, sur le fond flouté du premier
// résultat. La barre haute, le champ, les résultats en jaquettes (titres, éditeurs et genres ;
// le début du titre trouvé en orange), les recherches récentes à droite, et le clavier compact
// (KeyboardPanel) dont la rangée du haut propose des suggestions. ≡ (ou « Rechercher ») passe
// aux résultats : ← / → choisissent, A ouvre le jeu (chosen), B ou bas reviennent au clavier.
// Haut depuis la rangée du haut : les résultats, sinon les recherches récentes. B au clavier
// referme. Aucune dépendance Moonlight.
FocusScope {
    id: root

    // Les jeux, au format GameInfo du Companion, avec leur jaquette (`cover`) et leur fond
    // (`background`) : { name, developers, publishers, genres, releaseDate, cover, background }.
    property var games: []
    property var recent: []              // recherches récentes, la dernière en tête
    // La barre haute.
    property string hostName
    property bool connected: false
    property int latencyMs: -1
    property int jitterMs: -1
    property string timeText
    property int signalStrength: -1
    property int batteryPercent: -1
    property bool charging: false
    property alias qwerty: panel.qwerty
    property alias startDown: panel.startDown

    signal chosen(int index, string query)   // un résultat : son index dans `games`
    signal closed()

    property bool opened: false
    property string zone: "keys"         // keys, results ou recent : qui a la manette
    property int resultIndex: 0
    property int recentIndex: 0
    readonly property alias panel: panel
    readonly property string query: panel.text
    readonly property var found: Search.results(games, query)
    readonly property var suggestions: Search.suggestions(games, query, Theme.srchSuggestions)
    onFoundChanged: resultIndex = 0

    function open() {
        panel.reset("")
        zone = "keys"
        resultIndex = recentIndex = 0
        opened = true
        panel.forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        opened = false
        Sounds.play("close")
        closed()
    }
    function toKeys() {
        zone = "keys"
        panel.forceActiveFocus()
        Sounds.play("tick")
    }
    function toResults() {
        if (found.length === 0) {
            Sounds.play("deny")
            return
        }
        zone = "results"
        zones.forceActiveFocus()
        Sounds.play("tick")
    }
    function toRecent() {
        if (recent.length === 0) {
            Sounds.play("edge")
            return
        }
        zone = "recent"
        recentIndex = 0
        zones.forceActiveFocus()
        Sounds.play("tick")
    }
    function choose(i) {
        var r = found[i]
        if (!r) return
        Sounds.play("select")
        var q = query
        opened = false
        chosen(r.index, q)
        closed()
    }

    visible: opacity > 0
    opacity: opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.setFade; easing.type: Easing.OutCubic } }

    // --- Fond : le premier résultat, très flouté, sous un voile qui fonce vers le bas ---
    Rectangle { anchors.fill: parent; color: Theme.background }
    MouseArea { anchors.fill: parent; enabled: root.opened }
    BackdropLayer {
        anchors.fill: parent
        readonly property var first: root.found.length > 0 ? root.games[root.found[0].index] : null
        source: first ? (first.background || first.cover || "") : ""
        driftEnabled: root.opened && !Theme.reducedMotion
        opacity: Theme.srchBackdropOpacity
        vignette: 0
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.srchVeilTop }
            GradientStop { position: Theme.srchVeilAt; color: Theme.srchVeilBottom }
        }
    }

    StatusBar {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: implicitHeight
        hostName: root.hostName
        connected: root.connected
        latencyMs: root.latencyMs
        jitterMs: root.jitterMs
        timeText: root.timeText
        signalStrength: root.signalStrength
        batteryPercent: root.batteryPercent
        charging: root.charging
        notificationsAllowed: false
    }

    // --- Le champ ---
    Rectangle {
        id: field
        x: (root.width - width) / 2; y: Theme.srchFieldTop
        width: Theme.srchField.width; height: Theme.srchField.height
        radius: height / 2
        color: Theme.glassRaised
        border.width: 1; border.color: Theme.srchFieldStroke
        Image {
            id: lens
            x: Theme.srchFieldPadLeft; anchors.verticalCenter: parent.verticalCenter
            source: "icons/search.svg"
            width: 18; height: 18
            sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
            opacity: 0.6
        }
        Row {
            anchors.left: lens.right; anchors.leftMargin: Theme.listIconGap + 2
            anchors.verticalCenter: parent.verticalCenter
            QueryText { text: root.query.slice(0, panel.cursor) }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2; height: Theme.srchCaret; radius: 1
                color: Theme.accent
                visible: root.zone === "keys"
                SequentialAnimation on opacity {
                    running: root.opened; loops: Animation.Infinite
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: Theme.kbCaretBlink }
                    PropertyAction { value: 0 }
                    PauseAnimation { duration: Theme.kbCaretBlink }
                }
            }
            QueryText { text: root.query.slice(panel.cursor) }
        }
        Rectangle {                          // effacer la recherche
            anchors.right: parent.right; anchors.rightMargin: Theme.srchFieldPadRight
            anchors.verticalCenter: parent.verticalCenter
            visible: root.query !== ""
            width: Theme.srchClear; height: width; radius: width / 2
            color: Theme.srchClearFill
            Image {
                anchors.centerIn: parent
                source: "icons/clear.svg"
                width: 10; height: 10
                sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
            }
            HoverArea { anchors.fill: parent; anchors.margins: -6; onClicked: { panel.setText(""); Sounds.play("back") } }
        }
    }

    // --- Les résultats ---
    Row {
        x: Theme.margin; y: Theme.srchHeaderTop
        spacing: Theme.listIconGap + 2
        visible: root.query.trim() !== ""
        Text {
            id: count
            text: root.found.length === 0 ? qsTr("Aucun jeu ne correspond à « %1 »").arg(root.query.trim())
                : root.found.length === 1 ? qsTr("1 résultat") : qsTr("%1 résultats").arg(root.found.length)
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.srchCountSize; font.weight: Font.DemiBold
            font.letterSpacing: -0.02 * Theme.srchCountSize
        }
        Text {
            anchors.baseline: count.baseline
            text: qsTr("titres, éditeurs et genres")
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.optHostSize; font.weight: Font.Medium
        }
    }
    ListView {
        id: resultList
        x: Theme.margin; y: Theme.srchResultsTop
        width: root.width - x - Theme.margin - Theme.srchRecentWidth - Theme.srchColumnGap
        height: Theme.srchCover.height + Theme.srchCaption
        orientation: ListView.Horizontal
        spacing: Theme.srchGap
        clip: true
        interactive: false
        model: root.found
        currentIndex: root.resultIndex
        highlightMoveDuration: Theme.durFocus
        preferredHighlightBegin: 0; preferredHighlightEnd: width
        highlightRangeMode: ListView.ApplyRange
        delegate: Item {
            id: result
            required property var modelData
            required property int index
            readonly property var game: root.games[modelData.index] || ({})
            readonly property bool focused: root.zone === "results" && root.resultIndex === index
            width: Theme.srchCover.width; height: resultList.height
            Item {
                id: coverBox
                width: Theme.srchCover.width; height: Theme.srchCover.height
                scale: result.focused ? Theme.srchFocusScale : 1
                Behavior on scale {
                    NumberAnimation { duration: Theme.springSnappy.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve }
                }
                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: Theme.srchCoverRadius
                    visible: false
                    layer.enabled: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.srchCoverRadius
                    color: Theme.glassGroup
                }
                Image {
                    anchors.fill: parent
                    source: result.game.cover || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
                    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && GraphicsInfo.api !== GraphicsInfo.Unknown
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask }
                }
                FocusRing { anchors.fill: parent; shown: result.focused }
            }
            Text {
                y: coverBox.height + Theme.srchCaptionGap
                width: parent.width
                textFormat: Text.StyledText
                // Le début trouvé, en orange.
                text: {
                    var n = result.modelData.name, h = result.modelData.hit
                    var esc = function(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
                    return h > 0 ? "<font color=\"" + Theme.accent + "\"><b>" + esc(n.slice(0, h)) + "</b></font>" + esc(n.slice(h))
                                 : esc(n)
                }
                color: Theme.srchTitleInk
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: Theme.optHostSize; font.weight: Font.Medium
            }
            Text {
                y: coverBox.height + Theme.srchCaptionGap + Theme.srchWhyTop
                width: parent.width
                text: result.modelData.why
                color: Theme.srchWhyInk
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: Theme.srchWhySize; font.weight: Font.Medium
            }
            HoverArea {
                anchors.fill: coverBox
                onClicked: root.choose(result.index)
            }
        }
    }

    // --- Recherches récentes ---
    Column {
        x: root.width - Theme.margin - width; y: Theme.srchRecentTop
        width: Theme.srchRecentWidth
        spacing: Theme.listSectionBelow
        visible: root.recent.length > 0
        Text {
            text: qsTr("Recherches récentes")
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.listSectionSize; font.weight: Font.DemiBold
            font.letterSpacing: Theme.listSectionSpacing; font.capitalization: Font.AllUppercase
        }
        Repeater {
            model: root.recent
            Item {
                readonly property bool focused: root.zone === "recent" && root.recentIndex === index
                width: parent.width; height: Theme.srchRecentRow
                Rectangle {
                    x: -Theme.listIconGap; width: parent.width + Theme.listIconGap; height: parent.height
                    radius: Theme.radiusKey
                    color: Theme.focusRow
                    opacity: parent.focused ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.listFocusFade } }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.listIconGap
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "icons/clock.svg"
                        width: 14; height: 14
                        sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
                        opacity: 0.5
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: parent.parent.focused ? Theme.ink : Theme.srchRecentInk
                        font.family: Theme.fontUi; font.pixelSize: Theme.srchRecentSize; font.weight: Font.Medium
                    }
                }
                HoverArea {
                    anchors.fill: parent
                    onClicked: { panel.setText(modelData); root.toKeys() }
                }
            }
        }
    }

    // La manette hors du clavier : les résultats ou les recherches récentes.
    FocusScope {
        id: zones
        PadRepeat {
            id: pad
            keys: [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right]
            onTriggered: function(key) {
                if (root.zone === "results") {
                    if (key === Qt.Key_Down) root.toKeys()
                    else if (key === Qt.Key_Left || key === Qt.Key_Right) {
                        var next = root.resultIndex + (key === Qt.Key_Left ? -1 : 1)
                        if (next < 0 || next >= root.found.length) Sounds.play("edge")
                        else { root.resultIndex = next; Sounds.play("tick") }
                    } else Sounds.play("edge")
                } else {
                    if (key === Qt.Key_Left) root.toKeys()
                    else if (key === Qt.Key_Up || key === Qt.Key_Down) {
                        next = root.recentIndex + (key === Qt.Key_Up ? -1 : 1)
                        if (next >= root.recent.length) root.toKeys()
                        else if (next < 0) Sounds.play("edge")
                        else { root.recentIndex = next; Sounds.play("tick") }
                    } else Sounds.play("edge")
                }
            }
        }
        Keys.onPressed: function(event) {
            event.accepted = true
            if (pad.press(event) || event.isAutoRepeat) return
            if (event.key === Qt.Key_Escape) root.toKeys()
        }
        Keys.onReleased: function(event) {
            pad.release(event)
            if (event.isAutoRepeat || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
            if (root.zone === "results") root.choose(root.resultIndex)
            else { panel.setText(root.recent[root.recentIndex]); root.toKeys() }
        }
        onActiveFocusChanged: if (!activeFocus) pad.stop()
    }

    // --- Le clavier compact ---
    KeyboardPanel {
        id: panel
        compact: true
        x: (root.width - width) / 2
        y: root.height - Theme.srchKeyboardBottom - height
        focus: true
        live: root.opened
        chips: root.suggestions
        chipsHint: root.suggestions.length > 0 ? qsTr("Suggestions") : ""
        chipsGlyph: "↑"
        okLabel: qsTr("Rechercher")
        hints: [ { glyph: "X", label: qsTr("Effacer") }, { glyph: "Y", label: qsTr("Espace") },
                 { glyph: "LT", label: qsTr("Majuscule") }, { glyph: "≡", label: qsTr("Voir les résultats") },
                 { glyph: "B", label: qsTr("Fermer") } ]
        onSubmitted: root.toResults()
        onCancelled: root.close()
        onChipChosen: function(chip) { panel.setText(chip); Sounds.play("tick") }
        onUpRequested: root.found.length > 0 ? root.toResults() : root.toRecent()
    }

    component QueryText: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Theme.ink
        font.family: Theme.fontUi; font.pixelSize: Theme.srchQuerySize; font.weight: Font.Medium
    }
}
