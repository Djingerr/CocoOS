import QtQuick
import "../../../../app/gui/console"
import "Mock.js" as Mock

// Vue de contrôle du harnais : les jeux du mock et leurs jaquettes de remplacement, pour
// vérifier que données et images arrivent. Les écrans CocoOS viendront s'ajouter à côté.
//   ./shot.sh /tmp/a.png view=LibraryDemo
Item {
    property var args: ({})
    readonly property var games: Mock.games(Mock.load(Qt.resolvedUrl("../mock/library.mock.json")),
                                            Qt.resolvedUrl("art/"))

    Grid {
        anchors.centerIn: parent
        columns: 5
        spacing: Theme.space5
        Repeater {
            model: games
            Column {
                spacing: Theme.space2
                Rectangle {
                    width: 120; height: 170; radius: Theme.radiusCover
                    color: Theme.glassGroup
                    clip: true
                    Image { anchors.fill: parent; source: modelData.cover; fillMode: Image.PreserveAspectCrop }
                }
                Text {
                    width: 120
                    text: modelData.name
                    elide: Text.ElideRight
                    color: Theme.ink2
                    font.family: "Sora"
                    font.pixelSize: Theme.textCaption.size
                }
            }
        }
    }
}
