.pragma library

// Le pointeur a-t-il vraiment bougé ? Qt envoie aussi des survols quand le contenu glisse
// sous un pointeur immobile (une liste qui défile au clavier) : ceux-là ne doivent pas
// déplacer la sélection. Une position déjà vue compte encore SAME_EVENT ms : un vrai
// déplacement est livré à tous les éléments survolés, l'un après l'autre.
// ponytail: seules les zones de survol (HoverArea) relèvent la position ; revenir au pixel
// près à la dernière position vue, après être passé ailleurs, ne compte pas comme un
// déplacement. Un HoverHandler sur toute la fenêtre le corrigerait, s'il le fallait.
var SAME_EVENT = 30
var lastX = NaN, lastY = NaN, lastAt = 0

function moved(item, x, y) {
    var p = item.mapToGlobal(x, y), now = Date.now()
    if (p.x !== lastX || p.y !== lastY) {
        lastX = p.x
        lastY = p.y
        lastAt = now
        return true
    }
    return now - lastAt < SAME_EVENT
}
