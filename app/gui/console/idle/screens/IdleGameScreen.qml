import QtQuick
import ".."
import "../components"
import "../IdleFormat.js" as F

// Écrans 09 (jeu en cours) et 10 (jeu en cours + téléchargement, `showDownload`).
CoverScreen {
    id: root

    property bool showDownload: false
    readonly property var network: status.network
    readonly property var download: status.download

    game: status.session.game
    hintAction: qsTr("pour reprendre")
    columnTop: showDownload ? 150 : 170

    // Surtitre : pastille qui respire + « EN COURS SUR PC-SALON ».
    EntryReveal {
        started: root.entryStarted
        delay: IdleTheme.entryDelays.eyebrow
        width: 660; height: eyebrow.implicitHeight
        Eyebrow {
            id: eyebrow
            text: qsTr("En cours sur %1").arg(root.status.host.name)
            Rectangle {
                width: 6; height: 6
                radius: IdleTheme.radiusLiveDot
                color: IdleTheme.accent
                SequentialAnimation on opacity {
                    running: root.animated
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0.35; to: 1; duration: IdleTheme.liveDotPeriod / 2
                        easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
                    }
                    NumberAnimation {
                        from: 1; to: 0.35; duration: IdleTheme.liveDotPeriod / 2
                        easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
                    }
                }
            }
        }
    }
    Item { width: 1; height: 14 }
    GameInfo { game: root.game; entryStarted: root.entryStarted }
    Item { width: 1; height: root.showDownload ? 52 : 56 }

    // Durée de session.
    EntryReveal {
        started: root.entryStarted
        delay: IdleTheme.entryDelays.bigBlock
        width: 660; height: bigBlock.implicitHeight
        Column {
            id: bigBlock
            spacing: 8
            DurationText {
                parts: F.sessionParts(root.status.session.connectedAt
                                      ? (root.status.now - root.status.session.connectedAt) / 1000 : 0)
            }
            IdleText {
                text: qsTr("de jeu depuis la connexion")
                textStyle: IdleTheme.caption
                color: IdleTheme.textSecondary
            }
        }
    }
    Item { width: 1; height: root.showDownload ? 44 : 48 }

    EntryReveal {
        started: root.entryStarted
        delay: IdleTheme.entryDelays.statusLine
        width: 660; height: statusLine.implicitHeight
        StatusLine {
            id: statusLine
            items: [ { icon: "monitor", text: root.status.host.name },
                     { icon: "signal", text: F.latency(root.network.latencyMs) } ]
                   .concat(root.network.kind === "wifi"
                           ? [{ icon: "wifi", text: F.wifiQuality(root.network.quality
                                    || F.wifiQualityKey(root.network.rssiDbm), false) }] : [])
        }
    }

    // Écran 10 : la ligne du téléchargement.
    Item { visible: root.showDownload; width: 1; height: 36 }
    EntryReveal {
        visible: root.showDownload
        started: root.entryStarted
        delay: IdleTheme.entryDelays.downloadRow
        width: 660; height: 20
        Row {
            spacing: 12
            ProgressRing {
                progress: root.download.progress || 0
                Behavior on progress { NumberAnimation { duration: IdleTheme.progressUpdate; easing.type: Easing.Linear } }
            }
            IdleText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.download.kind === "install" ? qsTr("Installation de %1").arg(root.download.title)
                                                        : qsTr("Mise à jour de %1").arg(root.download.title)
                textStyle: IdleTheme.downloadRow
                color: IdleTheme.textStatus
            }
            IdleText {
                anchors.verticalCenter: parent.verticalCenter
                text: F.percent(root.download.progress || 0) + " · " + F.etaShort(root.download.etaSeconds || 0)
                textStyle: IdleTheme.downloadRow
                color: IdleTheme.textTertiary
                tabular: true
            }
        }
    }
}
