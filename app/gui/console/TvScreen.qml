import QtQuick

// Mode salon (MotionSalon) : la console branchée à une TV, son propre écran le dit (« Sur la TV »,
// « CocoOS s'affiche sur Salon · 4K · 60 i/s », « Débranchez la console pour reprendre sur son
// écran ») puis s'assombrit ; débranchée, l'accueil revient. Interface seule : la détection de la
// sortie HDMI (Q16) le déclenchera ; le harnais d'ici là (SystemDemo scene=tv).
Item {
    id: root

    property bool connected: false
    property string screenName: ""       // « Salon · 4K · 60 i/s »

    visible: scene.opacity > 0
    Rectangle { anchors.fill: parent; color: Theme.background; opacity: scene.opacity }

    Item {
        id: scene
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft
        opacity: root.connected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.connected ? Theme.tvIn : Theme.tvOut } }

        // Une fois dit, l'écran de la console s'assombrit (la TV prend le relais).
        Item {
            id: dimmer
            anchors.fill: parent
            opacity: dimmed ? Theme.tvDim : 1
            property bool dimmed: false
            Behavior on opacity { NumberAnimation { duration: Theme.tvDimFade } }
            Timer { running: root.connected; interval: Theme.tvDimAfter; onTriggered: dimmer.dimmed = true }
            Connections { target: root; function onConnectedChanged() { if (root.connected) dimmer.dimmed = false } }

            // La TV : un écran orné d'une lueur orange, son pied.
            Item {
                id: tv
                x: (parent.width - width) / 2; y: Theme.tvTop
                width: Theme.tvSize.width; height: Theme.tvSize.height
                scale: root.connected || Theme.reducedMotion ? 1 : Theme.tvFrom
                Behavior on scale { NumberAnimation { duration: Theme.tvMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain } }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.tvRadius
                    color: "transparent"
                    border.width: Theme.tvBorder; border.color: Theme.ink
                    clip: true
                    Glow {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: parent.height * 0.1
                        width: parent.width * 1.4; height: parent.height * 1.4
                        color: Theme.accent
                    }
                }
                Rectangle { x: (parent.width - 12) / 2; y: parent.height; width: 12; height: 12; color: Theme.ink }
                Rectangle { x: (parent.width - 72) / 2; y: parent.height + 10; width: 72; height: 4; radius: 2; color: Theme.ink }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.tvTextTop
                spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Sur la TV")
                    color: Theme.ink
                    font.family: Theme.fontUi; font.pixelSize: Theme.tvTitleSize; font.weight: Font.DemiBold
                    font.letterSpacing: -0.03 * Theme.tvTitleSize
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("CocoOS s'affiche sur %1").arg(root.screenName)
                    color: Theme.launchStatusInk
                    font.family: Theme.fontUi; font.pixelSize: Theme.tvSubSize; font.weight: Font.Medium
                }
                Item { width: 1; height: Theme.tvNoteTop - 8 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Débranchez la console pour reprendre sur son écran")
                    color: Theme.tvNoteInk
                    font.family: Theme.fontUi; font.pixelSize: Theme.tvNoteSize; font.weight: Font.Medium
                }
            }
        }
    }
}
