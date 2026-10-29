import QtQuick
import QtQuick.Effects

// Cadre du lancement et du retour d'un jeu (MotionLancement, MotionQuitter) : la jaquette du
// carrousel (`origin`, sur le canevas) qui grandit jusqu'au plein écran (`grow` de 0 à 1, coins
// de radiusCover à 0), et l'image du jeu qui la remplace (`art` de 0 à 1), assombrie (`dim`),
// floutée (`blur`, en px ; rendu GPU seulement), qui dérive lentement (`drift`). Sans origine,
// il est plein écran. Remplit le canevas de son parent. Aucune dépendance Moonlight.
Item {
    id: root

    property rect origin: Qt.rect(0, 0, 0, 0)
    property real grow: 1
    property url thumbnail
    property url image
    property real art: 1
    property real dim: Theme.launchDim
    property real blur: 0
    property bool drift: false

    readonly property bool fromThumb: origin.width > 0
    readonly property real g: fromThumb ? grow : 1
    readonly property real radius: Theme.radiusCover * (1 - g)

    x: origin.x * (1 - g)
    y: origin.y * (1 - g)
    width: origin.width + (parent.width - origin.width) * g
    height: origin.height + (parent.height - origin.height) * g

    // Coins arrondis tant qu'il n'est pas plein écran.
    layer.enabled: radius > 0.5 && GraphicsInfo.api !== GraphicsInfo.Software
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: roundMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
    Item {
        id: roundMask
        width: root.width; height: root.height
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: root.radius; antialiasing: true }
    }

    Rectangle { anchors.fill: parent; color: Theme.background; clip: true

        Image {
            anchors.fill: parent
            visible: root.fromThumb && root.art < 1
            opacity: 1 - root.art
            source: root.thumbnail
            fillMode: Image.PreserveAspectCrop
            asynchronous: false         // déjà en cache : la jaquette est à l'écran
            sourceSize.height: Math.round(Theme.coverSlots[0][1] * Math.max(1, Theme.scale) * 1.5)
        }

        Item {
            anchors.fill: parent
            opacity: root.art
            visible: opacity > 0

            Image {
                id: picture
                // (à la taille de l'écran, pas du cadre qui grandit : elle ne se recharge pas en route)
                width: root.parent.width; height: root.parent.height
                x: (parent.width - width) / 2; y: (parent.height - height) / 2
                source: root.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.height: Math.round(Theme.canvasHeight * Theme.scale)
                property real t: 0
                scale: Theme.launchDriftFrom + (Theme.launchDriftTo - Theme.launchDriftFrom) * t
                transform: Translate { x: Theme.launchDriftShift.x * picture.t; y: Theme.launchDriftShift.y * picture.t }
                SequentialAnimation on t {
                    running: root.drift && !Theme.reducedMotion && root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: Theme.launchDrift; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: Theme.launchDrift; easing.type: Easing.InOutSine }
                }
                layer.enabled: root.blur > 0.5 && GraphicsInfo.api !== GraphicsInfo.Software
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 64
                    blur: Math.min(1, root.blur / 64)
                }
            }
            Rectangle { anchors.fill: parent; color: Theme.background; opacity: root.dim }
        }
    }
}
