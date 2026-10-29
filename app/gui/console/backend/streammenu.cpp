#include "streammenu.h"
#include "streampainter.h"
#include "haptics.h"

#include "streaming/session.h"
#include "streaming/video/decoder.h"

#include <QCoreApplication>
#include <QEasingCurve>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QFile>
#include <QHash>
#include <QLocale>
#include <QMutex>
#include <QMutexLocker>
#include <QDateTime>
#include <QTime>
#include <QUrl>
#include <QVariantMap>
#include <QDir>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QThreadPool>
#include <QtMath>

#include <atomic>

extern "C" {
#include <libavutil/frame.h>
#include <libavutil/hwcontext.h>
#include <libswscale/swscale.h>
}

namespace {

// Stick gauche : une marche quand il passe la poussée, la suivante une fois revenu
// sous le repos.
const int STICK_PUSH = 20000;
const int STICK_REST = 10000;

const char* STATS_SETTING = "ConsoleUi/streamStats";
const char* HAPTICS_SETTING = "ConsoleUi/haptics";
const double HAPTICS_DEFAULT = 0.6;   // « Légères »
const char* MOTION_SETTING = "ConsoleUi/reduceMotion";
// Départ sans action pour l'accueil : le flux s'est fermé autrement que par le menu.
const char* ENDED = "ended";
const char* SOUNDS_SETTING = "ConsoleUi/sounds";

// Durées du centre de contrôle (MotionMenuJeu), en ms.
const int ENTRY_TOTAL = 8 * 35 + 560;   // la dernière tuile a fini d'entrer (streampainter)
const int CLOSE_MOVE = 260;         // fermeture : tuiles et en-tête s'effacent en rétrécissant
const int SHEET_DIM_FADE = 320;     // fond, linéaire
const int TILE_FOCUS_FADE = 300;    // anneau et contour de la tuile en focus
const int SHEET_VALUE_SWAP = 260;   // « Affichées » / « Masquées »
const int POWER_IN = 420;           // carte d'alimentation : arrive (ressort), part plus vite
const int POWER_OUT = 200;
const int BLUR_FADE = 200;          // l'image floutée remplace le voile
const int STATS_FADE = 220;         // Theme.toastFade
const int CURTAIN_FADE = 250;       // fondu au noir avant de quitter le flux
const int STREAM_FADE_IN = 400;     // au début du flux, le noir s'efface sur ses premières images
// Par-dessus le jeu (MotionAlertes, MotionReseau, MotionCapture) : la bannière arrive au ressort
// (640 ms), reste, repart (360) ; la carte de la manette (560, après 150), « reconnectée » puis
// s'efface ; la capture : flash, vignette au ressort (640, après 150), étiquette, départ.
const int BANNER_IN = 640;
const int BANNER_OUT = 360;
const Uint32 BANNER_HOLD = 3600;
const int PAUSE_IN = 560;
const int PAUSE_OUT = 260;
const Uint32 PAUSE_RESUME = 1300;   // « Manette reconnectée », le temps de le lire
const int SHOT_FLASH = 380;
const int SHOT_FLY = 640;
const int SHOT_OUT = 420;
const Uint32 SHOT_HOLD = 2700;
const int BATTERY_CRITICAL = 5;     // %, sur batterie : la bannière « Batterie très faible »
const int VALUE_STEP = 5;           // volume, luminosité : ← / → de 5 % (la souris aussi, par crans de 5)
const int SLIDER_MOVE = 160;        // la poignée rejoint la nouvelle valeur, OutCubic
const int BRIGHTNESS_MIN = 5;       // SystemStatus.setBrightness : jamais tout à fait noir
const int POOR_SECONDS = 10;        // réseau « mauvais » (Format.networkQuality) aussi longtemps : un avis
const int POOR_RTT = 50;            // au-delà : mauvais (ms), comme la pastille de l'accueil
const int POOR_VARIANCE = 15;
const int STATS_HISTORY = 24;       // la courbe de la latence : les 24 dernières secondes
// Appui maintenu des confirmations (Theme.hold*, HoldFill.qml) : plein en HOLD_DURATION,
// affiché progression^HOLD_CURVE, vidé en HOLD_DRAIN si on lâche ; plein, la coche arrive en
// HOLD_SWAP, puis l'action part après HOLD_FINISH.
const int HOLD_DURATION = 900;
const int HOLD_DRAIN = 280;
const qreal HOLD_CURVE = 1.4;
const int HOLD_SWAP = 300;
const int HOLD_FINISH = 613;        // Theme.springBouncy.duration (le rebond de HoldFill)
const int FRAME_MS = 16;            // une image toutes les 16 ms pendant une animation

// Croix ou stick tenus : une marche, puis la répétition de l'accueil (PadRepeat,
// Theme.repeat*) : un délai, puis un intervalle qui se resserre jusqu'à un plancher.
const int REPEAT_DELAY = 360;
const int REPEAT_INTERVAL = 120;
const int REPEAT_STEP = 10;
const int REPEAT_MIN = 55;

// Avant de fermer le flux, la fenêtre de l'accueil revient (finishLeave) : on attend
// qu'elle ait affiché une image, au plus ce délai, puis que le logo du rideau y soit
// apparu (Theme.curtainReveal) et que l'écran l'ait montrée.
const int SHOW_TIMEOUT_MS = 500;
const int SHOW_REVEAL_MS = 320;
const int SHOW_SETTLE_MS = 50;
// Moonlight ne compose l'overlay qu'en affichant une image du flux ; sur un écran
// immobile, le PC n'en envoie presque plus. Sans image reçue depuis ce délai (un peu
// plus qu'une image à 60 i/s), le décodeur réaffiche la dernière sous le menu.
const Uint32 REPEAT_AFTER_MS = 20;

// Sons du pack CocoOS (sounds/*.wav, 48 kHz stéréo 16 bits), joués par SDL :
// QtMultimedia ne tourne pas pendant un flux. Seuls ceux qui ont leur place par-dessus
// le jeu (SPEC §2 : menu en jeu, curseurs, volume).
const int SOUND_RATE = 48000;
const int SOUND_CHANNELS = 2;
const double SOUND_VOLUME = 0.8;  // Theme.soundVolume
const char* const SOUND_NAMES[] = { "ingame_menu_open", "ingame_menu_close", "focus_tick", "nav_edge", "select",
                                    "hold_fill", "hold_done", "volume_tick", "volume_limit", "brightness_tick",
                                    "slider_limit" };

// Une valeur qui va de `from` à `to` en `duration` ms à partir de `start`.
struct Anim {
    double from = 0;
    double to = 0;
    Uint32 start = 0;
    int duration = 0;
    QEasingCurve::Type easing = QEasingCurve::Linear;

