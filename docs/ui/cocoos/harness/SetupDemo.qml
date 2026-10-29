import QtQuick
import "../../../../app/gui/console"
import "../../../../app/gui/console/setup"

// Première configuration (phase 8) sans backend, sur les données des maquettes.
//
//   ./shot.sh /tmp/s.png view=SetupDemo step=wifi delay=1500
//   ./filmstrip.sh /tmp/p.png 10000 view=SetupDemo step=pair paired=5200
//
// step : hello | language | wifi | pc | pair | library ; paired=ms (le PC accepte le code à tant),
// companion=1 (le code à 6 chiffres à saisir), finish=ms (« Commencer » à tant : MotionSetupFin),
// covers=n (jaquettes déjà là, 11 par défaut). Au clavier comme à la manette.
Item {
    id: demo
    property var args: ({})
    width: 1280; height: 800

    Rectangle { anchors.fill: parent; color: "black" }

    readonly property var art: ["mc", "hk", "fh", "ce", "sv", "er", "ha", "zl", "p2"]

    SetupFlow {
        id: setup
        anchors.fill: parent
        z: 1
        shown: true
        padReady: true
        languages: [ { label: "Français" }, { label: "English" } ]
        regionText: "Région France · clavier AZERTY · format 24 h"
        networks: [
            { ssid: "Livebox-7A3C", secured: true, bars: 4, frequency: 5180, active: false },
            { ssid: "Livebox-7A3C_2.4G", secured: true, bars: 4, frequency: 2437, active: false },
            { ssid: "Bbox-41F2", secured: true, bars: 2, frequency: 2412, active: false },
            { ssid: "FreeWifi_secure", secured: true, bars: 1, frequency: 2462, active: false } ]
        wifiScanning: true
        lanName: "LIVEBOX-7A3C"
        hostScanning: true
        hosts: [ { name: "PC-Salon", detail: "Apollo · HostCompanion · Playnite · 192.168.1.20", pill: { text: "Prêt", accent: true } },
                 { name: "PC-Bureau", detail: "Apollo seulement · installez HostCompanion pour la bibliothèque", pill: { text: "Sans jaquettes" } } ]
        libraryText: "214 jeux trouvés dans Playnite sur PC-Salon. Réglez quelques préférences pendant le chargement."
        library.covers: {
            var n = Number(demo.args.covers || 11), list = []
            for (var i = 0; i < n; i++) list.push(Qt.resolvedUrl("art/" + demo.art[i % demo.art.length] + "-cover.png"))
            return list
        }
        library.done: 132
        library.total: 214
        library.rows: [
            { key: "accent", label: "Couleur d’accent", options: ["Orange", "Blanc", "Bleu", "Vert", "Rose"], index: 0,
              swatches: Theme.accentChoices, group: "prefs", section: "Préférences" },
            { key: "sounds", label: "Sons de l’interface", toggle: true, options: ["Coupés", "Activés"], index: 1, group: "prefs" },
            { key: "uninstalled", label: "Jeux non installés", sub: "Les afficher dans la bibliothèque", toggle: true,
              options: ["Masqués", "Affichés"], index: 0, group: "prefs" },
            { key: "sleep", label: "Mise en veille", options: ["Après 5 min"], index: 0, group: "prefs" } ]
        pair.hostName: "PC-Salon"
        pair.code: demo.args.companion === "1" ? "" : "4827"
        pair.mode: demo.args.companion === "1" ? "companion" : "moonlight"
        onHostChosen: go("pair")
        onNetworkChosen: go("pc")
        pair.onSubmitted: function(code) { pair.done = true }
        onHomeReturn: { home.opacity = 1; shown = false }
        Component.onCompleted: if (demo.args.step) go(demo.args.step)
    }
    // (l'accueil qui revient à la fin)
    Image {
        id: home
        anchors.fill: parent
        source: Qt.resolvedUrl("../reference/png/AccueilCarrousel.png")
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 1400 } }
    }
    Timer { running: demo.args.paired !== undefined; interval: Number(demo.args.paired || 0); onTriggered: setup.pair.done = true }
    Timer { running: demo.args.finish !== undefined; interval: Number(demo.args.finish || 0); onTriggered: setup.finish() }

    Component.onCompleted: Sounds.enabled = false
}
