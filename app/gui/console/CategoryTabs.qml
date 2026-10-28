import QtQuick

// Onglets de catégories de l'accueil CocoOS, au centre de la barre haute
// (AccueilCarrousel, MotionCategories) : [LB] Tout · Favoris · Récents · Apps [RB] dans
// une pastille de verre ; une pastille blanche glisse sous l'onglet actif. Présentation
// pure : HomeScreen donne les libellés et l'onglet actif, LB / RB arrivent par
// `pressed(direction)` (InputStatus ou Page préc. / suiv.), un clic par `requested`.
Row {
    id: root

    property var labels: []
    property int currentIndex: 0
    signal requested(int delta)              // clic sur un onglet : l'écart avec l'actif

    // LB (-1) ou RB (+1) vient d'être pressé : son glyphe s'allume, la pastille s'écrase.
    function pressed(direction) {
        (direction < 0 ? lb : rb).flash()
        squash.restart()
    }

    spacing: Theme.tabsGlyphGap

    component Glyph: Rectangle {
        id: glyph
        property string label
        property bool lit: false
        function flash() { lit = true; unlight.restart() }
        Timer { id: unlight; interval: Theme.tabsGlyphFlash; onTriggered: glyph.lit = false }
        anchors.verticalCenter: parent.verticalCenter
        width: glyphText.implicitWidth + 2 * Theme.tabsGlyphPad
        height: Theme.tabsGlyphHeight
        radius: height / 2
        color: lit ? Theme.ink : "transparent"
        border.color: Theme.tabsGlyphStroke
        Behavior on color { ColorAnimation { duration: Theme.tabsGlyphFade } }
        Text {
            id: glyphText
            anchors.centerIn: parent
            text: glyph.label
            color: glyph.lit ? Theme.inkOnLight : Theme.ink2
            Behavior on color { ColorAnimation { duration: Theme.tabsGlyphFade } }
            font.family: Theme.fontUi; font.pixelSize: Theme.tabsGlyphSize; font.weight: Font.DemiBold
        }
    }

    Glyph { id: lb; label: "LB" }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: tabs.width + 2 * Theme.tabsPad
        height: tabs.height + 2 * Theme.tabsPad
        radius: height / 2
        color: Theme.glassPill
        border.color: Theme.hostPillStroke

        // Pastille blanche sous l'onglet actif.
        Rectangle {
            readonly property Item target: repeater.count > root.currentIndex ? repeater.itemAt(root.currentIndex) : null
            x: Theme.tabsPad + (target ? target.x : 0)
            y: Theme.tabsPad
            width: target ? target.width : 0
            height: tabs.height
            radius: height / 2
            color: Theme.ink
            scale: 1
            transform: Scale { id: squashScale; origin.x: width / 2; xScale: 1 }
            Behavior on x {
                NumberAnimation { duration: Theme.tabsMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveTabs }
            }
            Behavior on width {
                NumberAnimation { duration: Theme.tabsMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveTabs }
            }
        }
        SequentialAnimation {
            id: squash
            PauseAnimation { duration: Theme.tabsSquashDelay }
            NumberAnimation { target: squashScale; property: "xScale"; to: Theme.tabsSquash; duration: Theme.tabsSquashMove }
            PauseAnimation { duration: Theme.tabsSquashHold }
            NumberAnimation { target: squashScale; property: "xScale"; to: 1; duration: Theme.tabsSquashMove }
        }

        Row {
            id: tabs
            x: Theme.tabsPad; y: Theme.tabsPad
            Repeater {
                id: repeater
                model: root.labels
                Item {
                    readonly property bool active: index === root.currentIndex
                    width: label.implicitWidth + 2 * Theme.tabsLabelPadH
                    height: label.implicitHeight + 2 * Theme.tabsLabelPadV
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.active ? Theme.inkOnLight : tabMouse.containsMouse ? Theme.ink : Theme.tabsInk
                        Behavior on color { ColorAnimation { duration: Theme.tabsInkFade } }
                        font.family: Theme.fontUi; font.pixelSize: Theme.tabsSize
                        font.weight: parent.active ? Font.DemiBold : Font.Medium
                    }
                    HoverArea {
                        id: tabMouse
                        anchors.fill: parent
                        onClicked: if (!parent.active) root.requested(index - root.currentIndex)
                    }
                }
            }
        }
    }

    Glyph { id: rb; label: "RB" }
}
