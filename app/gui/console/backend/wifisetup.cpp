#include "wifisetup.h"

#include "systemstatus.h"

#include <algorithm>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QMap>
#include <QSet>
#include <QVariantMap>

// Réglages d'une connexion NetworkManager : a{sa{sv}}.
typedef QMap<QString, QVariantMap> NMSettings;
Q_DECLARE_METATYPE(NMSettings)

namespace {

const QString NM = QStringLiteral("org.freedesktop.NetworkManager");
const QString NM_PATH = QStringLiteral("/org/freedesktop/NetworkManager");
const QString NM_SETTINGS_PATH = QStringLiteral("/org/freedesktop/NetworkManager/Settings");
const QString NM_DEVICE = NM + QStringLiteral(".Device");
const QString NM_WIRELESS = NM + QStringLiteral(".Device.Wireless");
const QString NM_AP = NM + QStringLiteral(".AccessPoint");
const int DBUS_TIMEOUT_MS = 500;
const int STATE_POLL_MS = 5000;           // en plus des signaux, au cas où
const int SCAN_SETTLE_MS = 3500;          // le temps que l'adaptateur balaie les canaux
const int CONNECT_TIMEOUT_MS = 30000;

const uint DEVICE_TYPE_WIFI = 2;
const uint NM_STATE_CONNECTED_LOCAL = 50;
const uint DEVICE_STATE_ACTIVATED = 100;
const uint DEVICE_STATE_FAILED = 120;
const uint AP_FLAGS_PRIVACY = 0x1;
const uint AP_SEC_KEY_MGMT_PSK = 0x100;
const uint AP_SEC_KEY_MGMT_SAE = 0x400;

QDBusConnection bus()
{
    return QDBusConnection::systemBus();
}

}

WifiSetup::WifiSetup(QObject* parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<NMSettings>();

    m_connectTimeout.setSingleShot(true);
    connect(&m_connectTimeout, &QTimer::timeout, this, [this] {
        finishConnect(false, tr("Le réseau ne répond pas."));
    });
    connect(&m_stateTimer, &QTimer::timeout, this, &WifiSetup::refreshState);
}

void WifiSetup::start()
{
    if (m_started) {
        return;
    }
    m_started = true;
    m_stateTimer.start(STATE_POLL_MS);
    if (bus().isConnected()) {
        bus().connect(NM, NM_PATH, NM, QStringLiteral("StateChanged"), this, SLOT(refreshState()));
    }
    refreshState();
    readNetworks();
}

bool WifiSetup::isBadPassword(uint reason)
{
    // NO_SECRETS, SUPPLICANT_DISCONNECT, SUPPLICANT_CONFIG_FAILED
    return reason == 7 || reason == 8 || reason == 9;
}

QString WifiSetup::failureMessage(uint reason)
{
    if (isBadPassword(reason)) {
        return tr("Mot de passe incorrect.");
    }
    switch (reason) {
    case 11:    // SUPPLICANT_TIMEOUT
        return tr("Le réseau ne répond pas.");
    case 53:    // SSID_NOT_FOUND
        return tr("Réseau introuvable.");
    default:
        return tr("Connexion impossible.");
    }
}

QString WifiSetup::findWifiDevice() const
{
    QDBusInterface manager(NM, NM_PATH, NM, bus());
    manager.setTimeout(DBUS_TIMEOUT_MS);
    QDBusReply<QList<QDBusObjectPath>> devices = manager.call(QStringLiteral("GetDevices"));
    if (!devices.isValid()) {
        return QString();
    }
    for (const QDBusObjectPath& device : devices.value()) {
        QDBusInterface iface(NM, device.path(), NM_DEVICE, bus());
        iface.setTimeout(DBUS_TIMEOUT_MS);
        if (iface.property("DeviceType").toUInt() == DEVICE_TYPE_WIFI) {
            return device.path();
        }
    }
    return QString();
}

