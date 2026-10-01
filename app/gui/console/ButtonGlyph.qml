import QtQuick

// Glyphe d'un bouton de manette (A, B, Y…) : une lettre dans un rond. Cerclé par
// défaut ; plein dès qu'on lui donne une couleur de fond (`color`).
Rectangle {
    id: root

    property string label
    property color ink: Theme.ink            // lettre et contour
    property real fontSize: Theme.glyphFontSize

    width: Theme.glyphSize
    height: width
    radius: width / 2
    color: "transparent"
    border.width: color.a > 0 ? 0 : Theme.glyphBorder
    border.pixelAligned: false   // garde le trait de 1,5 px (sinon arrondi à 2)
    border.color: ink

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.ink
        font.family: Theme.fontMono; font.pixelSize: root.fontSize; font.weight: Font.Medium
    }
}
