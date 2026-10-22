import QtQuick

// Indicateur élastique (soulignement des onglets, et plus tard des profils de flux) :
// ses deux bords rejoignent la cible séparément. Le bord avant part d'abord (ressort
// « vif »), le bord arrière suit (Theme.elasticTrail, curveOut, après
// Theme.elasticTrailDelay) : il s'étire en route. Le dessin est à mettre dedans (il
// prend x et width). Aucune dépendance Moonlight.
//
//   ElasticIndicator { targetLeft: tab.x; targetRight: tab.x + tab.width; animated: shown
//                      Rectangle { anchors.fill: parent; color: Theme.accent } }
Item {
    id: root

    property real targetLeft: 0
    property real targetRight: 0
    property bool animated: true

    property real leftEdge: 0
    property real rightEdge: 0
    x: leftEdge
    width: rightEdge - leftEdge

    onTargetLeftChanged: Qt.callLater(follow)
    onTargetRightChanged: Qt.callLater(follow)
    Component.onCompleted: follow()

    function follow() {
        if (!animated) {
            leftMove.stop(); rightMove.stop()
            leftEdge = targetLeft; rightEdge = targetRight
            return
        }
        if (targetLeft === leftEdge && targetRight === rightEdge) return
        var forward = targetLeft + targetRight > leftEdge + rightEdge
        aim(leftMove, leftPause, leftAnim, targetLeft, !forward)
        aim(rightMove, rightPause, rightAnim, targetRight, forward)
    }
    function aim(move, pause, anim, to, lead) {
        pause.duration = lead ? 0 : Theme.elasticTrailDelay
        anim.duration = lead ? Theme.springSnappy.duration : Theme.elasticTrail
        anim.easing.bezierCurve = lead ? Theme.springSnappy.curve : Theme.curveOut
        anim.to = to
        move.restart()
    }

    SequentialAnimation {
        id: leftMove
        PauseAnimation { id: leftPause }
        NumberAnimation { id: leftAnim; target: root; property: "leftEdge"; easing.type: Easing.BezierSpline }
    }
    SequentialAnimation {
        id: rightMove
        PauseAnimation { id: rightPause }
        NumberAnimation { id: rightAnim; target: root; property: "rightEdge"; easing.type: Easing.BezierSpline }
    }
}
