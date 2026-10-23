#include "streammenu.h"
#include "streampainter.h"

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
const char* RUMBLE_SETTING = "ConsoleUi/rumble";
const char* MOTION_SETTING = "ConsoleUi/reduceMotion";
// Départ sans action pour l'accueil : le flux s'est fermé autrement que par le menu.
const char* ENDED = "ended";
const char* SOUNDS_SETTING = "ConsoleUi/sounds";

// Durées et courbes de Theme.qml (ConsoleDialog, OptionsSheet, Toast), en ms.
const int SHEET_SLIDE = 440;        // panneau, easeQuint
const int SHEET_DIM_FADE = 320;     // fond, linéaire
const int SHEET_FOCUS_MOVE = 220;   // surlignage, easeOut
const int SHEET_FOCUS_FADE = 160;   // couleur des libellés, glyphe A
const int SHEET_VALUE_SWAP = 260;   // « Affichées » / « Masquées »
const int BLUR_FADE = 200;          // l'image floutée remplace le voile
const int STATS_FADE = 220;         // Theme.toastFade
const int CURTAIN_FADE = 250;       // fondu au noir avant de quitter le flux
const int STREAM_FADE_IN = 400;     // au début du flux, le noir s'efface sur ses premières images
const int NOTICE_FADE = 220;        // un avis pendant le jeu paraît, reste NOTICE_HOLD, s'efface
const Uint32 NOTICE_HOLD = 3000;
const int VALUE_STEP = 5;           // volume, luminosité : ← / → de 5 % (la souris aussi, par crans de 5)
const int SLIDER_MOVE = 160;        // la poignée rejoint la nouvelle valeur, OutCubic
const int BRIGHTNESS_MIN = 5;       // SystemStatus.setBrightness : jamais tout à fait noir
const int POOR_SECONDS = 10;        // réseau « mauvais » (Format.networkQuality) aussi longtemps : un avis
const int POOR_RTT = 50;            // au-delà : mauvais (ms), comme la pastille de l'accueil
const int POOR_VARIANCE = 15;
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

// Sons de l'accueil (sounds/*.wav, 44,1 kHz mono 16 bits), joués par SDL :
// QtMultimedia ne tourne pas pendant un flux.
const int SOUND_RATE = 44100;
const double SOUND_VOLUME = 0.125;  // Theme.soundVolume
const char* const SOUND_NAMES[] = { "move", "edge", "select", "open", "close", "tick", "hold", "confirm" };

// Une valeur qui va de `from` à `to` en `duration` ms à partir de `start`.
struct Anim {
    double from = 0;
    double to = 0;
    Uint32 start = 0;
    int duration = 0;
    QEasingCurve::Type easing = QEasingCurve::Linear;

    double at(Uint32 now) const
    {
        if (!running(now)) {
            return to;
        }
        return from + (to - from) * QEasingCurve(easing).valueForProgress(double(now - start) / duration);
    }
    bool running(Uint32 now) const
    {
        return duration > 0 && now - start < (Uint32)duration;
    }
    void go(double target, int ms, Uint32 now, QEasingCurve::Type curve = QEasingCurve::Linear)
    {
        from = at(now);
        to = target;
        start = now;
        duration = ms;
        easing = curve;
    }
    void set(double value)
    {
        from = to = value;
        duration = 0;
    }
};

struct Action {
    QString key;
    QString label;
};

QMutex s_lock;
Session* s_session = nullptr;   // le flux où le menu a été ouvert
bool s_open = false;
int s_focus = 0;
bool s_armed = false;           // A enfoncé dans le menu : l'action part au relâché
int s_stick = 0;
QSize s_screen;
QString s_game;
QStringList s_power;
QString s_layout;
QString s_exit;
std::atomic<bool> s_stats { false };    // statistiques affichées (réglage mémorisé)
StreamPainter::Stats s_statsView;       // les dernières reçues
std::atomic<bool> s_wantFrame { false };    // le menu attend une image du jeu
QImage s_backdrop;                      // l'image du jeu floutée, à la taille de l'écran

