import QtQuick
import QtQuick.Shapes

// État « Aucun favori » de l'accueil CocoOS (EtatFavorisVide) : à la place du carrousel,
// quatre emplacements en pointillés en perspective, une étoile dans un disque de verre,
// le message et « RB Voir les jeux récents », l'aide en bas. Le fond est un dégradé sourd
// sous le vignettage, comme quand aucun jeu n'est là. Présentation pure : RB, LB et Y
// arrivent par les mêmes chemins que sur le carrousel (InputStatus, ConsoleHome).
Item {
    id: root

    signal recentRequested()           // le bouton (clic) : la catégorie Récents

    // Fond : dégradé sourd, vignettage plus fort (0,9).
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.emptyTop }
            GradientStop { position: 1; color: Theme.emptyBottom }
        }
    }
    Shape {
        // Vignettage radial : une ellipse au rapport de l'écran, centrée à 50 % 40 %.
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width / 2; centerY: root.height * 0.4
                focalX: centerX; focalY: centerY
                centerRadius: Math.hypot(root.width / 2, root.height * 0.6) * 1.08
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, Theme.vignetteIn) }
                GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, Theme.vignetteOutEmpty) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, Theme.vignetteOutEmpty) }
            }
            PathRectangle { width: root.width; height: root.height }
        }
    }

    // Les quatre emplacements vides, en perspective (perspective : 900px sur l'écran).
    function frame(x, y, w, h, deg) {
        var a = deg * Math.PI / 180, c = Math.cos(a), s = Math.sin(a)
        var ox = root.width / 2 - x, oy = root.height / 2 - y      // centre de la perspective, repère local
        var t = function(tx, ty) { return Qt.matrix4x4(1, 0, 0, tx, 0, 1, 0, ty, 0, 0, 1, 0, 0, 0, 0, 1) }
        var rotate = Qt.matrix4x4(c, 0, s, 0, 0, 1, 0, 0, -s, 0, c, 0, 0, 0, 0, 1)
        var perspective = Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, -1 / Theme.coverPerspective, 1)
        var m = t(ox, oy).times(perspective).times(t(-ox, -oy))
                .times(t(w / 2, h / 2)).times(rotate).times(t(-w / 2, -h / 2))
        // Sans profondeur (z = 0) : Qt Quick couperait ce qui sort de sa plage de z.
        return Qt.matrix4x4(m.m11, m.m12, m.m13, m.m14, m.m21, m.m22, m.m23, m.m24,
                            0, 0, 1, 0, m.m41, m.m42, m.m43, m.m44)
    }
    Repeater {
        model: Theme.emptySlots
        Shape {
            readonly property var slot: modelData     // [x depuis le centre, y, angle, opacité]
            x: root.width / 2 + slot[0]; y: slot[1]
            width: Theme.emptySlotSize.width; height: Theme.emptySlotSize.height
            opacity: slot[3]
            transform: Matrix4x4 { matrix: root.frame(x, y, width, height, slot[2]) }
            // (le CurveRenderer ne trace pas les pointillés)
            ShapePath {
                strokeColor: Theme.ink
                strokeWidth: Theme.emptySlotStroke
                strokeStyle: ShapePath.DashLine
                dashPattern: Theme.emptySlotDash
                fillColor: "transparent"
                PathRectangle { width: Theme.emptySlotSize.width; height: Theme.emptySlotSize.height; radius: Theme.radiusCover }
            }
        }
    }

    // Étoile dans un disque de verre.
    Rectangle {
        x: (root.width - width) / 2; y: Theme.emptyStarTop
        width: Theme.emptyStarDisk; height: width; radius: width / 2
        color: Theme.glassDialog
        border.color: Theme.hairlineStrong
        Shape {
            anchors.centerIn: parent
            width: 24; height: 24
            scale: Theme.emptyStarSize / 24
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.ink
                strokeWidth: 1.5
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M12 3.2l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.6l-5.2 2.7 1-5.8L3.5 9.4l5.9-.8z" }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.emptyTextTop
        spacing: Theme.homeMetaTop
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Aucun favori pour l’instant")
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.textTitleM.size; font.weight: Font.DemiBold
            font.letterSpacing: Theme.textTitleM.spacing
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.emptyTextWidth
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            // (« Vos favoris sont aussi enregistrés dans Playnite » : pas encore vrai, cf. next_steps.md.)
            text: qsTr("Sur la fiche d’un jeu, appuyez sur %1 pour l’ajouter ici.")
                  .arg("<font color='" + Theme.ink + "'><b>X</b></font>")
            color: Theme.ink2
            lineHeight: Theme.textBody.lineHeight
            font.family: Theme.fontUi; font.pixelSize: Theme.textBody.size; font.weight: Font.Medium
        }
        Item { width: 1; height: Theme.emptyButtonTop }
        Pressable {
            id: recent
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.playPadLeft + recentRow.width + Theme.emptyButtonPadRight
            height: Theme.playHeight
            down: recentMouse.pressed
            hovered: recentMouse.containsMouse
            hoverScale: Theme.hoverScale
            Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.glassRaised }
            Row {
                id: recentRow
                x: Theme.playPadLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.playGap
                ButtonGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "RB"
                    size: Theme.playGlyphSize
                    ink: Theme.optionsGlyphInk
                    fontSize: Theme.playGlyphFontSize
                    weight: Font.Bold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Voir les jeux récents")
                    color: Theme.ink
                    font.family: Theme.fontUi; font.pixelSize: Theme.emptyButtonSize; font.weight: Font.DemiBold
                }
            }
            HoverArea { id: recentMouse; anchors.fill: parent; onClicked: root.recentRequested() }
        }
    }

    // Aide : LB Tout · RB Récents · Y Options.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - Theme.emptyHelpBottom - height
        spacing: Theme.emptyHelpGap
        Repeater {
            model: [["LB", qsTr("Tout")], ["RB", qsTr("Récents")], ["Y", qsTr("Options")]]
            Row {
                spacing: Theme.helpInnerGap
                ButtonGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    label: modelData[0]
                    size: Theme.helpGlyphSize
                    ink: Theme.helpGlyphStroke
                    fontSize: Theme.emptyHelpGlyphSize
                    weight: Font.DemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[1]
                    color: Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: Theme.helpSize; font.weight: Font.Medium
                }
            }
        }
    }
}
