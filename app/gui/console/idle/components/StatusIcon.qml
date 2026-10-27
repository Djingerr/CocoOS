import QtQuick
import ".."

// Icône de l'écran de veille (assets/icons), à sa taille d'affichage dans les maquettes.
// Blanc #F5F5F7 : la couleur d'état (blanc à 78 %, 70 % dans la capsule) passe par l'opacité.
Image {
    id: root

    property string name          // "monitor", "signal", "wifi"
    property bool large: false    // taille de la capsule de l'écran 12

    readonly property var sizes: large ? { monitor: Qt.size(20, 18), wifi: Qt.size(20, 15) }
                                       : { monitor: Qt.size(17, 15), signal: Qt.size(15, 13), wifi: Qt.size(17, 12) }
    readonly property size iconSize: sizes[name] || Qt.size(0, 0)

    width: iconSize.width; height: iconSize.height
    source: name !== "" ? "../assets/icons/" + name + ".svg" : ""
    fillMode: Image.PreserveAspectFit
    sourceSize: Qt.size(width * 2 * IdleTheme.scale, height * 2 * IdleTheme.scale)
    opacity: large ? 0.7 : IdleTheme.textStatus.a
}