// Animations (StreamPainter::Frame) et le minuteur qui les fait avancer.
Anim s_reveal, s_veil, s_blurMix, s_focusY, s_swap, s_statsFade;
QVector<Anim> s_highlight;              // par ligne de la page
int s_swapRow = -1;
QString s_swapFrom;
Anim s_curtain;                         // fondu au noir avant de quitter le flux
int s_repeatDir = 0;                    // direction tenue, répétée par le minuteur
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
StreamPainter::Notice s_notice;         // l'avis en cours, hors du menu (en haut à droite)
Anim s_noticeFade;
SDL_TimerID s_noticeTimer = 0;
std::atomic<bool> s_shotWanted { false };   // une capture d'écran attend la prochaine image
QString s_shotValue;                    // valeur de la ligne « Capture d'écran » (« Enregistrée »…)
int s_poorSeconds = 0;                  // réseau mauvais depuis… (s), bon depuis…
int s_goodSeconds = 0;
bool s_poorNoticed = false;
bool s_batteryNoticed = false;
Anim s_hold, s_holdDone;                // appui maintenu sur une confirmation, puis sa coche
bool s_holding = false;                 // A (ou le clic) tenu sur la ligne à maintenir
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
bool s_rumbleOn = true;
bool s_reducedMotion = false;           // « Réduire les animations » : pas de fondu d'entrée
std::atomic<bool> s_fadedIn { false };  // le flux a eu son fondu d'entrée
QHash<QString, QByteArray> s_sounds;    // échantillons, volume appliqué
SDL_AudioDeviceID s_audio = 0;

// Textes du menu, contexte de traduction « StreamMenu » (Text::tr, que lupdate sait lire).
struct Text { Q_DECLARE_TR_FUNCTIONS(StreamMenu) };

QString statsValue(bool shown)
{
    return shown ? Text::tr("Affichées") : Text::tr("Masquées");
}

QString percent(int value)
{
    return Text::tr("%1 %").arg(value);
}

QList<Action> actions()
{
    QList<Action> list = {
        { "resume", Text::tr("Reprendre") },
        { "shot", Text::tr("Capture d'écran") },
    };
    if (s_volume >= 0) list.append({ "volume", Text::tr("Volume") });
    if (s_brightness >= 0) list.append({ "brightness", Text::tr("Luminosité") });
    list += QList<Action> {
        { "stats", Text::tr("Statistiques du flux") },
        { "home", Text::tr("Retour à l'accueil") },
        { "quit", s_game.isEmpty() ? Text::tr("Quitter le jeu") : Text::tr("Quitter %1").arg(s_game) },
    };
    if (s_power.contains(QLatin1String("suspend"))) list.append({ "suspend", Text::tr("Mettre en veille") });
    if (s_power.contains(QLatin1String("reboot"))) list.append({ "reboot", Text::tr("Redémarrer") });
    if (s_power.contains(QLatin1String("poweroff"))) list.append({ "poweroff", Text::tr("Éteindre") });
    return list;
}

int actionIndex(const QString& key)
{
    const QList<Action> list = actions();
    for (int i = 0; i < list.size(); i++) {
        if (list[i].key == key) {
            return i;
        }
    }
    return 0;
}

// Quitter le jeu, redémarrer, éteindre : pas de page de confirmation, la ligne elle-même
// se maintient (A, Entrée ou le clic tenus), comme « Quitter la partie » à l'accueil.
bool holdRow()
{
    const QString key = actions().value(s_focus).key;
    return key == QLatin1String("quit") || key == QLatin1String("reboot") || key == QLatin1String("poweroff");
}

// Les libellés de fin de l'accueil (ConsoleHome.homeMenuChosen).
QString doneLabel()
{
    const QString key = actions().value(s_focus).key;
    return key == QLatin1String("quit") ? Text::tr("Fermeture du jeu")
         : key == QLatin1String("reboot") ? Text::tr("Redémarrage") : Text::tr("Extinction");
}

