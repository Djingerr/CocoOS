#pragma once

// StreamMenu — le menu en jeu (bouton Home) et les statistiques du flux, posés
// par-dessus l'image du jeu. Build `embedded` seulement.
//
// Pendant un flux, Qt est suspendu et l'image est affichée par Moonlight (SDL) : le
// menu est dessiné en QPainter (StreamPainter) et confié à l'overlay de débogage de
// Moonlight (OverlayManager::setOverlaySurface), que tous ses moteurs de rendu savent
// composer. gamepad.cpp (sous CONSOLE_UI) l'ouvre au bouton Home et, tant qu'il est
// ouvert, lui donne les boutons : le PC voit une manette relâchée. ffmpeg.cpp lui
// passe chaque seconde les chiffres du flux quand les statistiques sont affichées
// (réglage ConsoleUi/streamStats, ligne du menu ou Select + L1 + R1 + X), et, à
// l'ouverture du menu, une image décodée : le fond flouté, figé.
// L'accueil le prépare avant chaque flux (InputStatus.prepareStreamMenu) et lit au
// retour l'action qui a fait quitter le flux (InputStatus.takeStreamExit).

#include <QString>
#include <QStringList>

#include <cstdint>

struct _VIDEO_STATS;
struct AVFrame;

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
void toggleStats();

// Fil du décodeur (ffmpeg.cpp).
bool wantsStats();
void updateStats(const _VIDEO_STATS& stats, int videoFormat, int width, int height, double megabitsPerSec);
void offerFrame(const AVFrame* frame);

}
