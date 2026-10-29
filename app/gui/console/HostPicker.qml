import QtQuick
import QtQuick.Effects

// Choix du PC (ChoixPC) : un menu de verre sous la pastille du PC, « Jouer depuis » : les PC
// appairés (connecté et coché, en veille avec « Réveiller », introuvable), puis « Ajouter un
// PC » ; l'accueil s'assombrit derrière. A bascule, B ferme. Présentation pure, sur le canevas.
// hosts : [{ name, state: "connected" | "online" | "asleep" | "missing", detail, current }]
FocusScope {
    id: root

    property var hosts: []
    property bool opened: false
    property int current: 0              // ligne qui a la manette ; hosts.length : « Ajouter un PC »
    property bool aDown: false

    signal chosen(int index)
    signal addRequested()
    signal closed()

    readonly property int count: hosts.length + 1

    function open(index) {
        current = Math.max(0, Math.min(index, count - 1))
        aDown = false
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        opened = false
        Sounds.play("close")
        closed()
    }
    function move(delta) {
        var next = current + delta
        if (next < 0 || next >= count) {
            Sounds.play("edge")
            return
        }
        current = next
        Sounds.play("move")
    }
    function activate(index) {
        if (index < hosts.length) chosen(index)
        else addRequested()
    }
    function refuse() { addRow.refuse() }

    enabled: opened
    visible: reveal > 0
    property real reveal: opened ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: Theme.reducedMotion ? Theme.reducedSpring.duration : root.opened ? Theme.pickerIn : Theme.pickerOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.opened && !Theme.reducedMotion ? Theme.curveSpring : Theme.curveMain
        }
    }

    Keys.onPressed: function(event) {
        event.accepted = true                 // rien n'atteint l'accueil
        if (event.isAutoRepeat) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) aDown = true
        else if (event.key === Qt.Key_Up) move(-1)
        else if (event.key === Qt.Key_Down) move(1)
        else if (event.key === Qt.Key_Escape) close()
    }
    Keys.onReleased: function(event) {
        event.accepted = true
        if (event.isAutoRepeat || event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter || !aDown) return
        aDown = false
        activate(current)
    }

    // (l'accueil s'assombrit lui-même, sous sa barre haute : HomeScreen.hostPickerOpen) ; un clic
    // à côté ferme.
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: card
        x: parent.width - Theme.pickerRight - width
        y: Theme.pickerTop
        width: Theme.pickerWidth
        height: list.height
        radius: Theme.pickerRadius
        color: Theme.glassDialog
        border.color: Theme.hairline
        opacity: Math.min(1, root.reveal)
        scale: Theme.reducedMotion ? 1 : Theme.pickerFrom + (1 - Theme.pickerFrom) * root.reveal
        transformOrigin: Item.TopRight
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.offlineShadow
            shadowVerticalOffset: Theme.offlineShadowY
            shadowBlur: 1
        }

        Column {
            id: list
            width: parent.width

            Text {
                width: parent.width
                topPadding: Theme.pickerHeaderTop; bottomPadding: Theme.pickerHeaderBottom
                leftPadding: Theme.pickerHeaderLeft
                text: qsTr("Jouer depuis").toUpperCase()
                color: Theme.ink3
                font.family: Theme.fontUi; font.pixelSize: Theme.pickerHeaderSize; font.weight: Font.DemiBold
                font.letterSpacing: 0.06 * Theme.pickerHeaderSize
            }

            Repeater {
                model: root.hosts
                Column {
                    id: hostRow
                    required property int index
                    required property var modelData
                    readonly property bool focused: root.current === index
                    width: list.width
                    Pressable {
                        width: parent.width; height: Theme.pickerRowHeight
                        down: hostRow.focused && root.aDown || rowMouse.pressed
                        downScale: Theme.pressRowScale
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.pickerFocus
                            opacity: hostRow.focused ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.hoverFade } }
                        }
                        Rectangle {
                            x: Theme.pickerPad
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.pickerDot; height: width; radius: width / 2
                            color: hostRow.modelData.state === "asleep" ? Theme.hostDotAsleep
                                 : hostRow.modelData.state === "missing" ? Theme.danger : Theme.accent
                        }
                        Column {
                            x: Theme.pickerPad + Theme.pickerDot + Theme.pickerGap
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.pickerLineGap
                            Text {
                                text: hostRow.modelData.name
                                color: Theme.ink
                                font.family: Theme.fontUi; font.pixelSize: Theme.pickerNameSize
                                font.weight: hostRow.focused ? Font.DemiBold : Font.Medium
                            }
                            Text {
                                text: hostRow.modelData.detail
                                color: Theme.hostDetailInk
                                font.family: Theme.fontUi; font.pixelSize: Theme.pickerDetailSize; font.weight: Font.Medium
                            }
                        }
                        // À droite : la coche du PC en cours, « Réveiller » pour un PC en veille.
                        CheckMark {
                            anchors.right: parent.right; anchors.rightMargin: Theme.pickerPad
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.pickerCheck; height: width
                            visible: hostRow.modelData.current === true
                            checked: root.opened
                            drawDelay: 0
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: Theme.pickerPad
                            anchors.verticalCenter: parent.verticalCenter
                            visible: hostRow.modelData.state === "asleep" && hostRow.modelData.current !== true
                            text: qsTr("Réveiller")
                            color: Theme.ink2
                            font.family: Theme.fontUi; font.pixelSize: Theme.pickerDetailSize; font.weight: Font.DemiBold
                        }
                        HoverArea {
                            id: rowMouse
                            anchors.fill: parent
                            onPointed: root.current = hostRow.index
                            onClicked: root.activate(hostRow.index)
                        }
                    }
                    Rectangle {
                        x: Theme.pickerSeparatorLeft
                        width: parent.width - x; height: 1
                        color: Theme.hairline
                    }
                }
            }

            // « + Ajouter un PC »
            Pressable {
                id: addRow
                readonly property bool focused: root.current === root.hosts.length
                width: parent.width; height: Theme.pickerAddHeight
                down: focused && root.aDown || addMouse.pressed
                downScale: Theme.pressRowScale
                Rectangle {
                    anchors.fill: parent
                    color: Theme.pickerFocus
                    bottomLeftRadius: Theme.pickerRadius; bottomRightRadius: Theme.pickerRadius
                    opacity: addRow.focused ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.hoverFade } }
                }
                Row {
                    x: Theme.pickerPad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.pickerGap
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.pickerPlus; height: width
                        source: "icons/plus.svg"
                        sourceSize: Qt.size(width * Math.max(1, Theme.scale) * 2, height * Math.max(1, Theme.scale) * 2)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Ajouter un PC")
                        color: Theme.ink
                        font.family: Theme.fontUi; font.pixelSize: Theme.pickerNameSize; font.weight: Font.Medium
                    }
                }
                HoverArea {
                    id: addMouse
                    anchors.fill: parent
                    onPointed: root.current = root.hosts.length
                    onClicked: root.activate(root.hosts.length)
                }
            }
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
        hints: [ { glyph: "A", label: qsTr("Basculer") }, { glyph: "B", label: qsTr("Fermer") } ]
        onTriggered: function(glyph) {
            if (glyph === "A") root.activate(root.current)
            else if (glyph === "B") root.close()
        }
    }
}
