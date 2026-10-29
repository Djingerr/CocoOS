import QtQuick
import "../../../../app/gui/console"
import "Mock.js" as Mock

// La recherche (SearchScreen) sur la bibliothèque du mock, plus « Horizon Zero Dawn » des
// données de la maquette :
//
//   ./shot.sh /tmp/a.png view=SearchDemo delay=1500                 (Recherche : « ho », focus sur l)
//   ./shot.sh /tmp/a.png view=SearchDemo query=zelda2 delay=1500    (aucun résultat)
//
// Arguments : query (« ho » par défaut ; vide : rien de tapé), results=1 (la manette sur les résultats).
Item {
    id: demo
    property var args: ({})
    width: 1280; height: 800

    readonly property var mock: Mock.load(Qt.resolvedUrl("../mock/library.mock.json"))
    readonly property var games: Mock.games(mock, Qt.resolvedUrl("art/")).concat([
        { id: "hz", name: "Horizon Zero Dawn", developers: ["Guerrilla"], publishers: ["Sony"],
          releaseDate: "2017-02-28T00:00:00", genres: ["Action-RPG"], cover: "", background: "" } ])

    SearchScreen {
        id: search
        anchors.fill: parent
        games: demo.games
        recent: ["minecraft", "celeste", "course"]
        hostName: "PC-Salon"
        connected: true
        latencyMs: 4
        timeText: "21:42"
        signalStrength: 4
        batteryPercent: 82
    }

    Component.onCompleted: {
        Sounds.enabled = false
        search.open()
        search.panel.setText(demo.args.query !== undefined ? demo.args.query : "ho")
        search.panel.row = 2; search.panel.col = 8      // « l »
        if (demo.args.results === "1") search.toResults()
    }
}
