import QtQuick

// Fond de l'écran d'accueil : l'illustration du jeu sélectionné en plein écran,
// sous un voile de lisibilité. Deux calques d'image en fondu croisé : le nouveau
// passe devant, l'ancien est vidé ensuite. Aucune dépendance Moonlight.
// Volontairement sans flou ni `layer` : seuls opacity et transform sont animés.
Item {
    id: root

    // Image à afficher. Un changement n'est appliqué qu'après l'anti-rebond, en
    // fondu croisé ; la toute première image apparaît sans fondu.
    property url source
    // Dérive lente du fond. La couper la fige sur place, ce qui laisse le GPU
    // au repos (elle redémarre à chaque nouvelle image).
    property bool driftEnabled: true
    // Zoom d'ensemble de l'image (entrée de l'écran, lancement) ; le voile n'en
    // fait pas partie. `unveiled` le retire (lancement d'un jeu).
    property real zoom: 1
    property bool unveiled: false
    // Teinte ambiante : colore le bas du voile (transparente = aucune).
    property color tint: "transparent"
    Behavior on tint { ColorAnimation { duration: Theme.ambientFade } }

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

    component Layer: Image {
        id: layer

        property real drift: 0   // 0 → 1 → 0, en boucle
        readonly property alias fading: fade.running

        function load(url) {
            fade.stop()
            fadeAway.stop()
            driftAnim.stop()
            opacity = 0
            drift = 0
            z = 1
            source = url
            driftAnim.start()
            // Image déjà disponible (ou absente) : onStatusChanged ne préviendra pas.
            if (status !== Image.Loading)
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
            source = ""
        }

        anchors.fill: parent
        opacity: 0
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        // Décodée à la hauteur de l'écran, jamais à la taille d'origine.
        sourceSize.height: Math.round(root.height * Theme.scale)
        onStatusChanged: if (status === Image.Ready || status === Image.Error) root.reveal(layer)

        transform: [
            Translate {
                x: layer.width * Theme.driftShift.x * layer.drift
                y: layer.height * Theme.driftShift.y * layer.drift
            },
            Scale {
                origin.x: layer.width * Theme.driftOrigin.x
                origin.y: layer.height * Theme.driftOrigin.y
                xScale: Theme.driftScaleFrom + (Theme.driftScaleTo - Theme.driftScaleFrom) * layer.drift
                yScale: xScale
            }
        ]

        NumberAnimation {
            id: fade
            target: layer; property: "opacity"; to: 1
            duration: Theme.backdropFade; easing.type: Theme.easeOut
            onFinished: if (root.deferred) {
                root.deferred = false
                root.swap()
            }
        }
        NumberAnimation {
            id: fadeAway
            target: layer; property: "opacity"; to: 0
            duration: Theme.backdropFade; easing.type: Theme.easeOut
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

    // Voile de lisibilité (au-dessus des deux calques, hors zoom et hors dérive).
    Item {
        id: scrim
        anchors.fill: parent
        opacity: root.unveiled ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.launchScrimFade } }
        Rectangle { anchors.fill: parent; gradient: Theme.scrimLeft }
        Rectangle { anchors.fill: parent; gradient: Theme.scrimBottom }
        Rectangle { anchors.fill: parent; gradient: Theme.scrimTop }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: Theme.ambientTintStart; color: "transparent" }
                GradientStop {
                    position: 1
                    color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tint.a * Theme.ambientTintBottom)
                }
            }
        }
    }
}
