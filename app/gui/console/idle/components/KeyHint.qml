pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Indication du bas (SPEC §2.4) : « Appuyez sur (A) pour reprendre ». Le bouton du bas de la
// manette, dessiné comme elle (cf. ButtonGlyph) : A, B sur une Nintendo, ✕ sur une PlayStation.
Row {
    id: root

    readonly property string glyph: IdleTheme.buttonLayout === "nintendo" ? "B" : "A"
    readonly property bool cross: IdleTheme.buttonLayout === "playstation"
    property string action: qsTr("pour reprendre")

    spacing: 8

    component HintText: IdleText {
        anchors.verticalCenter: parent.verticalCenter
        color: IdleTheme.textHint
        textStyle: IdleTheme.hint
    }

    HintText { text: qsTr("Appuyez sur") }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 22; height: 22
        radius: IdleTheme.radiusKeyHint
        color: "transparent"
        border.width: 1
        border.color: IdleTheme.keyHintStroke
        IdleText {
            anchors.centerIn: parent
            visible: !root.cross
            text: root.glyph
            textStyle: IdleTheme.keyGlyph
        }
        // ✕ : deux traits de la graisse de la lettre (≈ 1,5 px sur 11 px).
        Repeater {
            model: root.cross ? [45, -45] : []
            Rectangle {
                required property int modelData
                anchors.centerIn: parent
                width: 9; height: 1.5
                radius: height / 2
                color: IdleTheme.textPrimary
                antialiasing: true
                rotation: modelData
            }
        }
    }
    HintText { text: root.action }
}
