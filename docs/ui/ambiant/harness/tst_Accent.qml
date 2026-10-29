import QtQuick
import QtTest
import "../../../../app/gui/console/Accent.js" as Accent

// Accent d'un jeu (MotionAccent) : la couleur de la jaquette ramenée dans une plage lisible.
TestCase {
    name: "Accent"

    function test_keepsTheMockupColors() {
        // Les accents des maquettes sont déjà dans la plage : ils ne bougent (presque) pas.
        ["#7BC96F", "#8FB3DA", "#FFA24D"].forEach(function(hex) {
            var c = Accent.readable(Qt.color(hex), "red")
            var ref = Qt.color(hex)
            verify(Math.abs(c.r - ref.r) < 0.02 && Math.abs(c.g - ref.g) < 0.02 && Math.abs(c.b - ref.b) < 0.02, hex + " → " + c)
        })
    }
    function test_darkOrDullColorsBecomeReadable() {
        ["#1A2540", "#3A0505", "#0000FF", "#556070"].forEach(function(hex) {
            var c = Accent.readable(Qt.color(hex), "red")
            verify(Accent.contrastOnBlack(c) >= 4.5, hex + " : " + Accent.contrastOnBlack(c))
            verify(c.hslSaturation >= 0.44 && c.hslLightness <= 0.96, hex)
        })
    }
    function test_tooBrightIsToned() {
        var c = Accent.readable(Qt.color("#FFE8D0"), "red")
        verify(c.hslLightness <= 0.721)
    }
    function test_invalidFallsBack() {
        compare(Accent.readable(undefined, "#F2802A"), "#F2802A")
    }
}
