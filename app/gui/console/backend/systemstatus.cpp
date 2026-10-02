#include "systemstatus.h"

#include "backend/computermanager.h"

#include <algorithm>

#include <QDir>
#include <QFile>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QProcess>
#include <QRegularExpression>
#include <QTcpSocket>

namespace {

const int REFRESH_INTERVAL_MS = 10000;
const int PROBE_INTERVAL_MS = 3000;
const int PROBE_TIMEOUT_MS = 1500;
const int PROBE_SAMPLES = 8;            // fenêtre glissante des mesures
// Un NetworkManager qui ne répond pas ne doit pas figer l'interface.
const int DBUS_TIMEOUT_MS = 300;

const QString NM_SERVICE = QStringLiteral("org.freedesktop.NetworkManager");
const QString NM_PATH = QStringLiteral("/org/freedesktop/NetworkManager");
const uint NM_DEVICE_TYPE_WIFI = 2;

const QString LOGIN_SERVICE = QStringLiteral("org.freedesktop.login1");
const QString LOGIN_PATH = QStringLiteral("/org/freedesktop/login1");
const QString LOGIN_MANAGER = QStringLiteral("org.freedesktop.login1.Manager");
// Action de l'UI → méthodes logind (Can…, puis l'action elle-même).
const struct { const char* action; const char* method; } POWER_METHODS[] = {
    { "suspend", "Suspend" }, { "reboot", "Reboot" }, { "poweroff", "PowerOff" },
};

QString readLine(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromLatin1(file.readLine()).trimmed();
}

}

SystemStatus::SystemStatus(QObject* parent)
    : QObject(parent)
{
    connect(&m_probeTimer, &QTimer::timeout, this, &SystemStatus::probe);
    connect(&m_timer, &QTimer::timeout, this, &SystemStatus::refresh);
}

void SystemStatus::start()
{
    if (m_started) {
        return;
    }
    m_started = true;
    m_timer.start(REFRESH_INTERVAL_MS);
    QDBusConnection::systemBus().connect(LOGIN_SERVICE, LOGIN_PATH, LOGIN_MANAGER, QStringLiteral("PrepareForSleep"),
                                         this, SLOT(onPrepareForSleep(bool)));
    m_powerActions = readPowerActions();
    refresh();
    emit changed();

    qInfo("SystemStatus: battery %d %%%s, Wi-Fi %d/4 (-1 = none), power: %s",
          m_batteryPercent, m_charging ? " (charging)" : "", m_signalStrength,
          qPrintable(m_powerActions.join(QLatin1Char(' '))));
}

QStringList SystemStatus::readPowerActions()
{
    QStringList actions;
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        return actions;
    }
    QDBusInterface manager(LOGIN_SERVICE, LOGIN_PATH, LOGIN_MANAGER, bus);
    manager.setTimeout(DBUS_TIMEOUT_MS);
    for (const auto& power : POWER_METHODS) {
        // « challenge » demanderait un mot de passe, impossible sur la console.
        QDBusReply<QString> can = manager.call(QStringLiteral("Can") + QLatin1String(power.method));
        if (can.isValid() && can.value() == QLatin1String("yes")) {
            actions << QLatin1String(power.action);
        }
    }
    return actions;
}

void SystemStatus::power(const QString& action)
{
    for (const auto& power : POWER_METHODS) {
        if (action == QLatin1String(power.action) && m_powerActions.contains(action)) {
            qInfo("SystemStatus: %s", power.method);
            QDBusInterface manager(LOGIN_SERVICE, LOGIN_PATH, LOGIN_MANAGER, QDBusConnection::systemBus());
            manager.asyncCall(QLatin1String(power.method), false);   // false : jamais de demande interactive
            return;
        }
    }
    qWarning("SystemStatus: unavailable power action %s", qPrintable(action));
}

void SystemStatus::refresh()
{
    bool charging = false;
    int battery = readBattery(QStringLiteral("/sys/class/power_supply"), &charging);
    int wifi = readWifi();
    int brightness = -1;
    const QString backlight = backlightDir();
    if (!backlight.isEmpty()) {
        int max = readLine(backlight + QStringLiteral("/max_brightness")).toInt();
        if (max > 0) {
            brightness = qRound(100.0 * readLine(backlight + QStringLiteral("/brightness")).toInt() / max);
        }
    }
    if (battery != m_batteryPercent || charging != m_charging || wifi != m_signalStrength ||
            brightness != m_brightness) {
        m_batteryPercent = battery;
        m_charging = charging;
        m_signalStrength = wifi;
        m_brightness = brightness;
        emit changed();
    }
    readVolume();
}

