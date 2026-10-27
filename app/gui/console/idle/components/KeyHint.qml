import QtQuick
import ".."

// Indication du bas (SPEC §2.4) : « Appuyez sur (A) pour reprendre ».
Row {
    id: root

    property string glyph: "A"
    property string action: qsTr("pour reprendre")

    spacing: 8

    component HintText: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: IdleTheme.textHint
        font.family: IdleTheme.fontFamily
        font.pixelSize: IdleTheme.hint.size
        font.weight: IdleTheme.hint.weight
    }

    HintText { text: qsTr("Appuyez sur") }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 22; height: 22
        radius: IdleTheme.radiusKeyHint
        color: "transparent"
        border.width: 1
        border.color: IdleTheme.keyHintStroke
        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: IdleTheme.textPrimary
            font.family: IdleTheme.fontFamily
            font.pixelSize: IdleTheme.keyGlyph.size
            font.weight: IdleTheme.keyGlyph.weight
        }
    }
    HintText { text: root.action }
}
