import QtQuick
import QtTest
import "../../../../app/gui/console"

// La souris dans les panneaux : survoler une ligne y amène la sélection, mais seulement si
// le pointeur a vraiment bougé (Pointer.js) ; la légende cliquée fait ce que fait le bouton.
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tst_Hover.qml
Item {
    width: Theme.canvasWidth; height: Theme.canvasHeight

    OptionsSheet {
        id: sheet
        anchors.fill: parent
        tabs: [ { label: "Flux", rows: [
            { key: "a", label: "Première", options: ["1", "2"], index: 0 },
            { key: "b", label: "Deuxième", options: ["1", "2"], index: 0 },
            { key: "c", label: "Troisième", options: ["1", "2"], index: 0 } ] } ]
    }
    SignalSpy { id: closes; target: sheet; signalName: "closed" }

    TestCase {
        name: "Hover"
        when: windowShown

        function find(from, test) {
            for (var i = 0; i < from.children.length; i++) {
                var c = from.children[i]
                if (test(c)) return c
                var deeper = find(c, test)
                if (deeper) return deeper
            }
            return null
        }
        function line(i) {
            return find(sheet, function(c) { return c.row !== undefined && c.focused !== undefined && c.index === i })
        }

        function init() {
            sheet.open()
            closes.clear()
            wait(Theme.sheetSlide + 50)
            mouseMove(line(0), 40, 10)          // le pointeur repart de la première ligne, en focus
            wait(50)
        }
        function cleanup() { sheet.close() }

        function test_hoverMovesTheSelection() {
            mouseMove(line(1), 20, 10)
            compare(sheet.current, 1)
            mouseMove(line(2), 20, 10)
            compare(sheet.current, 2)
        }

        // Une ligne qui passe sous un pointeur immobile (liste qui défile au clavier) ne
        // prend pas la sélection.
        function test_stillPointerKeepsTheKeyboardSelection() {
            mouseMove(line(1), 20, 10)
            compare(sheet.current, 1)
            keyClick(Qt.Key_Down)
            compare(sheet.current, 2)
            wait(50)
            mouseMove(line(1), 20, 10)          // même place : pas un vrai déplacement
            compare(sheet.current, 2)
        }

        function test_clickOnTheHoveredRowChangesItsValue() {
            var changes = []
            var record = function(key, index) { changes.push(key + "=" + index) }
            sheet.changed.connect(record)
            mouseMove(line(1), 20, 10)
            mouseClick(line(1), 20, 10)
            sheet.changed.disconnect(record)
            compare(changes, ["b=1"])
        }

        function test_legendBClosesThePanel() {
            var legend = find(sheet, function(c) { return c.hints !== undefined && c.triggered !== undefined })
            legend.triggered("B")
            compare(closes.count, 1)
            verify(!sheet.opened)
        }
    }
}
