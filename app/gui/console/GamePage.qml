import QtQuick
import QtQuick.Effects

// Fiche éditoriale du jeu (FicheEditoriale, MotionFiche), ouverte par le bas du pad sur le
// carrousel : la jaquette, à gauche, est celle du carrousel (CoverFlow.detail) ; cette page
// pose à droite l'éditeur, le titre, la méta et ses pastilles, la description (qui défile par
// lignes entières), les chiffres, les faits et les boutons, en cascade ; en haut à gauche
// « ↑ Bibliothèque », en bas l'aide. Un champ absent disparaît (CasLimites).
// Pad : bas fait défiler la description, puis, s'il y en a un, va sur « Désinstaller » ; haut
// remonte, puis referme une fois en haut ; B referme ; A joue (ou désinstalle, sur ce bouton) ;
// X : favori ; Y : options. Présentation pure, en pixels du canevas : à poser dans
// HomeScreen.detailStage.
FocusScope {
    id: root

    property bool shown: false
    property string title
    property url logo                    // (le logo n'est pas sur la fiche CocoOS)
    property string label                // éditeur, en capitales au-dessus du titre
    property string meta                 // « 2011 · Bac à sable, Survie »
    property var tags: []                // pastilles : « PEGI 7 », modes de jeu…
    property string description          // texte simple (Format.plainText) ; vide : pas de section
    // Chiffres : [{ value, unit, label }] ou [{ text, label }] (« Jamais joué »).
    property var stats: []
    // Faits : [{ label, value }] (Développeur, Sortie, Bibliothèque, Dernière session).
    property var details: []
    property bool favorite: false
    property bool canUninstall: false
    property bool uninstalling: false    // désinstallation en cours sur le PC
    // (Ambiant : faits et studios en une ligne ; gardés pour les tests et l'appelant.)
    property string facts
    property string credits

    signal playRequested()
    signal favoriteRequested()
    signal optionsRequested()
    signal uninstallRequested()

    property bool onButton: false        // « Désinstaller » a le focus (sinon la description)
    // Défilement voulu de la description : la cible, pas la valeur animée.
    property real scrollY: 0
    readonly property real lineHeight: Theme.ficheTextSize * Theme.ficheTextLineHeight
    readonly property bool hasButton: canUninstall || uninstalling
    readonly property real maxScroll: Math.max(0, body.contentHeight - textBox.height)

    function open() {
        onButton = false
        scrollY = 0
        shown = true
        Sounds.play("fiche_open")
    }
    function close() {
        if (!shown) return
        pad.stop()
        shown = false
        Sounds.play("fiche_close")
    }
    function scrollText(dir) {
        var next = Math.min(maxScroll, Math.max(0, scrollY + dir * lineHeight))
        if (next === scrollY) return
        scrollY = next
        Sounds.play("move")
    }
    // Un cran de défilement, le passage au bouton une fois en bas, ou la fermeture en haut.
    function step(dir) {
        if (dir > 0) {
            if (!onButton && scrollY < maxScroll) scrollText(1)
            else if (!onButton && hasButton) { onButton = true; Sounds.play("tick") }
            else Sounds.play("edge")
        } else if (onButton) {
            onButton = false
            Sounds.play("tick")
        } else if (scrollY > 0) {
            scrollText(-1)
        } else {
            close()
        }
    }

    anchors.fill: parent
    visible: shown || column.opacity > 0
    focus: shown

    PadRepeat {
        id: pad
        keys: [Qt.Key_Up, Qt.Key_Down]
        onTriggered: function(key) { root.step(key === Qt.Key_Down ? 1 : -1) }
    }
    Keys.onPressed: function(event) {
        if (pad.press(event)) return
        event.accepted = true            // fiche ouverte : rien ne traverse vers l'accueil
        if (event.isAutoRepeat) return
        switch (event.key) {
        case Qt.Key_Escape: close(); break
        case Qt.Key_Menu: favoriteRequested(); break             // X
        case Qt.Key_Hangup: case Qt.Key_Y: optionsRequested(); break
        }
    }
    Keys.onReleased: function(event) {
        pad.release(event)
        if (event.isAutoRepeat || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        if (onButton) {
            if (canUninstall && !uninstalling) {
                Sounds.play("select")
                uninstallRequested()
            }
        } else {
            playRequested()
        }
    }
    onActiveFocusChanged: if (!activeFocus) pad.stop()

    // Un bloc qui arrive en cascade (cocoIn : de 18 px plus bas, flou, en fondu) et repart d'un coup.
    component Cascade: Item {
        id: block
        property int order: 0
        property real lift: Theme.ficheInTravel
        width: childrenRect.width; height: childrenRect.height
        opacity: 0
        transform: Translate { y: block.lift }
        readonly property bool blurred: GraphicsInfo.api !== GraphicsInfo.Unknown && GraphicsInfo.api !== GraphicsInfo.Software
                                        && !Theme.reducedMotion
        layer.enabled: blurred && opacity > 0 && opacity < 1
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: (1 - block.opacity) * Theme.ficheInBlur / 16 }
        Connections {
            target: root
            function onShownChanged() {
                if (root.shown) { leave.stop(); enter.restart() }
                else { enter.stop(); leave.restart() }
            }
        }
        SequentialAnimation {
            id: enter
            PauseAnimation { duration: Theme.reducedMotion ? 0 : Theme.ficheCascade[Math.min(block.order, Theme.ficheCascade.length - 1)] }
            ParallelAnimation {
                NumberAnimation { target: block; property: "opacity"; to: 1; duration: Theme.reducedMotion ? 200 : Theme.ficheIn; easing.type: Easing.OutCubic }
                NumberAnimation {
                    target: block; property: "lift"; to: 0; duration: Theme.reducedMotion ? 0 : Theme.ficheIn
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain
                }
            }
        }
        ParallelAnimation {
            id: leave
            NumberAnimation { target: block; property: "opacity"; to: 0; duration: Theme.ficheOut }
            NumberAnimation { target: block; property: "lift"; to: Theme.ficheInTravel; duration: Theme.ficheOut; easing.type: Easing.InQuad }
        }
    }

    // Bouton pastille : blanc (Jouer) ou de verre, avec son glyphe.
    component PillButton: Pressable {
        id: pill
        property string glyph
        property string text
        property bool primary: false
        property bool focused: false
        width: Theme.playPadLeft + pillRow.width + (primary ? Theme.playPadRight : Theme.optionsPadRight)
        height: Theme.playHeight
        hovered: pillMouse.containsMouse
        hoverScale: Theme.hoverScale
        signal clicked()
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: pill.primary ? Theme.ink : Theme.glassRaised
            border.color: pill.primary ? "transparent" : Theme.hairlineStrong
        }
        Row {
            id: pillRow
            x: Theme.playPadLeft
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.playGap
            ButtonGlyph {
                anchors.verticalCenter: parent.verticalCenter
                label: pill.glyph
                size: pill.primary ? Theme.playGlyphSize : Theme.optionsGlyphSize
                color: pill.primary ? Theme.inkOnLight : "transparent"
                ink: pill.primary ? Theme.ink : Theme.optionsGlyphInk
                fontSize: pill.primary ? Theme.playGlyphFontSize : Theme.optionsGlyphFontSize
                weight: pill.primary ? Font.Bold : Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.text
                color: pill.primary ? Theme.inkOnLight : Theme.ink
                font.family: Theme.fontUi; font.weight: Font.DemiBold
                font.pixelSize: pill.primary ? Theme.playLabelSize : Theme.optionsLabelSize
            }
        }
        FocusRing { shown: pill.focused }
        HoverArea { id: pillMouse; anchors.fill: parent; onClicked: pill.clicked() }
    }

    // --- « ↑ Bibliothèque », à la place du logo ---
    Rectangle {
        id: back
        x: Theme.marginScreen - Theme.backPillShift * (1 - column.opacity); y: Theme.tabsTop
        width: Theme.backPillPadLeft + backRow.width + Theme.backPillPadRight
        height: Theme.backPillHeight
        radius: height / 2
        color: Theme.backPillFill
        border.color: Theme.hairlineStrong
        opacity: column.opacity
        Row {
            id: backRow
            x: Theme.backPillPadLeft
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "↑"
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.textCaption.size + 1; font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Bibliothèque")
                color: Theme.ink
                font.family: Theme.fontUi; font.pixelSize: Theme.textCaption.size; font.weight: Font.DemiBold
            }
        }
        HoverArea { anchors.fill: parent; onClicked: root.close() }
    }

    // --- La colonne de droite ---
    Column {
        id: column
        x: Theme.ficheText.x; y: Theme.ficheText.y
        width: Theme.ficheTextWidth
        // Opacité d'ensemble : celle du premier bloc (sert au bouton du haut et à `visible`).
        opacity: labelBlock.opacity > 0 ? 1 : 0

        Cascade {
            id: labelBlock
            order: 0
            Text {
                visible: root.label !== ""
                text: root.label.toUpperCase()
                color: Theme.ficheLabelInk
                font.family: Theme.fontUi; font.pixelSize: Theme.ficheLabelSize; font.weight: Font.DemiBold
                font.letterSpacing: 0.08 * Theme.ficheLabelSize
            }
        }
        Item { width: 1; height: root.label !== "" ? Theme.ficheGap : 0 }
        Cascade {
            order: 1
            Text {
                width: Theme.ficheTextWidth
                text: root.title
                color: Theme.ink
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeightMode: Text.FixedHeight
                lineHeight: Theme.ficheTitleSize * 1.05
                font.family: Theme.fontUi; font.pixelSize: Theme.ficheTitleSize; font.weight: Font.DemiBold
                font.letterSpacing: -0.045 * Theme.ficheTitleSize
            }
        }
        Item { width: 1; height: Theme.ficheGap }
        Cascade {
            order: 2
            Row {
                spacing: Theme.space2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.meta !== ""
                    text: root.meta
                    rightPadding: 6
                    color: Theme.homeMetaInk
                    font.family: Theme.fontUi; font.pixelSize: Theme.ficheMetaSize; font.weight: Font.Medium
                }
                Repeater {
                    model: root.tags
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: tagText.implicitWidth + 2 * Theme.ficheTagPad
                        height: Theme.ficheTagHeight
                        radius: Theme.ficheTagRadius
                        color: "transparent"
                        border.color: Theme.ficheTagStroke
                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.ficheTagInk
                            font.family: Theme.fontUi; font.pixelSize: Theme.pegiSize; font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
        Item { width: 1; height: root.description !== "" ? Theme.ficheTextTop : 0 }
        Cascade {
            order: 3
            Item {
                id: textBox
                visible: root.description !== ""
                width: Theme.ficheTextMaxWidth
                height: root.description !== "" ? Theme.ficheTextLines * root.lineHeight : 0
                clip: true
                Text {
                    id: body
                    y: -scroll
                    property real scroll: root.scrollY
                    Behavior on scroll { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.OutCubic } }
                    width: parent.width
                    text: root.description
                    color: Theme.ficheTextInk
                    wrapMode: Text.WordWrap
                    lineHeightMode: Text.FixedHeight
                    lineHeight: root.lineHeight
                    font.family: Theme.fontUi; font.pixelSize: Theme.ficheTextSize; font.weight: Font.Normal
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) { root.scrollText(wheel.angleDelta.y > 0 ? -1 : 1) }
                }
            }
        }
        Item { width: 1; height: root.stats.length > 0 ? Theme.ficheStatsTop : 0 }
        Cascade {
            order: 4
            Row {
                spacing: Theme.ficheStatsGap
                Repeater {
                    model: root.stats
                    Column {
                        spacing: 6
                        // Le chiffre (interligne 1) et son unité, sur la même ligne de base.
                        Item {
                            width: number.implicitWidth + 4 + unit.implicitWidth
                            height: Theme.ficheStatSize
                            Text {
                                id: number
                                readonly property real size: modelData.value !== undefined ? Theme.ficheStatSize : Theme.ficheStatUnitSize
                                anchors.baseline: parent.top
                                anchors.baselineOffset: Theme.ficheStatSize * 0.8
                                text: modelData.value !== undefined ? modelData.value : modelData.text
                                color: Theme.ink
                                font.family: Theme.fontUi; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
                                font.pixelSize: size
                                font.letterSpacing: -0.04 * size
                            }
                            Text {
                                id: unit
                                x: number.implicitWidth + 4
                                anchors.baseline: number.baseline
                                text: modelData.unit || ""
                                color: Theme.ink3
                                font.family: Theme.fontUi; font.pixelSize: Theme.ficheStatUnitSize; font.weight: Font.Medium
                            }
                        }
                        Text {
                            text: modelData.label
                            color: Theme.ficheLabelInk
                            font.family: Theme.fontUi; font.pixelSize: Theme.ficheStatLabelSize; font.weight: Font.Medium
                        }
                    }
                }
            }
        }
        Item { width: 1; height: root.details.length > 0 ? Theme.ficheFactsTop : 0 }
        Cascade {
            order: 5
            Item {
                visible: root.details.length > 0
                width: Theme.ficheFactsWidth
                height: visible ? Theme.ficheFactsPad + facts.height : 0
                Rectangle { width: parent.width; height: 1; color: Theme.hairlineStrong }
                Grid {
                    id: facts
                    y: Theme.ficheFactsPad
                    columns: 4
                    columnSpacing: 20
                    Repeater {
                        model: root.details
                        Column {
                            width: (Theme.ficheFactsWidth - 3 * 20) / 4
                            spacing: 4
                            Text {
                                text: modelData.label
                                color: Theme.helpInk
                                font.family: Theme.fontUi; font.pixelSize: Theme.ficheFactLabelSize; font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                text: modelData.value
                                elide: Text.ElideRight
                                color: Theme.ink
                                font.family: Theme.fontUi; font.pixelSize: Theme.ficheFactSize; font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
        Item { width: 1; height: Theme.ficheButtonsTop }
        Cascade {
            order: 6
            Row {
                spacing: Theme.homeButtonsGap
                PillButton {
                    primary: true; glyph: "A"; text: qsTr("Jouer")
                    onClicked: root.playRequested()
                }
                PillButton {
                    glyph: "X"; text: root.favorite ? qsTr("Retirer") : qsTr("Favori")
                    onClicked: root.favoriteRequested()
                }
                PillButton {
                    glyph: "Y"; text: qsTr("Options")
                    onClicked: root.optionsRequested()
                }
                // (Absent de la maquette : la désinstallation à distance d'un jeu Steam, qui existait déjà.)
                PillButton {
                    visible: root.hasButton
                    glyph: "A"
                    text: root.uninstalling ? qsTr("Désinstallation…") : qsTr("Désinstaller")
                    focused: root.onButton && root.activeFocus
                    onClicked: if (root.canUninstall && !root.uninstalling) root.uninstallRequested()
                }
            }
        }
    }

    // --- Aide : « Appuyez sur B ou ↑ pour revenir » ---
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - Theme.ficheHelpBottom - height
        spacing: Theme.space2
        opacity: column.opacity * (banner.shown ? 0 : 1)
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Appuyez sur")
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.helpSize; font.weight: Font.Medium
        }
        ButtonGlyph {
            anchors.verticalCenter: parent.verticalCenter
            label: "B"; size: Theme.helpGlyphSize; ink: Theme.helpGlyphStroke
            fontSize: Theme.emptyHelpGlyphSize; weight: Font.DemiBold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("ou")
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.helpSize; font.weight: Font.Medium
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.helpGlyphSize; height: width; radius: width / 2
            color: "transparent"; border.color: Theme.helpGlyphStroke
            Text { anchors.centerIn: parent; text: "↑"; color: Theme.ink; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("pour revenir")
            color: Theme.ink3
            font.family: Theme.fontUi; font.pixelSize: Theme.helpSize; font.weight: Font.Medium
        }
    }

    // La bannière des favoris de l'accueil, que la fiche montre aussi (HomeScreen la pose).
    property Item banner: Item { property bool shown: false }
}
