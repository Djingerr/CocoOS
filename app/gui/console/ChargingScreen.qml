import QtQuick

// Recharge console éteinte (MotionRecharge) : au branchement du câble, l'écran s'allume un
// instant : un anneau qui se remplit jusqu'au niveau, l'éclair, « 42 % », « En charge · pleine
// dans environ 1 h 10 », puis tout s'éteint. Interface seule : le matériel (démarrage sur le
// câble, Q16) le déclenchera ; le harnais d'ici là (SystemDemo scene=charge).
Item {
    id: root

    property int level: 0                // %
    property string detail: ""           // « En charge · pleine dans environ 1 h 10 »
    property bool shown: false

    // Le câble est branché : l'écran s'allume, se remplit, puis s'éteint seul.
    function plug() {
        fill = 0
        shown = true
        fillAnim.restart()
        offTimer.restart()
    }
    property real fill: 0
    NumberAnimation {
        id: fillAnim
        target: root; property: "fill"; from: 0; to: root.level / 100
        duration: Theme.chargeFill; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
    }
    Timer { id: offTimer; interval: Theme.chargeShow; onTriggered: root.shown = false }

    visible: scene.opacity > 0
    Rectangle { anchors.fill: parent; color: Theme.background }

    Item {
        id: scene
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.shown ? Theme.chargeIn : Theme.chargeOut } }

        Item {
            id: ring
            x: (parent.width - width) / 2
            y: Theme.chargeRingTop
            width: Theme.chargeRing; height: width
            scale: root.shown || Theme.reducedMotion ? 1 : Theme.chargeFrom
            Behavior on scale { NumberAnimation { duration: root.shown ? Theme.chargeMove : Theme.chargeOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain } }
            Glow {
                anchors.centerIn: parent
                width: 2 * Theme.chargeRing; height: width
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                SequentialAnimation on opacity {
                    running: root.shown && !Theme.reducedMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.45; duration: Theme.chargeBreath / 2; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: Theme.chargeBreath / 2; easing.type: Easing.InOutSine }
                }
            }
            LoaderRing {
                anchors.fill: parent
                stroke: Theme.chargeStroke
                track: Theme.chargeTrack
                spinning: false
                fill: root.fill
            }
            Image {
                anchors.centerIn: parent
                width: Theme.chargeBolt.width; height: Theme.chargeBolt.height
                source: "icons/bolt.svg"
                sourceSize: Qt.size(width * Math.max(1, Theme.scale) * 2, height * Math.max(1, Theme.scale) * 2)
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: ring.y + ring.height + Theme.chargeTextTop
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("%1 %").arg(Math.round(root.fill * 100))
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.chargeLevelSize; font.weight: Font.DemiBold
                font.letterSpacing: -0.03 * Theme.chargeLevelSize
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.detail
                color: Theme.chargeDetailInk
                font.family: Theme.fontUi; font.pixelSize: Theme.chargeDetailSize; font.weight: Font.Medium
            }
        }
    }
}
