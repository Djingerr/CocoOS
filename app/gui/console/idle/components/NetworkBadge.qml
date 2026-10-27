import QtQuick
import ".."

// Génération d'un réseau mobile (« 4G », « 5G ») à la place de l'icône Wi-Fi, de la couleur et
// de la taille des icônes d'état (`large` : capsule de l'écran 12).
IdleText {
    property bool large: false
    textStyle: large ? IdleTheme.networkBadgeLarge : IdleTheme.networkBadge
    color: large ? IdleTheme.textPrimary : IdleTheme.textStatus
    opacity: large ? 0.7 : 1
}
