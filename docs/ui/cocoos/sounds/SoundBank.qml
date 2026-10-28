// SoundBank.qml — CocoOS UI sounds (Qt 6, QtMultimedia)
// Usage: SoundBank { id: sfx } … sfx.play("select")  /  sfx.ambiance("amb_veille")
import QtQuick
import QtMultimedia

Item {
    id: bank

    // Options › Console › « Sons » (toggles UI sounds, not the game stream)
    property bool enabled: true
    // master level for UI sounds, 0..1 (independent from the system volume)
    property real level: 0.8
    // optional home music bed (amb_accueil), off by default
    property bool homeAmbiance: false

    readonly property string base: Qt.resolvedUrl("../sounds/wav/")

    // per-sound trim (dB) on top of the mastering in the files
    readonly property var trims: ({ "brightness_tick": -3, "slider_tick": -2 })

    // one-shots that must answer instantly are preloaded as SoundEffect
    readonly property var oneShots: [
        "nav_move_1","nav_move_2","nav_move_3","nav_move_fast","nav_edge","select","back",
        "category_next","category_prev","focus_tick","fiche_open","fiche_close","library_ready",
        "sheet_open","sheet_close","tab_switch","toggle_on","toggle_off","slider_tick","slider_limit","hold_fill","hold_done","deny",
        "launch_start","launch_ready","host_unreachable","ingame_menu_open","ingame_menu_close",
        "quit_prompt","quit_confirm","capture","favorite_add","favorite_remove",
        "volume_tick","volume_limit","brightness_tick","notification","controller_connected",
        "controller_disconnected","battery_low","battery_critical","network_cellular",
        "network_quality_down","network_restored","network_unstable","pairing_code","pairing_success",
        "host_wake_send","host_online","tv_connected","tv_disconnected","download_complete",
        "boot","shutdown","sleep","wake","idle_enter","idle_exit","charging_start","charging_stop",
        "update_restart","update_installed"
    ]

    property var _fx: ({})
    property int _navIdx: 0
    property double _lastFast: 0

    Component {
        id: fxComp
        SoundEffect { }
    }

    Component.onCompleted: {
        for (const id of oneShots) {
            _fx[id] = fxComp.createObject(bank, { source: base + id + ".wav" })
        }
    }

    function _gain(id) {
        const t = trims[id] || 0
        return Math.max(0, Math.min(1, level * Math.pow(10, t / 20)))
    }

    // Plays a one-shot. Navigation rotates 3 variants so repeats never sound mechanical.
    function play(id) {
        if (!enabled) return
        if (id === "nav_move") { id = "nav_move_" + (1 + (_navIdx++ % 3)) }
        if (id === "nav_move_fast") {                    // held stick: cap at ~11 ticks/s
            const now = Date.now()
            if (now - _lastFast < 90) return
            _lastFast = now
        }
        const fx = _fx[id]
        if (!fx) { console.warn("SoundBank: unknown sound", id); return }
        fx.volume = _gain(id)
        if (fx.playing) fx.stop()
        fx.play()
    }

    // ------------------------------------------------------------- loops
    // Ambiances are seamless WAV loops: SoundEffect with infinite loops is gapless.
    SoundEffect { id: ambA; loops: SoundEffect.Infinite; volume: 0 }
    SoundEffect { id: ambB; loops: SoundEffect.Infinite; volume: 0 }
    property var _cur: null
    property string currentAmbiance: ""

    NumberAnimation { id: fadeIn;  property: "volume"; duration: 1800; easing.type: Easing.InOutSine }
    NumberAnimation { id: fadeOut; property: "volume"; duration: 900;  easing.type: Easing.InOutSine; to: 0
        onFinished: if (target) target.stop() }

    // ambiance("amb_veille") · ambiance("") stops. Cross-fades between loops.
    function ambiance(id) {
        if (id === currentAmbiance) return
        if (_cur) { fadeOut.target = _cur; fadeOut.from = _cur.volume; fadeOut.restart() }
        currentAmbiance = id
        if (!id || !enabled) { _cur = null; return }
        const next = (_cur === ambA) ? ambB : ambA
        next.source = base + id + ".wav"
        next.volume = 0
        next.play()
        fadeIn.target = next; fadeIn.from = 0; fadeIn.to = level; fadeIn.restart()
        _cur = next
    }

    onEnabledChanged: if (!enabled) ambiance("")
}