QString SystemStatus::backlightDir()
{
    const QString root = QStringLiteral("/sys/class/backlight");
    const QStringList devices = QDir(root).entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    return devices.isEmpty() ? QString() : root + QLatin1Char('/') + devices.first();
}

void SystemStatus::setBrightness(int percent)
{
    const QString backlight = backlightDir();
    if (backlight.isEmpty()) {
        return;
    }
    int max = readLine(backlight + QStringLiteral("/max_brightness")).toInt();
    // Jamais tout à fait noir : 5 % au moins, sinon on ne voit plus rien pour remonter.
    percent = qBound(5, percent, 100);
    QDBusInterface session(LOGIN_SERVICE, LOGIN_PATH + QStringLiteral("/session/auto"),
                           QStringLiteral("org.freedesktop.login1.Session"), QDBusConnection::systemBus());
    session.asyncCall(QStringLiteral("SetBrightness"), QStringLiteral("backlight"),
                      QDir(backlight).dirName(), uint(qRound(max * percent / 100.0)));
    if (percent != m_brightness) {
        m_brightness = percent;
        emit changed();
    }
}

void SystemStatus::readVolume()
{
    QProcess* wpctl = new QProcess(this);
    connect(wpctl, &QProcess::finished, this, [this, wpctl] {
        // « Volume: 0.55 » (suivi de « [MUTED] » si coupé)
        QRegularExpressionMatch match = QRegularExpression(QStringLiteral("Volume: ([0-9.]+)"))
                                            .match(QString::fromLatin1(wpctl->readAllStandardOutput()));
        int volume = match.hasMatch() ? qRound(match.captured(1).toDouble() * 100) : -1;
        wpctl->deleteLater();
        if (volume != m_volume) {
            m_volume = volume;
            emit changed();
        }
    });
    connect(wpctl, &QProcess::errorOccurred, wpctl, &QObject::deleteLater);   // pas de wpctl
    wpctl->start(QStringLiteral("wpctl"), { QStringLiteral("get-volume"), QStringLiteral("@DEFAULT_AUDIO_SINK@") });
}

void SystemStatus::setVolume(int percent)
{
    if (m_volume < 0) {
        return;
    }
    percent = qBound(0, percent, 100);
    QProcess::startDetached(QStringLiteral("wpctl"), { QStringLiteral("set-volume"),
                            QStringLiteral("@DEFAULT_AUDIO_SINK@"), QString::number(percent / 100.0) });
    if (percent != m_volume) {
        m_volume = percent;
        emit changed();
    }
}

int SystemStatus::readBattery(const QString& powerSupplyDir, bool* charging)
{
    *charging = false;
    const QStringList supplies = QDir(powerSupplyDir).entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString& name : supplies) {
        const QString dir = powerSupplyDir + QLatin1Char('/') + name;
        // Les manettes et souris sans fil exposent aussi une « Battery », de portée « Device ».
        if (readLine(dir + QStringLiteral("/type")) != QLatin1String("Battery") ||
                readLine(dir + QStringLiteral("/scope")) == QLatin1String("Device")) {
            continue;
        }

        bool ok = false;
        int percent = readLine(dir + QStringLiteral("/capacity")).toInt(&ok);
        if (ok) {
            *charging = readLine(dir + QStringLiteral("/status")) == QLatin1String("Charging");
            return qBound(0, percent, 100);
        }
    }
    return -1;
}

int SystemStatus::barsForStrength(int percent)
{
    // Mêmes seuils que nmcli.
    if (percent > 80) return 4;
    if (percent > 55) return 3;
    if (percent > 30) return 2;
    if (percent > 5) return 1;
    return 0;
}

