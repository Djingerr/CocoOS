#include "ambientcolor.h"

#include <QImageReader>
#include <QPointer>
#include <QThreadPool>

namespace {

const int THUMB_SIZE = 48;          // côté max de la miniature analysée
const int HUE_BINS = 24;
const double MIN_COLORFULNESS = 0.03;   // poids moyen sous lequel l'image est « grise »
const float MIN_SATURATION = 0.55f;
const float MIN_VALUE = 0.88f;

}

AmbientColor::AmbientColor(QObject* parent)
    : QObject(parent)
{
}

QImage AmbientColor::thumbnail(const QString& path)
{
    QImageReader reader(path);
    QSize size = reader.size();
    if (size.isValid()) {
        // (le JPEG se décode directement réduit : rapide même pour une image 4K)
        reader.setScaledSize(size.scaled(THUMB_SIZE, THUMB_SIZE, Qt::KeepAspectRatio));
    }
    return reader.read();
}

QColor AmbientColor::dominant(const QImage& image)
{
    if (image.isNull()) {
        return QColor();
    }
    double weight[HUE_BINS] = {}, red[HUE_BINS] = {}, green[HUE_BINS] = {}, blue[HUE_BINS] = {};
    double total = 0;
    int pixels = 0;
    for (int y = 0; y < image.height(); y++) {
        for (int x = 0; x < image.width(); x++) {
            QColor c = image.pixelColor(x, y);
            float h, s, v;
            c.getHsvF(&h, &s, &v);
            pixels++;
            if (h < 0) {
                continue;   // gris pur
            }
            double w = double(s) * s * v;
            int bin = qMin(HUE_BINS - 1, int(h * HUE_BINS));
            weight[bin] += w;
            red[bin] += c.redF() * w;
            green[bin] += c.greenF() * w;
            blue[bin] += c.blueF() * w;
            total += w;
        }
    }
    if (pixels == 0 || total / pixels < MIN_COLORFULNESS) {
        return QColor();
    }
    int best = 0;
    for (int i = 1; i < HUE_BINS; i++) {
        if (weight[i] > weight[best]) {
            best = i;
        }
    }
    QColor average = QColor::fromRgbF(red[best] / weight[best], green[best] / weight[best], blue[best] / weight[best]);
    float h, s, v;
    average.getHsvF(&h, &s, &v);
    return QColor::fromHsvF(h, qMax(s, MIN_SATURATION), qMax(v, MIN_VALUE));
}

QColor AmbientColor::colorFor(const QUrl& image)
{
    const QString key = image.toString();
    if (key.isEmpty()) {
        return QColor();
    }
    auto cached = m_cache.constFind(key);
    if (cached != m_cache.constEnd()) {
        return cached.value();
    }
    if (!m_pending.contains(key)) {
        m_pending.insert(key);
        const QString path = image.isLocalFile() ? image.toLocalFile()
                           : image.scheme() == QLatin1String("qrc") ? QLatin1Char(':') + image.path()
                           : QString();
        QPointer<AmbientColor> self(this);
        QThreadPool::globalInstance()->start([self, key, path] {
            QColor color = path.isEmpty() ? QColor() : dominant(thumbnail(path));
            if (self) {
                QMetaObject::invokeMethod(self, [self, key, color] {
                    self->m_cache.insert(key, color);
                    self->m_pending.remove(key);
                    self->m_revision++;
                    emit self->ready();
                }, Qt::QueuedConnection);
            }
        });
    }
    return QColor();
}
