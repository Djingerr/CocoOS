#include "inputstatus.h"

#include <QKeyEvent>
#include <QWindow>
#include "streammenu.h"

#include "SDL_compat.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QEvent>

namespace {

const int HOME_POLL_MS = 50;              // le rythme de SdlGamepadKeyNavigation
const int CONTROLLERS_POLL_MS = 2000;
const qint64 ACTIVITY_THROTTLE_MS = 500;
const int TRIGGER_PRESS = 16000;          // gâchette (0 à 32767) : enfoncée au-delà de la moitié

}

void InputStatus::prepareStreamMenu(const QString& game, const QStringList& powerActions,
                                    const QString& buttonLayout, QObject* system, const QVariantMap& info)
{
    StreamMenu::prepare(game, powerActions, buttonLayout, system, info);
}

QString InputStatus::takeStreamExit()
{
    return StreamMenu::takeExit();
}

void InputStatus::feedback(const QString& sound, double level)
{
    StreamMenu::rumble(sound, level);
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
    // La touche power, une fois (à la fenêtre, avant les éléments), et gardée pour nous.
    if ((event->type() == QEvent::KeyPress || event->type() == QEvent::KeyRelease) && qobject_cast<QWindow*>(watched)) {
        const QKeyEvent* key = static_cast<const QKeyEvent*>(event);
        if (key->key() == Qt::Key_PowerOff || key->key() == Qt::Key_PowerDown
                || key->key() == Qt::Key_Sleep || key->key() == Qt::Key_Suspend) {
            if (!key->isAutoRepeat()) {
                emit powerKey(event->type() == QEvent::KeyPress);
            }
            return true;
        }
    }
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

bool InputStatus::startHeld() const
{
    if (!SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        return false;
    }
    for (int i = 0; i < SDL_NumJoysticks(); i++) {
        SDL_GameController* gc = SDL_GameControllerFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
        if (gc != nullptr && SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_START)) {
            return true;
        }
    }
    return false;
}

void InputStatus::pollButtons()
{
    bool home = false, left = false, right = false, leftTrigger = false, rightTrigger = false;
    bool leftStick = false, rightStick = false;
    if (SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        for (int i = 0; i < SDL_NumJoysticks(); i++) {
            SDL_GameController* gc = SDL_GameControllerFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
            if (gc != nullptr) {
                home |= SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_GUIDE) != 0;
                left |= SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_LEFTSHOULDER) != 0;
                right |= SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER) != 0;
                leftTrigger |= SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_TRIGGERLEFT) > TRIGGER_PRESS;
                rightTrigger |= SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_TRIGGERRIGHT) > TRIGGER_PRESS;
                leftStick |= SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_LEFTSTICK) != 0;
                rightStick |= SDL_GameControllerGetButton(gc, SDL_CONTROLLER_BUTTON_RIGHTSTICK) != 0;
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
    if (leftTrigger && !m_leftTriggerDown) {
        noteActivity();
        emit triggerPressed(-1);
    }
    if (rightTrigger && !m_rightTriggerDown) {
        noteActivity();
        emit triggerPressed(1);
    }
    if (leftStick && !m_leftStickDown) {
        noteActivity();
        emit stickPressed(-1);
    }
    if (rightStick && !m_rightStickDown) {
        noteActivity();
        emit stickPressed(1);
    }
    m_leftStickDown = leftStick;
    m_rightStickDown = rightStick;
    m_leftTriggerDown = leftTrigger;
    m_rightTriggerDown = rightTrigger;
    m_homeDown = home;
    m_leftDown = left;
    m_rightDown = right;
}

void InputStatus::refreshControllers()
{
    QVariantList controllers;
    if (SDL_WasInit(SDL_INIT_GAMECONTROLLER)) {
        for (int i = 0; i < SDL_NumJoysticks(); i++) {
            if (!SDL_IsGameController(i)) {
                continue;
            }
            SDL_Joystick* joystick = SDL_JoystickFromInstanceID(SDL_JoystickGetDeviceInstanceID(i));
            const char* name = SDL_GameControllerNameForIndex(i);
            controllers.append(QVariantMap {
                { QStringLiteral("name"), QString::fromUtf8(name != nullptr ? name : "") },
                { QStringLiteral("family"), layoutForType(SDL_GameControllerTypeForIndex(i)) },
                { QStringLiteral("battery"), joystick != nullptr
                      ? batteryForPowerLevel(SDL_JoystickCurrentPowerLevel(joystick)) : -1 },
            });
        }
    }
    // Famille et batterie : celles de la première.
    const QVariantMap first = controllers.isEmpty() ? QVariantMap() : controllers.first().toMap();
    const QString layout = first.value(QStringLiteral("family")).toString();
    const int battery = first.value(QStringLiteral("battery"), -1).toInt();
    const int count = controllers.size();
    if (controllers != m_controllers) {
        m_controllers = controllers;
        m_layout = layout;
        m_controllerBattery = battery;
        m_controllerCount = count;
        emit controllersChanged();
    }
}
