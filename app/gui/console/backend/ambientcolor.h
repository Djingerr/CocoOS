#pragma once

// AmbientColor — la couleur « vive » qui domine une image (le fond du jeu), pour
// teinter l'interface autour. Calculée hors du fil principal sur une miniature,
// puis gardée en cache. Compilé dans le build `embedded` seulement, comme le reste
// de app/gui/console/ (singleton QML `AmbientColor`).

#include <QColor>
#include <QHash>
#include <QImage>
#include <QObject>
#include <QSet>
#include <QUrl>

class AmbientColor : public QObject
{
    Q_OBJECT

    // Change à chaque couleur calculée : à lire dans une liaison pour la réévaluer.
    Q_PROPERTY(int revision READ revision NOTIFY ready)

public:
    explicit AmbientColor(QObject* parent = nullptr);

    int revision() const { return m_revision; }

    // Couleur de `image` si elle est connue ; sinon couleur invalide, et le calcul
    // part (ready() suivra). Invalide aussi pour une image sans couleur franche.
    Q_INVOKABLE QColor colorFor(const QUrl& image);

    // La couleur dominante d'une image : la teinte qui pèse le plus, pondérée par
    // la saturation (un gris majoritaire ne compte pas), rendue assez vive pour un
    // trait fin sur fond sombre. Invalide si l'image est quasi grise.
    static QColor dominant(const QImage& image);
    static QImage thumbnail(const QString& path);

signals:
    void ready();

private:
    QHash<QString, QColor> m_cache;
    QSet<QString> m_pending;
    int m_revision = 0;
};
