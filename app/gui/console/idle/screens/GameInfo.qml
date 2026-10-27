import QtQuick
import ".."
import "../components"

// Titre et méta d'un jeu (SPEC §2.3) : « Minecraft », « Mojang Studios · Bac à sable ».
// Les entrées sont décalées (titre, puis méta) ; la colonne les empile.
Column {
    id: root

    property var game: ({})
    property bool entryStarted: true

    width: 660

    EntryReveal {
        started: root.entryStarted
        delay: IdleTheme.entryDelays.title
        width: parent.width; height: title.implicitHeight
        IdleText {
            id: title
            width: parent.width
            text: root.game ? root.game.title || "" : ""
            textStyle: IdleTheme.title
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
    Item { width: 1; height: 8 }
    EntryReveal {
        started: root.entryStarted
        delay: IdleTheme.entryDelays.meta
        width: parent.width; height: meta.implicitHeight
        IdleText {
            id: meta
            width: parent.width
            text: root.game ? [root.game.publisher, root.game.genre].filter(function(s) { return !!s }).join(" · ") : ""
            textStyle: IdleTheme.meta
            color: IdleTheme.textSecondary
            elide: Text.ElideRight
        }
    }
}
