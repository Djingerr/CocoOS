#pragma once

// WifiSetup — choix du réseau Wi-Fi depuis la console, sans bureau : réseaux
// visibles, connexion (mot de passe saisi au clavier à l'écran), état du réseau.
// Passe par NetworkManager (D-Bus). Compilé dans le build `embedded` seulement,
// comme le reste de app/gui/console/ (singleton QML `WifiSetup`).

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>

class WifiSetup : public QObject
{
    Q_OBJECT

    // Un adaptateur Wi-Fi géré par NetworkManager.
    Q_PROPERTY(bool available READ available NOTIFY stateChanged)
    // Le réseau local est joignable (Wi-Fi ou câble) : de quoi trouver le PC.
    Q_PROPERTY(bool online READ online NOTIFY stateChanged)
    // Réseau Wi-Fi en cours ; vide sans Wi-Fi.
    Q_PROPERTY(QString currentNetwork READ currentNetwork NOTIFY stateChanged)
    // Réseaux visibles, le plus fort d'abord : [{ ssid, bars (0 à 4), secured, known, active }].
    Q_PROPERTY(QVariantList networks READ networks NOTIFY networksChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY networksChanged)
    Q_PROPERTY(bool connecting READ connecting NOTIFY stateChanged)

public:
    explicit WifiSetup(QObject* parent = nullptr);

    // Premier relevé (D-Bus, synchrone) et suivi de NetworkManager. Appelé à la fin de
    // l'animation de démarrage : rien ne doit bloquer le fil GUI pendant celle-ci.
    Q_INVOKABLE void start();

    bool available() const { return !m_device.isEmpty(); }
    bool online() const { return m_online; }
    QString currentNetwork() const { return m_currentNetwork; }
    QVariantList networks() const { return m_networks; }
    bool scanning() const { return m_scanning; }
    bool connecting() const { return m_connecting; }

    // Demande une recherche ; la liste suit quelques secondes plus tard.
    Q_INVOKABLE void scan();
    // Se connecte à `ssid`. Mot de passe vide : réseau ouvert, ou déjà connu.
    Q_INVOKABLE void connectTo(const QString& ssid, const QString& password);

    // Message pour l'utilisateur d'après la raison d'échec NetworkManager.
    static QString failureMessage(uint reason);
    static bool isBadPassword(uint reason);

signals:
    void stateChanged();
    void networksChanged();
    // `badPassword` : le réseau a refusé le mot de passe (à redemander).
    void connectFinished(bool ok, const QString& error, bool badPassword);

private slots:
    void refreshState();
    void readNetworks();
    void onDeviceStateChanged(uint newState, uint oldState, uint reason);

private:
    QString findWifiDevice() const;
    QString knownConnection(const QString& ssid) const;
    void finishConnect(bool ok, const QString& error, bool badPassword = false);

    QString m_device;               // chemin D-Bus de l'adaptateur Wi-Fi
    bool m_online = false;
    QString m_currentNetwork;
    QVariantList m_networks;
    bool m_scanning = false;
    bool m_connecting = false;
    QTimer m_stateTimer;
    QTimer m_connectTimeout;
    bool m_started = false;
};