    double at(Uint32 now) const
    {
        if (duration > 0 && (Sint32)(now - start) < 0) {
            return from;   // (pas encore partie : `delay`)
        }
        if (!running(now)) {
            return to;
        }
        return from + (to - from) * QEasingCurve(easing).valueForProgress(double(now - start) / duration);
    }
    bool running(Uint32 now) const
    {
        return duration > 0 && (Sint32)(now - start) < duration;
    }
    void go(double target, int ms, Uint32 now, QEasingCurve::Type curve = QEasingCurve::Linear, int delay = 0)
    {
        from = at(now);
        to = target;
        start = now + delay;
        duration = ms;
        easing = curve;
    }
    void set(double value)
    {
        from = to = value;
        duration = 0;
    }
};

QMutex s_lock;
Session* s_session = nullptr;   // le flux où le menu a été ouvert
bool s_open = false;
int s_focus = 0;                // tuile en focus (ordre de StreamPainter : resume, brightness, volume…)
bool s_armed = false;           // A enfoncé dans le menu : l'action part au relâché
int s_stickX = 0, s_stickY = 0;
QSize s_screen;
QString s_game;
QStringList s_power;
QString s_layout;
QString s_exit;
QImage s_cover;                         // jaquette du jeu (en-tête)
QString s_host;
int s_latency = -1;                     // vers le PC (ms), mise à jour par les statistiques
qint64 s_startedAt = 0;                 // début de la partie (ms depuis l'époque) ; 0 : inconnu
int s_battery = -1;
QString s_batteryLife;                  // « environ 3 h 10 » (carte d'alimentation)
QString s_batteryShort;                 // « 3 h 10 » (statistiques)
std::atomic<int> s_stats { 0 };         // statistiques : StreamPainter::Stats::Mode (réglage mémorisé)
QVector<qreal> s_latencyHistory;        // latence totale, une valeur par seconde (la courbe)
StreamPainter::Stats s_statsView;       // les dernières reçues
std::atomic<bool> s_wantFrame { false };    // le menu attend une image du jeu
QImage s_backdrop;                      // l'image du jeu floutée, à la taille de l'écran

// Animations (StreamPainter::Frame) et le minuteur qui les fait avancer.
Anim s_openMs, s_closing, s_veil, s_blurMix, s_swap, s_statsFade;
QVector<Anim> s_highlight;              // par tuile
int s_swapTile = -1;
QString s_swapFrom;
bool s_powerOpen = false;               // la carte d'alimentation est ouverte
int s_powerFocus = 0;
Anim s_powerMix;
QVector<Anim> s_powerHighlight;
Anim s_curtain;                         // fondu au noir avant de quitter le flux
int s_repeatKey = 0;                    // direction tenue (bouton de la croix), répétée par le minuteur
Uint32 s_repeatAt = 0;
int s_repeats = 0;
QString s_leaving;                      // action choisie, le temps du fondu au noir
bool s_finishPending = false;           // finishLeave à lancer, hors du verrou
bool s_quitPassing = false;             // le SDL_QUIT de finishLeave : il ferme le flux
QObject* s_system = nullptr;            // SystemStatus (volume, luminosité), fil principal seulement
int s_volume = -1;                      // ses valeurs, gardées ici (lues sur tous les fils) ; -1 : absent
int s_brightness = -1;
Anim s_volumeAnim, s_brightnessAnim;    // leurs curseurs, qui glissent (en %)
bool s_dragSlider = false;              // la souris tient un curseur
// Par-dessus le jeu, hors du menu (StreamPainter::Overlay).
StreamPainter::Banner s_banner;         // la bannière en cours, en haut
Anim s_bannerIn, s_bannerOut;
SDL_TimerID s_bannerTimer = 0;
int s_pads = 0;                         // manettes branchées à la dernière seconde
bool s_paused = false;                  // la carte « Manette déconnectée » est là
Anim s_pauseShow, s_pauseBack, s_pauseBackdrop;
SDL_TimerID s_pauseTimer = 0;
QImage s_pauseImage;                    // l'image du jeu floutée, sous la carte
std::atomic<bool> s_wantPauseFrame { false };
QImage s_shotImage;                     // la dernière capture, réduite (sa vignette)
QString s_shotTitle;
Anim s_flash, s_shotFly, s_shotLabel, s_shotOut;
SDL_TimerID s_shotTimer = 0;
bool s_batteryLow = false;              // batterie de la console très faible : déjà dit
std::atomic<bool> s_shotWanted { false };   // une capture d'écran attend la prochaine image
QString s_shotSub;                      // sous-titre de la tuile Capture (« Capture… »…) ; vide : l'habituel
int s_poorSeconds = 0;                  // réseau mauvais depuis… (s), bon depuis…
int s_goodSeconds = 0;
bool s_poorNoticed = false;
bool s_batteryNoticed = false;
Anim s_hold, s_holdDone;                // appui maintenu sur Quitter le jeu, puis sa coche
bool s_holding = false;                 // A (ou le clic) tenu sur la tuile à maintenir
Uint32 s_holdDoneAt = 0;                // plein à cet instant ; 0 : pas encore
bool s_wasAnimating = false;            // la dernière image dessinée était en mouvement
SDL_TimerID s_timer = 0;
bool s_dirty = false;                   // une image est demandée (requestRender)

// Dernière image décodée, gardée pendant que le menu est à l'écran pour être
// réaffichée (frameToRepeat). Fil du décodeur seulement.
AVFrame* s_lastFrame = nullptr;
std::atomic<bool> s_keepFrames { false };
std::atomic<bool> s_repeat { false };       // l'overlay a changé depuis la dernière image
std::atomic<Uint32> s_lastFrameTicks { 0 };

bool s_soundsOn = false;
double s_haptics = HAPTICS_DEFAULT;     // intensité des vibrations (0 : coupées)
bool s_reducedMotion = false;           // « Réduire les animations » : ni cascade ni fondu d'entrée
std::atomic<bool> s_fadedIn { false };  // le flux a eu son fondu d'entrée
QHash<QString, QByteArray> s_sounds;    // échantillons, volume appliqué
SDL_AudioDeviceID s_audio = 0;

// Textes du menu, contexte de traduction « StreamMenu » (Text::tr, que lupdate sait lire).
struct Text { Q_DECLARE_TR_FUNCTIONS(StreamMenu) };

QString statsValue(int mode)
{
    return mode == StreamPainter::Stats::Detailed ? Text::tr("Détaillées")
         : mode == StreamPainter::Stats::Compact ? Text::tr("Compactes") : Text::tr("Masquées");
}

// Le réglage : 0 masquées, 1 détaillées, 2 compactes (« true » d'avant : détaillées).
int readStatsMode()
{
    const QString value = QSettings().value(STATS_SETTING, 0).toString();
    return value == QLatin1String("true") ? 1 : qBound(0, value.toInt(), 2);
}

QString percent(int value)
{
    return Text::tr("%1 %").arg(value);
}

// « 1 h 24 min », « 24 min » : la durée de la partie.
QString duration(qint64 ms)
{
    const qint64 minutes = qMax<qint64>(1, ms / 60000);
    return minutes < 60 ? Text::tr("%1 min").arg(minutes)
                        : Text::tr("%1 h %2 min").arg(minutes / 60).arg(minutes % 60);
}

// Les tuiles, dans l'ordre de la grille (StreamPainter) ; leurs voisines à la croix.
enum { RESUME, BRIGHTNESS, VOLUME, SHOT, STATS, HOME, QUIT, SLEEP, POWER, TILES };
// Vers le haut, le bas, la gauche, la droite ; -1 : bord. Sur un curseur, haut et bas le règlent.
const int NEIGHBOURS[4][TILES] = {
    { -1, -1, -1, RESUME, RESUME, SHOT, STATS, BRIGHTNESS, VOLUME },
    { SHOT, -1, -1, HOME, QUIT, -1, -1, -1, -1 },
    { -1, RESUME, BRIGHTNESS, -1, SHOT, -1, HOME, QUIT, SLEEP },
    { BRIGHTNESS, VOLUME, -1, STATS, BRIGHTNESS, QUIT, SLEEP, POWER, -1 },
};

bool hasPower()
{
    return s_power.contains(QLatin1String("reboot")) || s_power.contains(QLatin1String("poweroff"));
}

bool enabled(int tile)
{
    switch (tile) {
    case BRIGHTNESS: return s_brightness >= 0;
    case VOLUME: return s_volume >= 0;
    case SLEEP: return s_power.contains(QLatin1String("suspend"));
    case POWER: return hasPower();
    default: return true;
    }
}

bool isSlider(int tile)
{
    return tile == BRIGHTNESS || tile == VOLUME;
}

// Quitter le jeu : pas de confirmation, la tuile elle-même se maintient (A, Entrée ou le clic
// tenus), comme « Quitter la partie » à l'accueil.
bool holdTile()
{
    return s_focus == QUIT && !s_powerOpen;
}

QStringList powerKeys()
{
    QStringList keys;
    for (const char* key : { "suspend", "reboot", "poweroff" }) {
        if (s_power.contains(QLatin1String(key))) {
            keys.append(QLatin1String(key));
        }
    }
    return keys;
}

StreamPainter::Control control()
{
    StreamPainter::Control control;
    control.game = s_game.isEmpty() ? Text::tr("Menu") : s_game;
    control.status = s_startedAt > 0 ? Text::tr("En pause · %1").arg(duration(QDateTime::currentMSecsSinceEpoch() - s_startedAt))
                                     : Text::tr("En pause");
    control.cover = s_cover;
    control.host = s_host;
    control.latency = s_latency > 0 ? Text::tr("%1 ms").arg(s_latency) : QString();
    control.time = QTime::currentTime().toString(QStringLiteral("HH:mm"));
    control.battery = s_battery;
    control.focus = s_focus;
    control.tiles = {
        { QStringLiteral("resume"), Text::tr("Reprendre"), Text::tr("Retour au jeu") },
        { QStringLiteral("brightness"), Text::tr("Luminosité"), s_brightness >= 0 ? percent(s_brightness) : QString(),
          s_brightness >= 0 ? s_brightness / 100.0 : 0 },
        { QStringLiteral("volume"), Text::tr("Volume"), s_volume >= 0 ? percent(s_volume) : QString(),
          s_volume >= 0 ? s_volume / 100.0 : 0 },
        { QStringLiteral("shot"), Text::tr("Capture"), s_shotSub.isEmpty() ? Text::tr("Sur la console") : s_shotSub },
        { QStringLiteral("stats"), Text::tr("Statistiques"), statsValue(s_stats) },
        { QStringLiteral("home"), Text::tr("Accueil"), QString() },
        { QStringLiteral("quit"), Text::tr("Quitter le jeu"), QString() },
        { QStringLiteral("sleep"), Text::tr("Veille"), QString() },
        { QStringLiteral("power"), Text::tr("Alimentation"), Text::tr("Redémarrer · Éteindre") },
    };
    for (int i = 0; i < TILES; i++) {
        control.tiles[i].enabled = enabled(i);
    }
    control.activateLabel = holdTile() ? Text::tr("Maintenir") : Text::tr("Activer");
    return control;
}

StreamPainter::Power powerCard()
{
    StreamPainter::Power power;
    if (s_battery >= 0) {
        power.header = s_batteryLife.isEmpty() ? Text::tr("Batterie %1 %").arg(s_battery)
                                               : Text::tr("Batterie %1 % · %2").arg(s_battery).arg(s_batteryLife);
    }
    power.keys = powerKeys();
    for (const QString& key : power.keys) {
        power.labels.append(key == QLatin1String("suspend") ? Text::tr("Mise en veille")
                          : key == QLatin1String("reboot") ? Text::tr("Redémarrer") : Text::tr("Éteindre"));
    }
    power.focus = s_powerFocus;
    power.note = Text::tr("Le stream en cours sera fermé proprement avant l'arrêt.");
    return power;
}

void resetHighlights(int focus)
{
    s_highlight = QVector<Anim>(TILES);
    for (int i = 0; i < TILES; i++) {
        s_highlight[i].set(i == focus ? 1 : 0);
    }
}

StreamPainter::Frame frame(Uint32 now)
{
    StreamPainter::Frame frame;
    frame.control = control();
    for (const Anim& highlight : s_highlight) {
        frame.tileFocus.append(highlight.at(now));
    }
    frame.control.tiles[BRIGHTNESS].value = qMax(0.0, s_brightnessAnim.at(now) / 100);
    frame.control.tiles[VOLUME].value = qMax(0.0, s_volumeAnim.at(now) / 100);
    frame.openMs = s_openMs.at(now);
    frame.closing = s_closing.at(now);
    frame.swapTile = s_swapTile;
    frame.swapFrom = s_swapFrom;
    frame.swapProgress = s_swap.at(now);
    frame.power = powerCard();
    frame.powerMix = s_powerMix.at(now);
    for (const Anim& highlight : s_powerHighlight) {
        frame.powerFocus.append(highlight.at(now));
    }
    frame.veil = s_veil.at(now);
    frame.blurMix = s_blurMix.at(now);
    frame.backdrop = s_backdrop;
    frame.stats = s_statsView;
    frame.statsOpacity = s_statsFade.at(now);
    frame.layout = s_layout;
    frame.curtain = s_curtain.at(now);
    frame.hold = qPow(s_hold.at(now), HOLD_CURVE);
    frame.holdDone = s_holdDone.at(now);
    frame.doneLabel = Text::tr("Fermeture du jeu");
    return frame;
}

bool animating(Uint32 now)
{
    for (const Anim* anim : { &s_openMs, &s_closing, &s_veil, &s_blurMix, &s_swap, &s_statsFade, &s_curtain,
                              &s_hold, &s_holdDone, &s_volumeAnim, &s_brightnessAnim, &s_powerMix,
                              &s_bannerIn, &s_bannerOut, &s_pauseShow, &s_pauseBack, &s_pauseBackdrop,
                              &s_flash, &s_shotFly, &s_shotLabel, &s_shotOut }) {
        if (anim->running(now)) {
            return true;
        }
    }
    for (const QVector<Anim>* list : { &s_highlight, &s_powerHighlight }) {
        for (const Anim& highlight : *list) {
            if (highlight.running(now)) {
                return true;
            }
        }
    }
    return s_paused && s_pauseBack.at(now) < 1;   // la roue d'attente tourne
}

// Arrête toutes les animations là où elles en sont.
void freeze(Uint32 now)
{
    for (Anim* anim : { &s_openMs, &s_closing, &s_veil, &s_blurMix, &s_swap, &s_statsFade, &s_curtain,
                        &s_hold, &s_holdDone, &s_volumeAnim, &s_brightnessAnim, &s_powerMix,
                        &s_bannerIn, &s_bannerOut, &s_pauseShow, &s_pauseBack, &s_pauseBackdrop,
                        &s_flash, &s_shotFly, &s_shotLabel, &s_shotOut }) {
        anim->set(anim->at(now));
    }
    for (QVector<Anim>* list : { &s_highlight, &s_powerHighlight }) {
        for (Anim& highlight : *list) {
            highlight.set(highlight.at(now));
        }
    }
}

// --- Sons ---

// Fil de Qt (prepare) : les fichiers sont dans les ressources de l'application.
void loadSounds()
{
    if (!s_sounds.isEmpty()) {
        return;
    }
    for (const char* name : SOUND_NAMES) {
        QFile file(QStringLiteral(":/gui/console/sounds/%1.wav").arg(QLatin1String(name)));
        if (!file.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QByteArray wav = file.readAll();
        SDL_AudioSpec spec;
        Uint8* buffer = nullptr;
        Uint32 length = 0;
        if (SDL_LoadWAV_RW(SDL_RWFromConstMem(wav.constData(), wav.size()), 1, &spec, &buffer, &length) == nullptr) {
            continue;
        }
        if (spec.format == AUDIO_S16SYS && spec.channels == SOUND_CHANNELS && spec.freq == SOUND_RATE) {
            QByteArray samples(reinterpret_cast<const char*>(buffer), length);
            int16_t* data = reinterpret_cast<int16_t*>(samples.data());
            for (int i = 0; i < samples.size() / 2; i++) {
                data[i] = int16_t(data[i] * SOUND_VOLUME);
            }
            s_sounds.insert(QLatin1String(name), samples);
        }
        SDL_FreeWAV(buffer);
    }
}

// Un son à la fois, comme à l'accueil : le suivant coupe le précédent.
void play(const char* name)
{
    if (s_haptics > 0) {
        StreamMenu::rumble(QLatin1String(name), s_haptics);
    }
    const QByteArray samples = s_sounds.value(QLatin1String(name));
    if (!s_soundsOn || samples.isEmpty()) {
        return;
    }
    if (s_audio == 0) {
        if (SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
            s_soundsOn = false;
            return;
        }
        SDL_AudioSpec want;
        SDL_zero(want);
        want.freq = SOUND_RATE;
        want.format = AUDIO_S16SYS;
        want.channels = SOUND_CHANNELS;
        want.samples = 512;
        s_audio = SDL_OpenAudioDevice(nullptr, 0, &want, nullptr, 0);
        if (s_audio == 0) {
            SDL_QuitSubSystem(SDL_INIT_AUDIO);
            s_soundsOn = false;   // pas de sortie son : on n'insiste pas pendant ce flux
            return;
        }
        SDL_PauseAudioDevice(s_audio, 0);
    }
    SDL_ClearQueuedAudio(s_audio);
    SDL_QueueAudio(s_audio, samples.constData(), samples.size());
}

void closeAudio()
{
    if (s_audio != 0) {
        SDL_CloseAudioDevice(s_audio);
        SDL_QuitSubSystem(SDL_INIT_AUDIO);
        s_audio = 0;
    }
}

// --- Image ---

// La taille de la fenêtre du flux, en pixels : l'overlay s'y pose sans mise à
// l'échelle. Fil SDL seulement.
QSize screenSize()
{
    SDL_Window* window = SDL_GetKeyboardFocus();
    if (window == nullptr) {
        window = SDL_GetMouseFocus();
    }
    int width = 0, height = 0;
    if (window != nullptr) {
#if SDL_VERSION_ATLEAST(2, 26, 0)
        SDL_GetWindowSizeInPixels(window, &width, &height);
#else
        SDL_GetWindowSize(window, &width, &height);
#endif
    }
    SDL_DisplayMode mode;
    if ((width <= 0 || height <= 0) && SDL_GetCurrentDisplayMode(0, &mode) == 0) {
        width = mode.w;
        height = mode.h;
    }
    return QSize(width, height);
}

SDL_Surface* toSurface(const QImage& image)
{
    if (image.isNull()) {
        return nullptr;
    }
    const QImage argb = image.convertToFormat(QImage::Format_ARGB32);   // = SDL_PIXELFORMAT_ARGB8888
    SDL_Surface* surface = SDL_CreateRGBSurfaceWithFormat(0, argb.width(), argb.height(), 32, SDL_PIXELFORMAT_ARGB8888);
    if (surface == nullptr) {
        return nullptr;
    }
    for (int y = 0; y < argb.height(); y++) {
        memcpy((uint8_t*)surface->pixels + y * surface->pitch, argb.constScanLine(y), argb.width() * 4);
    }
    return surface;
}

// Le menu dessiné directement dans la mémoire d'une surface SDL (ni conversion ni
// copie d'une image entière : à 2560 × 1600, elle pèse 16 Mo).
SDL_Surface* menuSurface(const StreamPainter::Frame& frame, QSize screen)
{
    SDL_Surface* surface = SDL_CreateRGBSurfaceWithFormat(0, screen.width(), screen.height(), 32,
                                                          SDL_PIXELFORMAT_ARGB8888);
    if (surface == nullptr) {
        return nullptr;
    }
    QImage image(static_cast<uchar*>(surface->pixels), surface->w, surface->h, surface->pitch,
                 QImage::Format_ARGB32_Premultiplied);
    if (!StreamPainter::paintFrame(frame, image)) {
        // Transparente par endroits (fondus) : Moonlight attend un alpha non prémultiplié.
        // La conversion de Qt est vectorisée ; si elle ne se fait pas sur place, on recopie.
        image.convertTo(QImage::Format_ARGB32);
        if (image.constBits() != surface->pixels) {
            for (int y = 0; y < surface->h; y++) {
                memcpy(static_cast<uchar*>(surface->pixels) + y * surface->pitch, image.constScanLine(y), surface->w * 4);
            }
        }
    }
    return surface;
}

void repeatStep(Uint32 now);
void holdStep(Uint32 now);
void resetHold();

// Minuteur SDL (son propre fil) : tout le dessin se fait ici, ni dans le fil de la
// manette ni dans celui du décodeur, et hors du verrou (seules la photo de l'état et
// la pose de l'image le prennent) ; une image par tour tant que quelque chose bouge.
Uint32 tick(Uint32, void*)
{
    Uint32 now;
    QSize screen;
    bool menuShown;
    StreamPainter::Frame view;
    StreamPainter::Overlay overlay;
    {
        QMutexLocker locker(&s_lock);
        if (Session::get() == nullptr || Session::get() != s_session) {
            s_timer = 0;
            return 0;
        }
        now = SDL_GetTicks();
        if (s_repeatKey != 0 && (Sint32)(now - s_repeatAt) >= 0) {
            repeatStep(now);
        }
        holdStep(now);
        // Rien n'a changé (une direction est tenue, entre deux pas ; une confirmation
        // maintenue attend son départ) : pas d'image, mais le minuteur continue.
        const bool moving = animating(now);
        if (!s_dirty && !moving && !s_wasAnimating) {
            if (s_repeatKey != 0 || s_holding || (s_holdDoneAt != 0 && s_leaving.isEmpty())) {
                return FRAME_MS;
            }
            s_timer = 0;
            return 0;
        }
        s_wasAnimating = moving;   // une dernière image aux valeurs finales
        s_dirty = false;
        if (!s_screen.isValid()) {
            SDL_DisplayMode mode;   // pas encore de fenêtre connue : l'écran
            if (SDL_GetCurrentDisplayMode(0, &mode) == 0) {
                s_screen = QSize(mode.w, mode.h);
            }
        }
        screen = s_screen;
        menuShown = s_open || s_veil.at(now) > 0 || s_curtain.at(now) > 0;
        if (menuShown) {
            view = frame(now);
        }
        overlay.stats = s_statsView;
        overlay.statsOpacity = s_statsFade.at(now);
        overlay.banner = s_banner;
        overlay.bannerIn = s_bannerIn.at(now);
        overlay.bannerOut = s_bannerOut.at(now);
        overlay.pause.title = Text::tr("Manette déconnectée");
        overlay.pause.body = Text::tr("Reconnectez la manette pour reprendre.");
        overlay.pause.backTitle = Text::tr("Manette reconnectée");
        overlay.pause.backBody = Text::tr("Reprise du jeu…");
        overlay.pause.waiting = Text::tr("Recherche de la manette…");
        overlay.pauseShow = s_pauseShow.at(now);
        overlay.pauseBack = s_pauseBack.at(now);
        overlay.backdrop = s_pauseImage;
        overlay.backdropShow = s_pauseBackdrop.at(now);
        overlay.spin = (now % 1000) / 1000.0;
        overlay.shot.image = s_shotImage;
        overlay.shot.title = s_shotTitle;
        overlay.shot.sub = Text::tr("sur la console");
        overlay.flash = s_flash.at(now);
        overlay.shotFly = s_shotFly.at(now);
        overlay.shotLabel = s_shotLabel.at(now);
        overlay.shotOut = s_shotOut.at(now);
    }

    // Le menu (ouvert ou en train de se fermer), sinon ce qui est par-dessus le jeu, sinon rien.
    SDL_Surface* surface = menuShown ? menuSurface(view, screen)
                                     : toSurface(StreamPainter::paintOverlay(overlay, screen));

    QMutexLocker locker(&s_lock);
    Session* session = Session::get();
    if (session == nullptr || session != s_session) {
        SDL_FreeSurface(surface);
        s_timer = 0;
        return 0;
    }
    session->getOverlayManager().setOverlaySurface(Overlay::OverlayDebug, surface);

    // Si le PC n'envoie rien, le décodeur réaffiche la dernière image pour que
    // l'overlay apparaisse (FFmpegVideoDecoder::decoderThreadProc, frameToRepeat).
    s_keepFrames = surface != nullptr;
    s_repeat = true;
    if (SDL_GetTicks() - s_lastFrameTicks >= REPEAT_AFTER_MS) {
        LiWakeWaitForVideoFrame();
    }

    if (animating(now) || s_dirty || s_repeatKey != 0 || s_holding || (s_holdDoneAt != 0 && s_leaving.isEmpty())) {
        return FRAME_MS;
    }
    s_timer = 0;
    if (!s_open && s_exit.isEmpty() && s_leaving.isEmpty()) {   // menu refermé (pas quitté : son son finit) :
        s_backdrop = QImage();              // le fond et la sortie son ne servent plus
        closeAudio();
    }
    return 0;
}

// Demande une image au minuteur. s_lock tenu.
void requestRender()
{
    s_dirty = true;
    if (s_timer == 0) {
        s_timer = SDL_AddTimer(1, tick, nullptr);
    }
}

// Le flux en cours ; un nouveau flux repart menu fermé. s_lock tenu.
void attach()
{
    Session* session = Session::get();
    if (session != s_session) {
        s_session = session;
        s_open = false;
        s_veil.set(0);
    }
}

// Batterie de la console (en-tête, carte d'alimentation) : relue à chaque ouverture. Fil
// principal (celui du flux ; Qt y est suspendu, SystemStatus se lit directement).
void readBattery()
{
    if (s_system == nullptr) {
        return;
    }
    s_battery = s_system->property("batteryPercent").toInt();
    const int minutes = s_system->property("batteryDetails").toMap().value(QStringLiteral("minutes"), -1).toInt();
    const bool charging = s_system->property("charging").toBool();
    s_batteryShort = minutes <= 0 || charging ? QString()
                   : minutes < 60 ? Text::tr("%1 min").arg(minutes)
                   : Text::tr("%1 h %2").arg(minutes / 60).arg(minutes % 60, 2, 10, QLatin1Char('0'));
    s_batteryLife = s_batteryShort.isEmpty() ? QString() : Text::tr("environ %1").arg(s_batteryShort);
}

void openMenu()
{
    const Uint32 now = SDL_GetTicks();
    s_open = true;
    s_focus = RESUME;
    s_shotSub.clear();
    resetHold();
    s_armed = false;
    s_stickX = s_stickY = 0;
    s_repeatKey = 0;
    s_leaving.clear();
    s_powerOpen = false;
    s_powerMix.set(0);
    s_curtain.set(0);
    s_screen = screenSize();
    readBattery();
    s_wantFrame = true;   // l'image floutée remplacera le voile (offerFrame)
    if (s_backdrop.isNull()) {
        s_blurMix.set(0);
    }
    s_closing.set(0);
    s_openMs.set(s_reducedMotion ? ENTRY_TOTAL : 0);
    if (!s_reducedMotion) {
        s_openMs.go(ENTRY_TOTAL, ENTRY_TOTAL, now);
    }
    s_veil.go(1, SHEET_DIM_FADE, now);
    s_swap.set(1);
    s_swapTile = -1;
    resetHighlights(RESUME);
    play("ingame_menu_open");
    requestRender();
}

void closeMenu(bool sound = true)
{
    const Uint32 now = SDL_GetTicks();
    s_open = false;
    s_armed = false;
    s_repeatKey = 0;
    s_wantFrame = false;
    s_closing.go(1, CLOSE_MOVE, now, QEasingCurve::Linear);
    s_veil.go(0, SHEET_DIM_FADE, now);
    if (s_powerOpen) {
        s_powerOpen = false;
        s_powerMix.go(0, POWER_OUT, now);
    }
    if (sound) {
        play("ingame_menu_close");
    }
    requestRender();
}

// Quitter le flux : un fondu au noir, puis finishLeave (hors du verrou) ; l'accueil
// fera la suite (ConsoleHome.returnedHome). Le menu ne répond plus entre-temps.
void beginLeave(const QString& action)
{
    s_leaving = action;
    s_repeatKey = 0;
    s_wantFrame = false;
    s_curtain.go(1, CURTAIN_FADE, SDL_GetTicks());
    s_finishPending = true;
    requestRender();
}

// L'anneau passe à la tuile `next` (qui existe et n'est pas la tuile en focus).
void focusTile(int next)
{
    resetHold();
    const Uint32 now = SDL_GetTicks();
    s_highlight[s_focus].go(0, TILE_FOCUS_FADE, now);
    s_highlight[next].go(1, TILE_FOCUS_FADE, now);
    s_focus = next;
    play("focus_tick");
    requestRender();
}

// Carte d'alimentation : le choix `next`.
void focusPower(int next)
{
    const Uint32 now = SDL_GetTicks();
    s_powerHighlight[s_powerFocus].go(0, TILE_FOCUS_FADE, now);
    s_powerHighlight[next].go(1, TILE_FOCUS_FADE, now);
    s_powerFocus = next;
    play("focus_tick");
    requestRender();
}

void openPower(bool open)
{
    const Uint32 now = SDL_GetTicks();
    s_powerOpen = open;
    if (open) {
        const QStringList keys = powerKeys();
        s_powerFocus = qMax(0, keys.indexOf(QStringLiteral("reboot")));
        s_powerHighlight = QVector<Anim>(keys.size());
        for (int i = 0; i < keys.size(); i++) {
            s_powerHighlight[i].set(i == s_powerFocus ? 1 : 0);
        }
    }
    s_powerMix.go(open ? 1 : 0, s_reducedMotion ? 200 : open ? POWER_IN : POWER_OUT, now);
    play(open ? "select" : "ingame_menu_close");
    requestRender();
}

void resetHold()
{
    if (s_holding && s_audio != 0) {
        SDL_ClearQueuedAudio(s_audio);   // le son de l'appui s'arrête avec lui
    }
    s_holding = false;
    s_hold.set(0);
    s_holdDone.set(0);
    s_holdDoneAt = 0;
}

// A (ou le clic) enfoncé sur la tuile à maintenir : elle se remplit.
void startHold()
{
    const Uint32 now = SDL_GetTicks();
    s_holding = true;
    s_hold.go(1, int((1 - s_hold.at(now)) * HOLD_DURATION), now);
    play("hold_fill");
    requestRender();
}

// Lâché avant la fin : elle se vide.
void releaseHold()
{
    if (!s_holding || s_holdDoneAt != 0) {
        return;
    }
    const Uint32 now = SDL_GetTicks();
    s_holding = false;
    s_hold.go(0, int(s_hold.at(now) * HOLD_DRAIN), now);
    if (s_audio != 0) {
        SDL_ClearQueuedAudio(s_audio);   // le son de l'appui s'arrête avec lui
    }
    requestRender();
}

// Fil du minuteur : pleine, la coche arrive ; puis le départ, comme un choix du menu. Le
// fondu et le retour de l'accueil se font sur le fil des événements : un SDL_QUIT l'y
// amène (interceptQuit).
void holdStep(Uint32 now)
{
    if (s_holding && s_holdDoneAt == 0 && s_hold.at(now) >= 1) {
        s_holdDoneAt = now;
        s_holdDone.go(1, HOLD_SWAP, now, QEasingCurve::OutCubic);
        play("hold_done");
    }
    if (s_holdDoneAt != 0 && s_leaving.isEmpty() && now - s_holdDoneAt >= (Uint32)HOLD_FINISH) {
        beginLeave(QStringLiteral("quit"));
        s_holding = false;
        s_holdDoneAt = 0;   // un seul départ : finishLeave vide s_leaving, il ne doit pas repartir
        SDL_Event quit;
        quit.type = SDL_QUIT;
        quit.quit.timestamp = now;
        SDL_PushEvent(&quit);
    }
}

int setValue(int tile, int wanted, bool dragged);

// Une direction de la croix (0 haut, 1 bas, 2 gauche, 3 droite) : la tuile voisine (les
// indisponibles sont sautées), ou, sur un curseur, haut et bas le règlent ; dans la carte
// d'alimentation, gauche et droite. Renvoie le réglage à appliquer (-1 : aucun) dans `value`,
// et faux à un bord.
bool move(int direction, int* value)
{
    *value = -1;
    if (s_powerOpen) {
        const int next = s_powerFocus + (direction == 2 ? -1 : direction == 3 ? 1 : 0);
        if (direction < 2 || next < 0 || next >= s_powerHighlight.size()) {
            play("nav_edge");
            return false;
        }
        focusPower(next);
        return true;
    }
    if (isSlider(s_focus) && direction < 2) {
        const int current = s_focus == VOLUME ? s_volume : s_brightness;
        const int floor = current / VALUE_STEP * VALUE_STEP;
        const int wanted = direction == 0 ? floor + VALUE_STEP : (current == floor ? floor - VALUE_STEP : floor);
        *value = setValue(s_focus, wanted, false);
        return *value >= 0;
    }
    int next = NEIGHBOURS[direction][s_focus];
    while (next >= 0 && !enabled(next)) {
        next = NEIGHBOURS[direction][next];
    }
    if (next < 0) {
        play("nav_edge");
        return false;
    }
    focusTile(next);
    return true;
}

// Croix ou stick enfoncés : une marche tout de suite, la suite par le minuteur.
int press(int direction)
{
    int value;
    s_repeatKey = move(direction, &value) ? direction + 1 : 0;
    s_repeats = 0;
    s_repeatAt = SDL_GetTicks() + REPEAT_DELAY;
    requestRender();   // le minuteur tourne tant que la direction est tenue
    return value;
}

void applySettingLater(int tile, int value);

// Fil du minuteur : la répétition s'arrête au bord (ou au bout d'un curseur).
void repeatStep(Uint32 now)
{
    int value;
    if (!s_open || !s_leaving.isEmpty() || !move(s_repeatKey - 1, &value)) {
        s_repeatKey = 0;
        return;
    }
    if (value >= 0) {
        applySettingLater(s_focus, value);
    }
    s_repeats++;
    s_repeatAt = now + qMax(REPEAT_MIN, REPEAT_INTERVAL - s_repeats * REPEAT_STEP);
}

// Une bannière en haut (MotionAlertes, MotionReseau) : elle arrive, reste BANNER_HOLD, repart.
// Une nouvelle remplace celle qui est là.
Uint32 hideBanner(Uint32, void*)
{
    QMutexLocker locker(&s_lock);
    s_bannerTimer = 0;
    s_bannerOut.go(1, BANNER_OUT, SDL_GetTicks());
    requestRender();
    return 0;
}

void showBanner(StreamPainter::Banner::Icon icon, bool alert, bool accent, const QString& title, const QString& sub)
{
    const Uint32 now = SDL_GetTicks();
    s_banner.icon = icon;
    s_banner.alert = alert;
    s_banner.accent = accent;
    s_banner.title = title;
    s_banner.sub = sub;
    s_bannerIn.set(0);
    s_bannerIn.go(1, s_reducedMotion ? 200 : BANNER_IN, now);
    s_bannerOut.set(0);
    if (s_bannerTimer != 0) {
        SDL_RemoveTimer(s_bannerTimer);
    }
    s_bannerTimer = SDL_AddTimer(BANNER_HOLD, hideBanner, nullptr);
    requestRender();
}

// Manette déconnectée : la carte paraît sur l'image du jeu floutée (offerFrame la prépare) ;
// revenue, « Manette reconnectée », puis tout s'efface.
Uint32 endPause(Uint32, void*)
{
    QMutexLocker locker(&s_lock);
    const Uint32 now = SDL_GetTicks();
    s_pauseTimer = 0;
    s_paused = false;
    s_pauseShow.go(0, PAUSE_OUT, now);
    s_pauseBackdrop.go(0, PAUSE_OUT, now, QEasingCurve::Linear, 200);
    requestRender();
    return 0;
}

void padsChanged(int count)
{
    const Uint32 now = SDL_GetTicks();
    if (count == 0 && s_pads > 0 && !s_open) {
        s_paused = true;
        s_pauseBack.set(0);
        s_pauseShow.go(1, PAUSE_IN, now, QEasingCurve::Linear, 150);
        s_pauseBackdrop.go(1, PAUSE_IN, now);
        s_wantPauseFrame = true;
        if (s_pauseTimer != 0) {
            SDL_RemoveTimer(s_pauseTimer);
            s_pauseTimer = 0;
        }
        requestRender();
    }
    else if (count > 0 && s_paused && s_pauseTimer == 0) {
        s_pauseBack.go(1, PAUSE_IN, now);
        s_pauseTimer = SDL_AddTimer(PAUSE_RESUME, endPause, nullptr);
        requestRender();
    }
    s_pads = count;
}

// Capture d'écran (MotionCapture) : un flash, l'image se réduit en vignette en bas à gauche,
// l'étiquette paraît ; plus tard, la vignette part à gauche.
Uint32 endShot(Uint32, void*)
{
    QMutexLocker locker(&s_lock);
    const Uint32 now = SDL_GetTicks();
    s_shotTimer = 0;
    s_shotLabel.go(0, 200, now);
    s_shotOut.go(1, SHOT_OUT, now);
    requestRender();
    return 0;
}

void showShot(const QImage& image)
{
    const Uint32 now = SDL_GetTicks();
    s_shotImage = image;
    s_shotTitle = Text::tr("Capture enregistrée");
    s_flash.set(1);
    s_flash.go(0, SHOT_FLASH, now, QEasingCurve::OutCubic, 80);
    s_shotFly.set(0);
    s_shotFly.go(1, SHOT_FLY, now, QEasingCurve::Linear, 150);
    s_shotLabel.set(0);
    s_shotLabel.go(1, 500, now, QEasingCurve::Linear, 500);
    s_shotOut.set(0);
    if (s_shotTimer != 0) {
        SDL_RemoveTimer(s_shotTimer);
    }
    s_shotTimer = SDL_AddTimer(SHOT_HOLD, endShot, nullptr);
    requestRender();
}

// Le sous-titre d'une tuile change : l'ancien sort, le nouveau entre (SwapBox).
void swapSub(int tile, const QString& from)
{
    const Uint32 now = SDL_GetTicks();
    s_swapTile = tile;
    s_swapFrom = from;
    s_swap.set(0);
    s_swap.go(1, SHEET_VALUE_SWAP, now);
    requestRender();
}

// Une capture d'écran : la prochaine image du jeu (ou la dernière, si le PC n'envoie rien),
// prise par le décodeur (captureIfWanted).
void requestShot()
{
    s_shotWanted = true;
    if (s_open) {
        const QString from = control().tiles[SHOT].sub;
        s_shotSub = Text::tr("Capture…");
        swapSub(SHOT, from);
    }
    s_repeat = true;
    LiWakeWaitForVideoFrame();
}

// Le volume ou la luminosité passe à `wanted` : le remplissage glisse, la valeur change (en
// glissant, sauf `dragged` : elle suit la souris). Le réglage lui-même (SystemStatus) se fait
// hors du verrou, par l'appelant : renvoie la valeur à poser, -1 sinon.
int setValue(int tile, int wanted, bool dragged)
{
    const bool volume = tile == VOLUME;
    int& value = volume ? s_volume : s_brightness;
    Anim& anim = volume ? s_volumeAnim : s_brightnessAnim;
    const int next = qBound(volume ? 0 : BRIGHTNESS_MIN, wanted, 100);
    if (next == value) {
        if (!dragged) {
            play(volume ? "volume_limit" : "slider_limit");
        }
        return -1;
    }
    const QString from = percent(value);
    value = next;
    if (dragged) {
        anim.set(next);
        s_swapTile = -1;
        requestRender();
    }
    else {
        anim.go(next, SLIDER_MOVE, SDL_GetTicks(), QEasingCurve::OutCubic);
        swapSub(tile, from);
    }
    play(volume ? "volume_tick" : "brightness_tick");
    return next;
}

// Fil principal (celui du flux : Qt y est suspendu, mais SystemStatus s'appelle directement).
void applySetting(int tile, int value)
{
    if (value < 0 || s_system == nullptr || !isSlider(tile)) {
        return;
    }
    QMetaObject::invokeMethod(s_system, tile == VOLUME ? "setVolume" : "setBrightness",
                              Qt::DirectConnection, Q_ARG(int, value));
}

// Depuis le minuteur (répétition tenue) : le réglage passe par le fil principal.
void applySettingLater(int tile, int value)
{
    if (s_system == nullptr) {
        return;
    }
    QMetaObject::invokeMethod(s_system, tile == VOLUME ? "setVolume" : "setBrightness",
                              Qt::QueuedConnection, Q_ARG(int, value));
}

void back()
{
    if (s_powerOpen) {
        openPower(false);
    }
    else {
        closeMenu();
    }
}

void switchStats()
{
    const Uint32 now = SDL_GetTicks();
    // Masquées → détaillées → compactes → masquées.
    const QString from = statsValue(s_stats);
    s_stats = (s_stats + 1) % 3;
    QSettings().setValue(STATS_SETTING, s_stats.load());
    if (s_open) {
        swapSub(STATS, from);
    }
    if (s_stats == StreamPainter::Stats::Detailed) {
        s_statsView = StreamPainter::Stats();   // elles apparaîtront avec les premiers chiffres
        s_statsView.total = -1;
        s_statsFade.set(0);
    }
    else if (s_stats == StreamPainter::Stats::Compact) {
        s_statsView.mode = StreamPainter::Stats::Compact;   // les mêmes chiffres, en pastille
    }
    else {
        s_statsFade.go(0, STATS_FADE, now);
    }
    requestRender();
}

void activate()
{
    if (s_powerOpen) {
        const QString key = powerKeys().value(s_powerFocus);
        if (!key.isEmpty()) {
            play("select");
            beginLeave(key);   // A suffit (MenuAlimentation)
        }
        return;
    }
    if (holdTile()) {
        return;   // elle se maintient (startHold)
    }
    switch (s_focus) {
    case RESUME:
        play("select");
        closeMenu(false);
        break;
    case STATS:
        play("focus_tick");
        switchStats();
        break;
    case SHOT:
        play("select");
        requestShot();
        break;
    case BRIGHTNESS:
    case VOLUME:
        play("slider_limit");   // haut / bas les règlent
        break;
    case HOME:
        play("select");
        beginLeave(QStringLiteral("home"));
        break;
    case SLEEP:
        play("select");
        beginLeave(QStringLiteral("suspend"));
        break;
    case POWER:
        openPower(true);
        break;
    }
}

// L'image décodée, copiée en mémoire si elle est sur le GPU et réduite `divisor` fois
// (au huitième pour le fond du menu : la moyenne des pixels, un premier flou ; 1 pour une
// capture d'écran). Nulle si le format ne s'y prête pas.
// ponytail: couleurs en BT.601 par défaut, sans HDR ; à régler si le fond tire.
QImage snapshot(const AVFrame* frame, int divisor)
{
    AVFrame* copy = nullptr;
    if (frame->hw_frames_ctx != nullptr) {
        copy = av_frame_alloc();
        if (copy == nullptr || av_hwframe_transfer_data(copy, frame, 0) < 0) {
            av_frame_free(&copy);
            return QImage();
        }
        frame = copy;
    }
    QImage image(qMax(1, frame->width / divisor), qMax(1, frame->height / divisor), QImage::Format_RGB32);
    SwsContext* context = sws_getContext(frame->width, frame->height, (AVPixelFormat)frame->format,
                                         image.width(), image.height(), AV_PIX_FMT_BGRA,   // = Format_RGB32
                                         divisor > 1 ? SWS_AREA : SWS_BILINEAR, nullptr, nullptr, nullptr);
    if (context != nullptr) {
        uint8_t* const data[] = { image.bits() };
        const int linesize[] = { (int)image.bytesPerLine() };
        sws_scale(context, frame->data, frame->linesize, 0, frame->height, data, linesize);
        sws_freeContext(context);
    }
    av_frame_free(&copy);
    return context != nullptr ? image : QImage();
}

// La capture est enregistrée (ou pas) : la ligne du menu le dit, sinon un avis.
void shotDone(bool saved)
{
    QMutexLocker locker(&s_lock);
    if (s_open) {
        const QString from = control().tiles[SHOT].sub;
        s_shotSub = saved ? Text::tr("Enregistrée") : Text::tr("Échec");
        swapSub(SHOT, from);
    }
    else if (!saved) {
        s_shotLabel.set(0);   // (l'étiquette « Capture enregistrée » ne paraîtra pas)
        s_shotTitle.clear();
        showBanner(StreamPainter::Banner::Check, false, false, Text::tr("Capture impossible"), QString());
    }
    play(saved ? "confirm" : "deny");
}

// Fil du décodeur : une capture est demandée, voici l'image. Elle est convertie ici, puis
// enregistrée à part (un PNG en 4K prend son temps) dans Images/CocoOS, au nom du jeu.
void captureIfWanted(const AVFrame* frame)
{
    if (frame == nullptr || !s_shotWanted.exchange(false)) {
        return;
    }
    QString game;
    {
        QMutexLocker locker(&s_lock);
        game = s_game;
    }
    const QImage image = snapshot(frame, 1);
    if (image.isNull()) {
        shotDone(false);
        return;
    }
    // Hors du menu : le flash et la vignette tout de suite, l'enregistrement suit.
    {
        const QImage thumbnail = image.scaledToWidth(qMin(640, image.width()), Qt::SmoothTransformation);
        QMutexLocker locker(&s_lock);
        if (!s_open) {
            showShot(thumbnail);
        }
    }
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + QStringLiteral("/CocoOS");
    const QString name = (game.isEmpty() ? QStringLiteral("CocoOS") : game)
                             .replace(QRegularExpression(QStringLiteral("[/\\:*?\"<>|]")), QStringLiteral(" "));
    const QString path = dir + QLatin1Char('/') + name + QLatin1Char(' ')
                       + QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH.mm.ss")) + QStringLiteral(".png");
    QThreadPool::globalInstance()->start([image, dir, path] {
        const bool saved = QDir().mkpath(dir) && image.save(path);
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "[console-ui] Capture d'écran %s : %s",
                    saved ? "enregistrée" : "impossible", qPrintable(path));
        shotDone(saved);
    });
}

// Chaque seconde (fil du décodeur) : le réseau, mauvais depuis POOR_SECONDS, et la manette,
// presque vide, valent un avis ; une fois par épisode.
void checkHealth(const VIDEO_STATS& stats)
{
    if (stats.lastRtt != 0) {
        const bool poor = stats.lastRtt > POOR_RTT || stats.lastRttVariance > POOR_VARIANCE;
        s_poorSeconds = poor ? s_poorSeconds + 1 : 0;
        s_goodSeconds = poor ? 0 : s_goodSeconds + 1;
        if (s_poorSeconds == POOR_SECONDS && !s_poorNoticed) {
            s_poorNoticed = true;
            showBanner(StreamPainter::Banner::Network, false, false, Text::tr("Réseau instable"),
                       Text::tr("Latence %1 ms · gigue %2 ms").arg(stats.lastRtt).arg(stats.lastRttVariance));
        }
        if (s_goodSeconds >= POOR_SECONDS) {
            s_poorNoticed = false;
        }
    }
    bool low = false;
    int pads = 0;
    if (SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        for (int i = 0; i < SDL_NumJoysticks(); i++) {
            SDL_GameController* gc = SDL_GameControllerFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
            if (gc != nullptr) {
                pads++;
                const SDL_JoystickPowerLevel level = SDL_JoystickCurrentPowerLevel(SDL_GameControllerGetJoystick(gc));
                low |= level == SDL_JOYSTICK_POWER_LOW || level == SDL_JOYSTICK_POWER_EMPTY;
            }
        }
    }
    padsChanged(pads);
    // La batterie de la console (SDL), très faible et hors charge : une bannière, une fois.
    int percent = -1;
    const SDL_PowerState power = SDL_GetPowerInfo(nullptr, &percent);
    const bool critical = power == SDL_POWERSTATE_ON_BATTERY && percent >= 0 && percent <= BATTERY_CRITICAL;
    if (critical && !s_batteryLow) {
        showBanner(StreamPainter::Banner::Battery, true, false, Text::tr("Batterie très faible · %1 %").arg(percent),
                   Text::tr("Branchez la console."));
    }
    s_batteryLow = critical;
    if (low && !s_batteryNoticed) {
        showBanner(StreamPainter::Banner::Pad, false, true, Text::tr("Manette presque vide"), Text::tr("Pensez à la recharger"));
    }
    s_batteryNoticed = low;
}

QString codecName(int videoFormat)
{
    QString codec = (videoFormat & VIDEO_FORMAT_MASK_H264) ? QStringLiteral("H.264")
                  : (videoFormat & VIDEO_FORMAT_MASK_H265) ? QStringLiteral("HEVC")
                  : (videoFormat & VIDEO_FORMAT_MASK_AV1) ? QStringLiteral("AV1")
                  : QString();
    if (videoFormat & VIDEO_FORMAT_MASK_10BIT) {
        codec += LiGetCurrentHostDisplayHdrMode() ? QStringLiteral(" HDR") : Text::tr(" 10 bits");
    }
    if (videoFormat & VIDEO_FORMAT_MASK_YUV444) {
        codec += QStringLiteral(" 4:4:4");
    }
    return codec;
}

// Les chiffres de Moonlight (ffmpeg.cpp, stringifyVideoStats) pour la carte (StatsOverlay) :
// latence totale (réseau, encodage sur le PC, décodage), sa courbe, l'image, le débit, les
// images perdues, la batterie ; et la pastille compacte. s_lock tenu.
StreamPainter::Stats statsView(const VIDEO_STATS& stats, int videoFormat, int height, double megabitsPerSec)
{
    // Nombres à la façon de la langue de l'interface (réglage Langue ; Auto : celle du système).
    const StreamingPreferences::Language language = StreamingPreferences::get()->language;
    const QLocale locale = language == StreamingPreferences::LANG_EN ? QLocale(QLocale::English)
                         : language == StreamingPreferences::LANG_FR ? QLocale(QLocale::French)
                         : QLocale::system();
    auto number = [&](double value) { return locale.toString(value, 'f', 1); };

    StreamPainter::Stats view;
    view.mode = StreamPainter::Stats::Mode(s_stats.load());
    view.host = s_host;
    const double network = stats.lastRtt;
    const double encode = stats.framesWithHostProcessingLatency != 0
                        ? stats.totalHostProcessingLatency / 10.0 / stats.framesWithHostProcessingLatency : 0;
    const double decode = stats.decodedFrames != 0 ? stats.totalDecodeTimeUs / 1000.0 / stats.decodedFrames : 0;
    if (stats.lastRtt == 0) {
        view.total = -1;   // pas encore de mesure du réseau
        return view;
    }
    view.total = qRound(network + encode + decode);
    // Les seuils de la pastille de l'accueil (Format.networkQuality).
    const bool good = stats.lastRtt <= 20 && stats.lastRttVariance <= 5;
    const bool fair = stats.lastRtt <= 50 && stats.lastRttVariance <= 15;
    view.quality = (good ? Text::tr("Excellent") : fair ? Text::tr("Correct") : Text::tr("Faible")).toUpper();
    s_latencyHistory.append(view.total);
    while (s_latencyHistory.size() > STATS_HISTORY) {
        s_latencyHistory.removeFirst();
    }
    view.history = s_latencyHistory;

    const QString ms = Text::tr("%1 ms");
    view.labels.append(Text::tr("Réseau"));
    view.values.append(ms.arg(stats.lastRtt));
    if (encode > 0) {
        view.labels.append(Text::tr("Encodage sur le PC"));
        view.values.append(ms.arg(number(encode)));
    }
    if (decode > 0) {
        view.labels.append(Text::tr("Décodage"));
        view.values.append(ms.arg(number(decode)));
    }
    view.labels.append(QString());
    view.values.append(QString());
    const QString codec = codecName(videoFormat);
    view.labels.append(Text::tr("Image"));
    view.values.append(Text::tr("%1p · %2 i/s").arg(height).arg(qRound(stats.decodedFps))
                       + (codec.isEmpty() ? QString() : QStringLiteral(" · ") + codec));
    view.labels.append(Text::tr("Débit"));
    view.values.append(Text::tr("%1 Mb/s").arg(number(megabitsPerSec)));
    if (stats.totalFrames != 0) {
        view.labels.append(Text::tr("Images perdues"));
        view.values.append(Text::tr("%1 %").arg(number(100.0 * (stats.networkDroppedFrames + stats.pacerDroppedFrames)
                                                       / stats.totalFrames)));
    }
    if (s_battery >= 0) {
        view.labels.append(Text::tr("Batterie"));
        view.values.append(s_batteryShort.isEmpty() ? percent(s_battery)
                                                    : Text::tr("%1 % · %2").arg(s_battery).arg(s_batteryShort));
    }
    view.compact = QStringList { ms.arg(view.total), Text::tr("%1 i/s").arg(qRound(stats.decodedFps)),
                                 Text::tr("%1 Mb/s").arg(qRound(megabitsPerSec)) };
    if (s_battery >= 0) {
        view.compact.append(percent(s_battery));
    }
    return view;
}

}

