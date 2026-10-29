pragma Singleton
import QtQuick

// Faux SystemStatus : une console sur batterie, bien connectée en Wi-Fi, qui peut
// se mettre en veille, redémarrer et s'éteindre (`lastPower` garde la dernière demande).
QtObject {
    property int batteryPercent: 82
    property bool charging: false
    property int signalStrength: 4
    property var batteryDetails: ({ minutes: 194, watts: 6.8, status: "Discharging" })
    property var wifi: ({ ssid: "Maison-5G", strength: 86, secured: true, frequency: 5180, bitrate: 866 })
    property string deviceName: "Console de Coco"
    property double free: 44023414784       // 41 Go libres
    function freeStorage() { return free }
    property var powerActions: ["suspend", "reboot", "poweroff"]
    property string lastPower: ""
    // Réseau vers le PC : sondé quand ConsoleHome le demande (`probed`).
    property int latencyMs: 9
    property int jitterMs: 2
    property string probed: ""
    property int brightness: 60
    property int volume: 75

    signal changed()
    signal networkChanged()
    signal resumed()

    property bool started: false

    property var environment: ({})        // variables d'environnement simulées

    function start() { started = true }
    function env(name) { return environment[name] || "" }
    function power(action) { lastPower = action }
    function probeHost(manager, hostName) { probed = hostName }
    function stopProbing() { probed = "" }
    function hostAddress(manager, hostName) { return "192.168.1.20" }
    // (un faux code : les trois repères et un damier, 29 × 29)
    function qrRows(text) {
        var n = 29, rows = []
        var finder = function(x, y) {
            var inBox = function(ox, oy) {
                var dx = x - ox, dy = y - oy
                if (dx < 0 || dy < 0 || dx > 6 || dy > 6) return -1
                return dx === 0 || dy === 0 || dx === 6 || dy === 6 || (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4) ? 1 : 0
            }
            return Math.max(inBox(0, 0), inBox(n - 7, 0), inBox(0, n - 7))
        }
        for (var y = 0; y < n; y++) {
            var row = ""
            for (var x = 0; x < n; x++) {
                var f = finder(x, y)
                row += f >= 0 ? f : ((x * 7 + y * 13 + x * y) % 3 === 0 ? 1 : 0)
            }
            rows.push(row)
        }
        return rows
    }
    function setBrightness(percent) { brightness = percent }
    function setVolume(percent) { volume = percent }
}