StreamPainter::Page page()
{
    StreamPainter::Page page;
    page.focus = s_focus;
    page.title = s_game.isEmpty() ? Text::tr("Menu") : s_game;
    for (const Action& action : actions()) {
        page.sliders.append(action.key == QLatin1String("volume") ? s_volume / 100.0
                          : action.key == QLatin1String("brightness") ? s_brightness / 100.0 : -1);
        page.labels.append(action.label);
        page.values.append(action.key == QLatin1String("stats") ? statsValue(s_stats)
                         : action.key == QLatin1String("volume") ? percent(s_volume)
                         : action.key == QLatin1String("brightness") ? percent(s_brightness)
                         : action.key == QLatin1String("shot") ? s_shotValue : QString());
    }
    page.backLabel = Text::tr("Fermer");
    if (holdRow()) {
        page.confirmLabel = Text::tr("Maintenir");
    }
    return page;
}

void resetHighlights(int focus)
{
    s_highlight = QVector<Anim>(page().labels.size());
    for (int i = 0; i < s_highlight.size(); i++) {
        s_highlight[i].set(i == focus ? 1 : 0);
    }
}

StreamPainter::Frame frame(Uint32 now)
{
    StreamPainter::Frame frame;
    frame.page = page();
    frame.focusY = s_focusY.at(now);
    for (const Anim& highlight : s_highlight) {
        frame.highlight.append(highlight.at(now));
    }
    frame.swapRow = s_swapRow;
    frame.swapFrom = s_swapFrom;
    frame.swapProgress = s_swap.at(now);
    frame.reveal = s_reveal.at(now);
    frame.veil = s_veil.at(now);
    frame.blurMix = s_blurMix.at(now);
    frame.backdrop = s_backdrop;
    frame.stats = s_statsView;
    frame.statsOpacity = s_statsFade.at(now);
    frame.layout = s_layout;
    frame.curtain = s_curtain.at(now);
    const QList<Action> list = actions();
    for (int i = 0; i < list.size() && i < frame.page.sliders.size(); i++) {
        if (list[i].key == QLatin1String("volume")) frame.page.sliders[i] = s_volumeAnim.at(now) / 100;
        if (list[i].key == QLatin1String("brightness")) frame.page.sliders[i] = s_brightnessAnim.at(now) / 100;
    }
    frame.hold = qPow(s_hold.at(now), HOLD_CURVE);
    frame.holdDone = s_holdDone.at(now);
    frame.doneLabel = doneLabel();
    return frame;
}

bool animating(Uint32 now)
{
    for (const Anim* anim : { &s_reveal, &s_veil, &s_blurMix, &s_focusY, &s_swap, &s_statsFade, &s_curtain,
                              &s_hold, &s_holdDone, &s_noticeFade, &s_volumeAnim, &s_brightnessAnim }) {
        if (anim->running(now)) {
            return true;
        }
    }
    for (const Anim& highlight : s_highlight) {
        if (highlight.running(now)) {
            return true;
        }
    }
    return false;
}

