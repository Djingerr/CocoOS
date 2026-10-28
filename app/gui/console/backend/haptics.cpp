#include "haptics.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <algorithm>

namespace Haptics {

namespace {

const int STEP_MS = 10;

}

QVector<Pattern> parse(const QByteArray& json)
{
    QVector<Pattern> patterns;
    const QJsonArray list = QJsonDocument::fromJson(json).object().value(QStringLiteral("patterns")).toArray();
    for (const QJsonValue& v : list) {
        const QJsonObject o = v.toObject();
        Pattern p;
        p.id = o.value(QStringLiteral("id")).toString();
        p.sound = o.value(QStringLiteral("sound")).toString();
        p.totalMs = o.value(QStringLiteral("total_ms")).toInt();
        const QJsonArray pulses = o.value(QStringLiteral("pulses")).toArray();
        // Chaque pas prend le niveau de chaque moteur au milieu du pas (le plus fort si
        // deux impulsions se chevauchent).
        for (int t = 0; t < p.totalMs; t += STEP_MS) {
            const int ms = std::min(STEP_MS, p.totalMs - t);
            const double mid = t + ms / 2.0;
            Step step { ms, 0, 0 };
            for (const QJsonValue& pv : pulses) {
                const QJsonObject pulse = pv.toObject();
                const double start = pulse.value(QStringLiteral("start")).toDouble();
                const double duration = pulse.value(QStringLiteral("duration")).toDouble();
                if (mid < start || mid >= start + duration) {
                    continue;
                }
                const double from = pulse.value(QStringLiteral("from")).toDouble();
                const double to = pulse.value(QStringLiteral("to")).toDouble();
                const double level = from + (to - from) * (mid - start) / duration;
                double& motor = pulse.value(QStringLiteral("motor")).toString() == QLatin1String("L") ? step.low : step.high;
                motor = std::max(motor, level);
            }
            if (!p.steps.isEmpty() && p.steps.last().low == step.low && p.steps.last().high == step.high) {
                p.steps.last().ms += ms;
            }
            else {
                p.steps.append(step);
            }
        }
        patterns.append(p);
    }
    return patterns;
}

const Pattern* forSound(const QString& sound)
{
    static const QVector<Pattern> patterns = [] {
        QFile file(QStringLiteral(":/gui/console/haptics.json"));
        return file.open(QIODevice::ReadOnly) ? parse(file.readAll()) : QVector<Pattern>();
    }();
    // Le motif « Catégorie (LB / RB) » vaut pour les deux sens ; le fichier ne nomme que category_next.
    const QString name = sound == QLatin1String("category_prev") ? QStringLiteral("category_next") : sound;
    for (const Pattern& p : patterns) {
        if (p.sound == name) {
            return &p;
        }
    }
    return nullptr;
}

}
