#include "streammenu.h"
#include "streampainter.h"

#include "streaming/session.h"

#include <QCoreApplication>
#include <QMutex>
#include <QMutexLocker>

namespace {

// Stick gauche : une marche quand il passe la poussée, la suivante une fois revenu
// sous le repos.
const int STICK_PUSH = 20000;
const int STICK_REST = 10000;

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

QString tr(const char* text)
{
    return QCoreApplication::translate("StreamMenu", text);
}

QList<Action> actions()
{
    QList<Action> list = {
        { "resume", tr("Reprendre") },
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
    if (s_confirm.isEmpty()) {
        menu.title = s_game.isEmpty() ? tr("Menu") : s_game;
        for (const Action& action : actions()) {
            menu.labels.append(action.label);
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

// Pose (ou retire) le menu sur l'image du flux. s_lock tenu.
void render()
{
    Session* session = Session::get();
    if (session == nullptr || session != s_session) {
        return;
    }
    QImage image;
    if (s_open && s_screen.isValid()) {
        image = StreamPainter::paintMenu(view(), s_screen);
    }
    session->getOverlayManager().setOverlaySurface(Overlay::OverlayDebug, toSurface(image));
}

void close()
{
    s_open = false;
    s_armed = false;
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
    Session* session = Session::get();
    if (s_open && s_session == session) {
        close();
        return;
    }
    s_session = session;
    s_open = true;
    s_focus = 0;
    s_confirm.clear();
    s_armed = false;
    s_stick = 0;
    s_screen = screenSize();
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
