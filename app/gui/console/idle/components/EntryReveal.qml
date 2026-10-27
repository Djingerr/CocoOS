pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import ".."

// Animation d'entrée d'un élément (SPEC §4) : il part d'une opacité nulle, 18 px plus bas
// et flou (si IdleTheme.entryBlur), et se pose en `duration` ms (appleOut) après `delay` ms.
// Elle part à la création, ou quand `started` passe à vrai ; play() la rejoue. Le contenu va
// dans l'enveloppe, qui doit couvrir tout ce qu'il dessine (le flou passe par une couche à sa
// taille).
Item {
    id: root

    property bool started: true
    onStartedChanged: if (started) play()
    Component.onCompleted: if (started) play()

    property int delay: 0
    property int duration: IdleTheme.entryDuration
    property real progress: 0
    default property alias content: inner.data

    implicitWidth: inner.childrenRect.x + inner.childrenRect.width
    implicitHeight: inner.childrenRect.y + inner.childrenRect.height

    function play() { anim.restart() }

    SequentialAnimation {
        id: anim
        PropertyAction { target: root; property: "progress"; value: 0 }
        PauseAnimation { duration: root.delay }
        NumberAnimation {
            target: root; property: "progress"; to: 1; duration: root.duration
            easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.appleOut
        }
    }

    Item {
        id: inner
        width: root.width; height: root.height
        opacity: root.progress
        transform: Translate { y: IdleTheme.entryShift * (1 - root.progress) }
        // La couche n'existe que pendant l'entrée.
        layer.enabled: IdleTheme.entryBlur && root.progress > 0 && root.progress < 1
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * IdleTheme.textureScale), Math.ceil(height * IdleTheme.textureScale))
        // blur(8px) CSS : MultiEffect donne un écart type de 7,8 px à blurMax 32, à peu près
        // proportionnel à `blur` (mesuré sur le laptop).
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: 1 - root.progress
        }
    }
}
