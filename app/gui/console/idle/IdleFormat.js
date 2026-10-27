.pragma library

// Formats de texte de l'écran de veille (docs/design/idle/SPEC.md §5). Source en français,
// traduite par qsTr comme le reste de la console.

var NBSP = " "
var DAYS = [QT_TR_NOOP("dimanche"), QT_TR_NOOP("lundi"), QT_TR_NOOP("mardi"), QT_TR_NOOP("mercredi"),
            QT_TR_NOOP("jeudi"), QT_TR_NOOP("vendredi"), QT_TR_NOOP("samedi")]
var MONTHS = [QT_TR_NOOP("janvier"), QT_TR_NOOP("février"), QT_TR_NOOP("mars"), QT_TR_NOOP("avril"),
              QT_TR_NOOP("mai"), QT_TR_NOOP("juin"), QT_TR_NOOP("juillet"), QT_TR_NOOP("août"),
              QT_TR_NOOP("septembre"), QT_TR_NOOP("octobre"), QT_TR_NOOP("novembre"), QT_TR_NOOP("décembre")]

function pad(n) {
    return (n < 10 ? "0" : "") + n
}

// « 21:46 »
function clock(date) {
    return pad(date.getHours()) + ":" + pad(date.getMinutes())
}

// « Mardi 27 octobre »
function longDate(date) {
    var text = qsTr("%1 %2 %3").arg(qsTr(DAYS[date.getDay()])).arg(date.getDate()).arg(qsTr(MONTHS[date.getMonth()]))
    return text.charAt(0).toUpperCase() + text.slice(1)
}

// Durée de session, en morceaux pour le grand bloc : [{ value: "1", unit: "h" },
// { value: "24", unit: "min" }] ; seulement les minutes sous 1 h, sur deux chiffres sinon.
function sessionParts(seconds) {
    var minutes = Math.floor(Math.max(0, seconds) / 60)
    var h = Math.floor(minutes / 60), m = minutes % 60
    if (h === 0) return [{ value: "" + m, unit: "min" }]
    return [{ value: "" + h, unit: "h" }, { value: pad(m), unit: "min" }]
}
// « 1 h 24 min », « 24 min »
function sessionDuration(seconds) {
    return sessionParts(seconds).map(function(p) { return p.value + " " + p.unit }).join(" ")
}

// Débit (octets par seconde, unités décimales) : « 1,2 Go/s », « 850 Mo/s », « 300 ko/s ».
function rate(bytesPerSec) {
    var mo = Math.round(bytesPerSec / 1e6)
    // Séparateur décimal (anglais : un point).
    if (mo >= 1000) return qsTr("%1 Go/s").arg((Math.round(bytesPerSec / 1e8) / 10).toFixed(1).replace(".", qsTr(",")))
    if (mo >= 1) return qsTr("%1 Mo/s").arg(mo)
    return qsTr("%1 ko/s").arg(Math.round(bytesPerSec / 1e3))
}

// Temps restant d'un téléchargement : minutes entamées, « 4 min », « 1 h 05 ».
function etaShort(seconds) {
    var minutes = Math.ceil(seconds / 60)
    if (minutes < 60) return qsTr("%1 min").arg(minutes)
    return qsTr("%1 h %2").arg(Math.floor(minutes / 60)).arg(pad(minutes % 60))
}
// « environ 6 min », « moins d'une minute », « environ 1 h 05 »
function eta(seconds) {
    if (seconds < 60) return qsTr("moins d'une minute")
    return qsTr("environ %1").arg(etaShort(seconds))
}

// « 82 % » (espace insécable)
function percent(fraction) {
    return Math.floor(fraction * 100 + 1e-9) + NBSP + "%"
}
function percentValue(value) {
    return Math.round(value) + NBSP + "%"
}

// « 4 ms »
function latency(ms) {
    return qsTr("%1 ms").arg(Math.round(ms))
}

