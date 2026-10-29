import QtQuick
import QtTest
import "../../../../app/gui/console/Search.js" as Search

// Recherche (Search.js) : titres d'abord (le début du titre, puis n'importe où), puis studios et
// genres ; casse et accents ignorés ; suggestions et recherches récentes.
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tst_Search.qml
TestCase {
    name: "Search"

    readonly property var games: [
        { name: "Hollow Knight", developers: ["Team Cherry"], releaseDate: "2017-02-24T00:00:00", genres: ["Metroidvania"] },
        { name: "Forza Horizon 5", developers: ["Playground Games"], genres: ["Course"] },
        { name: "Horizon Zero Dawn", developers: ["Guerrilla"], releaseDate: "2017-02-28", genres: ["Action-RPG"] },
        { name: "Hades", developers: ["Supergiant Games"], genres: ["Rogue-lite"] },
        { name: "Élden Ring", publishers: ["Bandai Namco"], genres: ["Action-RPG"] } ]

    function test_titlesFirstThenStudiosAndGenres() {
        var r = Search.results(games, "Ho")
        compare(r.map(function(x) { return x.name }), ["Hollow Knight", "Horizon Zero Dawn", "Forza Horizon 5"])
        compare([r[0].hit, r[0].why], [2, "Team Cherry · 2017"])
        compare([r[2].hit, r[2].why], [0, "titre contient « Ho »"])
        r = Search.results(games, "rpg")
        compare(r.map(function(x) { return x.name }), ["Élden Ring", "Horizon Zero Dawn"])
        compare(r[0].why, "genre : action-rpg")
        compare(Search.results(games, "supergiant")[0].why, "studio : Supergiant Games")
        compare(Search.results(games, "elden")[0].name, "Élden Ring")   // sans accents
        compare(Search.results(games, "  ").length, 0)
        compare(Search.results(games, "zelda").length, 0)
    }

    function test_suggestionsAndRecent() {
        compare(Search.suggestions(games, "ho", 3), ["hollow", "horizon", "hollow knight"])
        compare(Search.suggestions(games, "", 3), [])
        compare(Search.remember(["minecraft", "celeste", "course"], "Celeste", 3), ["Celeste", "minecraft", "course"])
        compare(Search.remember(["a"], "  ", 3), ["a"])
    }
}
