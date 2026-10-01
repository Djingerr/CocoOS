#pragma once

// SystemStatus — état de la console : niveau de la batterie et force du signal
// Wi-Fi (barre haute), actions d'alimentation (menu Home). Compilé dans le build
// `embedded` seulement, comme le reste de app/gui/console/ (singleton QML `SystemStatus`).
//
// Sources, toutes génériques Linux (rien de propre à une carte) :
//   - batterie : /sys/class/power_supply (première batterie du système) ;
//   - Wi-Fi    : NetworkManager, par D-Bus (point d'accès actif du premier adaptateur) ;
//   - alimentation : systemd-logind, par D-Bus (veille, redémarrage, extinction).
// Une valeur de -1 signifie « pas de donnée » : la barre haute masque l'indicateur.

#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>

class SystemStatus : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY changed)   // 0 à 100, -1 sans batterie
    Q_PROPERTY(bool charging READ charging NOTIFY changed)              // la batterie est en charge
    Q_PROPERTY(int signalStrength READ signalStrength NOTIFY changed)   // 0 à 4, -1 sans Wi-Fi
    // Actions d'alimentation que logind autorise sans mot de passe, parmi
    // "suspend", "reboot", "poweroff" (lues une fois, au démarrage).
    Q_PROPERTY(QStringList powerActions READ powerActions CONSTANT)

public:
    explicit SystemStatus(QObject* parent = nullptr);

    int batteryPercent() const { return m_batteryPercent; }
    bool charging() const { return m_charging; }
    int signalStrength() const { return m_signalStrength; }
    QStringList powerActions() const { return m_powerActions; }

    // Met la console en veille, la redémarre ou l'éteint ("suspend", "reboot", "poweroff").
    Q_INVOKABLE void power(const QString& action);

    // Niveau de la première batterie système sous `powerSupplyDir`, -1 s'il n'y en a
    // pas ; `charging` dit si elle est en charge.
    static int readBattery(const QString& powerSupplyDir, bool* charging);
    // Force du signal NetworkManager (0 à 100) convertie en 0 à 4 barres.
    static int barsForStrength(int percent);

signals:
    void changed();

private slots:
    void refresh();

private:
    static int readWifi();
    static QStringList readPowerActions();

    QTimer m_timer;
    int m_batteryPercent = -1;
    bool m_charging = false;
    int m_signalStrength = -1;
    QStringList m_powerActions;
};
