pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Texte rempli d'un dégradé vertical (heure de l'écran 12, SPEC §3) : le dégradé couvre la
// boîte CSS du texte (line-height), la ligne de base est celle du navigateur (cf. IdleText).
// Une marge autour du texte garde dans la couche les lettres qu'un interlettrage négatif fait
// déborder.
Item {
    id: root

    property alias text: label.text
    property var textStyle: IdleTheme.restClock
    property color topColor: IdleTheme.clockGradientTop
    property color bottomColor: IdleTheme.clockGradientBottom
    readonly property real margin: 24

    implicitWidth: label.implicitWidth
    implicitHeight: label.boxHeight

    Item {
        id: layerBox
        x: -root.margin; y: -root.margin
        width: label.implicitWidth + 2 * root.margin
        height: label.boxHeight + 2 * root.margin
        layer.enabled: true
        layer.effect: ShaderEffect {
            property color topColor: root.topColor
            property color bottomColor: root.bottomColor
            property real boxTop: root.margin / layerBox.height
            property real boxBottom: 1 - root.margin / layerBox.height
            fragmentShader: "../shaders/textgradient.frag.qsb"
        }
        IdleText {
            id: label
            x: root.margin; y: root.margin
            textStyle: root.textStyle
            tabular: true
            color: "white"
        }
    }
}
