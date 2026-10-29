import QtQuick
import QtQuick.Effects
import ".."

// Code PIN de la première configuration (MotionAppairage). Deux sens :
// - `mode: "moonlight"` : le code à 4 chiffres à saisir dans Apollo, sur le PC (`code`) ; les
//   cases entrent, puis les chiffres un à un ; « En attente de … » ;
// - `mode: "companion"` : le code à 6 chiffres que le HostCompanion affiche sur le PC, à saisir
//   ici (↑ ↓ le chiffre, ← → la case, A valide ; mêmes cases, hors maquette).
// `done` : les cases se rejoignent au centre, la coche apparaît et se trace, « … est associé »,
// puis A Continuer (`continued`). Sur le canevas ; aucune dépendance Moonlight.
FocusScope {
    id: root

    property string mode: "moonlight"
    property string hostName: ""
    property string code: ""             // moonlight : les chiffres à recopier
    property bool done: false
    property bool busy: false            // companion : vérification en cours
    property string errorText: ""
    property bool pressing: false

    signal submitted(string code)
    signal continued()
    signal backRequested()                // B de la légende, à la souris

    // (à chaque entrée dans l'étape)
    function reset() {
        digits = mode === "companion" ? [0, 0, 0, 0, 0, 0] : []
        active = 0
        done = false
        busy = false
        errorText = ""
        pressing = false
        boxesIn.restart()
    }

    property var digits: []
    property int active: 0
    readonly property var shownDigits: mode === "companion" ? digits : code.split("")
    readonly property int count: mode === "companion" ? 6 : Math.max(4, code.length)
    readonly property bool editing: mode === "companion" && !done && !busy

    function setDigit(i, v) {
        var d = digits.slice()
        d[i] = ((v % 10) + 10) % 10
        digits = d
        Sounds.play("tick")
    }
    function moveTo(i) {
        if (i < 0 || i >= count) { Sounds.play("edge"); return }
        active = i
        Sounds.play("move")
    }
    function refuse() { shake.restart(); Sounds.play("deny") }
    onErrorTextChanged: if (errorText !== "") refuse()

    Keys.onPressed: function(event) {
        if (event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            pressing = true
            event.accepted = true
            return
        }
        if (!editing) return
        event.accepted = true
        if (event.key === Qt.Key_Left) moveTo(active - 1)
        else if (event.key === Qt.Key_Right) moveTo(active + 1)
        else if (event.key === Qt.Key_Up) setDigit(active, digits[active] + 1)
        else if (event.key === Qt.Key_Down) setDigit(active, digits[active] - 1)
        else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            setDigit(active, event.key - Qt.Key_0)
            if (active < count - 1) active++
        } else if (event.key === Qt.Key_Backspace) active = Math.max(0, active - 1)
        else event.accepted = false
    }
    Keys.onReleased: function(event) {
        if (event.isAutoRepeat || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) || !pressing) return
        pressing = false
        event.accepted = true
        if (done) {
            Sounds.play("select")
            continued()
        } else if (editing) {
            busy = true
            errorText = ""
            Sounds.play("select")
            submitted(digits.join(""))
        }
    }

    readonly property real cx: width / 2
    // Le code Moonlight arrive après l'entrée dans l'étape : les chiffres entrent alors.
    onCodeChanged: if (mode === "moonlight" && code !== "" && !done) boxesIn.restart()

    // En-tête et titre : « Associez votre PC », puis « … est associé ».
    Text {
        width: parent.width
        y: Theme.pairStepTop
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("PREMIÈRE CONFIGURATION · %1 SUR %2").arg(2).arg(3)
        color: Theme.ink3
        font.family: Theme.fontUi; font.pixelSize: Theme.setupStepSize; font.weight: Font.DemiBold
        font.letterSpacing: 0.08 * Theme.setupStepSize
    }
    component Swap: Column {
        id: swap
        property bool on: false
        property string title
        property string text
        property real shift: Theme.pairSwapShift
        property real blurPx: Theme.pairSwapBlur
        width: root.width
        y: Theme.pairTitleTop
        spacing: Theme.pairTextGap
        opacity: 0
        transform: Translate { y: swap.shift * Theme.move }
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && opacity > 0 && opacity < 1
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: swap.blurPx / 16 }
        states: State { name: "on"; when: swap.on; PropertyChanges { swap.opacity: 1; swap.shift: 0; swap.blurPx: 0 } }
        transitions: Transition {
            SequentialAnimation {
                PauseAnimation { duration: Theme.pairSwapDelay }
                ParallelAnimation {
                    NumberAnimation { properties: "opacity,blurPx"; duration: Theme.pairSwapFade }
                    NumberAnimation { property: "shift"; duration: Theme.pairSwapMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
                }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: swap.title
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.pairTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: -0.03 * Theme.pairTitleSize
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: swap.text
            color: Theme.ink2
            font.family: Theme.fontUi; font.pixelSize: Theme.setupTextSize; font.weight: Font.Medium
        }
    }
    Swap {
        on: !root.done
        // (sorti vers le haut, entré par le bas)
        title: qsTr("Associez votre PC")
        text: root.mode === "companion" ? qsTr("Saisissez le code à 6 chiffres affiché sur %1 :").arg(root.hostName)
                                        : qsTr("Dans Apollo, sur %1, saisissez ce code :").arg(root.hostName)
        Component.onCompleted: shift = Theme.pairSwapShift
        onOnChanged: if (!on) shift = -Theme.pairSwapShift
    }
    Swap {
        on: root.done
        title: qsTr("%1 est associé").arg(root.hostName)
        text: qsTr("Tout est prêt. Votre bibliothèque arrive.")
    }

    // Les cases.
    Item {
        id: boxes
        readonly property real span: root.count * (Theme.pairBox + Theme.pairBoxGap) - Theme.pairBoxGap
        x: (root.width - span) / 2
        y: Theme.pairBoxesTop
        width: span; height: Theme.pairBoxHeight
        property real entry: 0
        NumberAnimation on entry { id: boxesIn; from: 0; to: 1; duration: Theme.pairBoxIn + 6 * Theme.pairBoxStagger + Theme.pairDigitDelay + 6 * Theme.pairDigitStagger + Theme.pairDigitMove; running: false }
        // Refus : les cases se secouent.
        property real shakeX: 0
        transform: Translate { x: boxes.shakeX }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: boxes; property: "shakeX"; to: -9; duration: 60 }
            NumberAnimation { target: boxes; property: "shakeX"; to: 8; duration: 80 }
            NumberAnimation { target: boxes; property: "shakeX"; to: -5; duration: 80 }
            NumberAnimation { target: boxes; property: "shakeX"; to: 3; duration: 80 }
            NumberAnimation { target: boxes; property: "shakeX"; to: 0; duration: 140 }
        }

        Repeater {
            model: root.count
            Item {
                id: box
                required property int index
                readonly property real home: index * (Theme.pairBox + Theme.pairBoxGap)
                readonly property real toCenter: boxes.span / 2 - (home + Theme.pairBox / 2)
                readonly property real fromCenter: Math.abs((root.count - 1) / 2 - index)
                // Entrée (en ms depuis le début), puis rassemblement au centre (`done`).
                readonly property real t: boxes.entry * boxesIn.duration
                readonly property real inP: Math.max(0, Math.min(1, (t - index * Theme.pairBoxStagger) / Theme.pairBoxIn))
                readonly property real digitAt: Theme.pairDigitDelay + index * Theme.pairDigitStagger
                readonly property real digitP: Math.max(0, Math.min(1, (t - digitAt) / Theme.pairDigitMove))
                property real gather: 0
                x: home + toCenter * gather * Theme.move
                width: Theme.pairBox; height: Theme.pairBoxHeight
                opacity: Math.min(1, inP * boxesIn.duration / Theme.pairBoxFade) * (1 - gatherFade)
                property real gatherFade: 0
                scale: 1 - (1 - (Theme.pairBoxFrom + (1 - Theme.pairBoxFrom) * ease(inP)) * (1 - (1 - Theme.pairGatherScale) * gather)) * Theme.move
                function ease(p) { return 1 - Math.pow(1 - p, 3) }
                states: State { name: "gathered"; when: root.done; PropertyChanges { box.gather: 1; box.gatherFade: 1 } }
                transitions: Transition {
                    to: "gathered"
                    SequentialAnimation {
                        PauseAnimation { duration: box.fromCenter * Theme.pairGatherStagger }
                        ParallelAnimation {
                            NumberAnimation { property: "gather"; duration: Theme.pairGather; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
                            SequentialAnimation {
                                PauseAnimation { duration: 120 }
                                NumberAnimation { property: "gatherFade"; duration: Theme.pairGatherFade }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.pairBoxRadius
                    color: Theme.pairBoxFill
                    border.width: root.editing && root.active === box.index ? 2 : 1
                    border.color: root.editing && root.active === box.index ? Theme.accent : Theme.pairBoxStroke
                    HoverArea {
                        anchors.fill: parent
                        enabled: root.editing
                        onClicked: if (root.active !== box.index) root.moveTo(box.index)
                        onWheel: function(wheel) {
                            root.active = box.index
                            root.setDigit(box.index, root.digits[box.index] + (wheel.angleDelta.y > 0 ? 1 : -1))
                        }
                    }
                }
                Text {
                    id: digit
                    anchors.centerIn: parent
                    // (moonlight : chaque chiffre arrive à son tour ; companion : tous là)
                    readonly property real p: root.mode === "companion" ? 1 : box.digitP
                    text: root.shownDigits[box.index] !== undefined ? root.shownDigits[box.index] : ""
                    color: Theme.ink
                    opacity: Math.min(1, p * Theme.pairDigitMove / Theme.pairDigitFade)
                    transform: Translate { y: (1 - digit.eased) * Theme.pairDigitShift * Theme.move }
                    readonly property real eased: 1 - Math.pow(1 - p, 3)
                    font.family: Theme.fontUi; font.pixelSize: Theme.pairDigitSize; font.weight: Font.DemiBold
                    font.letterSpacing: -0.03 * Theme.pairDigitSize
                    font.features: { "tnum": 1 }
                    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && p > 0 && p < 1
                    layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: (1 - digit.opacity) * Theme.pairDigitBlur / 16 }
                }
            }
        }
    }

    // La coche, sur un rond orange.
    Rectangle {
        id: check
        x: root.cx - width / 2
        y: Theme.pairCheckTop
        width: Theme.pairCheck; height: width; radius: width / 2
        color: Theme.accent
        opacity: 0
        scale: 1 - (1 - Theme.pairCheckFrom) * Theme.move
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && opacity > 0
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.pairCheckGlow / 100)
            shadowVerticalOffset: 20; shadowBlur: 1
        }
        CheckMark {
            anchors.centerIn: parent
            width: 44 * 24 / 22; height: width
            color: "#FFFFFF"
            checked: root.done
            drawDelay: Theme.pairCheckDrawDelay
            drawDuration: Theme.pairCheckDraw
        }
        states: State { name: "on"; when: root.done; PropertyChanges { check.opacity: 1; check.scale: 1 } }
        transitions: Transition {
            to: "on"
            SequentialAnimation {
                PauseAnimation { duration: Theme.pairCheckDelay }
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; duration: Theme.pairCheckFade }
                    NumberAnimation { property: "scale"; duration: Theme.pairCheckPop; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curvePairCheck }
                }
            }
        }
    }

    // « En attente de … » (moonlight), « Vérification… » ou l'erreur (companion).
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.pairWaitTop
        spacing: 10
        opacity: root.done ? 0 : (root.mode === "moonlight" ? (boxes.entry * boxesIn.duration > Theme.pairWaitDelay ? 1 : 0)
                                                            : (root.busy || root.errorText !== "" ? 1 : 0))
        Behavior on opacity { NumberAnimation { duration: 300 } }
        LoaderRing {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.errorText === ""
            width: Theme.pairWaitSpinner
            stroke: 2.5
            track: Theme.accentTrack
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.errorText !== "" ? root.errorText
                : root.mode === "companion" ? qsTr("Vérification…")
                : qsTr("En attente de %1…").arg(root.hostName)
            color: root.errorText !== "" ? Theme.poor : Theme.ink2
            font.family: Theme.fontUi; font.pixelSize: Theme.pairWaitSize; font.weight: Font.Medium
        }
    }

    // Saisie du code Companion (hors maquette) : la légende de CompanionPairing.
    ControllerLegend {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.canvasHeight - Theme.legendBottomCoco - height
        visible: root.mode === "companion" && !root.done
        spacing: Theme.offlineLegendGap
        textSize: Theme.legendSizeCoco
        glyphGap: Theme.legendGlyphGapCoco
        pressing: root.pressing
        hints: [ { glyph: "↕", label: qsTr("Chiffre") }, { glyph: "↔", label: qsTr("Case") },
                 { glyph: "A", label: qsTr("Valider") }, { glyph: "B", label: qsTr("Retour") } ]
        onTriggered: function(glyph) {
            if (glyph === "A" && root.editing) { root.busy = true; root.errorText = ""; root.submitted(root.digits.join("")) }
            else if (glyph === "B") root.backRequested()
        }
    }

    // A Continuer, une fois associé.
    PillButton {
        id: cta
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.pairCtaTop + shift * Theme.move
        property real shift: Theme.pairCtaShift
        primary: true
        glyph: "A"
        label: qsTr("Continuer")
        held: root.pressing && root.done
        opacity: 0
        enabled: root.done
        onClicked: if (root.done) { Sounds.play("select"); root.continued() }
        states: State { name: "on"; when: root.done; PropertyChanges { cta.opacity: 1; cta.shift: 0 } }
        transitions: Transition {
            to: "on"
            SequentialAnimation {
                PauseAnimation { duration: Theme.pairCtaDelay }
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; duration: Theme.pairCtaFade }
                    NumberAnimation { property: "shift"; duration: Theme.pairCtaMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain }
                }
            }
        }
    }
}
