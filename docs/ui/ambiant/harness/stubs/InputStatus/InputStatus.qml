pragma Singleton
import QtQuick

// Faux InputStatus : pas de manette par défaut. Les tests émettent ses signaux à
// la main (activity, homePressed, bumperPressed) et posent `streamExit` pour simuler
// le retour d'un jeu quitté par le menu en jeu ; `streamMenu` garde la dernière
// préparation de ce menu ([jeu, actions d'alimentation, glyphes]).
QtObject {
    property string layout: ""
    property int controllerBattery: -1
    property int controllerCount: 0
    property string streamExit: ""
    property var streamMenu: null

    signal activity()
    signal homePressed()
    signal bumperPressed(int direction)
    signal triggerPressed(int direction)

    function prepareStreamMenu(game, powerActions, buttonLayout) {
        streamMenu = [game, powerActions, buttonLayout]
    }
    property var feedbacks: []           // sons transmis aux vibrations (feedback)
    function feedback(sound) { feedbacks = feedbacks.concat([sound]) }
    function takeStreamExit() {
        var exit = streamExit
        streamExit = ""
        return exit
    }
}
