import QtQuick
import QtQuick.Effects

// Carrousel 3D de l'accueil CocoOS (AccueilCarrousel, MotionNavigation, MotionJaquettes,
// CasLimites) : la jaquette sélectionnée au centre, les autres de part et d'autre, plus
// petites, tournées vers elle en perspective et assombries, avec leur reflet au sol.
// Présentation pure, aucune dépendance Moonlight. Remplace l'étagère « Ambiant »
// (GameShelf) avec la même interface pour HomeScreen.
//
// Chaque jaquette suit une seule valeur, `position` (le jeu au centre, fractionnaire en
// mouvement) : sa place, sa taille, sa rotation et sa luminosité s'interpolent entre les
// emplacements de Theme.coverSlots. Un nouvel appui relance l'animation de `position`
// depuis là où elle en est (interruptible, MotionInterruption).
// Modèle : rôles `name`, `boxart` (jaquette Apollo) et, s'ils existent, `cover` (jaquette
// Playnite, préférée), `publisher` (jaquette composée). Remplit son parent : x = 0 est le
// bord du canevas, y = 0 son haut.
FocusScope {
    id: root

    property alias model: repeater.model
    readonly property alias count: repeater.count
    property int currentIndex: 0
    property int direction: 1            // sens du dernier déplacement (+1 : vers la droite)
    property string runningName: ""      // (étagère Ambiant : le jeu en cours ; pas de marque ici)
    property bool shown: true
    property int enterStep: 0            // (étagère Ambiant : cascade d'entrée)
    property bool pressing: false        // A enfoncé
    readonly property bool focused: activeFocus
    // Flèche tenue (l'aide en bas l'allume) : -1 gauche, +1 droite, 0 aucune.
    readonly property int heldDirection: pad.heldKey === Qt.Key_Left ? -1 : pad.heldKey === Qt.Key_Right ? 1 : 0

    signal launchRequested(int index)
    signal detailsRequested()
    signal upRequested()
    signal collectionRequested(int direction)

    // La jaquette centrale, sur le canevas : l'écran de lancement en part.
    readonly property rect activeRect: Qt.rect(width / 2 - Theme.coverSlots[0][0] / 2,
                                               Theme.coverFloor - Theme.coverSlots[0][1],
                                               Theme.coverSlots[0][0], Theme.coverSlots[0][1])

    // Lancement d'un jeu (MotionLancement) : les voisines s'écartent en s'effaçant ; au retour
    // (MotionQuitter), elles reviennent du centre, à plat et plus petites.
    property bool launching: false
    // Le retour (après un jeu : MotionQuitter ; au réveil : MotionVeille) : délai, écart entre
    // rangs, durées, et d'où elles reviennent (part du chemin vers le centre, échelle).
    property int gatherDelay: Theme.returnCoverDelay
    property int gatherStagger: Theme.returnCoverStagger
    property int gatherMove: Theme.returnCoverMove
    property int gatherFade: Theme.returnCoverFade
    property real gatherAmount: Theme.returnCoverGather
    property real gatherScale: Theme.returnCoverScale
    // Au départ, les voisines se replient vers le centre au lieu de s'écarter (extinction :
    // MotionExtinction), les plus éloignées d'abord.
    property bool leaveGather: false
    // PC hors ligne (EtatHorsLigne) : jaquettes grisées, assombries, à 55 %.
    property bool greyed: false
    property real grey: greyed ? 1 : 0
    Behavior on grey { NumberAnimation { duration: Theme.offlineFade } }

    // --- Fiche du jeu (FicheEditoriale, MotionFiche) : la jaquette centrale devient la sienne ---
    // 0 → 1 : elle glisse en Theme.ficheCover et s'incline, les autres s'écartent et s'effacent.
    property bool detailOpen: false
    property real detail: detailOpen ? 1 : 0
    Behavior on detail {
        NumberAnimation {
            duration: Theme.reducedMotion ? Theme.reducedSpring.duration : root.detailOpen ? Theme.ficheOpen : Theme.ficheClose
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
        }
    }
    // Inclinaison de la jaquette de la fiche, qui oscille lentement (cocoTilt).
    property real sway: Theme.ficheTilt[0]
    SequentialAnimation on sway {
        running: root.detail > 0 && !Theme.reducedMotion
        loops: Animation.Infinite
        NumberAnimation { to: Theme.ficheTilt[1]; duration: Theme.ficheTiltPeriod; easing.type: Easing.InOutSine }
        NumberAnimation { to: Theme.ficheTilt[0]; duration: Theme.ficheTiltPeriod; easing.type: Easing.InOutSine }
    }
    function mix(a, b, t) { return a + (b - a) * t }

    // --- Position animée ---
    property real position: currentIndex
    property bool fast: false            // flèche maintenue : pas rapides, sans rebond
    property real bump: 0                // butée : tout le carrousel recule
    property int lastIndex: 0
    property bool completed: false

    onCurrentIndexChanged: {
        if (currentIndex !== lastIndex)
            direction = currentIndex > lastIndex ? 1 : -1
        lastIndex = currentIndex
        if (!completed || Theme.reducedMotion) {
            slide.stop()
            position = currentIndex
            return
        }
        slide.duration = fast ? Theme.coverMoveFast : Theme.coverMove
        slide.easing.bezierCurve = fast ? Theme.curveCoverFast : Theme.curveCoverMove
        slide.to = currentIndex
        slide.restart()
    }
    NumberAnimation {
        id: slide
        target: root; property: "position"
        easing.type: Easing.BezierSpline
    }
    Component.onCompleted: {
        lastIndex = currentIndex
        position = currentIndex
        completed = true
    }
    // (count vaut 0 tant que le modèle n'est pas chargé : ne pas y perdre la sélection.)
    // Un Repeater compte ses éléments un à un pendant qu'on remplit le modèle : attendre la
    // fin du remplissage avant de ramener la sélection dans la liste.
    onCountChanged: Qt.callLater(function() { if (count > 0 && currentIndex >= count) currentIndex = count - 1 })

    // Déplace la sélection d'un cran ; en bout de liste, le carrousel bute.
    function move(dir) {
        var next = currentIndex + dir
        if (next < 0 || next >= count) {
            bumpAnim.stop()
            bumpOut.to = -dir * Theme.coverBump
            bumpAnim.start()
            Sounds.play("edge")
            return
        }
        currentIndex = next
        Sounds.play(fast ? "nav_move_fast" : "nav_move", "nav_move")   // même vibration (cues.json)
    }
    SequentialAnimation {
        id: bumpAnim
        NumberAnimation {
            id: bumpOut
            target: root; property: "bump"
            duration: Theme.coverBumpOut
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveCoverFast
        }
        NumberAnimation {
            target: root; property: "bump"; to: 0
            duration: Theme.coverBumpBack
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveCoverFast
        }
    }

    // --- Saut alphabétique (RT / LT, CasLimites) : au-delà de Theme.coverJumpMin jeux, à la
    //     première jaquette de la lettre suivante (ou de la précédente). ---
    function initial(i) {
        var name = repeater.itemAt(i) ? repeater.itemAt(i).name : ""
        var c = name.normalize("NFD").replace(/[̀-ͯ]/g, "").charAt(0).toUpperCase()
        return /[A-Z]/.test(c) ? c : "#"
    }
    function jump(dir) {
        if (count < Theme.coverJumpMin)
            return
        var letter = initial(currentIndex)
        var i = currentIndex
        while (i + dir >= 0 && i + dir < count && initial(i + dir) === letter)
            i += dir
        i += dir
        if (i < 0 || i >= count) {
            move(dir)                    // plus de lettre de ce côté : la butée
            return
        }
        if (dir < 0) {                   // la première jaquette de la lettre précédente
            var previous = initial(i)
            while (i > 0 && initial(i - 1) === previous)
                i--
        }
        currentIndex = i
        letterBox.letter = initial(i)
        letterBox.flash()
        Sounds.play("tab_switch", "category_next")
    }

    // --- Changement de catégorie (MotionCategories) : le carrousel arrive du côté demandé ---
    property real slideX: 0
    property real slideBlur: 0
    property real slideOpacity: 1
    function slideIn(dir) {
        if (Theme.reducedMotion) return
        categoryAnim.stop()
        slideX = dir * Theme.categorySlide
        slideBlur = Theme.categoryBlur
        slideOpacity = 0
        categoryAnim.start()
    }
    ParallelAnimation {
        id: categoryAnim
        NumberAnimation {
            target: root; property: "slideX"; to: 0
            duration: Theme.categoryEnterMove
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.categoryEnterDelay }
            ParallelAnimation {
                NumberAnimation { target: root; property: "slideOpacity"; to: 1; duration: Theme.categoryEnterFade }
                NumberAnimation { target: root; property: "slideBlur"; to: 0; duration: Theme.categoryEnterFade }
            }
        }
    }

    // --- Balayage de la jaquette centrale (cocoSheen) ---
    property real sheen: -2
    SequentialAnimation on sheen {
        running: root.shown && !Theme.reducedMotion
        loops: Animation.Infinite
        PropertyAction { value: -1.6 }
        PauseAnimation { duration: Theme.sheenPeriod * 0.55 }
        NumberAnimation {
            to: 4.2; duration: Theme.sheenPeriod * 0.3
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1]
        }
        PauseAnimation { duration: Theme.sheenPeriod * 0.15 }
    }

    // Emplacement à la distance k (0 à 4, fractionnaire) : interpolé entre ceux de Theme.
    function slotAt(k) {
        var i = Math.min(Math.floor(k), 3), f = k - i
        var a = Theme.coverSlots[i], b = Theme.coverSlots[i + 1]
        var mix = function(j) { return a[j] + (b[j] - a[j]) * f }
        return { w: mix(0), h: mix(1), dx: mix(2), brightness: mix(3),
                 angle: Theme.coverAngles[i] + (Theme.coverAngles[i + 1] - Theme.coverAngles[i]) * f }
    }
    // perspective(900px) rotateY(deg), autour du centre d'un élément w × h (comme en CSS).
    function tilt(w, h, deg) {
        var a = deg * Math.PI / 180, c = Math.cos(a), s = Math.sin(a) / Theme.coverPerspective
        var cx = w / 2, cy = h / 2
        return Qt.matrix4x4(c + cx * s, 0, 0, cx - c * cx - cx * cx * s,
                            cy * s, 1, 0, -cy * cx * s,
                            0, 0, 1, 0,
                            s, 0, 0, 1 - s * cx)
    }
    // Teinte d'une jaquette composée : une des six de secours, choisie par le nom.
    function composedHue(name) {
        var h = 0
        for (var i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 9973
        return Theme.composedHues[h % Theme.composedHues.length] / 360
    }

    // --- Manette et clavier ---
    PadRepeat {
        id: pad
        keys: [Qt.Key_Left, Qt.Key_Right]
        interval: Theme.navFastStep
        minimum: Theme.navFastStep
        step: 0
        onTriggered: function(key) {
            root.fast = pad.repeats > 0
            root.move(key === Qt.Key_Left ? -1 : 1)
        }
        onHeldKeyChanged: if (heldKey === 0) root.fast = false
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
            if (count > 0) root.launchRequested(currentIndex)   // (d'abord : un lancement garde le bouton enfoncé)
            pressing = false
        }
    }
    Keys.onUpPressed: root.upRequested()
    Keys.onDownPressed: if (count > 0) root.detailsRequested()
    Keys.onReturnPressed: function(event) { if (!event.isAutoRepeat) pressing = true }
    Keys.onEnterPressed: function(event) { if (!event.isAutoRepeat) pressing = true }
    onActiveFocusChanged: if (!activeFocus) { pad.stop(); pressing = false }

    // Molette : une jaquette par cran (les pavés tactiles s'additionnent).
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

    // --- Les jaquettes ---
    Item {
        id: strip
        width: root.width
        height: Theme.coverAreaHeight
        x: root.slideX
        opacity: (root.shown ? 1 : 0) * root.slideOpacity * (1 - (1 - Theme.offlineCovers) * root.grey)
        Behavior on opacity { enabled: !categoryAnim.running; NumberAnimation { duration: Theme.entryCardFade } }
        // Flou d'ensemble seulement le temps d'un saut de lettre, d'un changement de catégorie ou
        // d'un défilement rapide (flèche maintenue : « jaquettes floutées en mouvement »).
        property real fastBlur: root.fast && !Theme.reducedMotion ? Theme.coverFastBlur : 0
        Behavior on fastBlur { NumberAnimation { duration: Theme.coverFastBlurFade } }
        readonly property real blurPx: Math.max(root.slideBlur, letterBox.shown ? Theme.letterBlur : 0, fastBlur)
        layer.enabled: (blurPx > 0 || root.grey > 0) && GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            blurEnabled: strip.blurPx > 0; blurMax: 16; blur: strip.blurPx / 16
            saturation: -root.grey
            brightness: Theme.offlineCoverDim * root.grey
        }

        Repeater {
            id: repeater
            delegate: Item {
                id: slot

                required property int index
                required property var model
                readonly property string name: model.name || ""
                readonly property url art: model.cover ? model.cover : (model.boxart || "")
                readonly property real o: index - root.position
                readonly property real k: Math.min(Math.abs(o), 4)
                readonly property real side: Math.min(k, 1)          // 0 au centre, 1 sur les côtés
                readonly property var place: root.slotAt(k)
                // Fiche ouverte : la centrale va en place, les autres s'écartent.
                readonly property bool central: Math.abs(o) < 0.5
                readonly property real fiche: central ? root.detail : 0
                readonly property real brightness: root.mix(place.brightness, Theme.ficheCoverBrightness, fiche)

                // Lancement : `away` 0 → 1 écarte (ou, au retour, `gather`, rapproche), `faded` efface.
                readonly property bool leaving: root.launching
                property bool gather: false
                property real away: 0
                property real faded: 0
                onLeavingChanged: {
                    gather = leaving ? root.leaveGather : faded > 0.99
                    var target = leaving && !central ? 1 : 0
                    awayAnim.stop()
                    awayWait.duration = leaving ? (root.leaveGather ? Math.max(0, 3 - k) : Math.max(0, k - 1)) * Theme.launchCoverStagger
                                      : gather && !Theme.reducedMotion ? root.gatherDelay + k * root.gatherStagger : 0
                    awayMove.to = awayFade.to = target
                    awayMove.duration = leaving ? Theme.launchCoverMove : root.gatherMove
                    awayFade.duration = Theme.reducedMotion ? Theme.reducedSpring.duration
                                      : leaving ? Theme.launchCoverFade : root.gatherFade
                    awayAnim.start()
                }
                // (créée pendant que l'accueil est caché, au démarrage : déjà partie, prête à revenir)
                Component.onCompleted: if (leaving && !central) { away = 1; faded = 1 }
                SequentialAnimation {
                    id: awayAnim
                    PauseAnimation { id: awayWait }
                    ParallelAnimation {
                        NumberAnimation {
                            id: awayMove; target: slot; property: "away"
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                        }
                        NumberAnimation { id: awayFade; target: slot; property: "faded" }
                    }
                }
                readonly property real moved: Theme.reducedMotion ? 0 : away
                readonly property real launchShift: gather ? -Math.sign(o) * place.dx * root.gatherAmount * moved
                                                           : Math.sign(o) * Theme.launchCoverSpread * moved
                scale: gather ? 1 - (1 - root.gatherScale) * moved : 1

                visible: Math.abs(o) < 4 && (central || root.detail < 1) && faded < 1
                x: root.mix(root.width / 2 + Math.sign(o) * (place.dx + Theme.ficheSpread * root.detail) + launchShift
                            + root.bump - place.w / 2,
                            Theme.ficheCover.x, fiche)
                y: root.mix(Theme.coverFloor - place.h, Theme.ficheCover.y, fiche)
                width: root.mix(place.w, Theme.ficheCover.width, fiche)
                height: root.mix(place.h, Theme.ficheCover.height, fiche)
                z: 10 - k
                opacity: (k <= 3 ? 1 : 4 - k) * (central ? 1 : 1 - root.detail) * (1 - faded)
                transform: Matrix4x4 {
                    matrix: root.tilt(slot.width, slot.height,
                                      root.mix(-Math.sign(slot.o) * slot.place.angle * (slot.gather ? 1 - slot.moved : 1),
                                               root.sway, slot.fiche))
                }

                // Ombres portées (pré-rendues), centrale et latérale en fondu.
                Image {
                    readonly property real f: slot.width / Theme.coverSlots[0][0]
                    x: -Theme.coverShadowPad * f; y: -Theme.coverShadowPad * f
                    width: slot.width + 2 * Theme.coverShadowPad * f
                    height: slot.height + 2 * Theme.coverShadowPad * f
                    source: "shadows/cover.png"
                    opacity: 1 - slot.side
                    visible: opacity > 0
                }
                Image {
                    readonly property real f: slot.width / Theme.coverSlots[1][0]
                    x: -Theme.coverSideShadowPad * f; y: -Theme.coverSideShadowPad * f
                    width: slot.width + 2 * Theme.coverSideShadowPad * f
                    height: slot.height + 2 * Theme.coverSideShadowPad * f
                    source: "shadows/coverSide.png"
                    opacity: slot.side
                    visible: opacity > 0
                }

                Loader {
                    anchors.fill: parent
                    active: slot.visible
                    sourceComponent: slot.art.toString() !== "" ? artCover : composedCover
                }

                // Favori (MotionFavori) : pastille cœur en haut à droite de la jaquette centrale ;
                // à l'ajout, un anneau accent s'en élargit.
                readonly property bool favorite: model.favorite === true
                readonly property bool badgeShown: favorite && central && root.detail < 0.01 && root.shown
                onFavoriteChanged: if (favorite && central && !Theme.reducedMotion) ringAnim.restart()
                Rectangle {
                    id: ring
                    x: parent.width - Theme.favBadgeInset - width; y: Theme.favBadgeInset
                    width: Theme.favBadgeSize; height: width; radius: width / 2
                    color: "transparent"
                    border.width: 2; border.color: Theme.accent
                    opacity: 0
                    SequentialAnimation {
                        id: ringAnim
                        PropertyAction { target: ring; property: "opacity"; value: 0.8 }
                        PropertyAction { target: ring; property: "scale"; value: 1 }
                        ParallelAnimation {
                            NumberAnimation { target: ring; property: "opacity"; to: 0; duration: Theme.favRingMove; easing.type: Easing.OutQuad }
                            NumberAnimation {
                                target: ring; property: "scale"; to: Theme.favRingScale; duration: Theme.favRingMove
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                            }
                        }
                    }
                }
                Rectangle {
                    x: parent.width - Theme.favBadgeInset - width; y: Theme.favBadgeInset
                    width: Theme.favBadgeSize; height: width; radius: width / 2
                    color: Theme.favBadgeFill
                    border.color: Theme.favBadgeStroke
                    visible: opacity > 0
                    opacity: slot.badgeShown ? 1 : 0
                    scale: slot.badgeShown ? 1 : 0.2
                    Behavior on opacity { NumberAnimation { duration: slot.badgeShown ? 150 : Theme.durExit } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: slot.badgeShown ? Theme.favBadgeIn : Theme.favBadgeOut
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: slot.badgeShown ? Theme.curveFavIn : Theme.curveExit
                        }
                    }
                    Heart { anchors.centerIn: parent; size: Theme.favHeartSize; filled: true }
                }

                // Jaquette d'après son image : un passage de shader (et un pour son reflet).
                Component {
                    id: artCover
                    Item {
                        id: cover
                        property real reveal: 0
                        property real zoom: 1
                        property real blurPx: 0
                        property real shimmer: -1.2

                        Image {
                            id: picture
                            source: slot.art
                            visible: false
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            sourceSize.width: Math.round(Theme.coverSlots[0][0] * Math.max(1, Theme.scale) * 1.5)
                            // Déjà là (cache) : aucune apparition ; sinon le fondu de MotionJaquettes.
                            Component.onCompleted: if (status === Image.Ready) cover.reveal = 1
                            onStatusChanged: if (status === Image.Ready && cover.reveal === 0) appear.start()
                        }
                        ParallelAnimation {
                            id: appear
                            NumberAnimation { target: cover; property: "reveal"; from: 0; to: 1; duration: Theme.coverRevealFade }
                            NumberAnimation {
                                target: cover; property: "zoom"; from: Theme.coverRevealZoom; to: 1
                                duration: Theme.coverRevealMove
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                            }
                            NumberAnimation { target: cover; property: "blurPx"; from: Theme.coverRevealBlur; to: 0; duration: Theme.coverRevealFade }
                        }
                        NumberAnimation on shimmer {
                            running: cover.reveal < 1 && !Theme.reducedMotion
                            from: -1.2; to: 2.6; loops: Animation.Infinite
                            duration: Theme.shimmerPeriod; easing.type: Easing.InOutSine
                        }

                        ShaderEffect {
                            id: face
                            anchors.fill: parent
                            readonly property size coverSize: Qt.size(width, height)
                            readonly property real itemHeight: height
                            readonly property real radius: Theme.radiusCover
                            readonly property real dim: 1 - slot.brightness
                            readonly property real gloss: root.mix(Theme.coverGloss, Theme.ficheGloss, slot.fiche)
                            readonly property real shade: Theme.coverShade * slot.side
                            readonly property real ring: root.mix(Theme.coverRing * (1 - slot.side), Theme.ficheRing, slot.fiche)
                            readonly property real sheen: slot.k < 0.5 ? root.sheen : -2
                            readonly property real shimmer: cover.shimmer
                            readonly property real reveal: cover.reveal
                            readonly property real zoom: cover.zoom
                            readonly property real blurPx: cover.blurPx
                            readonly property real mirror: 0
                            readonly property real mirrorAlpha: Theme.coverReflectAlpha
                            readonly property real mirrorSpan: Theme.coverReflectSpan
                            readonly property var source: picture
                            fragmentShader: "shaders/Cover.frag.qsb"
                        }
                        ShaderEffect {
                            y: parent.height + Theme.coverReflectGap
                            width: parent.width
                            height: parent.height * mirrorSpan
                            readonly property size coverSize: face.coverSize
                            readonly property real itemHeight: height
                            readonly property real radius: Theme.radiusCover
                            readonly property real dim: face.dim
                            readonly property real gloss: 0
                            readonly property real shade: 0
                            readonly property real ring: 0
                            readonly property real sheen: -2
                            readonly property real shimmer: -2
                            readonly property real reveal: cover.reveal
                            readonly property real zoom: 1
                            readonly property real blurPx: 0
                            readonly property real mirror: 1
                            readonly property real mirrorAlpha: root.mix(Theme.coverReflectAlpha, Theme.ficheReflectAlpha, slot.fiche)
                            readonly property real mirrorSpan: root.mix(Theme.coverReflectSpan, Theme.ficheReflectSpan, slot.fiche)
                            readonly property var source: picture
                            fragmentShader: "shaders/Cover.frag.qsb"
                        }
                        // Titre des latérales, sur le dégradé bas.
                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.coverTitleInset }
                            text: slot.name
                            visible: slot.side > 0
                            opacity: slot.side
                            color: Qt.rgba(Theme.ink.r * slot.brightness, Theme.ink.g * slot.brightness,
                                           Theme.ink.b * slot.brightness, 1)
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.coverTitleSize
                            font.weight: Font.DemiBold
                            lineHeight: Theme.coverTitleLineHeight
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }

                // Jaquette composée (CasLimites) : dégradé sourd, éditeur, titre.
                Component {
                    id: composedCover
                    Item {
                        readonly property real hue: root.composedHue(slot.name)
                        readonly property real unit: width
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusCover
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.hsla(hue, Theme.composedLevels[0][0], Theme.composedLevels[0][1], 1) }
                                GradientStop { position: 0.55; color: Qt.hsla(hue, Theme.composedLevels[1][0], Theme.composedLevels[1][1], 1) }
                                GradientStop { position: 1; color: Qt.hsla(hue, Theme.composedLevels[2][0], Theme.composedLevels[2][1], 1) }
                            }
                        }
                        Text {
                            x: Theme.composedInset * unit; y: x
                            width: parent.width - 2 * x
                            text: (slot.model.publisher || "").toUpperCase()
                            color: Theme.ink2
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.composedLabelSize * unit
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.08 * Theme.composedLabelSize * unit
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.composedInset * unit }
                            text: slot.name
                            color: Theme.ink
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.composedTitleSize * unit
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.03 * Theme.composedTitleSize * unit
                            lineHeight: 1.05
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusCover
                            color: "black"
                            opacity: 1 - slot.brightness
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, Theme.coverRing * (1 - slot.side))
                        }
                    }
                }
            }
        }
    }

    // Fondus noirs des bords (pas sur la fiche).
    Rectangle {
        opacity: 1 - root.detail
        width: Theme.coverEdgeFade; height: Theme.coverAreaHeight
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, Theme.coverEdgeFadeAlpha) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        opacity: 1 - root.detail
        x: root.width - width
        width: Theme.coverEdgeFade; height: Theme.coverAreaHeight
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, Theme.coverEdgeFadeAlpha) }
        }
    }

    // Lettre du saut alphabétique, dans un carré de verre au centre.
    Rectangle {
        id: letterBox
        property string letter: ""
        property bool shown: false
        function flash() { shown = true; letterHide.restart() }
        Timer { id: letterHide; interval: Theme.letterShow; onTriggered: letterBox.shown = false }

        width: Theme.letterBoxSize; height: width
        radius: Theme.letterBoxRadius
        x: (root.width - width) / 2
        y: Theme.coverFloor - Theme.coverSlots[0][1] / 2 - height / 2
        z: 20
        color: Theme.glassDialog
        border.color: Theme.hairlineStrong
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.86
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
        Behavior on scale { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpring } }
        Text {
            anchors.centerIn: parent
            text: letterBox.letter
            color: Theme.ink
            font.family: Theme.fontUi
            font.pixelSize: Theme.letterSize
            font.weight: Font.DemiBold
            font.letterSpacing: -0.03 * Theme.letterSize
        }
    }
}
