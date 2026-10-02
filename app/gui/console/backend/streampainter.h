#pragma once

// StreamPainter — le dessin du menu en jeu et des statistiques du flux (StreamMenu),
// en QPainter pur : pendant un flux, l'image est affichée par Moonlight (SDL) et
// notre QML n'y a pas accès. Mêmes jetons que Theme.qml (canevas de 800 de haut mis
// à l'échelle de l'écran) et même panneau que ConsoleDialog ; les animations sont
// des valeurs de Frame, que StreamMenu fait avancer. Sans SDL ni Moonlight : le
// harnais le dessine seul (docs/ui/ambiant/harness/streammenu-shot.cpp).

#include <QColor>
#include <QImage>
#include <QSize>
#include <QStringList>
#include <QVector>

namespace StreamPainter {

// Statistiques du flux, en haut à gauche : la première ligne en blanc, les autres
// en gris, `dotLine` précédée du point de qualité du réseau.
struct Stats {
    QStringList lines;
    int dotLine = -1;
    QColor dot;
};

// Le contenu du panneau : une liste d'actions, ou une confirmation.
struct Page {
    QString title;
    QString message;
    QStringList labels;
    QStringList values;     // valeur à droite de la ligne ("" : une action, glyphe A en focus)
    int focus = 0;
    QString backLabel;      // légende : B <backLabel>, A Valider
};

// Une image du menu, animations comprises (de 0 à 1 sauf mention).
struct Frame {
    Page page;
    qreal focusY = -1;              // surlignage, en lignes (il glisse) ; < 0 : page.focus
    QVector<qreal> highlight;       // par ligne : couleur du libellé, glyphe A ; vide : page.focus
    Page previous;                  // la page qui s'efface…
    qreal pageMix = 1;              // …tant que celle-ci n'est pas entièrement là
    int swapRow = -1;               // valeur qui vient de changer sur cette ligne : l'ancienne
    QString swapFrom;               // sort, la nouvelle entre, comme dans SwapBox
    qreal swapProgress = 1;
    qreal reveal = 1;               // panneau : 0 hors de l'écran à droite, 1 en place
    qreal veil = 1;                 // fond : 0 transparent, 1 entièrement posé
    qreal blurMix = 1;              // fond : 0 voile seul, 1 image floutée seule
    QImage backdrop;                // l'image floutée (blurred), à la taille de l'écran
    Stats stats;
    qreal statsOpacity = 1;
    QString layout;                 // glyphes : "xbox", "playstation" ou "nintendo"
};

// Le menu plein écran : le fond, les statistiques, le panneau à droite.
QImage paintFrame(const Frame& frame, QSize screen);

// Les statistiques seules, sur une image qui part du coin haut gauche de l'écran.
QImage paintStats(const Stats& stats, qreal opacity, QSize screen);

// Le fond du menu : une image du jeu, déjà réduite (au huitième), floutée, assombrie
// et mise à la taille de l'écran.
QImage blurred(QImage small, QSize screen);

// Couleur du point de qualité : mêmes seuils que la pastille de l'accueil
// (Format.networkQuality) ; gris si la latence n'est pas encore connue.
QColor networkColor(int latencyMs, int jitterMs);

}
