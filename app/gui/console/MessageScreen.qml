import QtQuick

// Écran de message, à la place du héros et de l'étagère de l'accueil : recherche du
// PC, chargement des jeux, appairage. Même ancrage et même titre que le bloc héros
// (posé par le bas : un titre sur deux lignes le fait grandir vers le haut), puis
// une explication, un code éventuel en grandes cases et une ligne d'état ; la
// légende des boutons en bas à gauche.
// Présentation pure, en pixels du canevas : à poser dans HomeScreen.stage.
FocusScope {
    id: root

    property bool shown: false
    property string title
    property string text                 // explication, sous le titre ; vide = masquée
    property string code                 // chiffres en grandes cases ; vide = pas de code
    property int codeFocus: -1           // case en cours de saisie (soulignée), -1 = aucune
    property string status               // ligne d'état ; vide = masquée
    property bool error: false           // la ligne d'état signale un échec
    property bool busy: false            // attente en cours : un segment parcourt la piste
    property var hints: []               // légende : [{ glyph, label }]

    anchors.fill: parent
    visible: shown || appear.opacity > 0

    // L'écran qui sort s'efface vite ; celui qui entre attend qu'il soit parti.
    Appear {
        id: appear
        anchors.fill: parent
        shown: root.shown
        delay: Theme.messageSwap
        hideDuration: Theme.messageSwap

        Column {
            x: Theme.margin
            y: Theme.heroBottom - height
            width: Theme.heroWidth

            Text {
                width: parent.width
                text: root.title
                color: Theme.ink
                wrapMode: Text.WordWrap
                maximumLineCount: Theme.heroTitleMaxLines
                elide: Text.ElideRight
                lineHeightMode: Text.FixedHeight
                lineHeight: Theme.heroTitleLineHeight
                font.family: Theme.fontUi; font.pixelSize: Theme.heroTitleSize; font.weight: Font.DemiBold
                font.letterSpacing: Theme.heroTitleSpacing
            }
            Text {
                width: parent.width
                topPadding: Theme.messageTextTop
                visible: root.text !== ""
                text: root.text
                color: Theme.heroSubColor
                wrapMode: Text.WordWrap
                lineHeightMode: Text.FixedHeight
                lineHeight: Theme.heroSubHeight
                font.family: Theme.fontUi; font.pixelSize: Theme.heroSubSize
            }

            Row {
                topPadding: Theme.messageBlockTop
                visible: root.code !== ""
                spacing: Theme.codeCellGap
                Repeater {
                    model: root.code.length
                    Rectangle {
                        readonly property bool focused: index === root.codeFocus
                        width: Theme.codeCellSize.width; height: Theme.codeCellSize.height
                        radius: Theme.codeCellRadius
                        color: focused ? Theme.codeCellFocusFill : Theme.codeCellFill
                        Text {
                            anchors.centerIn: parent
                            text: root.code.charAt(index)
                            color: root.codeFocus < 0 || parent.focused ? Theme.ink : Theme.ink2
                            font.family: Theme.fontMono; font.pixelSize: Theme.codeDigitSize; font.weight: Font.Medium
                        }
                        Rectangle {
                            visible: parent.focused
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                                      margins: Theme.codeUnderlineInset }
                            height: Theme.underlineHeight; radius: Theme.underlineRadius
                            color: Theme.accent
                        }
                    }
                }
            }

            Text {
                topPadding: Theme.messageBlockTop
                visible: root.status !== ""
                text: root.status
                color: root.error ? Theme.accent : Theme.ink2
                font.family: Theme.fontMono; font.pixelSize: Theme.launchStageSize
            }
            // La piste de l'écran de lancement, parcourue par un segment orange.
            Item {
                width: Theme.launchProgressWidth
                height: track.y + track.height
                visible: root.busy
                Rectangle {
                    id: track
                    y: root.status !== "" ? Theme.launchTrackTop : Theme.messageBlockTop
                    width: parent.width; height: Theme.launchTrackHeight
                    radius: height / 2
                    color: Theme.launchTrackColor
                    clip: true
                    Rectangle {
                        width: parent.width * Theme.waitBarSpan; height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        NumberAnimation on x {
                            from: -Theme.launchProgressWidth * Theme.waitBarSpan; to: Theme.launchProgressWidth
                            duration: Theme.waitBarSweep; easing.type: Easing.InOutCubic
                            loops: Animation.Infinite
                            running: root.busy && root.visible
                        }
                    }
                }
            }
        }

        ControllerLegend {
            x: Theme.margin
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.sheetPadBottom
            hints: root.hints
        }
    }
}
