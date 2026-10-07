import QtQuick

// Fiche du jeu sélectionné, ouverte par le bas du pad sur l'étagère : à la place du héros et
// de l'étagère (qui s'effacent comme pour un écran de message), sur le fond du jeu. Logo ou
// titre, faits (genres, année, PEGI, taille), studios, description qui défile, et en bas
// « Désinstaller » quand le PC sait le faire.
// Pad : bas fait défiler la description, puis descend sur le bouton ; haut remonte, puis
// referme la fiche une fois en haut ; B referme ; A sur le bouton → uninstallRequested().
// Présentation pure, en pixels du canevas : à poser dans HomeScreen.stage.
FocusScope {
    id: root

    property bool shown: false
    property string title
    property url logo                    // logo du jeu ; vide = le titre en texte
    property string facts                // « Action · RPG · 2022 · PEGI 16 · 49,7 Go »
    property string credits              // « FromSoftware · Bandai Namco »
    property string description          // texte simple (Format.plainText)
    property bool canUninstall: false
    property bool uninstalling: false    // désinstallation en cours sur le PC

    signal uninstallRequested()

    property bool onButton: false        // le bouton a le focus (sinon la description)
    // Défilement voulu de la description : la cible, pas la valeur animée (relire celle-ci en
    // pleine animation ferait repartir chaque appui répété de presque zéro).
    property real scrollY: 0
    // Hauteur d'une ligne de description : défilement et zone visible en lignes entières
    // (sinon des lignes à moitié coupées en haut et en bas).
    readonly property real lineHeight: body.lineCount > 0 ? body.contentHeight / body.lineCount
                                                          : Theme.gamePageTextSize * Theme.gamePageTextLineHeight
    readonly property bool hasButton: canUninstall || uninstalling

    function open() {
        onButton = false
        scrollY = 0
        shown = true
        Sounds.play("open")
    }
    function close() {
        if (!shown) return
        pad.stop()
        shown = false
        Sounds.play("back")
    }

    // Un cran de défilement, ou le passage au bouton une fois en bas.
    function step(dir) {
        var max = Math.max(0, text.contentHeight - text.height)
        if (dir > 0) {
            if (!onButton && scrollY < max) {
                scrollY = Math.min(max, scrollY + Theme.gamePageScrollLines * lineHeight)
                Sounds.play("move")
            } else if (!onButton && hasButton) {
                onButton = true
                Sounds.play("tick")
            } else {
                Sounds.play("edge")
            }
        } else if (onButton) {
            onButton = false
            Sounds.play("tick")
        } else if (scrollY > 0) {
            scrollY = Math.max(0, scrollY - Theme.gamePageScrollLines * lineHeight)
            Sounds.play("move")
        } else {
            close()
        }
    }

    anchors.fill: parent
    visible: shown || appear.opacity > 0
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
        case Qt.Key_Escape:
            close()
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (onButton && canUninstall && !uninstalling) {
                Sounds.play("select")
                uninstallRequested()
            }
            break
        }
    }
    Keys.onReleased: function(event) { pad.release(event) }
    onActiveFocusChanged: if (!activeFocus) pad.stop()

    Appear {
        id: appear
        anchors.fill: parent
        shown: root.shown
        delay: Theme.messageSwap
        hideDuration: Theme.messageSwap

        Column {
            id: header
            x: Theme.margin
            y: Theme.gamePageTop
            width: Theme.heroWidth
            spacing: Theme.gamePageLineGap

            Image {
                id: logoImage
                visible: status === Image.Ready
                source: root.logo
                height: Theme.gamePageLogoHeight
                width: Math.min(Theme.heroLogoMaxWidth, implicitWidth * height / Math.max(1, implicitHeight))
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                asynchronous: true
            }
            Text {
                visible: !logoImage.visible
                width: parent.width
                text: root.title
                color: Theme.ink
                wrapMode: Text.WordWrap
                maximumLineCount: Theme.heroTitleMaxLines
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: Theme.gamePageTitleSize; font.weight: Font.DemiBold
                font.letterSpacing: Theme.heroTitleSpacing
            }
            Text {
                visible: text !== ""
                topPadding: Theme.gamePageFactsTop
                text: root.facts
                color: Theme.heroMetaColor
                font.family: Theme.fontUi; font.pixelSize: Theme.heroSubSize; font.weight: Font.Medium
            }
            Text {
                visible: text !== ""
                text: root.credits
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.heroMetaSize
            }
        }

        // La description, découpée : elle défile au pad, jamais au doigt.
        Flickable {
            id: text
            x: Theme.margin
            y: header.y + header.height + Theme.gamePageTextTop
            width: Theme.heroWidth
            height: Math.floor(((root.hasButton ? button.y : legend.y) - Theme.gamePageTextTop - y) / root.lineHeight)
                    * root.lineHeight
            contentHeight: body.height
            contentY: root.scrollY
            clip: true
            interactive: false
            Behavior on contentY { NumberAnimation { duration: Theme.gamePageScroll; easing.type: Theme.easeOut } }

            Text {
                id: body
                width: parent.width
                text: root.description !== "" ? root.description : qsTr("Pas de description pour ce jeu.")
                color: Theme.heroSubColor
                wrapMode: Text.WordWrap
                lineHeight: Theme.gamePageTextLineHeight
                font.family: Theme.fontUi; font.pixelSize: Theme.gamePageTextSize
            }
        }

        // Désinstaller : pastille discrète (ce n'est pas l'action principale), éclairée au focus.
        Rectangle {
            id: button
            visible: root.hasButton
            x: Theme.margin
            y: legend.y - Theme.gamePageButtonBottom - height
            width: buttonRow.width + Theme.playPadLeft + Theme.playPadRight
            height: Theme.playHeight; radius: height / 2
            color: root.onButton ? Theme.gamePageButtonFocusFill : Theme.gamePageButtonFill
            Behavior on color { ColorAnimation { duration: Theme.sheetFocusFade } }

            Row {
                id: buttonRow
                x: Theme.playPadLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.playGap
                ButtonGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "A"
                    size: Theme.playGlyphSize
                    fontSize: Theme.playGlyphFontSize
                    opacity: root.onButton && !root.uninstalling ? 1 : 0
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.uninstalling ? qsTr("Désinstallation…") : qsTr("Désinstaller")
                    color: root.onButton ? Theme.ink : Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: Theme.playLabelSize; font.weight: Font.DemiBold
                }
            }
        }

        ControllerLegend {
            id: legend
            x: Theme.margin
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.sheetPadBottom
            hints: (root.onButton && root.canUninstall && !root.uninstalling
                    ? [{ glyph: "A", label: qsTr("Désinstaller") }] : [])
                   .concat([{ glyph: "B", label: qsTr("Retour") }])
        }
    }
}
