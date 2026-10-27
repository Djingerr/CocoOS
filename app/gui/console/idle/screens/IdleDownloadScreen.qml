import QtQuick
import QtQuick.Shapes
import ".."
import "../components"
import "../IdleFormat.js" as F

// Écran 11 : téléchargement seul (pas de partie en cours).
CoverScreen {
    id: root

    readonly property var network: status.network
    readonly property var download: status.download

    game: download.game
    hintAction: qsTr("pour ouvrir l'accueil")
    columnTop: 170

    // Surtitre : flèche de téléchargement qui rebondit + « TÉLÉCHARGEMENT SUR PC-SALON ».
    EntryReveal {
        started: root.entryStarted
        delay: IdleTheme.entryDelays.eyebrow
        width: 660; height: eyebrow.implicitHeight
        Eyebrow {
            id: eyebrow
            text: qsTr("Téléchargement sur %1").arg(root.status.host.name)
            // SVG 12 × 12 (viewBox 20) : la flèche rebondit, le plateau reste.
            Item {
                width: 12; height: 12
                Shape {
                    id: arrowIcon
                    width: 20; height: 20
                    scale: 12 / 20
                    transformOrigin: Item.TopLeft
                    preferredRendererType: Shape.CurveRenderer
                    property real bounce: -1
                    SequentialAnimation on bounce {
                        running: root.animated
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -1; to: 2; duration: IdleTheme.downloadArrowPeriod / 2
                            easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
                        }
                        NumberAnimation {
                            from: 2; to: -1; duration: IdleTheme.downloadArrowPeriod / 2
                            easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
                        }
                    }
                    ShapePath {
                        strokeColor: IdleTheme.accent
                        strokeWidth: 2.4
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: "M10 " + (2.5 + arrowIcon.bounce) + "v10M5.5 " + (8.5 + arrowIcon.bounce)
                                        + " 10 " + (13 + arrowIcon.bounce) + "l4.5-4.5" }
                    }
                    ShapePath {
                        strokeColor: IdleTheme.accent
                        strokeWidth: 2.4
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: "M3 17.5h14" }
                    }
                }
            }
        }
    }
    Item { width: 1; height: 14 }
    GameInfo { game: root.game; entryStarted: root.entryStarted }
    Item { width: 1; height: 56 }

    // Progression : « 42 % », débit et temps restant, barre.
    EntryReveal {
        started: root.entryStarted
        delay: IdleTheme.entryDelays.bigBlock
        width: 660; height: bigBlock.implicitHeight
        Column {
            id: bigBlock
            spacing: 8
            DurationText {
                parts: [{ value: "" + Math.floor((root.download.progress || 0) * 100 + 1e-9), unit: "%" }]
            }
            IdleText {
                text: [root.download.kind === "install" ? qsTr("Installation") : qsTr("Mise à jour"),
                       F.rate(root.download.bytesPerSec || 0), F.eta(root.download.etaSeconds || 0)].join(" · ")
                textStyle: IdleTheme.caption
                color: IdleTheme.textSecondary
                tabular: true
            }
            Item {
                width: 420; height: 16          // 14 px de marge (en plus de l'écart de 8) puis la barre
                HairlineProgress {
                    y: 14
                    progress: root.download.progress || 0
                    animated: root.animated
                }
            }
        }
    }
    Item { width: 1; height: 44 }

    EntryReveal {
        started: root.entryStarted
        delay: IdleTheme.entryDelays.statusLine
        width: 660; height: statusLine.implicitHeight
        StatusLine {
            id: statusLine
            items: [ { icon: "monitor", text: root.status.host.name + " · " + F.hostState(root.status.host) },
]
                   .concat(root.network.latencyMs >= 0 ? [{ icon: "signal", text: F.latency(root.network.latencyMs) }] : [])
                   .concat(root.network.kind === "wifi"
                           ? [{ icon: "wifi", text: F.wifiQuality(root.network.quality
                                    || F.wifiQualityKey(root.network.rssiDbm), false) }] : [])
        }
    }
}
