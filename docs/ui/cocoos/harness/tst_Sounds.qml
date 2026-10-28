import QtQuick
import QtTest
import "../../../../app/gui/console"

// Pack de sons CocoOS : chaque son du manifeste et chaque ancien nom (alias) se résout
// vers un fichier présent dans app/gui/console/sounds/ et déclaré dans console.qrc.
// Lit des fichiers locaux : lancer avec QML_XHR_ALLOW_FILE_READ=1.
TestCase {
    name: "Sounds"

    readonly property url consoleDir: Qt.resolvedUrl("../../../../app/gui/console/")

    function read(url) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url, false)
        xhr.send()
        return xhr.responseText
    }
    function manifestIds() {
        return JSON.parse(read(Qt.resolvedUrl("../sounds/manifest.json"))).sounds.map(function(s) { return s.id })
    }
    function exists(name) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", consoleDir + "sounds/" + name + ".wav", false)
        xhr.responseType = "arraybuffer"
        xhr.send()
        return xhr.response !== null && xhr.response.byteLength > 44   // plus qu'un en-tête WAV
    }
    // Ce que SoundBank joue pour un nom du pack : nav_move tourne sur trois variantes.
    function files(name) {
        return name === "nav_move" ? ["nav_move_1", "nav_move_2", "nav_move_3"] : [name]
    }

    function test_manifestFilesExistAndAreInTheQrc() {
        var qrc = read(consoleDir + "console.qrc")
        var ids = manifestIds()
        compare(ids.length, 68)
        ids.forEach(function(id) {
            verify(exists(id), id)
            verify(qrc.indexOf("<file>sounds/" + id + ".wav</file>") >= 0, id + " absent de console.qrc")
        })
    }

    function test_aliasesResolveToFiles() {
        var ids = manifestIds()
        Object.keys(Sounds.aliases).forEach(function(old) {
            var name = Sounds.resolve(old)
            if (name === "")
                return                                  // boot-close : plus de son (SPEC §2)
            files(name).forEach(function(f) { verify(ids.indexOf(f) >= 0, old + " → " + f) })
        })
        compare(Sounds.resolve("select"), "select")     // un nom du pack reste tel quel
    }

    // Les sons ponctuels et connecting_loop sont préchargés, les ambiances (amb_*) lues à
    // la demande : à eux trois, tout le manifeste.
    function test_soundBankCoversTheManifest() {
        var bank = Qt.createComponent(consoleDir + "SoundBank.qml").createObject(null)
        verify(bank, "SoundBank (QtMultimedia) ne se charge pas")
        var manifest = JSON.parse(read(Qt.resolvedUrl("../sounds/manifest.json"))).sounds
        manifest.forEach(function(s) {
            var ambiance = s.id.indexOf("amb_") === 0
            compare(bank.oneShots.indexOf(s.id) >= 0, !s.loop, s.id)
            compare(bank.loops.indexOf(s.id) >= 0, s.loop && !ambiance, s.id)
            verify(!ambiance || s.loop, s.id)
        })
        compare(bank.preloaded.length, manifest.filter(function(s) { return s.id.indexOf("amb_") !== 0 }).length)
        bank.destroy()
    }

    function test_playedEmitsThePackName() {
        var heard = []
        var record = function(name) { heard.push(name) }
        Sounds.played.connect(record)
        Sounds.play("edge")
        Sounds.play("boot-close")
        Sounds.play("nav_move")
        Sounds.played.disconnect(record)
        compare(heard, ["nav_edge", "nav_move"])
    }
}
