.pragma library

// Mise en forme, pour l'accueil, des données de bibliothèque reçues du
// HostCompanion (GameInfo : source, lastPlayed, playtimeSeconds).

var SOURCES = {
    steam: "Steam", epic: "Epic Games", gog: "GOG", ea: "EA", battlenet: "Battle.net",
    ubisoft: "Ubisoft Connect", xbox: "Xbox", amazon: "Amazon Games", itchio: "itch.io"
}

// « steam » → « Steam » ; une source inconnue est simplement mise en capitale.
function sourceName(source) {
    if (!source) return ""
    return SOURCES[source] || source.charAt(0).toUpperCase() + source.slice(1)
}

// « 412 h de jeu », « 35 min de jeu » ; vide si le jeu n'a (presque) pas été joué.
function playtime(seconds) {
    if (!seconds || seconds < 60) return ""
    if (seconds < 3600) return qsTr("%1 min de jeu").arg(Math.floor(seconds / 60))
    return qsTr("%1 h de jeu").arg(Math.floor(seconds / 3600))
}

function startOfDay(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

function pad(n) {
    return (n < 10 ? "0" : "") + n
}

// Dernière session, relativement à `now` : « Aujourd'hui, 21:30 », « Hier, 23:40 »,
// « Il y a 4 jours », « Il y a 3 semaines », « Il y a 2 mois », « Il y a 1 an ».
// `iso` est une date locale sans fuseau (« 2026-06-01T21:30:00 ») ; vide si jamais joué.
function lastPlayed(iso, now) {
    var m = /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d)/.exec(iso || "")
    if (!m) return ""
    var then = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5])
    // Jours de calendrier (arrondi : une journée de changement d'heure fait 23 ou 25 h).
    var days = Math.round((startOfDay(now) - startOfDay(then)) / 86400000)
    var time = pad(then.getHours()) + ":" + pad(then.getMinutes())
    if (days <= 0) return qsTr("Aujourd'hui, %1").arg(time)
    if (days === 1) return qsTr("Hier, %1").arg(time)
    if (days < 14) return qsTr("Il y a %1 jours").arg(days)
    if (days < 60) return qsTr("Il y a %1 semaines").arg(Math.floor(days / 7))
    if (days < 365) return qsTr("Il y a %1 mois").arg(Math.floor(days / 30))
    var years = Math.floor(days / 365)
    return years === 1 ? qsTr("Il y a 1 an") : qsTr("Il y a %1 ans").arg(years)
}
