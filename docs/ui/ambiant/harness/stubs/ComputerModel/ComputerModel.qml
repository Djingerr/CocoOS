import QtQuick

// Faux ComputerModel : un seul PC, en ligne, appairé et réveillable (adresse MAC
// connue). `wakes` compte les réveils demandés.
ListModel {
    property int wakes: 0
    signal pairingCompleted(var error)

    function initialize(manager) {
        append({ name: "Djinger", online: true, paired: true, statusUnknown: false, wakeable: true })
    }
    function generatePinString() { return "1234" }
    function pairComputer(index, pin) {}
    function deleteComputer(index) { remove(index) }
    function wakeComputer(index) { wakes++ }
}
