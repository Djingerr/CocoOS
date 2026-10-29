import QtQuick
import QtQuick.Effects

// Lancement d'un jeu (MotionLancement) : la jaquette du carrousel grandit jusqu'au plein écran
// pendant que l'image du jeu la remplace, puis l'anneau, le nom du jeu et l'état (« Réveil de
// PC-Salon… », « Lancement de Minecraft… », « Connexion au flux vidéo… »). Échec (MotionEchec) :
// l'anneau secoue et devient « ! », « PC-Salon ne répond pas », A Réessayer / Y Réveiller le PC /
// B Annuler. Présentation pure : l'appelant fournit les états et dit où l'on en est.
//
// Remplit son parent et se dessine, comme HomeScreen, sur un canevas de 800 de haut mis à
// l'échelle. À poser AU-DESSUS de la pile d'écrans de Moonlight : il reste visible pendant que
// la page de connexion d'origine travaille dessous.
FocusScope {
    id: root

    property url image                  // image du jeu (fond Playnite)
    // Jaquette d'où part l'écran : sa place sur le canevas et son image. Sans elle (origin
    // vide), l'image du jeu apparaît en fondu.
    property rect origin: Qt.rect(0, 0, 0, 0)
    property url thumbnail
    property string title               // nom du jeu, sous l'anneau
    property var steps: []              // états, dans l'ordre (« Lancement de Minecraft… »)
    property int step: 0
    property real progress: -1          // avancement connu de l'étape (mise à jour), sinon -1
    property bool cancellable: false    // B annule (préparation par le Companion)
    // Échec : son titre et son explication. Réessayer, et Réveiller le PC si `canWake`.
    property string error: ""
    property string errorTitle: ""
    property bool canWake: false
    // Fige les animations. Moonlight bloque l'interface en préparant son décodeur :
    // mieux vaut une image immobile qu'une animation qui saute.
    property bool frozen: false

    signal opened()                     // l'écran couvre tout, l'anneau est en place
    signal cancelRequested()            // B : annulation, ou abandon après un échec
    signal retryRequested()             // A après un échec
    signal wakeRequested()              // Y après un échec

    property bool active: false
    property bool leaving: false        // il retourne à la jaquette : l'accueil revient déjà
    readonly property bool covering: active && !leaving
    readonly property bool failed: error !== ""
    property bool loaderShown: false
    property bool ready: false          // le flux arrive : l'anneau se remplit, puis s'en va
    property real grow: 1
    property real art: 1

    visible: active

    function open() {
        intro.stop(); shrink.stop(); outro.stop()
        error = ""; errorTitle = ""; frozen = false
        ready = false; loaderShown = false; leaving = false
        content.opacity = 1
        grow = frame.fromThumb ? 0 : 1
        art = frame.fromThumb ? 0 : 1
        active = true
        forceActiveFocus()
        intro.restart()
    }
    // Le flux arrive : l'anneau se remplit, puis l'ensemble grandit en se floutant.
    function complete() {
        if (!active) return
        Sounds.stop("connecting_loop")
        ready = true
    }
    // Disparition immédiate (le flux a pris l'écran) ou animée (retour à l'accueil) : partie
    // de la jaquette, l'image y retourne en rétrécissant ; sinon, en fondu.
    function close(animated) {
        if (!active) return
        intro.stop()
        Sounds.stop("connecting_loop")
        leaving = true
        if (animated && frame.fromThumb) {
            loaderShown = false
            shrink.restart()
        } else if (animated) {
            outro.restart()
        } else {
            active = false
        }
    }

    onLoaderShownChanged: if (loaderShown && !failed && !ready) Sounds.play("connecting_loop")
    onFailedChanged: {
        if (failed) {
            Sounds.stop("connecting_loop")
            Sounds.play("host_unreachable")
            shake.restart()
        } else if (loaderShown) {
            Sounds.play("connecting_loop")
        }
    }

    // Tout est avalé : l'accueil, dessous, ne doit pas réagir. A agit au relâché.
    property bool aDown: false
    Keys.onPressed: function(event) {
        event.accepted = true
        if (event.isAutoRepeat) return
        if (event.key === Qt.Key_Escape && (cancellable || failed))
            cancelRequested()
        else if (failed && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
            aDown = true
        else if (failed && root.canWake && event.key === Qt.Key_Hangup)
            wakeRequested()
    }
    Keys.onReleased: function(event) {
        event.accepted = true
        if (event.isAutoRepeat) return
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && aDown) {
            aDown = false
            if (failed) {
                Sounds.play("select")
                retryRequested()
            }
        }
    }
    ParallelAnimation {
        id: intro
        paused: running && root.frozen
        SequentialAnimation {
            PauseAnimation { duration: frame.fromThumb ? Theme.launchFrameDelay : 0 }
            NumberAnimation {
                target: root; property: "grow"; to: 1
                duration: frame.fromThumb ? Theme.motion(Theme.launchFrameGrow, Theme.curveMain).duration : 0
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.launchArtDelay }
            NumberAnimation { target: root; property: "art"; to: 1; duration: Theme.launchArtFade }
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.launchLoaderAt }
            ScriptAction { script: root.loaderShown = true }
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.launchOpened }
            ScriptAction { script: root.opened() }
        }
    }
    SequentialAnimation {
        id: outro
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: Theme.returnArtFade }
        ScriptAction { script: root.active = false }
    }
    // Retour (annulation, échec) : comme au retour d'un jeu (MotionQuitter).
    SequentialAnimation {
        id: shrink
        ParallelAnimation {
            SequentialAnimation {
                PauseAnimation { duration: Theme.returnFrameDelay }
                NumberAnimation {
                    target: root; property: "grow"; to: 0
                    duration: Theme.motion(Theme.returnFrameShrink, Theme.curveMain).duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.returnArtDelay }
                NumberAnimation { target: root; property: "art"; to: 0; duration: Theme.returnThumbFade }
            }
        }
        ScriptAction { script: root.active = false }
    }

    Item {
        id: content
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        LaunchFrame {
            id: frame
            origin: root.origin
            grow: root.grow
            thumbnail: root.thumbnail
            image: root.image
            art: root.art
            drift: root.active
            dim: root.failed ? Theme.failDim : Theme.launchDim
            Behavior on dim { NumberAnimation { duration: Theme.failDimFade } }
        }

        // L'anneau, le nom du jeu et l'état ; à l'échec, le « ! », le titre, l'explication et
        // les boutons. La colonne remonte pour leur faire place.
        Item {
            id: column
            x: (parent.width - width) / 2
            y: root.failed ? Theme.failColumnTop : Theme.launchColumnTop
            Behavior on y {
                NumberAnimation {
                    duration: Theme.motion(Theme.failRise, Theme.curveMain).duration
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                }
            }
            width: Theme.failColumnWidth
            height: Theme.canvasHeight - y

            readonly property bool exiting: root.ready && !root.failed
            opacity: root.loaderShown && !exiting ? 1 : 0
            visible: opacity > 0
            scale: exiting ? Theme.launchLoaderExitScale : root.loaderShown ? 1 : Theme.launchLoaderFrom
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: Theme.launchLoaderFade } }
            Behavior on scale {
                enabled: !Theme.reducedMotion
                NumberAnimation {
                    duration: Theme.launchLoaderMove
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                }
            }
            property real blurPx: exiting && !Theme.reducedMotion ? Theme.launchLoaderExitBlur : 0
            Behavior on blurPx { NumberAnimation { duration: Theme.launchLoaderFade } }
            layer.enabled: blurPx > 0.1 && GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: column.blurPx / 16 }

            Item {
                id: ringBox
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.ringSize; height: width
                // Échec : l'anneau secoue (cocoShake).
                property real shakeProgress: 1
                transform: Translate {
                    x: {
                        var keys = Theme.failShakeKeys, at = ringBox.shakeProgress * (keys.length - 1)
                        var i = Math.min(Math.floor(at), keys.length - 2)
                        return keys[i] + (keys[i + 1] - keys[i]) * (at - i)
                    }
                }
                NumberAnimation {
                    id: shake
                    target: ringBox; property: "shakeProgress"; from: 0; to: 1
                    duration: Theme.reducedMotion ? 0 : Theme.failShake
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.failShakeCurve
                }

                LoaderRing {
                    anchors.fill: parent
                    spinning: !root.failed && !root.ready && root.progress < 0
                    track: root.failed ? Theme.failRingTrack : Theme.ringTrack
                    Behavior on track { ColorAnimation { duration: Theme.failRingFade } }
                    fill: root.failed ? 0 : root.ready ? 1 : Math.max(0, root.progress)
                    Behavior on fill {
                        NumberAnimation { duration: Theme.ringFill; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
                    }
                }
                FailAppear {
                    anchors.centerIn: parent
                    width: bang.width; height: bang.height
                    delay: Theme.failBangDelay
                    hiddenY: 0
                    hiddenScale: Theme.failBangFrom
                    moveDuration: Theme.failBangMove
                    bezier: Theme.curveFailBang
                    Text {
                        id: bang
                        text: "!"
                        color: Theme.ink
                        font.family: Theme.fontUi; font.pixelSize: Theme.failBangSize; font.weight: Font.Bold
                    }
                }
            }

            // Nom du jeu, ou titre de l'échec.
            Item {
                id: titleBox
                y: ringBox.height + Theme.launchTitleGap
                width: parent.width; height: Theme.failTitleHeight
                FailAppear {
                    width: parent.width; height: parent.height
                    shown: !root.failed
                    hiddenY: Theme.reducedMotion ? 0 : -Theme.failShift
                    delay: 0
                    CenteredText { text: root.title; size: Theme.launchTitleSize }
                }
                FailAppear {
                    width: parent.width; height: parent.height
                    delay: Theme.failTitleDelay
                    CenteredText { text: root.errorTitle; size: Theme.failTitleSize }
                }
            }
            // État, ou explication de l'échec.
            Item {
                id: statusBox
                y: titleBox.y + Theme.launchTitleLine + Theme.launchStatusGap
                width: parent.width; height: Theme.failBodyHeight
                Repeater {
                    model: root.steps
                    Text {
                        id: line
                        required property int index
                        required property string modelData
                        readonly property bool current: index === root.step && !root.failed
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.launchStatusInk
                        elide: Text.ElideRight
                        font.family: Theme.fontUi; font.pixelSize: Theme.launchStatusSize; font.weight: Font.Medium
                        opacity: current ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.launchStatusFade } }
                        transform: Translate {
                            y: line.current || Theme.reducedMotion ? 0 : line.index < root.step ? -Theme.launchStatusShift : Theme.launchStatusShift
                            Behavior on y { NumberAnimation { duration: Theme.launchStatusMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain } }
                        }
                    }
                }
                FailAppear {
                    width: parent.width; height: parent.height
                    delay: Theme.failBodyDelay
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        text: root.error
                        color: Theme.failBodyInk
                        lineHeight: 1.5
                        font.family: Theme.fontUi; font.pixelSize: Theme.failBodySize
                    }
                }
            }
            // A Réessayer · Y Réveiller le PC · B Annuler
            FailAppear {
                anchors.horizontalCenter: parent.horizontalCenter
                y: statusBox.y + statusBox.height + Theme.failButtonsGap
                width: buttons.width; height: buttons.height
                delay: Theme.failButtonsDelay
                hiddenY: Theme.reducedMotion ? 0 : Theme.failButtonsShift
                moveDuration: Theme.failButtonsMove
            Row {
                id: buttons
                spacing: Theme.homeButtonsGap
                PillButton {
                    primary: true; glyph: "A"; label: qsTr("Réessayer")
                    labelSize: Theme.failPrimarySize
                    held: root.aDown
                    onClicked: { Sounds.play("select"); root.retryRequested() }
                }
                PillButton {
                    visible: root.canWake
                    glyph: "Y"; label: qsTr("Réveiller le PC")
                    onClicked: root.wakeRequested()
                }
                PillButton {
                    glyph: "B"; label: qsTr("Annuler")
                    onClicked: root.cancelRequested()
                }
            }
            }
        }
    }

    // Ce qui paraît à l'échec (MotionEchec), après son délai, en montant de 10 px ; s'efface
    // aussitôt quand on réessaie.
    component FailAppear: Appear {
        shown: root.failed
        hiddenY: Theme.reducedMotion ? 0 : Theme.failShift
        hideDuration: Theme.launchStatusFade
        fadeDuration: Theme.launchStatusFade
        moveDuration: Theme.failMove
        moveEasing: Easing.BezierSpline
        bezier: Theme.curveMain
    }
    component CenteredText: Text {
        property real size: 14
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: Theme.ink
        font.family: Theme.fontUi; font.pixelSize: size; font.weight: Font.DemiBold
        font.letterSpacing: -0.02 * size
    }
}
