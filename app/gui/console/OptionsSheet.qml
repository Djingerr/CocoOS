import QtQuick

// Panneau « Options » (bouton Y) : glisse depuis la droite pendant que le reste de
// l'écran s'assombrit. Des onglets (L1 / R1) ; haut / bas choisissent une ligne,
// gauche / droite (ou A) changent sa valeur, B ou Y referment. Aucune dépendance
// Moonlight.
//
// Le panneau ne garde aucun réglage : il affiche `tabs` et signale les choix
// (`changed`, `actionRequested`), à l'appelant d'appliquer la valeur et de mettre
// `tabs` à jour.
FocusScope {
    id: root

    // Onglets : [{ label, rows }]. Une ligne est un réglage { key, label, options:
    // [libellés], index }, ou une action { key, label, value, action: true } (A la
    // déclenche ; `value` est affichée à droite).
    property var tabs: []
    property int tab: 0
    readonly property var rows: tabs.length > 0 ? tabs[Math.min(tab, tabs.length - 1)].rows : []
    // PC hôte, rappelé sous le titre. S'il est connu, la dernière ligne du premier
    // onglet propose de l'oublier.
    property string hostName
    property bool connected: false

    signal changed(string key, int index)
    signal actionRequested(string key)
    signal forgetConfirmed()
    signal closed()

    property bool opened: false
    property int current: 0              // ligne en focus ; rows.length = « Oublier ce PC »
    property bool confirming: false      // « Oublier ce PC » attend sa confirmation
    property int direction: 1            // sens du dernier changement de valeur
    readonly property bool forgettable: tab === 0 && hostName !== ""
    readonly property int lineCount: rows.length + (forgettable ? 1 : 0)
    // 0 = fermé, 1 = ouvert ; le panneau et le voile en découlent.
    property real reveal: opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.sheetSlide; easing.type: Theme.easeQuint } }

    visible: reveal > 0 || dim.opacity > 0

    function open() {
        tab = 0
        current = 0
        confirming = false
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        pad.stop()
        opened = false
        confirming = false
        Sounds.play("close")
        closed()
    }

    function step(dir) {
        var next = current + dir
        if (next < 0 || next >= lineCount) {
            Sounds.play("edge")
            return
        }
        confirming = false
        current = next
        Sounds.play("move")
    }
    // L1 / R1 : onglet voisin, la première ligne en focus.
    function switchTab(dir) {
        var next = tab + dir
        if (next < 0 || next >= tabs.length) {
            Sounds.play("edge")
            return
        }
        tab = next
        current = 0
        confirming = false
        Sounds.play("move")
    }
    // Gauche / droite : valeur voisine, bute aux extrémités. A : valeur suivante, en boucle.
    function change(dir, wrap) {
        if (current >= rows.length) return
        var row = rows[current]
        if (row.action) {
            if (wrap) {
                Sounds.play("select")
                actionRequested(row.key)
            } else {
                Sounds.play("edge")
            }
            return
        }
        var next = wrap ? (row.index + 1) % row.options.length : row.index + dir
        if (next < 0 || next >= row.options.length) {
            Sounds.play("edge")
            return
        }
        direction = dir
        Sounds.play("tick")
        changed(row.key, next)
    }
    function activate() {
        if (current < rows.length) {
            change(1, true)
        } else if (!confirming) {
            confirming = true
            Sounds.play("tick")
        } else {
            confirming = false
            Sounds.play("select")
            forgetConfirmed()
        }
    }

    PadRepeat {
        id: pad
        keys: [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right]
        onTriggered: function(key) {
            if (key === Qt.Key_Up) root.step(-1)
            else if (key === Qt.Key_Down) root.step(1)
            else root.change(key === Qt.Key_Left ? -1 : 1, false)
        }
    }
    Keys.onPressed: function(event) {
        if (pad.press(event)) return
        event.accepted = true    // panneau ouvert : rien ne traverse vers l'accueil
        if (event.isAutoRepeat) return
        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Hangup:
        case Qt.Key_Menu:
            close()
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate()
            break
        case Qt.Key_PageUp:          // L1 / R1 au clavier
        case Qt.Key_PageDown:
            switchTab(event.key === Qt.Key_PageUp ? -1 : 1)
            break
        }
    }
    Keys.onReleased: function(event) { pad.release(event) }
    onActiveFocusChanged: if (!activeFocus) pad.stop()

    // Pointe de chevron (‹ ou ›) : deux traits arrondis qui partent de la pointe.
    // Tracé de l'icône 16 × 16 du prototype, rendue à 14 px au centre de sa case.
    component Chevron: Item {
        id: chevron
        property int dir: 1                      // -1 : ‹ ; +1 : ›
        readonly property real stroke: 1.575
        readonly property real arm: 5.57

        width: Theme.sheetChevronSize; height: width
        Repeater {
            model: [-1, 1]
            Rectangle {
                x: (chevron.dir < 0 ? 6.81 : 11.19) - chevron.stroke / 2
                y: 9 - chevron.stroke / 2
                width: chevron.arm + chevron.stroke; height: chevron.stroke
                radius: height / 2
                color: Theme.ink3
                antialiasing: true
                transform: Rotation {
                    origin.x: chevron.stroke / 2; origin.y: chevron.stroke / 2
                    angle: chevron.dir < 0 ? 45 * modelData : 180 - 45 * modelData
                }
            }
        }
    }

    component ValueText: Item {
        id: slot
        property string value
        property color color: Theme.ink2

        width: Theme.sheetValueBox.width; height: Theme.sheetValueBox.height
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: slot.value
            color: slot.color
            font.family: Theme.fontUi; font.pixelSize: Theme.sheetValueSize
        }
    }

    // --- Voile sur le reste de l'écran ---
    Rectangle {
        id: dim
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
        x: root.width - width * root.reveal + width * 0.04 * (1 - root.reveal)
        width: Theme.sheetWidth; height: root.height
        color: Theme.sheetFill

        Rectangle { x: -1; width: 1; height: parent.height; color: Theme.sheetEdge }
        MouseArea { anchors.fill: parent }   // un clic dans le panneau ne le referme pas

        Text {
            id: title
            x: Theme.sheetPadSide; y: Theme.sheetPadTop
            text: qsTr("Options")
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.sheetTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: Theme.sheetTitleSpacing
        }
        Row {
            id: host
            x: Theme.sheetPadSide
            y: title.y + title.height + Theme.sheetHostTop
            height: hostLabel.height
            spacing: Theme.sheetHostGap
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hostName !== ""
                width: Theme.hostDotSize; height: width; radius: width / 2
                color: root.connected ? Theme.ok : Theme.accent
            }
            Text {
                id: hostLabel
                text: root.hostName
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.sheetHostSize
            }
        }

        // Onglets : [L1] Flux  Console [R1]
        Row {
            id: tabStrip
            x: Theme.sheetPadSide
            y: host.y + host.height + Theme.sheetTabsTop
            spacing: Theme.sheetTabGap
            visible: root.tabs.length > 1

            ButtonGlyph { anchors.verticalCenter: parent.verticalCenter; label: "LB"; ink: Theme.ink3 }
            Repeater {
                model: root.tabs
                Item {
                    readonly property bool active: index === root.tab
                    anchors.verticalCenter: parent.verticalCenter
                    width: tabLabel.width; height: Theme.sheetTabHeight
                    Text {
                        id: tabLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.active ? Theme.ink : Theme.ink3
                        font.family: Theme.fontUi; font.pixelSize: Theme.sheetTabSize
                        font.weight: parent.active ? Font.DemiBold : Font.Medium
                        Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: Theme.underlineHeight; radius: Theme.underlineRadius
                        color: Theme.accent
                        opacity: parent.active ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.switchTab(index - root.tab) }
                }
            }
            ButtonGlyph { anchors.verticalCenter: parent.verticalCenter; label: "RB"; ink: Theme.ink3 }
        }

        Item {
            id: list
            x: Theme.sheetPadSide
            y: (tabStrip.visible ? tabStrip.y + tabStrip.height : host.y + host.height) + Theme.sheetRowsTop
            width: panel.width - 2 * Theme.sheetPadSide

            Rectangle {
                x: -Theme.sheetFocusOutset
                y: root.current * Theme.sheetRowHeight
                width: parent.width + 2 * Theme.sheetFocusOutset
                height: Theme.sheetRowHeight
                radius: Theme.sheetFocusRadius
                color: Theme.sheetFocusFill
                Behavior on y {
                    enabled: root.opened
                    NumberAnimation { duration: Theme.sheetFocusMove; easing.type: Theme.easeOut }
                }
            }

            // Un délégué par ligne, conservé quand `rows` est remplacé : c'est ce qui
            // permet à la valeur de glisser de l'ancienne à la nouvelle.
            Repeater {
                model: root.rows.length
                Item {
                    id: line
                    required property int index
                    readonly property var row: root.rows[index] || ({ label: "", options: [""], index: 0 })
                    readonly property bool focused: root.current === index
                    readonly property color ink: focused ? Theme.ink : Theme.ink2

                    y: index * Theme.sheetRowHeight
                    width: list.width; height: Theme.sheetRowHeight

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - value.width - Theme.sheetRowGap
                        text: line.row.label
                        color: line.ink
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontUi; font.pixelSize: Theme.sheetLabelSize
                        Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }
                    }
                    Row {
                        id: value
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sheetValueGap

                        Chevron {
                            dir: -1
                            opacity: line.focused && !line.row.action ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                        }
                        SwapBox {
                            width: Theme.sheetValueBox.width; height: Theme.sheetValueBox.height
                            axis: "x"
                            distance: Theme.sheetValueTravel
                            duration: Theme.sheetValueSwap
                            direction: root.direction
                            animated: root.opened
                            key: line.row.action ? (line.row.value || "") : (line.row.options[line.row.index] || "")
                            value: key

                            ValueText { color: line.ink }
                            ValueText { color: line.ink }
                        }
                        Chevron {
                            dir: 1
                            opacity: line.focused ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.sheetFocusFade } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (line.focused) {
                                root.change(1, true)
                            } else {
                                root.confirming = false
                                root.current = line.index
                                Sounds.play("move")
                            }
                        }
                    }
                }
            }

            // « Oublier ce PC » : une première pression demande confirmation.
            Item {
                readonly property bool focused: root.current === root.rows.length
                visible: root.forgettable
                y: root.rows.length * Theme.sheetRowHeight
                width: list.width; height: Theme.sheetRowHeight

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.confirming ? qsTr("Confirmer : oublier %1 ?").arg(root.hostName)
                                          : qsTr("Oublier ce PC")
                    color: root.confirming ? Theme.accent : parent.focused ? Theme.ink : Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: Theme.sheetLabelSize
                    Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }
                }
                ButtonGlyph {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sheetHintRight
                    anchors.verticalCenter: parent.verticalCenter
                    label: "A"
                    ink: Theme.ink3
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (parent.focused) {
                            root.activate()
                        } else {
                            root.current = root.rows.length
                            Sounds.play("move")
                        }
                    }
                }
            }
        }

        ControllerLegend {
            x: Theme.sheetPadSide
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.sheetPadBottom
            hints: [ { glyph: "B", label: qsTr("Fermer") }, { glyph: "A", label: qsTr("Changer") } ]
        }
    }
}
