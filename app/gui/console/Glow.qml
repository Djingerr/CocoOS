import QtQuick
import QtQuick.Shapes

// Lueur : une ellipse `width` × `height` dont la couleur s'efface du centre vers le bord
// (radial-gradient(closest-side, couleur, transparent) des maquettes).
Shape {
    id: root
    property color color: Theme.accent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: root.width / 2; centerY: root.width / 2
            centerRadius: root.width / 2
            focalX: centerX; focalY: centerY
            GradientStop { position: 0; color: root.color }
            GradientStop { position: 1; color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0) }
        }
        PathRectangle { width: root.width; height: root.width }
    }
    // (le dégradé est tracé dans un carré, aplati à la hauteur voulue)
    transform: Scale { yScale: root.height / Math.max(1, root.width) }
}
