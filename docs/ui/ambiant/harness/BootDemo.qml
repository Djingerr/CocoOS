import QtQuick
import "../../../../app/gui/console"

// L'animation de démarrage seule (BootSplash), sur fond noir.
//
//   qml-qt6 Harness.qml -- view=BootDemo size=1280x720
//   ./shot.sh /tmp/a.png view=BootDemo size=1280x720 t=1400   # instant figé (ms)
//
// Arguments du harnais :
//   t       instant figé (ms) ; sans lui, l'animation se joue
//   speed   multiplicateur de vitesse (0.25 pour regarder de près)
//   mode    cold (défaut) | wake
//   ready   instant (ms) où le système devient prêt ; sans lui, prêt d'emblée
Item {
    id: demo
    property var args: ({})

    BootSplash {
        id: splash
        anchors.fill: parent
        autoStart: demo.args.t === undefined
        mode: demo.args.mode || "cold"
        speed: Number(demo.args.speed || 1)
        systemReady: demo.args.ready === undefined
        Component.onCompleted: {
            if (demo.args.t !== undefined) {
                splash.readyAt = demo.args.ready === undefined ? 0 : Number(demo.args.ready)
                splash.t = Number(demo.args.t)
            }
        }
        onSoundCue: function(name) { console.info("[demo] son", name, Math.round(splash.t)) }
    }
    Timer {
        interval: Number(demo.args.ready || 0)
        running: demo.args.ready !== undefined && demo.args.t === undefined
        onTriggered: splash.systemReady = true
    }
}
