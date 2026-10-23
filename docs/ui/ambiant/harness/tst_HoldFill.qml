import QtQuick
import QtTest
import "../../../../app/gui/console"

// Appui maintenu (HoldFill) : tenu jusqu'au bout, il se remplit en Theme.holdDuration,
// rebondit, puis confirme ; lâché avant, il se vide en Theme.holdDrain sans rien faire.
// Le remplissage affiché démarre lentement (progression^Theme.holdCurve).
Item {
    width: 500; height: 100

    HoldFill { id: hold; width: 400; height: 60; label: "Éteindre" }
    SignalSpy { id: completions; target: hold; signalName: "completed" }

    TestCase {
        name: "HoldFill"
        when: windowShown

        function init() { hold.holding = false; hold.reset(); completions.clear() }

        function test_heldToTheEndConfirms() {
            var start = Date.now()
            hold.holding = true
            tryCompare(hold, "done", true, Theme.holdDuration + 500)
            verify(Date.now() - start >= Theme.holdDuration - 50, "rempli trop tôt")
            compare(completions.count, 0)               // d'abord le rebond…
            tryCompare(completions, "count", 1, Theme.springBouncy.duration + 500)
            hold.holding = false                        // …puis lâcher ne change plus rien
            compare(hold.progress, 1)
        }

        function test_interruptedHoldDrains() {
            hold.holding = true
            tryVerify(function() { return hold.progress > 0.5 }, Theme.holdDuration)
            hold.holding = false
            tryCompare(hold, "progress", 0, Theme.holdDrain + 300)
            wait(Theme.springBouncy.duration)
            compare(completions.count, 0)
        }

        function test_fillStartsSlowly() {
            hold.progress = 0.5
            compare(hold.children[0].width, hold.width * Math.pow(0.5, Theme.holdCurve))
            verify(hold.children[0].width < hold.width / 2)
        }
    }
}
