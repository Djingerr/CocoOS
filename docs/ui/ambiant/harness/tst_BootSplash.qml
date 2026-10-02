import QtQuick
import QtTest
import "../../../../app/gui/console"

// BootSplash : le temps avance, A l'accélère (×4) jusqu'à la fin, la séquence garde
// la manette, et se termine (exitStarted puis finished) sur le calendrier du prototype.
Item {
    width: 1280; height: 720

    BootSplash { id: splash; anchors.fill: parent; autoStart: false; systemReady: true }
    SignalSpy { id: exits; target: splash; signalName: "exitStarted" }
    SignalSpy { id: ends; target: splash; signalName: "finished" }
    SignalSpy { id: sounds; target: splash; signalName: "soundCue" }

    TestCase {
        name: "BootSplash"
        when: windowShown

        function init() { exits.clear(); ends.clear(); sounds.clear() }

        function test_timeSkipAndEnd() {
            splash.start()
            splash.running = false                  // le temps est avancé à la main
            splash.advance(100)
            compare(splash.t, 100)
            splash.forceActiveFocus()
            keyClick(Qt.Key_Right)                  // avalée, sans effet
            keyClick(Qt.Key_Return)                 // A : ×4
            verify(splash.skipping)
            splash.advance(100)
            compare(splash.t, 500)
            splash.advance(600)                     // 2900 : sons de 1000 et 1230 ms joués
            compare(sounds.count, 2)
            compare(sounds.signalArguments[0][0], "close")
            compare(exits.count, 1)                 // E + 250 = 2635 dépassé
            compare(ends.count, 0)
            splash.advance(100)                     // 3300 > E + 750
            compare(ends.count, 1)
            verify(splash.done && !splash.skipping && !splash.visible)
        }

        // Système en retard : le chargeur paraît à 2785 ms, reste au moins 600 ms, se
        // referme une fois le système prêt, pulse, puis la sortie commence.
        function test_loaderWaitsForTheSystem() {
            splash.systemReady = false
            splash.start()
            splash.running = false
            splash.advance(2700)
            verify(!splash.loading)
            splash.advance(300)                     // 3000
            verify(splash.loading)
            verify(!isFinite(splash.exitAt))        // pas de sortie tant que le système n'est pas prêt
            splash.running = true                   // (prend l'instant où il devient prêt)
            splash.systemReady = true
            splash.running = false
            compare(splash.readyAt, 3000)
            compare(splash.exitAt, Math.max(3000, 2785 + 600) + 520 + 380)   // 600 ms au moins
            splash.advance(500)                     // 3500 : toujours le chargeur
            verify(splash.loading)
            splash.advance(800)                     // 4300 : la sortie a commencé
            verify(!splash.loading)
            compare(sounds.signalArguments[sounds.count - 1][0], "close")    // fermeture du O
            splash.systemReady = true
        }
    }
}
