#pragma once

// StreamMenu — le menu en jeu (bouton Home) et les statistiques du flux, posés
// par-dessus l'image du jeu. Build `embedded` seulement.
//
// Pendant un flux, Qt est suspendu et l'image est affichée par Moonlight (SDL) : le
// menu est dessiné en QPainter (StreamPainter) et confié à l'overlay de débogage de
// Moonlight (OverlayManager::setOverlaySurface), que tous ses moteurs de rendu savent
// composer. gamepad.cpp (sous CONSOLE_UI) l'ouvre au bouton Home (keyboard.cpp à
// Ctrl+Alt+Maj+Tab) et, tant qu'il est ouvert, lui donne les boutons, les touches
// (keyboard.cpp) et la souris, libérée (mouse.cpp) : le PC voit une manette relâchée. ffmpeg.cpp lui
// passe chaque seconde les chiffres du flux quand les statistiques sont affichées
// (réglage ConsoleUi/streamStats, ligne du menu ou Select + L1 + R1 + X), et, à
// l'ouverture du menu, une image décodée : le fond flouté, figé. Quand l'écran du PC
// ne bouge pas, le décodeur réaffiche la dernière image, sans quoi l'overlay ne
// serait pas redessiné.
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

// Fil des événements SDL du flux (gamepad.cpp, keyboard.cpp, mouse.cpp).
bool isOpen();
void toggle();
void onButton(uint8_t button, bool pressed);
void onAxis(uint8_t axis, int16_t value);
// Souris (mouse.cpp), en points de la fenêtre : survoler une ligne la sélectionne, le
// clic gauche la valide au relâché, à côté du panneau ou clic droit : comme B.
// `button` à 0 : un simple déplacement.
void onPointer(int x, int y, int button, bool pressed);
void toggleStats();
// SDL_QUIT reçu par la boucle du flux (session.cpp). Un flux qui se ferme autrement que par
// le menu (connexion perdue, combinaison de la manette, Ctrl+Alt+Maj+Q, fenêtre fermée)
// passe lui aussi par le fondu au noir et le rideau : vrai, ce SDL_QUIT est mangé et un
// autre le suit, une fois la fenêtre de l'accueil revenue ; faux, il ferme le flux.
bool interceptQuit();

// Fil du décodeur (ffmpeg.cpp).
bool wantsStats();
void updateStats(const _VIDEO_STATS& stats, int videoFormat, int width, int height, double megabitsPerSec);
void offerFrame(const AVFrame* frame);
// Copie de la dernière image à réafficher pour que l'overlay apparaisse, si le menu a
// changé depuis (le PC n'envoie pas d'image quand son écran ne bouge pas) ; nullptr
// sinon. releaseFrame : le décodeur s'arrête, la copie gardée ne doit pas lui survivre.
AVFrame* frameToRepeat();
void releaseFrame();

}
