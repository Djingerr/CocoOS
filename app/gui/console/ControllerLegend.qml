import QtQuick

// Légende des boutons de la manette : un glyphe, puis ce qu'il fait.
// hints : [{ glyph: "B", label: "Fermer" }, …]. Aucune dépendance Moonlight.
Row {
    id: root

    property var hints: []
    property bool pressing: false        // A enfoncé : son entrée s'écrase (Pressable)

    spacing: Theme.legendGap

    Repeater {
        model: root.hints
        Pressable {
            width: hint.width; height: hint.height
            down: root.pressing && modelData.glyph === "A"
            Row {
                id: hint
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
}
