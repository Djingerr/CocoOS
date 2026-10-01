import QtQuick
import QtTest
import "../../../../app/gui/console"

// Logique de l'étagère : répétition qui accélère à l'appui prolongé, arrêt au
// relâchement, rebond en bout de liste, sélection conservée pendant le chargement,
// et ressort identique à celui du prototype (même intégrateur, mêmes paramètres).
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tst_GameShelf.qml
Item {
    width: Theme.canvasWidth; height: Theme.canvasHeight

    ListModel { id: games }
    GameShelf { id: shelf; width: parent.width; model: games }
    SignalSpy { id: launches; target: shelf; signalName: "launchRequested" }

    TestCase {
        name: "GameShelf"
        when: windowShown

        function init() {
            games.clear()
            for (var i = 0; i < 10; i++)
                games.append({ boxart: "" })
            shelf.currentIndex = 0
            shelf.bump = 0
            launches.clear()
            shelf.forceActiveFocus()
        }

        function test_holdRepeatsThenStopsOnRelease() {
            keyPress(Qt.Key_Right)
            compare(shelf.currentIndex, 1)      // premier déplacement immédiat
            wait(300)
            compare(shelf.currentIndex, 1)      // rien avant 360 ms
            wait(400)                           // ≈ 700 ms : répétitions à 360, 470, 570 et 660 ms
            verify(shelf.currentIndex >= 4 && shelf.currentIndex <= 6, "index " + shelf.currentIndex)
            keyRelease(Qt.Key_Right)
            var stopped = shelf.currentIndex
            wait(300)
            compare(shelf.currentIndex, stopped)
        }

        function test_bumpAtBothEnds() {
            keyClick(Qt.Key_Left)
            compare(shelf.currentIndex, 0)
            verify(shelf.bump < 0)
            tryCompare(shelf, "bump", 0, 1000)
            shelf.currentIndex = 9
            keyClick(Qt.Key_Right)
            compare(shelf.currentIndex, 9)
            verify(shelf.bump > 0)
            tryCompare(shelf, "bump", 0, 1000)
        }

        function test_selectionKeptWhileModelLoads() {
            games.clear()
            shelf.currentIndex = 3
            for (var i = 0; i < 10; i++)
                games.append({ boxart: "" })
            compare(shelf.currentIndex, 3)
            games.remove(2, 8)                  // le modèle rétrécit : on retombe sur le dernier
            tryCompare(shelf, "currentIndex", 1, 1000)   // (la vue compte à sa prochaine mise en page)
        }

        // Le prototype avance par pas fixes de 16 ms : v += spring·écart − damping·v,
        // puis x += v·0,016 (classe Spring de ambiant-prototype.html). Le
        // SpringAnimation de Qt doit suivre la même courbe, image par image.
        function test_springMatchesPrototype() {
            var proto = [0], x = 0, v = 0
            for (var n = 0; n < 200; n++) {
                v += Theme.springStrength * (1 - x) - Theme.springDamping * v
                x += v * 0.016
                proto.push(x)
            }
            tryCompare(shelf, "pos", 0, 3000)   // au repos avant de partir
            var samples = [], t0 = Date.now()
            var record = function() { samples.push([Date.now() - t0, shelf.pos]) }
            shelf.posChanged.connect(record)
            shelf.currentIndex = 1
            tryCompare(shelf, "pos", 1, 3000)
            shelf.posChanged.disconnect(record)
            verify(samples.length > 20, samples.length + " images")
            // L'animation démarre à l'image qui suit le changement : on cale l'origine.
            var best = 1
            for (var off = 0; off <= 40; off++) {
                var worst = 0
                for (var i = 0; i < samples.length; i++) {
                    var step = Math.max(0, Math.min(200, Math.round((samples[i][0] - off) / 16)))
                    worst = Math.max(worst, Math.abs(samples[i][1] - proto[step]))
                }
                best = Math.min(best, worst)
            }
            verify(best < 0.02, "écart maximal au prototype : " + best.toFixed(4) + " index")
        }

        // Une vignette créée en défilant est là d'emblée ; seule la cascade d'entrée
        // fait apparaître les vignettes en fondu.
        Component { id: lateThumb; Appear { shown: true; animateInitially: false } }
        Component { id: entryThumb; Appear { shown: true } }
        function test_thumbnailCreatedWhileScrollingIsVisibleAtOnce() {
            var late = createTemporaryObject(lateThumb, shelf)
            compare(late.opacity, 1)
            var entering = createTemporaryObject(entryThumb, shelf)
            verify(entering.opacity < 1)
            tryCompare(entering, "opacity", 1, 2000)
            late.shown = false                       // …mais elle s'efface bien en fondu ensuite
            verify(late.opacity > 0)
            tryCompare(late, "opacity", 0, 2000)
        }

        function test_returnLaunchesCurrentGame() {
            shelf.currentIndex = 4
            keyClick(Qt.Key_Return)
            compare(launches.count, 1)
            compare(launches.signalArguments[0][0], 4)
        }
    }
}