namespace {

// La fenêtre de l'accueil (cachée par StreamSegue pendant le flux) revient sous ou
// sur la fenêtre du flux, noire elle aussi (StreamCurtain, posé au début du flux) :
// quand la fenêtre du flux se fermera, l'écran restera noir, sans laisser voir le
// bureau. Qt est suspendu pendant le flux : on le fait tourner le temps qu'elle
// affiche une image. Fil SDL principal, hors du verrou.
QQuickWindow* homeWindow()
{
    for (QWindow* candidate : QGuiApplication::topLevelWindows()) {
        if (QQuickWindow* window = qobject_cast<QQuickWindow*>(candidate)) {
            return window;
        }
    }
    return nullptr;
}

void showHomeWindow()
{
    QQuickWindow* window = homeWindow();
    if (window == nullptr || window->isVisible()) {
        return;
    }
    std::atomic<bool> swapped { false };
    const QMetaObject::Connection connection =
        QObject::connect(window, &QQuickWindow::frameSwapped, [&swapped] { swapped = true; });
    window->setVisible(true);
    window->update();
    QElapsedTimer timer;
    timer.start();
    while (!swapped && timer.elapsed() < SHOW_TIMEOUT_MS) {
        QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents, 5);
    }
    QObject::disconnect(connection);
    // Ensuite, Qt est suspendu jusqu'à la fin du flux : le fondu du logo doit être fini.
    const qint64 settled = qMax(timer.elapsed(), qint64(SHOW_REVEAL_MS)) + SHOW_SETTLE_MS;
    while (timer.elapsed() < settled) {   // le compositeur l'affiche à son tour
        QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents, 5);
    }
}

