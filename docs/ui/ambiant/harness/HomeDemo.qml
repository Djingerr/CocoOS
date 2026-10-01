import QtQuick
import "../../../../app/gui/console"
import "../../../../app/gui/console/Format.js" as Format

// L'écran d'accueil « Ambiant » (HomeScreen) alimenté par les jeux de démo, sans
// ConsoleHome ni backend Moonlight. Flèches gauche/droite pour changer de jeu
// (maintenir pour la répétition), Y pour les options, Entrée pour lancer : la
// séquence de lancement suit alors le minutage de la maquette, puis revient.
//
// Arguments du harnais :
//   focus  index du jeu sélectionné au départ (0 à 9)
//   goto   index vers lequel se déplacer à `at` ms (pour capturer une transition)
//   do     actions jouées à `at` ms, séparées par des virgules et espacées de
//          150 ms : options, up, down, left, right, a, launch, tab (onglet suivant)
//   at     instant de `goto` / `do`, en ms (300 par défaut)
//   drift  0 pour figer la dérive du fond (captures comparables aux références)
//   sound  0 pour couper les sons (coupés d'office pendant une capture)
//   connected=0, signal=0..4, battery=0..100, charging=1   états de la barre haute
//   pad=xbox|playstation|nintendo, padbattery=0..3          manette (glyphes, batterie)
// Pour comparer à une référence, capturer après l'entrée de l'écran : delay=2500.
HomeScreen {
    id: demo

    property var args: ({})
    readonly property var game: games.count > 0 ? games.get(currentIndex) : null
    // Réglages de la maquette (tableau SETTINGS du prototype)
    property var settings: ({ res: 1, fps: 1, rate: 0, codec: 0, hdr: 0 })

    focus: true
    model: DemoGames { id: games }
    ready: games.count > 0
    currentIndex: Number(args.focus || 0)
    driftAllowed: args.drift !== "0"

    title: game ? game.name : ""
    source: game ? Format.sourceName(game.source) : ""
    lastPlayed: game ? Format.lastPlayed(game.lastPlayed, new Date()) : ""
    playtime: game ? Format.playtime(game.playtimeSeconds) : ""
    updateNote: game ? game.updateNote : ""
    backdrop: game ? game.boxart : ""

    hostName: "Djinger"
    connected: args.connected !== "0"
    latencyMs: 9
    signalStrength: Number(args.signal || 4)
    batteryPercent: Number(args.battery || 82)
    charging: args.charging === "1"
    controllerBattery: args.padbattery !== undefined ? Number(args.padbattery) : -1
    timeText: "21:30"

    optionsHost: "Djinger"
    optionTabs: [
        { label: "Flux", rows: [
            { key: "res", label: "Résolution", options: ["720p", "Natif 1280×800", "1080p"], index: settings.res },
            { key: "fps", label: "Images par seconde", options: ["30", "60", "90", "120"], index: settings.fps },
            { key: "rate", label: "Débit", options: ["Auto", "10 Mb/s", "20 Mb/s", "40 Mb/s", "80 Mb/s"], index: settings.rate },
            { key: "codec", label: "Codec", options: ["Auto (AV1)", "H.264", "HEVC", "AV1"], index: settings.codec },
            { key: "hdr", label: "HDR", options: ["Désactivé", "Activé"], index: settings.hdr }
        ] },
        { label: "Console", rows: [
            { key: "brightness", label: "Luminosité", options: ["40 %", "50 %", "60 %", "70 %"], index: 2 },
            { key: "volume", label: "Volume", options: ["60 %", "70 %", "80 %"], index: 1 },
            { key: "sleep", label: "Veille de l'écran", options: ["2 min", "5 min", "10 min"], index: 1 },
            { key: "buttons", label: "Boutons", options: ["Auto", "Xbox", "PlayStation", "Nintendo"], index: 0 },
            { key: "sounds", label: "Sons", options: ["Activés", "Coupés"], index: 0 },
            { key: "wifi", label: "Wi-Fi", value: "Maison-5G", action: true }
        ] }
    ]
    onOptionChanged: function(key, index) {
        var next = Object.assign({}, settings)
        next[key] = index
        settings = next
    }
    onForgetRequested: console.info("[demo] oublier Djinger")
    onLaunchRequested: launch()

    Component.onCompleted: {
        Sounds.enabled = args.out === undefined && args.sound !== "0"
        Theme.buttonLayout = args.pad || "xbox"
    }
    Keys.onHangupPressed: options.open()
    Keys.onPressed: function(event) { if (event.key === Qt.Key_Y) options.open() }

    // --- Lancement, au minutage de la maquette : une étape toutes les 680 ms ---
    function launch() {
        if (pressed) return
        Sounds.play("select")
        pressed = true
        launchOpen.start()
    }
    Timer {
        id: launchOpen
        interval: Theme.launchPress
        onTriggered: {
            demo.launching = true
            launchScreen.step = 0
            launchScreen.steps = ["Réveil de Djinger"]
                .concat(demo.game.updateNote ? ["Mise à jour de 2,4 Go sur le PC"] : [])
                .concat(["Lancement de " + demo.game.name, "Ouverture du flux 800p60 AV1"])
            launchScreen.image = demo.game.boxart
            launchScreen.open()
        }
    }
    Timer {
        interval: Theme.launchStep
        repeat: true
        running: launchScreen.active && launchScreen.progressShown
        onTriggered: {
            if (launchScreen.step < launchScreen.steps.length - 1) {
                launchScreen.step++
            } else {
                // Ici le vrai flux démarrerait ; la démo revient à l'accueil.
                Sounds.play("ready")
                launchScreen.close(true)
                demo.launching = false
                demo.pressed = false
                demo.forceActiveFocus()
            }
        }
    }
    LaunchScreen {
        id: launchScreen
        anchors.fill: parent
        cancellable: true
        onCancelRequested: {
            Sounds.play("back")
            close(true)
            demo.launching = false
            demo.pressed = false
            demo.forceActiveFocus()
        }
    }

    // --- Actions scriptées (captures) ---
    property var script: (args["do"] || "").split(",").filter(function(a) { return a !== "" })
    Timer {
        interval: Number(demo.args.at || 300)
        running: demo.args.goto !== undefined || demo.script.length > 0
        onTriggered: {
            if (demo.args.goto !== undefined)
                demo.currentIndex = Number(demo.args.goto)
            scriptStep.start()
        }
    }
    Timer {
        id: scriptStep
        interval: 150
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (demo.script.length === 0) { stop(); return }
            var action = demo.script.shift()
            if (action === "options") demo.options.open()
            else if (action === "up") demo.options.step(-1)
            else if (action === "down") demo.options.step(1)
            else if (action === "left") demo.options.change(-1, false)
            else if (action === "right") demo.options.change(1, false)
            else if (action === "a") demo.options.activate()
            else if (action === "launch") demo.launch()
            else if (action === "tab") demo.options.switchTab(1)
        }
    }
}
