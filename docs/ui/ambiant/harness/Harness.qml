import QtQuick
import "../../../../app/gui/console"

// Harnais de développement de l'écran « Ambiant » : charge une vue de démo de ce
// dossier dans une fenêtre 1280 × 800, sans aucun backend Moonlight, et peut en
// enregistrer une capture à comparer aux références de ../ref/ (ref-capture.py).
//
//   qml-qt6 -I stubs Harness.qml -- view=HomeDemo        (à l'écran, interactif)
//   ./shot.sh /tmp/a.png view=HomeDemo focus=2 drift=0   (capture, rendu GPU)
// (« -I stubs » : faux modules Moonlight, nécessaires à la vue ConsoleHomeDemo.)
//
// Arguments (clé=valeur, après « -- ») :
//   view   nom de la vue à charger (fichier <view>.qml de ce dossier)
//   out    chemin du PNG à écrire ; la fenêtre se ferme ensuite
//   delay  attente avant la capture, en ms (1500 par défaut)
//   size   taille de la fenêtre, « 960x600 » par exemple (1280x800 par défaut)
//
// Avec QT_QPA_PLATFORM=offscreen, Qt Quick rend en logiciel : positions et textes
// sont fidèles, mais les petits tracés (icônes) sont approximatifs et ShaderEffect /
// MultiEffect / layer n'apparaissent pas. D'où shot.sh pour les captures.
Window {
    id: win

    readonly property var args: {
        var a = {}
        Qt.application.arguments.forEach(function(s) {
            var i = s.indexOf("=")
            if (i > 0) a[s.slice(0, i)] = s.slice(i + 1)
        })
        return a
    }

    readonly property var size: (args.size || Theme.canvasWidth + "x" + Theme.canvasHeight).split("x")

    width: Number(size[0])
    height: Number(size[1])
    visible: true
    color: Theme.background
    // Capture : sans décoration, pour que la scène fasse exactement 1280 × 800.
    flags: args.out !== undefined ? Qt.Window | Qt.FramelessWindowHint : Qt.Window

    // Fond dans la scène : grabToImage ne capture pas la couleur de la fenêtre.
    Rectangle { anchors.fill: parent; color: Theme.background }

    // Chaque vue déclare `property var args` et y reçoit les arguments du harnais.
    Loader {
        anchors.fill: parent
        focus: true
        onStatusChanged: if (status === Loader.Error) Qt.exit(1)
        Component.onCompleted: if (win.args.view) setSource(win.args.view + ".qml", { args: win.args })
    }

    Timer {
        interval: win.args.delay ? Number(win.args.delay) : 1500
        running: win.args.out !== undefined
        onTriggered: win.contentItem.grabToImage(function(result) {
            Qt.exit(result.saveToFile(win.args.out) ? 0 : 1)
        })
    }
}
