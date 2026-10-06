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
#include <QSettings>

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
const char* SOUNDS_SETTING = "ConsoleUi/sounds";

// Durées et courbes de Theme.qml (ConsoleDialog, OptionsSheet, Toast), en ms.
const int SHEET_SLIDE = 440;        // panneau, easeQuint
const int SHEET_DIM_FADE = 320;     // fond, linéaire
const int SHEET_FOCUS_MOVE = 220;   // surlignage, easeOut
const int SHEET_FOCUS_FADE = 160;   // couleur des libellés, glyphe A
const int SHEET_VALUE_SWAP = 260;   // « Affichées » / « Masquées »
const int PAGE_FADE = 260;          // liste ↔ confirmation, easeOut (à l'accueil, deux dialogs se croisent)
const int BLUR_FADE = 200;          // l'image floutée remplace le voile
const int STATS_FADE = 220;         // Theme.toastFade
const int CURTAIN_FADE = 250;       // fondu au noir avant de quitter le flux
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
const char* const SOUND_NAMES[] = { "move", "edge", "select", "open", "close", "tick" };

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
QString s_confirm;              // action qui attend sa confirmation ; vide : la liste
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
Anim s_reveal, s_veil, s_blurMix, s_focusY, s_pageMix, s_swap, s_statsFade;
QVector<Anim> s_highlight;              // par ligne de la page
StreamPainter::Page s_previous;         // la page qui s'efface
int s_swapRow = -1;
QString s_swapFrom;
Anim s_curtain;                         // fondu au noir avant de quitter le flux
int s_repeatDir = 0;                    // direction tenue, répétée par le minuteur
Uint32 s_repeatAt = 0;
int s_repeats = 0;
QString s_leaving;                      // action choisie, le temps du fondu au noir
bool s_finishPending = false;           // finishLeave à lancer, hors du verrou
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
QHash<QString, QByteArray> s_sounds;    // échantillons, volume appliqué
SDL_AudioDeviceID s_audio = 0;

// Textes du menu, contexte de traduction « StreamMenu » (Text::tr, que lupdate sait lire).
struct Text { Q_DECLARE_TR_FUNCTIONS(StreamMenu) };

QString statsValue(bool shown)
{
    return shown ? Text::tr("Affichées") : Text::tr("Masquées");
}

