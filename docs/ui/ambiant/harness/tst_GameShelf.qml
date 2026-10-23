import QtQuick
import QtTest
import "../../../../app/gui/console"

// Logique de l'étagère : répétition qui accélère à l'appui prolongé, arrêt au
// relâchement, butée de la piste en bout de liste, sélection conservée pendant le
// chargement, et le carrousel (anneau fixe, piste qui défile, focus).
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tst_GameShelf.qml
Item {
    width: Theme.canvasWidth; height: Theme.canvasHeight

    ListModel { id: games }
    GameShelf { id: shelf; width: parent.width; model: games }
    SignalSpy { id: launches; target: shelf; signalName: "launchRequested" }
    Item { id: other }
    Image { id: thumbShadow; source: "../../../../app/gui/console/shadows/thumb.png" }

    TestCase {
        name: "GameShelf"
        when: windowShown

        function init() {
            games.clear()
            for (var i = 0; i < 10; i++)
                games.append({ boxart: "" })
            shelf.animated = false              // la piste revient d'emblée au début
            shelf.currentIndex = 0
            shelf.bump = 0
            shelf.animated = true
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
            verify(shelf.bump < 0)                      // la piste bute…
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

        function listView() {
            for (var i = 0; i < shelf.children.length; i++)
                if (shelf.children[i].contentX !== undefined) return shelf.children[i]
            return null
        }
        function thumbAt(i) {
            listView().forceLayout()            // (les vignettes se créent à la mise en page suivante)
            return listView().itemAtIndex(i).children[0]
        }
        function ring() {
            var found = null
            var walk = function(from) {
                for (var i = 0; i < from.children.length && !found; i++) {
                    if (from.children[i].boxWidth !== undefined) found = from.children[i]
                    else walk(from.children[i])
                }
            }
            walk(shelf)
            return found
        }

        // L'anneau reste à la marge gauche ; la piste défile pour y amener la vignette active.
        function test_ringStaysAndTrackScrolls() {
            var r = ring()
            var ringCenter = function() { return r.mapToItem(shelf, r.width / 2, 0).x }
            var x0 = ringCenter()
            compare(x0, Theme.margin + Theme.shelfThumbSize.width / 2)
            shelf.currentIndex = 3
            compare(ringCenter(), x0)                       // l'anneau ne bouge pas
            tryCompare(shelf, "scroll", 3 * shelf.pitch, 2000)
            shelf.currentIndex = 9
            tryCompare(shelf, "scroll", 9 * shelf.pitch, 2000)
            tryVerify(function() {
                return Math.abs(ringCenter() - thumbAt(9).mapToItem(shelf, Theme.shelfThumbSize.width / 2, 0).x) < 0.5
            }, 2000, "l'anneau est centré sur la vignette active")
            shelf.currentIndex = 0
            compare(shelf.activeRect.x, Theme.margin - Theme.shelfThumbSize.width * (Theme.shelfActiveScale - 1) / 2)
        }

        // Avec la manette : la vignette active grandit, les autres s'estompent, l'anneau est
        // là. Sans elle, tout revient et l'anneau s'efface en rétrécissant.
        function test_focusLightsTheCurrentThumbnailAndTheRing() {
            shelf.currentIndex = 2
            tryCompare(thumbAt(2), "scale", Theme.shelfActiveScale, 1500)
            tryCompare(thumbAt(1), "opacity", Theme.shelfRestOpacity, 1500)
            compare(thumbAt(1).scale, 1)
            tryCompare(ring(), "opacity", 1, 1000)
            other.forceActiveFocus()
            tryCompare(thumbAt(2), "scale", 1, 1500)
            tryCompare(thumbAt(1), "opacity", 1, 1500)
            tryCompare(ring(), "opacity", 0, 1000)
            compare(ring().scale, Theme.shelfRingHiddenScale)
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

        // Un jeu déplacé en tête (épinglé, joué) : la vignette sélectionnée est bien à sa
        // place, au début de la piste.
        function test_currentThumbStaysInPlaceAfterReorder() {
            var list = listView()
            shelf.currentIndex = 3
            games.move(3, 0, 1)
            shelf.currentIndex = 0
            tryCompare(shelf, "scroll", 0, 3000)
            wait(50)
            compare(Math.round(list.itemAtIndex(0).mapToItem(shelf, 0, 0).x), Theme.margin)
            games.insert(0, { boxart: "" })      // une app ajoutée devant la sélection
            shelf.currentIndex = 1
            tryCompare(shelf, "scroll", shelf.pitch, 3000)
            wait(50)
            compare(Math.round(list.itemAtIndex(1).mapToItem(shelf, 0, 0).x), Theme.margin)
        }

        function test_returnLaunchesCurrentGame() {
            shelf.currentIndex = 4
            keyClick(Qt.Key_Return)
            compare(launches.count, 1)
            compare(launches.signalArguments[0][0], 4)
        }

        // A agit au relâché, et seulement après un appui fait ici : le relâché d'un A
        // qui a fermé un panneau, ou un appui interrompu (focus parti), ne lance rien.
        function test_launchesOnReleaseOnly() {
            keyPress(Qt.Key_Return)
            verify(shelf.pressing)
            compare(launches.count, 0)
            tryCompare(thumbAt(0), "scale", Theme.shelfTapScale, 500)       // la vignette active s'écrase…
            keyRelease(Qt.Key_Return)
            verify(!shelf.pressing)
            compare(launches.count, 1)
            tryCompare(thumbAt(0), "scale", Theme.shelfActiveScale, Theme.springSnappy.duration + 500)   // …et revient

            keyRelease(Qt.Key_Return)                   // relâché sans appui
            compare(launches.count, 1)

            keyPress(Qt.Key_Return)
            other.forceActiveFocus()
            verify(!shelf.pressing)
            shelf.forceActiveFocus()
            keyRelease(Qt.Key_Return)
            compare(launches.count, 1)
        }

        // L'ombre pré-calculée (make-shadows.py) correspond à la vignette de Theme.qml.
        function test_shadowMatchesTheThumbnail() {
            tryCompare(thumbShadow, "status", Image.Ready)
            compare(thumbShadow.implicitWidth, 2 * (Theme.shelfThumbSize.width + 2 * Theme.shelfShadowPad))
            compare(thumbShadow.implicitHeight, 2 * (Theme.shelfThumbSize.height + 2 * Theme.shelfShadowPad))
        }

        // Reflet : il balaie la vignette active une fois, Theme.sheenDelay après un
        // déplacement (comme le prototype) ; un nouveau déplacement le remet à zéro, et sans
        // la manette il ne part pas.
        function test_sheenSweepsOnceAfterAMove() {
            keyClick(Qt.Key_Right)
            compare(shelf.sheen, 0)
            wait(Theme.sheenDelay - 150)
            compare(shelf.sheen, 0)
            tryVerify(function() { return shelf.sheen > 0 && shelf.sheen < 1 }, 400)
            keyClick(Qt.Key_Right)                      // on bouge : remis à zéro
            compare(shelf.sheen, 0)
            tryCompare(shelf, "sheen", 1, Theme.sheenDelay + Theme.sheenDuration + 500)   // une fois…
            wait(Theme.sheenDelay + 200)
            compare(shelf.sheen, 1)                     // …puis il reste hors de la vignette

            keyClick(Qt.Key_Left)
            other.forceActiveFocus()                    // la manette part (panneau, veille…)
            wait(Theme.sheenDelay + 200)
            compare(shelf.sheen, 0)
        }
    }
}
