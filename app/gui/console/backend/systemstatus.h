#pragma once

// SystemStatus — état de la console affiché dans la barre haute : niveau de la
// batterie et force du signal Wi-Fi. Compilé dans le build `embedded` seulement,
// comme le reste de app/gui/console/ (singleton QML `SystemStatus`).
//
// Sources, toutes deux génériques Linux (rien de propre à une carte) :
//   - batterie : /sys/class/power_supply (première batterie du système) ;
//   - Wi-Fi    : NetworkManager, par D-Bus (point d'accès actif du premier adaptateur).
// Une valeur de -1 signifie « pas de donnée » : la barre haute masque l'indicateur.

#include <QObject>
#include <QString>
#include <QTimer>

class SystemStatus : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY changed)   // 0 à 100, -1 sans batterie
    Q_PROPERTY(bool charging READ charging NOTIFY changed)              // la batterie est en charge
    Q_PROPERTY(int signalStrength READ signalStrength NOTIFY changed)   // 0 à 4, -1 sans Wi-Fi

public:
    explicit SystemStatus(QObject* parent = nullptr);

    int batteryPercent() const { return m_batteryPercent; }
    bool charging() const { return m_charging; }
    int signalStrength() const { return m_signalStrength; }

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

    QTimer m_timer;
    int m_batteryPercent = -1;
    bool m_charging = false;
    int m_signalStrength = -1;
};