// Arrête toutes les animations là où elles en sont.
void freeze(Uint32 now)
{
    for (Anim* anim : { &s_reveal, &s_veil, &s_blurMix, &s_focusY, &s_swap, &s_statsFade, &s_curtain,
                        &s_hold, &s_holdDone, &s_noticeFade, &s_volumeAnim, &s_brightnessAnim }) {
        anim->set(anim->at(now));
    }
    for (Anim& highlight : s_highlight) {
        highlight.set(highlight.at(now));
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
        if (spec.format == AUDIO_S16SYS && spec.channels == 1 && spec.freq == SOUND_RATE) {
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
    if (s_rumbleOn) {
        StreamMenu::rumble(QLatin1String(name));
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
        want.channels = 1;
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
    StreamPainter::Stats stats;
    qreal statsOpacity;
    StreamPainter::Notice notice;
    qreal noticeOpacity;
    {
        QMutexLocker locker(&s_lock);
        if (Session::get() == nullptr || Session::get() != s_session) {
            s_timer = 0;
            return 0;
        }
        now = SDL_GetTicks();
        if (s_repeatDir != 0 && (Sint32)(now - s_repeatAt) >= 0) {
            repeatStep(now);
        }
        holdStep(now);
        // Rien n'a changé (une direction est tenue, entre deux pas ; une confirmation
        // maintenue attend son départ) : pas d'image, mais le minuteur continue.
        const bool moving = animating(now);
        if (!s_dirty && !moving && !s_wasAnimating) {
            if (s_repeatDir != 0 || s_holding || (s_holdDoneAt != 0 && s_leaving.isEmpty())) {
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
        menuShown = s_open || s_reveal.at(now) > 0 || s_veil.at(now) > 0 || s_curtain.at(now) > 0;
        if (menuShown) {
            view = frame(now);
        }
        stats = s_statsView;
        statsOpacity = s_statsFade.at(now);
        notice = s_notice;
        noticeOpacity = s_noticeFade.at(now);
    }

    // Le menu (ouvert ou en train de se fermer), sinon les statistiques, sinon rien.
    SDL_Surface* surface = menuShown ? menuSurface(view, screen)
                                     : toSurface(StreamPainter::paintStats(stats, statsOpacity, screen,
                                                                           notice, noticeOpacity));

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

    if (animating(now) || s_dirty || s_repeatDir != 0 || s_holding || (s_holdDoneAt != 0 && s_leaving.isEmpty())) {
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
        s_reveal.set(0);
        s_veil.set(0);
    }
}

void openMenu()
{
    const Uint32 now = SDL_GetTicks();
    s_open = true;
    s_focus = 0;
    s_shotValue.clear();
    resetHold();
    s_armed = false;
    s_stick = 0;
    s_repeatDir = 0;
    s_leaving.clear();
    s_curtain.set(0);
    s_screen = screenSize();
    s_wantFrame = true;   // l'image floutée remplacera le voile (offerFrame)
    if (s_backdrop.isNull()) {
        s_blurMix.set(0);
    }
    s_reveal.go(1, SHEET_SLIDE, now, QEasingCurve::OutQuint);
    s_veil.go(1, SHEET_DIM_FADE, now);
    s_focusY.set(0);
    s_swap.set(1);
    s_swapRow = -1;
    resetHighlights(0);
    play("open");
    requestRender();
}

void closeMenu(bool sound = true)
{
    const Uint32 now = SDL_GetTicks();
    s_open = false;
    s_armed = false;
    s_repeatDir = 0;
    s_wantFrame = false;
    s_reveal.go(0, SHEET_SLIDE, now, QEasingCurve::OutQuint);
    s_veil.go(0, SHEET_DIM_FADE, now);
    if (sound) {
        play("close");
    }
    requestRender();
}

// Quitter le flux : un fondu au noir, puis finishLeave (hors du verrou) ; l'accueil
// fera la suite (ConsoleHome.returnedHome). Le menu ne répond plus entre-temps.
void beginLeave(const QString& action)
{
    s_leaving = action;
    s_repeatDir = 0;
    s_wantFrame = false;
    s_curtain.go(1, CURTAIN_FADE, SDL_GetTicks());
    s_finishPending = true;
    requestRender();
}

// Le surlignage glisse jusqu'à la ligne `next` (qui existe et n'est pas la ligne en focus).
void focusRow(int next)
{
    resetHold();
    const Uint32 now = SDL_GetTicks();
    s_highlight[s_focus].go(0, SHEET_FOCUS_FADE, now);
    s_highlight[next].go(1, SHEET_FOCUS_FADE, now);
    s_focus = next;
    s_focusY.go(next, SHEET_FOCUS_MOVE, now, QEasingCurve::OutCubic);
    play("move");
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

// A (ou le clic) enfoncé sur une ligne à maintenir : elle se remplit.
void startHold()
{
    const Uint32 now = SDL_GetTicks();
    s_holding = true;
    s_hold.go(1, int((1 - s_hold.at(now)) * HOLD_DURATION), now);
    play("hold");
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
        play("confirm");
    }
    if (s_holdDoneAt != 0 && s_leaving.isEmpty() && now - s_holdDoneAt >= (Uint32)HOLD_FINISH) {
        beginLeave(actions().value(s_focus).key);
        s_holding = false;
        s_holdDoneAt = 0;   // un seul départ : finishLeave vide s_leaving, il ne doit pas repartir
        SDL_Event quit;
        quit.type = SDL_QUIT;
        quit.quit.timestamp = now;
        SDL_PushEvent(&quit);
    }
}

// Renvoie faux à une extrémité de la liste.
bool step(int direction)
{
    const int next = s_focus + direction;
    if (next < 0 || next >= s_highlight.size()) {
        play("edge");
        return false;
    }
    focusRow(next);
    return true;
}

// Croix ou stick enfoncés : une marche tout de suite, la suite par le minuteur.
void hold(int direction)
{
    s_repeatDir = step(direction) ? direction : 0;
    s_repeats = 0;
    s_repeatAt = SDL_GetTicks() + REPEAT_DELAY;
    requestRender();   // le minuteur tourne tant que la direction est tenue
}

// Fil du minuteur : la répétition s'arrête au bout de la liste.
void repeatStep(Uint32 now)
{
    if (!s_open || !s_leaving.isEmpty() || !step(s_repeatDir)) {
        s_repeatDir = 0;
        return;
    }
    s_repeats++;
    s_repeatAt = now + qMax(REPEAT_MIN, REPEAT_INTERVAL - s_repeats * REPEAT_STEP);
}

// Un avis bref, hors du menu (en haut à droite) : il paraît, reste NOTICE_HOLD, s'efface.
Uint32 hideNotice(Uint32, void*)
{
    QMutexLocker locker(&s_lock);
    s_noticeTimer = 0;
    s_noticeFade.go(0, NOTICE_FADE, SDL_GetTicks());
    requestRender();
    return 0;
}

void showNotice(const QString& text, StreamPainter::Notice::Tone tone)
{
    s_notice.text = text;
    s_notice.tone = tone;
    s_noticeFade.go(1, NOTICE_FADE, SDL_GetTicks(), QEasingCurve::OutCubic);
    if (s_noticeTimer != 0) {
        SDL_RemoveTimer(s_noticeTimer);
    }
    s_noticeTimer = SDL_AddTimer(NOTICE_HOLD, hideNotice, nullptr);
    requestRender();
}

// La valeur d'une ligne change : l'ancienne sort, la nouvelle entre (SwapBox).
void swapValue(int row, const QString& from)
{
    const Uint32 now = SDL_GetTicks();
    s_swapRow = row;
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
        const QString from = s_shotValue;
        s_shotValue = Text::tr("Capture…");
        swapValue(actionIndex(QStringLiteral("shot")), from);
    }
    s_repeat = true;
    LiWakeWaitForVideoFrame();
}

bool valueRow()
{
    const QString key = actions().value(s_focus).key;
    return key == QLatin1String("volume") || key == QLatin1String("brightness");
}

// Le volume ou la luminosité (ligne en focus) passe à `wanted` : la poignée glisse, la valeur
// change (en glissant, sauf `dragged` : elle suit la souris). Le réglage lui-même
// (SystemStatus) se fait hors du verrou, par l'appelant : renvoie la valeur à poser, -1 sinon.
int setValue(int wanted, bool dragged)
{
    const bool volume = actions().value(s_focus).key == QLatin1String("volume");
    int& value = volume ? s_volume : s_brightness;
    Anim& anim = volume ? s_volumeAnim : s_brightnessAnim;
    const int next = qBound(volume ? 0 : BRIGHTNESS_MIN, wanted, 100);
    if (next == value) {
        if (!dragged) {
            play("edge");
        }
        return -1;
    }
    const QString from = percent(value);
    value = next;
    if (dragged) {
        anim.set(next);
        s_swapRow = -1;
        requestRender();
    }
    else {
        anim.go(next, SLIDER_MOVE, SDL_GetTicks(), QEasingCurve::OutCubic);
        swapValue(s_focus, from);
    }
    play("tick");
    return next;
}

// ← / → sur le volume ou la luminosité : le cran de 5 % suivant (61 → 65, 61 → 60).
int adjust(int direction)
{
    const int value = actions().value(s_focus).key == QLatin1String("volume") ? s_volume : s_brightness;
    const int floor = value / VALUE_STEP * VALUE_STEP;
    return setValue(direction > 0 ? floor + VALUE_STEP : (value == floor ? floor - VALUE_STEP : floor), false);
}

// Fil principal (celui du flux : Qt y est suspendu, mais SystemStatus s'appelle directement).
void applySetting(const QString& key, int value)
{
    if (value < 0 || s_system == nullptr) {
        return;
    }
    QMetaObject::invokeMethod(s_system, key == QLatin1String("volume") ? "setVolume" : "setBrightness",
                              Qt::DirectConnection, Q_ARG(int, value));
}

void back()
{
    closeMenu();
}

void switchStats()
{
    const Uint32 now = SDL_GetTicks();
    s_swapFrom = statsValue(s_stats);
    s_stats = !s_stats;
    QSettings().setValue(STATS_SETTING, s_stats.load());
    if (s_open) {
        s_swapRow = actionIndex(QStringLiteral("stats"));
        s_swap.set(0);
        s_swap.go(1, SHEET_VALUE_SWAP, now);
    }
    if (s_stats) {
        s_statsView = StreamPainter::Stats();   // elles apparaîtront avec les premiers chiffres
        s_statsFade.set(0);
    }
    else {
        s_statsFade.go(0, STATS_FADE, now);
    }
    requestRender();
}

void activate()
{
    if (holdRow()) {
        return;   // elle se maintient (startHold)
    }
    const QString key = actions().value(s_focus).key;
    if (key == QLatin1String("resume")) {
        play("select");
        closeMenu(false);
    }
    else if (key == QLatin1String("stats")) {
        play("tick");
        switchStats();
    }
    else if (key == QLatin1String("shot")) {
        play("select");
        requestShot();
    }
    else if (key == QLatin1String("volume") || key == QLatin1String("brightness")) {
        play("edge");   // ← / → les règlent
    }
    else {
        play("select");
        beginLeave(key);
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
        const QString from = s_shotValue;
        s_shotValue = saved ? Text::tr("Enregistrée") : Text::tr("Échec");
        swapValue(actionIndex(QStringLiteral("shot")), from);
    }
    else {
        showNotice(saved ? Text::tr("Capture enregistrée") : Text::tr("Capture impossible"),
                   saved ? StreamPainter::Notice::Good : StreamPainter::Notice::Bad);
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
            showNotice(Text::tr("Réseau instable"), StreamPainter::Notice::Bad);
        }
        if (s_goodSeconds >= POOR_SECONDS) {
            s_poorNoticed = false;
        }
    }
    bool low = false;
    if (SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        for (int i = 0; i < SDL_NumJoysticks(); i++) {
            SDL_GameController* gc = SDL_GameControllerFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
            if (gc != nullptr) {
                const SDL_JoystickPowerLevel level = SDL_JoystickCurrentPowerLevel(SDL_GameControllerGetJoystick(gc));
                low |= level == SDL_JOYSTICK_POWER_LOW || level == SDL_JOYSTICK_POWER_EMPTY;
            }
        }
    }
    if (low && !s_batteryNoticed) {
        showNotice(Text::tr("Manette presque vide"), StreamPainter::Notice::Warn);
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

// Les chiffres de Moonlight (ffmpeg.cpp, stringifyVideoStats) en quatre lignes.
StreamPainter::Stats statsView(const VIDEO_STATS& stats, int videoFormat, int width, int height, double megabitsPerSec)
{
    // Nombres à la façon de la langue de l'interface (réglage Langue ; Auto : celle du système).
    const StreamingPreferences::Language language = StreamingPreferences::get()->language;
    const QLocale locale = language == StreamingPreferences::LANG_EN ? QLocale(QLocale::English)
                         : language == StreamingPreferences::LANG_FR ? QLocale(QLocale::French)
                         : QLocale::system();
    auto number = [&](double value) { return locale.toString(value, 'f', 1); };

    StreamPainter::Stats view;
    view.lines.append(Text::tr("%1 × %2 · %3 i/s · %4 · %5 Mb/s").arg(width).arg(height)
                          .arg(number(stats.decodedFps), codecName(videoFormat), number(megabitsPerSec)));
    view.dotLine = 1;
    view.dot = StreamPainter::networkColor(stats.lastRtt, stats.lastRttVariance);
    view.lines.append(stats.lastRtt != 0 ? Text::tr("Latence réseau %1 ms (± %2 ms)").arg(stats.lastRtt).arg(stats.lastRttVariance)
                                         : Text::tr("Latence réseau : mesure en cours"));
    if (stats.totalFrames != 0 && stats.decodedFrames != 0) {
        view.lines.append(Text::tr("Images perdues : %1 % réseau · %2 % gigue")
                              .arg(number(100.0 * stats.networkDroppedFrames / stats.totalFrames),
                                   number(100.0 * stats.pacerDroppedFrames / stats.decodedFrames)));
    }
    if (stats.decodedFrames != 0 && stats.renderedFrames != 0) {
        QString times = Text::tr("Décodage %1 ms · Affichage %2 ms")
                            .arg(number(stats.totalDecodeTimeUs / 1000.0 / stats.decodedFrames),
                                 number(stats.totalRenderTimeUs / 1000.0 / stats.renderedFrames));
        if (stats.framesWithHostProcessingLatency != 0) {
            times += Text::tr(" · PC %1 ms").arg(number(stats.totalHostProcessingLatency / 10.0
                                                  / stats.framesWithHostProcessingLatency));
        }
        view.lines.append(times);
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
                         QObject* system)
{
    QMutexLocker locker(&s_lock);
    s_system = system;
    s_volume = system != nullptr ? system->property("volume").toInt() : -1;
    s_brightness = system != nullptr ? system->property("brightness").toInt() : -1;
    s_volumeAnim.set(s_volume);
    s_brightnessAnim.set(s_brightness);
    s_dragSlider = false;
    s_notice = StreamPainter::Notice();
    s_noticeFade.set(0);
    if (s_noticeTimer != 0) {
        SDL_RemoveTimer(s_noticeTimer);
        s_noticeTimer = 0;
    }
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
    s_reveal.set(0);
    s_veil.set(0);
    s_stats = QSettings().value(STATS_SETTING, false).toBool();
    s_statsView = StreamPainter::Stats();
    s_statsFade.set(0);   // les statistiques apparaissent avec les premiers chiffres
    s_soundsOn = QSettings().value(SOUNDS_SETTING, true).toBool();
    s_rumbleOn = QSettings().value(RUMBLE_SETTING, true).toBool();
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
    QString setting;      // volume ou luminosité réglés : appliqués hors du verrou
    int settingValue = -1;
    {
        QMutexLocker locker(&s_lock);
        if (!s_open || !s_leaving.isEmpty() || s_holdDoneAt != 0) {
            return;
        }
        // Haut / bas : la ligne ; gauche / droite : la valeur (volume, luminosité).
        const int direction = button == SDL_CONTROLLER_BUTTON_DPAD_UP ? -1
                            : button == SDL_CONTROLLER_BUTTON_DPAD_DOWN ? 1 : 0;
        const int sideways = button == SDL_CONTROLLER_BUTTON_DPAD_LEFT ? -1
                           : button == SDL_CONTROLLER_BUTTON_DPAD_RIGHT ? 1 : 0;
        if (pressed && sideways != 0 && valueRow()) {
            setting = actions().value(s_focus).key;
            settingValue = adjust(sideways);
        }
        if (!pressed) {
            if (direction != 0 && direction == s_repeatDir) {
                s_repeatDir = 0;
            }
            if (button == SDL_CONTROLLER_BUTTON_A && s_holding) {
                releaseHold();
            }
            else if (button == SDL_CONTROLLER_BUTTON_A && s_armed) {
                s_armed = false;
                activate();
            }
        }
        else if (direction != 0) {
            hold(direction);
        }
        else if (button == SDL_CONTROLLER_BUTTON_A && holdRow()) {
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
            applySetting(setting, settingValue);
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
    QString setting;      // volume ou luminosité tirés : appliqués hors du verrou
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
        const int row = StreamPainter::rowAt(page(), s_screen, at);
        if (row >= 0 && row != s_focus && row < s_highlight.size() && !s_holding && !s_dragSlider) {
            focusRow(row);
        }
        // Un curseur (volume, luminosité) : cliqué, la poignée y vient ; tiré, elle suit.
        const qreal slider = StreamPainter::sliderAt(page(), s_screen, at);
        if (button == SDL_BUTTON_LEFT && pressed && slider >= 0) {
            s_dragSlider = true;
        }
        else if (button == SDL_BUTTON_LEFT && !pressed && s_dragSlider) {
            s_dragSlider = false;
            s_armed = false;
            button = 0;   // (rien d'autre à faire de ce relâché)
        }
        if (s_dragSlider && valueRow()) {
            // Où que soit la souris, la position horizontale sur le rail, par crans de 5 %.
            const qreal fraction = StreamPainter::sliderAt(page(), s_screen, at, true);
            setting = actions().value(s_focus).key;
            settingValue = setValue(qRound(fraction * 100 / VALUE_STEP) * VALUE_STEP, true);
        }
        if (button == SDL_BUTTON_LEFT && pressed && s_dragSlider) {
            // (un clic sur un curseur ne fait que le régler)
        }
        else if (button == SDL_BUTTON_LEFT && pressed) {
            s_armed = row >= 0 && !holdRow();
            if (row >= 0 && holdRow()) {
                startHold();   // le clic se maintient, comme A
            }
            else if (row == -2) {
                back();     // à côté du panneau : comme B
            }
        }
        else if (button == SDL_BUTTON_LEFT && s_holding) {
            releaseHold();
        }
        else if (button == SDL_BUTTON_LEFT && s_armed) {
            s_armed = false;
            if (row == s_focus) {
                activate();
            }
        }
        else if (button == SDL_BUTTON_RIGHT && pressed) {
            back();
        }
        if (!s_finishPending) {
            locker.unlock();
            applySetting(setting, settingValue);
            return;
        }
        s_finishPending = false;
    }
    finishLeave();
}

void StreamMenu::onAxis(uint8_t axis, int16_t value)
{
    if (axis != SDL_CONTROLLER_AXIS_LEFTY) {
        return;
    }
    QMutexLocker locker(&s_lock);
    if (!s_open || !s_leaving.isEmpty() || s_holdDoneAt != 0) {
        return;
    }
    const int direction = value <= -STICK_PUSH ? -1 : value >= STICK_PUSH ? 1 : 0;
    if (direction != 0 && direction != s_stick) {
        hold(direction);
    }
    else if (direction == 0 && qAbs(value) < STICK_REST && s_stick != 0 && s_repeatDir == s_stick) {
        s_repeatDir = 0;   // stick revenu au repos
    }
    if (direction != 0 || qAbs(value) < STICK_REST) {
        s_stick = direction;
    }
}

void StreamMenu::rumble(const QString& sound)
{
    // Moteur grave, moteur aigu (0 à 0xFFFF), durée : une touche légère pour une butée,
    // un coup franc pour une confirmation, une poussée douce pour un lancement.
    struct Rumble { const char* sound; Uint16 low; Uint16 high; Uint32 ms; };
    static const Rumble RUMBLES[] = {
        { "edge", 0x2800, 0x5000, 40 },
        { "deny", 0x7000, 0x3000, 90 },
        { "confirm", 0xA000, 0xC000, 120 },
        { "launch", 0x6000, 0x2000, 220 },
    };
    if (!SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        return;
    }
    for (const Rumble& r : RUMBLES) {
        if (sound != QLatin1String(r.sound)) {
            continue;
        }
        for (int i = 0; i < SDL_NumJoysticks(); i++) {
            SDL_GameController* gc = SDL_GameControllerFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
            if (gc != nullptr) {
                SDL_GameControllerRumble(gc, r.low, r.high, r.ms);
            }
        }
        return;
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
    play("tick");
    switchStats();
}

bool StreamMenu::wantsStats()
{
    return true;   // chaque seconde : les avis (réseau, manette), même statistiques masquées
}

void StreamMenu::updateStats(const VIDEO_STATS& stats, int videoFormat, int width, int height, double megabitsPerSec)
{
    {
        QMutexLocker locker(&s_lock);
        attach();
        checkHealth(stats);
        if (!s_stats) {
            return;
        }
    }
    const StreamPainter::Stats view = statsView(stats, videoFormat, width, height, megabitsPerSec);
    QMutexLocker locker(&s_lock);
    if (!s_stats) {
        return;
    }
    const Uint32 now = SDL_GetTicks();
    if (s_statsView.lines.isEmpty()) {
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
