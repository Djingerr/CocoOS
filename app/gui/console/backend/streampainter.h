#pragma once

// StreamPainter — le dessin du menu en jeu et des statistiques du flux (StreamMenu),
// en QPainter pur : pendant un flux, l'image est affichée par Moonlight (SDL) et
// notre QML n'y a pas accès.
// Mêmes jetons que Theme.qml (canevas de 800 de haut mis à l'échelle de l'écran) et
// même panneau que ConsoleDialog. Sans SDL ni Moonlight : le harnais le dessine seul
// (docs/ui/ambiant/harness/streammenu-shot.cpp).

#include <QColor>
#include <QImage>
#include <QSize>
#include <QStringList>

namespace StreamPainter {

// Statistiques du flux, en haut à gauche : la première ligne en blanc, les autres
// en gris, `dotLine` précédée du point de qualité du réseau.
struct Stats {
    QStringList lines;
    int dotLine = -1;
    QColor dot;
};

struct Menu {
    QString title;
    QString message;
    QStringList labels;
    QStringList values;     // valeur à droite de la ligne ("" : une action, glyphe A en focus)
    int focus = 0;
    QString backLabel;      // légende : B <backLabel>, A Valider
    QString layout;         // glyphes : "xbox", "playstation" ou "nintendo"
    Stats stats;            // affichées par-dessus le voile si elles ont des lignes
    QImage backdrop;        // l'image du jeu floutée (blurred) ; nulle : un voile sur le flux
};

// Le menu plein écran : le fond, le panneau à droite.
QImage paintMenu(const Menu& menu, QSize screen);

// Le fond du menu : une image du jeu, déjà réduite (au huitième), floutée, assombrie
// et mise à la taille de l'écran.
QImage blurred(QImage small, QSize screen);

// Les statistiques seules, sur une image qui part du coin haut gauche de l'écran.
QImage paintStats(const Stats& stats, QSize screen);

// Couleur du point de qualité : mêmes seuils que la pastille de l'accueil
// (Format.networkQuality) ; gris si la latence n'est pas encore connue.
QColor networkColor(int latencyMs, int jitterMs);

}
