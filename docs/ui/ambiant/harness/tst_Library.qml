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
