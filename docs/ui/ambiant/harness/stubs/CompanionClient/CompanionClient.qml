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

    function startDiscovery() {}
    function games() {
        var list = []
        for (var i = 0; i < demo.count; i++) {
            var g = demo.get(i)
            list.push({ id: "game-" + i, name: g.name, source: g.source,
                        lastPlayed: g.lastPlayed, playtimeSeconds: g.playtimeSeconds,
                        background: backgrounds["game-" + i] || "",
                        logo: logos["game-" + i] || "" })
        }
        return list
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
}
