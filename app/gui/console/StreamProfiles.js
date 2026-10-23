.pragma library

// Profils de flux (docs/stream/STREAM-OPTIMISATION.md §4, phase 1) : ce que chaque profil
// demande au lancement, d'après l'écran de la console et la qualité du réseau mesurée vers
// le PC. Fonctions pures, testées dans docs/ui/ambiant/harness/tst_StreamProfiles.qml.
// Un profil n'agit qu'au lancement (Apollo ne renégocie pas une session en cours) et ne
// touche ni au codec ni au HDR, qui restent ceux de l'utilisateur.

var KEYS = ["competitive", "balanced", "quality", "saver", "manual"]
var DEFAULT = "balanced"

// Les définitions 16:9 courantes, celles qu'Apollo et Moonlight connaissent.
var STANDARD = [ { width: 2560, height: 1440 }, { width: 1920, height: 1080 },
                 { width: 1280, height: 720 }, { width: 960, height: 540 } ]

// Définitions possibles, de la plus haute à la plus basse : celle de l'écran de la console si
// elle tient sous le plafond `cap` (l'image le remplit alors exactement), puis les définitions
// courantes, jamais au-dessus de l'écran ni du plafond.
function resolutions(screenWidth, screenHeight, cap) {
    var list = screenHeight <= cap ? [ { width: screenWidth, height: screenHeight } ] : []
    STANDARD.forEach(function(r) {
        if (r.height <= cap && r.height <= screenHeight && r.height !== screenHeight) list.push(r)
    })
    return list
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
        var list = resolutions(ctx.width, ctx.height, cap)
        return list[Math.min(steps, list.length - 1)]
    }
    var r, fps
    if (profile === "competitive") {          // la réactivité : toutes les images de l'écran
        r = pick(1080, drop)
        fps = Math.max(60, Math.min(120, Math.round(ctx.refresh || 60)))
    } else if (profile === "balanced") {
        r = pick(1080, drop)
        fps = 60
    } else if (profile === "quality") {       // l'image : plus de définition et de débit
        r = pick(1440, drop)
        fps = 60
    } else {                                  // l'économie : peu de données, peu de batterie
        r = pick(720, 0)
        fps = 30
    }
    var w = r.width, h = r.height
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
