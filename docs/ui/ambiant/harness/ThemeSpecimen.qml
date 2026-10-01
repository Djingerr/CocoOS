import QtQuick
import "../../../../app/gui/console"

// Planche de contrôle de Theme.qml : couleurs, et chaque style de texte du brief
// avec sa police embarquée. Les textes reprennent ceux du prototype (jeu n° 0)
// pour comparer formes et largeurs des glyphes à ../ref/home-0-minecraft.png.
Item {
    property var args: ({})

    Row {
        x: Theme.margin; y: 40; spacing: 16
        Repeater {
            model: [
                { name: "accent", c: Theme.accent }, { name: "inkOnAccent", c: Theme.inkOnAccent },
                { name: "ink", c: Theme.ink }, { name: "ink2", c: Theme.ink2 },
                { name: "ok", c: Theme.ok }, { name: "background", c: Theme.background }
            ]
            Column {
                spacing: 8
                Rectangle { width: 120; height: 56; radius: 8; color: modelData.c; border.color: Theme.ink2; border.width: 1 }
                Text { text: modelData.name + " " + modelData.c; color: Theme.ink2; font.family: Theme.fontUi; font.pixelSize: 12 }
            }
        }
    }

    Column {
        x: Theme.margin; y: 160; spacing: 18
        Repeater {
            model: [
                { label: "Sora 64 / 600, -1.8", t: "Minecraft", f: Theme.fontUi, s: 64, w: Font.DemiBold, ls: -1.8 },
                { label: "Sora 17 / 600", t: "Jouer", f: Theme.fontUi, s: 17, w: Font.DemiBold, ls: 0 },
                { label: "Sora 17 / 500", t: "21:30", f: Theme.fontUi, s: 17, w: Font.Medium, ls: 0 },
                { label: "Sora 16 / 500", t: "Options", f: Theme.fontUi, s: 16, w: Font.Medium, ls: 0 },
                { label: "Sora 14 / 500", t: "Prism Launcher   Hier, 23:40", f: Theme.fontUi, s: 14, w: Font.Medium, ls: 0 },
                { label: "Sora 15 / 400", t: "412 h de jeu · Mise à jour de 2,4 Go : le PC l’installe avant le lancement", f: Theme.fontUi, s: 15, w: Font.Normal, ls: 0 },
                { label: "Sora 14 / 400", t: "Natif 2560×1600   Auto (AV1)", f: Theme.fontUi, s: 14, w: Font.Normal, ls: 0 },
                { label: "Sora 13 / 400", t: "Ouverture du flux 800p60 AV1", f: Theme.fontUi, s: 13, w: Font.Normal, ls: 0 },
                { label: "Sora 12 / 500", t: "A  Y  B", f: Theme.fontUi, s: 12, w: Font.Medium, ls: 0 }
            ]
            Row {
                spacing: 24
                Text {
                    width: 220; anchors.baseline: sample.baseline
                    text: modelData.label; color: Theme.ink2
                    font.family: Theme.fontUi; font.pixelSize: 12
                }
                Text {
                    id: sample
                    text: modelData.t; color: Theme.ink
                    font.family: modelData.f; font.pixelSize: modelData.s
                    font.weight: modelData.w; font.letterSpacing: modelData.ls
                    // Famille et graisse réellement résolues + largeur, pour vérifier
                    // que chaque graisse tombe sur son fichier (pas de repli système).
                    Component.onCompleted: console.info("[specimen] " + modelData.label + " -> "
                        + fontInfo.family + " / " + fontInfo.weight + " / " + fontInfo.styleName
                        + ", largeur " + implicitWidth.toFixed(1))
                }
            }
        }
    }
}
