import QtQuick

// Flou gaussien de `source` (un élément caché, dessiné une fois), en deux passages.
// `output` sert de texture ; rien n'est redessiné tant que la source ne change pas.
Item {
    id: root

    property Item source
    property real sigma: 12            // en px de la source (≤ 12, cf. blur.frag)
    readonly property alias output: passVSource

    ShaderEffectSource {
        id: input
        sourceItem: root.source
        hideSource: true
        visible: false
    }
    ShaderEffect {
        id: passH
        width: root.source ? root.source.width : 0
        height: root.source ? root.source.height : 0
        property var source: input
        property vector2d texel: Qt.vector2d(1 / Math.max(1, width), 0)
        property real sigma: root.sigma
        fragmentShader: "../shaders/blur.frag.qsb"
    }
    ShaderEffectSource {
        id: passHSource
        sourceItem: passH
        hideSource: true
        visible: false
    }
    ShaderEffect {
        id: passV
        width: passH.width; height: passH.height
        property var source: passHSource
        property vector2d texel: Qt.vector2d(0, 1 / Math.max(1, height))
        property real sigma: root.sigma
        fragmentShader: "../shaders/blur.frag.qsb"
    }
    ShaderEffectSource {
        id: passVSource
        sourceItem: passV
        hideSource: true
        visible: false
    }
}
