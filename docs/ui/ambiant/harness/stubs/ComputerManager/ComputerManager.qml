pragma Singleton
import QtQuick

// Faux ComputerManager : ConsoleHome le passe aux modèles et écoute la fin d'un
// « quitter le jeu » ; la première configuration y ajoute un PC par son adresse.
QtObject {
    signal quitAppCompleted(var error)
    signal computerAddCompleted(var success, var detectedPortBlocking)
    property var added: []              // adresses demandées (tests)
    function addNewHostManually(address) { added = added.concat([address]) }
    function startPolling() {}
}