// Fin du fondu au noir, la fenêtre de l'accueil prête : on ferme le flux.
void finishLeave()
{
    SDL_Delay(CURTAIN_FADE + 3 * FRAME_MS);   // le minuteur et le fil d'affichage du flux s'en chargent
    showHomeWindow();
    QMutexLocker locker(&s_lock);
    s_exit = s_leaving == QLatin1String(ENDED) ? QString() : s_leaving;
    s_leaving.clear();
    s_open = false;
    s_quitPassing = true;
    freeze(SDL_GetTicks());   // l'écran reste noir jusqu'à la fermeture de la fenêtre du flux
    SDL_Event quit;
    quit.type = SDL_QUIT;
    quit.quit.timestamp = SDL_GetTicks();
    SDL_PushEvent(&quit);
}

}

void StreamMenu::prepare(const QString& game, const QStringList& powerActions, const QString& buttonLayout,
                         QObject* system, const QVariantMap& info)
{
    // La jaquette (une URL file:// du cache de l'accueil), lue avant de prendre le verrou.
    const QUrl coverUrl(info.value(QStringLiteral("cover")).toString());
    const QImage cover(coverUrl.isLocalFile() ? coverUrl.toLocalFile() : coverUrl.toString());
    QMutexLocker locker(&s_lock);
    s_cover = cover.isNull() ? QImage() : cover.scaledToHeight(160, Qt::SmoothTransformation);
    s_host = info.value(QStringLiteral("host")).toString();
    s_latency = info.value(QStringLiteral("latency"), -1).toInt();
    s_startedAt = info.value(QStringLiteral("startedAt"), 0).toLongLong();
    s_battery = -1;
    s_batteryLife.clear();
    s_batteryShort.clear();
    s_system = system;
    readBattery();
    s_volume = system != nullptr ? system->property("volume").toInt() : -1;
    s_brightness = system != nullptr ? system->property("brightness").toInt() : -1;
    s_volumeAnim.set(s_volume);
    s_brightnessAnim.set(s_brightness);
    s_dragSlider = false;
    s_banner = StreamPainter::Banner();
    s_bannerIn.set(0);
    s_bannerOut.set(0);
    for (SDL_TimerID* timer : { &s_bannerTimer, &s_pauseTimer, &s_shotTimer }) {
        if (*timer != 0) {
            SDL_RemoveTimer(*timer);
            *timer = 0;
        }
    }
    s_pads = 0;
    s_paused = false;
    s_pauseShow.set(0);
    s_pauseBack.set(0);
    s_pauseBackdrop.set(0);
    s_pauseImage = QImage();
    s_wantPauseFrame = false;
    s_shotImage = QImage();
    s_flash.set(0);
    s_shotFly.set(0);
    s_shotLabel.set(0);
    s_shotOut.set(0);
    s_batteryLow = false;
    s_shotWanted = false;
    s_poorSeconds = s_goodSeconds = 0;
    s_poorNoticed = s_batteryNoticed = false;
    closeAudio();
    s_session = nullptr;
    s_open = false;
    s_exit.clear();
    s_quitPassing = false;
    s_game = game;
    s_power = powerActions;
    s_layout = buttonLayout;
    s_screen = QSize();
    s_wantFrame = false;
    s_backdrop = QImage();
    s_veil.set(0);
    s_closing.set(0);
    s_powerOpen = false;
    s_powerMix.set(0);
    s_stats = readStatsMode();
    s_latencyHistory.clear();
    s_statsView = StreamPainter::Stats();
    s_statsFade.set(0);   // les statistiques apparaissent avec les premiers chiffres
    s_soundsOn = QSettings().value(SOUNDS_SETTING, true).toBool();
    s_haptics = QSettings().value(HAPTICS_SETTING, HAPTICS_DEFAULT).toDouble();
    s_reducedMotion = QSettings().value(MOTION_SETTING, false).toBool();
    s_fadedIn = false;
    if (s_soundsOn) {
        loadSounds();
    }
}

