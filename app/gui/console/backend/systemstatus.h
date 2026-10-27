#pragma once

// SystemStatus — état de la console : niveau de la batterie et force du signal
// Wi-Fi (barre haute), actions d'alimentation (menu Home). Compilé dans le build
// `embedded` seulement, comme le reste de app/gui/console/ (singleton QML `SystemStatus`).
//
// Sources, toutes génériques Linux (rien de propre à une carte) :
//   - batterie : /sys/class/power_supply (première batterie du système) ;
//   - Wi-Fi    : NetworkManager, par D-Bus (point d'accès actif du premier adaptateur) ;
//   - alimentation : systemd-logind, par D-Bus (veille, redémarrage, extinction, et
//     sortie de suspension : signal PrepareForSleep) ;
//   - réseau vers le PC : temps d'ouverture d'une connexion TCP vers son port HTTP
//     Moonlight (un aller-retour), mesuré toutes les 3 s tant qu'on le demande ;
//   - luminosité : /sys/class/backlight (lecture), logind SetBrightness (écriture,
//     sans droits root) ; volume : wpctl (PipeWire / WirePlumber).
// Une valeur de -1 signifie « pas de donnée » : la barre haute masque l'indicateur.

#include <QElapsedTimer>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

class ComputerManager;
class QTcpSocket;

class SystemStatus : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY changed)   // 0 à 100, -1 sans batterie
    Q_PROPERTY(bool charging READ charging NOTIFY changed)              // la batterie est en charge
    Q_PROPERTY(int signalStrength READ signalStrength NOTIFY changed)   // 0 à 4, -1 sans Wi-Fi
    // Détails de la batterie, -1 quand le pilote ne les donne pas : { minutes (avant d'être
    // vide, ou pleine en charge), watts (puissance qui sort ou entre), health (capacité
    // restante par rapport à celle d'origine, en %), status (celui du noyau : "Charging",
    // "Discharging", "Full", "Not charging") }.
    Q_PROPERTY(QVariantMap batteryDetails READ batteryDetails NOTIFY changed)
    // Réseau Wi-Fi associé : { ssid, strength (0 à 100), frequency (MHz), bitrate (Mb/s),
    // ip, secured } ; vide sans Wi-Fi.
    Q_PROPERTY(QVariantMap wifi READ wifi NOTIFY changed)
    // Actions d'alimentation que logind autorise sans mot de passe, parmi
    // "suspend", "reboot", "poweroff" (lues une fois, par start()).
    Q_PROPERTY(QStringList powerActions READ powerActions NOTIFY changed)
    // Réseau vers le PC sondé (probeHost) : latence (médiane) et gigue, en ms ; -1 sans mesure.
    Q_PROPERTY(int latencyMs READ latencyMs NOTIFY networkChanged)
    Q_PROPERTY(int jitterMs READ jitterMs NOTIFY networkChanged)
    // Luminosité de l'écran et volume de la sortie son, en % ; -1 si non réglable.
    Q_PROPERTY(int brightness READ brightness NOTIFY changed)
    Q_PROPERTY(int volume READ volume NOTIFY changed)

public:
    explicit SystemStatus(QObject* parent = nullptr);

    // Premiers relevés (D-Bus, synchrones) puis rafraîchissement régulier. Appelé à la
    // fin de l'animation de démarrage : rien ne doit bloquer le fil GUI pendant celle-ci.
    Q_INVOKABLE void start();

    int batteryPercent() const { return m_batteryPercent; }
    bool charging() const { return m_charging; }
    int signalStrength() const { return m_signalStrength; }
    QVariantMap batteryDetails() const { return m_batteryDetails; }
    QVariantMap wifi() const { return m_wifi; }
    QStringList powerActions() const { return m_powerActions; }
    int latencyMs() const { return m_latencyMs; }
    int jitterMs() const { return m_jitterMs; }
    int brightness() const { return m_brightness; }
    int volume() const { return m_volume; }

    Q_INVOKABLE void setBrightness(int percent);
    // Variable d'environnement (réglages de debug, ex. COCOOS_BOOT_SPEED) ; vide si absente.
    Q_INVOKABLE QString env(const QString& name) const { return qEnvironmentVariable(name.toUtf8().constData()); }
    Q_INVOKABLE void setVolume(int percent);

    // Sonde le PC `hostName` connu de `computerManager` (le singleton QML), jusqu'à
    // stopProbing(). Les mesures repartent de zéro.
    Q_INVOKABLE void probeHost(QObject* computerManager, const QString& hostName);
    Q_INVOKABLE void stopProbing();

    // Latence (médiane) et gigue (écart moyen entre mesures successives) d'une série
    // de temps d'aller-retour, en ms.
    static int median(QList<int> samples);
    static int jitter(const QList<int>& samples);

    // Met la console en veille, la redémarre ou l'éteint ("suspend", "reboot", "poweroff").
    Q_INVOKABLE void power(const QString& action);

    // Niveau de la première batterie système sous `powerSupplyDir`, -1 s'il n'y en a
    // pas ; `charging` dit si elle est en charge, `details` reçoit batteryDetails.
    static int readBattery(const QString& powerSupplyDir, bool* charging, QVariantMap* details);
    // Force du signal NetworkManager (0 à 100) convertie en 0 à 4 barres.
    static int barsForStrength(int percent);

signals:
    void changed();
    void networkChanged();
    void resumed();             // le système sort de suspension (logind)

private slots:
    void refresh();
    void probe();
    void onPrepareForSleep(bool start);

private:
    static QVariantMap readWifi();
    static QStringList readPowerActions();
    static QString backlightDir();
    void readVolume();

    QTimer m_timer;
    int m_batteryPercent = -1;
    bool m_charging = false;
    int m_signalStrength = -1;
    QVariantMap m_batteryDetails;
    QVariantMap m_wifi;
    QStringList m_powerActions;
    bool m_started = false;
    int m_brightness = -1;
    int m_volume = -1;

    void finishProbe(int rttMs);

    QTimer m_probeTimer;
    QPointer<ComputerManager> m_probeManager;
    QString m_probeHost;
    QTcpSocket* m_probeSocket = nullptr;
    QElapsedTimer m_probeClock;
    QList<int> m_samples;
    int m_latencyMs = -1;
    int m_jitterMs = -1;
};
