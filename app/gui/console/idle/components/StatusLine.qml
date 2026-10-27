pragma ComponentBehavior: Bound
import QtQuick
import ".."

// Ligne d'état (SPEC §2.3) : icône + 8 px + texte, trois items espacés de 28 px.
// items : [{ icon: "monitor" | "signal" | "wifi", text }] ; `badge` (« 5G ») à la place de l'icône.
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
                visible: !entry.modelData.badge
                name: entry.modelData.icon || ""
            }
            NetworkBadge {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!entry.modelData.badge
                text: entry.modelData.badge || ""
            }
            IdleText {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.text
                color: IdleTheme.textStatus
                textStyle: IdleTheme.status
                tabular: true
            }
        }
    }
}
