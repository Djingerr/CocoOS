import QtQuick
import ".."
import "../IdleFormat.js" as F

// Coin haut droit des écrans 09 à 11 (SPEC §2.1) : l'heure, puis la batterie (cadre SVG
// 25 × 12, remplissage dessiné selon le pourcentage).
Row {
    id: root

    property date now
    property int batteryPercent: 0

    spacing: 12

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: F.clock(root.now)
        color: IdleTheme.textPrimary
        font.family: IdleTheme.fontFamily
        font.pixelSize: IdleTheme.topClock.size
        font.weight: IdleTheme.topClock.weight
        font.features: { "tnum": 1 }
    }
    // Cadre 27 × 13 (viewBox du SVG) ramené à 25 × 12 : échelle uniforme 12/13, centré.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 25; height: 12
        visible: root.batteryPercent >= 0
        Item {
            x: (25 - 27 * 12 / 13) / 2
            width: 27; height: 13
            scale: 12 / 13
            transformOrigin: Item.TopLeft
            Image {
                anchors.fill: parent
                source: "../assets/icons/battery_frame.svg"
                sourceSize: Qt.size(27 * 2 * IdleTheme.scale, 13 * 2 * IdleTheme.scale)
            }
            Rectangle {
                x: 2; y: 2; height: 9
                width: 20 * Math.max(0, Math.min(100, root.batteryPercent)) / 100
                radius: 2
                color: IdleTheme.textPrimary
            }
        }
    }
}
