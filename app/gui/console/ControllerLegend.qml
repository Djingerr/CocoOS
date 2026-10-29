import QtQuick

// Légende des boutons de la manette : un glyphe, puis ce qu'il fait.
// hints : [{ glyph: "B", label: "Fermer" }, …]. À la souris, une entrée de bouton
// (A, B, X, Y) s'éclaire au survol et, cliquée, émet triggered(glyph) : à l'appelant
// d'y faire ce que fait le bouton. Aucune dépendance Moonlight.
Row {
    id: root

    property var hints: []
    property bool pressing: false        // A enfoncé : son entrée s'écrase (Pressable)
    property int textSize: Theme.legendSize
    property int glyphGap: Theme.legendGlyphGap
    signal triggered(string glyph)

    spacing: Theme.legendGap

    Repeater {
        model: root.hints
        Pressable {
            id: entry
            readonly property bool clickable: ["A", "B", "X", "Y"].indexOf(modelData.glyph) >= 0
            readonly property color ink: area.containsMouse && clickable ? Theme.ink : Theme.ink2
            width: hint.width; height: hint.height
            down: root.pressing && modelData.glyph === "A" || area.pressed
            Row {
                id: hint
                spacing: root.glyphGap
                ButtonGlyph {
                    label: modelData.glyph; ink: entry.ink
                    Behavior on ink { ColorAnimation { duration: Theme.hoverFade } }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: entry.ink
                    font.family: Theme.fontUi; font.pixelSize: root.textSize; font.weight: Font.Medium
                    Behavior on color { ColorAnimation { duration: Theme.hoverFade } }
                }
            }
            HoverArea {
                id: area
                anchors.fill: parent
                enabled: entry.clickable
                onClicked: root.triggered(modelData.glyph)
            }
        }
    }
}
