import QtQuick

// Écran de lancement d'un jeu : son illustration en plein écran, puis un voile
// et la progression (une ligne d'étape, une barre qui avance par étapes).
// Présentation pure : l'appelant fournit les étapes et dit où l'on en est.
//
// Remplit son parent et se dessine, comme HomeScreen, sur un canevas de 800 de
// haut mis à l'échelle. À poser AU-DESSUS de la pile d'écrans de Moonlight : il
// doit rester visible pendant que la page de connexion d'origine travaille dessous.
FocusScope {
    id: root

    property url image                  // illustration du jeu
    // Vignette d'où part l'écran : sa place sur le canevas et sa jaquette. Le cadre
    // grandit de là jusqu'au plein écran ; sans elle (origin vide), simple fondu.
    property rect origin: Qt.rect(0, 0, 0, 0)
    property url thumbnail
    readonly property bool fromThumb: origin.width > 0
    property real grow: 1               // 0 = à la place de la vignette, 1 = plein écran
    property var steps: []              // libellés des étapes, dans l'ordre
    property int step: 0                // étape en cours
    // Avancement dans l'étape en cours, de 0 à 1. À 1 (par défaut), la barre va
    // d'un trait au bout de l'étape ; sinon elle suit cette valeur.
    property real stepProgress: 1
    property string error: ""           // non vide : le lancement a échoué, voici pourquoi
    property bool cancellable: false    // B peut encore annuler
    property string hint: ""            // indication en bas d'écran, quand B n'a plus d'effet
    // Fige les animations. Moonlight bloque l'interface en préparant son décodeur :
    // mieux vaut une image immobile qu'une animation qui saute.
    property bool frozen: false

    signal opened()                     // l'écran couvre tout, la progression est en place
    signal cancelRequested()            // B : annulation, ou fermeture après une erreur

    property bool active: false
    property bool progressShown: false
    property real bar: 0                // remplissage de la barre, de 0 à 1
    readonly property real barTarget: steps.length > 0 ? Math.min(1, (step + stepProgress) / steps.length) : 0

    visible: active

    function open() {
        outro.stop()
        error = ""
        frozen = false
        progressShown = false
        bar = 0
        content.opacity = 1
        grow = fromThumb ? 0 : 1
        art.opacity = fromThumb ? 0 : 1
        frame.opacity = fromThumb ? 1 : 0
        shade.opacity = 0
        active = true
        forceActiveFocus()
        intro.restart()
    }
    // Disparition immédiate (le flux démarre) ou en fondu (retour à l'accueil).
    function close(animated) {
        if (!active) return
        intro.stop()
        barMove.stop()
        if (animated) {
            outro.restart()
        } else {
            active = false
        }
    }

    onBarTargetChanged: advanceBar()
    onProgressShownChanged: advanceBar()

    // La cible est posée ici, pas par une liaison : elle doit être à jour au
    // moment précis où l'animation repart.
    function advanceBar() {
        if (!progressShown) return
        barMove.to = barTarget
        barMove.restart()
    }

    // Tout est avalé : l'accueil, dessous, ne doit pas réagir.
    Keys.onPressed: function(event) {
        event.accepted = true
        if (event.key === Qt.Key_Escape && !event.isAutoRepeat && (cancellable || error !== ""))
            cancelRequested()
    }

    ParallelAnimation {
        id: intro
        paused: running && root.frozen
        // Depuis la vignette : le cadre grandit, l'illustration remplace la jaquette.
        SequentialAnimation {
            PauseAnimation { duration: root.fromThumb ? 0 : Theme.launchImageDelay }
            ParallelAnimation {
                NumberAnimation {
                    target: frame; property: "opacity"; to: 1
                    duration: root.fromThumb ? 0 : Theme.launchImageFade
                }
                NumberAnimation {
                    target: root; property: "grow"; to: 1
                    duration: root.fromThumb ? Theme.launchGrow : 0; easing.type: Theme.easeQuint
                }
                NumberAnimation {
                    target: art; property: "opacity"; to: 1
                    duration: root.fromThumb ? Theme.launchGrow : 0
                }
                NumberAnimation {
                    target: art; property: "scale"; from: root.fromThumb ? 1 : Theme.launchImageZoom; to: 1
                    duration: Theme.launchImageSettle; easing.type: Theme.easeQuint
                }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.launchShadeDelay }
            NumberAnimation { target: shade; property: "opacity"; from: 0; to: Theme.launchShade; duration: Theme.launchShadeFade }
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.launchProgressDelay }
            ScriptAction { script: { root.progressShown = true; Sounds.play("launch") } }
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.launchOpened }
            ScriptAction { script: root.opened() }
        }
    }
    NumberAnimation {
        id: barMove
        target: root; property: "bar"
        duration: Theme.launchStep; easing.type: Easing.InOutCubic
        paused: running && root.frozen
    }
    SequentialAnimation {
        id: outro
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: Theme.launchClose }
        ScriptAction { script: root.active = false }
    }

    component StageLine: Text {
        property string value
        width: Theme.launchProgressWidth; height: Theme.launchStageHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: value
        color: root.error !== "" ? Theme.accent : Theme.ink
        elide: Text.ElideRight
        font.family: Theme.fontUi; font.pixelSize: Theme.launchStageSize
    }

    Item {
        id: content
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        // L'illustration, sur fond noir, qui recouvre l'accueil : en fondu, ou en
        // grandissant depuis la vignette du jeu.
        Rectangle {
            id: frame
            x: root.origin.x * (1 - root.grow)
            y: root.origin.y * (1 - root.grow)
            width: root.origin.width + (parent.width - root.origin.width) * root.grow
            height: root.origin.height + (parent.height - root.origin.height) * root.grow
            color: Theme.background
            opacity: 0
            clip: true

            Image {
                anchors.fill: parent
                visible: root.fromThumb && root.grow < 1
                source: root.thumbnail
                fillMode: Image.PreserveAspectCrop
                asynchronous: false         // déjà en cache : la vignette est à l'écran
                sourceSize.height: Math.round(Theme.shelfThumbSize.height * Theme.shelfActiveScale * Theme.scale)
            }
            Image {
                id: art
                anchors.fill: parent
                transformOrigin: Item.TopLeft
                source: root.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.height: Math.round(parent.height * Theme.scale)
            }
            Rectangle { id: shade; anchors.fill: parent; color: Theme.background; opacity: 0 }
        }

        // La progression
        Item {
            x: (parent.width - width) / 2
            y: Theme.launchProgressY
            width: Theme.launchProgressWidth
            opacity: root.progressShown ? 1 : 0
            transform: Translate { y: root.progressShown ? 0 : Theme.launchProgressShift
                Behavior on y { NumberAnimation { duration: Theme.launchProgressMove; easing.type: Theme.easeQuint } }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.launchProgressFade } }

            SwapBox {
                id: stage
                width: parent.width; height: Theme.launchStageHeight
                duration: Theme.launchStageSwap
                animated: root.progressShown
                key: root.error !== "" ? qsTr("Le lancement a échoué") : (root.steps[root.step] || "")
                value: key

                StageLine {}
                StageLine {}
            }
            Rectangle {
                y: stage.height + Theme.launchTrackTop
                width: parent.width; height: Theme.launchTrackHeight
                radius: height / 2
                visible: root.error === ""
                color: Theme.launchTrackColor
                Rectangle {
                    width: parent.width * root.bar; height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }
            Text {
                y: stage.height + Theme.launchMessageTop
                width: parent.width
                visible: root.error !== ""
                text: root.error
                color: Theme.ink2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: Theme.fontUi; font.pixelSize: Theme.launchMessageSize
            }
        }

        // « B Annuler » tant que c'est possible, « B Fermer » après une erreur, sinon
        // l'indication fournie (comment quitter le jeu, par exemple).
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.hintBottom
            width: hint.width + 2 * Theme.hintPadH
            height: hint.height + 2 * Theme.hintPadV
            radius: height / 2
            color: Theme.hintFill
            opacity: root.progressShown && hintLabel.text !== "" ? Theme.hintOpacity : 0
            Behavior on opacity { NumberAnimation { duration: Theme.launchProgressFade } }

            Row {
                id: hint
                anchors.centerIn: parent
                spacing: Theme.hintGap
                ButtonGlyph { label: "B"; visible: root.cancellable || root.error !== "" }
                Text {
                    id: hintLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.error !== "" ? qsTr("Fermer") : root.cancellable ? qsTr("Annuler") : root.hint
                    color: Theme.ink
                    font.family: Theme.fontUi; font.pixelSize: Theme.hintSize
                }
            }
        }
    }
}
