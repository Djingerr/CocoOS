import QtQuick

// Bloc titre de l'accueil CocoOS, centré sous le carrousel (AccueilCarrousel) : titre du
// jeu, méta « Éditeur · Année · Genre » et PEGI, boutons « A Jouer » et « Y Options ».
// Partie en cours : « Reprendre la partie » et « Quitter la partie » (appui maintenu) ;
// avec la manette (`focus`, haut depuis le carrousel), ← / → choisissent, A agit, bas ou B
// la rendent (leaveRequested).
// Quand le jeu change, titre et méta se remplacent ensemble en fondu flou, en montant ou
// en descendant selon le sens (MotionNavigation) ; d'une catégorie à l'autre, de côté
// (`axis` "x", MotionCategories). Un titre trop long passe sur deux lignes équilibrées,
// puis en plus petit, puis en points de suspension (CasLimites). Aucune dépendance Moonlight.
Item {
    id: root

    property string title
    property url logo                // (logo du jeu : plus affiché sur l'accueil CocoOS)
    property string source           // (Ambiant)
    property string lastPlayed       // (Ambiant)
    property string playtime         // (Ambiant)
    // Méta sous le titre : ses morceaux (un absent disparaît avec son séparateur) et le PEGI.
    property var meta: []
    property string pegi: ""         // « PEGI 7 » ; vide = pas de pastille
    property string updateNote       // mise à jour ou téléchargement en cours : remplace la méta
    property bool running: false     // le jeu tourne déjà : « Reprendre »
    property string playLabel: ""    // autre libellé du bouton A (jeu à télécharger) ; vide = Jouer
    property bool waking: false      // le PC se réveille : roue et « Réveil du PC… » (MotionReveilPC)
    property bool favorite: false    // épinglé en tête de l'étagère : X le détache
    // Sens du dernier déplacement dans la liste (+1 vers la droite) : le nouveau titre
    // arrive par le bas. `axis` "x" : changement de catégorie, il arrive de côté.
    // `fast` : flèche maintenue, transitions courtes. `animated` à false : sans transition.
    property int direction: 1
    property string axis: "y"
    property bool fast: false
    property bool animated: true
    property bool pressed: false     // le bouton Jouer reste enfoncé (lancement)
    property bool held: false        // A enfoncé : le bouton Jouer s'écrase (le jeu part au relâché)
    // Glyphes (« légende manette ») : à l'entrée de l'accueil, ils apparaissent après le reste.
    property bool actionsShown: true

    signal playRequested()
    signal quitRequested()           // Quitter tenu jusqu'au bout
    signal leaveRequested()          // bas ou B : la manette retourne à l'étagère
    signal upRequested()             // haut : les icônes de la barre haute
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
    Keys.onUpPressed: upRequested()
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

    width: parent ? parent.width : Theme.canvasWidth
    implicitHeight: column.height

    // --- Titre et méta, remplacés ensemble ---
    TextMetrics { id: measure; font.family: Theme.fontUi; font.weight: Font.DemiBold }
    // Le titre à `size` px, interlettrage compris.
    function advance(text, size) {
        measure.font.pixelSize = size
        measure.font.letterSpacing = Theme.homeTitleSpacing * size
        measure.text = text
        return measure.advanceWidth
    }
    // { size, text } : sur une ligne à 48 px ; sinon deux lignes coupées au mot, le plus
    // équilibrées possible ; sinon pareil à 36 px ; sinon deux lignes à 36 px, la seconde
    // coupée par des points de suspension (le Text s'en charge).
    function fitTitle(text) {
        var sizes = [Theme.homeTitleSize, Theme.homeTitleSmallSize]
        var words = text.split(" ")
        for (var s = 0; s < sizes.length; s++) {
            var size = sizes[s]
            if (advance(text, size) <= Theme.homeTitleWidth)
                return { size: size, text: text }
            var best = null
            for (var i = 1; i < words.length; i++) {
                var a = words.slice(0, i).join(" "), b = words.slice(i).join(" ")
                var widest = Math.max(advance(a, size), advance(b, size))
                if (widest <= Theme.homeTitleWidth && (best === null || widest < best.widest))
                    best = { widest: widest, text: a + "\n" + b }
            }
            if (best !== null)
                return { size: size, text: best.text }
        }
        var half = Math.max(1, Math.ceil(words.length / 2))
        return { size: sizes[1], text: words.slice(0, half).join(" ") + "\n" + words.slice(half).join(" ") }
    }

    component TitleAndMeta: Column {
        id: block
        property var value: ({})
        // Calculé à chaque nouveau titre (pas en liaison : la mesure modifie TextMetrics).
        property var fitted: ({ size: Theme.homeTitleSize, text: "" })
        onValueChanged: fitted = root.fitTitle(value.title || "")
        width: root.width
        spacing: Theme.homeMetaTop
        // Interligne de 1,05 × la taille, comme en CSS (Qt l'appliquerait à la hauteur
        // naturelle de la police) ; le texte remonte de la moitié de l'écart.
        Item {
            width: parent.width
            height: titleText.lineCount * titleText.lineHeight
            FontMetrics { id: titleMetrics; font: titleText.font }
            Text {
                id: titleText
                y: (lineHeight - titleMetrics.height) / 2
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: block.fitted.text
                color: Theme.ink
                elide: Text.ElideRight
                maximumLineCount: 2
                lineHeightMode: Text.FixedHeight
                lineHeight: block.fitted.size * Theme.homeTitleLineHeight
                font.family: Theme.fontUi; font.pixelSize: block.fitted.size; font.weight: Font.DemiBold
                font.letterSpacing: Theme.homeTitleSpacing * block.fitted.size
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.homeMetaGap
            Repeater {
                // [« Mojang Studios », « · », « 2011 »…] : les séparateurs entre morceaux présents.
                model: (block.value.meta || []).reduce(function(all, part, i) {
                    return i === 0 ? [part] : all.concat(["·", part])
                }, [])
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: Theme.homeMetaInk
                    font.family: Theme.fontUi; font.pixelSize: Theme.homeMetaSize; font.weight: Font.Medium
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: (block.value.pegi || "") !== ""
                width: pegiText.implicitWidth + 2 * Theme.pegiPad
                height: Theme.pegiHeight
                radius: Theme.pegiRadius
                color: "transparent"
                border.color: Theme.pegiStroke
                Text {
                    id: pegiText
                    anchors.centerIn: parent
                    text: block.value.pegi || ""
                    color: Theme.ink
                    font.family: Theme.fontUi; font.pixelSize: Theme.pegiSize; font.weight: Font.DemiBold
                }
            }
        }
    }

    component PlayText: Text {
        property var value
        height: Theme.playHeight
        verticalAlignment: Text.AlignVCenter
        text: value || ""
        color: Theme.inkOnLight
        font.family: Theme.fontUi; font.pixelSize: Theme.playLabelSize; font.weight: Font.DemiBold
    }

    Column {
        id: column
        width: parent.width
        spacing: Theme.homeActionsTop

        SwapBox {
            id: titleBox
            width: parent.width
            height: currentItem ? currentItem.height : 0
            key: root.title + "\n" + root.meta.join("·") + root.pegi + root.updateNote
            value: ({ title: root.title, meta: root.updateNote !== "" ? [root.updateNote] : root.meta, pegi: root.pegi })
            direction: root.direction
            axis: root.axis
            animated: root.animated
            distance: root.axis === "x" ? Theme.categorySlide : Theme.homeTitleTravel
            duration: root.fast ? Theme.homeTitleFast : Theme.homeTitleMove
            exitDuration: root.fast ? Theme.homeTitleFast : Theme.homeTitleMove
            enterCurve: Theme.curveMain; exitCurve: Theme.curveMain
            blur: Theme.homeTitleBlur

            TitleAndMeta {}
            TitleAndMeta {}
        }

        // --- Boutons ---
        Row {
            id: actions
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.homeButtonsGap
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
            down: root.held || root.pressed || root.playHeld || playMouse.pressed
            hovered: playMouse.containsMouse
            hoverScale: Theme.hoverScale

            Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.ink }
            Row {
                id: playRow
                x: Theme.playPadLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.playGap
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.playGlyphSize; height: width
                    ButtonGlyph {
                        anchors.centerIn: parent
                        label: "A"
                        size: Theme.playGlyphSize
                        color: Theme.inkOnLight
                        ink: Theme.ink
                        fontSize: Theme.playGlyphFontSize
                        opacity: root.waking ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: Theme.hostLayerFade } }
                    }
                    // Réveil du PC : une roue dans le rond noir, à la place du A.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.inkOnLight
                        opacity: root.waking ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.hostLayerFade } }
                        LoaderRing {
                            anchors.centerIn: parent
                            width: Theme.heroWakeSpinner
                            stroke: Theme.heroWakeStroke
                            track: Theme.heroWakeTrack
                            color: Theme.ink
                            arc: Theme.hostSpinnerArc
                            period: Theme.hostSpinnerSpin
                            spinning: parent.visible
                        }
                    }
                }
                // Le libellé : au lancement, il cède la place à « Lancement… » en glissant,
                // et le bouton s'élargit pour le contenir.
                SwapBox {
                    id: playText
                    readonly property string text: root.waking && !root.pressed ? qsTr("Réveil du PC…")
                        : root.playLabel !== "" ? root.playLabel
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
            HoverArea {
                id: playMouse
                anchors.fill: parent
                onPointed: if (root.activeFocus && root.selected !== 0) root.choose(0)
                onClicked: root.playRequested()
            }
        }

        // Quitter la partie : A (ou le clic) tenu jusqu'au bout.
        Pressable {
            id: quitButton
            visible: root.running
            // (assez large pour la coche et « Partie terminée »)
            width: Math.max(quitLabel.implicitWidth, quitFill.doneWidth) + 2 * Theme.quitPad
            height: Theme.playHeight
            down: (root.quitHeld || quitMouse.pressed) && !quitFill.done
            downScale: Theme.quitPressScale
            hovered: quitMouse.containsMouse && !quitFill.done
            hoverScale: Theme.hoverScale

            Item {
                anchors.fill: parent
                scale: quitFill.bounce          // plein : tout le bouton rebondit, anneau compris
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: Theme.quitBorderWidth
                    border.color: quitMouse.containsMouse ? Theme.ink3 : Theme.quitBorder
                    border.pixelAligned: false
                    Behavior on border.color { ColorAnimation { duration: Theme.hoverFade } }
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
            HoverArea {
                id: quitMouse
                anchors.fill: parent
                onPointed: if (root.activeFocus && root.selected !== 1) root.choose(1)
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

        // Options : bouton de verre, glyphe cerclé.
        Pressable {
            id: optionsButton
            visible: !root.running
            width: Theme.playPadLeft + optionsRow.width + Theme.optionsPadRight
            height: Theme.playHeight
            down: optionsMouse.pressed
            hovered: optionsMouse.containsMouse
            hoverScale: Theme.hoverScale
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.glassRaised
                border.color: Theme.hairlineStrong
            }
            Row {
                id: optionsRow
                x: Theme.playPadLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.playGap
                ButtonGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Y"
                    size: Theme.optionsGlyphSize
                    ink: Theme.optionsGlyphInk
                    fontSize: Theme.optionsGlyphFontSize
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Options")
                    color: Theme.ink
                    font.family: Theme.fontUi; font.pixelSize: Theme.optionsLabelSize; font.weight: Font.DemiBold
                }
            }
            HoverArea { id: optionsMouse; anchors.fill: parent; onClicked: root.optionsRequested() }
        }
        }
    }
}
