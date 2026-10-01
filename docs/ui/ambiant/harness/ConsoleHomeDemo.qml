import QtQuick
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
//          150 ms : left, right, pin (bouton X)
//   at     instant de `do`, en ms (300 par défaut)
//   noart  noms de jeux (séparés par des virgules) privés de jaquette
Item {
    id: demo
    property var args: ({})

    // ConsoleHome empile ses écrans de stream sur le `stackView` de main.qml.
    QtObject {
        id: stackView
        function push(item) { console.info("[demo] stackView.push(" + item + ")") }
    }

    ConsoleHome { id: home; anchors.fill: parent; focus: true }

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
        }
    }
}
