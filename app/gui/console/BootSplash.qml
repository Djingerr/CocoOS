import QtQuick
import "BootTimeline.js" as Boot

// Animation de démarrage « le O » (docs/boot-animation/BOOT_ANIMATION.md, le
// prototype fait foi) : le O de « OS » se trace, les lettres en sortent, puis le
// logo laisse la place à l'accueil. Tout est fonction du temps `t` (ms), avancé
// image par image ; BootTimeline.js en donne l'état. Le A de la manette accélère
// (×4) ; les autres touches sont avalées le temps de la séquence.
// Remplit son parent (la fenêtre) ; repère du prototype : 1280 × 720, k = hauteur / 720.
// Aucune dépendance Moonlight.
FocusScope {
    id: root

    property string mode: "cold"            // "cold" (démarrage) | "wake" (sortie de veille)
    property bool systemReady: false         // l'accueil sait quoi montrer
    property string stepText: ""
    property bool showStepText: false
    property Item statusBarLogo: null        // logo de la barre haute, cible de la sortie
    property bool autoStart: true            // démarre seul dès que les polices sont là

    signal exitStarted()                     // E + 250 ms : l'accueil commence son entrée
    signal finished()                        // fin de la sortie
    signal soundCue(string name)             // "close" | "open"

    property real t: 0
    property real speed: 1
    property bool skipping: false
    property bool running: false
    property bool done: false
    property real readyAt: -1                // t où le système est devenu prêt, -1 : pas encore
    property bool exitAnnounced: false

    readonly property real k: height / Theme.bootRefHeight
    readonly property var ready: readyAt < 0 ? null : readyAt
    readonly property real exitAt: Boot.exitStart(ready)

    function start() {
        t = 0
        done = false
        skipping = false
        exitAnnounced = false
        readyAt = systemReady ? 0 : -1
        running = true
    }
    // Bouton A : la partie animée ×4, jusqu'à la fin de la sortie. L'attente du
    // système, elle, n'est pas raccourcie.
    function skip() { if (!done) skipping = true }
    // Fin immédiate (tests, ou rien à montrer).
    function finishNow() {
        if (done) return
        running = false
        done = true
        if (!exitAnnounced) { exitAnnounced = true; exitStarted() }
        finished()
    }

    function advance(dt) {
        var previous = t
        t += dt * speed * (skipping ? 4 : 1)
        var cues = Boot.soundCues(mode, ready)
        for (var i = 0; i < cues.length; i++)
            if (previous < cues[i].t && t >= cues[i].t) soundCue(cues[i].name)
        if (!exitAnnounced && t >= exitAt + 250) {
            exitAnnounced = true
            exitStarted()
        }
        if (t >= exitAt + Boot.T.exitDur) {
            skipping = false
            running = false
            done = true
            finished()
        }
    }

    onSystemReadyChanged: if (systemReady && readyAt < 0 && running) readyAt = t
    Component.onCompleted: if (autoStart && Theme.fontsReady) start()
    Connections {
        target: Theme
        function onFontsReadyChanged() { if (root.autoStart && Theme.fontsReady && !root.running && !root.done) root.start() }
    }

    FrameAnimation {
        running: root.running
        property bool focused: false
        onTriggered: {
            // (après la mise en place de la pile d'écrans, qui donne le focus à l'accueil)
            if (!focused) { focused = true; root.forceActiveFocus() }
            root.advance(frameTime * 1000)
        }
    }
    Keys.onPressed: function(event) {
        event.accepted = true
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !event.isAutoRepeat)
            root.skip()
    }

    visible: !done
    // ponytail: sortie provisoire (fondu) ; le vol vers la barre haute arrive à l'étape 5.
    opacity: 1 - Boot.clamp01((t - exitAt) / Boot.T.exitDur)

    Rectangle { anchors.fill: parent; color: Theme.background }

    // --- Le logo : lettres et O, état tiré de la chronologie ---
    Logotype {
        id: logo
        fontSize: Theme.logoSize * root.k
        width: implicitWidth; height: implicitHeight
        // Centré sur l'écran ; origine calée au pixel.
        x: Math.round((root.width - geo.w) / 2)
        y: Math.round((root.height - height) / 2)

        readonly property real cx: root.width / 2 - x            // centre de l'écran, repère du logo
        readonly property var oState: Boot.oState(root.t, cx, geo.ocx)

        oShift: oState.x - geo.ocx
        oScale: oState.s
        oVisible: root.t >= Boot.T.drawStart
        // ponytail: le tracé conique du O (ConicMask) arrive à l'étape 3 ; d'ici là, un fondu.
        opacity: 1
        oColor: { var c = Boot.oColor(root.t); return Qt.rgba(c[0], c[1], c[2], root.t < Boot.drawEnd ? Boot.draw(root.t).len : 1) }

        letters: {
            var t = root.t
            if (t >= Boot.revealEnd) {
                // Au repos : chaque lettre calée au pixel.
                var rest = geo.xs.concat([geo.xS])
                return rest.map(function(x) { return { x: Math.round(x), lum: 1, shown: true } })
            }
            var out = []
            for (var i = 0; i < 5; i++) {
                var fx = i < 4 ? geo.xs[i] : geo.xS
                var l = Boot.letter(t, i, oState.x, fx, geo.widths[i])
                out.push({ x: l.x, lum: l.lum, shown: t >= Boot.release && l.shown })
            }
            return out
        }
    }
}
