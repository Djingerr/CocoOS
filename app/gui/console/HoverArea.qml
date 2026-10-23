import QtQuick
import "Pointer.js" as Pointer

// Zone de clic qui suit aussi la souris : `containsMouse` (le pointeur est dessus, pour
// l'effet de survol) et pointed() quand il y bouge VRAIMENT (cf. Pointer.js) : c'est là
// qu'une liste déplace sa sélection. Curseur en main. Aucune dépendance Moonlight.
MouseArea {
    id: area
    signal pointed()
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (Pointer.moved(area, mouseX, mouseY)) pointed()
    onPositionChanged: function(mouse) { if (Pointer.moved(area, mouse.x, mouse.y)) pointed() }
}
