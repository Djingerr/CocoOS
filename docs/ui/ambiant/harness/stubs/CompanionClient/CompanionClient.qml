pragma Singleton
import QtQuick
import "../.." as Harness

// Faux CompanionClient. La bibliothèque de démo est toujours disponible ; par
// défaut la console n'est pas appairée au Companion (ConsoleHome prend alors son
// chemin de lancement direct). Passer `paired` et `eventsConnected` à vrai pour
// le chemin Companion, puis émettre ses signaux à la main. Mêmes propriétés,
// méthodes et signaux que le vrai, pour ce qu'en fait ConsoleHome.
QtObject {
    property bool paired: false
    property bool eventsConnected: false
    property string certFingerprint: ""
    property string hostName: "Djinger"
    property var demo: Harness.DemoGames {}
    // Trace des appels, pour les tests
    property string launched: ""
    property int cancels: 0
    property int forgets: 0
    property string confirmedCode: ""
    property var updateAnswers: []
    property var downloadCalls: []      // « download:<id> », « pause:<id> », « cancel:<id> »
    // Jeux du PC hors démo (non installés…) : { id, name, isInstalled, downloadable, cover }
    property var extraGames: []
    property var uninstallCalls: []     // gameId de chaque désinstallation demandée
    // Fiche de démo (GamePage) : champs de GameInfo en plus, par gameId (Elden Ring).
    property var details: ({
        "game-1": {
            isInstalled: true, uninstallable: true,
            genres: ["Action", "RPG", "Monde ouvert"], releaseDate: "2022-02-25T00:00:00",
            developers: ["FromSoftware"], publishers: ["Bandai Namco", "FromSoftware"],
            ageRatings: ["ESRB M", "PEGI 16"], installSizeBytes: 53365000000,
            description: "<p>Lève-toi, Sans-éclat, et laisse-toi guider par la grâce pour brandir la puissance du Cercle d&apos;Elden.</p>"
                + "<h2>Un vaste monde</h2><ul><li>Des plaines immenses</li><li>Des donjons labyrinthiques</li></ul>"
                + new Array(12).join("<p>Un monde ouvert foisonnant, où chaque région cache ses secrets, ses ennemis redoutables et ses trésors oubliés.</p>")
        }
    })
    // Images de fond et logos « en cache », par gameId (file://…)
    property var backgrounds: ({})
    property var logos: ({})

    signal libraryChanged()
    signal pairingFailed(string code)
    signal pairingSucceeded()
    signal launchStateChanged(string sessionId, string gameId, string state)
    signal updateRequired(string sessionId, string gameId, double sizeBytes)
    signal updateProgress(string sessionId, int pct, double bytesDone, double bytesTotal)
    signal launchReady(string sessionId, string apolloAppId)
    signal launchFailed(string sessionId, string code, string message)
    signal downloadStateChanged(string gameId, string state, double bytesDone, double bytesTotal)
    signal downloadFailed(string gameId, string code)
    signal uninstallStateChanged(string gameId, string state)
    signal uninstallFailed(string gameId, string code)

    function startDiscovery() {}
    function games() {
        var list = []
        for (var i = 0; i < demo.count; i++) {
            var g = demo.get(i)
            list.push(Object.assign({ id: "game-" + i, name: g.name, source: g.source,
                                      lastPlayed: g.lastPlayed, playtimeSeconds: g.playtimeSeconds,
                                      background: backgrounds["game-" + i] || "",
                                      logo: logos["game-" + i] || "" }, details["game-" + i] || {}))
        }
        return list.concat(extraGames)
    }
    function gameIdForName(name) {
        var found = games().filter(function(g) { return g.name === name })
        return found.length > 0 ? found[0].id : ""
    }
    function startPairing(deviceName) {}
    function confirmPairing(code) { confirmedCode = code }
    function forgetHost() { forgets++ }
    function submitMoonlightPin(pin) {}
    function launch(gameId) { launched = gameId }
    function respondUpdate(accept) { updateAnswers = updateAnswers.concat([accept]) }
    function cancelLaunch() { cancels++ }
    function download(gameId) { downloadCalls = downloadCalls.concat(["download:" + gameId]) }
    function pauseDownload(gameId) { downloadCalls = downloadCalls.concat(["pause:" + gameId]) }
    function cancelDownload(gameId) { downloadCalls = downloadCalls.concat(["cancel:" + gameId]) }
    function uninstall(gameId) { uninstallCalls = uninstallCalls.concat([gameId]) }
}
