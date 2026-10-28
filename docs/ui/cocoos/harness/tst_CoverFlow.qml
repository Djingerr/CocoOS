import QtQuick
import QtTest
import "../../../../app/gui/console"

// Carrousel 3D (CoverFlow) : emplacements de la maquette, déplacement interruptible, butée,
// saut de lettre au-delà de 30 jeux, A au relâché, rien à lancer sans jeu.
Item {
    width: 1280; height: 800

    ListModel { id: games }
    CoverFlow { id: flow; anchors.fill: parent; model: games; focus: true }
    SignalSpy { id: launches; target: flow; signalName: "launchRequested" }
    SignalSpy { id: details; target: flow; signalName: "detailsRequested" }

    TestCase {
        name: "CoverFlow"
        when: windowShown

        function fill(names) {
            games.clear()
            names.forEach(function(n) { games.append({ name: n, boxart: "", cover: "" }) })
            flow.currentIndex = 0
            flow.position = 0
            wait(0)                                     // (la sélection se borne après le remplissage)
        }
        function init() {
            fill(["Hades", "Celeste", "Hollow Knight", "Minecraft", "Forza Horizon 5", "Stardew Valley", "Elden Ring"])
            flow.currentIndex = 3
            flow.position = 3
            launches.clear(); details.clear()
        }

        // Au repos : les emplacements d'AccueilCarrousel (renderVals), au pixel près.
        function test_slotsMatchTheMockup() {
            var center = flow.slotAt(0), side = flow.slotAt(1), far = flow.slotAt(3)
            compare([center.w, center.h, center.dx, center.brightness, center.angle], [240, 340, 0, 1, 0])
            compare([side.w, side.h, side.dx, side.brightness, side.angle], [190, 269, 250, 0.6, 38])
            compare([far.w, far.h, far.dx, far.brightness, far.angle], [140, 198, 580, 0.2, 50])
            var half = flow.slotAt(0.5)                 // entre deux : interpolé
            compare(half.w, 215)
            compare(half.angle, 19)
            compare(flow.activeRect, Qt.rect(520, 96, 240, 340))
        }

        // perspective(900px) rotateY : le bord le plus loin rétrécit, le centre ne bouge pas.
        function test_tiltMatchesCss() {
            var m = flow.tilt(190, 269, -38)
            var at = function(x, y) {
                var v = m.times(Qt.vector4d(x, y, 0, 1))
                return Qt.point(v.x / v.w, v.y / v.w)
            }
            var c = at(95, 134.5)
            fuzzyCompare(c.x, 95, 0.01); fuzzyCompare(c.y, 134.5, 0.01)
            var left = at(0, 0), right = at(190, 0)
            verify(right.y < left.y)                    // rotateY(-38°) : le bord droit est le plus proche
        }

        // Un nouvel appui repart de la position courante (MotionInterruption).
        function test_moveIsInterruptible() {
            keyClick(Qt.Key_Right)
            compare(flow.currentIndex, 4)
            wait(Theme.coverMove / 3)
            var mid = flow.position
            verify(mid > 3 && mid < 4.2)
            keyClick(Qt.Key_Left)
            compare(flow.currentIndex, 3)
            fuzzyCompare(flow.position, mid, 0.1)       // pas de saut
            tryCompare(flow, "position", 3, Theme.coverMove + 200)
        }

        // En bout de liste : la sélection reste, le carrousel recule puis revient.
        function test_edgeBumps() {
            flow.currentIndex = 6
            keyClick(Qt.Key_Right)
            compare(flow.currentIndex, 6)
            tryVerify(function() { return flow.bump < -10 }, Theme.coverBumpOut + 100)
            tryCompare(flow, "bump", 0, Theme.coverBumpOut + Theme.coverBumpBack + 200)
        }

        function test_aLaunchesOnReleaseAndDownOpensDetails() {
            keyPress(Qt.Key_Return)
            compare(launches.count, 0)
            verify(flow.pressing)
            keyRelease(Qt.Key_Return)
            compare(launches.count, 1)
            compare(launches.signalArguments[0][0], 3)
            keyClick(Qt.Key_Down)
            compare(details.count, 1)
        }

        // Saut de lettre : rien sous 31 jeux, sinon la première jaquette de la lettre voisine.
        function test_letterJump() {
            flow.jump(1)
            compare(flow.currentIndex, 3)               // 7 jeux : pas de saut
            var names = []
            for (var i = 0; i < 40; i++)
                names.push(String.fromCharCode(65 + Math.floor(i / 4)) + " jeu " + i)   // A×4, B×4…
            fill(names)
            flow.currentIndex = 5                       // un « B »
            flow.jump(1)
            compare(flow.currentIndex, 8)               // le premier « C »
            flow.jump(-1)
            compare(flow.currentIndex, 4)               // le premier « B »
            flow.jump(-1)
            compare(flow.currentIndex, 0)               // le premier « A »
        }

        // Sans jeu (Favoris vide) : A et bas ne font rien.
        function test_emptyDoesNothing() {
            fill([])
            keyClick(Qt.Key_Return)
            keyClick(Qt.Key_Down)
            compare(launches.count, 0)
            compare(details.count, 0)
        }
    }
}
