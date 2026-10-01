import QtQuick

// Faux ComputerModel : un seul PC, en ligne et appairé.
ListModel {
    signal pairingCompleted(var error)

    function initialize(manager) {
        append({ name: "Djinger", online: true, paired: true, statusUnknown: false })
    }
    function generatePinString() { return "1234" }
    function pairComputer(index, pin) {}
    function deleteComputer(index) { remove(index) }
}
