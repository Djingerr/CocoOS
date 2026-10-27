pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../.."
import "../components"
import "../IdleFormat.js" as F

// Lanceur autonome de l'écran de veille, pour le développement et les captures :
//
//   qml app/gui/console/idle/preview/IdlePreview.qml -- --state game|gameDownload|download|rest
//       [--now 2026-10-27T21:46:00] [--no-drift] [--grab-after 3000 --grab captures/09_jeu.png]
//   qml app/gui/console/idle/preview/IdlePreview.qml -- --component CoverCard
//   … --network 4g|5g (réseau mobile au lieu du Wi-Fi), --pad playstation|nintendo (glyphe du bouton)
//
// --state : l'écran de veille complet sur le mock (par défaut). --component : un composant
// seul (EntryReveal, BlurredBackdrop, CoverCard, StatusLine, KeyHint, TopRightClock,
// DurationText, ProgressRing, HairlineProgress, GlassCapsule, GradientText, Glow).
// --grab-after : capture la fenêtre 1280 × 720 tant de ms après le démarrage, puis quitte ;
// avec --layout, écrit d'abord dans le journal (ligne « IDLE_LAYOUT ») la boîte de chaque texte
// (cf. layout_check.py).
// Touches : 1 à 4 changent l'état, R rejoue l'entrée, B bascule IdleTheme.entryBlur ; toute
// autre touche fait sortir l'écran de veille (wakeRequested, puis il revient après 1 s).
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
    readonly property string component: args.component || "IdleScreen"

    width: 1280; height: 720
    visible: true
    color: "black"
    title: "IdlePreview — " + component

    IdleStatusMock {
        id: status
        scenario: win.args.state || "game"
        networkKind: win.args.network || ""
        fixedNow: win.args.now ? new Date(win.args.now) : null
    }

    Binding { when: win.args.pad !== undefined; target: Theme; property: "buttonLayout"; value: win.args.pad }
    // Fond noir dans le contenu : grabToImage ne capture pas la couleur de la fenêtre.
    Rectangle { anchors.fill: parent; color: "black" }
    Item {
        id: stage
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            var states = { "1": "game", "2": "gameDownload", "3": "download", "4": "rest" }
            if (states[event.text]) status.scenario = states[event.text]
            else if (event.key === Qt.Key_R) win.replay()
            else if (event.key === Qt.Key_B) {
                IdleTheme.entryBlur = !IdleTheme.entryBlur
                console.info("IdlePreview : entryBlur", IdleTheme.entryBlur)
            }
            else if (loader.item as IdleScreen) (loader.item as IdleScreen).exit()
        }
        Loader {
            id: loader
            anchors.fill: parent
            sourceComponent: {
                switch (win.component) {
                case "IdleScreen": return idleScreen
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
        id: idleScreen
        IdleScreen {
            status: status
            drift: win.args["no-drift"] === undefined
            onWakeRequested: {
                console.info("IdlePreview : wakeRequested")
                if (win.args["grab-after"] === undefined) comeBack.start()
            }
        }
    }
    Timer { id: comeBack; interval: 1000; onTriggered: win.replay() }

    Component {
        id: entryReveal
        Item {
            EntryReveal {
                id: reveal
                x: 520; y: 199
                width: 660; height: 72
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

    // Boîte de chaque IdleText dans la fenêtre (enveloppe des coins projetés) : celle de sa
    // ligne d'icône pour une ligne d'état, celle de la pastille pour le glyphe de bouton.
    function dumpLayout() {
        var out = []
        function box(item) {
            var xs = [], ys = []
            ;[[0, 0], [item.width, 0], [0, item.height], [item.width, item.height]].forEach(function(c) {
                var p = item.mapToItem(win.contentItem, c[0], c[1])
                xs.push(p.x); ys.push(p.y)
            })
            var x = Math.min.apply(null, xs), y = Math.min.apply(null, ys)
            return { x: x, y: y, w: Math.max.apply(null, xs) - x, h: Math.max.apply(null, ys) - y }
        }
        function walk(item) {
            if (!item || !item.visible || item.opacity === 0) return
            if (item instanceof IdleText && item.text !== "") {
                var target = item, parent = item.parent
                if (parent && parent.children.length > 0 && parent.children[0] instanceof StatusIcon) target = parent
                else if (parent && parent.width === 22 && parent.height === 22) target = parent
                var b = box(target)
                out.push({ text: item.label.text, x: b.x, y: b.y, w: b.w, h: b.h,
                           size: item.textStyle.size, weight: item.textStyle.weight })
            }
            for (var i = 0; i < item.children.length; i++) walk(item.children[i])
        }
        walk(win.contentItem)
        console.info("IDLE_LAYOUT " + JSON.stringify(out))
    }

    Timer {
        running: win.args["grab-after"] !== undefined
        interval: Number(win.args["grab-after"])
        onTriggered: if (win.args.layout !== undefined) win.dumpLayout()
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