QString StreamMenu::takeExit()
{
    QMutexLocker locker(&s_lock);
    closeAudio();
    const QString exit = s_exit;
    s_exit.clear();
    return exit;
}

bool StreamMenu::isOpen()
{
    QMutexLocker locker(&s_lock);
    return s_open && s_session == Session::get();
}

void StreamMenu::toggle()
{
    QMutexLocker locker(&s_lock);
    attach();
    if (s_open) {
        closeMenu();
    }
    else {
        openMenu();
    }
}

void StreamMenu::onButton(uint8_t button, bool pressed)
{
    int tile = -1;        // volume ou luminosité réglés : appliqués hors du verrou
    int settingValue = -1;
    {
        QMutexLocker locker(&s_lock);
        if (!s_open || !s_leaving.isEmpty() || s_holdDoneAt != 0) {
            return;
        }
        const int direction = button == SDL_CONTROLLER_BUTTON_DPAD_UP ? 0
                            : button == SDL_CONTROLLER_BUTTON_DPAD_DOWN ? 1
                            : button == SDL_CONTROLLER_BUTTON_DPAD_LEFT ? 2
                            : button == SDL_CONTROLLER_BUTTON_DPAD_RIGHT ? 3 : -1;
        if (!pressed) {
            if (direction >= 0 && direction + 1 == s_repeatKey) {
                s_repeatKey = 0;
            }
            if (button == SDL_CONTROLLER_BUTTON_A && s_holding) {
                releaseHold();
            }
            else if (button == SDL_CONTROLLER_BUTTON_A && s_armed) {
                s_armed = false;
                activate();
            }
        }
        else if (direction >= 0) {
            tile = s_focus;
            settingValue = press(direction);
        }
        else if (button == SDL_CONTROLLER_BUTTON_A && holdTile()) {
            startHold();
        }
        else if (button == SDL_CONTROLLER_BUTTON_A) {
            s_armed = true;
        }
        else if (button == SDL_CONTROLLER_BUTTON_B) {
            back();
        }
        if (!s_finishPending) {
            locker.unlock();
            applySetting(tile, settingValue);
            return;
        }
        s_finishPending = false;
    }
    finishLeave();
}

