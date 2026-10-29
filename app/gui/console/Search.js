.pragma library

// Recherche dans la bibliothèque (SearchScreen) : titres, éditeurs et genres. Les jeux sont au
// format GameInfo du Companion (name, developers, publishers, genres, releaseDate) ; la casse et
// les accents ne comptent pas.

// « Élden  » → « elden » : minuscules, sans accents.
function normalize(s) {
    return String(s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
}

// Les jeux qui répondent à `query`, du plus pertinent au moins : le titre commence par la
// recherche, puis la contient, puis un studio ou un genre la contient. Chaque résultat :
// { index (dans `games`), name, hit (lettres du début du titre à souligner), why (pourquoi) }.
function results(games, query) {
    var q = normalize(query).trim()
    if (q === "") return []
    var found = []
    games.forEach(function(g, index) {
        var title = normalize(g.name)
        var studios = (g.developers || []).concat(g.publishers || [])
        var studio = studios.filter(function(s) { return normalize(s).indexOf(q) >= 0 })[0]
        var genre = (g.genres || []).filter(function(s) { return normalize(s).indexOf(q) >= 0 })[0]
        var year = /^(\d{4})/.exec(g.releaseDate || "")
        var r = title.indexOf(q) === 0
                ? { rank: 0, hit: q.length, why: [studios[0] || "", year ? year[1] : ""].filter(Boolean).join(" · ") }
              : title.indexOf(q) > 0 ? { rank: 1, hit: 0, why: qsTr("titre contient « %1 »").arg(query.trim()) }
              : studio ? { rank: 2, hit: 0, why: qsTr("studio : %1").arg(studio) }
              : genre ? { rank: 3, hit: 0, why: qsTr("genre : %1").arg(genre.toLowerCase()) }
              : null
        if (r) found.push({ index: index, name: g.name, hit: r.hit, why: r.why, rank: r.rank })
    })
    return found.sort(function(a, b) { return a.rank - b.rank || a.name.localeCompare(b.name) })
}

// Suggestions pour compléter la recherche : les mots des titres qui commencent par elle, puis
// les titres entiers (« ho » → hollow, horizon, hollow knight), `max` au plus.
function suggestions(games, query, max) {
    var q = normalize(query).trim()
    if (q === "") return []
    var words = [], titles = []
    games.forEach(function(g) {
        var name = String(g.name || "").toLowerCase()
        name.split(/[\s:’'\-]+/).forEach(function(w) {
            if (normalize(w).indexOf(q) === 0 && normalize(w) !== q && words.indexOf(w) < 0) words.push(w)
        })
        if (normalize(name).indexOf(q) === 0 && name.indexOf(" ") > 0 && titles.indexOf(name) < 0) titles.push(name)
    })
    return words.concat(titles.filter(function(t) { return words.indexOf(t) < 0 })).slice(0, max || 3)
}

// Les recherches récentes : `query` en tête, sans doublon, `max` au plus.
function remember(recent, query, max) {
    var q = String(query || "").trim()
    if (q === "") return recent
    return [q].concat(recent.filter(function(r) { return normalize(r) !== normalize(q) })).slice(0, max || 3)
}