QList<Action> actions()
{
    QList<Action> list = {
        { "resume", Text::tr("Reprendre") },
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

// Les mêmes confirmations que l'accueil (ConsoleHome.homeMenuChosen).
StreamPainter::Page page()
{
    StreamPainter::Page page;
    page.focus = s_focus;
    if (s_confirm.isEmpty()) {
        page.title = s_game.isEmpty() ? Text::tr("Menu") : s_game;
        for (const Action& action : actions()) {
            page.labels.append(action.label);
            page.values.append(action.key == QLatin1String("stats") ? statsValue(s_stats) : QString());
        }
        page.backLabel = Text::tr("Fermer");
        return page;
    }
    if (s_confirm == QLatin1String("quit")) {
        page.title = s_game.isEmpty() ? Text::tr("Quitter le jeu ?") : Text::tr("Quitter %1 ?").arg(s_game);
        page.message = Text::tr("Toute progression non sauvegardée sera perdue.");
        page.labels = QStringList { Text::tr("Annuler"), Text::tr("Quitter") };
    }
    else if (s_confirm == QLatin1String("reboot")) {
        page.title = Text::tr("Redémarrer la console ?");
        page.labels = QStringList { Text::tr("Annuler"), Text::tr("Redémarrer") };
    }
    else {
        page.title = Text::tr("Éteindre la console ?");
        page.labels = QStringList { Text::tr("Annuler"), Text::tr("Éteindre") };
    }
    page.backLabel = Text::tr("Annuler");
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
    frame.previous = s_previous;
    frame.pageMix = s_pageMix.at(now);
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
    return frame;
}

bool animating(Uint32 now)
{
    for (const Anim* anim : { &s_reveal, &s_veil, &s_blurMix, &s_focusY, &s_pageMix, &s_swap, &s_statsFade, &s_curtain }) {
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
    for (Anim* anim : { &s_reveal, &s_veil, &s_blurMix, &s_focusY, &s_pageMix, &s_swap, &s_statsFade, &s_curtain }) {
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
        // Rien n'a changé (une direction est tenue, entre deux pas) : pas d'image.
        const bool moving = animating(now);
        if (!s_dirty && !moving && !s_wasAnimating) {
            if (s_repeatDir != 0) {
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
        menuShown = s_open || s_reveal.at(now) > 0 || s_veil.at(now) > 0;
        if (menuShown) {
            view = frame(now);
        }
        stats = s_statsView;
        statsOpacity = s_statsFade.at(now);
    }

    // Le menu (ouvert ou en train de se fermer), sinon les statistiques, sinon rien.
    SDL_Surface* surface = menuShown ? menuSurface(view, screen)
                                     : toSurface(StreamPainter::paintStats(stats, statsOpacity, screen));

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

    if (animating(now) || s_dirty || s_repeatDir != 0) {
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
    s_confirm.clear();
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
    s_pageMix.set(1);
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

// Liste ↔ confirmation : l'ancienne page s'efface pendant que la nouvelle apparaît.
void switchPage(const QString& confirm, int focus)
{
    const Uint32 now = SDL_GetTicks();
    s_previous = page();
    s_confirm = confirm;
    s_focus = focus;
    s_repeatDir = 0;
    s_pageMix.set(0);
    s_pageMix.go(1, PAGE_FADE, now, QEasingCurve::OutCubic);
    s_focusY.set(focus);
    s_swap.set(1);
    s_swapRow = -1;
    resetHighlights(focus);
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

// Renvoie faux à une extrémité de la liste.
bool step(int direction)
{
    const int next = s_focus + direction;
    if (next < 0 || next >= s_highlight.size()) {
        play("edge");
        return false;
    }
    const Uint32 now = SDL_GetTicks();
    s_highlight[s_focus].go(0, SHEET_FOCUS_FADE, now);
    s_highlight[next].go(1, SHEET_FOCUS_FADE, now);
    s_focus = next;
    s_focusY.go(next, SHEET_FOCUS_MOVE, now, QEasingCurve::OutCubic);
    play("move");
    requestRender();
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

void back()
{
    if (s_confirm.isEmpty()) {
        closeMenu();
        return;
    }
    play("close");
    switchPage(QString(), actionIndex(s_confirm));
}

void switchStats()
{
    const Uint32 now = SDL_GetTicks();
    s_swapFrom = statsValue(s_stats);
    s_stats = !s_stats;
    QSettings().setValue(STATS_SETTING, s_stats.load());
    if (s_open && s_confirm.isEmpty()) {
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
    if (!s_confirm.isEmpty()) {
        if (s_focus == 1) {
            play("select");
            beginLeave(s_confirm);
        }
        else {
            back();
        }
        return;
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
    else if (key == QLatin1String("quit") || key == QLatin1String("reboot") || key == QLatin1String("poweroff")) {
        play("select");
        switchPage(key, 0);   // Annuler : le choix sûr
    }
    else {
        play("select");
        beginLeave(key);
    }
}

// L'image décodée, copiée en mémoire si elle est sur le GPU et réduite au huitième
// (moyenne des pixels : un premier flou). Nulle si le format ne s'y prête pas.
// ponytail: couleurs en BT.601 par défaut, sans HDR ; à régler si le fond tire.
QImage snapshot(const AVFrame* frame)
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
    QImage image(qMax(1, frame->width / 8), qMax(1, frame->height / 8), QImage::Format_RGB32);
    SwsContext* context = sws_getContext(frame->width, frame->height, (AVPixelFormat)frame->format,
                                         image.width(), image.height(), AV_PIX_FMT_BGRA,   // = Format_RGB32
                                         SWS_AREA, nullptr, nullptr, nullptr);
    if (context != nullptr) {
        uint8_t* const data[] = { image.bits() };
        const int linesize[] = { (int)image.bytesPerLine() };
        sws_scale(context, frame->data, frame->linesize, 0, frame->height, data, linesize);
        sws_freeContext(context);
    }
    av_frame_free(&copy);
    return context != nullptr ? image : QImage();
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
void showHomeWindow()
{
    QQuickWindow* window = nullptr;
    for (QWindow* candidate : QGuiApplication::topLevelWindows()) {
        if ((window = qobject_cast<QQuickWindow*>(candidate)) != nullptr) {
            break;
        }
    }
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
    s_exit = s_leaving;
    s_leaving.clear();
    s_open = false;
    freeze(SDL_GetTicks());   // l'écran reste noir jusqu'à la fermeture de la fenêtre du flux
    SDL_Event quit;
    quit.type = SDL_QUIT;
    quit.quit.timestamp = SDL_GetTicks();
    SDL_PushEvent(&quit);
}

}

void StreamMenu::prepare(const QString& game, const QStringList& powerActions, const QString& buttonLayout)
{
    QMutexLocker locker(&s_lock);
    closeAudio();
    s_session = nullptr;
    s_open = false;
    s_exit.clear();
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
    {
        QMutexLocker locker(&s_lock);
        if (!s_open || !s_leaving.isEmpty()) {
            return;
        }
        const int direction = button == SDL_CONTROLLER_BUTTON_DPAD_UP || button == SDL_CONTROLLER_BUTTON_DPAD_LEFT ? -1
                            : button == SDL_CONTROLLER_BUTTON_DPAD_DOWN || button == SDL_CONTROLLER_BUTTON_DPAD_RIGHT ? 1
                            : 0;
        if (!pressed) {
            if (direction != 0 && direction == s_repeatDir) {
                s_repeatDir = 0;
            }
            if (button == SDL_CONTROLLER_BUTTON_A && s_armed) {
                s_armed = false;
                activate();
            }
        }
        else if (direction != 0) {
            hold(direction);
        }
        else if (button == SDL_CONTROLLER_BUTTON_A) {
            s_armed = true;
        }
        else if (button == SDL_CONTROLLER_BUTTON_B) {
            back();
        }
        if (!s_finishPending) {
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
    if (!s_open || !s_leaving.isEmpty()) {
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
    return s_stats;
}

void StreamMenu::updateStats(const VIDEO_STATS& stats, int videoFormat, int width, int height, double megabitsPerSec)
{
    const StreamPainter::Stats view = statsView(stats, videoFormat, width, height, megabitsPerSec);
    QMutexLocker locker(&s_lock);
    attach();
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
    // Cette image portera l'overlay en cours : rien à réafficher.
    s_lastFrameTicks = SDL_GetTicks();
    s_repeat = false;
    av_frame_free(&s_lastFrame);
    if (s_keepFrames) {
        s_lastFrame = av_frame_clone(frame);
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
    const QImage small = snapshot(frame);
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
