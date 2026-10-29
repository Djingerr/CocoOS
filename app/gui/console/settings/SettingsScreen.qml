import QtQuick
import ".."

// Réglages plein écran (ReglagesWifi, ReglagesManettes, ReglagesEcranSon, ReglagesGeneral) :
// à gauche le titre, la carte de la console et le menu des rubriques (tuiles de couleur) ; à
// droite la page de la rubrique choisie, en listes groupées (SettingsList). La page suit la
// rubrique en focus ; → ou A entrent dans la page, LB / RB passent du menu à la page et
// retour, B revient au menu puis referme. Aucune dépendance Moonlight.
//
// Les rubriques : `pages` ([{ key, label, tile: { color, icon }, value, badge, group, rows }],
// `rows` : lignes de SettingsList ; `group` regroupe les rubriques voisines dans une carte du
// menu). Rien n'est gardé ici : `changed`, `actionRequested` et `holdCompleted` signalent les
// choix de la page, à l'appelant de les appliquer et de mettre `pages` à jour.
FocusScope {
    id: root

    property var pages: []
    readonly property int page: menu.current
    readonly property var rows: pages[page] ? pages[page].rows : []
    // La carte de la console : son nom, puis « CocoOS · 82 % · 41 Go libres ».
    property string deviceName
    property string deviceInfo
    // En haut à droite : l'heure, le Wi-Fi (0 à 4 ; -1 : masqué), la batterie (-1 : masquée).
    property string timeText
    property int signalStrength: -1
    property int batteryPercent: -1

    signal changed(string key, int value)
    signal actionRequested(string key)
    signal holdCompleted(string key)
    signal closed()

    property bool opened: false
    property bool contentFocused: false          // la page a la manette (sinon le menu)
    readonly property alias menu: menu
    readonly property alias content: content

    // Ouvre les réglages sur la rubrique `key` (la première par défaut), le menu en main.
    function open(key) {
        var at = pages.findIndex(function(p) { return p.key === key })
        menu.reset()
        menu.current = Math.max(0, at)
        content.reset()
        contentFocused = false
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        content.stopAll()
        opened = false
        Sounds.play("close")
        closed()
    }
    // Passe du menu à la page (`on`) ou de la page au menu.
    function focusContent(on) {
        if (on && rows.length === 0) {
            Sounds.play("edge")
            return
        }
        if (on === contentFocused) return
        if (on) content.reset()
        contentFocused = on
        Sounds.play("move")
    }

    // Autre rubrique : sa page remplace la précédente sans animer ses valeurs, en fondu.
    onPageChanged: {
        content.reset()
        pageFade.restart()
    }
    NumberAnimation {
        id: pageFade
        target: pageArea; property: "opacity"; from: 0; to: 1
        duration: Theme.setPageFade
    }

    Keys.onPressed: function(event) {
        event.accepted = true    // réglages ouverts : rien ne traverse vers l'accueil
        if (event.isAutoRepeat) return
        switch (event.key) {
        case Qt.Key_Escape:
            if (contentFocused) focusContent(false)
            else close()
            break
        case Qt.Key_PageUp:          // LB / RB : le menu ↔ la page
        case Qt.Key_PageDown:
            focusContent(!contentFocused)
            break
        }
    }

    visible: opacity > 0
    opacity: opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.setFade; easing.type: Easing.OutCubic } }

    Rectangle { anchors.fill: parent; color: Theme.background }
    MouseArea { anchors.fill: parent; enabled: root.opened }   // rien ne passe à l'accueil dessous
    // Lueur bleutée, en haut à gauche.
    Glow {
        x: Theme.setGlowRect.x; y: Theme.setGlowRect.y
        width: Theme.setGlowRect.width; height: Theme.setGlowRect.height
        color: Theme.setGlow
    }

    // --- À gauche : titre, carte de la console, menu ---
    Text {
        id: title
        x: Theme.setMenuX + 4; y: Theme.setTop
        height: Theme.setLineHeight
        verticalAlignment: Text.AlignVCenter
        text: qsTr("Réglages")
        color: Theme.ink
        font.family: Theme.fontUi; font.pixelSize: Theme.setTitleSize; font.weight: Font.DemiBold
        font.letterSpacing: -0.03 * Theme.setTitleSize
    }
    Rectangle {
        id: card
        x: Theme.setMenuX; y: title.y + title.height + Theme.setMenuTop
        width: Theme.setMenuWidth; height: Theme.setCardHeight
        radius: Theme.listMenu.radius + 2
        color: Theme.listMenu.fill
        Rectangle {
            id: cardIcon
            x: Theme.listMenu.padH + 2
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.setCardIcon; height: width
            radius: Theme.infoTileRadius
            color: Theme.setCardIconFill
            border.width: 1; border.color: Theme.hairlineStrong
            Image {
                anchors.centerIn: parent
                source: "../icons/console.svg"
                width: 30; height: 18
                sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
            }
        }
        Column {
            anchors.left: cardIcon.right; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.listSubGap
            Text {
                text: root.deviceName
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold
            }
            Text {
                text: root.deviceInfo
                color: Theme.listSubInk
                font.family: Theme.fontUi; font.pixelSize: Theme.listSubSize; font.weight: Font.Medium
            }
        }
    }
    SettingsList {
        id: menu
        x: Theme.setMenuX
        y: card.y + card.height + Theme.listMenu.cardGap
        width: Theme.setMenuWidth; height: root.height - y
        metrics: Theme.listMenu
        highlighted: true
        sideExits: true
        live: root.opened
        focus: !root.contentFocused
        rows: root.pages.map(function(p) {
            return { key: p.key, label: p.label, tile: p.tile, value: p.value || "", badge: p.badge,
                     group: p.group, action: true }
        })
        onActionRequested: root.focusContent(true)
        onSideRequested: function(dir) { if (dir > 0) root.focusContent(true); else Sounds.play("edge") }
    }
    Rectangle {
        x: Theme.setDividerX; y: Theme.setDividerInset
        width: 1; height: root.height - 2 * Theme.setDividerInset
        color: Theme.setDivider
    }

    // --- En haut à droite : l'heure, le Wi-Fi, la batterie ---
    Row {
        anchors.right: parent.right; anchors.rightMargin: Theme.setContentRight
        y: Theme.setStatusTop
        height: Theme.setStatusHeight
        spacing: Theme.setStatusGap
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
        }
        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.signalStrength >= 0
            source: root.signalStrength >= 3 ? "../icons/wifi.svg" : "../icons/wifi-weak.svg"
            width: 17; height: 12
            sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.batteryPercent >= 0
            width: 25; height: 12
            Rectangle {
                width: 22; height: 12; radius: 3.5
                color: "transparent"
                border.width: 1; border.color: Theme.listSubInk
            }
            Rectangle {
                x: 1.5; y: 1.5; height: 9; radius: 2
                width: 19 * Math.max(0, Math.min(100, root.batteryPercent)) / 100
                color: Theme.ink
            }
            Rectangle { x: 23.3; y: 4; width: 1.6; height: 4; radius: 0.8; color: Theme.listSubInk }
        }
    }

    // --- À droite : la page ---
    Item {
        id: pageArea
        x: Theme.setContentX
        width: root.width - Theme.setContentX - Theme.setContentRight
        height: root.height
        Text {
            y: Theme.setTop
            height: Theme.setLineHeight
            verticalAlignment: Text.AlignVCenter
            text: root.pages[root.page] ? root.pages[root.page].label : ""
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.setPageTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: -0.025 * Theme.setPageTitleSize
        }
        SettingsList {
            id: content
            y: Theme.setContentTop
            width: parent.width; height: Theme.setContentHeight
            rows: root.rows
            metrics: Theme.listSettings
            highlighted: root.contentFocused
            live: root.opened
            focus: root.contentFocused
            onChanged: function(key, value) { root.changed(key, value) }
            onActionRequested: function(key) { root.actionRequested(key) }
            onHoldCompleted: function(key) { root.holdCompleted(key) }
        }
    }

    ControllerLegend {
        anchors.right: parent.right; anchors.rightMargin: Theme.setContentRight
        y: root.height - Theme.setLegendBottom - height
        spacing: Theme.setLegendGap
        textSize: Theme.legendSizeCoco
        glyphGap: Theme.legendGlyphGapCoco
        pressing: root.contentFocused ? content.pressing : menu.pressing
        hints: [ { glyph: "LB", label: qsTr("Menu") },
                 { glyph: "A", label: root.contentFocused && content.currentRow && content.currentRow.hold
                                     ? qsTr("Maintenir") : qsTr("Modifier") },
                 { glyph: "B", label: qsTr("Retour") } ]
        onTriggered: function(glyph) {
            if (glyph === "B") {
                if (root.contentFocused) root.focusContent(false)
                else root.close()
            } else if (glyph === "A") {
                if (root.contentFocused) content.activate()
                else root.focusContent(true)
            }
        }
    }
}
