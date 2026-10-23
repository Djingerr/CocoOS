import QtQuick
import QtTest
import "../../../../app/gui/console"

// L'île de notification de la barre haute : elle s'ouvre sur un événement système, se
// referme seule (ou avec B), une nouvelle notification remplace l'ancienne sans refermer ;
// rien quand les notifications ne sont pas permises (entrée, panneau, lancement, veille).
Item {
    width: Theme.canvasWidth; height: 200

    StatusBar { id: bar; width: parent.width; hostName: "Djinger"; connected: true }
    Image { id: islandShadow; source: "../../../../app/gui/console/shadows/island.png" }

    TestCase {
        name: "StatusBar"
        when: windowShown

        // État de départ posé sans notification (permise ensuite).
        function init() {
            bar.dismiss()
            tryCompare(bar, "islandOpen", false, 1000)
            bar.notificationsAllowed = false
            bar.connected = true; bar.hostLost = false
            bar.controllerCount = 0; bar.controllerBattery = -1
            bar.batteryPercent = 80; bar.charging = false
            wait(50)
            bar.notificationsAllowed = true
        }

        // L'ombre pré-calculée (make-shadows.py) correspond à l'île de Theme.qml.
        function test_shadowMatchesTheIsland() {
            tryCompare(islandShadow, "status", Image.Ready)
            compare(islandShadow.implicitWidth, 2 * (Theme.islandSize.width + 2 * Theme.islandShadowPad))
            compare(islandShadow.implicitHeight, 2 * (Theme.islandSize.height + 2 * Theme.islandShadowPad))
        }

        function test_opensThenClosesByItself() {
            bar.notify({ icon: "pad", title: "Essai" })
            verify(bar.islandOpen && bar.islandContentShown)
            wait(Theme.islandHold - 300)
            verify(bar.islandOpen)
            tryCompare(bar, "islandOpen", false, 1000)
        }

        function test_replacesWithoutClosing() {
            bar.notify({ icon: "pad", title: "Première" })
            wait(500)
            bar.notify({ icon: "host", title: "Seconde" })
            verify(bar.islandOpen)
            compare(bar.notification.title, "Première")        // le temps que l'ancienne sorte…
            tryCompare(bar, "islandContentShown", true, Theme.islandSwap + 200)
            compare(bar.notification.title, "Seconde")         // …puis la nouvelle
            verify(bar.islandOpen)
        }

        function test_bCloses() {
            bar.notify({ icon: "pad", title: "Essai" })
            verify(bar.dismiss())
            verify(!bar.islandContentShown)
            tryCompare(bar, "islandOpen", false, Theme.islandCloseDelay + 300)
            verify(!bar.dismiss())                              // déjà fermée : B fait autre chose
        }

        function test_systemEvents() {
            bar.controllerCount = 1; bar.controllerFamily = "playstation"
            tryCompare(bar, "islandOpen", true, 200)
            compare(bar.notification.title, "Manette connectée")
            compare(bar.notification.text, "PlayStation")
            bar.dismiss()

            bar.connected = false
            tryVerify(function() { return bar.islandContentShown && bar.notification.title === "Djinger perdu" }, 500)
            bar.connected = true
            tryVerify(function() { return bar.islandContentShown && bar.notification.title === "Djinger retrouvé" }, 500)
            bar.dismiss()

            bar.batteryPercent = 15
            tryVerify(function() { return bar.islandContentShown && bar.notification.title === "Batterie faible" }, 500)
            compare(bar.notification.value, "15 %")
        }

        function test_nothingWhenNotAllowed() {
            bar.notificationsAllowed = false
            bar.controllerCount = 2
            bar.connected = false
            wait(200)
            verify(!bar.islandOpen)
            bar.notificationsAllowed = true                     // et pas de rattrapage après coup
            wait(200)
            verify(!bar.islandOpen)
        }
    }
}
