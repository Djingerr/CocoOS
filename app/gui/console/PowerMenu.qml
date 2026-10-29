import QtQuick
import QtQuick.Effects

// Menu d'alimentation (MenuAlimentation, MotionAlimentation) : carte centrée de verre, batterie
// et autonomie en tête, « Mise en veille », « Redémarrer », « Éteindre » en grandes pastilles,
// « Le stream en cours sera fermé proprement avant l'arrêt. » ; ◀ ▶ choisit, A confirme (Q7 :
// A suffit), B annule. La pastille « Maintenir le bouton » (en haut à droite) suit l'appui long
// sur la touche power : pleine, le menu s'ouvre. Sur le canevas ; présentation pure.
FocusScope {
    id: root

    property var actions: []             // "suspend", "reboot", "poweroff" (SystemStatus.powerActions)
    property string header: ""           // « Batterie 82 % · environ 3 h 10 » ; vide : masqué
    property bool opened: false
    property int current: 0
    property bool aDown: false

    signal chosen(string key)
    signal closed()

    readonly property var labels: ({ suspend: qsTr("Mise en veille"), reboot: qsTr("Redémarrer"), poweroff: qsTr("Éteindre") })
    readonly property var icons: ({ suspend: "power-moon", reboot: "power-reboot", poweroff: "power-off" })

    function open() {
        if (actions.length === 0) return
        current = 0
        aDown = false
        leaving = false
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    // `leaving` : une action part (la carte recule à 0,96 au lieu de 0,9).
    property bool leaving: false
    function close(leave) {
        if (!opened) return
        leaving = leave === true
        opened = false
        if (!leaving) Sounds.play("close")
        closed()
    }
    function move(delta) {
        var next = current + delta
        if (next < 0 || next >= actions.length) {
            Sounds.play("edge")
            return
        }
        current = next
        Sounds.play("move")
    }
    function confirm(index) {
        var key = actions[index]
        if (!key) return
        Sounds.play("select")
        close(true)
        chosen(key)
    }

    // --- Appui long sur la touche power : la pastille se remplit (1,2 s) ---
    property real hold: 0
    property bool holding: false
    function startHold() {
        holding = true
        holdDone = false
        holdFill.restart()
    }
    // Renvoie vrai si l'appui a été long (le menu est ouvert).
    function releaseHold() {
        holding = false
        holdFill.stop()
        var held = holdDone
        if (!held) hold = 0
        return held
    }
    property bool holdDone: false
    NumberAnimation {
        id: holdFill
        target: root; property: "hold"; from: 0; to: 1; duration: Theme.powerHold
        onFinished: { root.holdDone = true; root.open(); chipLinger.restart() }
    }
    Timer { id: chipLinger; interval: Theme.powerChipLinger; onTriggered: root.hold = 0 }

    enabled: opened || holding
    visible: reveal > 0 || chip.opacity > 0
    property real reveal: opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: root.opened ? Theme.powerIn : Theme.powerOut } }

    Keys.onPressed: function(event) {
        // Tout est avalé (l'accueil, dessous, ne réagit pas), sauf les raccourcis (Ctrl + Alt…).
        event.accepted = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
        if (event.isAutoRepeat) return
        if (event.key === Qt.Key_Left) move(-1)
        else if (event.key === Qt.Key_Right) move(1)
        else if (event.key === Qt.Key_Escape) close(false)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) aDown = true
    }
    Keys.onReleased: function(event) {
        event.accepted = true
        if (event.isAutoRepeat || event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter || !aDown) return
        aDown = false
        confirm(current)
    }

    // (l'accueil s'assombrit lui-même : HomeScreen.menuShown) ; un clic à côté : comme B.
    MouseArea { anchors.fill: parent; enabled: root.opened; onClicked: root.close(false) }

    Rectangle {
        id: card
        x: (parent.width - width) / 2
        y: Theme.powerTop
        width: Theme.powerWidth; height: Theme.powerHeight
        radius: Theme.powerRadius
        color: Theme.glassDialog
        border.color: Theme.hairline
        opacity: root.opened ? 1 : 0
        scale: root.opened || Theme.reducedMotion ? 1 : root.leaving ? Theme.powerLeaveScale : Theme.powerFrom
        Behavior on opacity { NumberAnimation { duration: root.opened ? Theme.powerFade : Theme.powerOut } }
        Behavior on scale {
            NumberAnimation {
                duration: root.opened ? Theme.powerSpring : Theme.powerShrink
                easing.type: Easing.BezierSpline; easing.bezierCurve: root.opened ? Theme.curveSpring : Theme.curveExit
            }
        }
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && opacity > 0
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: Theme.offlineShadow
            shadowVerticalOffset: Theme.offlineShadowY; shadowBlur: 1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.powerPadTop
            visible: root.header !== ""
            text: root.header.toUpperCase()
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.powerHeaderSize; font.weight: Font.DemiBold
            font.letterSpacing: 0.06 * Theme.powerHeaderSize
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.powerItemsTop
            spacing: Theme.powerGap
            Repeater {
                model: root.actions
                Item {
                    id: item
                    required property int index
                    required property string modelData
                    readonly property bool focused: root.current === index
                    width: Theme.powerItem; height: Theme.powerDisc + Theme.powerLabelGap + 20
                    Rectangle {
                        id: disc
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.powerDisc; height: width; radius: width / 2
                        color: item.focused ? Theme.ink : Theme.glassRaised
                        Behavior on color { ColorAnimation { duration: Theme.powerFocusFade } }
                        scale: item.focused ? (root.aDown || discMouse.pressed ? Theme.powerPress : Theme.powerDiscFocus) : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.aDown ? Theme.pressDuration : Theme.powerFocusMove
                                easing.type: Easing.BezierSpline; easing.bezierCurve: root.aDown ? Theme.curveOut : Theme.curvePowerFocus
                            }
                        }
                        Image {
                            anchors.centerIn: parent
                            width: Theme.powerIcon; height: width
                            source: "icons/" + root.icons[item.modelData] + ".svg"
                            sourceSize: Qt.size(width * Math.max(1, Theme.scale) * 2, height * Math.max(1, Theme.scale) * 2)
                            layer.enabled: true
                            layer.effect: MultiEffect { colorization: 1; colorizationColor: item.focused ? Theme.inkOnLight : Theme.ink }
                        }
                        HoverArea {
                            id: discMouse
                            anchors.fill: parent
                            onPointed: root.current = item.index
                            onClicked: root.confirm(item.index)
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.powerDisc + Theme.powerLabelGap
                        text: root.labels[item.modelData]
                        color: item.focused ? Theme.ink : Theme.powerLabelInk
                        Behavior on color { ColorAnimation { duration: Theme.powerFocusFade } }
                        font.family: Theme.fontUi; font.pixelSize: Theme.powerLabelSize
                        font.weight: item.focused ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.powerPadBottom
            text: qsTr("Le stream en cours sera fermé proprement avant l'arrêt.")
            color: Theme.powerNoteInk
            font.family: Theme.fontUi; font.pixelSize: Theme.powerNoteSize; font.weight: Font.Medium
        }
    }

    ControllerLegend {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.canvasHeight - Theme.legendBottomCoco - height
        opacity: root.reveal
        spacing: Theme.offlineLegendGap
        textSize: Theme.legendSizeCoco
        glyphGap: Theme.legendGlyphGapCoco
        pressing: root.aDown
        hints: [ { glyph: "◀▶", label: qsTr("Choisir") }, { glyph: "A", label: qsTr("Confirmer") },
                 { glyph: "B", label: qsTr("Annuler") } ]
        onTriggered: function(glyph) {
            if (glyph === "A") root.confirm(root.current)
            else if (glyph === "B") root.close(false)
        }
    }

    // « Maintenir le bouton » → « Menu d'alimentation » : l'anneau se remplit pendant l'appui.
    Rectangle {
        id: chip
        x: parent.width - Theme.powerChipRight - width
        y: Theme.powerChipTop - (shown ? 0 : Theme.powerChipShift)
        readonly property bool shown: root.holding || root.hold > 0
        width: chipRow.width + Theme.powerChipPadLeft + Theme.powerChipPadRight
        height: Theme.powerChipHeight
        radius: height / 2
        color: Theme.powerChipFill
        border.color: Theme.hairlineStrong
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.powerChipFade } }
        Behavior on y { NumberAnimation { duration: Theme.powerChipMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain } }
        Row {
            id: chipRow
            x: Theme.powerChipPadLeft
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.powerChipGap
            Item {
                width: Theme.powerChipRing; height: width
                LoaderRing {
                    anchors.fill: parent
                    stroke: Theme.powerChipStroke
                    track: Theme.powerChipTrack
                    spinning: false
                    fill: root.hold
                }
                Image {
                    anchors.centerIn: parent
                    width: Theme.powerChipIcon; height: width
                    source: "icons/power-off.svg"
                    sourceSize: Qt.size(width * Math.max(1, Theme.scale) * 2, height * Math.max(1, Theme.scale) * 2)
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.holdDone ? qsTr("Menu d'alimentation") : qsTr("Maintenir le bouton")
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.powerChipSize; font.weight: Font.DemiBold
            }
        }
    }
}
