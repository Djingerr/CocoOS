pragma Singleton
import QtQuick

// Faux SystemStatus : une console sur batterie, bien connectée en Wi-Fi.
QtObject {
    property int batteryPercent: 82
    property bool charging: false
    property int signalStrength: 4
}
