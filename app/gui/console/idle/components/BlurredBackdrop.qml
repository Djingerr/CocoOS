import QtQuick
import ".."

// Fond flou des écrans de veille (SPEC §2 et §3). Le contenu (`art`) est dessiné une fois,
// en basse résolution, sur la boîte `box` entourée de vide (le `filter: blur()` CSS fond
// les bords vers le transparent), flouté une fois ; seule sa place change ensuite
// (`layerScale` et `layerShift` autour du centre de la boîte, `layerOpacity`). Saturation,
// vignettage et grain « overlay » sont composés en un passage, sur 1280 × 720.
Item {
    id: root

    property rect box: Qt.rect(IdleTheme.backdropInset, IdleTheme.backdropInset,
                               IdleTheme.reference.width - 2 * IdleTheme.backdropInset,
                               IdleTheme.reference.height - 2 * IdleTheme.backdropInset)
    property real blurPx: IdleTheme.backdropBlurCssPx        // écart type du flou CSS
    property real saturation: 1
    property bool vignette: false
    property real layerScale: 1
    property point layerShift: Qt.point(0, 0)                  // translate() CSS, avant l'échelle
    property real layerOpacity: 1
    default property alias art: artBox.data

    // Toile : 12 px de toile par écart type, 4 écarts types de vide autour de la boîte.
    readonly property real k: 12 / blurPx
    readonly property real pad: 4 * blurPx
    readonly property size canvas: Qt.size(box.width + 2 * pad, box.height + 2 * pad)

    width: IdleTheme.reference.width
    height: IdleTheme.reference.height

    Item {
        id: canvasItem
        width: Math.round(root.canvas.width * root.k)
        height: Math.round(root.canvas.height * root.k)
        Item {
            id: artBox
            x: root.pad * root.k; y: root.pad * root.k
            width: root.box.width * root.k; height: root.box.height * root.k
        }
    }
    GaussianBlur {
        id: blur
        source: canvasItem
        sigma: 12
    }
    Image {
        id: grainImage
        source: "../assets/grain_256.png"
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        readonly property point center: Qt.point(root.box.x + root.box.width / 2, root.box.y + root.box.height / 2)
        property var blurred: blur.output
        property var grain: grainImage
        property size size: Qt.size(root.width, root.height)
        // Point de l'écran q → point de la boîte p = c + (q − c) / s − t → uv de la toile.
        property vector2d uvScale: Qt.vector2d(1 / (root.layerScale * root.canvas.width),
                                               1 / (root.layerScale * root.canvas.height))
        property vector2d uvOffset: Qt.vector2d(
            (center.x * (1 - 1 / root.layerScale) - root.layerShift.x - root.box.x + root.pad) / root.canvas.width,
            (center.y * (1 - 1 / root.layerScale) - root.layerShift.y - root.box.y + root.pad) / root.canvas.height)
        property real layerOpacity: root.layerOpacity
        property real saturation: root.saturation
        // radial-gradient(ellipse at 28% 45%) : rayons « farthest-corner ».
        property point vignetteCenter: Qt.point(0.28 * root.width, 0.45 * root.height)
        property size vignetteRadii: root.vignette ? Qt.size(Math.SQRT2 * 0.72 * root.width, Math.SQRT2 * 0.55 * root.height)
                                                  : Qt.size(0, 0)
        property real vignetteInner: IdleTheme.vignetteInner.a
        property real vignetteOuter: IdleTheme.vignetteOuter.a
        property real vignetteStop: 0.72
        property real grainOpacity: IdleTheme.grainOpacity
        property real grainTile: 256
        fragmentShader: "../shaders/backdrop.frag.qsb"
    }
}
