import QtQuick
import QtTest
import "../../../../app/gui/console"

// Les glyphes suivent la manette : lettres de la Xbox, lettres inversées de la
// Nintendo (Moonlight lit les boutons par position), symboles de la PlayStation.
TestCase {
    name: "ButtonGlyph"

    ButtonGlyph { id: a; label: "A" }
    ButtonGlyph { id: y; label: "Y" }

    function cleanup() { Theme.buttonLayout = "xbox" }

    function test_layouts() {
        compare([a.face, y.face], ["A", "Y"])
        Theme.buttonLayout = "nintendo"
        compare([a.face, y.face], ["B", "X"])
        Theme.buttonLayout = "playstation"
        compare([a.face, y.face], ["cross", "triangle"])
    }
}
