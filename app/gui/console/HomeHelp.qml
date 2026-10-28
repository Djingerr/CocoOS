import QtQuick
import QtQuick.Shapes

// Aide en bas de l'accueil CocoOS (AccueilCarrousel, MotionNavigation) :
// « ◀ ▶ Parcourir   ↓ Plus d'infos ». Les flèches sont tracées (icônes au trait) dans des
// cercles ; celle qu'on presse s'allume (`lit` : -1 gauche, +1 droite) ; la flèche du bas
// oscille doucement (cocoNudge). Présentation pure.
Row {
    id: root

    property int lit: 0
    spacing: Theme.helpGap

    // Flèche au trait dans un cercle ; `angle` 0 : vers la droite.
    component Arrow: Rectangle {
        id: arrow
        property real angle: 0
        property bool on: false
        property real nudge: 0
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.helpGlyphSize; height: width; radius: width / 2
        color: on ? Theme.ink : "transparent"
        border.color: Theme.helpGlyphStroke
        Behavior on color { ColorAnimation { duration: Theme.tabsGlyphFade } }
        Shape {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: arrow.nudge
            width: 12; height: 10
            rotation: arrow.angle
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: arrow.on ? Theme.inkOnLight : Theme.ink
                strokeWidth: Theme.helpArrowStroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M7 1l4 4-4 4M11 5H1" }
            }
        }
    }
    component Label: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.helpInk
        font.family: Theme.fontUi; font.pixelSize: Theme.helpSize; font.weight: Font.Medium
    }

    Row {
        spacing: Theme.helpInnerGap
        Row {
            spacing: Theme.helpArrowGap
            Arrow { angle: 180; on: root.lit < 0 }
            Arrow { on: root.lit > 0 }
        }
        Label { text: qsTr("Parcourir") }
    }
    Row {
        spacing: Theme.helpInnerGap
        Arrow {
            angle: 90
            SequentialAnimation on nudge {
                running: !Theme.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { to: Theme.helpNudge; duration: Theme.helpNudgePeriod / 2; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: Theme.helpNudgePeriod / 2; easing.type: Easing.InOutSine }
            }
        }
        Label { text: qsTr("Plus d'infos") }
    }
}
