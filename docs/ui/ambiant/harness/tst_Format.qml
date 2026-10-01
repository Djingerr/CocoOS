import QtQuick
import QtTest
import "../../../../app/gui/console/Format.js" as Format

// Mise en forme des données de bibliothèque affichées dans le bloc héros.
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tst_Format.qml
TestCase {
    name: "Format"

    function test_sourceName() {
        compare(Format.sourceName("steam"), "Steam")
        compare(Format.sourceName("epic"), "Epic Games")
        compare(Format.sourceName("humble"), "Humble")      // inconnue : capitale initiale
        compare(Format.sourceName(null), "")
    }

    function test_playtime() {
        compare(Format.playtime(412 * 3600 + 1200), "412 h de jeu")
        compare(Format.playtime(7260), "2 h de jeu")
        compare(Format.playtime(35 * 60), "35 min de jeu")
        compare(Format.playtime(0), "")
        compare(Format.playtime(undefined), "")
    }

    function test_lastPlayed() {
        var now = new Date(2026, 8, 30, 12, 0)               // 30 septembre 2026, midi
        compare(Format.lastPlayed("2026-09-30T09:05:00", now), "Aujourd'hui, 09:05")
        compare(Format.lastPlayed("2026-09-29T23:40:00", now), "Hier, 23:40")
        compare(Format.lastPlayed("2026-09-28T23:59:00", now), "Il y a 2 jours")
        compare(Format.lastPlayed("2026-09-17T08:00:00", now), "Il y a 13 jours")
        compare(Format.lastPlayed("2026-09-16T08:00:00", now), "Il y a 2 semaines")
        compare(Format.lastPlayed("2026-08-26T08:00:00", now), "Il y a 5 semaines")
        compare(Format.lastPlayed("2026-08-01T08:00:00", now), "Il y a 2 mois")
        compare(Format.lastPlayed("2025-10-05T08:00:00", now), "Il y a 12 mois")
        compare(Format.lastPlayed("2025-09-30T08:00:00", now), "Il y a 1 an")
        compare(Format.lastPlayed("2023-01-01T08:00:00", now), "Il y a 3 ans")
        compare(Format.lastPlayed(null, now), "")            // jamais joué
        compare(Format.lastPlayed("n'importe quoi", now), "")
    }

    function test_networkQuality() {
        compare(Format.networkQuality(-1, -1), "")             // pas de mesure
        compare(Format.networkQuality(9, 2), "good")
        compare(Format.networkQuality(9, -1), "good")          // une seule mesure : pas de gigue
        compare(Format.networkQuality(35, 4), "fair")
        compare(Format.networkQuality(12, 11), "fair")         // proche, mais irrégulier
        compare(Format.networkQuality(80, 3), "poor")
        compare(Format.networkQuality(15, 30), "poor")
    }
}
