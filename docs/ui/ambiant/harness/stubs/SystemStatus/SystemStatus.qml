pragma Singleton
import QtQuick

// Faux SystemStatus : une console sur batterie, bien connectée en Wi-Fi, qui peut
// se mettre en veille, redémarrer et s'éteindre (`lastPower` garde la dernière demande).
QtObject {
    property int batteryPercent: 82
    property bool charging: false
    property int signalStrength: 4
    property var powerActions: ["suspend", "reboot", "poweroff"]
    property string lastPower: ""
    // Réseau vers le PC : sondé quand ConsoleHome le demande (`probed`).
    property int latencyMs: 9
    property int jitterMs: 2
    property string probed: ""

    function power(action) { lastPower = action }
    function probeHost(manager, hostName) { probed = hostName }
    function stopProbing() { probed = "" }
}
