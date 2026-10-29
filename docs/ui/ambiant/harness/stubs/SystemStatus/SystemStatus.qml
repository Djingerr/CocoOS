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
    function setBrightness(percent) { brightness = percent }
    function setVolume(percent) { volume = percent }
}
