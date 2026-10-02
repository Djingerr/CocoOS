import QtQuick

// Le logotype « CocoOS » : une lettre par Text (C, o, c, o, O, S) en Sora Bold,
// placées comme dans le prototype de démarrage (docs/boot-animation/) : avances
// avec crénage, ligne de base commune, centre et rayons du O tirés de son rectangle
// serré. Le même composant sert à l'animation de démarrage (taille d'écran) et à la
// barre haute (réduit par `scale`) : même géométrie, aucun saut au passage de relais.
// Repère : origine à gauche de « Coco », en haut du rectangle serré de « CocoOS ».
// Aucune dépendance Moonlight.
Item {
    id: root

    property real fontSize: Theme.logoSize
    // Déploiement (BootSplash) : pour C, o, c, o puis S, { x (origine dans le repère
    // du logo), lum (luminance, 0 à 1), shown } ; vide = au repos, avec `lum`.
    property var letters: []
    property real lum: 1                     // luminance des lettres au repos, 0 à 1
    property color oColor: Theme.accent
    property real oScale: 1                  // échelle du O autour de son centre
    property real oShift: 0                  // décalage horizontal du O
    property bool oVisible: true

    // Géométrie au repos : { w, asc, desc, base, xs[4], widths[5], xO, xS, ocx, ocy, rxo, ryo }.
    readonly property var geo: { Theme.fontsReady; metrics.font; return layout() }

    function layout() {
        var adv = function(s) { return metrics.advanceWidth(s) }
        var word = "Coco"
        var wC = adv(word), wOS = adv("OS"), wS = adv("S")
        var all = metrics.tightBoundingRect("CocoOS")
        var asc = -all.y, desc = all.y + all.height
        var xs = []
        for (var i = 0; i < word.length; i++)
            xs.push(adv(word.slice(0, i + 1)) - adv(word[i]))
        var o = metrics.tightBoundingRect("O")
        return {
            w: wC + wOS, asc: asc, desc: desc, base: asc, xs: xs,
            widths: [adv("C"), adv("o"), adv("c"), adv("o"), wS],
            xO: wC, xS: wC + wOS - wS,
            ocx: wC + o.x + o.width / 2, ocy: asc + o.y + o.height / 2,
            rxo: o.width / 2, ryo: o.height / 2
        }
    }

    implicitWidth: geo.w
    implicitHeight: geo.asc + geo.desc

    FontMetrics {
        id: metrics
        font.family: Theme.fontUi
        font.weight: Font.Bold
        font.pixelSize: root.fontSize
        // Avances non arrondies : la géométrie suit la taille de façon linéaire.
        font.hintingPreference: Font.PreferNoHinting
    }

    component Letter: Text {
        property int slot: -1                // 0 à 4 : C, o, c, o, S ; -1 : le O
        property real restX
        readonly property var letterState: slot >= 0 && root.letters.length === 5 ? root.letters[slot] : null
        readonly property real l: letterState ? letterState.lum : root.lum
        x: letterState ? letterState.x : restX
        y: root.geo.base - baselineOffset
        visible: letterState ? letterState.shown : true
        font: metrics.font
    }

    Repeater {
        model: 4
        Letter {
            required property int index
            slot: index
            text: "Coco"[index]
            restX: root.geo.xs[index]
            color: Qt.rgba(l, l, l, 1)
        }
    }
    Letter {
        slot: 4
        text: "S"
        restX: root.geo.xS
        color: Qt.rgba(Theme.accent.r * l, Theme.accent.g * l, Theme.accent.b * l, 1)
    }
    Letter {
        id: oLetter
        text: "O"
        visible: root.oVisible
        restX: root.geo.xO + root.oShift
        color: root.oColor
        transform: Scale {
            origin.x: root.geo.ocx - root.geo.xO
            origin.y: root.geo.ocy - oLetter.y
            xScale: root.oScale; yScale: root.oScale
        }
    }
}