void StreamMenu::screenshot()
{
    QMutexLocker locker(&s_lock);
    attach();
    if (s_leaving.isEmpty()) {
        requestShot();
    }
}

void StreamMenu::onPointer(int x, int y, int button, bool pressed)
{
    int tile = -1;        // volume ou luminosité tirés : appliqués hors du verrou
    int settingValue = -1;
    {
        QMutexLocker locker(&s_lock);
        if (!s_open || !s_leaving.isEmpty() || s_holdDoneAt != 0) {
            return;
        }
        // Points de la fenêtre → pixels de l'écran (s_screen).
        SDL_Window* window = SDL_GetMouseFocus();
        int width = 0, height = 0;
        if (window != nullptr) {
            SDL_GetWindowSize(window, &width, &height);
        }
        const qreal scale = width > 0 ? qreal(s_screen.width()) / width : 1;
        const QPointF at = QPointF(x, y) * scale;

        if (s_powerOpen) {
            // Carte d'alimentation : survol, clic ; à côté de la carte ou clic droit : comme B.
            const int item = StreamPainter::powerAt(powerCard(), s_screen, at);
            if (item >= 0 && item != s_powerFocus) {
                focusPower(item);
            }
            if (button == SDL_BUTTON_LEFT && pressed) {
                s_armed = item >= 0;
                if (item == -2) {
                    back();
                }
            }
            else if (button == SDL_BUTTON_LEFT && s_armed) {
                s_armed = false;
                if (item == s_powerFocus) {
                    activate();
                }
            }
            else if (button == SDL_BUTTON_RIGHT && pressed) {
                back();
            }
        }
        else {
            const int hit = StreamPainter::tileAt(control(), s_screen, at);
            if (hit >= 0 && hit != s_focus && enabled(hit) && !s_holding && !s_dragSlider) {
                focusTile(hit);
            }
            // Un curseur (volume, luminosité) : cliqué, il se règle à cette hauteur ; tiré, il suit.
            if (button == SDL_BUTTON_LEFT && pressed && hit >= 0 && isSlider(hit) && enabled(hit)) {
                s_dragSlider = true;
            }
            else if (button == SDL_BUTTON_LEFT && !pressed && s_dragSlider) {
                s_dragSlider = false;
                s_armed = false;
                button = 0;   // (rien d'autre à faire de ce relâché)
            }
            if (s_dragSlider && isSlider(s_focus)) {
                const qreal fraction = StreamPainter::sliderAt(s_focus, s_screen, at);
                tile = s_focus;
                settingValue = setValue(s_focus, qRound(fraction * 100 / VALUE_STEP) * VALUE_STEP, true);
            }
            if (button == SDL_BUTTON_LEFT && pressed && s_dragSlider) {
                // (un clic sur un curseur ne fait que le régler)
            }
            else if (button == SDL_BUTTON_LEFT && pressed) {
                s_armed = hit >= 0 && !holdTile();
                if (hit >= 0 && holdTile()) {
                    startHold();   // le clic se maintient, comme A
                }
                else if (hit < 0) {
                    back();     // à côté des tuiles : comme B
                }
            }
            else if (button == SDL_BUTTON_LEFT && s_holding) {
                releaseHold();
            }
            else if (button == SDL_BUTTON_LEFT && s_armed) {
                s_armed = false;
                if (hit == s_focus) {
                    activate();
                }
            }
            else if (button == SDL_BUTTON_RIGHT && pressed) {
                back();
            }
        }
        if (!s_finishPending) {
            locker.unlock();
            applySetting(tile, settingValue);
            return;
        }
        s_finishPending = false;
    }
    finishLeave();
}

