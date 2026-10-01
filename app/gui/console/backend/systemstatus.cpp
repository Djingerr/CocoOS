#include "systemstatus.h"

#include <QDir>
#include <QFile>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusObjectPath>
#include <QDBusReply>

namespace {

const int REFRESH_INTERVAL_MS = 10000;
// Un NetworkManager qui ne répond pas ne doit pas figer l'interface.
const int DBUS_TIMEOUT_MS = 300;

const QString NM_SERVICE = QStringLiteral("org.freedesktop.NetworkManager");
const QString NM_PATH = QStringLiteral("/org/freedesktop/NetworkManager");
const uint NM_DEVICE_TYPE_WIFI = 2;

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
    connect(&m_timer, &QTimer::timeout, this, &SystemStatus::refresh);
    m_timer.start(REFRESH_INTERVAL_MS);
    refresh();

    qInfo("SystemStatus: battery %d %%%s, Wi-Fi %d/4 (-1 = none)",
          m_batteryPercent, m_charging ? " (charging)" : "", m_signalStrength);
}

void SystemStatus::refresh()
{
    bool charging = false;
    int battery = readBattery(QStringLiteral("/sys/class/power_supply"), &charging);
    int wifi = readWifi();
    if (battery != m_batteryPercent || charging != m_charging || wifi != m_signalStrength) {
        m_batteryPercent = battery;
        m_charging = charging;
        m_signalStrength = wifi;
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
