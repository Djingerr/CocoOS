import QtQuick

// Barre haute : pastille d'état du PC hôte (gauche), horloge / Wi-Fi / batterie
// (droite). Occupe toute la largeur en haut de l'écran ; aucune dépendance Moonlight.
Item {
    id: root

    property string hostName: ""
    property bool connected: false
    // -1 = pas de donnée → élément masqué (jamais de fausse jauge).
    property int latencyMs: -1
    property int signalStrength: -1      // 0 à 4
    property int batteryPercent: -1      // 0 à 100
    property bool charging: false        // éclair à côté de la batterie
    // Horloge, Wi-Fi et batterie : masqués sous un panneau latéral (il est translucide).
    property bool systemShown: true
    // Heure affichée : l'horloge système, sauf si on lui assigne un texte fixe.
    property string timeText: Qt.formatTime(clock.now, "HH:mm")

    implicitHeight: Theme.topBarY + Theme.topBarHeight

    Timer {
        id: clock
        property date now: new Date()
        interval: 1000; running: true; repeat: true
        onTriggered: now = new Date()
    }

    Item {
        x: Theme.margin; y: Theme.topBarY
        width: root.width - 2 * Theme.margin
        height: Theme.topBarHeight

        // --- Pastille de l'hôte ---
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.hostPillPadLeft + pillRow.width + Theme.hostPillPadRight
            height: hostLabel.height + 2 * Theme.hostPillPadV
            radius: height / 2
            color: Theme.hostPillFill

            // Filet posé PAR-DESSUS le fond (une bordure de Rectangle le remplacerait).
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.hostPillStroke
            }

            Row {
                id: pillRow
                x: Theme.hostPillPadLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.hostPillGap

                // Point d'état : orange clignotant pendant la connexion, vert fixe ensuite.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.hostDotSize; height: width; radius: width / 2
                    color: root.connected ? Theme.ok : Theme.accent
                    opacity: root.connected ? 1 : blink
                    property real blink: 1
                    SequentialAnimation on blink {
                        running: !root.connected
                        loops: Animation.Infinite
                        NumberAnimation { to: Theme.hostDotBlinkMin; duration: Theme.hostDotBlink / 2; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: Theme.hostDotBlink / 2; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    id: hostLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hostName
                    color: Theme.ink
                    font.family: Theme.fontUi; font.pixelSize: Theme.hostNameSize; font.weight: Font.Medium
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: !root.connected ? qsTr("connexion…")
                        : root.latencyMs >= 0 ? qsTr("%1 ms").arg(root.latencyMs) : ""
                    color: Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: Theme.hostDetailSize
                    font.features: { "tnum": 1 }
                }
            }
        }

        // --- Horloge, Wi-Fi, batterie ---
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sysGap
            opacity: root.systemShown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.sheetDimFade } }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.timeText
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.clockSize; font.weight: Font.Medium
            }

            // Wi-Fi : un point et trois arcs, allumés selon signalStrength (1 à 4).
            // Tracé sur la grille 24 × 24 de l'icône du prototype : arcs de centre
            // (12, 19.2), trait de 2, soit des anneaux dont on ne garde que le haut.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.signalStrength >= 0
                width: Theme.wifiSize; height: Theme.wifiSize

                Item {
                    width: 24; height: 24
                    scale: Theme.wifiSize / 24
                    transformOrigin: Item.TopLeft

                    Rectangle {
                        x: 10.7; y: 18; width: 2.6; height: 2.6; radius: 1.3
                        color: root.signalStrength >= 1 ? Theme.ink : Theme.inkOff
                    }
                    Repeater {
                        // r : rayon de l'arc ; end : ordonnée de ses extrémités
                        model: [ { r: 4.4, end: 16 }, { r: 9, end: 12.6 }, { r: 13.5, end: 9.2 } ]
                        Item {
                            x: 11 - modelData.r; y: 18.2 - modelData.r
                            width: 2 * modelData.r + 2; height: modelData.end + 0.7 - y
                            clip: true
                            Rectangle {
                                width: parent.width; height: width; radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: root.signalStrength >= index + 2 ? Theme.ink : Theme.inkOff
                            }
                        }
                    }
                }
            }

            // Batterie : éclair pendant la charge ; orange quand elle est faible.
            Row {
                id: battery
                anchors.verticalCenter: parent.verticalCenter
                visible: root.batteryPercent >= 0
                spacing: Theme.boltGap
                readonly property color ink: !root.charging && root.batteryPercent < Theme.batteryLow
                                             ? Theme.accent : Theme.ink
                readonly property real unit: Theme.batterySize.height / 16

                // Éclair : trois traits arrondis sur une grille 10 × 16.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.charging
                    width: 10 * battery.unit; height: 16 * battery.unit

                    Item {
                        width: 10; height: 16
                        scale: battery.unit
                        transformOrigin: Item.TopLeft
                        Repeater {
                            // [x1, y1, x2, y2]
                            model: [ [7, 1, 3, 8.6], [3, 8.6, 7, 7.4], [7, 7.4, 3, 15] ]
                            Rectangle {
                                readonly property real dx: modelData[2] - modelData[0]
                                readonly property real dy: modelData[3] - modelData[1]
                                x: modelData[0] - Theme.boltStroke / 2
                                y: modelData[1] - Theme.boltStroke / 2
                                width: Math.sqrt(dx * dx + dy * dy) + Theme.boltStroke
                                height: Theme.boltStroke
                                radius: height / 2
                                color: battery.ink
                                antialiasing: true
                                transform: Rotation {
                                    origin.x: Theme.boltStroke / 2; origin.y: Theme.boltStroke / 2
                                    angle: Math.atan2(dy, dx) * 180 / Math.PI
                                }
                            }
                        }
                    }
                }

                // Contour, borne et niveau, sur la grille 30 × 16 de l'icône.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.batterySize.width; height: Theme.batterySize.height

                    Item {
                        anchors.centerIn: parent
                        width: 30; height: 16
                        scale: battery.unit

                        Rectangle {
                            x: 0.2; y: 0.2; width: 26.1; height: 15.6; radius: 4.3
                            color: "transparent"
                            border.width: 1.6; border.color: battery.ink
                            border.pixelAligned: false
                        }
                        Rectangle { x: 27; y: 5.5; width: 2; height: 5; radius: 1; color: battery.ink }
                        Rectangle {
                            x: 3.5; y: 3.5; height: 9; radius: 1.6
                            width: 19.5 * Math.max(0, Math.min(100, root.batteryPercent)) / 100
                            color: battery.ink
                        }
                    }
                }
            }
        }
    }
}
