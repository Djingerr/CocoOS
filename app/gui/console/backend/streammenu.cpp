#include "streammenu.h"
#include "streampainter.h"

#include "streaming/session.h"
#include "streaming/video/decoder.h"

#include <QCoreApplication>
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

QString tr(const char* text)
{
    return QCoreApplication::translate("StreamMenu", text);
}

QList<Action> actions()
{
    QList<Action> list = {
        { "resume", tr("Reprendre") },
        { "stats", tr("Statistiques du flux") },
        { "home", tr("Retour à l'accueil") },
        { "quit", s_game.isEmpty() ? tr("Quitter le jeu") : tr("Quitter %1").arg(s_game) },
    };
    if (s_power.contains(QLatin1String("suspend"))) list.append({ "suspend", tr("Mettre en veille") });
    if (s_power.contains(QLatin1String("reboot"))) list.append({ "reboot", tr("Redémarrer") });
    if (s_power.contains(QLatin1String("poweroff"))) list.append({ "poweroff", tr("Éteindre") });
    return list;
}

// Les mêmes confirmations que l'accueil (ConsoleHome.homeMenuChosen).
StreamPainter::Menu view()
{
    StreamPainter::Menu menu;
    menu.layout = s_layout;
    menu.focus = s_focus;
    menu.stats = s_statsView;
    menu.backdrop = s_backdrop;
    if (s_confirm.isEmpty()) {
        menu.title = s_game.isEmpty() ? tr("Menu") : s_game;
        for (const Action& action : actions()) {
            menu.labels.append(action.label);
            menu.values.append(action.key == QLatin1String("stats") ? (s_stats ? tr("Affichées") : tr("Masquées"))
                                                                    : QString());
        }
        menu.backLabel = tr("Fermer");
        return menu;
    }
    if (s_confirm == QLatin1String("quit")) {
        menu.title = s_game.isEmpty() ? tr("Quitter le jeu ?") : tr("Quitter %1 ?").arg(s_game);
        menu.message = tr("Toute progression non sauvegardée sera perdue.");
        menu.labels = QStringList { tr("Annuler"), tr("Quitter") };
    }
    else if (s_confirm == QLatin1String("reboot")) {
        menu.title = tr("Redémarrer la console ?");
        menu.labels = QStringList { tr("Annuler"), tr("Redémarrer") };
    }
    else {
        menu.title = tr("Éteindre la console ?");
        menu.labels = QStringList { tr("Annuler"), tr("Éteindre") };
    }
    menu.backLabel = tr("Annuler");
    return menu;
}

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

// Le flux en cours ; un nouveau flux repart menu fermé. s_lock tenu.
void attach()
{
    Session* session = Session::get();
    if (session != s_session) {
        s_session = session;
        s_open = false;
    }
}

// Pose (ou retire) le menu ou les statistiques sur l'image du flux. s_lock tenu.
void render()
{
    Session* session = Session::get();
    if (session == nullptr || session != s_session) {
        return;
    }
    if (!s_screen.isValid()) {
        SDL_DisplayMode mode;   // pas encore de fenêtre connue : l'écran
        if (SDL_GetCurrentDisplayMode(0, &mode) == 0) {
            s_screen = QSize(mode.w, mode.h);
        }
    }
    QImage image;
    if (s_open) {
        image = StreamPainter::paintMenu(view(), s_screen);
    }
    else if (s_stats) {
        image = StreamPainter::paintStats(s_statsView, s_screen);
    }
    session->getOverlayManager().setOverlaySurface(Overlay::OverlayDebug, toSurface(image));
}

void switchStats()
{
    s_stats = !s_stats;
    QSettings().setValue(STATS_SETTING, s_stats.load());
    s_statsView = StreamPainter::Stats();   // les chiffres arrivent dans la seconde
    render();
}

