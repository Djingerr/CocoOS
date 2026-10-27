import QtQuick
import ".."
import "../components"

// Surtitre (SPEC §2.3) : une marque (pastille ou flèche) + 10 px + le texte en majuscules.
Row {
    id: root

    property string text
    default property alias mark: markBox.data

    spacing: 10

    Item {
        id: markBox
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width; height: childrenRect.height
    }
    IdleText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.text.toUpperCase()
        textStyle: IdleTheme.eyebrow
        color: IdleTheme.textSecondary
    }
}
