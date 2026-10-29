import QtQuick
import QtQuick.Effects
import ".."

// Bonjour (SetupBonjour) : « Bonjour » puis ses traductions, un mot toutes les 1,7 s, qui
// entre flou, petit et un peu bas, et sort flou vers le haut ; dessous, le A qui respire et
// « Appuyez pour commencer » ; en bas « CocoOS » et l'état de la manette. Le décor (lueurs)
// est celui de SetupFlow. Sur le canevas ; aucune dépendance Moonlight.
Item {
    id: root

    property bool running: false
    property bool padReady: false
    property bool pressing: false        // A enfoncé : le rond s'écrase

    readonly property var words: [ { text: "Bonjour", lang: "fr" }, { text: "Hello", lang: "en" },
                                   { text: "Hola", lang: "es" }, { text: "Hallo", lang: "de" },
                                   { text: "Ciao", lang: "it" }, { text: "こんにちは", lang: "ja" },
                                   { text: "Olá", lang: "pt" } ]
    // Le mot affiché (-1 : entre deux mots) et celui qui vient de sortir.
    property int shown: 0
    property int last: -1

    onRunningChanged: {
        shown = 0
        last = -1
        if (running) {
            leave.interval = Theme.helloStart + Theme.helloStep - Theme.helloLeave
            leave.restart()
        } else {
            leave.stop()
            next.stop()
        }
    }
    // Le mot sort 450 ms avant la fin de son tour ; le suivant entre au tour d'après.
    Timer {
        id: leave
        onTriggered: {
            root.last = root.shown
            root.shown = -1
            next.restart()
        }
    }
    Timer {
        id: next
        interval: Theme.helloLeave
        onTriggered: {
            root.shown = (root.last + 1) % root.words.length
            leave.interval = Theme.helloStep - Theme.helloLeave
            leave.restart()
        }
    }

    Item {
        x: 0; y: Theme.helloTop
        width: parent.width; height: Theme.helloLine
        Repeater {
            model: root.words
            Text {
                id: word
                required property int index
                required property var modelData
                property real blurPx: Theme.helloBlur
                property real shift: Theme.helloBelow
                property real track: Theme.helloTrackOff
                width: parent.width; height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.text
                color: Theme.ink
                opacity: 0
                property real zoom: Theme.helloScaleIn
                // (Réduire les animations : ni glissement ni échelle, le fondu seul)
                transform: [
                    Scale { origin.x: word.width / 2; origin.y: word.height / 2
                            xScale: 1 + (word.zoom - 1) * Theme.move; yScale: xScale },
                    Translate { y: word.shift * Theme.move }
                ]
                font.family: modelData.lang === "ja" ? Theme.fontHelloJp : Theme.fontUi
                font.pixelSize: Theme.helloSize; font.weight: Font.DemiBold
                font.letterSpacing: track * Theme.helloSize
                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && opacity > 0 && blurPx > 0.05
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: word.blurPx / 16 }

                state: root.shown === index ? "on" : root.last === index ? "after" : "before"
                states: [
                    State { name: "on"; PropertyChanges { word.opacity: 1; word.blurPx: 0; word.shift: 0; word.zoom: 1; word.track: Theme.helloTrackOn } },
                    State { name: "after"; PropertyChanges { word.opacity: 0; word.blurPx: Theme.helloBlur; word.shift: Theme.helloAbove; word.zoom: Theme.helloScaleOut; word.track: Theme.helloTrackOff } },
                    State { name: "before"; PropertyChanges { word.opacity: 0; word.blurPx: Theme.helloBlur; word.shift: Theme.helloBelow; word.zoom: Theme.helloScaleIn; word.track: Theme.helloTrackOff } }
                ]
                transitions: [
                    Transition {
                        to: "on"
                        NumberAnimation { property: "opacity"; duration: Theme.reducedMotion ? Theme.reducedSpring.duration : Theme.helloInFade; easing.type: Easing.InOutQuad }
                        NumberAnimation { property: "blurPx"; duration: Theme.reducedMotion ? 0 : Theme.helloInBlur; easing.type: Easing.InOutQuad }
                        NumberAnimation {
                            properties: "shift,zoom,track"; duration: Theme.helloInMove
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                        }
                    },
                    Transition {
                        to: "after"
                        NumberAnimation { properties: "opacity,blurPx"; duration: Theme.helloOutFade; easing.type: Easing.InQuad }
                        NumberAnimation {
                            properties: "shift,zoom,track"; duration: Theme.helloOutMove
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveExit
                        }
                    }
                    // (vers « before » : invisible, sans animation)
                ]
            }
        }
    }

    // Le A qui respire, et l'invitation.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.canvasHeight - Theme.helloCtaBottom - height
        spacing: Theme.helloCtaGap
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.helloDisc; height: width
            Rectangle {
                id: disc
                anchors.centerIn: parent
                width: parent.width; height: width; radius: width / 2
                color: Theme.ink
                property real breath: 0
                scale: (1 + (Theme.helloBreathScale - 1) * breath) * (root.pressing ? Theme.powerPress : 1)
                Behavior on scale { enabled: root.pressing; NumberAnimation { duration: Theme.pressDuration } }
                SequentialAnimation on breath {
                    running: root.running && !Theme.reducedMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: Theme.helloBreath / 2; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: Theme.helloBreath / 2; easing.type: Easing.InOutSine }
                }
                // Le halo de la respiration.
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 2 * Theme.helloBreathRing * disc.breath; height: width
                    radius: width / 2
                    color: Theme.helloBreathInk
                    opacity: disc.breath
                    z: -1
                }
                ButtonGlyph {
                    anchors.centerIn: parent
                    label: "A"
                    size: parent.width
                    color: "transparent"
                    border.width: 0
                    ink: Theme.inkOnLight
                    fontSize: Theme.helloDiscFont
                    weight: Font.Bold
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Appuyez pour commencer")
            color: Theme.ink2
            font.family: Theme.fontUi; font.pixelSize: Theme.helloCtaSize; font.weight: Font.Medium
        }
    }

    // En bas : CocoOS à gauche, la manette à droite.
    Text {
        x: Theme.helloCornerSide
        y: Theme.canvasHeight - Theme.helloCornerBottom - height
        textFormat: Text.StyledText
        text: "Coco<font color=\"" + Theme.accent + "\">OS</font>"
        color: Theme.helloCornerInk
        font.family: Theme.fontUi; font.pixelSize: Theme.helloLogoSize; font.weight: Font.DemiBold
        font.letterSpacing: -0.01 * Theme.helloLogoSize
    }
    Row {
        visible: root.padReady
        x: parent.width - Theme.helloCornerSide - width
        y: Theme.canvasHeight - Theme.helloCornerBottom - height
        spacing: 10
        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: "../icons/gamepad.svg"
            width: 20; height: 14
            sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
            opacity: 0.5
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Manette intégrée prête")
            color: Theme.helloCornerInk
            font.family: Theme.fontUi; font.pixelSize: Theme.helloPadSize; font.weight: Font.Medium
        }
    }
}