QString codecName(int videoFormat)
{
    QString codec = (videoFormat & VIDEO_FORMAT_MASK_H264) ? QStringLiteral("H.264")
                  : (videoFormat & VIDEO_FORMAT_MASK_H265) ? QStringLiteral("HEVC")
                  : (videoFormat & VIDEO_FORMAT_MASK_AV1) ? QStringLiteral("AV1")
                  : QString();
    if (videoFormat & VIDEO_FORMAT_MASK_10BIT) {
        codec += LiGetCurrentHostDisplayHdrMode() ? QStringLiteral(" HDR") : tr(" 10 bits");
    }
    if (videoFormat & VIDEO_FORMAT_MASK_YUV444) {
        codec += QStringLiteral(" 4:4:4");
    }
    return codec;
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

// Les chiffres de Moonlight (ffmpeg.cpp, stringifyVideoStats) en quatre lignes.
StreamPainter::Stats statsView(const VIDEO_STATS& stats, int videoFormat, int width, int height, double megabitsPerSec)
{
    const QLocale french(QLocale::French);
    auto number = [&](double value) { return french.toString(value, 'f', 1); };

    StreamPainter::Stats view;
    view.lines.append(tr("%1 × %2 · %3 i/s · %4 · %5 Mb/s").arg(width).arg(height)
                          .arg(number(stats.renderedFps), codecName(videoFormat), number(megabitsPerSec)));
    view.dotLine = 1;
    view.dot = StreamPainter::networkColor(stats.lastRtt, stats.lastRttVariance);
    view.lines.append(stats.lastRtt != 0 ? tr("Latence réseau %1 ms (± %2 ms)").arg(stats.lastRtt).arg(stats.lastRttVariance)
                                         : tr("Latence réseau : mesure en cours"));
    if (stats.totalFrames != 0 && stats.decodedFrames != 0) {
        view.lines.append(tr("Images perdues : %1 % réseau · %2 % gigue")
                              .arg(number(100.0 * stats.networkDroppedFrames / stats.totalFrames),
                                   number(100.0 * stats.pacerDroppedFrames / stats.decodedFrames)));
    }
    if (stats.decodedFrames != 0 && stats.renderedFrames != 0) {
        QString times = tr("Décodage %1 ms · Affichage %2 ms")
                            .arg(number(stats.totalDecodeTimeUs / 1000.0 / stats.decodedFrames),
                                 number(stats.totalRenderTimeUs / 1000.0 / stats.renderedFrames));
        if (stats.framesWithHostProcessingLatency != 0) {
            times += tr(" · PC %1 ms").arg(number(stats.totalHostProcessingLatency / 10.0
                                                  / stats.framesWithHostProcessingLatency));
        }
        view.lines.append(times);
    }
    return view;
}

void close()
{
    s_open = false;
    s_armed = false;
    s_wantFrame = false;
    s_backdrop = QImage();
    render();
}

// Quitte le flux ; l'accueil fera la suite (ConsoleHome.returnedHome). Le menu reste
// à l'écran jusqu'à la fermeture de la fenêtre du flux.
void leave(const QString& action)
{
    s_exit = action;
    s_open = false;
    SDL_Event quit;
    quit.type = SDL_QUIT;
    quit.quit.timestamp = SDL_GetTicks();
    SDL_PushEvent(&quit);
}

void step(int direction)
{
    const int next = s_focus + direction;
    if (next < 0 || next >= view().labels.size()) {
        return;
    }
    s_focus = next;
    render();
}

void back()
{
    if (s_confirm.isEmpty()) {
        close();
        return;
    }
    const QList<Action> list = actions();
    for (int i = 0; i < list.size(); i++) {
        if (list[i].key == s_confirm) {
            s_focus = i;
        }
    }
    s_confirm.clear();
    render();
}

void activate()
{
    if (!s_confirm.isEmpty()) {
        if (s_focus == 1) {
            leave(s_confirm);
        }
        else {
            back();
        }
        return;
    }
    const QString key = actions().value(s_focus).key;
    if (key == QLatin1String("resume")) {
        close();
    }
    else if (key == QLatin1String("stats")) {
        switchStats();
    }
    else if (key == QLatin1String("quit") || key == QLatin1String("reboot") || key == QLatin1String("poweroff")) {
        s_confirm = key;
        s_focus = 0;   // Annuler : le choix sûr
        render();
    }
    else {
        leave(key);
    }
}

}

void StreamMenu::prepare(const QString& game, const QStringList& powerActions, const QString& buttonLayout)
{
    QMutexLocker locker(&s_lock);
    s_session = nullptr;
    s_open = false;
    s_exit.clear();
    s_game = game;
    s_power = powerActions;
    s_layout = buttonLayout;
    s_screen = QSize();
    s_stats = QSettings().value(STATS_SETTING, false).toBool();
    s_statsView = StreamPainter::Stats();
}

QString StreamMenu::takeExit()
{
    QMutexLocker locker(&s_lock);
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
        close();
        return;
    }
    s_open = true;
    s_focus = 0;
    s_confirm.clear();
    s_armed = false;
    s_stick = 0;
    s_screen = screenSize();
    s_backdrop = QImage();
    s_wantFrame = true;   // le voile en attendant l'image suivante (offerFrame)
    render();
}

void StreamMenu::onButton(uint8_t button, bool pressed)
{
    QMutexLocker locker(&s_lock);
    if (!s_open) {
        return;
    }
    if (!pressed) {
        if (button == SDL_CONTROLLER_BUTTON_A && s_armed) {
            s_armed = false;
            activate();
        }
        return;
    }
    switch (button) {
    case SDL_CONTROLLER_BUTTON_DPAD_UP:
    case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
        step(-1);
        break;
    case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
    case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
        step(1);
        break;
    case SDL_CONTROLLER_BUTTON_A:
        s_armed = true;
        break;
    case SDL_CONTROLLER_BUTTON_B:
        back();
        break;
    }
}

void StreamMenu::onAxis(uint8_t axis, int16_t value)
{
    if (axis != SDL_CONTROLLER_AXIS_LEFTY) {
        return;
    }
    QMutexLocker locker(&s_lock);
    if (!s_open) {
        return;
    }
    const int direction = value <= -STICK_PUSH ? -1 : value >= STICK_PUSH ? 1 : 0;
    if (direction != 0 && s_stick == 0) {
        step(direction);
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
    if (s_stats) {
        s_statsView = view;
        render();
    }
}

void StreamMenu::offerFrame(const AVFrame* frame)
{
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
        s_backdrop = backdrop;
        render();
    }
}
