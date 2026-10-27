pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Grand chiffre et son unité, alignés sur la ligne de base (SPEC §2.3) : « 1 h 24 min »,
// « 42 % ». parts : [{ value, unit }]. Chiffres en `bigNumber`, unités en `unit`, 6 px entre
// chaque élément (le `gap` de la maquette), plus 14 px après une unité suivie d'un chiffre.
Row {
    id: root

    property var parts: []

    // Hauteur de la ligne : celle des chiffres (line-height 1).
    readonly property real numberBaseline: probe.baselineY
    height: probe.boxHeight
    spacing: 6

    IdleText { id: probe; visible: false; textStyle: IdleTheme.bigNumber }

    Repeater {
        model: root.parts
        Row {
            id: part
            required property var modelData
            required property int index
            spacing: 6
            rightPadding: index < root.parts.length - 1 ? 14 : 0
            IdleText {
                text: part.modelData.value
                textStyle: IdleTheme.bigNumber
                tabular: true
            }
            IdleText {
                id: unit
                y: root.numberBaseline - unit.baselineY
                text: part.modelData.unit
                color: IdleTheme.textUnit
                textStyle: IdleTheme.unit
            }
        }
    }
}
