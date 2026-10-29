import QtQuick
import QtTest
import "../../../../app/gui/console"
import "../../../../app/gui/console/settings"

// Listes groupées (SettingsList) et Réglages plein écran (SettingsScreen) : cartes, intitulés et
// notes à leur place, lignes repliées sautées ; la page suit la rubrique, → / LB / RB y entrent,
// B revient au menu puis referme.
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -import ../../ambiant/harness/stubs -input tst_Settings.qml
Item {
    width: 1280; height: 800

    SettingsList {
        id: list
        width: 436; height: 600
        metrics: Theme.listSheet
        focus: true
        rows: [
            { key: "a", label: "A", options: ["1", "2"], index: 0, group: "g1", section: "Premier" },
            { key: "b", label: "B", toggle: true, options: ["Non", "Oui"], index: 0, group: "g1", footnote: "Une note." },
            { key: "c", label: "C", options: ["1", "2"], index: 0, group: "g2", section: "Second", hidden: true },
            { key: "d", label: "D", slider: true, value: 10, min: 0, max: 100, stops: [], format: "%1 %", group: "g2" },
            { key: "e", label: "E", hold: true, group: "g3" } ]
    }
    SignalSpy { id: changes; target: list; signalName: "changed" }

    SettingsScreen {
        id: settings
        width: 1280; height: 800
        pages: [
            { key: "wifi", label: "Wi-Fi", tile: { color: "#2F7CF6", icon: "wifi" }, value: "Maison", group: "n",
              rows: [ { key: "w", label: "Réseau", action: true, group: "x" } ] },
            { key: "pads", label: "Manettes", tile: { color: "#5E5CE6", icon: "gamepad" }, group: "n",
              rows: [ { key: "buttons", label: "Glyphes", choice: true, options: ["Xbox", "PlayStation"], index: 0, group: "c" } ] },
            { key: "empty", label: "Vide", tile: { color: "#8E8E93", icon: "general" }, group: "s", rows: [] } ]
    }
    SignalSpy { id: picks; target: settings; signalName: "changed" }
    SignalSpy { id: closes; target: settings; signalName: "closed" }

    TestCase {
        name: "Settings"
        when: windowShown

        // Deux cartes sous leur intitulé, la note sous la première ; la ligne repliée ne compte
        // pas (D ouvre la seconde carte, qui garde l'intitulé « Second » de C).
        function test_layout() {
            var l = list.layout, m = Theme.listSheet
            compare(l.cards.length, 3)
            compare(l.sections.map(function(s) { return s.text }), ["Premier", "Second"])
            compare(l.sections[0].y, 0)
            var top = Theme.listSectionHeight + Theme.listSectionBelow
            compare(l.cards[0].y, top)
            compare(l.cards[0].height, 2 * m.row)
            compare(l.notes[0].text, "Une note.")
            compare(l.notes[0].y, top + 2 * m.row + Theme.listNoteTop)
            verify(l.items[0].first && l.items[1].last && !l.items[1].first)
            compare(l.items[2].height, 0)
            verify(l.items[3].first && l.items[3].last)
            compare(l.items[3].height, m.slider)
            compare(l.cards[1].y, l.notes[0].y + list.noteHeight + m.cardGap + top)
        }

        // Bas saute la ligne repliée ; un appui bref ne répète rien (la flèche n'est pas restée
        // « tenue ») ; en bout de liste, rien ne bouge.
        function test_navigationSkipsFoldedRowsAndDoesNotRepeat() {
            list.forceActiveFocus()
            list.reset()
            changes.clear()
            keyClick(Qt.Key_Down)
            compare(list.current, 1)
            keyClick(Qt.Key_Down)
            compare(list.current, 3)                    // C est repliée
            wait(Theme.repeatDelay + 2 * Theme.repeatInterval)
            compare(changes.count, 0)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Down)
            compare(list.current, 4)
            keyClick(Qt.Key_Up); keyClick(Qt.Key_Right)   // le curseur : un pas
            compare(changes.count, 1)
            compare([changes.signalArguments[0][0], changes.signalArguments[0][1]], ["d", 11])
        }

        function test_settingsScreen() {
            settings.open("pads")
            verify(settings.opened && !settings.contentFocused)
            compare(settings.page, 1)
            keyClick(Qt.Key_Up)                         // la page suit la rubrique
            compare(settings.page, 0)
            compare(settings.rows[0].key, "w")
            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Right)                      // → : dans la page
            verify(settings.contentFocused)
            keyClick(Qt.Key_Right)
            compare(picks.count, 1)
            compare([picks.signalArguments[0][0], picks.signalArguments[0][1]], ["buttons", 1])
            keyClick(Qt.Key_PageUp)                     // LB : au menu
            verify(!settings.contentFocused)
            keyClick(Qt.Key_Down)                       // une rubrique vide : on n'y entre pas
            keyClick(Qt.Key_PageDown)
            verify(!settings.contentFocused)
            keyClick(Qt.Key_Escape)                     // B : refermés
            verify(!settings.opened)
            compare(closes.count, 1)
        }
    }
}
