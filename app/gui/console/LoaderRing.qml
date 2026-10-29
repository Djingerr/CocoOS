import QtQuick
import QtQuick.Shapes

// Anneau de chargement CocoOS (MotionLancement, MotionEchec, MotionReveilPC) : une piste, un
// arc qui tourne tant que `spinning`, et un remplissage depuis le haut (`fill`, 0 à 1 : prêt,
// ou avancement connu). Taille et trait en pixels de son parent. Aucune dépendance Moonlight.
Item {
    id: root

    property real stroke: Theme.ringStroke
    property color track: Theme.ringTrack
    property color color: Theme.accent
    property real arc: Theme.ringArc         // longueur de l'arc qui tourne, fraction du tour
    property bool spinning: true
    property int period: Theme.ringSpin
    property real fill: 0

    width: Theme.ringSize; height: width
    readonly property real r: (width - stroke) / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.track
            strokeWidth: root.stroke
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: 0; sweepAngle: 360
            }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.spinning ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.ringSpinFade } }
        RotationAnimator on rotation {
            running: root.spinning && root.visible
            from: 0; to: 360; duration: root.period
            loops: Animation.Infinite
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: -90; sweepAngle: 360 * root.arc
            }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.fill > 0
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.stroke
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: -90; sweepAngle: 360 * Math.min(1, root.fill)
            }
        }
    }
}
