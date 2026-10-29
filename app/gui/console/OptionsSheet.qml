import QtQuick
import QtQuick.Effects

// Feuille « Options » (bouton Y ; OptionsFeuille, MotionOptions) : une carte de verre collée à
// droite, pendant que l'accueil recule derrière (HomeScreen, d'après `reveal`). En tête le
// titre et l'état du PC, puis les onglets en contrôle segmenté (LB / RB), la liste groupée
// de l'onglet (SettingsList) et la légende. B ou Y referment. Aucune dépendance Moonlight.
//
// La feuille ne garde aucun réglage : elle affiche `tabs` ([{ label, rows }], lignes de
// SettingsList) et signale les choix (`changed`, `actionRequested`, `holdCompleted`), à
// l'appelant d'appliquer la valeur et de mettre `tabs` à jour.
FocusScope {
    id: root

    property string title: qsTr("Options")
    property var tabs: []
    property int tab: 0
    readonly property var rows: tabs.length > 0 ? tabs[Math.min(tab, tabs.length - 1)].rows : []
    // Sous le titre, un point (accent si `connected`) et ce texte (« PC-Salon · connecté · 4 ms »).
    property string subtitle
    property bool connected: false

    signal changed(string key, int index)
    signal actionRequested(string key)
    signal holdCompleted(string key)
    signal closed()

    property bool opened: false
    // Ce qui est derrière la feuille (l'accueil) : flouté sous son verre, en petit (Theme.optBlur*).
    property Item backdrop: null
    readonly property bool blurs: backdrop !== null && GraphicsInfo.api !== GraphicsInfo.Unknown
                                  && GraphicsInfo.api !== GraphicsInfo.Software
    // La liste de l'onglet affiché : sa ligne en focus, son appui, ses butées.
    readonly property SettingsList list: panes.count > tab ? panes.itemAt(tab) : null
    readonly property int current: list ? list.current : 0
    readonly property bool pressing: list ? list.pressing : false
    readonly property real bump: list ? list.bump : 1
    readonly property int bumpDir: list ? list.bumpDir : 0
    readonly property alias tabPill: tabPill

    // 0 = fermée, 1 = ouverte : la carte glisse au ressort (Theme.optOpen), repart plus vite
    // (optClose) ; l'accueil recule d'après elle.
    property real reveal: opened ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.opened ? Theme.optOpen.duration : Theme.optClose.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.opened ? Theme.optOpen.curve : Theme.optClose.curve
        }
    }
    visible: reveal > 0 || panel.opacity > Theme.optClosedOpacity

    // Ouvre la feuille sur l'onglet `startTab` (le premier par défaut).
    function open(startTab) {
        tab = Math.min(startTab || 0, Math.max(0, tabs.length - 1))
        for (var i = 0; i < panes.count; i++) panes.itemAt(i).reset()
        opened = true
        forceActiveFocus()
        Sounds.play("open")
    }
    function close() {
        if (!opened) return
        if (list) list.stopAll()
        opened = false
        Sounds.play("close")
        closed()
    }
    // LB / RB : onglet voisin, sa première ligne en focus ; le glyphe pressé s'allume.
    property int flashed: 0              // -1 : LB, +1 : RB
    Timer { id: flash; interval: Theme.optGlyphFlash; onTriggered: root.flashed = 0 }
    function switchTab(dir) {
        var next = tab + dir
        if (next < 0 || next >= tabs.length) {
            Sounds.play("edge")
            return
        }
        if (list) list.stopAll()
        flashed = dir
        flash.restart()
        panes.itemAt(next).reset()
        tab = next
        Sounds.play("segment")
    }

    Keys.onPressed: function(event) {
        event.accepted = true    // feuille ouverte : rien ne traverse vers l'accueil
        if (event.isAutoRepeat) return
        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Hangup:
        case Qt.Key_Menu:
            close()
            break
        case Qt.Key_PageUp:          // LB / RB au clavier
        case Qt.Key_PageDown:
            switchTab(event.key === Qt.Key_PageUp ? -1 : 1)
            break
        }
    }

    // Un clic à côté de la feuille la referme.
    MouseArea { anchors.fill: parent; enabled: root.opened; onClicked: root.close() }

    Rectangle {
        id: panel
        x: root.width - Theme.optMargin - width + Theme.optSlide * (1 - root.reveal)
        y: Theme.optMargin
        width: Theme.optWidth; height: root.height - 2 * Theme.optMargin
        radius: Theme.radiusSheet
        color: "transparent"
        opacity: root.opened ? 1 : Theme.optClosedOpacity
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.opened ? 0 : Theme.optFadeOutDelay }
                NumberAnimation { duration: root.opened ? Theme.optFadeIn : Theme.optFadeOut }
            }
        }
        MouseArea { anchors.fill: parent }   // un clic dans la feuille ne la referme pas

        // Le verre : l'accueil flouté (une petite copie, refaite à chaque image), aux coins de
        // la feuille, sous la teinte.
        Rectangle {
            id: roundMask
            anchors.fill: parent
            radius: panel.radius
            visible: false
            layer.enabled: root.blurs
        }
        Item {
            anchors.fill: parent
            visible: root.blurs
            layer.enabled: visible
            layer.effect: MultiEffect {
                blurEnabled: true; blur: 1; blurMax: Theme.optBlurMax
                saturation: Theme.optBlurSaturation
                maskEnabled: true; maskSource: roundMask
            }
            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: root.blurs && root.visible ? root.backdrop : null
                // (mapFromItem n'est pas suivi : la place de la feuille et le recul de l'accueil, lus ici)
                sourceRect: !root.backdrop ? Qt.rect(0, 0, 0, 0)
                    : [panel.x, panel.y, root.backdrop.recede].length && root.backdrop.mapFromItem(panel, 0, 0, panel.width, panel.height)
                textureSize: Qt.size(Math.ceil(panel.width * Theme.optBlurScale), Math.ceil(panel.height * Theme.optBlurScale))
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: panel.radius
            color: Theme.glassSheet
            border.width: 1; border.color: Theme.hairline
        }

        Text {
            id: title
            x: Theme.optPad; y: Theme.optPad
            height: Math.round(Theme.optTitleSize * 1.2)
            verticalAlignment: Text.AlignVCenter
            text: root.title
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.optTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: -0.03 * Theme.optTitleSize
        }
        Row {
            id: host
            x: Theme.optPad
            y: title.y + title.height + Theme.optHostTop
            height: hostLabel.height
            spacing: Theme.sheetHostGap
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.subtitle !== ""
                width: Theme.hostDotSize; height: width; radius: width / 2
                color: root.connected ? Theme.accent : Theme.ink3
            }
            Text {
                id: hostLabel
                text: root.subtitle
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.optHostSize; font.weight: Font.Medium
            }
        }

        // Onglets : [LB] Stream | Console [RB]
        Row {
            id: tabStrip
            x: Theme.optPad
            y: host.y + host.height + Theme.optTabsTop
            width: panel.width - 2 * Theme.optPad
            height: Theme.optTabsHeight
            spacing: Theme.listIconGap
            visible: root.tabs.length > 1

            ButtonGlyph {
                anchors.verticalCenter: parent.verticalCenter
                label: "LB"
                ink: root.flashed < 0 ? Theme.inkOnLight : Theme.optTabInk
                color: root.flashed < 0 ? Theme.ink : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.optGlyphFade } }
            }
            Item {
                id: track
                width: parent.width - 2 * (parent.spacing + Theme.glyphSize * Theme.glyphPillScale)
                height: parent.height
                readonly property real cell: (width - 6) / Math.max(1, root.tabs.length)
                Rectangle { anchors.fill: parent; radius: Theme.optTabsRadius; color: Theme.segmentTrack }
                Rectangle {
                    id: tabPill
                    x: 3 + root.tab * track.cell; y: 3
                    width: track.cell; height: parent.height - 6
                    radius: Theme.optTabRadius
                    color: Theme.segmentActive
                    Behavior on x {
                        enabled: root.opened
                        NumberAnimation {
                            duration: Theme.optTabMove.duration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.optTabMove.curve
                        }
                    }
                }
                Repeater {
                    model: root.tabs.length
                    Text {
                        x: 3 + index * track.cell; y: 3
                        width: track.cell; height: track.height - 6
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: root.tabs[index] ? root.tabs[index].label : ""
                        color: index === root.tab ? Theme.ink : Theme.optTabInk
                        Behavior on color { ColorAnimation { duration: Theme.optTabInkFade } }
                        font.family: Theme.fontUi; font.pixelSize: Theme.optTabSize; font.weight: Font.DemiBold
                        HoverArea { anchors.fill: parent; onClicked: root.switchTab(index - root.tab) }
                    }
                }
            }
            ButtonGlyph {
                anchors.verticalCenter: parent.verticalCenter
                label: "RB"
                ink: root.flashed > 0 ? Theme.inkOnLight : Theme.optTabInk
                color: root.flashed > 0 ? Theme.ink : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.optGlyphFade } }
            }
        }

        // Une liste par onglet : celle qui part s'efface en glissant de côté, l'autre arrive.
        Item {
            id: body
            x: Theme.optPad
            y: (tabStrip.visible ? tabStrip.y + tabStrip.height : host.y + host.height) + Theme.optContentTop
            width: panel.width - 2 * Theme.optPad
            height: legend.y - y - Theme.optListBottom
            Repeater {
                id: panes
                model: root.tabs.length
                SettingsList {
                    readonly property int offset: index - root.tab      // < 0 : à gauche
                    width: body.width; height: body.height
                    rows: root.tabs[index] ? root.tabs[index].rows : []
                    metrics: Theme.listSheet
                    fadeColor: Theme.optFadeColor
                    focus: index === root.tab
                    live: root.opened
                    opacity: offset === 0 ? 1 : 0
                    visible: opacity > 0
                    transform: Translate { x: paneShift.value }
                    QtObject {
                        id: paneShift
                        property real value: offset === 0 ? 0 : offset * Theme.optPaneShift
                        Behavior on value {
                            enabled: root.opened
                            NumberAnimation {
                                duration: Theme.reducedMotion ? 0 : Theme.optPaneMove
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                            }
                        }
                    }
                    Behavior on opacity {
                        enabled: root.opened
                        NumberAnimation { duration: Theme.reducedMotion ? Theme.reducedSpring.duration : Theme.optPaneFade }
                    }
                    onChanged: function(key, value) { root.changed(key, value) }
                    onActionRequested: function(key) { root.actionRequested(key) }
                    onHoldCompleted: function(key) { root.holdCompleted(key) }
                }
            }
        }

        ControllerLegend {
            id: legend
            x: Theme.optPad
            y: panel.height - Theme.optPad - height
            spacing: Theme.optLegendGap
            textSize: Theme.legendSizeCoco
            glyphGap: Theme.legendGlyphGapCoco
            pressing: root.pressing
            hints: [ { glyph: "B", label: qsTr("Fermer") },
                     { glyph: "A", label: root.list && root.list.currentRow && root.list.currentRow.hold
                                         ? qsTr("Maintenir") : qsTr("Modifier") } ]
            onTriggered: function(glyph) {
                if (glyph === "B") root.close()
                else if (root.list) root.list.activate()
            }
        }
    }
}
