import QtQuick
import ".."

// Première configuration CocoOS (SPEC 5.9) : Bonjour → Langue → Wi-Fi → PC → code → Bibliothèque
// → « Tout est prêt » → accueil. Plein écran, par-dessus l'accueil, sur le canevas. Les étapes
// (`step`) : "hello", "language", "wifi", "pc", "pair", "library". La flèche simple (A : étape
// suivante, B : précédente) est ici ; ce qui touche au système (réseau, PC, appairage) est
// signalé, et l'appelant fait avancer (`go`) quand c'est fait. Aucune dépendance Moonlight.
FocusScope {
    id: root

    property string step: "hello"
    // La première étape : "hello" ; "pc" pour « Ajouter un PC » (B y referme, et le code fait
    // revenir à l'accueil : `closeRequested`).
    property string firstStep: "hello"
    property bool shown: false
    property bool padReady: false

    // Langue : [{ label }], la choisie, et la ligne « Région … · clavier … · format … ».
    property var languages: []
    property int languageIndex: 0
    property string regionText: ""
    // Wi-Fi : sans Wi-Fi (NetworkManager absent), l'étape est sautée.
    property bool wifiAvailable: true
    property var networks: []            // WifiSetup.networks
    property bool wifiScanning: false
    // PC : [{ name, detail, pill: { text, accent } }], le réseau (« LIVEBOX-7A3C »).
    property var hosts: []
    property bool hostScanning: false
    property string lanName: ""
    property string notice: ""           // sous la liste : échec d'un ajout, d'une connexion
    // « Installer Apollo et HostCompanion » : l'adresse et son code QR (lignes de « 0 » / « 1 »,
    // SystemStatus.qrRows) ; sans adresse, la ligne n'apparaît pas.
    property string installUrl: ""
    property var installQr: []
    // Code : cf. SetupPair.
    property alias pair: pairPage
    // Bibliothèque : cf. SetupLibrary ; `libraryText` sous le titre.
    property alias library: libraryPage
    property string libraryText: ""
    property bool libraryReady: false    // toutes les jaquettes sont là

    signal languageChosen(int index)
    signal networkChosen(string ssid)
    signal otherNetwork()
    signal rescanNetworks()
    signal hostChosen(int index)
    signal addHost()
    signal rescanHosts()
    signal pairCancelled()
    signal prefChanged(string key, int index)
    signal closeRequested()
    signal homeReturn()                  // la fin : l'accueil revient (en éventail)
    signal finished()

    // L'étape `next` s'affiche (et prend la manette).
    function go(next) {
        if (next === step) return
        forward = order.indexOf(next) > order.indexOf(step)
        step = next
        notice = ""
        if (next === "wifi" || next === "pc") lists[next].reset()
        if (next === "pair") pairPage.reset()
        Qt.callLater(focusStep)
    }
    function focusStep() {
        var page = { hello: helloPage, language: languageList, wifi: wifiList, pc: pcList, install: installPage,
                     pair: pairPage, library: libraryPage.list }[step]
        if (page) page.forceActiveFocus()
    }
    function back() {
        if (step === firstStep && step !== "hello") {
            Sounds.play("back")
            closeRequested()
            return
        }
        var prev = { language: "hello", wifi: "language", pc: wifiAvailable ? "wifi" : "language",
                     install: "pc", pair: "pc", library: "pc" }[step]
        if (!prev) return
        Sounds.play("back")
        if (step === "pair") pairCancelled()
        go(prev)
    }
    function finish() {
        if (finishing) return
        finishing = true
        Sounds.play("select")
        finishPage.start()
    }
    property bool finishing: false
    property bool forward: true
    readonly property var order: ["hello", "language", "wifi", "pc", "install", "pair", "library"]
    readonly property var lists: ({ wifi: wifiList, pc: pcList })

    visible: shown || fade.running
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { id: fade; duration: Theme.setupSwapIn } }
    onShownChanged: {
        if (shown) {
            finishing = false
            Sounds.ambiance("amb_appairage")
        } else {
            Sounds.ambiance("")
        }
    }

    Keys.onEscapePressed: back()
    // Y : actualiser (Wi-Fi, PC) ; Start (même touche) : commencer, à la bibliothèque.
    property var startDown: null
    Keys.onPressed: function(event) {
        if (event.key !== Qt.Key_Hangup || event.isAutoRepeat) return
        event.accepted = true
        if (step === "library") {
            if (startDown === null || startDown()) libraryPage.pressing = true
        } else if (step === "wifi") {
            Sounds.play("select")
            rescanNetworks()
        } else if (step === "pc") {
            Sounds.play("select")
            rescanHosts()
        }
    }
    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Hangup && !event.isAutoRepeat && libraryPage.pressing) {
            libraryPage.pressing = false
            finish()
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.background }

    // Lueurs : l'orange en bas, un bleu en haut à droite ; elles dérivent lentement.
    Item {
        id: aurora
        anchors.fill: parent
        opacity: finishPage.running && finishPage.leaving ? 0.6 : 1
        property real drift: 0
        SequentialAnimation on drift {
            running: root.shown && !Theme.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { to: 1; duration: Theme.setupDrift; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0; duration: Theme.setupDrift; easing.type: Easing.InOutSine }
        }
        transform: [
            Scale { origin.x: aurora.width / 2; origin.y: aurora.height / 2
                    xScale: 1 + (Theme.setupDriftScale - 1) * aurora.drift; yScale: xScale },
            Translate { x: Theme.setupDriftBy.x * aurora.drift; y: Theme.setupDriftBy.y * aurora.drift }
        ]
        readonly property bool hello: root.step === "hello"
        Glow {
            x: parent.width / 2 + (aurora.hello ? Theme.helloGlowLow.x : Theme.setupGlowLow.x)
            y: aurora.hello ? Theme.helloGlowLow.y : Theme.setupGlowLow.y
            width: Theme.setupGlowLow.width
            height: aurora.hello ? Theme.helloGlowLow.height : Theme.setupGlowLow.height
            color: aurora.hello ? Theme.helloGlowAccent : Theme.setupGlowAccent
            Behavior on y { NumberAnimation { duration: 1600; easing.type: Easing.InOutQuad } }
            Behavior on height { NumberAnimation { duration: 1600; easing.type: Easing.InOutQuad } }
        }
        Glow {
            x: parent.width / 2 + Theme.setupGlowHigh.x; y: Theme.setupGlowHigh.y
            width: Theme.setupGlowHigh.width; height: Theme.setupGlowHigh.height
            color: Theme.setupGlowBlue
        }
        Glow {
            x: Theme.helloGlowCorner.x; y: Theme.helloGlowCorner.y
            width: Theme.helloGlowCorner.width; height: Theme.helloGlowCorner.height
            color: Theme.helloGlowCornerInk
            opacity: aurora.hello ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 1600 } }
        }
    }

    // Le contenu des étapes ; il s'efface en se floutant à la fin (MotionSetupFin).
    Item {
        id: content
        anchors.fill: parent
        opacity: finishPage.leaving ? 0 : 1
        scale: finishPage.leaving ? Theme.finScale : 1
        Behavior on opacity { NumberAnimation { duration: Theme.finFade } }
        Behavior on scale { NumberAnimation { duration: Theme.finShrink; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExit } }

        // En-tête : trois points (l'étape en cours étirée, les faites plus claires) et le libellé.
        readonly property int stepNumber: ({ wifi: 1, pc: 2, install: 2, library: 3 })[root.step] || 0
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.setupDotsTop
            spacing: Theme.setupStepGap
            opacity: content.stepNumber > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.setupSwapOut } }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.setupDotGap
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property int n: index + 1
                        width: n === content.stepNumber ? Theme.setupDotActive : Theme.setupDot
                        height: Theme.setupDot; radius: height / 2
                        color: n === content.stepNumber ? Theme.accent : n < content.stepNumber ? Theme.setupDotDone : Theme.setupDotTodo
                        Behavior on width { NumberAnimation { duration: Theme.setupSwapIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain } }
                        Behavior on color { ColorAnimation { duration: Theme.setupSwapIn } }
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("PREMIÈRE CONFIGURATION · %1 SUR %2").arg(Math.max(1, content.stepNumber)).arg(3)
                color: Theme.ink3
                font.family: Theme.fontUi; font.pixelSize: Theme.setupStepSize; font.weight: Font.DemiBold
                font.letterSpacing: 0.08 * Theme.setupStepSize
            }
        }

        // Une étape : elle s'efface vite, la suivante monte de 12 px en apparaissant.
        component Page: FocusScope {
            id: page
            property string key
            property string title
            property string text
            readonly property bool on: root.step === key
            readonly property real titleTop: key === "language" ? Theme.setupTitleTopBare : Theme.setupTitleTop
            anchors.fill: parent
            enabled: on
            opacity: 0
            visible: opacity > 0
            property real rise: 0
            transform: Translate { y: page.rise }
            // (à la main : une pause qui dépendrait de `on` serait lue périmée, cf. CLAUDE.md)
            Component.onCompleted: if (on) opacity = 1
            onOnChanged: {
                enter.stop(); leave.stop()
                var shift = root.forward ? Theme.setupSwapShift : -Theme.setupSwapShift
                if (on) {
                    rise = shift
                    enter.restart()
                } else {
                    leaveRise.to = -shift
                    leave.restart()
                }
            }
            SequentialAnimation {
                id: enter
                PauseAnimation { duration: Theme.setupSwapOut }
                ParallelAnimation {
                    NumberAnimation { target: page; property: "opacity"; to: 1; duration: Theme.setupSwapIn }
                    NumberAnimation { target: page; property: "rise"; to: 0; duration: Theme.setupSwapIn; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
                }
            }
            ParallelAnimation {
                id: leave
                NumberAnimation { target: page; property: "opacity"; to: 0; duration: Theme.setupSwapOut }
                NumberAnimation { id: leaveRise; target: page; property: "rise"; duration: Theme.setupSwapOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExit }
            }
            Text {
                visible: page.title !== ""
                width: parent.width
                y: page.titleTop
                horizontalAlignment: Text.AlignHCenter
                text: page.title
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.setupTitleSize; font.weight: Font.DemiBold
                font.letterSpacing: -0.03 * Theme.setupTitleSize
            }
            Text {
                visible: page.text !== ""
                x: (parent.width - width) / 2
                y: page.titleTop + Theme.setupTextGap
                width: Theme.setupTextWidth
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeightMode: Text.FixedHeight
                lineHeight: 1.5 * Theme.setupTextSize
                text: page.text
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.setupTextSize; font.weight: Font.Medium
            }
        }
        component Legend: ControllerLegend {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.canvasHeight - Theme.legendBottomCoco - height
            spacing: Theme.offlineLegendGap
            textSize: Theme.legendSizeCoco
            glyphGap: Theme.legendGlyphGapCoco
        }
        component Notice: Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.notice
            visible: text !== ""
            color: Theme.poor
            font.family: Theme.fontUi; font.pixelSize: Theme.setupNoteSize; font.weight: Font.Medium
        }

        // --- Bonjour ---
        Page {
            key: "hello"
            SetupHello {
                id: helloPage
                anchors.fill: parent
                focus: true
                running: root.shown && root.step === "hello"
                padReady: root.padReady
                Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) pressing = true }
                Keys.onEnterPressed: function(event) { if (!event.isAutoRepeat) pressing = true }
                Keys.onReleased: function(event) {
                    if (!pressing || event.isAutoRepeat || event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return
                    pressing = false
                    Sounds.play("select")
                    root.go("language")
                }
                HoverArea { anchors.fill: parent; onClicked: { Sounds.play("select"); root.go("language") } }
            }
        }

        // --- Langue ---
        Page {
            key: "language"
            title: qsTr("Choisissez votre langue")
            text: qsTr("Vous pourrez la changer plus tard dans Réglages › Général.")
            Column {
                x: (parent.width - width) / 2
                y: Theme.setupListTopBare
                width: Theme.setupLanguageWidth
                spacing: Theme.setupNoteGap
                SettingsList {
                    id: languageList
                    width: parent.width; height: contentHeight
                    metrics: Theme.listSettings
                    focus: true
                    rows: root.languages.map(function(l, i) {
                        return { key: "" + i, label: l.label, action: true, chevron: false, check: i === root.languageIndex, group: "languages" }
                    })
                    onActionRequested: function(key) {
                        root.languageChosen(Number(key))
                        root.go(root.wifiAvailable ? "wifi" : "pc")
                    }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.regionText
                    color: Theme.setupNoteInk
                    font.family: Theme.fontUi; font.pixelSize: Theme.setupNoteSize; font.weight: Font.Medium
                }
            }
            Legend { hints: [ { glyph: "A", label: qsTr("Choisir") }, { glyph: "B", label: qsTr("Retour") } ]
                     pressing: languageList.pressing
                     onTriggered: function(glyph) { if (glyph === "A") languageList.activate(); else if (glyph === "B") root.back() } }
        }

        // --- Wi-Fi ---
        Page {
            key: "wifi"
            title: qsTr("Connectez la console à Internet")
            text: qsTr("Pour une latence minimale, branchez le PC en Ethernet et placez la console sur le même réseau en 5 GHz.")
            Column {
                x: (parent.width - width) / 2
                y: Theme.setupListTop
                width: Theme.setupWifiWidth
                spacing: Theme.setupNoteGap
                SettingsList {
                    id: wifiList
                    width: parent.width; height: contentHeight
                    metrics: Theme.listSettings
                    focus: true
                    rows: {
                        var nets = root.networks
                        // La bande, seulement quand un réseau voisin porte presque le même nom
                        // (« Livebox-7A3C » et « Livebox-7A3C_2.4G »).
                        var twin = function(a) {
                            return nets.some(function(b) { return b !== a && (b.ssid.indexOf(a.ssid) === 0 || a.ssid.indexOf(b.ssid) === 0) })
                        }
                        var band = function(f) { return f > 5900 ? qsTr("6 GHz") : f > 4900 ? qsTr("5 GHz") : f > 0 ? qsTr("2,4 GHz") : "" }
                        var rows = nets.map(function(n) {
                            return { key: "wifi:" + n.ssid, label: n.ssid, action: true, chevron: false, lock: n.secured,
                                     bars: n.bars, check: n.active, value: twin(n) ? band(n.frequency || 0) : "",
                                     group: "networks", section: qsTr("Réseaux Wi-Fi"), sectionBusy: root.wifiScanning }
                        })
                        if (rows.length === 0)
                            rows.push({ key: "none", label: qsTr("Recherche des réseaux…"), group: "networks",
                                        section: qsTr("Réseaux Wi-Fi"), sectionBusy: true })
                        return rows.concat([ { key: "other", label: qsTr("Autre réseau…"), action: true,
                                               tile: { color: "transparent", icon: "plus" },
                                               group: "others", section: qsTr("Autres options") } ])
                    }
                    onActionRequested: function(key) {
                        if (key === "other") root.otherNetwork()
                        else if (key.indexOf("wifi:") === 0) root.networkChosen(key.slice(5))
                    }
                }
                Notice {}
            }
            Legend { hints: [ { glyph: "A", label: qsTr("Choisir") }, { glyph: "Y", label: qsTr("Actualiser") },
                              { glyph: "B", label: qsTr("Retour") } ]
                     pressing: wifiList.pressing
                     onTriggered: function(glyph) {
                         if (glyph === "A") wifiList.activate()
                         else if (glyph === "Y") root.rescanNetworks()
                         else if (glyph === "B") root.back()
                     } }
        }

        // --- PC ---
        Page {
            key: "pc"
            title: qsTr("Choisissez votre PC")
            text: qsTr("Lancez Apollo sur le PC. HostCompanion ajoute vos jeux Playnite, leurs jaquettes et leurs informations.")
            Column {
                x: (parent.width - width) / 2
                y: Theme.setupListTop
                width: Theme.setupPcWidth
                spacing: Theme.setupNoteGap
                SettingsList {
                    id: pcList
                    width: parent.width; height: contentHeight
                    metrics: Theme.listSettings
                    focus: true
                    rows: {
                        var section = root.lanName !== "" ? qsTr("PC trouvés sur %1").arg(root.lanName) : qsTr("PC trouvés sur le réseau")
                        var rows = root.hosts.map(function(h, i) {
                            return { key: "pc:" + i, label: h.name, sub: h.detail, action: true, pill: h.pill,
                                     height: Theme.setupPcRow, tile: { color: "transparent", icon: "monitor", size: Theme.setupPcIcon },
                                     group: "hosts", section: section, sectionBusy: root.hostScanning }
                        })
                        if (rows.length === 0)
                            rows.push({ key: "none", label: qsTr("Recherche de votre PC…"), group: "hosts",
                                        section: section, sectionBusy: true })
                        return rows.concat([ { key: "address", label: qsTr("Ajouter avec une adresse IP"), action: true,
                                               tile: { color: "transparent", icon: "globe", size: 18 },
                                               group: "others", section: qsTr("Autres options") } ],
                                           root.installUrl === "" ? [] : [
                                             { key: "install", label: qsTr("Installer Apollo et HostCompanion"), action: true,
                                               value: qsTr("Code QR"), tile: { color: "transparent", icon: "qr", size: 18 },
                                               group: "others" } ])
                    }
                    onActionRequested: function(key) {
                        if (key === "address") root.addHost()
                        else if (key === "install") root.go("install")
                        else if (key.indexOf("pc:") === 0) root.hostChosen(Number(key.slice(3)))
                    }
                }
                Notice {}
            }
            Legend { hints: [ { glyph: "A", label: qsTr("Associer") }, { glyph: "Y", label: qsTr("Actualiser") },
                              { glyph: "B", label: qsTr("Retour") } ]
                     pressing: pcList.pressing
                     onTriggered: function(glyph) {
                         if (glyph === "A") pcList.activate()
                         else if (glyph === "Y") root.rescanHosts()
                         else if (glyph === "B") root.back()
                     } }
        }

        // --- Installer Apollo et HostCompanion (hors maquette) : le code QR de la page ---
        Page {
            id: installPage
            key: "install"
            title: qsTr("Installer Apollo et HostCompanion")
            text: qsTr("Scannez ce code avec votre téléphone pour ouvrir la page d’installation, ou saisissez l’adresse dans le navigateur du PC.")
            Keys.onReturnPressed: root.back()
            Rectangle {
                id: qrCard
                x: (parent.width - width) / 2
                y: Theme.setupListTop + Theme.qrTopGap
                width: Theme.qrCard; height: width
                radius: Theme.qrRadius
                color: Theme.ink
                Canvas {
                    id: qrCanvas
                    anchors.fill: parent
                    anchors.margins: Theme.qrQuiet
                    readonly property var rows: root.installQr
                    onRowsChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var n = rows.length
                        if (n === 0) return
                        var cell = width / n
                        ctx.fillStyle = Theme.inkOnLight
                        for (var y = 0; y < n; y++)
                            for (var x = 0; x < n; x++)
                                if (rows[y].charAt(x) === "1")
                                    ctx.fillRect(Math.floor(x * cell), Math.floor(y * cell),
                                                 Math.ceil(cell), Math.ceil(cell))
                    }
                }
            }
            Text {
                width: parent.width
                y: qrCard.y + qrCard.height + Theme.qrUrlGap
                horizontalAlignment: Text.AlignHCenter
                text: root.installUrl
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.setupTextSize; font.weight: Font.Medium
            }
            Legend { hints: [ { glyph: "B", label: qsTr("Retour") } ]
                     onTriggered: function(glyph) { if (glyph === "B") root.back() } }
        }

        // --- Code ---
        Page {
            key: "pair"
            SetupPair {
                id: pairPage
                anchors.fill: parent
                focus: true
                onContinued: root.firstStep === "pc" ? root.closeRequested() : root.go("library")
                onBackRequested: root.back()
            }
        }

        // --- Bibliothèque ---
        Page {
            key: "library"
            title: root.libraryReady ? qsTr("Votre bibliothèque est prête") : qsTr("Votre bibliothèque arrive")
            text: root.libraryText
            SetupLibrary {
                id: libraryPage
                anchors.fill: parent
                focus: true
                onChanged: function(key, index) { root.prefChanged(key, index) }
                onStarted: root.finish()
            }
            Legend { hints: [ { glyph: "A", label: qsTr("Modifier") }, { glyph: "≡", label: qsTr("Commencer") },
                              { glyph: "B", label: qsTr("Retour") } ]
                     pressing: libraryPage.list.pressing
                     onTriggered: function(glyph) {
                         if (glyph === "A") libraryPage.list.activate()
                         else if (glyph === "≡") root.finish()
                         else if (glyph === "B") root.back()
                     } }
        }
    }

    // --- Fin ---
    SetupFinish {
        id: finishPage
        anchors.fill: parent
        onHomeReturn: root.homeReturn()         // (à l'appelant de passer `shown` à faux)
        onFinished: root.finished()
    }
}
