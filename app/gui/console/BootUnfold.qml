import QtQuick

// Sortie du démarrage CocoOS (Demarrage) : relais de BootSplash, arrêté sur le logo au repos.
// « Coco » et « S » s'effacent, le O devient un anneau qui glisse au centre, puis se déplie en
// jaquette du jeu sélectionné (`origin`, `cover`) pendant que le noir se lève sur l'accueil ;
// `unfolding` dit à l'accueil de revenir (en éventail, HomeScreen returnStyle « boot »). Sans
// jaquette (pas de jeu), l'anneau s'efface. Remplit la fenêtre ; aucune dépendance Moonlight.
Item {
    id: root

    property rect origin: Qt.rect(0, 0, 0, 0)   // la jaquette centrale, sur le canevas
    property url cover
    property bool active: false

    signal unfolding()                           // l'accueil peut revenir
    signal finished()

    // `logo` : le Logotype au repos de BootSplash (sa place et sa taille servent au relais).
    function start(logo) {
        var k = Theme.scale > 0 ? 1 / Theme.scale : 1
        var p = logo.mapToItem(root, 0, 0)
        word.fontSize = logo.fontSize * k
        word.x = p.x * k; word.y = p.y * k
        var g = logo.geo
        // Le O : une ellipse (celle de la lettre), au même trait que l'anneau des maquettes.
        hero.x = word.x + (g.ocx - g.rxo) * k
        hero.y = word.y + (g.ocy - g.ryo) * k
        hero.width = 2 * g.rxo * k; hero.height = 2 * g.ryo * k
        hero.radius = Math.min(hero.width, hero.height) / 2
        hero.border.width = Theme.ringStroke / Theme.ringSize * hero.width
        hero.opacity = 1
        art.opacity = 0
        word.opacity = 1
        black.opacity = 1
        active = true
        sequence.restart()
    }

    visible: active

    Item {
        id: content
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        Rectangle { id: black; anchors.fill: parent; color: Theme.background }

        Logotype {
            id: word
            oVisible: false
            width: implicitWidth; height: implicitHeight
        }

        Rectangle {
            id: hero
            color: "transparent"
            border.color: Theme.accent
            clip: true
            Image {
                id: art
                anchors.fill: parent
                source: root.cover
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                opacity: 0
            }
        }
    }

    readonly property bool hasCover: origin.width > 0
    readonly property real cx: content.width / 2

    component Go: NumberAnimation {
        target: hero
        duration: Theme.bootUnfoldMove
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
    }

    SequentialAnimation {
        id: sequence
        // Le mot s'efface ; le O devient l'anneau, au centre.
        ParallelAnimation {
            NumberAnimation { target: word; property: "opacity"; to: 0; duration: Theme.bootWordFade }
            Go { property: "x"; to: root.cx - Theme.ringSize / 2 }
            Go { property: "y"; to: Theme.shutdownRingY - Theme.ringSize / 2 }
            Go { property: "width"; to: Theme.ringSize }
            Go { property: "height"; to: Theme.ringSize }
            Go { property: "radius"; to: Theme.ringSize / 2 }
            Go { property: "border.width"; to: Theme.ringStroke }
        }
        ScriptAction { script: root.unfolding() }
        // Il se déplie en jaquette ; le noir se lève.
        ParallelAnimation {
            Go { property: "x"; to: root.hasCover ? root.origin.x : root.cx }
            Go { property: "y"; to: root.hasCover ? root.origin.y : Theme.shutdownRingY }
            Go { property: "width"; to: root.hasCover ? root.origin.width : 0 }
            Go { property: "height"; to: root.hasCover ? root.origin.height : 0 }
            Go { property: "radius"; to: root.hasCover ? Theme.radiusCover : 0 }
            Go { property: "border.width"; to: 0 }
            NumberAnimation { target: art; property: "opacity"; to: 1; duration: Theme.bootUnfoldMove }
            SequentialAnimation {
                PauseAnimation { duration: Theme.bootBlackDelay }
                NumberAnimation { target: black; property: "opacity"; to: 0; duration: Theme.bootBlackFade; easing.type: Easing.InOutQuad }
            }
        }
        // (la jaquette est à la place de celle du carrousel, qui est dessous)
        NumberAnimation { target: hero; property: "opacity"; to: 0; duration: Theme.bootHandover }
        ScriptAction { script: { root.active = false; root.finished() } }
    }
}
