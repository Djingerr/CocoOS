import QtQuick
import QtTest
import "../IdleFormat.js" as F
import ".."

// Formats de texte de l'écran de veille (SPEC §5) et règle de sélection d'état (SPEC §1).
//
//   QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input app/gui/console/idle/tests/tst_format.qml
TestCase {
    name: "IdleFormat"
    readonly property string nb: " "

    function test_clock() {
        compare(F.clock(new Date(2026, 9, 27, 21, 46)), "21:46")
        compare(F.clock(new Date(2026, 9, 27, 7, 5)), "07:05")
    }

    function test_longDate() {
        compare(F.longDate(new Date(2026, 9, 27, 21, 46)), "Mardi 27 octobre")
        compare(F.longDate(new Date(2026, 0, 1)), "Jeudi 1 janvier")
        compare(F.longDate(new Date(2026, 7, 2)), "Dimanche 2 août")
    }

    function test_sessionDuration() {
        compare(F.sessionDuration(5077), "1 h 24 min")
        compare(F.sessionDuration(24 * 60 + 30), "24 min")
        compare(F.sessionDuration(3600 + 5 * 60), "1 h 05 min")       // deux chiffres dès qu'il y a des heures
        compare(F.sessionDuration(0), "0 min")
        compare(F.sessionParts(5077), [{ value: "1", unit: "h" }, { value: "24", unit: "min" }])
        compare(F.sessionParts(600), [{ value: "10", unit: "min" }])
    }

    function test_rate() {
        compare(F.rate(1.2e9), "1,2 Go/s")
        compare(F.rate(1e9), "1,0 Go/s")
        compare(F.rate(850e6), "850 Mo/s")
        compare(F.rate(999.7e6), "1,0 Go/s")                        // jamais « 1000 Mo/s »
        compare(F.rate(300e3), "300 ko/s")
    }

    function test_eta() {
        compare(F.eta(360), "environ 6 min")
        compare(F.eta(357), "environ 6 min")                         // minutes entamées
        compare(F.eta(59), "moins d'une minute")
        compare(F.eta(3900), "environ 1 h 05")
        compare(F.etaShort(240), "4 min")                            // ligne de téléchargement (10)
    }

    function test_percent() {
        compare(F.percent(0.82), "82" + nb + "%")
        compare(F.percent(0.6845), "68" + nb + "%")                  // jamais arrondi vers le haut
        compare(F.percent(0.42), "42" + nb + "%")
        compare(F.percentValue(82), "82" + nb + "%")
    }

    function test_latency() {
        compare(F.latency(4), "4 ms")
        compare(F.latency(12.6), "13 ms")
    }

    function test_autonomy() {
        compare(F.autonomy(180, false), "Environ 3 h")
        compare(F.autonomy(45, false), "Environ 45 min")
        compare(F.autonomy(184, false), "Environ 3 h")
        compare(F.autonomy(200, false), "Environ 3 h 20")
        compare(F.autonomy(180, true), "En charge")
        compare(F.autonomy(-1, false), "")                          // pas d'estimation : rien
    }

    function test_lastSession() {
        var now = new Date(2026, 9, 27, 21, 46)
        var ago = function(minutes) { return new Date(now.getTime() - minutes * 60000) }
        compare(F.lastSession(ago(12), now), "Il y a 12 min")
        compare(F.lastSession(ago(120), now), "Il y a 2 h")
        compare(F.lastSession(new Date(2026, 9, 26, 20, 0), now), "Hier")
        compare(F.lastSession(new Date(2026, 9, 24, 21, 0), now), "Il y a 3 jours")
        compare(F.lastSession(ago(0), now), "Il y a 1 min")
    }

    function test_wifiQuality() {
        compare(F.wifiQualityKey(-50), "excellent")
        compare(F.wifiQualityKey(-55), "excellent")
        compare(F.wifiQualityKey(-60), "good")
        compare(F.wifiQualityKey(-70), "fair")
        compare(F.wifiQualityKey(-80), "poor")
        compare(F.wifiQuality("excellent", false), "Excellent")
        compare(F.wifiQuality("good", false), "Bon")
        compare(F.wifiQuality("fair", false), "Moyen")
        compare(F.wifiQuality("poor", false), "Faible")
        compare(F.wifiQuality("excellent", true), "Wi-Fi excellent")
    }

    function test_hostState() {
        compare(F.hostState({ reachable: true, inGame: true }), "En jeu")
        compare(F.hostState({ reachable: true, inGame: false }), "En ligne")
        compare(F.hostState({ reachable: true, sleeping: true }), "En veille")
        compare(F.hostState({ reachable: false }), "Hors ligne")
    }

    // L'état suit la session et le téléchargement ; le mock donne les quatre.
    Component { id: mockComponent; IdleStatusMock { fixedNow: new Date(2026, 9, 27, 21, 46) } }
    function test_states() {
        var m = createTemporaryObject(mockComponent, null)
        ;["game", "gameDownload", "download", "rest"].forEach(function(s) {
            m.scenario = s
            compare(m.state, s)
        })
        m.scenario = "game"
        compare(F.sessionDuration((m.now - m.session.connectedAt) / 1000), "1 h 24 min")
        compare(m.session.game.title, "Minecraft")
        verify(m.session.game.coverUrl.toString().indexOf("idle/assets/placeholder_cover_600x848.png") > 0)
        m.scenario = "rest"
        compare(F.lastSession(m.lastGame.lastPlayedAt, m.now), "Il y a 2 h")
        compare(F.autonomy(m.battery.minutesLeft, m.battery.charging), "Environ 3 h")
    }
}
