import QtQuick
import QtQuick.Effects

// Mise à jour du système (MotionMiseAJour) : le O de « CocoOS » sert de barre de progression,
// « Mise à jour vers CocoOS 1.2 · Installation · 42 % » ; puis « Mise à jour installée ·
// Redémarrage… », la scène s'efface ; au retour, « CocoOS 1.2 est installé ». Présentation
// pure : l'appelant (un futur service de mise à jour, Q16 ; le harnais d'ici là) donne la
// version, l'avancement et l'étape. Sur un canevas de 800 de haut.
Item {
    id: root

    property string version: ""          // « CocoOS 1.2 »
    property real progress: 0            // 0 à 1
    property string phase: ""            // "installing", "restarting", "installed" ; "" : absent

    readonly property bool shown: phase !== ""
    visible: scene.opacity > 0 || shown

    Rectangle { anchors.fill: parent; color: Theme.background; visible: root.shown || scene.opacity > 0 }

    Item {
        id: scene
        width: root.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.shown ? Theme.updateIn : Theme.updateOut } }

        RingLogo {
            id: logo
            width: parent.width
            height: 2 * Theme.shutdownWordY
            fill: root.phase === "installed" ? 1 : root.progress
            glow: root.phase === "restarting" || root.phase === "installed" ? Theme.updateGlowHigh : Theme.updateGlowLow
            Behavior on fill { enabled: root.phase === "installing"; NumberAnimation { duration: Theme.updateStep } }
        }

        // Les trois messages, en fondu enchaîné (le nouveau monte de 10 px).
        Repeater {
            model: [
                { key: "installing", title: qsTr("Mise à jour vers %1").arg(root.version),
                  sub: qsTr("Installation · %1 %").arg(Math.round(root.progress * 100)),
                  note: qsTr("Ne débranchez pas et n'éteignez pas la console") },
                { key: "restarting", title: qsTr("Mise à jour installée"), sub: qsTr("Redémarrage…"), note: "" },
                { key: "installed", title: qsTr("%1 est installé").arg(root.version), sub: qsTr("Votre console est à jour"), note: "" }
            ]
            Column {
                id: message
                required property var modelData
                required property int index
                readonly property int current: ["installing", "restarting", "installed"].indexOf(root.phase)
                readonly property bool on: message.index === current
                width: parent.width
                y: Theme.updateTextTop + (on || Theme.reducedMotion ? 0 : message.index < current ? -Theme.updateShift : Theme.updateShift)
                spacing: Theme.updateTextGap
                opacity: on ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.updateTextFade } }
                Behavior on y { NumberAnimation { duration: Theme.updateTextMove; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMain } }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: message.modelData.title
                    color: Theme.ink
                    font.family: Theme.fontUi; font.pixelSize: Theme.updateTitleSize; font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: message.modelData.sub
                    color: Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: Theme.updateSubSize; font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: Theme.updateNoteTop
                    visible: text !== ""
                    text: message.modelData.note
                    color: Theme.updateNoteInk
                    font.family: Theme.fontUi; font.pixelSize: Theme.updateNoteSize; font.weight: Font.Medium
                }
            }
        }
    }
}
