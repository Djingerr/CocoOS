.pragma library

// Animation de démarrage « le O » : tout l'état visuel en fonction du temps t (ms).
// Port direct du JavaScript de docs/boot-animation/prototype.html, qui fait foi ;
// fonctions pures, sans dessin. Testé dans docs/ui/ambiant/harness/tst_BootTimeline.qml.
// Positions : en pixels du logo (repère Logotype), à l'échelle du logo affiché.

var T = {
    drawStart: 250, drawDur: 750,       // révélation conique du glyphe O
    pause: 150,                         // le O seul, complet
    anticip: 80,                        // élan : compression de 2 %
    oResp: 620, oZeta: 0.9,             // ressort du O (réponse, amortissement)
    lResp: 520, lZeta: 0.78,            // ressort des lettres
    firstDelay: 20, stagger: 45, sDelay: 40,
    settle: 600,
    holdLogo: 400,
    loaderDelay: 400, loaderMin: 600,   // chargeur : attente avant de l'afficher, durée minimale
    closeDur: 520, breath: 380, trackA: 0.18,
    spinCycle: 1333, spinRot: 1568,
    exitDur: 750,
    wakeStart: 80, wakeDur: 900,
    oScale: 1.25,                       // taille du O pendant son tracé
    statusScale: 0.2                    // taille du logo dans la barre haute
}
var drawEnd = T.drawStart + T.drawDur                                   // 1000
var anticStart = drawEnd + T.pause                                      // 1150
var release = anticStart + T.anticip                                    // 1230
var revealEnd = release + T.firstDelay + 3 * T.stagger + T.settle       // 1985
var normalE = revealEnd + T.holdLogo                                    // 2385
var loaderShowAt = normalE + T.loaderDelay                              // 2785

var ORANGE = [242 / 255, 128 / 255, 42 / 255]
var BRIGHT = [255 / 255, 176 / 255, 118 / 255]

// ---------- Easings, ressort ----------
function cubicBezier(x1, y1, x2, y2) {
    var cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
    var cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
    var sx = function(t) { return ((ax * t + bx) * t + cx) * t }
    var sy = function(t) { return ((ay * t + by) * t + cy) * t }
    return function(x) {
        if (x <= 0) return 0
        if (x >= 1) return 1
        var lo = 0, hi = 1, t = x
        for (var i = 0; i < 22; i++) {
            t = (lo + hi) / 2
            if (sx(t) < x) lo = t; else hi = t
        }
        return sy(t)
    }
}
var E_OUT = cubicBezier(0.33, 1, 0.68, 1)
var E_INOUT = cubicBezier(0.65, 0, 0.35, 1)
var E_EMPH = cubicBezier(0.2, 0, 0, 1)
var E_DRAW = cubicBezier(0.7, 0, 0.2, 1)
var E_STD = cubicBezier(0.4, 0, 0.2, 1)

// Ressort amorti (départ au repos, vitesse nulle), paramétré comme SwiftUI.
function spring(t, resp, zeta) {
    if (t <= 0) return 0
    var w = 2 * Math.PI / resp, wd = w * Math.sqrt(1 - zeta * zeta)
    return 1 - Math.exp(-zeta * w * t) * (Math.cos(wd * t) + (zeta * w / wd) * Math.sin(wd * t))
}

function clamp01(v) { return v < 0 ? 0 : v > 1 ? 1 : v }
function lerp(a, b, t) { return a + (b - a) * t }
// Mélange de deux couleurs [r, g, b] (0 à 1), multiplié par `m` (luminance).
function mix(a, b, k, m) {
    var l = m === undefined ? 1 : m
    return [lerp(a[0], b[0], k) * l, lerp(a[1], b[1], k) * l, lerp(a[2], b[2], k) * l]
}

// ---------- Tracé du O (250 → 1000) ----------
// len : fraction de tour révélée ; a0 : angle de départ (radians, sens horaire).
function draw(t) {
    var p = clamp01((t - T.drawStart) / T.drawDur)
    return { len: E_DRAW(p), a0: -Math.PI / 2 - 0.6 * (1 - E_OUT(p)) }
}
// Couleur du O : clair pendant le tracé, puis l'accent.
function oColor(t) { return mix(BRIGHT, ORANGE, E_OUT(clamp01((t - drawEnd) / 400))) }

