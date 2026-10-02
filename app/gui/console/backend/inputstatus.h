#pragma once

// InputStatus — ce que fait l'utilisateur, pour l'UI console. Compilé dans le build
// `embedded` seulement, comme le reste de app/gui/console/ (singleton QML
// `InputStatus`).
//
//   - activité : toute touche, clic ou mouvement (la manette arrive en touches par
//     SdlGamepadKeyNavigation), pour l'écran de veille ;
//   - boutons Home (Guide), L1 et R1 de la manette : SdlGamepadKeyNavigation ne les
//     traduit en aucune touche, on lit donc leur état dans SDL (que cette navigation
//     met à jour toutes les 50 ms). Pendant un flux, Qt est suspendu : rien n'est lu ici ;
//   - manette branchée : sa famille (disposition des boutons) et sa batterie ;
//   - menu en jeu (StreamMenu) : l'accueil le prépare avant chaque flux et lit au
//     retour l'action qui a fait quitter le jeu.
// Rien n'est ouvert ni modifié côté SDL : on lit l'état des manettes que
// SdlGamepadKeyNavigation a déjà ouvertes.

#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>

class InputStatus : public QObject
{
    Q_OBJECT

    // Famille de la première manette : "xbox", "playstation" ou "nintendo" ;
    // vide sans manette (ou famille inconnue).
    Q_PROPERTY(QString layout READ layout NOTIFY controllersChanged)
    // Batterie de la première manette sans fil : 0 (vide) à 3 (pleine) ; -1 si
    // filaire, sans manette ou niveau inconnu.
    Q_PROPERTY(int controllerBattery READ controllerBattery NOTIFY controllersChanged)

public:
    explicit InputStatus(QObject* parent = nullptr);

    QString layout() const { return m_layout; }
    int controllerBattery() const { return m_controllerBattery; }

    // Menu en jeu (StreamMenu) : le nom du jeu, les actions d'alimentation et les
    // glyphes à montrer, avant chaque flux ; au retour, l'action choisie ("home",
    // "quit", "suspend", "reboot", "poweroff"), vide si le flux s'est fini autrement.
    Q_INVOKABLE void prepareStreamMenu(const QString& game, const QStringList& powerActions,
                                       const QString& buttonLayout);
    Q_INVOKABLE QString takeStreamExit();

    // Correspondances SDL → UI (statiques pour être vérifiables seules).
    static QString layoutForType(int sdlControllerType);
    static int batteryForPowerLevel(int sdlPowerLevel);

signals:
    void activity();            // l'utilisateur a agi (au plus une fois toutes les 500 ms)
    void homePressed();         // bouton Home de la manette
    void bumperPressed(int direction);   // L1 (-1) ou R1 (+1)
    void controllersChanged();

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private slots:
    void pollButtons();
    void refreshControllers();

private:
    void noteActivity();

    QTimer m_homeTimer;
    QTimer m_controllersTimer;
    qint64 m_lastActivity = 0;
    bool m_homeDown = false;
    bool m_leftDown = false;
    bool m_rightDown = false;
    QString m_layout;
    int m_controllerBattery = -1;
};
