import QtQuick
import "../../../../app/gui/console"

// Écrans système sans backend (phase 7) : un minuteur rejoue la maquette.
//
//   ./filmstrip.sh /tmp/u.png 10000 view=SystemDemo scene=update      (MotionMiseAJour)
//
// scene : update (la mise à jour : avancement, redémarrage, « … est installé »).
Item {
    id: demo
    property var args: ({})
    width: 1280; height: 800

    Rectangle { anchors.fill: parent; color: "black" }

    // --- Mise à jour : l'avancement de la maquette (renderVals de MotionMiseAJour) ---
    UpdateScreen {
        id: update
        anchors.fill: parent
        version: "CocoOS 1.2"
    }
    property real t: 0
    NumberAnimation on t { running: demo.args.scene === "update"; from: 0; to: 10000; duration: 10000 }
    onTChanged: {
        if (args.scene !== "update") return
        var seg = function(a, b, va, vb) { return t <= a ? va : t >= b ? vb : va + (vb - va) * (t - a) / (b - a) }
        update.progress = t < 600 ? 0 : t < 2200 ? seg(600, 2200, 0, 0.34) : t < 3000 ? seg(2200, 3000, 0.34, 0.38)
                        : t < 5200 ? seg(3000, 5200, 0.38, 0.92) : seg(5200, 6000, 0.92, 1)
        update.phase = t >= 7400 && t < 10200 ? "installed" : t >= 6000 && t < 6600 ? "restarting"
                     : t >= 150 && t < 6600 ? "installing" : ""
    }
    Component.onCompleted: Sounds.enabled = false
}
