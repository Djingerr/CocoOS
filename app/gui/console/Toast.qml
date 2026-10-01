import QtQuick
import QtQuick.Effects

// Message bref, centré au-dessus de l'étagère (« .toast » du prototype) :
// show(texte), il s'efface seul. Aucune dépendance Moonlight.
Item {
    id: root

    property string text: ""
    property bool shown: false

    function show(message) {
        text = message
        shown = true
        hide.restart()
    }

    x: (parent.width - width) / 2
    y: Theme.toastTop + (shown ? 0 : Theme.toastShift)
    width: pill.width; height: pill.height
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.toastFade } }
    Behavior on y { NumberAnimation { duration: Theme.toastMove; easing.type: Theme.easeQuint } }

    Timer { id: hide; interval: Theme.toastDuration; onTriggered: root.shown = false }

    Rectangle {
        id: pill
        width: label.width + 2 * Theme.toastPadH
        height: label.height + 2 * Theme.toastPadV
        radius: height / 2
        color: Theme.toastFill
        border.width: 1
        border.color: Theme.toastStroke
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.toastShadow
            shadowVerticalOffset: Theme.toastShadowOffset
            blurMax: Theme.toastShadowBlur
            shadowBlur: 1
        }

        Text {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, Theme.toastMaxWidth - 2 * Theme.toastPadH)
            text: root.text
            elide: Text.ElideRight
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.toastSize
        }
    }
}
