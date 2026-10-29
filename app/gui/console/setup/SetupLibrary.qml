import QtQuick
import QtQuick.Effects
import ".."

// Bibliothèque de la première configuration (SetupBibliotheque) : à gauche les jaquettes qui
// arrivent (18 places, les autres en attente, qui scintillent) et la progression « 132 / 214 » ;
// à droite les préférences (une SettingsList, `rows`) et « ≡ Commencer ». Les préférences
// prennent la manette ; Start (≡) ou un clic sur le bouton : `started`. Sur le canevas ;
// aucune dépendance Moonlight.
FocusScope {
    id: root

    property var covers: []              // images des premières jaquettes (url)
    property int done: 0                 // jaquettes et informations reçues…
    property int total: 0                // …sur tant
    property alias rows: prefs.rows
    property alias list: prefs
    property bool pressing: false        // ≡ enfoncé : le bouton s'écrase

    signal changed(string key, int index)
    signal started()

    // Les jaquettes.
    Item {
        x: Theme.libGridLeft
        y: Theme.libGridTop
        Repeater {
            model: Theme.libTiles
            Item {
                id: tile
                required property int index
                readonly property url art: root.covers[index] || ""
                x: (index % Theme.libColumns) * (Theme.libTile.width + Theme.libTileGapX)
                y: Math.floor(index / Theme.libColumns) * (Theme.libTile.height + Theme.libTileGapY)
                width: Theme.libTile.width; height: Theme.libTile.height
                // En attente : une plaque, qu'un reflet balaie.
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.libTileRadius
                    color: Theme.libSkeleton
                    clip: true
                    opacity: 1 - image.opacity
                    Rectangle {
                        id: shine
                        width: parent.width / 2; height: parent.height
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.5; color: Theme.libShimmer }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        SequentialAnimation on x {
                            running: tile.visible && image.status !== Image.Ready && !Theme.reducedMotion
                            loops: Animation.Infinite
                            PauseAnimation { duration: (tile.index % Theme.libColumns) * Theme.libShimmerStagger }
                            NumberAnimation {
                                from: -1.2 * shine.width; to: tile.width + 0.2 * shine.width
                                duration: Theme.libShimmerSweep; easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
                Image {
                    id: image
                    anchors.fill: parent
                    source: tile.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * Theme.scale * 2, height * Theme.scale * 2)
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.libTileFade } }
                    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software && GraphicsInfo.api !== GraphicsInfo.Unknown
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: mask }
                }
                Rectangle {
                    id: mask
                    anchors.fill: parent
                    radius: Theme.libTileRadius
                    visible: false
                    layer.enabled: true
                }
            }
        }
    }

    // La progression.
    Column {
        x: Theme.libGridLeft
        y: Theme.libProgressTop
        width: Theme.libProgressWidth
        spacing: Theme.libBarGap
        visible: root.total > 0
        Item {
            width: parent.width; height: label.height
            Text {
                id: label
                text: qsTr("Jaquettes et informations")
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.libProgressSize; font.weight: Font.Medium
            }
            Text {
                anchors.right: parent.right
                text: qsTr("%1 / %2").arg(root.done).arg(root.total)
                color: Theme.ink2
                font.family: Theme.fontUi; font.pixelSize: Theme.libProgressSize; font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }
        Rectangle {
            width: parent.width; height: Theme.libBar; radius: height / 2
            color: Theme.libBarTrack
            Rectangle {
                height: parent.height; radius: parent.radius
                width: parent.width * (root.total > 0 ? Math.min(1, root.done / root.total) : 0)
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.libBarMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain } }
            }
        }
    }

    // Les préférences, et Commencer.
    SettingsList {
        id: prefs
        x: Theme.libPrefsLeft
        y: Theme.libGridTop
        width: Theme.libPrefsWidth; height: contentHeight
        metrics: Theme.listSettings
        focus: true
        onChanged: function(key, index) { root.changed(key, index) }
    }
    PillButton {
        x: Theme.libPrefsLeft + Theme.libPrefsWidth - width
        y: Theme.libGridTop + prefs.contentHeight + Theme.libStartGap
        primary: true
        glyph: "≡"
        label: qsTr("Commencer")
        held: root.pressing
        onClicked: root.started()
    }
}
