.pragma library

// Mise en forme, pour l'accueil et la fiche du jeu, des données de bibliothèque reçues
// du HostCompanion (GameInfo), et de la qualité du réseau vers le PC.

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

// --- Fiche du jeu (GamePage) ---

// Description Playnite (HTML brut, souvent celle de Steam) → texte simple : les blocs et
// les <br> deviennent des retours à la ligne, les <li> des puces, les autres balises
// (images comprises) tombent, les entités sont décodées en une passe, et les lignes vides
// d'affilée se réduisent à une seule.
function plainText(html) {
    if (!html) return ""
    var named = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " " }
    return html
        .replace(/<\s*br\s*\/?>/gi, "\n")
        .replace(/<\s*li[^>]*>/gi, "\n• ")
        .replace(/<\s*\/\s*(p|div|h[1-6]|ul|ol)\s*>/gi, "\n")
        .replace(/<[^>]*>/g, "")
        .replace(/&(#\d+|amp|lt|gt|quot|apos|nbsp);/g, function(e, name) {
            return name.charAt(0) === "#" ? String.fromCharCode(+name.slice(1)) : named[name]
        })
        .split("\n").map(function(line) { return line.trim() }).join("\n")
        .replace(/\n{3,}/g, "\n\n")
        .trim()
}

// La classification d'âge à afficher : le PEGI d'abord (console européenne), sinon la première.
function ageRating(ratings) {
    var list = ratings || []
    var pegi = list.filter(function(r) { return /^PEGI/i.test(r) })
    return pegi.length > 0 ? pegi[0] : (list[0] || "")
}

// Faits de la fiche : deux genres au plus, l'année de sortie, la classification d'âge.
function facts(info) {
    var list = (info.genres || []).slice(0, 2)
    var year = /^(\d{4})/.exec(info.releaseDate || "")
    if (year) list.push(year[1])
    var rating = ageRating(info.ageRatings)
    if (rating) list.push(rating)
    return list
}

// Développeurs puis éditeurs, sans doublon : « FromSoftware · Bandai Namco ».
function credits(info) {
    var names = []
    ;(info.developers || []).concat(info.publishers || []).forEach(function(n) {
        if (n && names.indexOf(n) < 0) names.push(n)
    })
    return names.join(" · ")
}

// Qualité du réseau vers le PC pour du streaming : "good", "fair", "poor", ou ""
// sans mesure. Latence (aller-retour) et gigue en ms, -1 si inconnues.
function networkQuality(latencyMs, jitterMs) {
    if (latencyMs < 0) return ""
    var jitter = Math.max(0, jitterMs)
    if (latencyMs <= 20 && jitter <= 5) return "good"
    if (latencyMs <= 50 && jitter <= 15) return "fair"
    return "poor"
}
