import QtQuick

// Nombre dont chaque chiffre roule dans sa colonne 0–9 (ressort « vif »), en chiffres
// tabulaires de Sora, suivi d'un suffixe (« % », « Mb/s »). `digits` colonnes toujours
// là : un chiffre de tête absent s'efface sans rien décaler (à aligner à droite).
// Aucune dépendance Moonlight.
Row {
    id: root

    property int value: 0
    property int digits: 1
    property string suffix
    property color color: Theme.ink2
    property int pixelSize: Theme.sheetValueSize

    FontMetrics {
        id: metrics
        font.family: Theme.fontUi; font.pixelSize: root.pixelSize; font.features: { "tnum": 1 }
    }

    Repeater {
        model: root.digits
        Item {
            readonly property int power: Math.pow(10, root.digits - 1 - index)
            width: metrics.advanceWidth("0"); height: metrics.height
            clip: true
            opacity: index < root.digits - 1 && root.value < power ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.rollFade
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
            Text {
                y: -(Math.floor(root.value / parent.power) % 10) * parent.height
                text: "0\n1\n2\n3\n4\n5\n6\n7\n8\n9"
                lineHeightMode: Text.FixedHeight; lineHeight: parent.height
                color: root.color
                font.family: Theme.fontUi; font.pixelSize: root.pixelSize; font.features: { "tnum": 1 }
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.springSnappy.duration
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                    }
                }
            }
        }
    }
    Text {
        text: root.suffix
        color: root.color
        font.family: Theme.fontUi; font.pixelSize: root.pixelSize; font.features: { "tnum": 1 }
    }
}
