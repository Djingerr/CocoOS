pragma Singleton
import QtQuick

// Faux ComputerManager : ConsoleHome le passe aux modèles et écoute la fin d'un
// « quitter le jeu ».
QtObject {
    signal quitAppCompleted(var error)
}
