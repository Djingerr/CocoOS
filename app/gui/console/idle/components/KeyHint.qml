import QtQuick
import ".."

// Indication du bas (SPEC §2.4) : « Appuyez sur (A) pour reprendre ».
Row {
    id: root

    property string glyph: "A"
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
            text: root.glyph
            textStyle: IdleTheme.keyGlyph
        }
    }
    HintText { text: root.action }
}
