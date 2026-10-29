import QtQuick
import QtQuick.Effects

// État « PC hors ligne » de l'accueil CocoOS (EtatHorsLigne) : par-dessus le carrousel grisé,
// un disque de verre et l'écran barré, « PC-Salon est hors ligne », « Votre bibliothèque reste
// consultable. Réveillez le PC pour jouer. », A Réveiller le PC / Y Choisir un autre PC, et la
// légende en bas. Présentation pure : A, Y et ≡ arrivent par ConsoleHome ; ici, la souris.
Item {
    id: root

    property string hostName
    property bool pressing: false        // A enfoncé : « Réveiller le PC » s'écrase
    signal wakeRequested()
    signal pickRequested()
    signal networkRequested()

    function refuse() { wake.refuse() }

    // L'écran barré, dans un disque de verre, sur la jaquette centrale.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.offlineIconTop
        width: Theme.offlineIconDisc; height: width; radius: width / 2
        color: Theme.glassDialog
        border.color: Theme.hairline
        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && !Theme.reducedMotion
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.offlineShadow
            shadowVerticalOffset: Theme.offlineShadowY
            shadowBlur: 1
        }
        Image {
            anchors.centerIn: parent
            width: Theme.offlineIconSize.width; height: Theme.offlineIconSize.height
            source: "icons/pc-offline.svg"
            sourceSize: Qt.size(width * Math.max(1, Theme.scale) * 2, height * Math.max(1, Theme.scale) * 2)
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.offlineTitleTop
        spacing: Theme.offlineGap

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("%1 est hors ligne").arg(root.hostName)
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.offlineTitleSize; font.weight: Font.DemiBold
            font.letterSpacing: -0.03 * Theme.offlineTitleSize
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Votre bibliothèque reste consultable. Réveillez le PC pour jouer.")
            color: Theme.ink2
            font.family: Theme.fontUi; font.pixelSize: Theme.offlineTextSize; font.weight: Font.Medium
        }
        Item { width: 1; height: Theme.offlineButtonsTop - Theme.offlineGap }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.offlineButtonsGap
            PillButton {
                id: wake
                primary: true; glyph: "A"; label: qsTr("Réveiller le PC")
                held: root.pressing
                onClicked: root.wakeRequested()
            }
            PillButton {
                glyph: "Y"; label: qsTr("Choisir un autre PC")
                labelSize: Theme.offlineSecondarySize
                onClicked: root.pickRequested()
            }
        }
    }

    ControllerLegend {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.canvasHeight - Theme.legendBottomCoco - height
        spacing: Theme.offlineLegendGap
        textSize: Theme.legendSizeCoco
        glyphGap: Theme.legendGlyphGapCoco
        hints: [ { glyph: "A", label: qsTr("Réveiller") },
                 { glyph: "Y", label: qsTr("Autre PC") },
                 { glyph: "≡", label: qsTr("Réglages réseau") } ]
        onTriggered: function(glyph) {
            if (glyph === "A") root.wakeRequested()
            else if (glyph === "Y") root.pickRequested()
        }
    }
}
