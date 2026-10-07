import QtQuick
import QtTest
import "../../../../app/gui/console/Library.js" as Library

// L'étagère : filtre des utilitaires, ordre (favoris, récents, nom) et
// synchronisation du ListModel sans recréer les éléments déjà présents.
TestCase {
    name: "Library"

    function names(list) { return list.map(function(a) { return a.name }) }
    function never() { return 0 }

    function test_utilitiesAreHiddenWhenThereAreGames() {
        var apps = [{ name: "Desktop" }, { name: "Hades" }, { name: "Steam Big Picture" },
                    { name: " virtual display " }, { name: "PlayNite" }]
        compare(names(Library.order(apps, [], never)), ["Hades"])
    }

    function test_utilitiesStayWhenThereIsNoGame() {
        var apps = [{ name: "Steam Big Picture" }, { name: "Desktop" }]
        compare(names(Library.order(apps, [], never)), ["Desktop", "Steam Big Picture"])
    }

    function test_favoritesThenRecentThenName() {
        var apps = [{ name: "Celeste" }, { name: "Hades" }, { name: "Abzû" }, { name: "Outer Wilds" }, { name: "Doom" }]
        var played = { "Hades": 200, "Doom": 300, "Outer Wilds": 100 }
        var order = Library.order(apps, ["Outer Wilds", "Celeste"], function(n) { return played[n] || 0 })
        compare(names(order), ["Outer Wilds", "Celeste", "Doom", "Hades", "Abzû"])
    }

    function test_pendingTilesAreCompanionGamesNotYetApps() {
        var games = [
            { id: "1", name: "Hades", isInstalled: true, downloadable: false },        // déjà une app
            { id: "2", name: "Zelda-like", isInstalled: false, downloadable: true },
            { id: "3", name: "Fortnite", isInstalled: false, downloadable: false },    // Epic : pas en v1
            { id: "4", name: "Celeste", isInstalled: true, downloadable: false },      // tout juste téléchargé, app pas encore là
            { id: "9", name: "Doom", isInstalled: true, downloadable: false },         // installé, sans téléchargement : jamais
            { id: "5", name: "Abzû", isInstalled: false, downloadable: true },
            { id: "6", name: "Outer Wilds", isInstalled: false, downloadable: true },  // en téléchargement
            { id: "7", name: "abzû", isInstalled: false, downloadable: true },         // homonyme
            { id: "8", name: "Desktop", isInstalled: true, downloadable: false }       // utilitaire
        ]
        var tiles = Library.pendingTiles(games, ["HADES", "Steam Big Picture"], { "6": { state: "PAUSED" }, "4": { state: "DONE" } })
        compare(names(tiles), ["Celeste", "Outer Wilds", "Abzû", "Zelda-like"])
    }

    function test_toggledPinsInFrontAndUnpins() {
        compare(Library.toggled(["A", "B"], "C"), ["C", "A", "B"])
        compare(Library.toggled(["A", "B", "C"], "B"), ["A", "C"])
    }

    function test_parseFallsBackOnGarbage() {
        compare(Library.parse("[\"A\"]", []), ["A"])
        compare(Library.parse("{oops", []), [])
        compare(Library.parse("{\"A\": 1}", []), [])          // mauvais type
        compare(Library.parse("{\"A\": 1}", {}), { A: 1 })
    }

    ListModel { id: model }
    Instantiator {
        id: watcher
        model: model
        delegate: QtObject { property string tag: "" }
    }

    function test_syncMovesInsteadOfRecreating() {
        model.clear()
        Library.sync(model, [{ name: "A", boxart: "a" }, { name: "B", boxart: "b" }, { name: "C", boxart: "c" }])
        compare(model.count, 3)
        watcher.objectAt(2).tag = "kept"                     // l'élément C
        Library.sync(model, [{ name: "C", boxart: "c2" }, { name: "A", boxart: "a" }, { name: "D", boxart: "d" }])
        compare(model.count, 3)
        compare([model.get(0).name, model.get(1).name, model.get(2).name], ["C", "A", "D"])
        compare(model.get(0).boxart, "c2")
        compare(watcher.objectAt(0).tag, "kept")             // déplacé, pas recréé
    }
}
