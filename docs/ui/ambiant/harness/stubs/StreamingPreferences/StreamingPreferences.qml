pragma Singleton
import QtQuick

// Fausses préférences de stream : les champs lus et écrits par la couche console.
QtObject {
    // Comme dans le vrai StreamingPreferences
    enum VideoCodecConfig { VCC_AUTO, VCC_FORCE_H264, VCC_FORCE_HEVC, VCC_FORCE_HEVC_HDR_DEPRECATED, VCC_FORCE_AV1 }

    property int width: 1920
    property int height: 1080
    property int fps: 60
    property int bitrateKbps: 30000
    property bool autoAdjustBitrate: true
    property int videoCodecConfig: StreamingPreferences.VCC_AUTO
    property bool enableHdr: false
    property bool enableYUV444: false
    property int saves: 0

    // Ordre de grandeur du vrai calcul : 20 Mb/s en 1080p60.
    function getDefaultBitrate(width, height, fps, yuv444) {
        return Math.round(width * height * fps / 6220.8 / 1000) * 1000
    }
    function save() { saves++ }
}
