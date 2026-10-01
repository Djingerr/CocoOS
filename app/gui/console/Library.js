.pragma library

// L'étagère de l'accueil : quelles apps du PC y figurent, et dans quel ordre.
// Logique pure, testée dans docs/ui/ambiant/harness/tst_Library.qml.

// Apps qu'Apollo / Sunshine (ou l'utilisateur) déclarent et qui ne sont pas des
// jeux. Noms en minuscules.
var UTILITIES = [
    "desktop", "low res desktop", "steam big picture", "virtual display",
    "playnite", "playnite fullscreen", "terminate"
]

function isUtility(name) {
    return UTILITIES.indexOf((name || "").trim().toLowerCase()) >= 0
}

// apps : [{ name, … }] ; favorites : noms épinglés, le dernier épinglé en tête ;
// lastPlayed(name) : date de la dernière partie en ms, 0 si jamais joué.
// Les utilitaires sont écartés tant qu'il reste au moins un jeu (sinon la console
// ne servirait à rien). Ordre : favoris, puis du plus récent au plus ancien, puis
// les jamais joués par nom.
function order(apps, favorites, lastPlayed) {
    var games = apps.filter(function(a) { return !isUtility(a.name) })
    var list = games.length > 0 ? games : apps.slice()
    var pin = function(a) {
        var i = favorites.indexOf(a.name)
        return i < 0 ? favorites.length : i
    }
    var played = list.map(function(a) { return lastPlayed(a.name) })
    var index = list.map(function(a, i) { return i })
    index.sort(function(i, j) {
        var a = list[i], b = list[j]
        if (pin(a) !== pin(b)) return pin(a) - pin(b)
        if (played[i] !== played[j]) return played[j] - played[i]
        return a.name.localeCompare(b.name)
    })
    return index.map(function(i) { return list[i] })
}

// Aligne `model` (un ListModel) sur `items` (objets portant au moins `name`) en
// déplaçant, insérant et supprimant le moins possible : les vignettes déjà
// présentes gardent leur délégué (pas de rechargement d'image ni de clignotement).
function sync(model, items) {
    for (var i = 0; i < items.length; i++) {
        var j = i
        while (j < model.count && model.get(j).name !== items[i].name)
            j++
        if (j === model.count) {
            model.insert(i, items[i])
            continue
        }
        if (j !== i)
            model.move(j, i, 1)
        for (var key in items[i]) {
            if (model.get(i)[key] !== items[i][key])
                model.setProperty(i, key, items[i][key])
        }
    }
    if (model.count > items.length)
        model.remove(items.length, model.count - items.length)
}

// Les favoris une fois `name` épinglé (il passe en tête) ou détaché.
function toggled(favorites, name) {
    var rest = favorites.filter(function(n) { return n !== name })
    return rest.length < favorites.length ? rest : [name].concat(rest)
}

// Lecture tolérante d'un réglage stocké en JSON.
function parse(json, fallback) {
    try {
        var value = JSON.parse(json)
        var sameType = value !== null && typeof value === typeof fallback
                       && Array.isArray(value) === Array.isArray(fallback)
        return sameType ? value : fallback
    } catch (e) {
        return fallback
    }
}
