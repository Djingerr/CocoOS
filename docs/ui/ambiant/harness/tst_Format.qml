import QtQuick
import QtTest
import "../../../../app/gui/console/Format.js" as Format

// Mise en forme des données de bibliothèque affichées dans le bloc héros.
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tst_Format.qml
TestCase {
    name: "Format"

    // Description Playnite (HTML de Steam) → texte de la fiche.
    function test_plainText() {
        compare(Format.plainText("<p>Lève-toi, Sans-éclat.</p><p>Le Cercle d&apos;Elden &amp; toi.</p>"),
                "Lève-toi, Sans-éclat.\nLe Cercle d'Elden & toi.")
        compare(Format.plainText("<h2>Atouts</h2><ul><li>Un</li><li>Deux</li></ul><img src=\"x.gif\">Fin<br/>là"),
                "Atouts\n\n• Un\n• Deux\nFin\nlà")
        compare(Format.plainText("&amp;lt;b&amp;gt; &#233;t&#233;"), "&lt;b&gt; été")   // une seule passe
        compare(Format.plainText("<p>A</p>\n\n\n<p>B</p>"), "A\n\nB")
        compare(Format.plainText(null), "")
    }

    function test_ageRatingPrefersPegi() {
        compare(Format.ageRating(["ESRB M", "PEGI 16"]), "PEGI 16")
        compare(Format.ageRating(["ESRB M"]), "ESRB M")
        compare(Format.ageRating([]), "")
        compare(Format.ageRating(undefined), "")
    }

    function test_factsAndCredits() {
        var info = { genres: ["Action", "RPG", "Monde ouvert"], releaseDate: "2022-02-25T00:00:00",
                     ageRatings: ["PEGI 16"], developers: ["FromSoftware"],
                     publishers: ["Bandai Namco", "FromSoftware"] }
        compare(Format.facts(info), ["Action", "RPG", "2022", "PEGI 16"])
        compare(Format.facts({}), [])
        compare(Format.credits(info), "FromSoftware · Bandai Namco")
        compare(Format.credits({}), "")
    }

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
