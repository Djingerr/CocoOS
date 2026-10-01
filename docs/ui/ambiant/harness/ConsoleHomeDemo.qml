import QtQuick
import "../../../../app/gui/console"

// Le VRAI ConsoleHome (logique et overlays compris), branché sur de faux modules
// Moonlight (stubs/) : un PC en ligne et appairé, les jeux de démo. Sert à voir
// l'accueil tel que l'application l'assemble, sans PC hôte.
//
//   qml-qt6 -I stubs Harness.qml -- view=ConsoleHomeDemo
//   ./shot.sh /tmp/a.png view=ConsoleHomeDemo delay=2500
Item {
    property var args: ({})

    // ConsoleHome empile ses écrans de stream sur le `stackView` de main.qml.
    QtObject {
        id: stackView
        function push(item) { console.info("[demo] stackView.push(" + item + ")") }
    }

    ConsoleHome { anchors.fill: parent; focus: true }
}
