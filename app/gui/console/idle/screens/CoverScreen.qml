pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../components"

// Structure commune des écrans 09 à 11 (SPEC §2) : fond flou de la jaquette, puis, dans le
// groupe qui dérive, l'heure et la batterie, la jaquette, la colonne de texte (`column`,
// remplie par l'écran) et l'indication du bas.
Item {
    id: root

    property IdleStatus status
    property var game: ({})
    property bool drift: true
    property bool animated: true
    // Faux : tout est en place mais invisible, l'entrée attend (fondu enchaîné entre états).
    property bool entryStarted: true
    property string hintAction
    property real columnTop: 170
    default property alias column: column.data

    width: IdleTheme.reference.width
    height: IdleTheme.reference.height

    // --- Fond ---
    BlurredBackdrop {
        id: backdrop
        property real pan: 0                    // backdropPan, 60 s aller-retour
        saturation: IdleTheme.backdropSaturation
        vignette: true
        layerScale: 1.25 + 0.09 * pan
        layerShift: Qt.point(-30 * pan, 16 * pan)
        SequentialAnimation on pan {
            running: root.animated
            loops: Animation.Infinite
            NumberAnimation {
                from: 0; to: 1; duration: IdleTheme.backdropPanPeriod
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
            }
            NumberAnimation {
                from: 1; to: 0; duration: IdleTheme.backdropPanPeriod
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
            }
        }
        Image {
            anchors.fill: parent
            source: root.game && root.game.coverUrl ? root.game.coverUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        }
    }

    DriftGroup {
        running: root.animated && root.drift

        // --- Heure et batterie ---
        EntryReveal {
            started: root.entryStarted
            delay: IdleTheme.entryDelays.topRightClock
            anchors.right: parent.right
            anchors.rightMargin: 56
            y: 36
            width: clock.implicitWidth; height: clock.implicitHeight
            TopRightClock {
                id: clock
                now: root.status.now
                batteryPercent: root.status.battery.percent
            }
        }

        // --- Jaquette : l'enveloppe couvre l'ombre et le reflet au sol (flou d'entrée) ---
        EntryReveal {
            id: coverReveal
            readonly property int margin: 170
            started: root.entryStarted
            delay: IdleTheme.entryDelays.cover
            duration: IdleTheme.entryDurations.cover
            x: 112 - margin; y: 104 - margin
            width: card.width + 2 * margin
            height: 2 * card.height + IdleTheme.reflectionGap + 2 * margin
            CoverCard {
                id: card
                x: coverReveal.margin; y: coverReveal.margin
                animated: root.animated
                source: root.game && root.game.coverUrl ? root.game.coverUrl : ""
                // Libellé seulement sur la jaquette de test (TODO(HostCompanion) : vraies jaquettes).
                label: source.toString().indexOf("placeholder_cover_600x848.png") >= 0
                       ? qsTr("Jaquette %1 · 600 × 848").arg(root.game.title) : ""
            }
        }

        // --- Colonne de texte ---
        Column {
            id: column
            x: 520; y: root.columnTop
            width: 660
        }

        // --- Indication du bas ---
        EntryReveal {
            started: root.entryStarted
            delay: IdleTheme.entryDelays.keyHint
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 44 - height
            width: hint.implicitWidth; height: hint.implicitHeight
            KeyHint { id: hint; action: root.hintAction }
        }
    }
}
