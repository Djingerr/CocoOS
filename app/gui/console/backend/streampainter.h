#pragma once

// StreamPainter — le dessin du menu en jeu et des statistiques du flux (StreamMenu),
// en QPainter pur : pendant un flux, l'image est affichée par Moonlight (SDL) et
// notre QML n'y a pas accès. Mêmes jetons que Theme.qml (canevas de 800 de haut mis
// à l'échelle de l'écran) et même panneau que ConsoleDialog ; les animations sont
// des valeurs de Frame, que StreamMenu fait avancer. Sans SDL ni Moonlight : le
// harnais le dessine seul (docs/ui/ambiant/harness/streammenu-shot.cpp).

#include <QColor>
#include <QImage>
#include <QPointF>
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

// Un avis bref pendant le jeu, en haut à droite : manette presque vide, réseau instable,
// capture enregistrée. Le point dit le ton : Good (vert), Warn (orange), Bad (rouge).
struct Notice {
    enum Tone { Good, Warn, Bad };
    QString text;
    Tone tone = Good;
};

// Le contenu du panneau : une liste d'actions, ou une confirmation.
struct Page {
    QString title;
    QString message;
    QStringList labels;
    QStringList values;     // valeur à droite de la ligne ("" : une action, glyphe A en focus)
    QVector<qreal> sliders; // par ligne : un curseur à cette position (0 à 1) à droite, la valeur
                            // à sa gauche ; < 0 ou absent : pas de curseur
    int focus = 0;
    QString backLabel;      // légende : B <backLabel>, A Valider
    QString confirmLabel;   // légende de A ; vide : « Valider »
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
    qreal curtain = 0;              // fondu au noir par-dessus tout (avant de quitter le flux)
    // Appui maintenu sur la ligne en focus (comme HoldFill.qml) : le remplissage orange, de
    // gauche à droite (déjà courbé), puis, plein, le libellé cède la place à une coche et à
    // `doneLabel` (holdDone de 0 à 1).
    qreal hold = 0;
    qreal holdDone = 0;
    QString doneLabel;
};

// Le menu plein écran (le fond, les statistiques, le panneau à droite), dessiné dans
// `image` (ARGB32 prémultiplié, à la taille de l'écran ; elle peut envelopper la
// mémoire d'une surface SDL). Renvoie vrai si l'image est entièrement opaque : elle
// n'a alors pas besoin d'être « dé-prémultipliée ».
bool paintFrame(const Frame& frame, QImage& image);

// La ligne de `page` sous `pos` (en pixels de l'écran, panneau en place) : -1 dans le
// panneau, hors des lignes ; -2 hors du panneau.
int rowAt(const Page& page, QSize screen, QPointF pos);
// Sur le curseur d'une ligne (ou tout près) : la position visée, de 0 à 1 ; -1 sinon.
// `dragging` : la poignée est tenue, c'est celui de la ligne en focus, où que soit `pos`.
qreal sliderAt(const Page& page, QSize screen, QPointF pos, bool dragging = false);

// Hors du menu : les statistiques (en haut à gauche) et l'avis (en haut à droite, qui
// descend en apparaissant), sur une image qui part du coin haut gauche de l'écran ; nulle
// s'il n'y a rien à montrer.
QImage paintStats(const Stats& stats, qreal opacity, QSize screen,
                  const Notice& notice = Notice(), qreal noticeOpacity = 0);

// Le fond du menu : une image du jeu, déjà réduite (au huitième), floutée, assombrie
// et mise à la taille de l'écran.
QImage blurred(QImage small, QSize screen);

// Couleur du point de qualité : mêmes seuils que la pastille de l'accueil
// (Format.networkQuality) ; gris si la latence n'est pas encore connue.
QColor networkColor(int latencyMs, int jitterMs);

}
