#pragma once

// StreamMenu — le menu en jeu (bouton Home), posé par-dessus l'image du jeu. Build
// `embedded` seulement.
//
// Pendant un flux, Qt est suspendu et l'image est affichée par Moonlight (SDL) : le
// menu est dessiné en QPainter (StreamPainter) et confié à l'overlay de débogage de
// Moonlight (OverlayManager::setOverlaySurface), que tous ses moteurs de rendu savent
// composer. gamepad.cpp (sous CONSOLE_UI) l'ouvre au bouton Home et, tant qu'il est
// ouvert, lui donne les boutons : le PC voit une manette relâchée.
// L'accueil le prépare avant chaque flux (InputStatus.prepareStreamMenu) et lit au
// retour l'action qui a fait quitter le flux (InputStatus.takeStreamExit).

#include <QString>
#include <QStringList>

#include <cstdint>

namespace StreamMenu {

// Fil de Qt, avant le flux.
void prepare(const QString& game, const QStringList& powerActions, const QString& buttonLayout);
// "home", "quit", "suspend", "reboot" ou "poweroff" ; vide si le flux s'est fini
// autrement. Ne le dit qu'une fois.
QString takeExit();

// Fil des événements SDL du flux (gamepad.cpp).
bool isOpen();
void toggle();
void onButton(uint8_t button, bool pressed);
void onAxis(uint8_t axis, int16_t value);

}
