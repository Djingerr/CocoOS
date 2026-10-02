#pragma once

// StreamPainter — le dessin du menu en jeu (StreamMenu), en QPainter pur : pendant
// un flux, l'image est affichée par Moonlight (SDL) et notre QML n'y a pas accès.
// Mêmes jetons que Theme.qml (canevas de 800 de haut mis à l'échelle de l'écran) et
// même panneau que ConsoleDialog. Sans SDL ni Moonlight : le harnais le dessine seul
// (docs/ui/ambiant/harness/streammenu-shot.cpp).

#include <QImage>
#include <QSize>
#include <QStringList>

namespace StreamPainter {

struct Menu {
    QString title;
    QString message;
    QStringList labels;
    QStringList values;     // valeur à droite de la ligne ("" : une action, glyphe A en focus)
    int focus = 0;
    QString backLabel;      // légende : B <backLabel>, A Valider
    QString layout;         // glyphes : "xbox", "playstation" ou "nintendo"
};

// Le menu plein écran : un voile sur le flux, le panneau à droite.
QImage paintMenu(const Menu& menu, QSize screen);

}
