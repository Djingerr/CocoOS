import QtQuick

// Demande de confirmation, dans un panneau qui glisse depuis la droite comme celui
// des options : un titre, un message, deux choix (Annuler en premier et par défaut :
// le choix sûr). Haut / bas (ou gauche / droite) choisissent, A valide, B annule.
// Avec `actions`, c'est un menu : autant de choix que d'actions, A émet chosen(key).
// Remplit son parent et se dessine, comme LaunchScreen, sur le canevas mis à
// l'échelle. Aucune dépendance Moonlight.
FocusScope {
    id: root

    property string title: ""
    property string message: ""
    property string confirmLabel: qsTr("Confirmer")
    property string cancelLabel: qsTr("Annuler")

    // Menu : [{ label, key }] à la place d'Annuler / Confirmer.
    property var actions: []

    signal confirmed()
    signal chosen(string key)
    signal closed()

    property bool opened: false
    // Choix en focus ; sans `actions` : 0 = annuler, 1 = confirmer.
    property int focusedButton: 0
    readonly property var labels: actions.length > 0 ? actions.map(function(a) { return a.label })
                                                     : [cancelLabel, confirmLabel]
    // 0 = fermé, 1 = ouvert ; le panneau et le voile en découlent.
    property real reveal: opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.sheetSlide; easing.type: Theme.easeQuint } }

    visible: opened || reveal > 0

    function open() {
        focusedButton = 0
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

    function activate() {
        if (actions.length > 0) {
            opened = false
            Sounds.play("select")
            chosen(actions[focusedButton].key)
            closed()
        } else if (focusedButton === 1) {
            opened = false
            Sounds.play("select")
            confirmed()
            closed()
        } else {
            close()
        }
    }

    function step(dir) {
        var next = focusedButton + dir
        if (next < 0 || next >= labels.length) {
            Sounds.play("edge")
            return
        }
        focusedButton = next
        Sounds.play("move")
    }

    // Modal : rien ne traverse vers l'écran du dessous.
    Keys.onPressed: function(event) {
        event.accepted = true
        if (!opened) return
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Left:
            step(-1)
            break
        case Qt.Key_Down:
        case Qt.Key_Right:
            step(1)
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!event.isAutoRepeat) activate()
            break
        case Qt.Key_Escape:
            if (!event.isAutoRepeat) close()
            break
        }
    }

    Item {
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        // --- Voile sur le reste de l'écran ---
        Rectangle {
            anchors.fill: parent
            color: Theme.background
            opacity: root.opened ? Theme.sheetDim : 0
            Behavior on opacity { NumberAnimation { duration: Theme.sheetDimFade } }
            MouseArea { anchors.fill: parent; enabled: root.opened; onClicked: root.close() }
        }

        // --- Panneau ---
        Rectangle {
            id: panel
            // Fermé, il attend juste au-delà du bord droit.
            x: parent.width - width * root.reveal + width * 0.04 * (1 - root.reveal)
            width: Theme.sheetWidth; height: parent.height
            color: Theme.sheetFill

            Rectangle { x: -1; width: 1; height: parent.height; color: Theme.sheetEdge }
            MouseArea { anchors.fill: parent }   // un clic dans le panneau ne le referme pas

            Text {
                id: title
                x: Theme.sheetPadSide; y: Theme.sheetPadTop
                width: panel.width - 2 * Theme.sheetPadSide
                text: root.title
                color: Theme.ink
                wrapMode: Text.WordWrap
                font.family: Theme.fontUi; font.pixelSize: Theme.sheetTitleSize; font.weight: Font.DemiBold
                font.letterSpacing: Theme.sheetTitleSpacing
            }
            Text {
                id: message
                x: Theme.sheetPadSide
                y: title.y + title.height + Theme.dialogMessageTop
                width: title.width
                height: text !== "" ? implicitHeight : 0
                text: root.message
                color: Theme.ink2
                wrapMode: Text.WordWrap
                lineHeight: Theme.dialogMessageLineHeight
                font.family: Theme.fontUi; font.pixelSize: Theme.dialogMessageSize
            }

            Item {
                id: choices
                x: Theme.sheetPadSide
                y: message.y + message.height + Theme.dialogChoicesTop
                width: title.width

                Rectangle {
                    x: -Theme.sheetFocusOutset
                    y: root.focusedButton * Theme.sheetRowHeight
                    width: parent.width + 2 * Theme.sheetFocusOutset
                    height: Theme.sheetRowHeight
                    radius: Theme.sheetFocusRadius
                    color: Theme.sheetFocusFill
                    Behavior on y {
                        enabled: root.opened
                        NumberAnimation { duration: Theme.sheetFocusMove; easing.type: Theme.easeOut }
                    }
                }

                Repeater {
                    model: root.labels
                    Item {
                        readonly property bool focused: root.focusedButton === index
                        y: index * Theme.sheetRowHeight
                        width: choices.width; height: Theme.sheetRowHeight

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            color: parent.focused ? Theme.ink : Theme.ink2
                            font.family: Theme.fontUi; font.pixelSize: Theme.sheetLabelSize
                            Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }
                        }
                        ButtonGlyph {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.sheetHintRight
                            anchors.verticalCenter: parent.verticalCenter
                            label: "A"
                            ink: Theme.ink3
                            opacity: parent.focused ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.focusedButton = index
                                root.activate()
                            }
                        }
                    }
                }
            }

            ControllerLegend {
                x: Theme.sheetPadSide
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.sheetPadBottom
                hints: [ { glyph: "B", label: root.actions.length > 0 ? qsTr("Fermer") : root.cancelLabel },
                         { glyph: "A", label: qsTr("Valider") } ]
            }
        }
    }
}
