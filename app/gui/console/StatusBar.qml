import QtQuick
import "Format.js" as Format

// Barre haute : logotype et pastille d'état du PC hôte (gauche), horloge / Wi-Fi /
// batterie (droite). Occupe toute la largeur en haut de l'écran ; aucune dépendance
// Moonlight. La pastille s'ouvre en île de notification pour un événement système
// (manette, batterie, PC perdu ou retrouvé, réseau mauvais), puis se referme seule.
// Wi-Fi, batterie et réglages se choisissent (focus : ← / →, A, bas ou B pour rendre la
// manette ; ou la souris) : l'icône choisie ouvre sa fiche sous la barre.
Item {
    id: root

    property string hostName: ""
    property bool connected: false
    // -1 = pas de donnée → élément masqué (jamais de fausse jauge).
    property int latencyMs: -1
    property int jitterMs: -1
    // Qualité du réseau vers le PC : la couleur du point d'état une fois connecté.
    readonly property string quality: Format.networkQuality(latencyMs, jitterMs)
    property int signalStrength: -1      // 0 à 4
    property int batteryPercent: -1      // 0 à 100
    property bool charging: false        // éclair à côté de la batterie
    property int controllerBattery: -1   // manette sans fil : 0 (vide) à 3 (pleine)
    // Le logotype, à gauche : cible de l'animation de démarrage, qui le masque le
    // temps de voler jusqu'à lui (BootSplash).
    readonly property alias logo: logo
    property bool logoShown: true
    // Pastille de l'hôte, horloge, Wi-Fi, batterie : en fondu à l'entrée de l'accueil.
    property bool contentShown: true
    property real contentOpacity: contentShown ? 1 : 0
    Behavior on contentOpacity {
        enabled: root.contentShown
        NumberAnimation { duration: Theme.entryTextFade; easing.type: Easing.OutCubic }
    }
    // Horloge, Wi-Fi et batterie : masqués sous un panneau latéral (il est translucide).
    property bool systemShown: true
    // Heure affichée : l'horloge système, sauf si on lui assigne un texte fixe.
    property string timeText: Qt.formatTime(clock.now, "HH:mm")

    // --- Icônes de droite : Wi-Fi, batterie, réglages ---
    property var wifi: ({})              // { ssid, strength, secured }
    property var batteryDetails: ({})    // { minutes, watts, status }
    property bool wifiChangeable: false  // A sur le Wi-Fi : la liste des réseaux
    signal activated(string key)         // A ou clic : "wifi", "settings" (la batterie n'a rien à faire)
    signal leaveRequested()              // bas ou B
    readonly property var keys: {
        var k = []
        if (signalStrength >= 0) k.push("wifi")
        if (batteryPercent >= 0) k.push("battery")
        k.push("settings")
        return k
    }
    property string selected: "settings"
    property bool aHeld: false
    property string hoveredKey: ""
    // La fiche ouverte : l'icône survolée, sinon celle qui a la manette.
    readonly property string cardKey: !systemShown || !contentShown ? ""
                                    : hoveredKey !== "" ? hoveredKey : activeFocus ? selected : ""
    onActiveFocusChanged: {
        aHeld = false
        if (keys.indexOf(selected) < 0) selected = "settings"
    }
    function move(dir) {
        var next = keys.indexOf(selected) + dir
        if (next < 0 || next >= keys.length) {
            Sounds.play("edge")
            return
        }
        aHeld = false
        selected = keys[next]
        Sounds.play("move")
    }
    function activate(key) {
        if (key === "battery" || key === "wifi" && !wifiChangeable) Sounds.play("edge")
        else activated(key)
    }
    // La souris entre (ou sort) d'une icône ou de sa fiche ; en sortant, elle a un instant
    // pour passer de l'une à l'autre.
    function hover(key, inside) {
        if (inside) {
            hoverOut.stop()
            hoveredKey = key
        } else if (hoveredKey === key) {
            hoverOut.restart()
        }
    }
    Timer { id: hoverOut; interval: Theme.sysCardHoverGrace; onTriggered: root.hoveredKey = "" }
    Keys.onLeftPressed: move(-1)
    Keys.onRightPressed: move(1)
    Keys.onUpPressed: Sounds.play("edge")
    Keys.onDownPressed: leaveRequested()
    Keys.onEscapePressed: leaveRequested()
    Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) aHeld = true }
    Keys.onEnterPressed: function(event) { if (!event.isAutoRepeat) aHeld = true }
    Keys.onReleased: function(event) {
        if (event.isAutoRepeat || event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter || !aHeld) return
        aHeld = false
        activate(selected)
    }

    // --- Île de notification ---
    property int controllerCount: 0      // manettes branchées
    property string controllerFamily: "" // "xbox", "playstation", "nintendo"
    // Faux pendant l'entrée (rien ne bouge pendant le vol du logo), un panneau, un lancement,
    // la veille : les événements de ces moments-là sont ignorés.
    property bool notificationsAllowed: true
    property bool islandOpen: false          // la forme
    property bool islandContentShown: false  // le contenu de la notification
    // { icon: "pad" | "battery" | "host" | "network", title, text, value, accent }
    property var notification: null
    property var nextNotification: null
    property bool hostLost: false
    property var seen: null                  // dernier état vu, auquel comparer le suivant

    // Ouvre l'île (ou remplace la notification affichée, sans refermer).
    function notify(n) {
        if (!notificationsAllowed) return
        Sounds.play("notify")
        holdTimer.restart()
        if (islandOpen && islandContentShown) {
            islandContentShown = false
            nextNotification = n
            swapTimer.restart()
            islandBump.restart()
        } else {
            closeTimer.stop()
            notification = n
            islandOpen = true
            islandContentShown = true
        }
    }
    // Referme l'île (B) ; faux si elle l'était déjà.
    function dismiss() {
        if (!islandOpen || !islandContentShown && !swapTimer.running) return false
        holdTimer.stop()
        swapTimer.stop()
        islandContentShown = false
        closeTimer.restart()
        return true
    }
    Timer { id: holdTimer; interval: Theme.islandHold; onTriggered: root.dismiss() }
    Timer {
        id: swapTimer
        interval: Theme.islandSwap
        onTriggered: { root.notification = root.nextNotification; root.islandContentShown = true }
    }
    Timer { id: closeTimer; interval: Theme.islandCloseDelay; onTriggered: root.islandOpen = false }

    function familyName(family) {
        return family === "xbox" ? "Xbox" : family === "playstation" ? "PlayStation"
             : family === "nintendo" ? "Nintendo" : ""
    }
    function snapshot() {
        return { host: hostName, connected: connected, battery: batteryPercent, charging: charging,
                 pad: controllerBattery, pads: controllerCount }
    }
    // Les événements : ce qui a changé depuis le dernier état vu.
    function watch() {
        var now = snapshot(), was = seen
        seen = now
        if (!was || !notificationsAllowed) return
        if (now.pads > was.pads)
            notify({ icon: "pad", title: qsTr("Manette connectée"), text: familyName(controllerFamily) })
        else if (now.pads < was.pads)
            notify({ icon: "pad", title: qsTr("Manette déconnectée") })
        else if (now.pad >= 0 && now.pad <= 1 && was.pad > 1)
            notify({ icon: "pad", accent: true, title: qsTr("Manette presque vide"), text: qsTr("Pensez à la recharger") })
        if (!now.charging && now.battery >= 0 && now.battery < Theme.batteryLow
                && (was.battery >= Theme.batteryLow || was.charging))
            notify({ icon: "battery", accent: true, title: qsTr("Batterie faible"), text: qsTr("Branchez la console"),
                     value: qsTr("%1 %").arg(now.battery) })
        if (now.host !== "" && now.host === was.host) {
            if (was.connected && !now.connected) {
                hostLost = true
                notify({ icon: "host", accent: true, title: qsTr("%1 perdu").arg(now.host), text: qsTr("Reconnexion…") })
            } else if (!was.connected && now.connected && hostLost) {
                hostLost = false
                notify({ icon: "host", title: qsTr("%1 retrouvé").arg(now.host), text: qsTr("Connexion rétablie"),
                         value: latencyMs >= 0 ? qsTr("%1 ms").arg(latencyMs) : "" })
            }
        }
    }
    Component.onCompleted: seen = snapshot()
    onNotificationsAllowedChanged: seen = snapshot()
    onHostNameChanged: Qt.callLater(watch)
    onConnectedChanged: Qt.callLater(watch)
    onBatteryPercentChanged: Qt.callLater(watch)
    onChargingChanged: Qt.callLater(watch)
    onControllerBatteryChanged: Qt.callLater(watch)
    onControllerCountChanged: Qt.callLater(watch)
    // Réseau mauvais pendant Theme.islandPoorDelay : une fois par épisode.
    Timer {
        interval: Theme.islandPoorDelay
        running: root.connected && root.quality === "poor" && root.notificationsAllowed
        onTriggered: root.notify({ icon: "network", accent: true, title: qsTr("Réseau instable"),
                                   text: qsTr("Latence %1 ms · gigue %2 ms").arg(root.latencyMs).arg(root.jitterMs) })
    }

    // Élément du contenu de l'île : il entre en fondu montant, `order` fois
    // Theme.islandStagger après les autres, et sort en fondu.
    component IslandPart: Item {
        id: part
        property int order: 0
        property real shift: Theme.islandShift
        property real grow: Theme.islandContentScale
        opacity: 0
        transform: [
            Scale { origin.x: part.width / 2; origin.y: part.height / 2; xScale: part.grow; yScale: part.grow },
            Translate { y: part.shift }
        ]
        states: State {
            name: "in"; when: root.islandContentShown
            PropertyChanges { target: part; opacity: 1; shift: 0; grow: 1 }
        }
        transitions: [
            Transition {
                to: "in"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.islandContentDelay + part.order * Theme.islandStagger }
                    NumberAnimation {
                        properties: "opacity,shift,grow"; duration: Theme.islandFade
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                    }
                }
            },
            Transition {
                from: "in"
                SequentialAnimation {
                    NumberAnimation {
                        property: "opacity"; duration: Theme.islandOut
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                    }
                    PropertyAction { properties: "shift,grow" }
                }
            }
        ]
    }

    // Silhouette de manette, sur une grille 24 × 16.
    component PadShape: Item {
        id: padShape
        property color ink: Theme.ink
        width: Theme.padIconSize.width; height: Theme.padIconSize.height
        Rectangle {
            x: 1; y: 2; width: 22; height: 12; radius: 6
            color: "transparent"
            border.width: 1.6; border.color: padShape.ink
            border.pixelAligned: false
        }
        Rectangle { x: 4.6; y: 7.3; width: 5.4; height: 1.4; radius: 0.7; color: padShape.ink }
        Rectangle { x: 6.6; y: 5.3; width: 1.4; height: 5.4; radius: 0.7; color: padShape.ink }
        Rectangle { x: 15; y: 5.4; width: 2; height: 2; radius: 1; color: padShape.ink }
        Rectangle { x: 17.6; y: 8; width: 2; height: 2; radius: 1; color: padShape.ink }
    }

    // Batterie : contour, borne et niveau, sur la grille 30 × 16 de l'icône.
    component BatteryShape: Item {
        id: batteryShape
        property int percent: 0
        property color ink: Theme.ink
        width: Theme.batterySize.width; height: Theme.batterySize.height
        Item {
            anchors.centerIn: parent
            width: 30; height: 16
            scale: Theme.batterySize.height / 16
            Rectangle {
                x: 0.2; y: 0.2; width: 26.1; height: 15.6; radius: 4.3
                color: "transparent"
                border.width: 1.6; border.color: batteryShape.ink
                border.pixelAligned: false
            }
            Rectangle { x: 27; y: 5.5; width: 2; height: 5; radius: 1; color: batteryShape.ink }
            Rectangle {
                x: 3.5; y: 3.5; height: 9; radius: 1.6
                width: 19.5 * Math.max(0, Math.min(100, batteryShape.percent)) / 100
                color: batteryShape.ink
            }
        }
    }

    // Wi-Fi : un point et trois arcs, allumés selon `strength` (1 à 4). Tracé sur la grille
    // 24 × 24 de l'icône du prototype : arcs de centre (12, 19.2), trait de 2, soit des
    // anneaux dont on ne garde que le haut.
    component WifiShape: Item {
        id: wifiShape
        property int strength: 0
        width: Theme.wifiSize; height: Theme.wifiSize
        Item {
            width: 24; height: 24
            scale: Theme.wifiSize / 24
            transformOrigin: Item.TopLeft

            Rectangle {
                x: 10.7; y: 18; width: 2.6; height: 2.6; radius: 1.3
                color: wifiShape.strength >= 1 ? Theme.ink : Theme.inkOff
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
                        border.color: wifiShape.strength >= index + 2 ? Theme.ink : Theme.inkOff
                    }
                }
            }
        }
    }

    // Icône de droite qu'on peut choisir : sa pastille déborde de l'icône (la barre garde
    // sa géométrie), éclairée au survol et sous la manette, avec l'anneau de focus.
    component SysButton: Pressable {
        id: sysButton
        property string key
        readonly property bool focused: root.activeFocus && root.selected === key
        anchors.verticalCenter: parent.verticalCenter
        down: focused && root.aHeld || sysMouse.pressed
        hovered: sysMouse.containsMouse
        hoverScale: Theme.hoverScale
        Item {
            id: plate
            anchors.centerIn: parent
            width: parent.width + 2 * Theme.sysButtonPad; height: Theme.sysButtonHeight
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.hoverFill
                opacity: sysMouse.containsMouse || sysButton.focused ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.hoverFade } }
            }
            FocusRing { inset: 0; shown: sysButton.focused }
        }
        HoverArea {
            id: sysMouse
            anchors.fill: plate
            onContainsMouseChanged: root.hover(sysButton.key, containsMouse)
            onClicked: root.activate(sysButton.key)
        }
    }

    // Fiche d'une icône : icône, titre, sous-titre, puis ses lignes (libellé, valeur ; une
    // valeur vide masque la ligne) et ce que fait A. Sous la barre, calée à droite.
    component SysCard: Item {
        id: card
        property string key
        property string title
        property string subtitle
        property bool accent: false
        property var lines: []
        property string action: ""
        default property alias icon: iconBox.data
        readonly property var shownLines: lines.filter(function(l) { return l.value !== "" })

        x: root.width - Theme.margin + Theme.sysButtonPad - width
        y: Theme.topBarY + Theme.topBarHeight + Theme.sysCardGap
        width: Theme.sysCardWidth
        height: body.height + 2 * Theme.sysCardPad
        transformOrigin: Item.TopRight
        visible: opacity > 0
        opacity: 0
        scale: Theme.islandContentScale
        property real shift: Theme.sysCardShift
        transform: Translate { y: card.shift }
        states: State {
            name: "in"; when: root.cardKey === card.key
            PropertyChanges { target: card; opacity: 1; scale: 1; shift: 0 }
        }
        transitions: [
            Transition {
                to: "in"
                NumberAnimation {
                    property: "opacity"; duration: Theme.islandFade
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
                NumberAnimation {
                    properties: "scale,shift"; duration: Theme.springGentle.duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                }
            },
            Transition {
                from: "in"
                SequentialAnimation {
                    NumberAnimation {
                        property: "opacity"; duration: Theme.islandOut
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                    }
                    PropertyAction { properties: "scale,shift" }
                }
            }
        ]

        // L'ombre de l'île (pré-calculée), étirée à la taille de la fiche.
        BorderImage {
            anchors.fill: parent
            anchors.margins: -Theme.islandShadowPad
            source: "shadows/island.png"
            border { left: shadowBorder; right: shadowBorder; top: shadowBorder; bottom: shadowBorder }
            readonly property int shadowBorder: Theme.islandShadowPad + Theme.islandRadius
            visible: !Theme.reducedMotion
        }
        Rectangle { anchors.fill: parent; radius: Theme.sysCardRadius; color: Theme.islandFill }
        // Filet posé PAR-DESSUS le fond (une bordure de Rectangle le remplacerait).
        Rectangle {
            anchors.fill: parent
            radius: Theme.sysCardRadius
            color: "transparent"
            border.width: 1
            border.color: Theme.hostPillStroke
        }
        // Survolée, la fiche reste ouverte ; les clics passent à la légende.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled: card.visible
            onContainsMouseChanged: root.hover(card.key, containsMouse)

            Column {
                id: body
                x: Theme.sysCardPad; y: Theme.sysCardPad
                width: parent.width - 2 * Theme.sysCardPad
                spacing: Theme.sysCardSectionGap

                Row {
                    spacing: Theme.islandGap
                    Item {
                        id: iconBox
                        width: Theme.islandIconSize; height: width
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: card.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.islandIconAccent)
                                               : Theme.islandIconFill
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: body.width - Theme.islandIconSize - Theme.islandGap
                        spacing: Theme.islandTextGap
                        Text {
                            width: parent.width
                            text: card.title
                            color: card.accent ? Theme.accent : Theme.ink
                            elide: Text.ElideRight
                            font.family: Theme.fontUi; font.pixelSize: Theme.islandTitleSize; font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: card.subtitle
                            color: Theme.ink2
                            elide: Text.ElideRight
                            font.family: Theme.fontUi; font.pixelSize: Theme.islandTextSize
                        }
                    }
                }
                Rectangle {
                    visible: card.shownLines.length > 0
                    width: parent.width; height: 1
                    color: Theme.hostPillStroke
                }
                Column {
                    visible: card.shownLines.length > 0
                    width: parent.width
                    spacing: Theme.sysCardLineGap
                    Repeater {
                        model: card.shownLines
                        Item {
                            width: parent.width; height: lineValue.height
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: Theme.ink3
                                font.family: Theme.fontUi; font.pixelSize: Theme.sysCardLabelSize
                            }
                            Text {
                                id: lineValue
                                anchors.right: parent.right
                                text: modelData.value
                                color: Theme.ink
                                font.family: Theme.fontUi; font.pixelSize: Theme.sysCardValueSize
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
                ControllerLegend {
                    visible: card.action !== ""
                    hints: [ { glyph: "A", label: card.action } ]
                    pressing: root.aHeld && root.selected === card.key
                    onTriggered: root.activate(card.key)
                }
            }
        }
    }

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

        // --- Logotype ---
        // À la taille du logo de démarrage (repère 720 ramené au canevas), réduit par
        // `scale` : même géométrie que celui de BootSplash.
        Item {
            id: logoBox
            anchors.verticalCenter: parent.verticalCenter
            width: logo.width * logo.scale; height: logo.height * logo.scale
            Logotype {
                id: logo
                fontSize: Theme.logoSize * Theme.canvasHeight / Theme.bootRefHeight
                scale: Theme.statusLogoScale
                transformOrigin: Item.TopLeft
                width: implicitWidth; height: implicitHeight
                opacity: root.logoShown ? 1 : 0
            }
        }

        // Ombre de l'île ouverte (pré-calculée), sous la pastille.
        Image {
            x: pill.x - Theme.islandShadowPad
            y: pill.y + pill.height / 2 - Theme.islandSize.height / 2 - Theme.islandShadowPad
            width: Theme.islandSize.width + 2 * Theme.islandShadowPad
            height: Theme.islandSize.height + 2 * Theme.islandShadowPad
            source: "shadows/island.png"
            opacity: Math.min(1, pill.open) * root.contentOpacity
            visible: opacity > 0 && !Theme.reducedMotion
        }

        // --- Pastille de l'hôte, qui s'ouvre en île de notification ---
        Rectangle {
            id: pill
            readonly property real idleWidth: Theme.hostPillPadLeft + pillRow.width + Theme.hostPillPadRight
            readonly property real idleHeight: hostLabel.height + 2 * Theme.hostPillPadV
            // 0 = pastille, 1 = île : la taille suit le ressort « souple », le rayon à part.
            property real open: root.islandOpen ? 1 : 0
            Behavior on open {
                NumberAnimation {
                    duration: Theme.springGentle.duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springGentle.curve
                }
            }
            property real round: root.islandOpen ? 1 : 0
            Behavior on round {
                NumberAnimation {
                    duration: Theme.islandRadiusMove
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
            property real bump: 1                // 0 → 1 : rebond quand une notification en remplace une autre
            NumberAnimation {
                id: islandBump
                target: pill; property: "bump"; from: 0; to: 1
                duration: Theme.islandBounceDuration
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
            }

            opacity: root.contentOpacity
            x: logoBox.width + Theme.statusLogoGap
            anchors.verticalCenter: parent.verticalCenter
            width: idleWidth + (Theme.islandSize.width - idleWidth) * open
            height: idleHeight + (Theme.islandSize.height - idleHeight) * open
            radius: idleHeight / 2 + (Theme.islandRadius - idleHeight / 2) * round
            color: root.islandOpen ? Theme.islandFill : Theme.hostPillFill
            Behavior on color { ColorAnimation { duration: Theme.islandRadiusMove } }
            scale: 1 + (Theme.islandBounce - 1) * (1 - Math.abs(2 * bump - 1))
            clip: true

            // Filet posé PAR-DESSUS le fond (une bordure de Rectangle le remplacerait).
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.hostPillStroke
            }
            // Île ouverte, à la souris : cliquée, elle se referme ; survolée, elle reste.
            HoverArea {
                anchors.fill: parent
                enabled: root.islandOpen && root.islandContentShown
                onClicked: root.dismiss()
                onContainsMouseChanged: if (containsMouse) holdTimer.stop()
                                        else if (enabled) holdTimer.restart()
            }

            Row {
                id: pillRow
                x: Theme.hostPillPadLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.hostPillGap
                // Effacé à l'ouverture de l'île, de retour après sa fermeture.
                states: State {
                    name: "hidden"; when: root.islandOpen
                    PropertyChanges { target: pillRow; opacity: 0 }
                }
                transitions: [
                    Transition {
                        to: "hidden"
                        NumberAnimation {
                            property: "opacity"; duration: Theme.islandIdleOut
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                        }
                    },
                    Transition {
                        from: "hidden"
                        SequentialAnimation {
                            PauseAnimation { duration: Theme.islandIdleDelay }
                            NumberAnimation {
                                property: "opacity"; duration: Theme.islandIdleIn
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                            }
                        }
                    }
                ]

                // Point d'état : orange clignotant pendant la connexion, puis fixe, de la
                // couleur de la qualité du réseau (vert sans mesure).
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.hostDotSize; height: width; radius: width / 2
                    color: !root.connected ? Theme.accent
                         : root.quality === "poor" ? Theme.poor
                         : root.quality === "fair" ? Theme.fair : Theme.ok
                    Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }
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

            // Contenu de l'île : icône, titre et détail, valeur à droite.
            Item {
                id: islandBody
                readonly property var n: root.notification || ({})
                readonly property color tone: n.accent ? Theme.accent : Theme.ink
                width: Theme.islandSize.width; height: Theme.islandSize.height
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.open > 0
                Accessible.role: Accessible.AlertMessage
                Accessible.name: (n.title || "") + (n.text ? " · " + n.text : "")

                IslandPart {
                    id: islandIcon
                    order: 0
                    x: Theme.islandPadLeft
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.islandIconSize; height: width
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: islandBody.n.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.islandIconAccent)
                                                   : Theme.islandIconFill
                    }
                    PadShape { anchors.centerIn: parent; visible: islandBody.n.icon === "pad"; ink: islandBody.tone }
                    BatteryShape {
                        anchors.centerIn: parent
                        visible: islandBody.n.icon === "battery"
                        percent: root.batteryPercent; ink: islandBody.tone
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: islandBody.n.icon === "host"
                        width: Theme.islandHostDot; height: width; radius: width / 2
                        color: islandBody.n.accent ? Theme.accent : Theme.ok
                    }
                    Row {
                        anchors.centerIn: parent
                        visible: islandBody.n.icon === "network"
                        spacing: Theme.signalBarGap
                        Repeater {
                            model: 4
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: Theme.signalBarWidth; height: Theme.signalBarStep * (index + 1)
                                radius: width / 2
                                color: index === 0 ? islandBody.tone : Theme.inkOff
                            }
                        }
                    }
                }
                IslandPart {
                    order: 1
                    x: islandIcon.x + islandIcon.width + Theme.islandGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: islandValue.x - x - (valueText.text !== "" ? Theme.islandGap : 0)
                    height: islandTexts.height
                    Column {
                        id: islandTexts
                        width: parent.width
                        spacing: Theme.islandTextGap
                        Text {
                            width: parent.width
                            text: islandBody.n.title || ""
                            color: Theme.ink
                            elide: Text.ElideRight
                            font.family: Theme.fontUi; font.pixelSize: Theme.islandTitleSize; font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: islandBody.n.text || ""
                            color: Theme.ink2
                            elide: Text.ElideRight
                            font.family: Theme.fontUi; font.pixelSize: Theme.islandTextSize
                        }
                    }
                }
                IslandPart {
                    id: islandValue
                    order: 2
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.islandPadRight
                    anchors.verticalCenter: parent.verticalCenter
                    width: valueText.width; height: valueText.height
                    Text {
                        id: valueText
                        text: islandBody.n.value || ""
                        color: Theme.ink
                        font.family: Theme.fontUi; font.pixelSize: Theme.islandValueSize; font.features: { "tnum": 1 }
                    }
                }
            }
        }

        // --- Horloge, Wi-Fi, batterie ---
        Item {
            anchors.fill: parent
            opacity: root.contentOpacity

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

            // Manette sans fil : sa silhouette et trois barres, sur une grille 24 × 16
            // puis 10 × 10. Orange quand il ne reste qu'une barre (ou aucune).
            Row {
                id: pad
                anchors.verticalCenter: parent.verticalCenter
                visible: root.controllerBattery >= 0
                spacing: Theme.padBarsGap
                readonly property color ink: root.controllerBattery <= 1 ? Theme.accent : Theme.ink

                PadShape { anchors.verticalCenter: parent.verticalCenter }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1.5
                    Repeater {
                        model: [4, 7, 10]
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: 2; height: modelData; radius: 1
                            color: root.controllerBattery > index ? pad.ink : Theme.inkOff
                        }
                    }
                }
            }

            SysButton {
                key: "wifi"
                visible: root.signalStrength >= 0
                width: Theme.wifiSize; height: Theme.wifiSize
                WifiShape { strength: root.signalStrength }
            }

            // Batterie : éclair pendant la charge ; orange quand elle est faible.
            SysButton {
                key: "battery"
                visible: root.batteryPercent >= 0
                width: battery.width; height: battery.height
            Row {
                id: battery
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

                BatteryShape {
                    anchors.verticalCenter: parent.verticalCenter
                    percent: root.batteryPercent; ink: battery.ink
                }
            }
            }

            SysButton {
                key: "settings"
                width: Theme.settingsIconSize; height: width
                Image {
                    anchors.fill: parent
                    source: "icons/settings.svg"
                    sourceSize: Qt.size(width * Theme.scale, height * Theme.scale)
                }
            }
        }
        }
    }

    // --- Fiches des icônes de droite ---
    SysCard {
        key: "wifi"
        readonly property var w: root.wifi || ({})
        title: w.ssid || qsTr("Wi-Fi")
        subtitle: w.secured === false ? qsTr("Connecté · réseau ouvert") : qsTr("Connecté · sécurisé")
        lines: [
            { label: qsTr("Signal"), value: w.strength !== undefined ? qsTr("%1 %").arg(w.strength) : "" },
            { label: qsTr("Latence vers %1").arg(root.hostName),
              value: !root.connected || root.latencyMs < 0 ? ""
                   : root.jitterMs >= 0 ? qsTr("%1 ms · gigue %2 ms").arg(root.latencyMs).arg(root.jitterMs)
                   : qsTr("%1 ms").arg(root.latencyMs) }
        ]
        action: root.wifiChangeable ? qsTr("Changer de réseau") : ""
        WifiShape { anchors.centerIn: parent; strength: root.signalStrength }
    }
    SysCard {
        id: batteryCard
        key: "battery"
        readonly property var d: root.batteryDetails || ({})
        title: qsTr("%1 %").arg(root.batteryPercent)
        subtitle: root.charging ? qsTr("En charge")
                : d.status === "Full" ? qsTr("Chargée")
                : d.status === "Not charging" ? qsTr("Branchée, sans charger")
                : qsTr("Sur batterie")
        accent: !root.charging && root.batteryPercent < Theme.batteryLow
        lines: [
            { label: root.charging ? qsTr("Pleine dans") : qsTr("Autonomie restante"),
              value: Format.duration(d.minutes) },
            { label: root.charging ? qsTr("Puissance de charge") : qsTr("Consommation"),
              value: d.watts > 0 ? qsTr("%1 W").arg(Format.decimal(d.watts)) : "" }
        ]
        BatteryShape {
            anchors.centerIn: parent
            percent: root.batteryPercent
            ink: batteryCard.accent ? Theme.accent : Theme.ink
        }
    }
    SysCard {
        key: "settings"
        title: qsTr("Paramètres")
        action: qsTr("Ouvrir")
        Image {
            anchors.centerIn: parent
            width: Theme.settingsIconSize; height: width
            source: "icons/settings.svg"
            sourceSize: Qt.size(width * Theme.scale, height * Theme.scale)
        }
    }
}
