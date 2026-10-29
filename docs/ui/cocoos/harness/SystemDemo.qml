import QtQuick
import "../../../../app/gui/console"

// Écrans système sans backend (phase 7) : un minuteur rejoue la maquette.
//
//   ./filmstrip.sh /tmp/u.png 10000 view=SystemDemo scene=update      (MotionMiseAJour)
//
// scene : update (la mise à jour : avancement, redémarrage, « … est installé ») ; charge (le câble
// branché, console éteinte : MotionRecharge, level=42) ; tv (la TV branchée puis débranchée :
// MotionSalon, sur une image de l'accueil).
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
    // --- Recharge et mode salon : le câble (1 s) ; la TV (1,4 s, débranchée à 6,6 s) ---
    Image {
        anchors.fill: parent
        visible: demo.args.scene === "tv"
        source: visible ? Qt.resolvedUrl("../reference/png/AccueilCarrousel.png") : ""
        fillMode: Image.PreserveAspectCrop
    }
    ChargingScreen {
        id: charge
        anchors.fill: parent
        level: Number(demo.args.level || 42)
        detail: "En charge · plein dans environ 1 h 10"
    }
    TvScreen {
        id: tv
        anchors.fill: parent
        screenName: "Salon · 4K · 60 i/s"
    }
    Timer { running: demo.args.scene === "charge"; interval: 1000; onTriggered: charge.plug() }
    Timer { running: demo.args.scene === "tv"; interval: 1400; onTriggered: tv.connected = true }
    Timer { running: demo.args.scene === "tv"; interval: 6600; onTriggered: tv.connected = false }

    Component.onCompleted: Sounds.enabled = false
}
