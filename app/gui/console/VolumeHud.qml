import QtQuick
import QtQuick.Shapes

// Indicateur du volume (MotionHud) : une capsule de 220 px en haut de l'écran (les boutons sont
// sur le dessus de la console), fine (10 px) puis épaisse (48) pendant les appuis, remplie de
// gauche à droite, haut-parleur à gauche ; en butée, elle s'étire du côté poussé. Même dessin
// que dans le jeu (streampainter). Sur le canevas de 800 de haut ; `position` : "left",
// "center", "right". Aucune dépendance Moonlight.
Item {
    id: root

    property string position: "left"
    property real level: 0                  // 0 à 1

    // Un appui (`direction` : +1, -1) ; `limit` : déjà au bout.
    function press(direction, limit) {
        shown = true
        expanded = true
        if (limit && !Theme.reducedMotion) {
            bumpRight = direction > 0
            bumpAnim.restart()
        }
        collapse.restart()
    }

    property bool shown: false
    property bool expanded: false
    property bool bumpRight: true
    property real bump: 0
    SequentialAnimation {
        id: bumpAnim
        NumberAnimation { target: root; property: "bump"; to: 1; duration: Theme.hudBumpRise; easing.type: Easing.OutQuad }
        NumberAnimation {
            target: root; property: "bump"; to: 0; duration: Theme.hudBumpBack
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveHudBump
        }
    }
    // Sans appui : elle s'amincit, puis part.
    Timer {
        id: collapse
        interval: Theme.hudHold
        onTriggered: { root.expanded = false; hide.restart() }
    }
    Timer { id: hide; interval: Theme.hudLinger; onTriggered: root.shown = false }

    readonly property real canvasWidth: parent ? parent.width : Theme.canvasWidth
    x: position === "center" ? (canvasWidth - width) / 2
     : position === "right" ? canvasWidth - Theme.hudSide - width : Theme.hudSide
    y: Theme.hudTop - (shown ? 0 : Theme.hudHiddenShift)
    width: Theme.hudWidth
    height: (expanded ? Theme.hudThick : Theme.hudThin) - Theme.hudBumpHeight * bump * (expanded ? 1 : 0)
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on y { NumberAnimation { duration: Theme.motion(Theme.hudMove, Theme.curveSpring).duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpring } }
    Behavior on opacity { NumberAnimation { duration: root.shown ? Theme.hudShow : Theme.hudHide } }
    Behavior on height {
        enabled: !bumpAnim.running
        NumberAnimation {
            duration: root.expanded ? Theme.hudExpand : Theme.hudCollapse
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? Theme.curveHudExpand : Theme.curveMain
        }
    }
    transform: Scale {
        origin.x: root.bumpRight ? 0 : root.width
        xScale: 1 + Theme.hudBumpWidth * root.bump
    }

    Rectangle {
        id: capsule
        anchors.fill: parent
        radius: height / 2
        color: Theme.hudFill
        clip: true
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.level))
            height: parent.height
            color: Theme.ink
            Behavior on width { NumberAnimation { duration: Theme.hudLevelMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain } }
        }
    }
    // (le filet par-dessus le remplissage, coins compris)
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.color: Theme.hairlineStrong
    }

    // Le haut-parleur : deux ondes selon le niveau, barré à 0 ; sombre sur le remplissage.
    Item {
        id: speaker
        readonly property color ink: root.level >= 0.2 ? Theme.inkDark : Theme.ink
        x: Theme.hudIconLeft
        anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20
        opacity: root.expanded ? 1 : 0
        scale: root.expanded ? 1 : 0.6
        Behavior on opacity { NumberAnimation { duration: Theme.hudIconFade } }
        Behavior on scale { NumberAnimation { duration: Theme.hudIconMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveHudExpand } }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; fillColor: speaker.ink
                PathSvg { path: "M3 7.5h3l4-3.2v11.4l-4-3.2H3z" }
            }
            ShapePath {
                strokeColor: root.level > 0 ? speaker.ink : "transparent"; strokeWidth: 1.7
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathSvg { path: "M13 7.5a3.5 3.5 0 0 1 0 5" }
            }
            ShapePath {
                strokeColor: root.level >= 0.5 ? speaker.ink : "transparent"; strokeWidth: 1.7
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathSvg { path: "M15.5 5a7 7 0 0 1 0 10" }
            }
            ShapePath {
                strokeColor: root.level <= 0 ? speaker.ink : "transparent"; strokeWidth: 1.7
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathSvg { path: "M13 7l5 6M18 7l-5 6" }
            }
        }
    }
}
