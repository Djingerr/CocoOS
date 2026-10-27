import QtQuick
import "mock/IdleMockData.js" as Mock

// IdleStatus alimenté par le mock (mock/IdleMockData.js) : un des quatre états, avec la
// progression du téléchargement qui avance et la latence qui varie.
// TODO(HostCompanion) : session, téléchargements et jaquettes viendront du PC.
IdleStatus {
    id: root

    property string scenario: "game"       // "game", "gameDownload", "download", "rest"

    // Les horodatages relatifs du mock deviennent absolus par rapport à `now`.
    function ago(seconds) { return new Date(root.now.getTime() - seconds * 1000) }
    function resolveGame(g) {
        return g ? Object.assign({}, g, { coverUrl: Qt.resolvedUrl(g.coverUrl) }) : g
    }
    function load() {
        var d = Mock.data[scenario]
        if (!d) return
        host = d.host
        network = Object.assign({}, d.network)
        battery = d.battery
        var s = Object.assign({}, d.session)
        if (s.active) {
            s.connectedAt = ago(s.connectedSecondsAgo)
            s.game = resolveGame(s.game)
        }
        session = s
        var dl = Object.assign({}, d.download)
        if (dl.game) dl.game = resolveGame(dl.game)
        download = dl
        lastGame = d.lastGame ? { title: d.lastGame.title, coverUrl: Qt.resolvedUrl(d.lastGame.coverUrl),
                                  lastPlayedAt: ago(d.lastGame.lastPlayedSecondsAgo) } : null
        jitterIndex = 0
    }
    onScenarioChanged: load()
    Component.onCompleted: load()

    property Timer progressTimer: Timer {
        interval: 1000; repeat: true
        running: root.download.active === true && root.download.simulateProgressPerSecond > 0
        onTriggered: root.download = Object.assign({}, root.download, {
            progress: Math.min(0.99, root.download.progress + root.download.simulateProgressPerSecond),
            etaSeconds: Math.max(0, root.download.etaSeconds - 1)
        })
    }
    property int jitterIndex: 0
    property Timer jitterTimer: Timer {
        interval: Mock.data.latencyJitterPeriodMs; repeat: true; running: true
        onTriggered: {
            var seq = Mock.data.latencyJitterSequenceMs
            root.jitterIndex = (root.jitterIndex + 1) % seq.length
            root.network = Object.assign({}, root.network, { latencyMs: seq[root.jitterIndex] })
        }
    }
}
