pragma Singleton
import QtQuick

// Sons de l'interface, pack CocoOS (docs/ui/cocoos/sounds/manifest.json) :
// Sounds.play("sheet_open"), "nav_move" (alterne nav_move_1/2/3), "nav_move_fast" (flèche
// maintenue, 11 par seconde au plus)… ; Sounds.stop("hold_fill") ; Sounds.ambiance("amb_veille")
// pour une boucle (fondu croisé), ambiance("") pour l'arrêter.
// Les anciens noms (« Ambiant ») restent valides par alias (SPEC §2).
// Coupés par défaut : c'est l'application (ConsoleHome) qui les active, pas le harnais ni les tests.
// played(name) est émis même sons coupés, avec le nom du pack (ou celui du `haptic` donné) :
// l'accueil en tire les vibrations de la manette (motion/haptics.json).
// Les sons eux-mêmes sont dans SoundBank.qml, chargé à part : si QtMultimedia
// manque sur la machine, l'interface fonctionne, simplement sans son.
QtObject {
    id: root

    property bool enabled: false
    signal played(string name)

    // Ancien nom → nom du pack ("" : plus de son).
    readonly property var aliases: ({
        "move": "nav_move", "edge": "nav_edge", "open": "sheet_open", "close": "sheet_close",
        "tick": "focus_tick", "launch": "launch_start", "ready": "launch_ready",
        "toggle-on": "toggle_on", "toggle-off": "toggle_off", "hold": "hold_fill", "confirm": "hold_done",
        "notify": "notification", "detent": "slider_tick", "segment": "tab_switch",
        "boot-close": "", "boot-open": "boot"
    })
    function resolve(name) {
        return aliases[name] !== undefined ? aliases[name] : name
    }

    // `haptic` : le son dont la vibration accompagne celui-ci, s'il diffère (le saut de lettre
    // du carrousel sonne tab_switch et vibre comme une catégorie, category_next).
    function play(name, haptic) {
        name = resolve(name)
        if (name === "")
            return
        played(haptic || name)
        if (bank.item)
            bank.item.play(name)
    }
    function stop(name) {
        if (bank.item)
            bank.item.stop(resolve(name))
    }
    function ambiance(name) {
        if (bank.item)
            bank.item.ambiance(name)
    }

    readonly property Loader bank: Loader {
        active: root.enabled
        source: "SoundBank.qml"
    }
}