void StreamMenu::onAxis(uint8_t axis, int16_t value)
{
    if (axis != SDL_CONTROLLER_AXIS_LEFTX && axis != SDL_CONTROLLER_AXIS_LEFTY) {
        return;
    }
    int tile = -1, settingValue = -1;
    {
        QMutexLocker locker(&s_lock);
        if (!s_open || !s_leaving.isEmpty() || s_holdDoneAt != 0) {
            return;
        }
        // Stick gauche : comme la croix (0 haut, 1 bas, 2 gauche, 3 droite).
        const bool vertical = axis == SDL_CONTROLLER_AXIS_LEFTY;
        int& stick = vertical ? s_stickY : s_stickX;
        const int sign = value <= -STICK_PUSH ? -1 : value >= STICK_PUSH ? 1 : 0;
        const int direction = sign == 0 ? -1 : vertical ? (sign < 0 ? 0 : 1) : (sign < 0 ? 2 : 3);
        if (sign != 0 && sign != stick) {
            tile = s_focus;
            settingValue = press(direction);
        }
        else if (sign == 0 && qAbs(value) < STICK_REST && stick != 0) {
            const int held = vertical ? (stick < 0 ? 0 : 1) : (stick < 0 ? 2 : 3);
            if (s_repeatKey == held + 1) {
                s_repeatKey = 0;   // stick revenu au repos
            }
        }
        if (sign != 0 || qAbs(value) < STICK_REST) {
            stick = sign;
        }
    }
    applySetting(tile, settingValue);
}

