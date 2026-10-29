import QtQuick

// Bouton en pilule des maquettes (« A Réessayer », « Y Réveiller le PC ») : clair et glyphe
// plein (`primary`), ou de verre et glyphe cerclé. S'écrase tant que `down` ; au clic, le
// signal `clicked` ; `held` : A enfoncé dessus. Aucune dépendance Moonlight.
Pressable {
    id: root

    property bool primary: false
    property string glyph
    property string label
    property real labelSize: primary ? Theme.playLabelSize : Theme.optionsLabelSize
    property bool held: false
    signal clicked()

    width: Theme.playPadLeft + row.width + (primary ? Theme.pillPadRight : Theme.optionsPadRight)
    height: Theme.playHeight
    down: held || mouse.pressed
    hovered: mouse.containsMouse
    hoverScale: Theme.hoverScale

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.primary ? Theme.ink : Theme.glassRaised
        border.color: root.primary ? "transparent" : Theme.hairlineStrong
    }
    Row {
        id: row
        x: Theme.playPadLeft
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.playGap
        ButtonGlyph {
            anchors.verticalCenter: parent.verticalCenter
            label: root.glyph
            size: root.primary ? Theme.playGlyphSize : Theme.optionsGlyphSize
            color: root.primary ? Theme.inkOnLight : "transparent"
            ink: root.primary ? Theme.ink : Theme.optionsGlyphInk
            fontSize: root.primary ? Theme.playGlyphFontSize : Theme.optionsGlyphFontSize
            weight: root.primary ? Font.Bold : Font.DemiBold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.primary ? Theme.inkOnLight : Theme.ink
            font.family: Theme.fontUi; font.pixelSize: root.labelSize; font.weight: Font.DemiBold
        }
    }
    HoverArea { id: mouse; anchors.fill: parent; onClicked: root.clicked() }
}
