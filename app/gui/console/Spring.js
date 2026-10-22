.pragma library

// Ressorts physiques des micro-interactions (raideur k, amortissement c, masse m) :
// port de spring() de docs/ui/micro-interactions/micro-interactions-prototype.html,
// qui fait foi. Fonctions pures, testées dans docs/ui/ambiant/harness/tst_Spring.qml.
//
// SpringAnimation de Qt n'est pas ce ressort : elle intègre par pas de 16 ms et garde
// sa vitesse quand la cible change. On convertit donc le ressort en courbe pour
// Easing.BezierSpline : une NumberAnimation ordinaire le joue (Behavior, Transition),
// et repart de la valeur courante quand la cible change, comme une transition CSS.
//
//   NumberAnimation { duration: Theme.springBouncy.duration
//                     easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springBouncy.curve }

// Qt garde au plus 10 segments par BezierSpline (QEasingCurve) : au-delà, il écrit
// hors de son tableau et l'interface se bloque.
var SEGMENTS = 10

function params(k, c, m) {
    var w0 = Math.sqrt(k / m), z = c / (2 * Math.sqrt(k * m))
    // Durée : l'enveloppe de l'oscillation est tombée à 1/250 (0,4 % de la course).
    return { w0: w0, z: z, T: Math.log(250) / (z * w0) }
}

// Position (0 → 1) et vitesse (course par seconde) à t secondes.
function state(k, c, m, t) {
    var p = params(k, c, m), w0 = p.w0, z = p.z
    if (z < 1) {
        var wd = w0 * Math.sqrt(1 - z * z), e = Math.exp(-z * w0 * t)
        return { x: 1 - e * (Math.cos(wd * t) + (z * w0 / wd) * Math.sin(wd * t)),
                 v: e * Math.sin(wd * t) * w0 * w0 / wd }
    }
    var f = Math.exp(-w0 * t)
    return { x: 1 - f * (1 + w0 * t), v: f * w0 * w0 * t }
}

// Durée en ms, arrondie comme dans le prototype.
function duration(k, c, m) {
    return Math.round(params(k, c, m).T * 1000)
}

// Courbe pour easing.bezierCurve : segments de Hermite (position et vitesse exactes à
// chaque bout). Le dernier point vaut 1, comme la dernière valeur du prototype.
function curve(k, c, m) {
    var T = params(k, c, m).T, h = 1 / SEGMENTS, out = []
    for (var i = 0; i < SEGMENTS; i++) {
        var a = state(k, c, m, i * h * T), b = state(k, c, m, (i + 1) * h * T)
        var end = i === SEGMENTS - 1 ? 1 : b.x
        out.push(i * h + h / 3, a.x + a.v * T * h / 3,
                 (i + 1) * h - h / 3, end - b.v * T * h / 3,
                 (i + 1) * h, end)
    }
    return out
}

// Jeton de Theme.qml : { duration, curve }.
function make(k, c, m) {
    m = m || 1
    return { duration: duration(k, c, m), curve: curve(k, c, m) }
}
