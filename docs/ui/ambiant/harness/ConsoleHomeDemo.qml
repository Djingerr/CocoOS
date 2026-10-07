import QtQuick
import InputStatus 1.0
import CompanionClient 1.0
import WifiSetup 1.0
import "../../../../app/gui/console"

// Le VRAI ConsoleHome (logique et overlays compris), branché sur de faux modules
// Moonlight (stubs/) : un PC en ligne et appairé, les jeux de démo. Sert à voir
// l'accueil tel que l'application l'assemble, sans PC hôte.
//
//   qml-qt6 -I stubs Harness.qml -- view=ConsoleHomeDemo
//   ./shot.sh /tmp/a.png view=ConsoleHomeDemo delay=2500
//
// Arguments du harnais :
//   do     actions jouées à `at` ms, séparées par des virgules et espacées de
//          150 ms : left, right, down, a, pin (bouton X), home (bouton Home), sleep,
//          wifi (liste des réseaux), net:<réseau> (le choisir), launch (bouton A),
//          details (bas sur l'étagère : la fiche du jeu ; Elden Ring en a une de démo)
//   at     instant de `do`, en ms (300 par défaut)
//   noart  noms de jeux (séparés par des virgules) privés de jaquette
//   offline=1  le PC est hors ligne (la console tente de le réveiller)
//   nogames=1  aucun jeu : l'écran de recherche
//   running    nom du jeu en cours sur le PC
//   logos=1    un logo pour Elden Ring (art/logo-elden.png), comme le Companion en sert
//   setup=1    premier démarrage (bienvenue)
//   nonet=1    la console n'est pas en ligne (premier démarrage : le choix du réseau)
//   download=1 deux jeux du PC pas encore installés en fin d'étagère, l'un en téléchargement (42 %)
Item {
    id: demo
    property var args: ({})

    // ConsoleHome empile ses écrans de stream sur le `stackView` de main.qml.
    QtObject {
        id: stackView
        function push(item) { console.info("[demo] stackView.push(" + item + ")") }
    }

    ConsoleHome {
        id: home
        anchors.fill: parent
        focus: true
        Component.onCompleted: {
            setupDone = demo.args.setup !== "1"
            if (demo.args.nonet === "1") WifiSetup.online = false
            if (demo.args.logos === "1") {
                CompanionClient.logos = { "game-1": Qt.resolvedUrl("art/logo-elden.png").toString() }
                CompanionClient.libraryChanged()
            }
            if (demo.args.download === "1") {
                CompanionClient.extraGames = [
                    { id: "dl-1", name: "Celeste", isInstalled: false, downloadable: true,
                      cover: Qt.resolvedUrl("art/hollow.jpg").toString() },
                    { id: "dl-2", name: "Stardew Valley", isInstalled: false, downloadable: true,
                      cover: Qt.resolvedUrl("art/sot.jpg").toString() }
                ]
                CompanionClient.libraryChanged()
                CompanionClient.downloadStateChanged("dl-1", "DOWNLOADING", 3.1e9, 7.4e9)
            }
        }
    }

    // Premier élément, sous `from`, qui porte la propriété `property`.
    function find(from, property) {
        for (var i = 0; i < from.children.length; i++) {
            var c = from.children[i]
            if (c[property] !== undefined) return c
            var deeper = find(c, property)
            if (deeper) return deeper
        }
        return null
    }

    Connections {
        target: home
        function onAppModelChanged() {
            var noArt = (demo.args.noart || "").split(",")
            for (var i = 0; home.appModel && i < home.appModel.count; i++)
                if (noArt.indexOf(home.appModel.get(i).name) >= 0)
                    home.appModel.setProperty(i, "boxart", "")
            if (home.appModel && demo.args.nogames === "1")
                home.appModel.clear()
            if (home.appModel && demo.args.running)
                home.appModel.runningName = demo.args.running
        }
        function onComputerModelChanged() {
            if (demo.args.offline === "1")
                home.computerModel.setProperty(0, "online", false)
        }
    }

    property var script: (args["do"] || "").split(",").filter(function(a) { return a !== "" })
    Timer {
        interval: Number(demo.args.at || 300)
        running: demo.script.length > 0
        onTriggered: scriptStep.start()
    }
    Timer {
        id: scriptStep
        interval: 150
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (demo.script.length === 0) { stop(); return }
            var action = demo.script.shift()
            var screen = demo.find(home, "ready")
            if (action === "right") screen.currentIndex++
            else if (action === "left") screen.currentIndex--
            else if (action === "pin") home.toggleFavorite()
            else if (action === "home") InputStatus.homePressed()
            else if (action === "sleep") demo.find(home.Window.window.contentItem, "asleep").sleep()
            else if (action === "launch") screen.launchRequested(screen.currentIndex)
            else if (action === "details") screen.detailsRequested()
            else if (action === "wifi") home.openWifi()
            else if (action === "options") screen.options.open()
            else if (action === "tab") screen.options.switchTab(1)
            else if (action.indexOf("net:") === 0) home.chooseNetwork(action.slice(4))
            else if (action === "down" || action === "a") {
                var target = home.Window.activeFocusItem
                while (target && target.step === undefined) target = target.parent
                if (target && action === "down") target.step(1)
                else if (target) target.activate()
            }
        }
    }
}
