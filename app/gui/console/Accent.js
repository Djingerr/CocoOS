.pragma library

// Accent d'un jeu (MotionAccent) : la couleur dominante de sa jaquette (AmbientColor), ramenée
// dans la plage lisible des maquettes — saturation au moins 0,45, luminosité HSL de 0,58 à 0,72,
// puis éclaircie s'il le faut jusqu'à 4,5:1 sur le noir. Couleur invalide (jaquette grise) :
// renvoie `fallback`.

var MIN_SATURATION = 0.45
var LIGHTNESS = [0.58, 0.72]
var MIN_CONTRAST = 4.5

// Luminance relative (WCAG) d'une couleur QML.
function luminance(c) {
    var lin = function(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}
function contrastOnBlack(c) { return (luminance(c) + 0.05) / 0.05 }

function readable(c, fallback) {
    if (!c || !c.valid) return fallback
    var h = Math.max(0, c.hslHue)
    var s = Math.max(c.hslSaturation, MIN_SATURATION)
    var l = Math.min(Math.max(c.hslLightness, LIGHTNESS[0]), LIGHTNESS[1])
    var out = Qt.hsla(h, s, l, 1)
    while (contrastOnBlack(out) < MIN_CONTRAST && l < 0.95) {
        l += 0.02
        out = Qt.hsla(h, s, l, 1)
    }
    return out
}
