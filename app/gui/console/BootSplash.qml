import QtQuick
import "BootTimeline.js" as Boot

// Animation de démarrage « le O » (docs/boot-animation/BOOT_ANIMATION.md, le
// prototype fait foi) : le O de « OS » se trace, les lettres en sortent, puis le
// logo vole jusqu'à celui de la barre haute pendant que l'accueil entre dessous.
// En sortie de veille (`mode: "wake"`), seul le logo de la barre haute s'anime. Tout est fonction du temps `t` (ms), avancé
// image par image ; BootTimeline.js en donne l'état. Si le système tarde, le O devient
// le chargeur (au moins 600 ms), puis se referme. Le A de la manette accélère
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
    property bool entryOpen: false           // l'accueil peut entrer (à partir de exitStarted)

    readonly property real k: height / Theme.bootRefHeight
    readonly property var ready: readyAt < 0 ? null : readyAt
    readonly property real exitAt: Boot.exitStart(ready)
    // Système en retard : le O de OS devient le chargeur (§5), jusqu'à la sortie.
    readonly property bool loading: t >= Boot.revealEnd && t > Boot.loaderShowAt && t < exitAt
                                    && Boot.loaderShown(ready)
    readonly property var loaderState: loading ? Boot.loader(t, ready) : null
    property real stepChangedAt: 0
    onStepTextChanged: stepChangedAt = t

    function start() {
        t = 0
        done = false
        skipping = false
        exitAnnounced = false
        entryOpen = false
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
        if (!exitAnnounced) { exitAnnounced = true; entryOpen = true; exitStarted() }
        restoreStatusLogo()
        finished()
    }

    // Sortie de veille : le logo de la barre haute, en fondu, luminance et O qui respire.
    function driveStatusLogo() {
        if (!statusBarLogo) return
        var w = Boot.wake(t)
        statusBarLogo.opacity = w.opacity
        statusBarLogo.lum = w.lum
        statusBarLogo.oScale = w.oScale
    }
    function restoreStatusLogo() {
        if (!statusBarLogo || mode !== "wake") return
        statusBarLogo.opacity = 1
        statusBarLogo.lum = 1
        statusBarLogo.oScale = 1
    }

    // Début de l'entrée de l'accueil et fin de la séquence, selon la variante.
    readonly property real entryAt: mode === "wake" ? Boot.T.wakeStart : exitAt + 250
    readonly property real endAt: mode === "wake" ? Boot.T.wakeStart + Boot.T.wakeDur : exitAt + Boot.T.exitDur

    function advance(dt) {
        var previous = t
        t += dt * speed * (skipping ? 4 : 1)
        var cues = Boot.soundCues(mode, ready)
        for (var i = 0; i < cues.length; i++)
            if (previous < cues[i].t && t >= cues[i].t) soundCue(cues[i].name)
        if (mode === "wake")
            driveStatusLogo()
        if (!exitAnnounced && t >= entryAt) {
            exitAnnounced = true
            entryOpen = true
            exitStarted()
        }
        if (t >= endAt) {
            skipping = false
            running = false
            done = true
            restoreStatusLogo()
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
            // (après la mise en place de la pile d'écrans, qui donne le focus à l'accueil ;
            // en sortie de veille, la manette reste à l'accueil)
            if (!focused && root.mode === "cold") { focused = true; root.forceActiveFocus() }
            root.advance(frameTime * 1000)
        }
    }
    Keys.onPressed: function(event) {
        event.accepted = true
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !event.isAutoRepeat)
            root.skip()
    }

    visible: !done

    // Fond noir : il s'efface quand l'accueil commence à entrer, dessous.
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: root.mode === "wake" ? (root.t < Boot.T.wakeStart ? 1 : 0)
                                      : 1 - Boot.E_OUT(Boot.clamp01((root.t - root.entryAt) / Theme.entryTextFade))
    }

    // --- Sortie : vers le logo de la barre haute (Bézier quadratique, E_EMPH) ---
    readonly property real exitProgress: Boot.E_EMPH(Boot.clamp01((t - exitAt) / Boot.T.exitDur))
    readonly property point flyFrom: Qt.point(logo.screenX + logo.width / 2, logo.screenY + logo.height / 2)
    // Centre et échelle du logo de la barre haute dans ce repère (à défaut : en haut à
    // gauche, comme le prototype).
    readonly property var flyTarget: {
        t
        if (statusBarLogo) {
            var a = statusBarLogo.mapToItem(root, 0, 0)
            var b = statusBarLogo.mapToItem(root, statusBarLogo.width, statusBarLogo.height)
            return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, scale: (b.x - a.x) / logo.width }
        }
        return { x: (40 + Boot.T.statusScale * logo.width / k / 2) * k, y: 42 * k, scale: Boot.T.statusScale }
    }
    readonly property point flyPos: { var p = Boot.exitPos(exitProgress, flyFrom, flyTarget); return Qt.point(p.x, p.y) }
    readonly property real flyScale: Boot.lerp(1, flyTarget.scale, exitProgress)

    // --- Le logo : lettres et O, état tiré de la chronologie ---
    // Les lettres sortent de derrière la silhouette du O : masque elliptique, le temps
    // du déploiement seulement, posé sur un cadre plus grand que le logo (les lettres
    // et leurs ressorts débordent un peu de son rectangle).
    Item {
        id: maskFrame
        readonly property real margin: Math.ceil(0.2 * logo.geo.w)
        visible: root.mode === "cold"
        x: logo.screenX - margin; y: logo.screenY - margin
        width: logo.width + 2 * margin; height: logo.height + 2 * margin
        transform: [
            Scale {
                origin.x: root.flyFrom.x - maskFrame.x; origin.y: root.flyFrom.y - maskFrame.y
                xScale: root.flyScale; yScale: root.flyScale
            },
            Translate { x: root.flyPos.x - root.flyFrom.x; y: root.flyPos.y - root.flyFrom.y }
        ]

        layer.enabled: root.t >= Boot.release && root.t < Boot.revealEnd
        layer.effect: ShaderEffect {
            readonly property size itemSize: Qt.size(maskFrame.width, maskFrame.height)
            readonly property point ellipseCenter: Qt.point(logo.oState.x + maskFrame.margin,
                                                            logo.geo.ocy + maskFrame.margin)
            readonly property size ellipseRadii: Qt.size(logo.geo.rxo * logo.oState.s * 0.97,
                                                         logo.geo.ryo * logo.oState.s * 0.97)
            fragmentShader: "shaders/EllipseMask.frag.qsb"
        }

        Logotype {
            id: logo
            fontSize: Theme.logoSize * root.k
            width: implicitWidth; height: implicitHeight
            // Centré sur l'écran ; origine calée au pixel (repère : le cadre du masque).
            readonly property real screenX: Math.round((root.width - geo.w) / 2)
            readonly property real screenY: Math.round((root.height - height) / 2)
            x: maskFrame.margin
            y: maskFrame.margin

            readonly property real cx: root.width / 2 - screenX      // centre de l'écran, repère du logo
            readonly property var oState: Boot.oState(root.t, cx, geo.ocx)

            // Jusqu'au repos, le O est celui de `drawnO`, dessiné à part (tracé, élan,
            // ressort). Pendant le chargeur, il reste en filigrane sous l'arc.
            oVisible: root.t >= Boot.revealEnd && (!root.loading || root.loaderState.len < 0.999)
            oColor: root.loading ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Boot.T.trackA)
                                 : Theme.accent

            letters: {
                var t = root.t
                if (t >= Boot.revealEnd) {
                    // Au repos : chaque lettre calée au pixel ; un peu éteintes pendant le chargeur.
                    var lum = root.loading ? Boot.lerp(1, 0.82, root.loaderState.vis) : 1
                    var rest = geo.xs.concat([geo.xS])
                    return rest.map(function(x) { return { x: Math.round(x), lum: lum, shown: true } })
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

    // --- Le O, de son tracé à sa place, puis en chargeur ---
    // Rendu à sa taille maximale (celle du tracé, ×1,25) puis réduit : jamais agrandi,
    // donc net. Le masque conique ne sert que pendant le tracé (à l'échelle 1) et
    // tant que l'arc du chargeur n'est pas un tour complet.
    Text {
        id: drawnO
        readonly property real fullScale: Boot.T.oScale
        // Centre du glyphe dans l'élément.
        readonly property var tight: { Theme.fontsReady; bigMetrics.font; return bigMetrics.tightBoundingRect("O") }
        readonly property real localCx: tight.x + tight.width / 2
        readonly property real localCy: baselineOffset + tight.y + tight.height / 2
        // Portion visible : celle du tracé, ou l'arc du chargeur (adouci aux deux bouts).
        readonly property var arc: {
            var l = root.loaderState
            if (l) {
                var f = Math.min(0.025, l.len / 3)
                return { a0: l.a0, len: l.len, head: f, tail: f }
            }
            var d = Boot.draw(root.t)
            return { a0: d.a0, len: d.len, head: 0.035, tail: 0 }
        }
        readonly property real bump: root.loaderState ? root.loaderState.bump : 0

        visible: root.mode === "cold" && ((root.t >= Boot.T.drawStart && root.t < Boot.revealEnd) || root.loading)
        text: "O"
        font: bigMetrics.font
        color: {
            var c = root.loading ? Boot.mix(Boot.ORANGE, Boot.BRIGHT, 0.8 * bump) : Boot.oColor(root.t)
            return Qt.rgba(c[0], c[1], c[2], 1)
        }
        x: logo.screenX + logo.oState.x - localCx
        y: logo.screenY + logo.geo.ocy - localCy
        transform: Scale {
            origin.x: drawnO.localCx; origin.y: drawnO.localCy
            xScale: (root.loading ? 1 + 0.045 * drawnO.bump : logo.oState.s) / drawnO.fullScale
            yScale: xScale
        }

        layer.enabled: visible && drawnO.arc.len < 0.999
        layer.effect: ShaderEffect {
            readonly property point center: Qt.point(drawnO.localCx / drawnO.width, drawnO.localCy / drawnO.height)
            readonly property size itemSize: Qt.size(drawnO.width, drawnO.height)
            readonly property real startAngle: drawnO.arc.a0
            readonly property real len: drawnO.arc.len
            readonly property real featherHead: drawnO.arc.head
            readonly property real featherTail: drawnO.arc.tail
            fragmentShader: "shaders/ConicMask.frag.qsb"
        }

        FontMetrics {
            id: bigMetrics
            font.family: Theme.fontUi
            font.weight: Font.Bold
            font.pixelSize: Theme.logoSize * root.k * Boot.T.oScale
            font.hintingPreference: Font.PreferNoHinting
        }
    }

    // --- Étape en cours, sous le logo, pendant le chargeur (si demandée) ---
    Text {
        readonly property var st: Boot.stepText(root.t, root.stepChangedAt, root.loaderState ? root.loaderState.vis : 0)
        visible: root.showStepText && root.loading && st.opacity > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: logo.screenY + logo.height + (Theme.bootStepTop + st.rise) * root.k - height / 2
        text: root.stepText
        opacity: st.opacity
        color: Theme.bootStepInk
        font.family: Theme.fontUi; font.pixelSize: Theme.bootStepSize * root.k
    }
}
