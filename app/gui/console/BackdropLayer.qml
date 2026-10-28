import QtQuick
import QtQuick.Effects

// Fond CocoOS : l'art du jeu sélectionné, très flouté, en plein écran, sous un
// vignettage radial et un grain (DESIGN_SYSTEM « Couleur », AccueilCarrousel). Deux
// calques en fondu croisé : le nouveau passe devant, l'ancien est vidé ensuite.
// Le flou est fait une fois, sur une petite copie de l'image (Theme.backdropBlurSize) ;
// ensuite un seul passage de shader par calque (shaders/Backdrop.frag) la cadre, la fait
// dériver, la vignette et la graine. Aucune dépendance Moonlight.
Item {
    id: root

    // Image à afficher. Un changement n'est appliqué qu'après l'anti-rebond, en
    // fondu croisé ; la toute première image apparaît sans fondu.
    property url source
    // Dérive lente du fond. La couper la fige sur place, ce qui laisse le GPU
    // au repos (elle redémarre à chaque nouvelle image).
    property bool driftEnabled: true
    // Zoom d'ensemble (lancement d'un jeu) ; `unveiled` retire le vignettage.
    property real zoom: 1
    property bool unveiled: false
    // Noir du vignettage au-delà de 75 % du rayon (0,85 à l'accueil, 0,9 pour un état vide).
    property real vignetteOut: Theme.vignetteOut
    property real vignette: unveiled ? 0 : 1
    Behavior on vignette { NumberAnimation { duration: Theme.launchScrimFade } }

    // Calque au premier plan (0 ou 1) ; -1 tant que rien n'est affiché.
    property int front: -1
    // Calque en cours de chargement, qui apparaîtra dès que son image est prête.
    property Item pending: null
    property bool completed: false
    // Un changement demandé pendant un fondu attend sa fin : le calque du dessous
    // est encore visible à travers, on ne peut pas le réutiliser tout de suite.
    property bool deferred: false
    readonly property var layers: [layerA, layerB]

    Component.onCompleted: {
        completed = true
        if (source.toString() !== "")
            swap()
    }
    onSourceChanged: {
        if (!completed) return
        if (front < 0) swap()
        else debounce.restart()
    }

    function swap() {
        if (front >= 0 && layers[front].fading) {
            deferred = true
            return
        }
        hold.stop()
        pending = layers[front === 0 ? 1 : 0]
        pending.load(root.source)
    }

    function reveal(layer) {
        if (layer !== pending) return
        pending = null
        var previous = front < 0 ? null : layers[front]
        front = layers.indexOf(layer)
        layer.show(previous === null)
        if (previous) {
            // Pas d'image à montrer : l'ancienne s'efface au lieu d'être recouverte.
            if (layer.status !== Image.Ready)
                previous.fadeOut()
            hold.restart()
        }
    }

    Timer { id: debounce; interval: Theme.backdropDebounce; onTriggered: root.swap() }
    Timer { id: hold; interval: Theme.backdropHold; onTriggered: root.layers[1 - root.front].clear() }

    component Layer: Item {
        id: layer

        property real drift: 0   // 0 → 1 → 0, en boucle
        readonly property alias fading: fade.running
        readonly property alias status: picture.status

        function load(url) {
            fade.stop()
            fadeAway.stop()
            driftAnim.stop()
            opacity = 0
            drift = 0
            z = 1
            picture.source = url
            driftAnim.start()
            // Image déjà disponible (ou absente) : onStatusChanged ne préviendra pas.
            if (picture.status !== Image.Loading)
                root.reveal(layer)
        }
        function show(instant) {
            if (instant) opacity = 1
            else fade.start()
        }
        function fadeOut() { fadeAway.start() }
        function clear() {
            driftAnim.stop()
            opacity = 0
            z = 0
            picture.source = ""
        }

        anchors.fill: parent
        opacity: 0

        // La petite copie floutée, cadrée comme l'écran et son débord (inset : -100px). Le
        // shader lit la sortie du MultiEffect (sa couche), pas l'image.
        Image {
            id: picture
            width: Theme.backdropBlurSize.width
            height: Theme.backdropBlurSize.height
            visible: false
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            sourceSize: Qt.size(width * 2, height * 2)
            onStatusChanged: if (status === Image.Ready || status === Image.Error) root.reveal(layer)
        }
        MultiEffect {
            id: blurred
            width: picture.width
            height: picture.height
            visible: false
            source: picture
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: Theme.backdropBlurMax
            blur: 1
            layer.enabled: true
            layer.smooth: true
        }

        ShaderEffect {
            anchors.fill: parent
            visible: picture.status === Image.Ready
            readonly property size size: Qt.size(width, height)
            readonly property real inset: Theme.backdropInset
            readonly property real zoom: Theme.backdropPanScaleFrom
                                         + (Theme.backdropPanScaleTo - Theme.backdropPanScaleFrom) * layer.drift
            readonly property point offset: Qt.point(Theme.backdropPanShift.x * layer.drift * zoom,
                                                     Theme.backdropPanShift.y * layer.drift * zoom)
            readonly property real vignetteIn: Theme.vignetteIn
            readonly property real vignetteOut: root.vignetteOut
            readonly property real vignette: root.vignette
            readonly property real grain: Theme.grainOpacity
            readonly property real grainSize: Theme.grainSize
            readonly property var source: blurred
            readonly property var noise: grainImage
            fragmentShader: "shaders/Backdrop.frag.qsb"
        }

        NumberAnimation {
            id: fade
            target: layer; property: "opacity"; to: 1
            duration: Theme.backdropFade; easing.type: Easing.InOutQuad
            onFinished: if (root.deferred) {
                root.deferred = false
                root.swap()
            }
        }
        NumberAnimation {
            id: fadeAway
            target: layer; property: "opacity"; to: 0
            duration: Theme.backdropFade; easing.type: Easing.InOutQuad
        }
        SequentialAnimation {
            id: driftAnim
            loops: Animation.Infinite
            paused: running && !root.driftEnabled
            NumberAnimation {
                target: layer; property: "drift"; from: 0; to: 1
                duration: Theme.driftDuration; easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: layer; property: "drift"; from: 1; to: 0
                duration: Theme.driftDuration; easing.type: Easing.InOutSine
            }
        }
    }

    Image {
        id: grainImage
        source: "images/grain.png"
        visible: false
    }

    Item {
        anchors.fill: parent
        transform: Scale {
            origin.x: root.width * Theme.backdropZoomOrigin.x
            origin.y: root.height * Theme.backdropZoomOrigin.y
            xScale: root.zoom; yScale: root.zoom
        }
        Layer { id: layerA }
        Layer { id: layerB }
    }
}
