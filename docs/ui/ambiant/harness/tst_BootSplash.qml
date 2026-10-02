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
    }
}
