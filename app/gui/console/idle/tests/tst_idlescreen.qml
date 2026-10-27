pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import ".."
import "../screens"

// Machine d'état de l'écran de veille (phase 3) : écran choisi selon l'état, fondu enchaîné
// puis entrée du nouvel écran, sortie sur une touche ou un clic (wakeRequested).
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input app/gui/console/idle/tests/tst_idlescreen.qml
Item {
    id: window
    width: 1280; height: 720

    IdleStatusMock { id: mock; fixedNow: new Date(2026, 9, 27, 21, 46) }
    Component {
        id: idleComponent
        IdleScreen { anchors.fill: parent; status: mock; drift: false; focus: true }
    }

    TestCase {
        name: "IdleScreen"
        when: windowShown

        function screenKind(item) {
            if (item instanceof IdleGameScreen) return item.showDownload ? "gameDownload" : "game"
            if (item instanceof IdleDownloadScreen) return "download"
            if (item instanceof IdleRestScreen) return "rest"
            return "?"
        }

        function test_statesAndCrossfade() {
            mock.scenario = "game"
            var idle = createTemporaryObject(idleComponent, window)
            tryVerify(function() { return idle.current !== null })
            compare(screenKind(idle.current), "game")
            verify(idle.current.entryStarted)                  // première apparition : l'entrée part tout de suite
            ;["gameDownload", "download", "rest", "game"].forEach(function(state) {
                var before = idle.current
                mock.scenario = state
                compare(screenKind(idle.current), state)
                verify(idle.current !== before)
                verify(!idle.current.entryStarted)             // l'entrée attend la fin du fondu
                tryVerify(function() { return idle.current.entryStarted && idle.previous === null }, 1500)
                compare(idle.current.opacity, 1)
            })
        }

        // Des données remplies juste après la création (le mock le fait dans son
        // Component.onCompleted) : le premier écran est le bon, sans fondu depuis le repos.
        Component { id: lateStatus; IdleStatus {} }
        function test_firstScreenWaitsForTheData() {
            var late = createTemporaryObject(lateStatus, window)
            var idle = createTemporaryObject(idleComponent, window, { status: late })
            late.session = { active: true, connectedAt: new Date(), game: { title: "Hades II" } }
            tryVerify(function() { return idle.current !== null })
            compare(screenKind(idle.current), "game")
            compare(idle.previous, null)
            verify(idle.current.entryStarted)
        }

        function test_scaleKeepsTheGrid() {
            var screen = createTemporaryObject(screenComponent, window)
            var idle = createTemporaryObject(idleComponent, screen)
            compare(IdleTheme.scale, 1.5)                      // min(1920/1280, 1200/720)
            tryVerify(function() { return idle.current !== null })
            compare(idle.current.width, 1280)                  // 16:10 : la grille s'étire en hauteur…
            compare(idle.current.height, 800)
            idle.destroy()
            wait(0)
        }

        function test_anyKeyExits() {
            var idle = createTemporaryObject(idleComponent, window)
            idle.forceActiveFocus()
            var spy = createTemporaryObject(spyComponent, window, { target: idle })
            keyClick(Qt.Key_Down)
            verify(idle.leaving)
            spy.wait(1000)
            compare(spy.count, 1)
            keyClick(Qt.Key_Return)                           // une seule sortie
            wait(400)
            compare(spy.count, 1)
        }

        function test_clickExits() {
            var idle = createTemporaryObject(idleComponent, window)
            var spy = createTemporaryObject(spyComponent, window, { target: idle })
            mouseClick(idle)
            spy.wait(1000)
            compare(spy.count, 1)
        }

        Component { id: screenComponent; Item { width: 1920; height: 1200 } }
        Component { id: spyComponent; SignalSpy { signalName: "wakeRequested" } }
    }
}
