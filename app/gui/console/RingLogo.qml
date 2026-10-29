import QtQuick

// Le mot « CocoOS » dont le O est l'anneau de chargement (MotionMiseAJour, MotionExtinction) :
// « Coco » et « S » (64 px, 600) de part et d'autre de LoaderRing, sa lueur derrière. Centré
// sur son parent (le mot, pas le O). `fill` : l'avancement (0 à 1). Aucune dépendance Moonlight.
Item {
    id: root

    property real fill: 0
    property real glow: Theme.updateGlowLow      // opacité de la lueur
    readonly property point oCenter: Qt.point(width / 2 + Theme.shutdownOShift, height / 2)

    Glow {
        x: root.oCenter.x - width / 2; y: root.oCenter.y - height / 2
        width: Theme.updateGlowSize; height: width
        opacity: root.glow
        Behavior on opacity { NumberAnimation { duration: Theme.updateGlowFade } }
    }
    Text {
        x: root.oCenter.x - Theme.ringSize / 2 - Theme.shutdownGapLeft - width
        y: root.oCenter.y - height / 2
        text: "Coco"
        color: Theme.ink
        font.family: Theme.fontUi; font.pixelSize: Theme.shutdownWordSize; font.weight: Font.DemiBold
        font.letterSpacing: -0.02 * Theme.shutdownWordSize
    }
    Text {
        x: root.oCenter.x + Theme.ringSize / 2 + Theme.shutdownGapRight
        y: root.oCenter.y - height / 2
        text: "S"
        color: Theme.accent
        font.family: Theme.fontUi; font.pixelSize: Theme.shutdownWordSize; font.weight: Font.DemiBold
        font.letterSpacing: -0.02 * Theme.shutdownWordSize
    }
    LoaderRing {
        x: root.oCenter.x - width / 2; y: root.oCenter.y - height / 2
        spinning: false
        track: Theme.accentTrack
        fill: root.fill
    }
}
