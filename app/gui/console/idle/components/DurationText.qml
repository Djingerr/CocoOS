pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Grand chiffre et son unité, alignés sur la ligne de base (SPEC §2.3) : « 1 h 24 min »,
// « 42 % ». parts : [{ value, unit }]. Chiffres en `bigNumber` (boîte CSS de 72 px de haut),
// unités en `unit`, 6 px entre chiffre et unité, 14 px après une unité suivie d'un chiffre.
Row {
    id: root

    property var parts: []

    // Line-height CSS : la boîte fait `lineHeight` em ; le texte y est centré.
    readonly property real boxHeight: IdleTheme.bigNumber.size * IdleTheme.bigNumber.lineHeight
    height: boxHeight

    Repeater {
        model: root.parts
        Row {
            id: part
            required property var modelData
            required property int index
            spacing: 6
            rightPadding: index < root.parts.length - 1 ? 14 : 0
            Text {
                id: number
                y: (root.boxHeight - implicitHeight) / 2
                text: part.modelData.value
                color: IdleTheme.textPrimary
                font.family: IdleTheme.fontFamily
                font.pixelSize: IdleTheme.bigNumber.size
                font.weight: IdleTheme.bigNumber.weight
                font.letterSpacing: IdleTheme.bigNumber.letterSpacing
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.baseline: number.baseline
                text: part.modelData.unit
                color: IdleTheme.textUnit
                font.family: IdleTheme.fontFamily
                font.pixelSize: IdleTheme.unit.size
                font.weight: IdleTheme.unit.weight
            }
        }
    }
}