int SystemStatus::readWifi()
{
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected() || !bus.interface()->isServiceRegistered(NM_SERVICE)) {
        return -1;
    }

    QDBusInterface manager(NM_SERVICE, NM_PATH, NM_SERVICE, bus);
    manager.setTimeout(DBUS_TIMEOUT_MS);
    QDBusReply<QList<QDBusObjectPath>> devices = manager.call(QStringLiteral("GetDevices"));
    if (!devices.isValid()) {
        return -1;
    }

    for (const QDBusObjectPath& device : devices.value()) {
        QDBusInterface deviceIface(NM_SERVICE, device.path(), NM_SERVICE + QStringLiteral(".Device"), bus);
        deviceIface.setTimeout(DBUS_TIMEOUT_MS);
        if (deviceIface.property("DeviceType").toUInt() != NM_DEVICE_TYPE_WIFI) {
            continue;
        }

        QDBusInterface wireless(NM_SERVICE, device.path(), NM_SERVICE + QStringLiteral(".Device.Wireless"), bus);
        wireless.setTimeout(DBUS_TIMEOUT_MS);
        const QString accessPoint = wireless.property("ActiveAccessPoint").value<QDBusObjectPath>().path();
        if (accessPoint.isEmpty() || accessPoint == QLatin1String("/")) {
            continue;   // adaptateur présent mais pas associé
        }

        QDBusInterface apIface(NM_SERVICE, accessPoint, NM_SERVICE + QStringLiteral(".AccessPoint"), bus);
        apIface.setTimeout(DBUS_TIMEOUT_MS);
        QVariant strength = apIface.property("Strength");
        if (strength.isValid()) {
            return barsForStrength(strength.toInt());
        }
    }
    return -1;
}

void SystemStatus::probeHost(QObject* computerManager, const QString& hostName)
{
    m_probeManager = qobject_cast<ComputerManager*>(computerManager);
    m_probeHost = hostName;
    m_samples.clear();
    if (m_latencyMs != -1 || m_jitterMs != -1) {
        m_latencyMs = m_jitterMs = -1;
        emit networkChanged();
    }
    m_probeTimer.start(PROBE_INTERVAL_MS);
    probe();
}

void SystemStatus::stopProbing()
{
    m_probeTimer.stop();
    m_probeManager = nullptr;
}

void SystemStatus::probe()
{
    if (m_probeManager == nullptr || m_probeSocket != nullptr) {
        return;
    }
    NvAddress address;
    for (NvComputer* computer : m_probeManager->getComputers()) {
        QReadLocker lock(&computer->lock);
        if (computer->name == m_probeHost) {
            address = computer->activeAddress;
            break;
        }
    }
    if (address.isNull()) {
        return;
    }

    QTcpSocket* socket = new QTcpSocket(this);
    m_probeSocket = socket;
    // (chaque issue ne vaut que pour CETTE sonde, pas pour une suivante)
    connect(socket, &QTcpSocket::connected, this, [this, socket] {
        if (m_probeSocket == socket) finishProbe(int(m_probeClock.elapsed()));
    });
    connect(socket, &QAbstractSocket::errorOccurred, this, [this, socket] {
        if (m_probeSocket == socket) finishProbe(-1);
    });
    QTimer::singleShot(PROBE_TIMEOUT_MS, socket, [this, socket] {
        if (m_probeSocket == socket) finishProbe(-1);
    });
    m_probeClock.start();
    socket->connectToHost(address.address(), address.port());
}

void SystemStatus::finishProbe(int rttMs)
{
    if (m_probeSocket == nullptr) {
        return;
    }
    m_probeSocket->abort();
    m_probeSocket->deleteLater();
    m_probeSocket = nullptr;
    if (rttMs < 0 || m_probeManager == nullptr) {
        return;
    }

    m_samples.append(rttMs);
    while (m_samples.size() > PROBE_SAMPLES) {
        m_samples.removeFirst();
    }
    int latency = median(m_samples);
    int jitterMs = m_samples.size() > 1 ? jitter(m_samples) : -1;
    if (latency != m_latencyMs || jitterMs != m_jitterMs) {
        m_latencyMs = latency;
        m_jitterMs = jitterMs;
        emit networkChanged();
    }
}

int SystemStatus::median(QList<int> samples)
{
    if (samples.isEmpty()) {
        return -1;
    }
    std::sort(samples.begin(), samples.end());
    return samples[samples.size() / 2];
}

int SystemStatus::jitter(const QList<int>& samples)
{
    if (samples.size() < 2) {
        return -1;
    }
    int total = 0;
    for (int i = 1; i < samples.size(); i++) {
        total += qAbs(samples[i] - samples[i - 1]);
    }
    return qRound(double(total) / (samples.size() - 1));
}

void SystemStatus::onPrepareForSleep(bool start)
{
    if (!start) {
        emit resumed();
    }
}
