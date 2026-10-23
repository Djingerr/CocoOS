import QtQuick
import QtTest
import "../../../../app/gui/console"

// Pressable : il s'écrase à l'appui et revient au relâché ; refuse() le secoue selon les
// positions du prototype, puis il revient en place.
Item {
    width: 400; height: 200

    Pressable { id: pressable; x: 100; y: 80; width: 120; height: 40 }

    TestCase {
        name: "Pressable"
        when: windowShown

        function shift() { return pressable.transform[0].x }

        function test_shakeFollowsThePrototype() {
            var keys = Theme.shakeKeys
            for (var i = 0; i < keys.length; i++) {
                pressable.shakeProgress = i / (keys.length - 1)
                compare(shift(), keys[i])
            }
            pressable.shakeProgress = 0.5 / (keys.length - 1)
            compare(shift(), (keys[0] + keys[1]) / 2)
            pressable.shakeProgress = 1
        }

        function test_refuseShakesThenRests() {
            pressable.refuse()
            tryVerify(function() { return shift() !== 0 }, 300)
            tryCompare(pressable, "shakeProgress", 1, Theme.shakeDuration + 500)
            compare(shift(), 0)
        }

        function test_pressThenRelease() {
            pressable.down = true
            tryCompare(pressable, "scale", Theme.pressScale, 500)
            pressable.down = false
            tryVerify(function() { return pressable.scale > 1 }, 1000)   // le rebond dépasse
            tryCompare(pressable, "scale", 1, Theme.springBouncy.duration + 500)
        }
    }
}