void WifiSetup::refreshState()
{
    if (!bus().isConnected()) {
        return;
    }
    if (m_device.isEmpty()) {
        // (un adaptateur peut apparaître après coup : dongle USB)
        m_device = findWifiDevice();
        if (!m_device.isEmpty()) {
            bus().connect(NM, m_device, NM_DEVICE, QStringLiteral("StateChanged"),
                          this, SLOT(onDeviceStateChanged(uint,uint,uint)));
        }
    }

    QDBusInterface manager(NM, NM_PATH, NM, bus());
    manager.setTimeout(DBUS_TIMEOUT_MS);
    bool online = manager.property("State").toUInt() >= NM_STATE_CONNECTED_LOCAL;

    QString current;
    if (!m_device.isEmpty()) {
        QDBusInterface wireless(NM, m_device, NM_WIRELESS, bus());
        wireless.setTimeout(DBUS_TIMEOUT_MS);
        const QString ap = wireless.property("ActiveAccessPoint").value<QDBusObjectPath>().path();
        if (!ap.isEmpty() && ap != QLatin1String("/")) {
            QDBusInterface apIface(NM, ap, NM_AP, bus());
            apIface.setTimeout(DBUS_TIMEOUT_MS);
            current = QString::fromUtf8(apIface.property("Ssid").toByteArray());
        }
    }

    if (online != m_online || current != m_currentNetwork) {
        m_online = online;
        m_currentNetwork = current;
        emit stateChanged();
    }
}

void WifiSetup::scan()
{
    if (m_device.isEmpty() || m_scanning) {
        return;
    }
    QDBusInterface wireless(NM, m_device, NM_WIRELESS, bus());
    wireless.asyncCall(QStringLiteral("RequestScan"), QVariantMap());
    m_scanning = true;
    emit networksChanged();
    QTimer::singleShot(SCAN_SETTLE_MS, this, &WifiSetup::readNetworks);
}

void WifiSetup::readNetworks()
{
    QVariantList networks;
    if (!m_device.isEmpty()) {
        QDBusInterface wireless(NM, m_device, NM_WIRELESS, bus());
        wireless.setTimeout(DBUS_TIMEOUT_MS);
        QDBusReply<QList<QDBusObjectPath>> aps = wireless.call(QStringLiteral("GetAllAccessPoints"));

        // Le point d'accès le plus fort de chaque réseau (un réseau = un SSID).
        QMap<QString, QVariantMap> best;
        if (aps.isValid()) {
            for (const QDBusObjectPath& ap : aps.value()) {
                QDBusInterface iface(NM, ap.path(), NM_AP, bus());
                iface.setTimeout(DBUS_TIMEOUT_MS);
                const QString ssid = QString::fromUtf8(iface.property("Ssid").toByteArray());
                if (ssid.isEmpty()) {
                    continue;   // réseau masqué
                }
                int strength = iface.property("Strength").toInt();
                if (best.contains(ssid) && best[ssid][QStringLiteral("strength")].toInt() >= strength) {
                    continue;
                }
                uint rsn = iface.property("RsnFlags").toUInt();
                uint wpa = iface.property("WpaFlags").toUInt();
                bool secured = (iface.property("Flags").toUInt() & AP_FLAGS_PRIVACY) || rsn || wpa;
                // WPA3 seul : « sae » ; sinon WPA2 (« wpa-psk », que NetworkManager
                // ouvre aussi en transition WPA2 / WPA3).
                bool saeOnly = (rsn & AP_SEC_KEY_MGMT_SAE) && !((rsn | wpa) & AP_SEC_KEY_MGMT_PSK);
                best[ssid] = QVariantMap {
                    { QStringLiteral("ssid"), ssid },
                    { QStringLiteral("strength"), strength },
                    { QStringLiteral("bars"), SystemStatus::barsForStrength(strength) },
                    { QStringLiteral("secured"), secured },
                    { QStringLiteral("keyMgmt"), saeOnly ? QStringLiteral("sae") : QStringLiteral("wpa-psk") },
                };
            }
        }

        QList<QVariantMap> list = best.values();
        for (QVariantMap& network : list) {
            const QString ssid = network[QStringLiteral("ssid")].toString();
            network[QStringLiteral("active")] = ssid == m_currentNetwork;
            network[QStringLiteral("known")] = !knownConnection(ssid).isEmpty();
        }
        std::sort(list.begin(), list.end(), [](const QVariantMap& a, const QVariantMap& b) {
            if (a[QStringLiteral("active")].toBool() != b[QStringLiteral("active")].toBool()) {
                return a[QStringLiteral("active")].toBool();
            }
            return a[QStringLiteral("strength")].toInt() > b[QStringLiteral("strength")].toInt();
        });
        for (const QVariantMap& network : list) {
            networks << network;
        }
    }

    m_scanning = false;
    m_networks = networks;
    emit networksChanged();
}

