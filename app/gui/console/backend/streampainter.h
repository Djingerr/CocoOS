#pragma once

// StreamPainter — le dessin du menu en jeu et des statistiques du flux (StreamMenu),
// en QPainter pur : pendant un flux, l'image est affichée par Moonlight (SDL) et
// notre QML n'y a pas accès. Mêmes jetons que Theme.qml (canevas de 800 de haut mis
// à l'échelle de l'écran) ; le menu est le centre de contrôle CocoOS (JeuControle,
// MotionMenuJeu) ; les animations sont des valeurs de Frame, que StreamMenu fait avancer. Sans SDL ni Moonlight : le
// harnais le dessine seul (docs/ui/ambiant/harness/streammenu-shot.cpp).

#include <QColor>
#include <QImage>
#include <QPointF>
#include <QSize>
#include <QStringList>
#include <QVector>

namespace StreamPainter {

// Statistiques du flux, en haut à gauche (StatsOverlay) : détaillées (latence totale, sa
// courbe, son détail, l'image, le débit…) ou compactes (une pastille).
struct Stats {
    enum Mode { Hidden, Detailed, Compact };
    Mode mode = Detailed;
    QString host;           // « PC-Salon »
    int total = -1;         // latence totale (ms) ; < 0 : pas encore mesurée
    QString quality;        // « EXCELLENT »
    QVector<qreal> history; // latence totale, une valeur par seconde (la courbe)
    QStringList labels;     // lignes du détail ; "" : un filet
    QStringList values;
    QStringList compact;    // la pastille : latence, i/s, débit, batterie
};

// Un avis bref pendant le jeu, en haut à droite : manette presque vide, réseau instable,
// capture enregistrée. Le point dit le ton : Good (vert), Warn (orange), Bad (rouge).
struct Notice {
    enum Tone { Good, Warn, Bad };
    QString text;
    Tone tone = Good;
};

// Une tuile du centre de contrôle (JeuControle). Clés, dans l'ordre de la grille : resume,
// brightness, volume, shot, stats, home, quit, sleep, power.
struct Tile {
    QString key;
    QString label;
    QString sub;            // sous le libellé (« Retour au jeu », « Masquées ») ; valeur d'un curseur
    qreal value = -1;       // luminosité, volume : la hauteur du remplissage (0 à 1) ; < 0 : une action
    bool enabled = true;    // indisponible : estompée, sautée par la manette
};

// Le centre de contrôle : en-tête (le jeu, le PC, l'heure, la batterie), tuiles, légende.
struct Control {
    QString game;
    QString status;         // « En pause · 1 h 24 min »
    QImage cover;           // jaquette du jeu (vignette de l'en-tête) ; nulle : masquée
    QString host;           // « PC-Salon » ; vide : masqué
    QString latency;        // « 4 ms »
    QString time;           // « 21:42 »
    int battery = -1;       // % de la batterie de la console ; < 0 : masquée
    QVector<Tile> tiles;
    int focus = 0;
    QString activateLabel;  // légende de A (« Activer », « Maintenir »)
};

// Le menu d'alimentation (MenuAlimentation), carte centrée par-dessus le centre de contrôle.
struct Power {
    QString header;         // « BATTERIE 82 % · ENVIRON 3 H 10 » ; vide : masqué
    QStringList keys;       // suspend, reboot, poweroff
    QStringList labels;
    int focus = 0;
    QString note;           // « Le stream en cours sera fermé proprement avant l'arrêt. »
};

// Une image du menu, animations comprises (de 0 à 1 sauf mention).
struct Frame {
    Control control;
    QVector<qreal> tileFocus;       // par tuile : anneau, échelle, contour (vide : control.focus)
    qreal openMs = 1e9;             // depuis l'ouverture : en-tête et tuiles entrent en cascade
    qreal closing = 0;              // fermeture : tuiles et en-tête s'effacent en rétrécissant
    int swapTile = -1;              // sous-titre qui vient de changer sur cette tuile : l'ancien
    QString swapFrom;               // sort, le nouveau entre, comme dans SwapBox
    qreal swapProgress = 1;
    Power power;
    qreal powerMix = 0;             // 0 : le centre de contrôle ; 1 : la carte d'alimentation
    QVector<qreal> powerFocus;      // par choix : la pastille claire, agrandie
    qreal veil = 1;                 // fond : 0 transparent, 1 entièrement posé
    qreal blurMix = 1;              // fond : 0 voile seul, 1 image floutée seule
    QImage backdrop;                // l'image floutée (blurred), à la taille de l'écran
    Stats stats;
    qreal statsOpacity = 1;
    QString layout;                 // glyphes : "xbox", "playstation" ou "nintendo"
    qreal curtain = 0;              // fondu au noir par-dessus tout (avant de quitter le flux)
    // Appui maintenu sur la tuile en focus (Quitter le jeu, comme HoldFill.qml) : le remplissage
    // orange, de gauche à droite (déjà courbé), puis, plein, le libellé cède la place à une
    // coche et à `doneLabel` (holdDone de 0 à 1).
    qreal hold = 0;
    qreal holdDone = 0;
    QString doneLabel;
};

// Le menu plein écran (le fond, les statistiques, le centre de contrôle), dessiné dans
// `image` (ARGB32 prémultiplié, à la taille de l'écran ; elle peut envelopper la
// mémoire d'une surface SDL). Renvoie vrai si l'image est entièrement opaque : elle
// n'a alors pas besoin d'être « dé-prémultipliée ».
bool paintFrame(const Frame& frame, QImage& image);

// La tuile de `control` sous `pos` (en pixels de l'écran) ; -1 hors des tuiles.
int tileAt(const Control& control, QSize screen, QPointF pos);
// Sur un curseur (`tile`) : la hauteur visée, de 0 (en bas) à 1 ; où que soit `pos`.
qreal sliderAt(int tile, QSize screen, QPointF pos);
// Le choix de la carte d'alimentation sous `pos` : -1 dans la carte, -2 hors de la carte.
int powerAt(const Power& power, QSize screen, QPointF pos);

// Les icônes (SVG, icons/) : dans les ressources de l'application ; le harnais les prend
// dans le dépôt.
void setIconRoot(const QString& root);

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
