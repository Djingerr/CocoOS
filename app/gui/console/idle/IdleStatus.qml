import QtQuick

// Données de l'écran de veille (interface du brief, docs/design/idle/CLAUDE_BRIEF.md). Les
// écrans ne lisent que ceci : un fournisseur alimenté par HostCompanion remplacera le mock
// sans les toucher.
QtObject {
    id: root

    // Heure affichée : l'horloge système, ou `fixedNow` (captures).
    property var fixedNow: null
    property date clockNow: new Date()
    readonly property date now: fixedNow ? fixedNow : clockNow
    property Timer clock: Timer {
        interval: 1000; repeat: true; running: !root.fixedNow
        onTriggered: root.clockNow = new Date()
    }

    property var host: ({ name: "", reachable: false, inGame: false, sleeping: false })
    // { kind: "wifi" | "4g" | "5g" ("lte" = "4g") | autre, latencyMs, rssiDbm | quality ("excellent",
    // "good", "fair", "poor") }
    property var network: ({ kind: "wifi", latencyMs: -1 })
    property var battery: ({ percent: -1, charging: false, minutesLeft: -1 })
    // { active, connectedAt: date, game { title, publisher, genre, coverUrl } }
    property var session: ({ active: false })
    // { active, kind: "update" | "install", title, progress 0..1, bytesPerSec, etaSeconds, game {…} }
    property var download: ({ active: false })
    property var lastGame: null       // { title, coverUrl, lastPlayedAt: date }

    // SPEC §1
    readonly property string state: session.active ? (download.active ? "gameDownload" : "game")
                                                   : download.active ? "download" : "rest"
}
