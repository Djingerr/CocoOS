pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Ligne d'état (SPEC §2.3) : icône + 8 px + texte, trois items espacés de 28 px.
// items : [{ icon: "monitor" | "signal" | "wifi", text }]
Row {
    id: root

    property var items: []

    spacing: 28

    Repeater {
        model: root.items
        Row {
            id: entry
            required property var modelData
            spacing: 8
            StatusIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: entry.modelData.icon
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.text
                color: IdleTheme.textStatus
                font.family: IdleTheme.fontFamily
                font.pixelSize: IdleTheme.status.size
                font.weight: IdleTheme.status.weight
                font.features: { "tnum": 1 }
            }
        }
    }
}
