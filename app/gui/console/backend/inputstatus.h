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
#include <QVariantList>

class InputStatus : public QObject
{
    Q_OBJECT

    // Famille de la première manette : "xbox", "playstation" ou "nintendo" ;
    // vide sans manette (ou famille inconnue).
    Q_PROPERTY(QString layout READ layout NOTIFY controllersChanged)
    // Batterie de la première manette sans fil : 0 (vide) à 3 (pleine) ; -1 si
    // filaire, sans manette ou niveau inconnu.
    Q_PROPERTY(int controllerBattery READ controllerBattery NOTIFY controllersChanged)
    // Manettes branchées (l'île de notification de la barre haute en suit les arrivées).
    Q_PROPERTY(int controllerCount READ controllerCount NOTIFY controllersChanged)
    // Les manettes branchées, dans l'ordre de SDL : { name, family, battery (0 à 3, -1) }.
    Q_PROPERTY(QVariantList controllers READ controllers NOTIFY controllersChanged)

public:
    explicit InputStatus(QObject* parent = nullptr);

    QString layout() const { return m_layout; }
    int controllerBattery() const { return m_controllerBattery; }
    int controllerCount() const { return m_controllerCount; }
    QVariantList controllers() const { return m_controllers; }

    // Menu en jeu (StreamMenu) : le nom du jeu, les actions d'alimentation et les
    // glyphes à montrer, avant chaque flux ; au retour, l'action choisie ("home",
    // "quit", "suspend", "reboot", "poweroff"), vide si le flux s'est fini autrement.
    Q_INVOKABLE void prepareStreamMenu(const QString& game, const QStringList& powerActions,
                                       const QString& buttonLayout, QObject* system = nullptr);
    Q_INVOKABLE QString takeStreamExit();
    // Un son de l'interface vient d'être joué (Sounds.played) : la manette vibre selon son
    // motif (StreamMenu::rumble), à l'intensité `level` (0 : coupées, 0,6 : légères, 1 : fortes).
    Q_INVOKABLE void feedback(const QString& sound, double level);
    // Start (≡) enfoncé sur une manette, à l'instant : la navigation upstream envoie la même
    // touche Qt (Key_Hangup) pour Y et Start, le clavier à l'écran les distingue ainsi.
    Q_INVOKABLE bool startHeld() const;

    // Correspondances SDL → UI (statiques pour être vérifiables seules).
    static QString layoutForType(int sdlControllerType);
    static int batteryForPowerLevel(int sdlPowerLevel);

signals:
    void activity();            // l'utilisateur a agi (au plus une fois toutes les 500 ms)
    void homePressed();         // bouton Home de la manette
    void bumperPressed(int direction);   // L1 (-1) ou R1 (+1)
    void triggerPressed(int direction);  // L2 (-1) ou R2 (+1), enfoncée au-delà de la moitié
    void stickPressed(int side);         // clic du stick gauche (-1, L3) ou droit (+1, R3)
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
    bool m_leftTriggerDown = false;
    bool m_leftStickDown = false;
    bool m_rightStickDown = false;
    bool m_rightTriggerDown = false;
    QString m_layout;
    int m_controllerBattery = -1;
    int m_controllerCount = 0;
    QVariantList m_controllers;
};
