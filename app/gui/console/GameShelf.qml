import QtQuick
import QtQuick.Effects

// Étagère de vignettes 16:9 en bas de l'accueil : le jeu sélectionné est calé à
// gauche, agrandi et souligné d'orange ; les suivants défilent vers la droite,
// les précédents s'estompent en sortant.
// Consomme un modèle exposant le rôle `boxart` (url). Aucune dépendance Moonlight.
//
// Tout le mouvement découle d'UNE valeur animée, `pos` (la position en index,
// portée par un ressort) : aucune vignette n'a d'animation propre.
FocusScope {
    id: root

    property alias model: list.model
    readonly property alias count: list.count
    property int currentIndex: 0
    // Sens du dernier déplacement (+1 vers la droite, -1 vers la gauche).
    property int direction: 1
    // Apparition des vignettes et du soulignement (cf. Appear) : `enterStep` est le
    // délai par rang de la cascade d'entrée (0 = tous ensemble).
    property bool shown: true
    property int enterStep: 0
    signal launchRequested(int index)

    // Rebond aux extrémités : décalage temporaire ajouté à la cible du ressort.
    property real bump: 0
    property real pos: currentIndex + bump
    property bool animated: false       // pas de ressort pendant la mise en place
    readonly property real pitch: Theme.shelfThumbSize.width + Theme.shelfGap

    implicitHeight: Theme.underlineY + Theme.underlineHeight
                    - (Theme.shelfBottom - Theme.shelfThumbSize.height)

    property int lastIndex: 0
    onCurrentIndexChanged: {
        if (currentIndex !== lastIndex)
            direction = currentIndex > lastIndex ? 1 : -1
        lastIndex = currentIndex
    }

    Component.onCompleted: {
        lastIndex = currentIndex
        animated = true
    }
    // (count vaut 0 tant que le modèle n'est pas chargé : ne pas y perdre la sélection.)
    onCountChanged: if (count > 0 && currentIndex >= count) currentIndex = count - 1

    // Pas de ressort non plus tant que l'étagère n'est pas montrée : une sélection
    // posée avant l'entrée (dernier jeu joué) est d'emblée en place.
    Behavior on pos {
        enabled: root.animated && root.shown
        SpringAnimation {
            spring: Theme.springStrength; damping: Theme.springDamping
            mass: Theme.springMass; epsilon: Theme.springEpsilon
        }
    }

    // Déplace la sélection d'un cran ; en bout de liste, petit rebond.
    function move(dir) {
        var next = currentIndex + dir
        if (next < 0 || next >= count) {
            bump = dir * Theme.edgeBump
            bumpBack.restart()
            Sounds.play("edge")
        } else {
            currentIndex = next
            Sounds.play("move")
        }
    }
    Timer { id: bumpBack; interval: Theme.edgeBumpHold; onTriggered: root.bump = 0 }

    // --- Gauche / droite, avec répétition qui accélère à l'appui prolongé ---
    PadRepeat {
        id: pad
        keys: [Qt.Key_Left, Qt.Key_Right]
        onTriggered: function(key) { root.move(key === Qt.Key_Left ? -1 : 1) }
    }
    Keys.onPressed: function(event) { pad.press(event) }
    Keys.onReleased: function(event) { pad.release(event) }
    // Rien au-dessus ni en dessous de l'étagère : haut / bas butent.
    Keys.onUpPressed: Sounds.play("edge")
    Keys.onDownPressed: Sounds.play("edge")
    Keys.onReturnPressed: root.launchRequested(currentIndex)
    Keys.onEnterPressed: root.launchRequested(currentIndex)
    onActiveFocusChanged: if (!activeFocus) pad.stop()

    // Masque commun à toutes les vignettes (rectangle arrondi).
    Rectangle {
        id: thumbMask
        width: Theme.shelfThumbSize.width; height: Theme.shelfThumbSize.height
        radius: Theme.shelfThumbRadius
        visible: false
        layer.enabled: Theme.shelfRounded
        layer.textureSize: list.thumbTextureSize
    }

    // ListView pour ne créer que les vignettes proches de l'écran ; elle ne défile
    // jamais seule, c'est `pos` qui fixe contentX.
    ListView {
        id: list

        // Texture des vignettes : à la taille réellement affichée de la plus grande.
        readonly property size thumbTextureSize: Qt.size(
            Math.ceil(Theme.shelfThumbSize.width * Theme.shelfActiveScale * Theme.scale),
            Math.ceil(Theme.shelfThumbSize.height * Theme.shelfActiveScale * Theme.scale))
        readonly property real wantedX: root.pos * root.pitch - Theme.margin

        width: parent.width; height: Theme.shelfThumbSize.height
        orientation: ListView.Horizontal
        interactive: false
        highlightFollowsCurrentItem: false
        currentIndex: -1
        // Synchronisation impérative : ListView réécrit contentX de son côté quand
        // le modèle change, ce qu'une simple liaison ne rattraperait pas.
        onWantedXChanged: contentX = wantedX
        onContentXChanged: if (contentX !== wantedX) contentX = wantedX
        Component.onCompleted: contentX = wantedX

        delegate: Item {
            id: del

            required property int index
            required property url boxart
            readonly property real d: index - root.pos            // écart à la position courante
            readonly property real f: Math.max(0, 1 - Math.abs(d))    // 1 = vignette active

            width: root.pitch; height: Theme.shelfThumbSize.height

            Item {
                id: thumb
                // La vignette active s'élargit : les suivantes lui font de la place.
                x: Theme.shelfThumbSize.width * (Theme.shelfActiveScale - 1) * Math.min(Math.max(del.d, 0), 1)
                y: -Theme.shelfActiveLift * del.f
                width: Theme.shelfThumbSize.width; height: Theme.shelfThumbSize.height
                transformOrigin: Item.BottomLeft
                scale: 1 + (Theme.shelfActiveScale - 1) * del.f
                opacity: (del.d < 0 ? Math.min(Math.max(1 + Theme.shelfExitFade * del.d, 0), 1) : 1)
                         * (Theme.shelfRestOpacity + (1 - Theme.shelfRestOpacity) * del.f)

                Appear {
                    anchors.fill: parent
                    shown: root.shown
                    delay: root.enterStep * (Theme.enterRankShelf + Math.min(del.index, Theme.enterRankShelfSpan))
                    // Hors cascade d'entrée, une vignette créée en défilant est là d'emblée.
                    animateInitially: root.enterStep > 0

                    Item {
                        id: card
                        anchors.fill: parent
                        visible: !Theme.shelfRounded
                        layer.enabled: Theme.shelfRounded
                        layer.textureSize: list.thumbTextureSize

                        Rectangle { anchors.fill: parent; color: Theme.shelfThumbFill }
                        Image {
                            anchors.fill: parent
                            source: del.boxart
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.height: list.thumbTextureSize.height
                        }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        visible: Theme.shelfRounded
                        source: card
                        maskEnabled: true
                        maskSource: thumbMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (del.index === root.currentIndex) {
                            root.launchRequested(del.index)
                        } else {
                            root.currentIndex = del.index
                            Sounds.play("move")
                        }
                    }
                }
            }
        }
    }

    // Soulignement : fixe, sous la vignette active.
    Appear {
        x: Theme.margin
        y: Theme.underlineY - (Theme.shelfBottom - Theme.shelfThumbSize.height)
        width: Theme.shelfThumbSize.width * Theme.shelfActiveScale
        height: Theme.underlineHeight
        shown: root.shown
        delay: root.enterStep * Theme.enterRankUnderline

        Rectangle { anchors.fill: parent; radius: Theme.underlineRadius; color: Theme.accent }
    }
}
