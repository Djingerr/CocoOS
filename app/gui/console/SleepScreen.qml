import QtQuick

// Veille de l'écran (« .sleep » du prototype) : tout passe au noir, une phrase
// discrète apparaît puis s'efface à son tour (dalle OLED : rien de fixe ne doit
// rester allumé). Une touche ou un clic réveille ; cette première action n'atteint
// pas l'écran du dessous. Au réveil, elle disparaît d'un coup : la sortie de veille
// de l'animation de démarrage (noir, puis l'accueil qui rentre) prend le relais.
// Aucune dépendance Moonlight.
FocusScope {
    id: root

    property bool asleep: false
    signal woke()

    function sleep() {
        if (asleep) return
        asleep = true
        forceActiveFocus()
        hint.shown = false
        hintIn.restart()
        Sounds.play("close")
    }
    function wake() {
        if (!asleep) return
        asleep = false
        hintIn.stop(); hintOut.stop()
        woke()
    }

    visible: opacity > 0
    opacity: asleep ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: root.asleep ? Theme.sleepFade : 0 } }

    Rectangle { anchors.fill: parent; color: Theme.background }

    Text {
        id: hint
        property bool shown: false
        anchors.centerIn: parent
        text: qsTr("Veille. Appuyez sur une touche pour réveiller la console.")
        color: Theme.ink3
        font.family: Theme.fontUi; font.pixelSize: Theme.sleepTextSize * Theme.scale
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.sleepTextFade } }
    }
    Timer { id: hintIn; interval: Theme.sleepTextDelay; onTriggered: { hint.shown = true; hintOut.restart() } }
    Timer { id: hintOut; interval: Theme.sleepTextHold; onTriggered: hint.shown = false }

    Keys.onPressed: function(event) {
        event.accepted = true
        if (!event.isAutoRepeat) root.wake()
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.asleep
        onPressed: root.wake()
    }
}
