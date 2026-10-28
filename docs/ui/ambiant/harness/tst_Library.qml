import QtQuick
import QtTest
import "../../../../app/gui/console/Library.js" as Library

// L'étagère : filtre des utilitaires, ordre (favoris, récents, nom) et
// synchronisation du ListModel sans recréer les éléments déjà présents.
TestCase {
    name: "Library"

    function names(list) { return list.map(function(a) { return a.name }) }
    function never() { return 0 }

    // Les utilitaires ne sont pas dans « Tout » quand il y a des jeux : ils ont leur onglet « Apps ».
    function test_utilitiesGoToApps() {
        var apps = Library.order([{ name: "Desktop" }, { name: "Hades" }, { name: "Steam Big Picture" },
                                  { name: " virtual display " }, { name: "PlayNite" }], never)
        compare(names(Library.collection(apps, "all", never)), ["Hades"])
        compare(names(Library.collection(apps, "apps", never)),
                ["Desktop", "PlayNite", "Steam Big Picture", " virtual display "])
    }

    function test_utilitiesStayWhenThereIsNoGame() {
        var apps = Library.order([{ name: "Steam Big Picture" }, { name: "Desktop" }], never)
        compare(names(Library.collection(apps, "all", never)), ["Desktop", "Steam Big Picture"])
    }

    // Les plus récents d'abord, puis par nom ; les favoris ne passent plus en tête (onglet à part).
    function test_recentThenName() {
        var apps = [{ name: "Celeste" }, { name: "Hades" }, { name: "Abzû" }, { name: "Outer Wilds" }, { name: "Doom" }]
        var played = { "Hades": 200, "Doom": 300, "Outer Wilds": 100 }
        var order = Library.order(apps, function(n) { return played[n] || 0 })
        compare(names(order), ["Doom", "Hades", "Outer Wilds", "Abzû", "Celeste"])
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

    // Catégories : favoris seuls, récents du plus récent au plus ancien ; « Tout » et
    // « Favoris » toujours proposés, « Récents » et « Apps » s'ils ont quelque chose.
    function test_collections() {
        var items = [ { name: "A", favorite: true }, { name: "B", favorite: false }, { name: "C", favorite: false } ]
        var dates = { B: 100, C: 300 }
        var played = function(n) { return dates[n] || 0 }
        compare(names(Library.collection(items, "all", played)), ["A", "B", "C"])
        compare(names(Library.collection(items, "favorites", played)), ["A"])
        compare(names(Library.collection(items, "recent", played)), ["C", "B"])
        compare(Library.collections(items, played), ["all", "favorites", "recent"])
        items[0].favorite = false
        compare(Library.collections(items, function() { return 0 }), ["all", "favorites"])
        compare(Library.collections(items.concat([{ name: "Desktop" }]), never), ["all", "favorites", "apps"])
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
