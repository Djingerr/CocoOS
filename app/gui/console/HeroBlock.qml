import QtQuick

// Bloc héros de l'accueil : méta (source | dernière session), titre du jeu,
// sous-titre (temps de jeu, mise à jour) et actions (Jouer, Options, Épingler).
// Tout est posé à partir du BAS du bloc : un titre sur deux lignes le fait
// grandir vers le haut, sans déplacer les actions. Quand le jeu change, chaque
// champ se remplace en glissant (SwapBox). Aucune dépendance Moonlight.
Item {
    id: root

    property string title
    property string source           // « Steam », « GOG »… ; vide = masqué
    property string lastPlayed       // « Hier, 23:40 » ; vide = masqué
    property string playtime         // « 412 h de jeu » ; vide = masqué
    property string updateNote       // mise à jour en attente côté PC ; vide = masqué
    property bool running: false     // le jeu tourne déjà : « Reprendre »
    property bool favorite: false    // épinglé en tête de l'étagère : X le détache
    // Sens du dernier déplacement dans la liste (+1 vers la droite) : les textes
    // glissent dans ce sens. `animated` à false : ils changent sans transition.
    property int direction: 1
    property bool animated: true
    property bool pressed: false     // le bouton Jouer s'enfonce (lancement)

    signal playRequested()
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
        duration: Theme.heroMetaSwap; delay: Theme.heroMetaSwapDelay

        MetaLine {}
        MetaLine {}
    }

    // --- Titre ---
    component TitleLines: Item {
        id: lines
        property string value
        readonly property int lineCount: Math.max(1, label.lineCount)

        width: Theme.heroWidth
        height: root.titleHeight(lineCount)

        FontMetrics { id: metrics; font: label.font }
        Text {
            id: label
            // L'interligne (1.04) est plus serré que la hauteur naturelle de la
            // police : on remonte le texte de la moitié de l'écart, comme en CSS.
            y: (Theme.heroTitleLineHeight - metrics.height) / 2
            width: parent.width
            text: lines.value
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
        value: root.title
        direction: root.direction
        animated: root.animated
        duration: Theme.heroTitleSwap; delay: Theme.heroTitleSwapDelay

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
        duration: Theme.heroSubSwap; delay: Theme.heroSubSwapDelay

        SubLine {}
        SubLine {}
    }

    // --- Actions ---
    Row {
        id: actions
        anchors.bottom: parent.bottom
        spacing: Theme.heroActionsGap

        Rectangle {
            width: Theme.playPadLeft + playRow.width + Theme.playPadRight
            height: Theme.playHeight
            radius: height / 2
            color: Theme.accent
            scale: root.pressed ? Theme.launchPressScale : 1
            Behavior on scale { NumberAnimation { duration: Theme.launchPress; easing.type: Theme.easeOut } }

            Row {
                id: playRow
                x: Theme.playPadLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.playGap
                ButtonGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "A"
                    width: Theme.playGlyphSize
                    color: Theme.inkOnAccent
                    ink: Theme.accent
                    fontSize: Theme.playGlyphFontSize
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.running ? qsTr("Reprendre") : qsTr("Jouer")
                    color: Theme.inkOnAccent
                    font.family: Theme.fontUi; font.pixelSize: Theme.playLabelSize; font.weight: Font.DemiBold
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.playRequested() }
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