// Autonomie de la batterie : « Environ 3 h », « Environ 45 min », « Environ 3 h 20 »
// (au-delà d'une heure, arrondie à 10 min) ; en charge : « En charge » ; vide sans estimation.
function autonomy(minutesLeft, charging) {
    if (charging) return qsTr("En charge")
    if (minutesLeft === undefined || minutesLeft < 0) return ""
    if (minutesLeft < 60) return qsTr("Environ %1 min").arg(Math.max(1, Math.round(minutesLeft)))
    var rounded = Math.round(minutesLeft / 10) * 10
    var h = Math.floor(rounded / 60), m = rounded % 60
    return m ? qsTr("Environ %1 h %2").arg(h).arg(pad(m)) : qsTr("Environ %1 h").arg(h)
}

function startOfDay(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}
// Dernière session : « Il y a 12 min », « Il y a 2 h » (le même jour), « Hier »,
// « Il y a 3 jours ».
function lastSession(then, now) {
    var minutes = Math.floor((now - then) / 60000)
    if (minutes < 60) return qsTr("Il y a %1 min").arg(Math.max(1, minutes))
    // Jours de calendrier (arrondi : une journée de changement d'heure fait 23 ou 25 h).
    var days = Math.round((startOfDay(now) - startOfDay(then)) / 86400000)
    if (days === 0) return qsTr("Il y a %1 h").arg(Math.floor(minutes / 60))
    if (days === 1) return qsTr("Hier")
    return qsTr("Il y a %1 jours").arg(days)
}

// Qualité du Wi-Fi d'après le RSSI (dBm) : "excellent", "good", "fair", "poor".
function wifiQualityKey(rssiDbm) {
    return rssiDbm >= -55 ? "excellent" : rssiDbm >= -67 ? "good" : rssiDbm >= -75 ? "fair" : "poor"
}
var QUALITY = { excellent: QT_TR_NOOP("Excellent"), good: QT_TR_NOOP("Bon"),
                fair: QT_TR_NOOP("Moyen"), poor: QT_TR_NOOP("Faible") }
var QUALITY_REST = { excellent: QT_TR_NOOP("Wi-Fi excellent"), good: QT_TR_NOOP("Wi-Fi bon"),
                     fair: QT_TR_NOOP("Wi-Fi moyen"), poor: QT_TR_NOOP("Wi-Fi faible") }
// « Excellent » (lignes d'état) ; `rest` : « Wi-Fi excellent » (capsule de l'écran 12).
function wifiQuality(key, rest) {
    var label = (rest ? QUALITY_REST : QUALITY)[key]
    return label ? qsTr(label) : ""
}

// Génération d'un réseau mobile : "4G", "5G" ; vide pour un autre réseau.
function cellular(kind) {
    return kind === "5g" ? "5G" : kind === "4g" || kind === "lte" ? "4G" : ""
}
var QUALITY_REST_CELL = { excellent: QT_TR_NOOP("%1 excellente"), good: QT_TR_NOOP("%1 bonne"),
                          fair: QT_TR_NOOP("%1 moyenne"), poor: QT_TR_NOOP("%1 faible") }
// Réseau de la console pour les lignes d'état : { icon: "wifi" } ou { badge: "5G" }, et la qualité
// (« Excellent » ; `rest` : « Wi-Fi excellent », « 5G excellente ») ; null sans Wi-Fi ni réseau mobile.
// network : { kind, quality ("excellent"…) ou rssiDbm }.
function networkItem(network, rest) {
    var key = network.quality || wifiQualityKey(network.rssiDbm)
    var generation = cellular(network.kind)
    if (generation !== "")
        return { badge: generation, text: rest ? qsTr(QUALITY_REST_CELL[key] || "%1").arg(generation)
                                               : wifiQuality(key, false) }
    if (network.kind === "wifi") return { icon: "wifi", text: wifiQuality(key, rest) }
    return null
}

// « En jeu », « En ligne », « En veille », « Hors ligne »
function hostState(host) {
    if (!host || !host.reachable) return qsTr("Hors ligne")
    if (host.sleeping) return qsTr("En veille")
    return host.inGame ? qsTr("En jeu") : qsTr("En ligne")
}
