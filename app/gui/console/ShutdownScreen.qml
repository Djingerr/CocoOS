import QtQuick

// Extinction et redémarrage (MotionExtinction, MotionAlimentation) : l'accueil se replie
// (HomeScreen, `launching` en style « collapse »), la jaquette centrale devient l'anneau, qui
// glisse à la place du O de « CocoOS » ; le mot paraît, l'anneau se vide, il reste un point,
// puis le noir ; alors seulement `finished` (l'appelant éteint ou redémarre). Le temps de
// l'animation, il garde la manette. Sur un canevas de 800 de haut ; aucune dépendance Moonlight.
FocusScope {
    id: root

    property rect origin: Qt.rect(0, 0, 0, 0)   // la jaquette centrale, sur le canevas
    property url cover
    property string status: ""                  // sous le logo : « Redémarrage… » (MotionAlimentation)

    property bool active: false
    signal finished()

    function start() {
        active = true
        forceActiveFocus()
        Sounds.play("shutdown")
        hero.x = origin.x; hero.y = origin.y
        hero.width = origin.width; hero.height = origin.height
        hero.radius = Theme.radiusCover
        hero.border.width = 0
        hero.border.color = Theme.accent
        hero.color = "transparent"
        hero.opacity = 1
        art.opacity = 1
        word.opacity = 0; word.spread = 0
        ring.opacity = 0; ring.fill = 1
        black.opacity = 0
        sequence.restart()
    }

    visible: active
    Keys.onPressed: function(event) { event.accepted = true }
    Keys.onReleased: function(event) { event.accepted = true }

    readonly property real cx: content.width / 2
    readonly property real ringSize: Theme.ringSize
    // Le O : au centre du mot « CocoOS » (le mot est centré sur l'écran).
    readonly property point oCenter: Qt.point(cx + Theme.shutdownOShift, Theme.shutdownWordY)

    Item {
        id: content
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        Rectangle { id: black; anchors.fill: parent; color: Theme.background; opacity: 0 }

        // « Coco » à gauche du O, « S » à droite, en orange.
        Item {
            id: word
            property real spread: 0
            anchors.fill: parent
            opacity: 0
            Text {
                x: root.oCenter.x - root.ringSize / 2 - Theme.shutdownGapLeft - width - word.spread
                y: root.oCenter.y - height / 2
                text: "Coco"
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.shutdownWordSize; font.weight: Font.DemiBold
                font.letterSpacing: -0.02 * Theme.shutdownWordSize
            }
            Text {
                x: root.oCenter.x + root.ringSize / 2 + Theme.shutdownGapRight + word.spread
                y: root.oCenter.y - height / 2
                text: "S"
                color: Theme.accent
                font.family: Theme.fontUi; font.pixelSize: Theme.shutdownWordSize; font.weight: Font.DemiBold
                font.letterSpacing: -0.02 * Theme.shutdownWordSize
            }
        }

        // « Redémarrage… », sous le mot, le temps qu'il est là.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.shutdownStatusTop
            visible: root.status !== ""
            text: root.status
            opacity: word.opacity
            color: Theme.shutdownStatusInk
            font.family: Theme.fontUi; font.pixelSize: Theme.shutdownStatusSize; font.weight: Font.Medium
        }

        // La jaquette, puis l'anneau (trait orange), puis le point.
        Rectangle {
            id: hero
            clip: true
            Image {
                id: art
                anchors.fill: parent
                source: root.cover
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
            }
            Glow {
                anchors.centerIn: parent
                width: Theme.sleepGlow; height: width
                visible: hero.width < Theme.ringSize / 2
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.sleepGlowAlpha * 0.6)
                z: -1
            }
        }
        // L'arc qui se vide, par-dessus la piste (le contour de `hero`, passé à 30 %).
        LoaderRing {
            id: ring
            x: root.oCenter.x - width / 2; y: root.oCenter.y - height / 2
            spinning: false
            track: "transparent"
            opacity: 0
        }
    }

    // Une étape de `hero` : sa place (centre, côté) et son rayon, en `ms` (curveMain).
    component Move: ParallelAnimation {
        id: move
        property point center
        property real side
        property int ms: Theme.shutdownMove
        NumberAnimation { target: hero; property: "x"; to: move.center.x - move.side / 2; duration: move.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
        NumberAnimation { target: hero; property: "y"; to: move.center.y - move.side / 2; duration: move.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
        NumberAnimation { target: hero; property: "width"; to: move.side; duration: move.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
        NumberAnimation { target: hero; property: "height"; to: move.side; duration: move.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
        NumberAnimation { target: hero; property: "radius"; to: move.side / 2; duration: move.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
    }

    SequentialAnimation {
        id: sequence
        // L'accueil se replie (HomeScreen), le noir monte.
        ParallelAnimation {
            NumberAnimation { target: black; property: "opacity"; to: 1; duration: Theme.shutdownBlack }
            SequentialAnimation {
                PauseAnimation { duration: Theme.shutdownCollapse }
                // La jaquette devient l'anneau, au centre…
                ParallelAnimation {
                    Move { center: Qt.point(root.cx, Theme.shutdownRingY); side: root.ringSize }
                    NumberAnimation { target: hero; property: "border.width"; to: Theme.ringStroke; duration: Theme.shutdownMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
                    NumberAnimation { target: art; property: "opacity"; to: 0; duration: Theme.shutdownArtFade }
                }
            }
        }
        // …puis glisse à la place du O ; le mot paraît.
        ParallelAnimation {
            Move { center: root.oCenter; side: root.ringSize }
            SequentialAnimation {
                PauseAnimation { duration: Theme.shutdownWordDelay }
                NumberAnimation { target: word; property: "opacity"; to: 1; duration: Theme.shutdownWordFade }
            }
        }
        // L'anneau se vide : sa piste pâlit, l'arc orange se retire.
        ScriptAction { script: { ring.opacity = 1; hero.border.color = Theme.ringTrack } }
        PauseAnimation { duration: Theme.shutdownUnwindDelay }
        NumberAnimation {
            target: ring; property: "fill"; to: 0; duration: Theme.shutdownUnwind
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveUnwind
        }
        // Le mot s'écarte en s'effaçant ; l'anneau se resserre en un point.
        ScriptAction { script: { ring.opacity = 0; hero.color = Theme.accent; hero.border.color = Theme.accent } }
        ParallelAnimation {
            NumberAnimation { target: word; property: "opacity"; to: 0; duration: Theme.shutdownWordFade }
            NumberAnimation { target: word; property: "spread"; to: Theme.shutdownSpread; duration: Theme.shutdownSpreadMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
            Move { center: root.oCenter; side: Theme.shutdownDot; ms: Theme.shutdownDotMove }
            NumberAnimation { target: hero; property: "border.width"; to: 0; duration: Theme.shutdownDotMove }
        }
        // Le point s'éteint.
        ParallelAnimation {
            NumberAnimation { target: hero; property: "opacity"; to: 0; duration: Theme.shutdownDotFade }
            Move { center: root.oCenter; side: Theme.shutdownDotEnd; ms: Theme.shutdownDotFade }
        }
        PauseAnimation { duration: Theme.shutdownBlackHold }
        ScriptAction { script: root.finished() }
    }
}
