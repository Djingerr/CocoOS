import QtQuick

// Légende des boutons de la manette : un glyphe, puis ce qu'il fait.
// hints : [{ glyph: "B", label: "Fermer" }, …]. Aucune dépendance Moonlight.
Row {
    id: root

    property var hints: []

    spacing: Theme.legendGap

    Repeater {
        model: root.hints
        Row {
            spacing: Theme.legendGlyphGap
            ButtonGlyph { label: modelData.glyph; ink: Theme.ink2 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.legendSize
            }
        }
    }
}