// --- Vibrations : un motif de haptics.json, pas après pas, par un minuteur SDL ---

namespace {

QMutex s_rumbleLock;
const Haptics::Pattern* s_rumblePattern = nullptr;
int s_rumbleStep = 0;
double s_rumbleLevel = 0;
int s_rumbleRun = 0;            // numéro du motif en cours : un ancien minuteur s'arrête seul
const Uint32 RUMBLE_SLACK_MS = 20;   // chaque pas dure un peu plus : le suivant le remplace sans trou

void setRumble(double low, double high, Uint32 ms)
{
    for (int i = 0; i < SDL_NumJoysticks(); i++) {
        SDL_GameController* gc = SDL_GameControllerFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
        if (gc != nullptr) {
            SDL_GameControllerRumble(gc, Uint16(low * s_rumbleLevel * 0xFFFF),
                                     Uint16(high * s_rumbleLevel * 0xFFFF), ms);
        }
    }
}

// Joue le pas suivant (verrou pris) ; rend sa durée, 0 une fois le motif fini.
Uint32 nextRumbleStep()
{
    if (s_rumblePattern == nullptr || s_rumbleStep >= s_rumblePattern->steps.size()) {
        setRumble(0, 0, 0);
        s_rumblePattern = nullptr;
        return 0;
    }
    const Haptics::Step& step = s_rumblePattern->steps.at(s_rumbleStep++);
    setRumble(step.low, step.high, Uint32(step.ms) + RUMBLE_SLACK_MS);
    return Uint32(step.ms);
}

Uint32 rumbleTimer(Uint32, void* run)
{
    QMutexLocker locker(&s_rumbleLock);
    if (int(reinterpret_cast<intptr_t>(run)) != s_rumbleRun) {
        return 0;
    }
    return nextRumbleStep();
}

}

void StreamMenu::rumble(const QString& sound, double level)
{
    const Haptics::Pattern* pattern = Haptics::forSound(sound);
    if (pattern == nullptr || level <= 0 || !SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        return;
    }
    QMutexLocker locker(&s_rumbleLock);
    s_rumblePattern = pattern;
    s_rumbleStep = 0;
    s_rumbleLevel = level;
    const Uint32 first = nextRumbleStep();
    if (first > 0) {
        SDL_AddTimer(first, rumbleTimer, reinterpret_cast<void*>(intptr_t(++s_rumbleRun)));
    }
}

bool StreamMenu::interceptQuit()
{
    {
        QMutexLocker locker(&s_lock);
        if (s_quitPassing) {
            s_quitPassing = false;
            // Aucun autre SDL_QUIT ne doit survivre au flux : la navigation à la manette de
            // l'accueil (SdlGamepadKeyNavigation) en ferait un « quitter l'application ».
            SDL_FlushEvent(SDL_QUIT);
            return false;
        }
        attach();
        if (!s_leaving.isEmpty() && !s_finishPending) {
            return true;   // un départ est déjà en cours : son SDL_QUIT suivra
        }
        if (!s_screen.isValid()) {
            s_screen = screenSize();
        }
        if (s_finishPending) {   // une confirmation maintenue jusqu'au bout (holdStep)
            s_finishPending = false;
            locker.unlock();
            finishLeave();
            return true;
        }
        // ponytail: connexion perdue, le PC n'envoie plus d'image : le fondu ne paraît que
        // si le décodeur en réaffiche une (statistiques affichées). La fenêtre de l'accueil
        // revient quand même avant que celle du flux se ferme : plus de trou.
        beginLeave(QLatin1String(ENDED));
        s_finishPending = false;
    }
    finishLeave();
    return true;
}

void StreamMenu::toggleStats()
{
    QMutexLocker locker(&s_lock);
    attach();
    s_screen = screenSize();
    play("focus_tick");
    switchStats();
}

bool StreamMenu::wantsStats()
{
    return true;   // chaque seconde : les avis (réseau, manette), même statistiques masquées
}

void StreamMenu::updateStats(const VIDEO_STATS& stats, int videoFormat, int width, int height, double megabitsPerSec)
{
    Q_UNUSED(width);
    QMutexLocker locker(&s_lock);
    attach();
    checkHealth(stats);
    if (stats.lastRtt != 0) {
        s_latency = int(stats.lastRtt);
    }
    if (s_stats == StreamPainter::Stats::Hidden) {
        return;
    }
    const StreamPainter::Stats view = statsView(stats, videoFormat, height, megabitsPerSec);
    if (view.total < 0) {
        return;
    }
    const Uint32 now = SDL_GetTicks();
    if (s_statsView.total < 0 || s_statsView.mode == StreamPainter::Stats::Hidden) {
        s_statsFade.go(1, STATS_FADE, now);
    }
    s_statsView = view;
    requestRender();
}

void StreamMenu::offerFrame(const AVFrame* frame)
{
    captureIfWanted(frame);
    // Cette image portera l'overlay en cours : rien à réafficher.
    s_lastFrameTicks = SDL_GetTicks();
    s_repeat = false;
    av_frame_free(&s_lastFrame);
    if (s_keepFrames) {
        s_lastFrame = av_frame_clone(frame);
    }
    // Première image du flux : elle sort du noir, comme le flux y rentre en partant.
    if (!s_fadedIn.exchange(true)) {
        QMutexLocker locker(&s_lock);
        if (!s_reducedMotion) {
            attach();
            const Uint32 now = SDL_GetTicks();
            s_curtain.set(1);
            s_curtain.go(0, STREAM_FADE_IN, now, QEasingCurve::OutCubic);
            requestRender();
        }
    }

    // Manette déconnectée : l'image floutée sous sa carte.
    if (s_wantPauseFrame.exchange(false)) {
        QSize screen;
        {
            QMutexLocker locker(&s_lock);
            if (!s_screen.isValid()) {
                s_screen = screenSize();
            }
            screen = s_screen;
        }
        const QImage small = snapshot(frame, 8);
        if (!small.isNull() && !screen.isEmpty()) {
            const QImage backdrop = StreamPainter::blurred(small, screen);
            QMutexLocker locker(&s_lock);
            s_pauseImage = backdrop;
            requestRender();
        }
    }

    if (!s_wantFrame || !s_wantFrame.exchange(false)) {
        return;
    }
    QSize screen;
    {
        QMutexLocker locker(&s_lock);
        if (!s_open) {
            return;
        }
        screen = s_screen;
    }
    const QImage small = snapshot(frame, 8);
    if (small.isNull() || screen.isEmpty()) {
        return;   // le voile reste
    }
    const QImage backdrop = StreamPainter::blurred(small, screen);
    QMutexLocker locker(&s_lock);
    if (s_open) {
        const Uint32 now = SDL_GetTicks();
        s_backdrop = backdrop;
        if (s_blurMix.to < 1) {
            s_blurMix.go(1, BLUR_FADE, now);
        }
        requestRender();
    }
}

AVFrame* StreamMenu::frameToRepeat()
{
    if (s_shotWanted) {
        captureIfWanted(s_lastFrame);   // le PC n'envoie rien : la dernière image fera l'affaire
    }
    if (!s_repeat.exchange(false) || s_lastFrame == nullptr) {
        return nullptr;
    }
    AVFrame* copy = av_frame_clone(s_lastFrame);
    if (copy != nullptr) {
        copy->pkt_dts = LiGetMicroseconds();   // le Pacer y mesure l'attente de l'image
    }
    return copy;
}

void StreamMenu::releaseFrame()
{
    av_frame_free(&s_lastFrame);
}
