import QtQuick

// Répétition des flèches à l'appui prolongé, identique partout dans l'interface :
// un premier délai, puis un intervalle qui se resserre (Theme.repeat*). Celle du
// système est ignorée ; le D-pad, lui, n'envoie qu'un appui puis un relâchement.
//
//   PadRepeat { id: pad; keys: [Qt.Key_Left, Qt.Key_Right]; onTriggered: key => … }
//   Keys.onPressed: event => pad.press(event)
//   Keys.onReleased: event => pad.release(event)
Item {
    id: root

    property var keys: []            // touches prises en charge
    signal triggered(int key)        // à l'appui, puis à chaque répétition

    property int heldKey: 0
    property int repeats: 0

    // Renvoie true (et accepte l'événement) si la touche est prise en charge.
    function press(event) {
        if (keys.indexOf(event.key) < 0)
            return false
        event.accepted = true
        if (event.isAutoRepeat)
            return true
        heldKey = event.key
        repeats = 0
        triggered(heldKey)
        timer.interval = Theme.repeatDelay
        timer.restart()
        return true
    }
    function release(event) {
        if (event.isAutoRepeat || event.key !== heldKey)
            return
        event.accepted = true
        stop()
    }
    // À appeler si le focus part touche enfoncée : le relâchement n'arrivera pas.
    function stop() {
        timer.stop()
        heldKey = 0
    }

    Timer {
        id: timer
        onTriggered: {
            root.repeats++
            root.triggered(root.heldKey)
            interval = Math.max(Theme.repeatMin, Theme.repeatInterval - root.repeats * Theme.repeatStep)
            restart()
        }
    }
}
