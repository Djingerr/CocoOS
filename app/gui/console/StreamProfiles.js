.pragma library

// Profils de flux (docs/stream/STREAM-OPTIMISATION.md §4, phase 1) : ce que chaque profil
// demande au lancement, d'après l'écran de la console et la qualité du réseau mesurée vers
// le PC. Fonctions pures, testées dans docs/ui/ambiant/harness/tst_StreamProfiles.qml.
// Un profil n'agit qu'au lancement (Apollo ne renégocie pas une session en cours) et ne
// touche ni au codec ni au HDR, qui restent ceux de l'utilisateur.

var KEYS = ["competitive", "balanced", "quality", "saver", "manual"]
var DEFAULT = "balanced"

// Définitions (hauteurs) possibles, de la plus haute à la plus basse : celle de l'écran,
// puis les paliers courants, plafonnées à `cap` et à l'écran.
function heights(screenHeight, cap) {
    var top = Math.min(screenHeight, cap)
    return [screenHeight, 1440, 1080, 720, 540]
        .filter(function(h, i, all) { return h <= top && all.indexOf(h) === i })
        .sort(function(a, b) { return b - a })
}

// Paliers retirés par la qualité du réseau : un sur un réseau moyen, deux sur un mauvais.
function networkDrop(quality) {
    return quality === "poor" ? 2 : quality === "fair" ? 1 : 0
}

// ctx : { width, height (de l'écran), refresh (Hz), quality ("good" | "fair" | "poor" | ""),
//         defaultKbps: function(w, h, fps) (le débit que Moonlight conseille) }.
// Rend { width, height, fps, bitrateKbps } ; null pour Manuel (les réglages de l'utilisateur).
function launchSettings(profile, ctx) {
    if (KEYS.indexOf(profile) < 0 || profile === "manual") return null
    var drop = networkDrop(ctx.quality)
    var pick = function(cap, steps) {
        var list = heights(ctx.height, cap)
        return list[Math.min(steps, list.length - 1)]
    }
    var h, fps
    if (profile === "competitive") {          // la réactivité : toutes les images de l'écran
        h = pick(1080, drop)
        fps = Math.max(60, Math.min(120, Math.round(ctx.refresh || 60)))
    } else if (profile === "balanced") {
        h = pick(1080, drop)
        fps = 60
    } else if (profile === "quality") {       // l'image : plus de définition et de débit
        h = pick(1440, drop)
        fps = 60
    } else {                                  // l'économie : peu de données, peu de batterie
        h = pick(720, 0)
        fps = 30
    }
    var w = 2 * Math.round(h * ctx.width / ctx.height / 2)
    var kbps = ctx.defaultKbps(w, h, fps)
    if (profile === "quality" && drop === 0)
        kbps = Math.min(150000, Math.round(kbps * 1.5 / 1000) * 1000)
    if (profile === "saver")
        kbps = Math.min(kbps, 5000)
    return { width: w, height: h, fps: fps, bitrateKbps: kbps }
}

// Données consommées en une heure à ce débit, en Go.
function gigabytesPerHour(kbps) {
    return kbps * 3600 / 8 / 1e6
}
