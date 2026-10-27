pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Texte rempli d'un dégradé vertical (heure de l'écran 12, SPEC §3) : le dégradé couvre la
// boîte CSS de `boxHeight` px (line-height), centrée sur le texte. Une marge autour du texte
// garde dans la couche les lettres qu'un interlettrage négatif fait déborder.
Item {
    id: root

    property alias text: label.text
    property alias font: label.font
    property real boxHeight: label.implicitHeight
    property color topColor: IdleTheme.clockGradientTop
    property color bottomColor: IdleTheme.clockGradientBottom
    readonly property real margin: 24

    // Taille de la boîte CSS ; le texte en déborde.
    implicitWidth: label.implicitWidth
    implicitHeight: boxHeight

    Item {
        id: layerBox
        x: -root.margin
        y: (root.boxHeight - label.implicitHeight) / 2 - root.margin
        width: label.implicitWidth + 2 * root.margin
        height: label.implicitHeight + 2 * root.margin
        layer.enabled: true
        layer.effect: ShaderEffect {
            property color topColor: root.topColor
            property color bottomColor: root.bottomColor
            property real boxTop: (layerBox.height - root.boxHeight) / 2 / layerBox.height
            property real boxBottom: 1 - (layerBox.height - root.boxHeight) / 2 / layerBox.height
            fragmentShader: "../shaders/textgradient.frag.qsb"
        }
        Text {
            id: label
            x: root.margin; y: root.margin
            color: "white"
        }
    }
}