// ---------- Déploiement ----------
// Le O : centre x (de `cx`, le centre de l'écran, à `ocx`, sa place) et échelle.
function oState(t, cx, ocx) {
    var s = T.oScale, x = cx
    if (t >= anticStart && t < release) {
        s = T.oScale * (1 - 0.02 * E_INOUT(clamp01((t - anticStart) / T.anticip)))
    } else if (t >= release) {
        var sp = spring(t - release, T.oResp, T.oZeta)
        s = lerp(T.oScale * 0.98, 1, sp)
        x = lerp(cx, ocx, sp)
    }
    return { x: x, s: s }
}
// Départ de chaque lettre après `release` : C, o, c, o, puis S.
function letterDelay(i) { return i < 4 ? T.firstDelay + i * T.stagger : T.sDelay }
// Une lettre : sortie de derrière le centre courant du O (`oX`) vers son origine
// `fx` ; `lw` : sa largeur d'avance. Visible à partir de son départ.
function letter(t, i, oX, fx, lw) {
    var start = release + letterDelay(i)
    var sp = spring(t - start, T.lResp, T.lZeta)
    return { shown: t >= start, x: lerp(oX - lw / 2, fx, sp), lum: lerp(0.55, 1, clamp01(sp)) }
}

// ---------- Système prêt, chargeur (§5) ----------
// `r` : instant (en t) où le système est prêt, null tant qu'il ne l'est pas.
function loaderShown(r) { return r === null || r === undefined || r > loaderShowAt }
// Fin de l'attente : au plus tôt 600 ms après l'apparition du chargeur.
function completeAt(r) {
    return r === null || r === undefined ? Infinity : Math.max(r, loaderShowAt + T.loaderMin)
}
// Début de la sortie vers la barre haute.
function exitStart(r) {
    if (r === null || r === undefined) return Infinity
    if (r <= loaderShowAt) return Math.max(normalE, r)
    return completeAt(r) + T.closeDur + T.breath
}

// Indicateur indéterminé façon Material, en tours.
function spinner(tau) {
    var D = T.spinCycle, tt = tau + D / 2
    var c = Math.floor(tt / D), u = (tt - c * D) / D
    var head = E_STD(clamp01(u / 0.5)) * 0.75, tail = E_STD(clamp01((u - 0.5) / 0.5)) * 0.75
    var base = c * 0.75 + tau / T.spinRot
    return { tail: base + tail, head: base + head + 0.03 }
}
// Le O de OS en chargeur : il s'ouvre, tourne, se referme une fois prêt, puis pulse.
// vis : présence (0 à 1) ; a0, len : arc (radians, fraction de tour) ; bump : pulsation.
function loader(t, r) {
    var ca = completeAt(r), tau = t - loaderShowAt
    var vis = E_OUT(clamp01(tau / 400)) * (isFinite(ca) ? 1 - E_OUT(clamp01((t - ca) / T.closeDur)) : 1)
    var sp = spinner(tau)
    var tail = lerp(sp.head - 1, sp.tail, E_OUT(clamp01(tau / 450)))    // part du O complet
    var head = sp.head
    if (isFinite(ca))
        head = lerp(head, tail + 1, E_EMPH(clamp01((t - ca) / T.closeDur)))
    var bb = isFinite(ca) ? clamp01((t - ca - T.closeDur) / T.breath) : 0
    var bump = bb > 0 && bb < 1 ? Math.sin(Math.PI * E_OUT(bb)) : 0
    return { vis: vis, a0: -Math.PI / 2 + 2 * Math.PI * (tail - 0.78), len: Math.min(1, head - tail), bump: bump }
}
// Étape en texte : à partir de loaderShowAt + 1500 ; fondu et montée de 4 px à
// chaque changement (`changedAt`), le tout multiplié par la présence du chargeur.
function stepText(t, changedAt, vis) {
    var t0 = loaderShowAt + 1500
    if (t < t0) return { opacity: 0, rise: 4 }
    var k = E_OUT(clamp01((t - Math.max(changedAt, t0)) / 300))
    return { opacity: k * vis * E_OUT(clamp01((t - t0) / 400)), rise: (1 - k) * 4 }
}

// ---------- Sortie vers la barre haute ----------
// Centre du logo sur une Bézier quadratique de `p0` à `p2` ({x, y}), e de 0 à 1.
function exitPos(e, p0, p2) {
    var c = { x: lerp(p0.x, p2.x, 0.25), y: lerp(p0.y, p2.y, 0.8) }
    var u = 1 - e
    return { x: u * u * p0.x + 2 * u * e * c.x + e * e * p2.x, y: u * u * p0.y + 2 * u * e * c.y + e * e * p2.y }
}

// ---------- Sortie de veille ----------
function wake(t) {
    var u = t - T.wakeStart
    var a = E_OUT(clamp01(u / 250))
    return { u: u, opacity: t < T.wakeStart ? 0 : a, lum: lerp(0.55, 1, a),
             oScale: 1 + 0.14 * Math.sin(Math.PI * E_INOUT(clamp01((u - 150) / 500))) }
}

// ---------- Sons (§9) : [{ t, name }] ----------
function soundCues(mode, r) {
    if (mode === "wake") return [{ t: T.wakeStart + 150, name: "open" }]
    var cues = [{ t: drawEnd, name: "close" }, { t: release, name: "open" }]
    if (loaderShown(r) && isFinite(completeAt(r)))
        cues.push({ t: completeAt(r) + T.closeDur * 0.8, name: "close" })
    return cues
}
