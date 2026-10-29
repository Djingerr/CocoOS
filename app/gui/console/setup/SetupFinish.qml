import QtQuick
import QtQuick.Effects
import ".."

// Fin de la première configuration (MotionSetupFin), après « Commencer » : la configuration
// s'efface (`leaving`, à SetupFlow de la flouter), l'anneau orange apparaît et se trace, « Tout
// est prêt. Bienvenue dans CocoOS. », la lueur s'avive ; puis texte et anneau s'en vont,
// `homeReturn` (l'accueil revient en éventail) et `finished`. Sur le canevas ; aucune
// dépendance Moonlight.
Item {
    id: root

    property bool running: false
    property bool leaving: false
    signal homeReturn()
    signal finished()

    function start() {
        running = true
        leaving = false
        ring.opacity = 0; ring.scale = 1 - (1 - Theme.finRingFrom) * Theme.move; ring.fill = 0
        glow.opacity = 0
        message.opacity = 0; message.shift = Theme.finTextIn; message.blurPx = Theme.finTextBlur
        sequence.restart()
    }

    visible: running

    Glow {
        id: glow
        x: (parent.width - width) / 2
        y: Theme.finGlowTop
        width: Theme.finGlow; height: width
        color: Theme.accent
        scale: ring.scale
        opacity: 0
    }
    LoaderRing {
        id: ring
        x: (parent.width - width) / 2
        y: Theme.finRingTop
        width: Theme.finRingSize
        stroke: Theme.finRingStroke
        track: Theme.accentTrack
        spinning: false
        opacity: 0
    }
    Column {
        id: message
        property real shift: Theme.finTextIn
        property real blurPx: Theme.finTextBlur
        width: parent.width
        y: Theme.finTextTop
        spacing: Theme.finTextGap
        opacity: 0
        transform: Translate { y: message.shift * Theme.move }
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && opacity > 0 && opacity < 1
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: message.blurPx / 16 }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Tout est prêt.")
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.finTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: -0.035 * Theme.finTitleSize
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Bienvenue dans CocoOS.")
            color: Theme.ink2
            font.family: Theme.fontUi; font.pixelSize: Theme.finSubSize; font.weight: Font.Medium
        }
    }

    component Curve: NumberAnimation { easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }

    SequentialAnimation {
        id: sequence
        PauseAnimation { duration: Theme.finLeave }
        ScriptAction { script: root.leaving = true }
        PauseAnimation { duration: Theme.finRingDelay - Theme.finLeave }
        // L'anneau : il apparaît au ressort, se trace ; le texte monte ; la lueur s'avive.
        ScriptAction { script: Sounds.play("library_ready") }
        ParallelAnimation {
            NumberAnimation { target: ring; property: "opacity"; to: 1; duration: Theme.finRingFade }
            NumberAnimation { target: ring; property: "scale"; to: 1; duration: Theme.finRingPop; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curvePairCheck }
            NumberAnimation { target: glow; property: "opacity"; to: Theme.finGlowRest; duration: Theme.finGlowFade }
            SequentialAnimation {
                PauseAnimation { duration: Theme.finRingDrawDelay }
                NumberAnimation { target: ring; property: "fill"; to: 1; duration: Theme.finRingDraw; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFinDraw }
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.finTextDelay }
                ParallelAnimation {
                    NumberAnimation { target: message; property: "opacity"; to: 1; duration: Theme.finTextFade }
                    NumberAnimation { target: message; property: "blurPx"; to: 0; duration: Theme.finTextFade }
                    Curve { target: message; property: "shift"; to: 0; duration: Theme.finTextMove }
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.finGlowPeakAt }
                NumberAnimation { target: glow; property: "opacity"; to: Theme.finGlowPeak; duration: Theme.finGlowFade }
            }
            PauseAnimation { duration: Theme.finTextOutAt }
        }
        // Le texte part vers le haut, l'anneau se resserre ; l'accueil revient.
        ParallelAnimation {
            NumberAnimation { target: message; property: "opacity"; to: 0; duration: Theme.finTextFade }
            NumberAnimation { target: message; property: "blurPx"; to: Theme.finTextBlur; duration: Theme.finTextFade }
            Curve { target: message; property: "shift"; to: Theme.finTextOut; duration: Theme.finTextMove }
            SequentialAnimation {
                PauseAnimation { duration: Theme.finRingOutAt - Theme.finTextOutAt }
                ParallelAnimation {
                    NumberAnimation { target: ring; property: "opacity"; to: 0; duration: Theme.finOut }
                    NumberAnimation { target: glow; property: "opacity"; to: 0; duration: Theme.finOut }
                    NumberAnimation { target: ring; property: "scale"; to: 1 - (1 - Theme.finRingTo) * Theme.move; duration: Theme.finOut * 640 / 360; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExit }
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.finRingOutAt - Theme.finTextOutAt + Theme.finHomeDelay }
                ScriptAction { script: root.homeReturn() }
            }
        }
        ScriptAction { script: { root.running = false; root.finished() } }
    }
}
