import QtQuick
import QtQuick.Shapes

// Cœur des favoris (MotionFavori), tracé sur la grille 20 × 20 des maquettes : plein (accent)
// ou au trait.
Item {
    id: root

    property real size: 18
    property bool filled: true
    property color color: Theme.accent           // remplissage
    property color stroke: Theme.accent          // trait (cœur vide, ou contour du plein)

    width: size; height: size
    Shape {
        width: 20; height: 20
        scale: root.size / 20
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.filled ? root.color : "transparent"
            strokeColor: root.filled ? "transparent" : root.stroke
            strokeWidth: 1.7
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M10 16.5s-6-3.7-6-8.2A3.3 3.3 0 0 1 10 6a3.3 3.3 0 0 1 6 2.3c0 4.5-6 8.2-6 8.2z" }
        }
    }
}
