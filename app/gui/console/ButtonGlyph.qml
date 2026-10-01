import QtQuick
import QtQuick.Shapes

// Glyphe d'un bouton de manette (A, B, Y…) : une lettre dans un rond. Cerclé par
// défaut ; plein dès qu'on lui donne une couleur de fond (`color`).
// `label` est le bouton par sa POSITION, comme Moonlight le lit (A en bas, B à
// droite, X à gauche, Y en haut) ; le glyphe suit la manette (Theme.buttonLayout) :
// lettres inversées sur une Nintendo, symboles sur une PlayStation.
Rectangle {
    id: root

    property string label
    property color ink: Theme.ink            // lettre et contour
    property real fontSize: Theme.glyphFontSize

    readonly property var nintendo: ({ A: "B", B: "A", X: "Y", Y: "X" })
    readonly property var playstation: ({ A: "cross", B: "circle", X: "square", Y: "triangle" })
    // Ce qui est dessiné : une lettre, ou "cross" / "circle" / "square" / "triangle".
    readonly property string face: Theme.buttonLayout === "nintendo" ? (nintendo[label] || label)
                                 : Theme.buttonLayout === "playstation" ? (playstation[label] || label)
                                 : label
    readonly property real symbol: width * Theme.glyphSymbolScale   // taille des symboles PlayStation

    width: Theme.glyphSize
    height: width
    radius: width / 2
    color: "transparent"
    border.width: color.a > 0 ? 0 : Theme.glyphBorder
    border.pixelAligned: false   // garde le trait de 1,5 px (sinon arrondi à 2)
    border.color: ink

    Text {
        anchors.centerIn: parent
        visible: root.face.length === 1
        text: root.face
        color: root.ink
        font.family: Theme.fontUi; font.pixelSize: root.fontSize; font.weight: Font.Medium
    }

    // --- Symboles PlayStation ---
    Repeater {
        model: root.face === "cross" ? [45, -45] : []
        Rectangle {
            anchors.centerIn: parent
            width: root.symbol * 1.15; height: Theme.glyphBorder
            radius: height / 2
            color: root.ink
            antialiasing: true
            rotation: modelData
        }
    }
    Rectangle {
        anchors.centerIn: parent
        visible: root.face === "circle" || root.face === "square"
        width: root.symbol * (root.face === "circle" ? 0.95 : 0.8); height: width
        radius: root.face === "circle" ? width / 2 : 1
        color: "transparent"
        border.width: Theme.glyphBorder
        border.pixelAligned: false
        border.color: root.ink
    }
    Shape {
        anchors.centerIn: parent
        visible: root.face === "triangle"
        width: root.symbol; height: root.symbol * 0.88
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.ink
            strokeWidth: Theme.glyphBorder
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: root.symbol / 2; startY: 0
            PathLine { x: root.symbol; y: root.symbol * 0.88 }
            PathLine { x: 0; y: root.symbol * 0.88 }
            PathLine { x: root.symbol / 2; y: 0 }
        }
    }
}
