pragma Singleton
import QtQuick

// Sons de l'interface : Sounds.play("move"), "edge", "select", "back", "open",
// "close", "tick", "launch", "ready" ; et ceux des micro-interactions : "toggle-on" /
// "toggle-off" (interrupteur), "hold" (appui maintenu, arrêté par Sounds.stop) puis
// "confirm", "deny" (refus), "notify" (île), "detent" (cran du curseur), "segment"
// (profil de flux). Coupés par défaut : c'est l'application
// (ConsoleHome) qui les active, pas le harnais ni les tests.
// played(name) est émis même sons coupés : l'accueil en tire les vibrations de la manette.
// Les sons eux-mêmes sont dans SoundBank.qml, chargé à part : si QtMultimedia
// manque sur la machine, l'interface fonctionne, simplement sans son.
QtObject {
    id: root

    property bool enabled: false
    signal played(string name)

    function play(name) {
        played(name)
        if (bank.item)
            bank.item.play(name)
    }
    function stop(name) {
        if (bank.item)
            bank.item.stop(name)
    }

    readonly property Loader bank: Loader {
        active: root.enabled
        source: "SoundBank.qml"
    }
}
