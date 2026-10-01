import QtQuick

// Écran de démarrage : le mot-symbole « CocoOS » sur noir, comme le thème Plymouth
// (deploy/plymouth/), pour que le passage du démarrage de Linux à l'interface ne se
// voie pas. Il s'efface seul pendant que l'accueil entre. Aucune dépendance Moonlight.
Item {
    id: root

    property bool shown: true
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.splashFade } }

    Timer { interval: Theme.splashHold; running: true; onTriggered: root.shown = false }

    Rectangle { anchors.fill: parent; color: Theme.background }

    Row {
        anchors.centerIn: parent
        // Même taille relative que le logo Plymouth : un tiers de la largeur environ.
        scale: Theme.scale
        Text {
            text: "Coco"
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.splashSize; font.weight: Font.DemiBold
            font.letterSpacing: Theme.splashSpacing
        }
        Text {
            text: "OS"
            color: Theme.accent
            font.family: Theme.fontUi; font.pixelSize: Theme.splashSize; font.weight: Font.DemiBold
            font.letterSpacing: Theme.splashSpacing
        }
    }
}