QString WifiSetup::knownConnection(const QString& ssid) const
{
    QDBusInterface settings(NM, NM_SETTINGS_PATH, NM + QStringLiteral(".Settings"), bus());
    settings.setTimeout(DBUS_TIMEOUT_MS);
    QDBusReply<QList<QDBusObjectPath>> connections = settings.call(QStringLiteral("ListConnections"));
    if (!connections.isValid()) {
        return QString();
    }
    for (const QDBusObjectPath& connection : connections.value()) {
        QDBusInterface iface(NM, connection.path(), NM + QStringLiteral(".Settings.Connection"), bus());
        iface.setTimeout(DBUS_TIMEOUT_MS);
        QDBusReply<NMSettings> reply = iface.call(QStringLiteral("GetSettings"));
        if (reply.isValid() &&
                reply.value().value(QStringLiteral("802-11-wireless")).value(QStringLiteral("ssid")).toByteArray() == ssid.toUtf8()) {
            return connection.path();
        }
    }
    return QString();
}

void WifiSetup::connectTo(const QString& ssid, const QString& password)
{
    if (m_device.isEmpty() || m_connecting) {
        return;
    }

    QDBusInterface manager(NM, NM_PATH, NM, bus());
    const QVariant device = QVariant::fromValue(QDBusObjectPath(m_device));
    const QVariant anyAccessPoint = QVariant::fromValue(QDBusObjectPath(QStringLiteral("/")));
    const QString known = knownConnection(ssid);
    QDBusMessage reply;
    if (!known.isEmpty() && password.isEmpty()) {
        reply = manager.call(QStringLiteral("ActivateConnection"),
                             QVariant::fromValue(QDBusObjectPath(known)), device, anyAccessPoint);
    }
    else {
        QString keyMgmt = QStringLiteral("wpa-psk");
        for (const QVariant& network : m_networks) {
            if (network.toMap().value(QStringLiteral("ssid")).toString() == ssid) {
                keyMgmt = network.toMap().value(QStringLiteral("keyMgmt")).toString();
            }
        }
        NMSettings settings;
        settings[QStringLiteral("connection")] = QVariantMap {
            { QStringLiteral("id"), ssid }, { QStringLiteral("type"), QStringLiteral("802-11-wireless") },
        };
        settings[QStringLiteral("802-11-wireless")] = QVariantMap {
            { QStringLiteral("ssid"), ssid.toUtf8() }, { QStringLiteral("mode"), QStringLiteral("infrastructure") },
        };
        if (!password.isEmpty()) {
            settings[QStringLiteral("802-11-wireless-security")] = QVariantMap {
                { QStringLiteral("key-mgmt"), keyMgmt }, { QStringLiteral("psk"), password },
            };
        }
        reply = manager.call(QStringLiteral("AddAndActivateConnection"),
                             QVariant::fromValue(settings), device, anyAccessPoint);
    }

    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning("WifiSetup: %s", qPrintable(reply.errorMessage()));
        emit connectFinished(false, tr("Connexion impossible."), false);
        return;
    }
    m_connecting = true;
    m_connectTimeout.start(CONNECT_TIMEOUT_MS);
    emit stateChanged();
}

void WifiSetup::onDeviceStateChanged(uint newState, uint, uint reason)
{
    if (m_connecting) {
        if (newState == DEVICE_STATE_ACTIVATED) {
            finishConnect(true, QString());
        }
        else if (newState == DEVICE_STATE_FAILED) {
            finishConnect(false, failureMessage(reason), isBadPassword(reason));
        }
    }
    refreshState();
}

void WifiSetup::finishConnect(bool ok, const QString& error, bool badPassword)
{
    if (!m_connecting) {
        return;
    }
    m_connectTimeout.stop();
    m_connecting = false;
    refreshState();
    emit stateChanged();
    emit connectFinished(ok, error, badPassword);
    readNetworks();
}
