.pragma library

// Données de démo de ../mock/library.mock.json au format de la console : chaque jeu au
// format GameInfo du Companion (../../../HostCompanion/docs/protocol.md §4, tel que le rend
// CompanionClient.games()), jaquettes et fonds de art/ (make-art.py). Un champ absent du
// mock reste absent (cas limites de CasLimites : on retire, on ne remplace pas).

// mock : le JSON lu ; art : URL du dossier art/ (finie par « / »).
function games(mock, art) {
    return mock.games.map(function(g) {
        var game = {
            id: g.id,
            name: g.title,
            publishers: g.publisher ? [g.publisher] : [],
            developers: g.developer ? [g.developer] : [],
            releaseDate: g.release ? g.release + "T00:00:00" : null,
            genres: g.genre ? [g.genre] : [],
            ageRatings: g.pegi ? ["PEGI " + g.pegi] : [],
            playtimeSeconds: (g.playtime_min || 0) * 60,
            lastPlayed: g.lastPlayed || null,
            isInstalled: g.installed,
            description: g.description || null,
            favorite: g.favorite === true,
            cover: g.cover === null ? "" : art + g.id + "-cover.png",
            background: g.background === null ? "" : art + g.id + "-bg.png",
            mockAccent: g.accent || ""        // (l'accent de la maquette : HomeDemo accent=1)
        }
        return game
    })
}

// Grande bibliothèque (saut alphabétique au-delà de 30 jeux) : les jeux répétés jusqu'à
// `count`, avec des titres de A à Z (mock.notes).
function expand(list, count) {
    var out = []
    for (var i = 0; i < count; i++) {
        var g = Object.assign({}, list[i % list.length])
        g.id = g.id + "-" + i
        g.name = String.fromCharCode(65 + i % 26) + " · " + g.name
        out.push(g)
    }
    return out.sort(function(a, b) { return a.name.localeCompare(b.name) })
}

// Lecture synchrone d'un fichier local (QML_XHR_ALLOW_FILE_READ=1).
function load(url) {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", url, false)
    xhr.send()
    return JSON.parse(xhr.responseText)
}
