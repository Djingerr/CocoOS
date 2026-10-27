import QtQuick
import QtQuick.Shapes
import ".."

// Anneau de progression (SPEC §2.3 et §3) : piste, puis arc depuis midi dans le sens
// horaire, à bouts ronds. `progress` de 0 à 1.
Shape {
    id: root

    property real progress: 0
    property real radius: 7
    property real strokeWidth: 2
    property color trackColor: IdleTheme.ringTrack
    property color color: IdleTheme.accent

    width: 20; height: 20
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: root.trackColor
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        PathAngleArc {
            centerX: root.width / 2; centerY: root.height / 2
            radiusX: root.radius; radiusY: root.radius
            startAngle: 0; sweepAngle: 360
        }
    }
    ShapePath {
        strokeColor: root.progress > 0 ? root.color : "transparent"
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: root.width / 2; centerY: root.height / 2
            radiusX: root.radius; radiusY: root.radius
            startAngle: -90; sweepAngle: 360 * Math.max(0, Math.min(1, root.progress))
        }
    }
}
