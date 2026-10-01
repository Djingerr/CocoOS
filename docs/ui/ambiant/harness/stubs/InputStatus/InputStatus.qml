pragma Singleton
import QtQuick

// Faux InputStatus : pas de manette par défaut. Les tests émettent ses signaux à
// la main (activity, homePressed) et posent `homeExit` pour simuler le retour d'un
// jeu par le bouton Home.
QtObject {
    property string layout: ""
    property int controllerBattery: -1
    property bool homeExit: false

    signal activity()
    signal homePressed()

    function takeHomeExit() {
        var exit = homeExit
        homeExit = false
        return exit
    }
}
