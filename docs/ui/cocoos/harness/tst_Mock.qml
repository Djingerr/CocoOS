import QtQuick
import QtTest
import "Mock.js" as Mock

// Données de démo du harnais : le mock au format GameInfo, cas limites compris, et la
// grande bibliothèque de A à Z. Lancer avec QML_XHR_ALLOW_FILE_READ=1.
TestCase {
    name: "Mock"

    readonly property var games: Mock.games(Mock.load(Qt.resolvedUrl("../mock/library.mock.json")),
                                            Qt.resolvedUrl("art/"))
    function byId(id) { return games.filter(function(g) { return g.id === id })[0] }

    function test_gameInfoShape() {
        compare(games.length, 10)
        var mc = byId("mc")
        compare(mc.name, "Minecraft")
        compare(mc.publishers, ["Mojang Studios"])
        compare(mc.ageRatings, ["PEGI 7"])
        compare(mc.playtimeSeconds, 4920 * 60)
        verify(mc.cover.toString().endsWith("art/mc-cover.png"))
    }

    function test_edgeCasesStayAbsent() {
        compare(byId("fa").cover, "")                   // Factorio : jaquette composée
        compare(byId("fa").background, "")
        compare(byId("p2").genres, [])                  // Portal 2 : ni genre, ni PEGI
        compare(byId("p2").ageRatings, [])
        compare(byId("p2").playtimeSeconds, 0)
        verify(!byId("er").isInstalled)
    }

    function test_artExistsForEveryCover() {
        games.forEach(function(g) {
            [g.cover, g.background].forEach(function(url) {
                if (url === "")
                    return
                var xhr = new XMLHttpRequest()
                xhr.open("GET", url, false)
                xhr.responseType = "arraybuffer"
                xhr.send()
                verify(xhr.response && xhr.response.byteLength > 0, url)
            })
        })
    }

    function test_bigLibraryFromAToZ() {
        var big = Mock.expand(games, 214)
        compare(big.length, 214)
        compare(big[0].name.charAt(0), "A")
        compare(big[213].name.charAt(0), "Z")
        var ids = {}
        big.forEach(function(g) { ids[g.id] = true })
        compare(Object.keys(ids).length, 214)
    }
}
