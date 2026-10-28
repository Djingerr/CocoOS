import QtQuick
import QtMultimedia

// Les sons de l'interface (sounds/*.wav, pack CocoOS, déjà mastérisés : ne pas les
// renormaliser). Voir Sounds.qml. Les sons ponctuels et connecting_loop (en boucle jusqu'à
// Sounds.stop) sont préchargés : ils doivent répondre tout de suite. Les ambiances (amb_*,
// 24 à 48 s) ne sont lues qu'à la demande.
// ponytail: QtMultimedia charge tout son moteur (FFmpeg, sondage VA-API). Si le démarrage
// en souffre sur la carte cible, les jouer par SDL (déjà lié à Moonlight) depuis un
// petit backend C++.
Item {
    id: bank

    readonly property var oneShots: [
        "nav_move_1", "nav_move_2", "nav_move_3", "nav_move_fast", "nav_edge", "select", "back",
        "category_next", "category_prev", "focus_tick", "fiche_open", "fiche_close", "library_ready",
        "sheet_open", "sheet_close", "tab_switch", "toggle_on", "toggle_off", "slider_tick", "slider_limit",
        "hold_fill", "hold_done", "deny", "launch_start", "launch_ready", "host_unreachable",
        "ingame_menu_open", "ingame_menu_close", "quit_prompt", "quit_confirm", "capture",
        "favorite_add", "favorite_remove", "volume_tick", "volume_limit", "brightness_tick", "notification",
        "controller_connected", "controller_disconnected", "battery_low", "battery_critical",
        "network_cellular", "network_quality_down", "network_restored", "network_unstable",
        "pairing_code", "pairing_success", "host_wake_send", "host_online", "tv_connected",
        "tv_disconnected", "download_complete", "boot", "shutdown", "sleep", "wake", "idle_enter",
        "idle_exit", "charging_start", "charging_stop", "update_restart", "update_installed"
    ]
    readonly property var loops: ["connecting_loop"]
    readonly property var preloaded: oneShots.concat(loops)
    // Correction par son (dB), par-dessus le mastering des fichiers (SoundBank de référence).
    readonly property var trims: ({ "brightness_tick": -3, "slider_tick": -2 })

    property var effects: ({})
    property int navIndex: 0
    property double lastFast: 0

    function gain(name) {
        return Math.max(0, Math.min(1, Theme.soundVolume * Math.pow(10, (trims[name] || 0) / 20)))
    }
    function play(name) {
        if (name === "nav_move")
            name = "nav_move_" + (1 + navIndex++ % 3)   // trois variantes : jamais mécanique
        if (name === "nav_move_fast") {
            var now = Date.now()
            if (now - lastFast < Theme.navFastInterval)
                return
            lastFast = now
        }
        var effect = effects[name]
        if (!effect) {
            console.warn("SoundBank : son inconnu", name)
            return
        }
        if (effect.playing)
            effect.stop()
        effect.play()
    }
    function stop(name) {
        var effect = effects[name]
        if (effect)
            effect.stop()
    }

    Instantiator {
        model: bank.preloaded
        delegate: SoundEffect {
            source: "sounds/" + modelData + ".wav"
            volume: bank.gain(modelData)
            loops: bank.loops.indexOf(modelData) >= 0 ? SoundEffect.Infinite : 1
        }
        onObjectAdded: function(index, object) { bank.effects[bank.preloaded[index]] = object }
    }

    // --- Ambiances : boucles sans couture, en fondu croisé entre deux lecteurs ---
    property string currentAmbiance: ""
    property SoundEffect current: null
    SoundEffect { id: ambA; loops: SoundEffect.Infinite; volume: 0 }
    SoundEffect { id: ambB; loops: SoundEffect.Infinite; volume: 0 }
    NumberAnimation { id: fadeIn; property: "volume"; duration: Theme.ambianceFadeIn; easing.type: Easing.InOutSine }
    NumberAnimation {
        id: fadeOut; property: "volume"; to: 0; duration: Theme.ambianceFadeOut; easing.type: Easing.InOutSine
        onFinished: if (target) target.stop()
    }

    function ambiance(name) {
        if (name === currentAmbiance)
            return
        if (current) {
            fadeOut.target = current
            fadeOut.from = current.volume
            fadeOut.restart()
        }
        currentAmbiance = name
        if (!name) {
            current = null
            return
        }
        var next = current === ambA ? ambB : ambA
        next.source = "sounds/" + name + ".wav"
        next.volume = 0
        next.play()
        fadeIn.target = next
        fadeIn.from = 0
        fadeIn.to = Theme.soundVolume
        fadeIn.restart()
        current = next
    }
}
