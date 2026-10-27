import QtQuick
import ".."

// Texte de l'écran de veille posé comme dans le navigateur des maquettes : une boîte de
// line-height CSS par ligne (« normal » = ascendante + descendante de Sora, arrondies chacune
// au pixel comme Chromium), la ligne de base à la même hauteur dans la boîte. `textStyle` est
// un style d'IdleTheme ({ size, weight, letterSpacing, lineHeight }).
Item {
    id: root

    property alias text: label.text
    property var textStyle: IdleTheme.caption
    property color color: IdleTheme.textPrimary
    property bool tabular: false
    property alias wrapMode: label.wrapMode
    property alias maximumLineCount: label.maximumLineCount
    property alias elide: label.elide
    property alias horizontalAlignment: label.horizontalAlignment
    readonly property alias label: label

    // Métriques de Sora (hhea = typo, USE_TYPO_METRICS) : ascendante 0,97 em, descendante 0,29 em.
    readonly property int ascent: Math.round(0.97 * textStyle.size)
    readonly property int descent: Math.round(0.29 * textStyle.size)
    readonly property real boxHeight: textStyle.lineHeight ? textStyle.size * textStyle.lineHeight : ascent + descent
    // Ligne de base, depuis le haut de la boîte (demi-interligne CSS).
    readonly property real baselineY: (boxHeight - ascent - descent) / 2 + ascent

    implicitWidth: label.implicitWidth
    implicitHeight: boxHeight * Math.max(1, label.lineCount)

    Text {
        id: label
        width: root.width > 0 ? root.width : implicitWidth
        y: root.baselineY - baselineOffset
        color: root.color
        font.family: IdleTheme.fontFamily
        font.pixelSize: root.textStyle.size
        font.weight: root.textStyle.weight
        font.letterSpacing: root.textStyle.letterSpacing || 0
        font.features: root.tabular ? { "tnum": 1 } : {}
        lineHeightMode: Text.FixedHeight
        lineHeight: root.boxHeight
    }
}
