import QtQuick

// Bloc héros de l'accueil : méta (source | dernière session), titre du jeu,
// sous-titre (temps de jeu, mise à jour) et actions (Jouer, Options, Épingler).
// Partie en cours : « Reprendre la partie » et « Quitter la partie » (appui maintenu),
// les boutons du prototype des micro-interactions ; avec la manette (`focus`, haut depuis
// l'étagère), ← / → choisissent, A agit, bas ou B la rendent (leaveRequested).
// Tout est posé à partir du BAS du bloc : un titre sur deux lignes le fait
// grandir vers le haut, sans déplacer les actions. Quand le jeu change, chaque
// champ se remplace en glissant et en se floutant (SwapBox, swapText du prototype).
// Aucune dépendance Moonlight.
Item {
    id: root

    property string title
    property url logo                // logo du jeu (Companion) ; vide = le titre en texte
    property string source           // « Steam », « GOG »… ; vide = masqué
    property string lastPlayed       // « Hier, 23:40 » ; vide = masqué
    property string playtime         // « 412 h de jeu » ; vide = masqué
    property string updateNote       // mise à jour en attente côté PC ; vide = masqué
    property bool running: false     // le jeu tourne déjà : « Reprendre »
    property string playLabel: ""    // autre libellé du bouton A (jeu à télécharger) ; vide = Jouer
    property bool favorite: false    // épinglé en tête de l'étagère : X le détache
    // Sens du dernier déplacement dans la liste (+1 vers la droite) : les textes
    // glissent dans ce sens. `animated` à false : ils changent sans transition.
    property int direction: 1
    property bool animated: true
    property bool pressed: false     // le bouton Jouer reste enfoncé (lancement)
    property bool held: false        // A enfoncé : le bouton Jouer s'écrase (le jeu part au relâché)
    // Glyphes (« légende manette ») : à l'entrée de l'accueil, ils apparaissent après le reste.
    property bool actionsShown: true

    signal playRequested()
    signal quitRequested()           // Quitter tenu jusqu'au bout
    signal leaveRequested()          // bas ou B : la manette retourne à l'étagère
    signal holdHintRequested()       // Quitter lâché avant la fin

    // Boutons à la manette : 0 Reprendre, 1 Quitter ; A tenu sur l'un ou l'autre.
    property int selected: 0
    property bool playHeld: false
    property bool quitHeld: false
    onActiveFocusChanged: {
        playHeld = quitHeld = false
        selected = 0
    }
    onRunningChanged: if (!running) {
        quitReset.stop()
        quitFill.reset()
        quitFill.opacity = 1
    }
    function choose(index) {
        if (index === selected) {
            Sounds.play("edge")
            return
        }
        playHeld = quitHeld = false
        selected = index
        Sounds.play("move")
    }
    function releaseQuit() {
        quitHeld = false
        if (!quitFill.done) holdHintRequested()
    }
    Keys.onLeftPressed: choose(0)
    Keys.onRightPressed: choose(running ? 1 : 0)
    Keys.onUpPressed: Sounds.play("edge")
    Keys.onDownPressed: leaveRequested()
    Keys.onEscapePressed: leaveRequested()
    function pressA(event) {
        if (event.isAutoRepeat) return
        if (selected === 0) playHeld = true
        else quitHeld = true
    }
    Keys.onReturnPressed: function(event) { pressA(event) }
    Keys.onEnterPressed: function(event) { pressA(event) }
    Keys.onReleased: function(event) {
        if (event.isAutoRepeat || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        if (playHeld) {
            playRequested()             // (d'abord : un lancement garde le bouton enfoncé)
            playHeld = false
        } else if (quitHeld) {
            releaseQuit()
        }
    }

    // Jouer est impossible (PC hors ligne) : le bouton se secoue.
    function refusePlay() { playButton.refuse() }
    signal optionsRequested()
    signal favoriteRequested()

    // Hauteur de la boîte du titre pour `lines` lignes.
    function titleHeight(lines) {
        return Math.round(lines * Theme.heroTitleLineHeight + Theme.heroTitlePadBottom)
    }

    width: Theme.heroWidth
    // Hauteur du bloc avec un titre sur une ligne (le titre peut dépasser en haut).
    implicitHeight: metaBox.height + Theme.heroTitleTopMargin + titleHeight(1)
                    + Theme.heroSubTopMargin + subBox.height
                    + Theme.heroActionsTopMargin + Theme.playHeight

    // --- Méta ---
    component MetaLine: Row {
        id: meta
        property var value: ({})
        readonly property string source: value.source || ""
        readonly property string lastPlayed: value.lastPlayed || ""

        spacing: Theme.heroMetaGap
        Text {
            visible: text !== ""
            text: meta.source
            color: Theme.heroMetaColor
            font.family: Theme.fontUi; font.pixelSize: Theme.heroMetaSize; font.weight: Font.Medium
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: meta.source !== "" && meta.lastPlayed !== ""
            width: 1; height: Theme.heroSeparatorHeight
            color: Theme.heroSeparatorColor
        }
        Text {
            visible: text !== ""
            text: meta.lastPlayed
            color: Theme.heroMetaColor
            font.family: Theme.fontUi; font.pixelSize: Theme.heroMetaSize; font.weight: Font.Medium
        }
    }

    SwapBox {
        id: metaBox
        y: titleBox.y - Theme.heroTitleTopMargin - height
        width: parent.width; height: Theme.heroMetaHeight
        key: root.source + "\n" + root.lastPlayed
        value: ({ source: root.source, lastPlayed: root.lastPlayed })
        direction: root.direction
        animated: root.animated
        axis: "x"; distance: Theme.heroSwapTravel
        duration: Theme.heroSwapIn; exitDuration: Theme.heroSwapOut
        enterCurve: Theme.curveOut; exitCurve: Theme.curveExit
        blur: Theme.swapBlur

        MetaLine {}
        MetaLine {}
    }

    // --- Titre : le logo du jeu s'il en a un (une fois chargé), sinon son nom ---
    component TitleLines: Item {
        id: lines
        property var value: ({})
        readonly property bool showLogo: logoImage.status === Image.Ready
        readonly property int lineCount: showLogo ? Theme.heroLogoLines : Math.max(1, label.lineCount)

        width: Theme.heroWidth
        height: root.titleHeight(lineCount)

        Image {
            id: logoImage
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.heroTitlePadBottom
            width: Theme.heroLogoMaxWidth
            height: root.titleHeight(Theme.heroLogoLines) - Theme.heroTitlePadBottom
            source: lines.value.logo || ""
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignBottom
            asynchronous: true
            sourceSize.width: Math.ceil(width * Theme.scale)
            opacity: lines.showLogo ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.heroLogoFade } }
        }

        FontMetrics { id: metrics; font: label.font }
        Text {
            id: label
            opacity: lines.showLogo ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.heroLogoFade } }
            // L'interligne (1.04) est plus serré que la hauteur naturelle de la
            // police : on remonte le texte de la moitié de l'écart, comme en CSS.
            y: (Theme.heroTitleLineHeight - metrics.height) / 2
            width: parent.width
            text: lines.value.title || ""
            color: Theme.ink
            wrapMode: Text.WordWrap
            maximumLineCount: Theme.heroTitleMaxLines
            elide: Text.ElideRight
            lineHeightMode: Text.FixedHeight
            lineHeight: Theme.heroTitleLineHeight
            font.family: Theme.fontUi; font.pixelSize: Theme.heroTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: Theme.heroTitleSpacing
        }
    }

    SwapBox {
        id: titleBox
        y: subBox.y - Theme.heroSubTopMargin - height
        width: parent.width
        // La boîte s'ajuste au titre courant ; la méta suit, au-dessus.
        height: root.titleHeight(currentItem ? currentItem.lineCount : 1)
        Behavior on height {
            enabled: root.animated
            NumberAnimation { duration: Theme.heroTitleResize; easing.type: Theme.easeQuint }
        }
        key: root.title
        value: ({ title: root.title, logo: root.logo.toString() })
        direction: root.direction
        animated: root.animated
        axis: "x"; distance: Theme.heroSwapTravel
        duration: Theme.heroSwapIn; exitDuration: Theme.heroSwapOut
        enterCurve: Theme.curveOut; exitCurve: Theme.curveExit
        blur: Theme.swapBlur

        TitleLines {}
        TitleLines {}
    }

    // --- Sous-titre ---
    component SubLine: Row {
        id: sub
        property var value: ({})
        readonly property string playtime: value.playtime || ""
        readonly property string updateNote: value.updateNote || ""

        height: Theme.heroSubHeight
        spacing: Theme.heroSubGap
        Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            visible: text !== ""
            text: sub.playtime
            color: Theme.heroSubColor
            font.family: Theme.fontUi; font.pixelSize: Theme.heroSubSize
        }
        Row {
            height: parent.height
            visible: sub.updateNote !== ""
            spacing: Theme.heroUpdateDotGap
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.heroUpdateDotSize; height: width; radius: 1
                color: Theme.accent
            }
            Text {
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: sub.updateNote
                color: Theme.heroSubColor
                font.family: Theme.fontUi; font.pixelSize: Theme.heroSubSize
            }
        }
    }

    SwapBox {
        id: subBox
        y: actions.y - Theme.heroActionsTopMargin - height
        width: parent.width; height: Theme.heroSubHeight
        key: root.playtime + "\n" + root.updateNote
        value: ({ playtime: root.playtime, updateNote: root.updateNote })
        direction: root.direction
        animated: root.animated
        axis: "x"; distance: Theme.heroSwapTravel
        duration: Theme.heroSwapIn; exitDuration: Theme.heroSwapOut
        enterCurve: Theme.curveOut; exitCurve: Theme.curveExit
        blur: Theme.swapBlur
        delay: Theme.heroSubSwapDelay

        SubLine {}
        SubLine {}
    }

    // --- Actions ---
    // Anneau de focus du bouton qui a la manette (il s'écrase avec lui).
    component FocusRing: Rectangle {
        property bool shown: false
        anchors.fill: parent
        anchors.margins: -(Theme.focusRingInset + Theme.focusRingWidth)
        radius: height / 2
        color: "transparent"
        border.width: Theme.focusRingWidth; border.color: Theme.ink
        opacity: shown ? 1 : 0
        scale: shown ? 1 : Theme.focusRingFrom
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.focusRingFade
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.springSnappy.duration
                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
            }
        }
    }
    component PlayText: Text {
        property var value
        height: Theme.playHeight
        verticalAlignment: Text.AlignVCenter
        text: value || ""
        color: Theme.inkOnAccent
        font.family: Theme.fontUi; font.pixelSize: Theme.playLabelSize; font.weight: Font.DemiBold
    }
    Row {
        id: actions
        anchors.bottom: parent.bottom
        spacing: Theme.heroActionsGap
        opacity: root.actionsShown ? 1 : 0
        Behavior on opacity {
            enabled: root.actionsShown
            SequentialAnimation {
                PauseAnimation { duration: Theme.entryLegendDelay }
                NumberAnimation { duration: Theme.entryTextFade; easing.type: Easing.OutCubic }
            }
        }

        Pressable {
            id: playButton
            width: Theme.playPadLeft + playRow.width + Theme.playPadRight
            height: Theme.playHeight
            down: root.held || root.pressed || root.playHeld

            Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.accent }
            Row {
                id: playRow
                x: Theme.playPadLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.playGap
                ButtonGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "A"
                    size: Theme.playGlyphSize
                    color: Theme.inkOnAccent
                    ink: Theme.accent
                    fontSize: Theme.playGlyphFontSize
                }
                // Le libellé : au lancement, il cède la place à « Lancement… » en glissant
                // (swapText du prototype), et le bouton s'élargit pour le contenir.
                SwapBox {
                    id: playText
                    readonly property string text: root.playLabel !== "" ? root.playLabel
                        : root.pressed ? (root.running ? qsTr("Reprise…") : qsTr("Lancement…"))
                        : root.running ? qsTr("Reprendre la partie") : qsTr("Jouer")
                    anchors.verticalCenter: parent.verticalCenter
                    width: playMetrics.advanceWidth; height: Theme.playHeight
                    Behavior on width {
                        enabled: root.animated
                        NumberAnimation {
                            duration: Theme.springSnappy.duration
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSnappy.curve
                        }
                    }
                    key: text
                    value: text
                    direction: root.pressed ? 1 : -1
                    animated: root.animated
                    duration: Theme.heroSwapIn; exitDuration: Theme.heroSwapOut
                    enterCurve: Theme.curveOut; exitCurve: Theme.curveExit
                    blur: Theme.swapBlur

                    PlayText {}
                    PlayText {}
                }
                TextMetrics { id: playMetrics; font: playFont.font; text: playText.text }
                PlayText { id: playFont; visible: false }
            }
            FocusRing { shown: root.activeFocus && root.selected === 0 }
            MouseArea { anchors.fill: parent; onClicked: root.playRequested() }
        }

        // Quitter la partie : A (ou le clic) tenu jusqu'au bout.
        Pressable {
            id: quitButton
            visible: root.running
            width: quitLabel.implicitWidth + 2 * Theme.quitPad
            height: Theme.playHeight
            down: (root.quitHeld || quitMouse.pressed) && !quitFill.done
            downScale: Theme.quitPressScale

            Item {
                anchors.fill: parent
                scale: quitFill.bounce          // plein : tout le bouton rebondit, anneau compris
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: Theme.quitBorderWidth; border.color: Theme.quitBorder
                    border.pixelAligned: false
                }
                PlayText {
                    id: quitLabel
                    anchors.centerIn: parent
                    value: qsTr("Quitter la partie")
                    color: Theme.ink
                }
                HoldFill {
                    id: quitFill
                    anchors.fill: parent
                    radius: height / 2
                    label: quitLabel.text
                    doneLabel: qsTr("Partie terminée")
                    centered: true
                    labelSize: Theme.playLabelSize; labelWeight: Font.DemiBold
                    bounces: false
                    holding: root.quitHeld || quitMouse.pressed
                    onCompleted: root.quitRequested()
                    onDoneChanged: if (done) quitReset.restart()
                }
                FocusRing { shown: root.activeFocus && root.selected === 1 }
            }
            MouseArea {
                id: quitMouse
                anchors.fill: parent
                onReleased: if (!quitFill.done) root.holdHintRequested()
            }
            // Le jeu tourne encore un moment après : la coche reste, puis le bouton se vide.
            SequentialAnimation {
                id: quitReset
                PauseAnimation { duration: Theme.quitResetDelay }
                NumberAnimation {
                    target: quitFill; property: "opacity"; to: 0; duration: Theme.quitResetFade
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOut
                }
                ScriptAction { script: { quitFill.reset(); quitFill.opacity = 1 } }
            }
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: optionsRow.width; height: optionsRow.height

            Row {
                id: optionsRow
                spacing: Theme.optionsGap
                ButtonGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Y"
                    ink: Theme.optionsColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Options")
                    color: Theme.optionsColor
                    font.family: Theme.fontUi; font.pixelSize: Theme.optionsLabelSize; font.weight: Font.Medium
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.optionsRequested() }
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: favoriteRow.width; height: favoriteRow.height

            Row {
                id: favoriteRow
                spacing: Theme.optionsGap
                ButtonGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "X"
                    ink: Theme.optionsColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.favorite ? qsTr("Désépingler") : qsTr("Épingler")
                    color: Theme.optionsColor
                    font.family: Theme.fontUi; font.pixelSize: Theme.optionsLabelSize; font.weight: Font.Medium
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.favoriteRequested() }
        }
    }
}
