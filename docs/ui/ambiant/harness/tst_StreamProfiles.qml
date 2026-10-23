import QtQuick
import QtTest
import "../../../../app/gui/console/StreamProfiles.js" as Profiles

// Les profils de flux : ce qu'ils demandent au lancement selon l'écran et le réseau.
TestCase {
    name: "StreamProfiles"

    // Le débit conseillé du faux module Moonlight (stubs/StreamingPreferences).
    function kbps(w, h, fps) { return Math.round(w * h * fps / 6220.8 / 1000) * 1000 }
    function ctx(width, height, refresh, quality) {
        return { width: width, height: height, refresh: refresh, quality: quality, defaultKbps: kbps }
    }

    function test_manualLeavesTheUserSettings() {
        compare(Profiles.launchSettings("manual", ctx(1920, 1080, 60, "good")), null)
        compare(Profiles.launchSettings("inconnu", ctx(1920, 1080, 60, "good")), null)
    }

    // Écran 1080p 120 Hz, bon réseau.
    function test_eachProfileOnA1080p120Screen() {
        var c = ctx(1920, 1080, 120, "good")
        var competitive = Profiles.launchSettings("competitive", c)
        compare([competitive.width, competitive.height, competitive.fps], [1920, 1080, 120])
        var balanced = Profiles.launchSettings("balanced", c)
        compare([balanced.height, balanced.fps, balanced.bitrateKbps], [1080, 60, kbps(1920, 1080, 60)])
        var quality = Profiles.launchSettings("quality", c)
        compare([quality.height, quality.fps], [1080, 60])          // jamais au-dessus de l'écran
        compare(quality.bitrateKbps, 30000)                           // ×1,5
        var saver = Profiles.launchSettings("saver", c)
        compare([saver.width, saver.height, saver.fps], [1280, 720, 30])
        verify(saver.bitrateKbps <= 5000)
    }

    // La définition de l'écran si elle tient sous le plafond du profil (1280 × 800 : l'image
    // le remplit), sinon les définitions courantes (1080p, 1440p…), jamais de taille bizarre.
    function test_followsTheScreen() {
        var s = Profiles.launchSettings("balanced", ctx(1280, 800, 60, "good"))
        compare([s.width, s.height], [1280, 800])
        s = Profiles.launchSettings("quality", ctx(2560, 1600, 60, "good"))
        compare([s.width, s.height], [2560, 1440])
        s = Profiles.launchSettings("balanced", ctx(2560, 1600, 60, "good"))
        compare([s.width, s.height], [1920, 1080])
        s = Profiles.launchSettings("balanced", ctx(1280, 800, 60, "fair"))
        compare([s.width, s.height], [1280, 720])
        s = Profiles.launchSettings("saver", ctx(1280, 800, 60, "good"))
        compare([s.width, s.height], [1280, 720])
    }

    // Réseau moyen : un palier de moins ; mauvais : deux. La réactivité garde ses images.
    function test_networkTakesTiersAway() {
        compare(Profiles.launchSettings("balanced", ctx(1920, 1080, 60, "fair")).height, 720)
        compare([Profiles.launchSettings("balanced", ctx(1920, 1080, 60, "poor")).width,
                 Profiles.launchSettings("balanced", ctx(1920, 1080, 60, "poor")).height], [960, 540])
        var competitive = Profiles.launchSettings("competitive", ctx(1920, 1080, 120, "poor"))
        compare([competitive.height, competitive.fps], [540, 120])
        compare(Profiles.launchSettings("quality", ctx(1920, 1080, 60, "fair")).bitrateKbps, kbps(1280, 720, 60))
        compare(Profiles.launchSettings("saver", ctx(1920, 1080, 60, "poor")).height, 720)
        compare(Profiles.launchSettings("balanced", ctx(1280, 800, 60, "")).height, 800)   // pas de mesure : rien en moins
    }

    function test_dataPerHour() {
        compare(Profiles.gigabytesPerHour(5000), 2.25)
    }
}
