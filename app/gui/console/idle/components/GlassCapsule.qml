import QtQuick
import ".."

// Capsule de verre de l'écran 12 (SPEC §3) : 76 px de haut, rayon 38, remplissage et
// contour translucides, 8 px de marge intérieure. Le flou d'arrière-plan de la maquette est
// remplacé par le simple remplissage (la lueur derrière est déjà floue).
Item {
    id: root

    default property alias content: row.data

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 76

    Rectangle {
        anchors.fill: parent
        radius: IdleTheme.radiusCapsule
        color: IdleTheme.glassFill
    }
    // Contour par-dessus le remplissage (une bordure de Rectangle le remplacerait).
    Rectangle {
        anchors.fill: parent
        radius: IdleTheme.radiusCapsule
        color: "transparent"
        border.width: 1
        border.color: IdleTheme.glassStroke
    }
    Row {
        id: row
        x: 8
        anchors.verticalCenter: parent.verticalCenter
    }
}
