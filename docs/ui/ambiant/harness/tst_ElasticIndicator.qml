import QtQuick
import QtTest
import "../../../../app/gui/console"

// L'indicateur élastique (soulignement des onglets) : ses deux bords rejoignent la
// cible séparément, le bord avant d'abord, d'où l'étirement en route, dans les deux
// sens ; sans animation, il est d'emblée en place.
Item {
    width: 600; height: 100

    ElasticIndicator { id: indicator; height: 3; targetLeft: 0; targetRight: 50 }

    TestCase {
        name: "ElasticIndicator"
        when: windowShown

        // Largeur maximale pendant le déplacement vers [left, right].
        function widest(left, right) {
            var widest = 0
            var watch = function() { widest = Math.max(widest, indicator.width) }
            indicator.widthChanged.connect(watch)
            indicator.targetLeft = left
            indicator.targetRight = right
            tryVerify(function() { return indicator.leftEdge === left && indicator.rightEdge === right }, 2000)
            indicator.widthChanged.disconnect(watch)
            return widest
        }

        function test_stretchesOnTheWayInBothDirections() {
            indicator.animated = false
            indicator.targetLeft = 0; indicator.targetRight = 50
            tryCompare(indicator, "width", 50)
            indicator.animated = true
            var wide = widest(200, 260)                 // vers la droite : le bord droit mène
            verify(wide > 60 + 20, "largeur maximale " + wide)
            compare(indicator.x, 200)
            wide = widest(0, 50)                        // vers la gauche : le bord gauche mène
            verify(wide > 60 + 20, "largeur maximale " + wide)
            compare(indicator.width, 50)
        }

        function test_inPlaceWithoutAnimation() {
            indicator.animated = false
            indicator.targetLeft = 300; indicator.targetRight = 380
            tryCompare(indicator, "x", 300, 100)
            compare(indicator.width, 80)
        }
    }
}
