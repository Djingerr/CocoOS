#pragma once

// Motifs de vibration CocoOS (docs/ui/cocoos/motion/haptics.json, embarqué en
// :/gui/console/haptics.json) : chaque son du pack qui fait vibrer a son motif, sur deux
// moteurs (L grave, H aigu), en impulsions de quelques ms d'amplitude 0..1 (une rampe
// `from → to` possible). SDL_GameControllerRumble ne connaît qu'un niveau par moteur :
// le motif est découpé ici en pas de 10 ms (SPEC §3). Sans SDL ni Moonlight, pour être
// vérifiable seul (docs/ui/cocoos/harness/tst_haptics.cpp). Joué par StreamMenu::rumble.

#include <QByteArray>
#include <QString>
#include <QVector>

namespace Haptics {

struct Step {
    int ms;          // durée du pas
    double low;      // moteur grave (L), 0..1
    double high;     // moteur aigu (H), 0..1
};

struct Pattern {
    QString id;
    QString sound;   // le son du pack qui le déclenche (Sounds.played)
    int totalMs = 0;
    QVector<Step> steps;   // pas consécutifs de même niveau fusionnés ; leurs durées font totalMs
};

// Contenu de haptics.json → motifs ; vide si illisible.
QVector<Pattern> parse(const QByteArray& json);

// Le motif d'un son du pack, ou nullptr. Lit les ressources au premier appel.
const Pattern* forSound(const QString& sound);

}
