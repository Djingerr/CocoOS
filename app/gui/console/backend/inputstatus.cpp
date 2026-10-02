#include "inputstatus.h"
#include "streammenu.h"

#include "SDL_compat.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QEvent>

namespace {

const int HOME_POLL_MS = 50;              // le rythme de SdlGamepadKeyNavigation
const int CONTROLLERS_POLL_MS = 2000;
const qint64 ACTIVITY_THROTTLE_MS = 500;

}

void InputStatus::prepareStreamMenu(const QString& game, const QStringList& powerActions,
                                    const QString& buttonLayout)
{
    StreamMenu::prepare(game, powerActions, buttonLayout);
}

QString InputStatus::takeStreamExit()
{
    return StreamMenu::takeExit();
}

InputStatus::InputStatus(QObject* parent)
    : QObject(parent)
{
    QCoreApplication::instance()->installEventFilter(this);

    connect(&m_homeTimer, &QTimer::timeout, this, &InputStatus::pollButtons);
    m_homeTimer.start(HOME_POLL_MS);
    connect(&m_controllersTimer, &QTimer::timeout, this, &InputStatus::refreshControllers);
    m_controllersTimer.start(CONTROLLERS_POLL_MS);
    refreshControllers();
}

QString InputStatus::layoutForType(int sdlControllerType)
{
    switch (sdlControllerType) {
    case SDL_CONTROLLER_TYPE_PS3:
    case SDL_CONTROLLER_TYPE_PS4:
    case SDL_CONTROLLER_TYPE_PS5:
        return QStringLiteral("playstation");
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_PRO:
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_LEFT:
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT:
    case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_PAIR:
        return QStringLiteral("nintendo");
    case SDL_CONTROLLER_TYPE_UNKNOWN:
        return QString();
    default:
        return QStringLiteral("xbox");
    }
}

int InputStatus::batteryForPowerLevel(int sdlPowerLevel)
{
    switch (sdlPowerLevel) {
    case SDL_JOYSTICK_POWER_EMPTY: return 0;
    case SDL_JOYSTICK_POWER_LOW: return 1;
    case SDL_JOYSTICK_POWER_MEDIUM: return 2;
    case SDL_JOYSTICK_POWER_FULL: return 3;
    default: return -1;      // filaire, inconnu
    }
}

bool InputStatus::eventFilter(QObject* watched, QEvent* event)
{
    switch (event->type()) {
    case QEvent::KeyPress:
    case QEvent::MouseButtonPress:
    case QEvent::MouseMove:
    case QEvent::Wheel:
    case QEvent::TouchBegin:
        noteActivity();
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

void InputStatus::noteActivity()
{
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_lastActivity >= ACTIVITY_THROTTLE_MS) {
        m_lastActivity = now;
        emit activity();
    }
}

void InputStatus::pollButtons()
{
    bool home = false, left = false, right = false;
    if (SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        for (int i = 0; i < SDL_NumJoysticks(); i++) {
            SDL_GameController* gc = SDL_GameControllerFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
            if (gc != nullptr) {
                home |= SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_GUIDE) != 0;
                left |= SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_LEFTSHOULDER) != 0;
                right |= SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER) != 0;
            }
        }
    }
    // Sur l'appui seulement (front montant)
    if (home && !m_homeDown) {
        noteActivity();
        emit homePressed();
    }
    if (left && !m_leftDown) {
        noteActivity();
        emit bumperPressed(-1);
    }
    if (right && !m_rightDown) {
        noteActivity();
        emit bumperPressed(1);
    }
    m_homeDown = home;
    m_leftDown = left;
    m_rightDown = right;
}

void InputStatus::refreshControllers()
{
    QString layout;
    int battery = -1;
    if (SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        for (int i = 0; i < SDL_NumJoysticks(); i++) {
            if (!SDL_IsGameController(i)) {
                continue;
            }
            layout = layoutForType(SDL_GameControllerTypeForIndex(i));
            SDL_Joystick* joystick = SDL_JoystickFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
            if (joystick != nullptr) {
                battery = batteryForPowerLevel(SDL_JoystickCurrentPowerLevel(joystick));
            }
            break;
        }
    }
    if (layout != m_layout || battery != m_controllerBattery) {
        m_layout = layout;
        m_controllerBattery = battery;
        emit controllersChanged();
    }
}
