import QtQuick

// Demande de confirmation, dans un panneau qui glisse depuis la droite comme celui
// des options : un titre, un message, deux choix (Annuler en premier et par défaut :
// le choix sûr). Haut / bas (ou gauche / droite) choisissent, A valide, B annule.
// Avec `actions`, c'est un menu : autant de choix que d'actions, A émet chosen(key).
// `holdToConfirm` : confirmer une action destructive demande de maintenir A (HoldFill).
// Remplit son parent et se dessine, comme LaunchScreen, sur le canevas mis à
// l'échelle. Aucune dépendance Moonlight.
FocusScope {
    id: root

    property string title: ""
    property string message: ""
    property string confirmLabel: qsTr("Confirmer")
    property string cancelLabel: qsTr("Annuler")
    property bool holdToConfirm: false
    property string doneLabel                // une fois l'appui maintenu au bout (« Extinction »…)

    // Menu : [{ label, key }] à la place d'Annuler / Confirmer.
    property var actions: []

    signal confirmed()
    signal chosen(string key)
    signal closed()

    property bool opened: false
    // Choix en focus ; sans `actions` : 0 = annuler, 1 = confirmer.
    property int focusedButton: 0
    // A enfoncé : le choix en focus s'écrase (Pressable) ; A valide au relâché.
    property bool pressing: false
    readonly property var labels: actions.length > 0 ? actions.map(function(a) { return a.label })
                                                     : [cancelLabel, confirmLabel]
    // Choix à maintenir (A tenu) plutôt qu'à presser.
    readonly property var holds: actions.length > 0 ? actions.map(function(a) { return false })
                                                    : [false, holdToConfirm]
    readonly property bool holdFocused: holds[focusedButton] === true
    // 0 = fermé, 1 = ouvert ; le panneau et le voile en découlent.
    property real reveal: opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.sheetSlide; easing.type: Theme.easeQuint } }

    visible: opened || reveal > 0

    function open() {
        focusedButton = 0
        pressing = false
        holdFill.reset()
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }

    function close() {
        if (!opened) return
        opened = false
        pressing = false
        Sounds.play("close")
        closed()
    }

    // `silent` : le son est déjà joué (« confirm » d'un appui maintenu).
    function activate(silent) {
        if (actions.length > 0) {
            opened = false
            Sounds.play("select")
            chosen(actions[focusedButton].key)
            closed()
        } else if (focusedButton === 1) {
            opened = false
            if (!silent) Sounds.play("select")
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
        moveTo(next)
    }
    function moveTo(next) {
        focusedButton = next
        pressing = false
        holdFill.reset()
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
            if (!event.isAutoRepeat) pressing = true
            break
        case Qt.Key_Escape:
            if (!event.isAutoRepeat) close()
            break
        }
    }
    // Seul un appui fait ici valide : le relâché d'un A qui a ouvert ce panneau ne fait rien.
    Keys.onReleased: function(event) {
        event.accepted = true
        if (pressing && !event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            pressing = false
            if (!holdFocused) activate()            // (un choix à maintenir se vide s'il est lâché trop tôt)
        }
    }
    onActiveFocusChanged: if (!activeFocus) pressing = false

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

                Pressable {
                    id: highlight
                    x: -Theme.sheetFocusOutset
                    y: root.focusedButton * Theme.sheetRowHeight
                    width: parent.width + 2 * Theme.sheetFocusOutset
                    height: Theme.sheetRowHeight
                    down: root.pressing
                    downScale: Theme.pressRowScale
                    Behavior on y {
                        enabled: root.opened
                        NumberAnimation { duration: Theme.sheetFocusMove; easing.type: Theme.easeOut }
                    }
                    Rectangle { anchors.fill: parent; radius: Theme.sheetFocusRadius; color: Theme.sheetFocusFill }
                }

                Repeater {
                    model: root.labels
                    Pressable {
                        readonly property bool focused: root.focusedButton === index
                        down: root.pressing && focused
                        downScale: Theme.pressRowScale
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
                        // À la souris comme à la manette : on survole, on presse, on relâche (ou
                        // on maintient).
                        HoverArea {
                            anchors.fill: parent
                            onPointed: if (!root.pressing && root.focusedButton !== index) root.moveTo(index)
                            onPressed: { root.focusedButton = index; root.pressing = true }
                            onReleased: {
                                if (!root.pressing) return
                                root.pressing = false
                                if (containsMouse && !root.holdFocused) root.activate()
                            }
                            onCanceled: root.pressing = false
                        }
                    }
                }
                // Choix à maintenir : le remplissage, par-dessus la ligne et son surlignage
                // (dont il suit l'écrasement).
                Item {
                    x: highlight.x; y: highlight.y
                    width: highlight.width; height: highlight.height
                    scale: highlight.scale
                    visible: root.holdFocused
                    HoldFill {
                        id: holdFill
                        anchors.fill: parent
                        holding: root.pressing && root.holdFocused
                        label: root.labels[root.focusedButton] || ""
                        doneLabel: root.doneLabel
                        labelX: Theme.sheetFocusOutset
                        radius: Theme.sheetFocusRadius
                        onCompleted: root.activate(true)
                    }
                }
            }

            ControllerLegend {
                x: Theme.sheetPadSide
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.sheetPadBottom
                hints: [ { glyph: "B", label: root.actions.length > 0 ? qsTr("Fermer") : root.cancelLabel },
                         { glyph: "A", label: root.holdFocused ? qsTr("Maintenir") : qsTr("Valider") } ]
                onTriggered: function(glyph) {
                    if (glyph === "B") root.close()
                    else if (!root.holdFocused) root.activate()   // (un choix à maintenir se maintient)
                }
            }
        }
    }
}
