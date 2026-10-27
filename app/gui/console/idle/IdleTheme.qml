pragma Singleton
import QtQuick
import ".."

// Jetons de l'écran de veille (docs/design/idle/tokens.json), en px de la grille de
// référence 1280 × 720. L'accent et la police viennent du thème de la console ; le reste est
// propre à la veille (son blanc #F5F5F7 n'est pas l'encre de l'accueil).
QtObject {
    readonly property size reference: Qt.size(1280, 720)

    // Couleurs
    readonly property color background: "#000000"
    readonly property color accent: Theme.accent
    readonly property color textPrimary: "#F5F5F7"
    readonly property color textStatus: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.78)
    readonly property color textSecondary: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.55)
    readonly property color textUnit: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.50)
    readonly property color textHint: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.50)
    readonly property color textTertiary: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.45)
    readonly property color textDate: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.60)   // date de l'écran 12
    readonly property color keyHintStroke: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.45)
    readonly property color batteryStroke: Qt.rgba(245 / 255, 245 / 255, 247 / 255, 0.45)
    readonly property color track: Qt.rgba(1, 1, 1, 0.12)
    readonly property color ringTrack: Qt.rgba(1, 1, 1, 0.16)
    readonly property color ringTrackRest: Qt.rgba(1, 1, 1, 0.14)
    readonly property color glassFill: Qt.rgba(1, 1, 1, 0.06)
    readonly property color glassStroke: Qt.rgba(1, 1, 1, 0.10)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.10)
    readonly property color coverRing: Qt.rgba(1, 1, 1, 0.07)
    readonly property color thumbRing: Qt.rgba(1, 1, 1, 0.10)
    readonly property color vignetteInner: Qt.rgba(0, 0, 0, 0.30)
    readonly property color vignetteOuter: Qt.rgba(0, 0, 0, 0.82)
    readonly property color clockGradientTop: "#FFFFFF"
    readonly property color clockGradientBottom: "#A9A9AE"

    // Typographie : { size, weight, letterSpacing (px), lineHeight }
    readonly property string fontFamily: Theme.fontUi
    readonly property var eyebrow: ({ size: 12, weight: Font.DemiBold, letterSpacing: 0.96 })
    readonly property var title: ({ size: 68, weight: Font.DemiBold, letterSpacing: -3.06, lineHeight: 1.05 })
    readonly property var meta: ({ size: 17, weight: Font.Medium, letterSpacing: 0 })
    readonly property var bigNumber: ({ size: 72, weight: Font.DemiBold, letterSpacing: -3.24, lineHeight: 1.0 })
    readonly property var unit: ({ size: 28, weight: Font.Medium, letterSpacing: 0 })
    readonly property var caption: ({ size: 15, weight: Font.Medium, letterSpacing: 0 })
    readonly property var status: ({ size: 15, weight: Font.Medium, letterSpacing: 0 })
    readonly property var downloadRow: ({ size: 14, weight: Font.Medium, letterSpacing: 0 })
    readonly property var hint: ({ size: 14, weight: Font.Medium, letterSpacing: 0 })
    readonly property var keyGlyph: ({ size: 11, weight: Font.DemiBold, letterSpacing: 0 })
    readonly property var topClock: ({ size: 15, weight: Font.DemiBold, letterSpacing: 0 })
    readonly property var coverLabel: ({ size: 11, weight: Font.Medium, letterSpacing: 0.44 })
    readonly property var restDate: ({ size: 20, weight: Font.DemiBold, letterSpacing: 0 })
    readonly property var restClock: ({ size: 176, weight: Font.DemiBold, letterSpacing: -9.68, lineHeight: 1.0 })
    readonly property var capsuleTitle: ({ size: 15, weight: Font.DemiBold, letterSpacing: 0 })
    readonly property var capsuleSub: ({ size: 12, weight: Font.Medium, letterSpacing: 0 })

    // Rayons
    readonly property int radiusCover: 12
    readonly property int radiusCapsule: 38
    readonly property int radiusCoverThumb: 5
    readonly property int radiusKeyHint: 11
    readonly property int radiusLiveDot: 3

    // Effets
    readonly property real backdropBlurCssPx: 100
    readonly property real backdropSaturation: 1.1
    readonly property int backdropInset: -100
    readonly property real coverBrightnessPlaceholder: 0.62
    readonly property real coverBrightnessReal: 0.92     // à valider à l'œil sur l'appareil
    readonly property color coverLightFrom: Qt.rgba(1, 1, 1, 0.10)
    readonly property real coverLightStop: 0.42
    readonly property int reflectionGap: 6
    readonly property real reflectionStartAlpha: 0.22
    readonly property real reflectionFadeAt: 0.28
    readonly property real grainOpacity: 0.07
    readonly property var restGlow: ({ width: 1100, height: 520, centerX: 640, top: 470, stopAt: 0.65,
                                       blurCssPx: 120, opacity: 0.22 })

    // Mouvement
    readonly property var appleOut: [0.32, 0.72, 0, 1, 1, 1]       // Easing.Bezier
    readonly property var easeInOut: [0.42, 0, 0.58, 1, 1, 1]
    // Flou d'entrée (le poste le plus coûteux) : désactivable, opacité + translation gardent
    // l'essentiel de l'effet.
    property bool entryBlur: true
    readonly property int entryShift: 18
    readonly property real entryBlurCssPx: 8
    readonly property int entryDuration: 1000
    readonly property var entryDelays: ({
        cover: 0, eyebrow: 150, title: 220, meta: 290, bigBlock: 400, statusLine: 500,
        topRightClock: 600, downloadRow: 650, keyHint: 1000, restDate: 100, restClock: 200, restCapsule: 450
    })
    readonly property var entryDurations: ({ cover: 1200, restClock: 1200, restCapsule: 1100 })
    readonly property int driftPeriod: 90000
    readonly property var driftKeys: [[0, 0, 0], [0.33, 6, -4], [0.66, -5, 5], [1.0, 4, 6]]
    readonly property int backdropPanPeriod: 60000
    readonly property int coverTiltPeriod: 18000
    readonly property int perspective: 1400
    readonly property int coverSheenPeriod: 11000
    readonly property int liveDotPeriod: 2400
    readonly property int downloadArrowPeriod: 1800
    readonly property int barSheenPeriod: 2400
    readonly property int restGlowPeriod: 14000
    readonly property int batteryRingDelay: 600
    readonly property int batteryRingDuration: 1600
    readonly property int progressUpdate: 1000
    readonly property int stateCrossfade: 600
    readonly property int exitDuration: 320
    readonly property real exitScale: 1.02
}
