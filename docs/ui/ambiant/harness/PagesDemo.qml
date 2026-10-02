import QtQuick
import "../../../../app/gui/console"

// Les écrans autres que l'accueil, posés dans un HomeScreen comme dans ConsoleHome :
// recherche du PC, chargement, liaison Moonlight (code à saisir sur le PC), liaison
// Companion (code à saisir sur la console), demande de confirmation. Les textes
// reprennent ceux de ConsoleHome.
//
//   qml-qt6 Harness.qml -- view=PagesDemo page=code
//   ./shot.sh /tmp/a.png view=PagesDemo page=pin delay=1500
//
// page : search | loading | pin | pin-error | code | code-busy | code-error | dialog | curtain
HomeScreen {
    id: demo

    property var args: ({})
    readonly property string page: args.page || "search"
    readonly property var legendOptions: [ { glyph: "Y", label: "Options" } ]

    focus: true
    hostName: page === "search" ? "Recherche…" : "Djinger"
    connected: page === "loading" || page === "dialog"
    signalStrength: 4
    batteryPercent: 82
    timeText: "21:30"
    staged: page !== "dialog"

    // La confirmation s'ouvre par-dessus l'accueil, avec ses jeux.
    model: page === "dialog" ? games : null
    ready: page === "dialog"
    title: page === "dialog" ? "Elden Ring" : ""
    source: page === "dialog" ? "Steam" : ""
    lastPlayed: page === "dialog" ? "Il y a 2 jours" : ""
    playtime: page === "dialog" ? "138 h de jeu" : ""
    backdrop: page === "dialog" && games.count > 1 ? games.get(1).boxart : ""
    currentIndex: page === "dialog" ? 1 : 0
    DemoGames { id: games }

    MessageScreen {
        parent: demo.stage
        shown: demo.page === "search" || demo.page === "loading"
        title: demo.page === "search" ? "Recherche de votre PC" : "Chargement de vos jeux"
        text: demo.page === "search" ? "Vérifiez qu'il est allumé et sur le même réseau que la console." : ""
        busy: true
        hints: demo.legendOptions
    }
    MessageScreen {
        parent: demo.stage
        shown: demo.page.indexOf("pin") === 0
        title: "Liaison avec Djinger"
        text: "Saisissez ce code sur votre PC. La console se connectera ensuite toute seule."
        code: "4821"
        status: error ? "La liaison a échoué. Nouvelle tentative dans un instant…" : "En attente de votre PC…"
        error: demo.page === "pin-error"
        busy: !error
        hints: demo.legendOptions
    }
    CompanionPairing {
        parent: demo.stage
        focus: shown
        shown: demo.page.indexOf("code") === 0
        hostName: "Djinger"
        digits: [4, 8, 2, 0, 0, 0]
        active: 3
        busy: demo.page === "code-busy"
        errorText: demo.page === "code-error" ? "Code incorrect — réessayez." : ""
        onSubmitted: function(code) { console.info("[demo] code " + code) }
    }

    // Rideau entre un jeu et l'accueil, pendant la fermeture du jeu.
    StreamCurtain {
        anchors.fill: parent
        z: 10
        Component.onCompleted: if (demo.page === "curtain") { cover(); reveal("Fermeture de Desktop…", true) }
    }

    ConsoleDialog {
        anchors.fill: parent
        title: "Un jeu est déjà en cours"
        message: "Hades II est en cours sur votre PC. Le fermer et lancer Elden Ring ? Toute progression non sauvegardée sera perdue."
        confirmLabel: "Fermer et jouer"
        Component.onCompleted: if (demo.page === "dialog") open()
        onClosed: demo.forceActiveFocus()
    }
}
