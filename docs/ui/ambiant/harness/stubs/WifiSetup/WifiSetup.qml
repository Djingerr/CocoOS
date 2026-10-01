pragma Singleton
import QtQuick

// Faux WifiSetup : un adaptateur Wi-Fi, en ligne sur « Maison », trois réseaux
// visibles. `lastConnect` garde la dernière demande de connexion ; les tests
// émettent connectFinished à la main.
QtObject {
    property bool available: true
    property bool online: true
    property string currentNetwork: "Maison"
    property bool scanning: false
    property bool connecting: false
    property var networks: [
        { ssid: "Maison", bars: 4, secured: true, known: true, active: true },
        { ssid: "Voisins", bars: 2, secured: true, known: false, active: false },
        { ssid: "Café", bars: 1, secured: false, known: false, active: false }
    ]
    property var lastConnect: null
    property int scans: 0

    signal stateChanged()
    signal connectFinished(bool ok, string error, bool badPassword)

    function scan() { scans++ }
    function connectTo(ssid, password) { lastConnect = { ssid: ssid, password: password } }
}
