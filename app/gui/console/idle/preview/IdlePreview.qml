pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../components"
import "../IdleFormat.js" as F

// Lanceur autonome de l'écran de veille, pour le développement et les captures :
//
//   qml app/gui/console/idle/preview/IdlePreview.qml -- --component CoverCard
//       [--now 2026-10-27T21:46:00] [--grab-after 3000 --grab captures/x.png]
//
// --component : un composant seul (EntryReveal, BlurredBackdrop, CoverCard, StatusLine,
// KeyHint, TopRightClock, DurationText, ProgressRing, HairlineProgress, GlassCapsule,
// GradientText, Glow). --grab-after : capture la fenêtre 1280 × 720 tant de ms après le
// démarrage, puis quitte. R rejoue les entrées, B bascule IdleTheme.entryBlur.
Window {
    id: win

    readonly property var args: {
        var out = {}, a = Qt.application.arguments
        for (var i = 0; i < a.length; i++) {
            if (a[i].indexOf("--") !== 0 || a[i] === "--") continue
            var next = a[i + 1]
            if (next !== undefined && next.indexOf("--") !== 0) { out[a[i].slice(2)] = next; i++ }
            else out[a[i].slice(2)] = true
        }
        return out
    }
    readonly property string component: args.component || "CoverCard"

    width: 1280; height: 720
    visible: true
    color: "black"
    title: "IdlePreview — " + component

    IdleStatusMock {
        id: status
        scenario: win.args.state || "game"
        fixedNow: win.args.now ? new Date(win.args.now) : null
    }

    // Fond noir dans le contenu : grabToImage ne capture pas la couleur de la fenêtre.
    Rectangle { anchors.fill: parent; color: "black" }
    Item {
        id: stage
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_R) win.replay()
            else if (event.key === Qt.Key_B) IdleTheme.entryBlur = !IdleTheme.entryBlur
        }
        Loader {
            id: loader
            anchors.fill: parent
            sourceComponent: {
                switch (win.component) {
                case "EntryReveal": return entryReveal
                case "BlurredBackdrop": return backdrop
                case "CoverCard": return coverCard
                case "StatusLine": return statusLine
                case "KeyHint": return keyHint
                case "TopRightClock": return topRightClock
                case "DurationText": return durationText
                case "ProgressRing": return progressRing
                case "HairlineProgress": return hairline
                case "GlassCapsule": return capsule
                case "GradientText": return gradientText
                case "Glow": return glow
                }
                console.warn("IdlePreview : composant inconnu", win.component)
                return null
            }
        }
    }
    function replay() {
        loader.active = false
        loader.active = true
    }

    readonly property var game: status.session.active ? status.session.game : status.download.game

    Component {
        id: entryReveal
        Item {
            EntryReveal {
                id: reveal
                x: 520; y: 199
                width: 660; height: 72
                Component.onCompleted: play()
                Text {
                    text: "Minecraft"
                    color: IdleTheme.textPrimary
                    font.family: IdleTheme.fontFamily
                    font.pixelSize: IdleTheme.title.size
                    font.weight: IdleTheme.title.weight
                    font.letterSpacing: IdleTheme.title.letterSpacing
                }
            }
        }
    }
    Component {
        id: backdrop
        BlurredBackdrop {
            saturation: IdleTheme.backdropSaturation
            vignette: true
            layerScale: 1.25
            Image {
                anchors.fill: parent
                source: win.game ? win.game.coverUrl : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width, height)
            }
        }
    }
    Component {
        id: coverCard
        Item {
            CoverCard {
                x: 112; y: 104
                source: win.game ? win.game.coverUrl : ""
                label: qsTr("Jaquette %1 · 600 × 848").arg(win.game ? win.game.title : "")
            }
        }
    }
    Component {
        id: statusLine
        Item {
            StatusLine {
                x: 520; y: 474
                items: [ { icon: "monitor", text: status.host.name },
                         { icon: "signal", text: F.latency(status.network.latencyMs) },
                         { icon: "wifi", text: F.wifiQuality(status.network.quality, false) } ]
            }
        }
    }
    Component {
        id: keyHint
        Item {
            KeyHint {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 654
            }
        }
    }
    Component {
        id: topRightClock
        Item {
            TopRightClock {
                anchors.right: parent.right; anchors.rightMargin: 56
                y: 36
                now: status.now
                batteryPercent: status.battery.percent
            }
        }
    }
    Component {
        id: durationText
        Item {
            DurationText {
                x: 520; y: 355
                parts: F.sessionParts((status.now - status.session.connectedAt) / 1000)
            }
        }
    }
    Component {
        id: progressRing
        Item {
            ProgressRing { x: 520; y: 530; progress: 0.68 }
            ProgressRing {
                x: 560; y: 527
                width: 26; height: 26; radius: 11; strokeWidth: 3
                trackColor: IdleTheme.ringTrackRest
                progress: 0.82
            }
        }
    }
    Component {
        id: hairline
        Item {
            HairlineProgress { x: 520; y: 470; progress: 0.42 }
        }
    }
    Component {
        id: capsule
        Item {
            GlassCapsule {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 452
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 22; rightPadding: 22
                    text: "PC-Salon"
                    color: IdleTheme.textPrimary
                    font.family: IdleTheme.fontFamily
                    font.pixelSize: IdleTheme.capsuleTitle.size
                    font.weight: IdleTheme.capsuleTitle.weight
                }
            }
        }
    }
    Component {
        id: gradientText
        Item {
            GradientText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 147
                text: F.clock(status.now)
                boxHeight: IdleTheme.restClock.size * IdleTheme.restClock.lineHeight
                font.family: IdleTheme.fontFamily
                font.pixelSize: IdleTheme.restClock.size
                font.weight: IdleTheme.restClock.weight
                font.letterSpacing: IdleTheme.restClock.letterSpacing
                font.features: { "tnum": 1 }
            }
        }
    }
    Component {
        id: glow
        BlurredBackdrop {
            readonly property var g: IdleTheme.restGlow
            box: Qt.rect(g.centerX - g.width / 2, g.top, g.width, g.height)
            blurPx: g.blurCssPx
            layerOpacity: g.opacity
            ShaderEffect {
                anchors.fill: parent
                property size canvasSize: Qt.size(width, height)
                property point center: Qt.point(width / 2, height / 2)
                property size radii: Qt.size(width / 2 * Math.SQRT2, height / 2 * Math.SQRT2)
                property real stopAt: IdleTheme.restGlow.stopAt
                property color color: IdleTheme.accent
                fragmentShader: "../shaders/glowsource.frag.qsb"
            }
        }
    }

    Timer {
        running: win.args["grab-after"] !== undefined
        interval: Number(win.args["grab-after"])
        onTriggered: win.contentItem.grabToImage(function(result) {
            if (!result.saveToFile(win.args.grab)) console.warn("IdlePreview : capture impossible", win.args.grab)
            Qt.quit()
        })
    }
}
