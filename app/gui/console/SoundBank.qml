import QtQuick
import QtMultimedia

// Les sons de l'interface (fichiers sounds/*.wav, produits par
// docs/ui/ambiant/harness/make-sounds.py à partir du prototype). Voir Sounds.qml.
// ponytail: QtMultimedia charge tout son moteur (FFmpeg, sondage VA-API) pour neuf
// petits sons. Si le démarrage en souffre sur la carte cible, les jouer par SDL
// (déjà lié à Moonlight) depuis un petit backend C++.
Item {
    id: bank

    readonly property var names: ["move", "edge", "select", "back", "open", "close", "tick", "launch", "ready"]
    property var effects: ({})

    function play(name) {
        var effect = effects[name]
        if (effect)
            effect.play()
    }

    Instantiator {
        model: bank.names
        delegate: SoundEffect {
            source: "sounds/" + modelData + ".wav"
            volume: Theme.soundVolume
        }
        onObjectAdded: function(index, object) { bank.effects[bank.names[index]] = object }
    }
}
