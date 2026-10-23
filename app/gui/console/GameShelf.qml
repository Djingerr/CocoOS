import QtQuick
import QtQuick.Effects

// Étagère de vignettes portrait (3:4, les jaquettes) en bas de l'accueil : le carrousel du
// prototype des micro-interactions, à sélecteur fixe : l'anneau reste à gauche et ce sont
// les vignettes qui défilent dessous (ressort « vif »). Avec la manette, la vignette active grandit depuis son
// centre et les autres s'estompent ; sans elle (panneau ouvert, héros), l'anneau s'efface.
// Consomme un modèle exposant le rôle `boxart` (url ; vide = pas de jaquette) et,
// s'il les a, `name` (écrit sur la vignette de repli), `favorite` (pastille), `pending`
// (jeu pas encore installé : estompé) et `progress` (0..1, barre de téléchargement ; < 0 :
// aucune). La vignette du jeu `runningName` (en cours sur le PC) porte un point qui pulse.
// Aucune dépendance Moonlight.
FocusScope {
    id: root

    property alias model: list.model
    property string runningName: ""      // jeu en cours sur le PC ; vide = aucun
    readonly property alias count: list.count
    property int currentIndex: 0
    // Sens du dernier déplacement (+1 vers la droite, -1 vers la gauche).
    property int direction: 1
    // Apparition des vignettes et de l'anneau (cf. Appear) : fondu et échelle,
    // `enterStep` étant le délai par rang de l'entrée (0 = tous ensemble, sans délai).
    property bool shown: true
    property int enterStep: 0
    signal launchRequested(int index)
    signal detailsRequested()
    signal upRequested()             // haut : au-dessus, le héros (une partie en cours), ou rien
    signal collectionRequested(int direction)   // L1 / R1 (Page préc. / suiv.) : collection voisine
    // A enfoncé : la vignette active s'écrase (Theme.shelfTapScale) et le bouton Jouer avec
    // elle (cf. Pressable). Le jeu part au relâché, et seulement si l'appui a eu lieu ici :
    // le relâché d'un A qui a fermé un panneau ne lance rien.
    property bool pressing: false
    // L'étagère a la manette (« carrousel actif » du prototype).
    readonly property bool focused: activeFocus
    // Reflet (0 → 1) qui balaie la vignette active : une fois, Theme.sheenDelay après
    // chaque déplacement (comme le prototype), et seulement si l'étagère a la manette (ni
    // en veille, ni pendant un lancement ou dans un panneau) et que son entrée est finie.
    property real sheen: 0
    readonly property bool sheenArmed: focused && shown && enterStep === 0 && !Theme.reducedMotion
    function restartSheen() {
        sheenSweep.stop()
        sheen = 0
        if (sheenArmed) sheenWait.restart()
        else sheenWait.stop()
    }
    onSheenArmedChanged: restartSheen()
    Timer { id: sheenWait; interval: Theme.sheenDelay; onTriggered: sheenSweep.start() }
    NumberAnimation {
        id: sheenSweep
        target: root; property: "sheen"; from: 0; to: 1
        duration: Theme.sheenDuration
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveInOut
    }

    // Vignette de repli : une teinte stable par jeu, tirée de son nom.
    function hue(name) {
        var h = 0
        for (var i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 360
        return h / 360
    }

    readonly property real pitch: Theme.shelfThumbSize.width + Theme.shelfGap
    property bool animated: false       // pas de ressort pendant la mise en place
    // Défilement de la piste (px) : la vignette active toujours sous l'anneau, à la marge
    // gauche ; aux extrémités, la piste bute (bump, en index) puis revient. Pas de ressort
    // tant que l'étagère n'est pas montrée : une sélection posée avant l'entrée (dernier jeu
    // joué) est d'emblée en place.
    property real bump: 0
    property real scroll: (currentIndex + bump) * pitch
    Behavior on scroll {
        enabled: root.animated && root.shown
        NumberAnimation {
            duration: Theme.springSnappy.duration
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
        }
    }
    // Place de la vignette active, agrandie, sous l'anneau (l'écran de lancement en part).
    readonly property rect activeRect: {
        var w = Theme.shelfThumbSize.width, h = Theme.shelfThumbSize.height, k = Theme.shelfActiveScale
        return Qt.rect(Theme.margin + w * (1 - k) / 2, h * (1 - k) / 2, w * k, h * k)
    }

    implicitHeight: Theme.shelfThumbSize.height

    property int lastIndex: 0
    onCurrentIndexChanged: {
        if (currentIndex !== lastIndex)
            direction = currentIndex > lastIndex ? 1 : -1
        lastIndex = currentIndex
        restartSheen()
    }

    Component.onCompleted: {
        lastIndex = currentIndex
        animated = true
    }
    // (count vaut 0 tant que le modèle n'est pas chargé : ne pas y perdre la sélection.)
    onCountChanged: if (count > 0 && currentIndex >= count) currentIndex = count - 1

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

    // L2 / R2 (Maj + ← / → au clavier) : Theme.shelfJump vignettes d'un coup, jusqu'au bout.
    function jump(dir) {
        var next = Math.max(0, Math.min(count - 1, currentIndex + dir * Theme.shelfJump))
        if (next === currentIndex) move(dir)    // déjà au bout : la butée
        else {
            currentIndex = next
            Sounds.play("move")
        }
    }

    // Nouvelle collection : la piste arrive du côté demandé, en fondu.
    property real slideX: 0
    property real slideOpacity: 1
    function slideIn(dir) {
        if (Theme.reducedMotion) return
        slideAnim.stop()
        slideX = dir * Theme.collectionSlide
        slideOpacity = 0
        slideAnim.start()
    }
    ParallelAnimation {
        id: slideAnim
        NumberAnimation {
            target: root; property: "slideX"; to: 0
            duration: Theme.collectionSlideDuration; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "slideOpacity"; to: 1
            duration: Theme.collectionSlideDuration; easing.type: Easing.OutCubic
        }
    }

    // Molette sur l'étagère : une vignette par cran (les pavés tactiles s'additionnent).
    property real wheelRest: 0
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
            var delta = wheel.angleDelta.x !== 0 ? -wheel.angleDelta.x : wheel.angleDelta.y
            root.wheelRest += delta
            while (Math.abs(root.wheelRest) >= 120) {
                root.move(root.wheelRest > 0 ? -1 : 1)
                root.wheelRest -= root.wheelRest > 0 ? 120 : -120
            }
        }
    }

    // --- Gauche / droite, avec répétition qui accélère à l'appui prolongé ---
    PadRepeat {
        id: pad
        keys: [Qt.Key_Left, Qt.Key_Right]
        onTriggered: function(key) { root.move(key === Qt.Key_Left ? -1 : 1) }
    }
    Keys.onPressed: function(event) {
        if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true
            root.jump(event.key === Qt.Key_Left ? -1 : 1)
            return
        }
        if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
            event.accepted = true
            if (!event.isAutoRepeat) root.collectionRequested(event.key === Qt.Key_PageUp ? -1 : 1)
            return
        }
        pad.press(event)
    }
    Keys.onReleased: function(event) {
        pad.release(event)
        if (pressing && !event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.launchRequested(currentIndex)   // (d'abord : un lancement garde le bouton enfoncé)
            pressing = false
        }
    }
    Keys.onUpPressed: root.upRequested()
    Keys.onDownPressed: root.detailsRequested()      // la fiche du jeu (ou une butée)
    Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) pressing = true }
    Keys.onEnterPressed: function(event) { if (!event.isAutoRepeat) pressing = true }
    onActiveFocusChanged: if (!activeFocus) { pad.stop(); pressing = false }

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
    // jamais seule, c'est `scroll` qui fixe contentX.
    ListView {
        id: list

        // Texture des vignettes : à la taille réellement affichée de la plus grande.
        readonly property size thumbTextureSize: Qt.size(
            Math.ceil(Theme.shelfThumbSize.width * Theme.shelfActiveScale * Theme.scale),
            Math.ceil(Theme.shelfThumbSize.height * Theme.shelfActiveScale * Theme.scale))
        // (originX : la vue décale son origine quand un élément passe devant les autres, ou
        // quand elle revient de loin et place ses vignettes à l'estime.)
        function sync() {
            var x = originX + root.scroll - Theme.margin
            if (contentX !== x) contentX = x
        }

        width: parent.width; height: Theme.shelfThumbSize.height
        opacity: root.slideOpacity
        transform: Translate { x: root.slideX }
        orientation: ListView.Horizontal
        interactive: false
        highlightFollowsCurrentItem: false
        currentIndex: -1
        // Synchronisation impérative : ListView réécrit contentX de son côté quand
        // le modèle change, ce qu'une simple liaison ne rattraperait pas.
        // Pas de liaison : l'origine bouge pendant qu'on écrit contentX (boucle de liaison).
        onOriginXChanged: sync()
        onContentXChanged: sync()
        Component.onCompleted: sync()
        Connections { target: root; function onScrollChanged() { list.sync() } }

        delegate: Item {
            id: del

            required property int index
            required property url boxart
            required property var model
            readonly property string name: model.name || ""
            readonly property bool favorite: model.favorite === true
            readonly property bool running: name !== "" && name === root.runningName
            readonly property bool pending: model.pending === true
            readonly property real progress: typeof model.progress === "number" ? model.progress : -1
            readonly property bool current: index === root.currentIndex
            readonly property bool lit: current && root.focused       // agrandie, pleine, ombrée
            // 0 → 1 : ombre et filet de la vignette active.
            property real glow: lit ? 1 : 0
            Behavior on glow {
                NumberAnimation {
                    duration: Theme.shelfFocusFade
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
            // Survolée à la souris (pas la vignette active) : elle grandit un peu et s'éclaire.
            readonly property bool hovered: thumbMouse.containsMouse && !lit
            property real dim: root.focused && !current ? (hovered ? Theme.shelfHoverOpacity : Theme.shelfRestOpacity) : 1
            Behavior on dim {
                NumberAnimation {
                    duration: Theme.shelfFocusFade
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
            // (une vignette créée en défilant ne rejoue pas son agrandissement)
            property bool ready: false
            Component.onCompleted: ready = true

            width: root.pitch; height: Theme.shelfThumbSize.height

            Item {
                id: thumb
                width: Theme.shelfThumbSize.width; height: Theme.shelfThumbSize.height
                opacity: del.dim * (del.pending ? Theme.shelfPendingOpacity : 1)
                states: [
                    State {
                        name: "tap"; when: del.lit && root.pressing
                        PropertyChanges { target: thumb; scale: Theme.shelfTapScale }
                    },
                    State {
                        name: "lit"; when: del.lit
                        PropertyChanges { target: thumb; scale: Theme.shelfActiveScale }
                    },
                    State {
                        name: "hover"; when: del.hovered
                        PropertyChanges { target: thumb; scale: Theme.shelfHoverScale }
                    }
                ]
                transitions: [
                    Transition {
                        to: "tap"
                        enabled: del.ready
                        NumberAnimation {
                            property: "scale"; duration: Theme.pressDuration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                        }
                    },
                    Transition {
                        enabled: del.ready
                        NumberAnimation {
                            property: "scale"; duration: Theme.springSnappy.duration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                        }
                    }
                ]

                Appear {
                    anchors.fill: parent
                    shown: root.shown
                    delay: root.enterStep > 0 ? Theme.entryCardDelay + root.enterStep * Math.min(del.index, Theme.entryCardSpan) : 0
                    hiddenY: 0
                    hiddenScale: Theme.entryCardScale
                    hideDuration: 0
                    fadeDuration: Theme.entryCardFade
                    moveDuration: Theme.entryCardFade
                    fadeEasing: Easing.BezierSpline
                    moveEasing: Easing.BezierSpline
                    // Hors cascade d'entrée, une vignette créée en défilant est là d'emblée.
                    animateInitially: root.enterStep > 0

                    // Ombre portée, sous la vignette active seulement (pré-calculée).
                    Image {
                        x: -Theme.shelfShadowPad; y: -Theme.shelfShadowPad
                        width: parent.width + 2 * Theme.shelfShadowPad
                        height: parent.height + 2 * Theme.shelfShadowPad
                        source: "shadows/thumb.png"
                        opacity: del.glow
                        visible: opacity > 0 && !Theme.reducedMotion
                    }
                    Item {
                        id: card
                        anchors.fill: parent
                        clip: true                  // (le reflet déborde)
                        visible: !Theme.shelfRounded
                        layer.enabled: Theme.shelfRounded
                        layer.textureSize: list.thumbTextureSize

                        Rectangle { anchors.fill: parent; color: Theme.shelfThumbFill }
                        // Pas de jaquette (ou illisible) : le nom du jeu sur un dégradé.
                        Rectangle {
                            id: fallback
                            anchors.fill: parent
                            visible: del.boxart.toString() === "" || art.status === Image.Error
                            readonly property real tint: root.hue(del.name)
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: Qt.hsla(fallback.tint, Theme.placeholderSaturation, Theme.placeholderLightTop, 1)
                                }
                                GradientStop {
                                    position: 1
                                    color: Qt.hsla(fallback.tint, Theme.placeholderSaturation, Theme.placeholderLightBottom, 1)
                                }
                            }
                            Text {
                                anchors.fill: parent
                                anchors.margins: Theme.placeholderPad
                                text: del.name
                                color: Theme.placeholderInk
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                                maximumLineCount: Theme.placeholderLines
                                elide: Text.ElideRight
                                font.family: Theme.fontUi; font.pixelSize: Theme.placeholderTextSize
                                font.weight: Font.DemiBold
                            }
                        }
                        Image {
                            id: art
                            anchors.fill: parent
                            source: del.boxart
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.height: list.thumbTextureSize.height
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.thumbFadeIn } }
                        }
                        // Pendant le chargement de la jaquette : une bande claire passe, en boucle.
                        Loader {
                            anchors.fill: parent
                            active: art.status === Image.Loading && !Theme.reducedMotion
                            sourceComponent: Item {
                                Rectangle {
                                    id: shimmer
                                    width: parent.width * Theme.shimmerSpan; height: parent.height
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Theme.shimmerColor }
                                        GradientStop { position: 1; color: "transparent" }
                                    }
                                    NumberAnimation on x {
                                        from: -shimmer.width; to: shimmer.parent.width
                                        duration: Theme.shimmerDuration; loops: Animation.Infinite
                                        easing.type: Easing.InOutSine
                                    }
                                }
                            }
                        }
                        // Reflet : la bande claire du dégradé du prototype, sur toute la
                        // hauteur de sa boîte (cf. Theme.sheen*). Créée le temps du balayage,
                        // sur la vignette active seulement : rien de plus à créer pendant que
                        // l'étagère glisse.
                        Loader {
                            active: del.index === root.currentIndex && root.sheen > 0 && root.sheen < 1
                            sourceComponent: Rectangle {
                                readonly property real angle: Theme.sheenAngle * Math.PI / 180
                                readonly property real boxWidth: card.width * Theme.sheenOversize
                                readonly property real boxHeight: card.height * Theme.sheenOversize
                                width: Theme.sheenSpan * (boxWidth * Math.cos(angle) + boxHeight * Math.sin(angle))
                                height: boxWidth * Math.sin(angle) + boxHeight * Math.cos(angle)
                                x: (card.width - width) / 2 + (2 * root.sheen - 1) * Theme.sheenTravel * boxWidth
                                y: (card.height - height) / 2
                                rotation: Theme.sheenAngle
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.rgba(Theme.sheenColor.r, Theme.sheenColor.g, Theme.sheenColor.b, 0) }
                                    GradientStop { position: 0.5; color: Theme.sheenColor }
                                    GradientStop { position: 1; color: Qt.rgba(Theme.sheenColor.r, Theme.sheenColor.g, Theme.sheenColor.b, 0) }
                                }
                            }
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
                    // Filet clair intérieur, plus net sur la vignette active.
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.shelfRounded ? Theme.shelfThumbRadius : 0
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, Theme.shelfEdge + (Theme.shelfEdgeActive - Theme.shelfEdge) * del.glow)
                    }
                    Rectangle {
                        visible: del.progress >= 0
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.pinBadgeInset }
                        height: Theme.shelfProgressHeight; radius: height / 2
                        color: Theme.shelfProgressTrack
                        Rectangle {
                            width: parent.width * Math.min(Math.max(del.progress, 0), 1)
                            height: parent.height; radius: parent.radius
                            color: Theme.accent
                        }
                    }
                    // En cours sur le PC : le point, et l'onde qui en part.
                    Item {
                        visible: del.running
                        x: Theme.pinBadgeInset; y: Theme.pinBadgeInset
                        width: Theme.runningDotSize + 2 * Theme.runningDotRing; height: width
                        Rectangle {
                            id: ripple
                            anchors.centerIn: parent
                            width: Theme.runningDotSize; height: width; radius: width / 2
                            color: Theme.accent
                            opacity: 0
                            SequentialAnimation {
                                running: del.running && !Theme.reducedMotion
                                loops: Animation.Infinite
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: ripple; property: "scale"; from: 1; to: Theme.runningRipple
                                        duration: Theme.runningPulse; easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: ripple; property: "opacity"; from: 0.6; to: 0
                                        duration: Theme.runningPulse; easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Theme.accent
                            border.width: Theme.runningDotRing; border.color: Theme.runningDotRingColor
                        }
                    }
                    Rectangle {
                        visible: del.favorite
                        anchors { top: parent.top; right: parent.right; margins: Theme.pinBadgeInset }
                        width: Theme.pinBadgeSize; height: width; radius: width / 2
                        color: Theme.accent
                        Image {
                            anchors.centerIn: parent
                            width: Theme.pinIconSize; height: width
                            source: "icons/pin.svg"
                            sourceSize: Qt.size(Math.ceil(width * Theme.shelfActiveScale * Theme.scale),
                                                Math.ceil(height * Theme.shelfActiveScale * Theme.scale))
                        }
                    }
                }

                HoverArea {
                    id: thumbMouse
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

    // L'anneau, fixe, au-dessus des vignettes : il apparaît avec elles à l'entrée.
    Appear {
        anchors.fill: parent
        shown: root.shown
        delay: root.enterStep > 0 ? Theme.entryCardDelay : 0
        hiddenY: 0
        hideDuration: 0
        fadeDuration: Theme.entryCardFade
        fadeEasing: Easing.BezierSpline

        Item {
            readonly property real boxWidth: Theme.shelfThumbSize.width * Theme.shelfActiveScale + 2 * Theme.shelfRingGap
            readonly property real boxHeight: Theme.shelfThumbSize.height * Theme.shelfActiveScale + 2 * Theme.shelfRingGap
            x: Theme.margin + (Theme.shelfThumbSize.width - boxWidth) / 2
            y: (Theme.shelfThumbSize.height - boxHeight) / 2
            width: boxWidth; height: boxHeight
            opacity: root.focused ? 1 : 0
            scale: root.focused ? 1 : Theme.shelfRingHiddenScale
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shelfRingFade
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.springSnappy.duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                }
            }

            Rectangle {         // halo
                readonly property real out: Theme.shelfRingWidth + Theme.shelfRingHalo
                anchors.fill: parent; anchors.margins: -out
                radius: Theme.shelfRingRadius + out
                color: "transparent"
                border.width: Theme.shelfRingHalo; border.color: Theme.shelfRingHaloColor
            }
            Rectangle {         // trait
                anchors.fill: parent; anchors.margins: -Theme.shelfRingWidth
                radius: Theme.shelfRingRadius + Theme.shelfRingWidth
                color: "transparent"
                border.width: Theme.shelfRingWidth; border.color: Theme.ink
            }
        }
    }
}
