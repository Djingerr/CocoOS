pragma Singleton
import QtQuick

// Faux AmbientColor : une teinte stable tirée du nom de l'image, tout de suite
// (le vrai la calcule à part, sur l'image elle-même).
QtObject {
    property int revision: 0
    property color none                 // jamais assignée : couleur invalide

    function colorFor(image) {
        var name = image.toString()
        if (name === "") return none
        var h = 0
        for (var i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 360
        return Qt.hsva(h / 360, 0.6, 0.88, 1)
    }
}
