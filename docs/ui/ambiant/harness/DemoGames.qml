import QtQuick

// Les 10 jeux de la maquette (tableau GAMES du prototype), pour les vues de démo.
// `name`, `boxart` et `running` portent les mêmes noms que les rôles d'AppModel ;
// `source`, `lastPlayed` et `playtimeSeconds` ont la forme brute de la bibliothèque
// Companion (GameInfo) et passent par Format.js, comme dans ConsoleHome.
// Les images viennent de ref-capture.py. Rempli après coup, comme le vrai modèle.
ListModel {
    // days : ancienneté de la dernière session, en jours (elle date de 23:40).
    readonly property var games: [
        { id: "minecraft", name: "Minecraft", source: "Prism Launcher", days: 1, hours: 412, updateNote: "" },
        { id: "elden", name: "Elden Ring", source: "steam", days: 2, hours: 138, updateNote: "" },
        { id: "cyberpunk", name: "Cyberpunk 2077", source: "gog", days: 4, hours: 96, updateNote: "Mise à jour de 2,4 Go : le PC l’installe avant le lancement" },
        { id: "hades2", name: "Hades II", source: "steam", days: 6, hours: 41, updateNote: "" },
        { id: "bg3", name: "Baldur’s Gate 3", source: "steam", days: 9, hours: 187, updateNote: "" },
        { id: "fh5", name: "Forza Horizon 5", source: "xbox", days: 14, hours: 58, updateNote: "" },
        { id: "rdr2", name: "Red Dead Redemption 2", source: "epic", days: 21, hours: 122, updateNote: "" },
        { id: "sot", name: "Sea of Thieves", source: "steam", days: 35, hours: 33, updateNote: "" },
        { id: "outerwilds", name: "Outer Wilds", source: "epic", days: 60, hours: 24, updateNote: "" },
        { id: "hollow", name: "Hollow Knight", source: "steam", days: 90, hours: 47, updateNote: "" }
    ]

    function isoDaysAgo(days) {
        var d = new Date()
        d.setDate(d.getDate() - days)
        var pad = function(n) { return (n < 10 ? "0" : "") + n }
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "T23:40:00"
    }

    Component.onCompleted: games.forEach(function(g) {
        append({ name: g.name, source: g.source, lastPlayed: isoDaysAgo(g.days),
                 playtimeSeconds: g.hours * 3600, updateNote: g.updateNote, running: false,
                 boxart: Qt.resolvedUrl("art/" + g.id + ".jpg").toString() })
    })
}
