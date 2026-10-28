// Motifs de vibration (backend/haptics) : chaque motif de haptics.json se charge, ses pas
// font exactement total_ms, reprennent ses impulsions (début, fin, niveaux), et chaque
// son déclencheur existe dans le pack. Depuis ce dossier :
//
//   g++ -std=c++17 -fPIC -I../../../../app/gui/console/backend tst_haptics.cpp \
//       ../../../../app/gui/console/backend/haptics.cpp \
//       $(pkg-config --cflags --libs Qt6Core) -o /tmp/tst_haptics
//   /tmp/tst_haptics            # « ok », sinon ce qui cloche

#include "haptics.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStringList>

#include <cmath>
#include <cstdio>

namespace {

int failures = 0;

void check(bool ok, const QString& what)
{
    if (!ok) {
        std::printf("ÉCHEC : %s\n", qPrintable(what));
        failures++;
    }
}

QByteArray read(const char* path)
{
    QFile file(QString::fromUtf8(path));
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

// Niveau d'un moteur à l'instant t d'après les pas.
double levelAt(const Haptics::Pattern& p, double t, bool low)
{
    int start = 0;
    for (const Haptics::Step& s : p.steps) {
        if (t >= start && t < start + s.ms) {
            return low ? s.low : s.high;
        }
        start += s.ms;
    }
    return 0;
}

}

int main()
{
    const QByteArray json = read("../motion/haptics.json");
    // Le fichier embarqué est une copie du pack : il ne doit pas en diverger.
    check(json == read("../../../../app/gui/console/haptics.json"), "app/gui/console/haptics.json diffère du pack");

    QStringList sounds;
    for (const QJsonValue& v : QJsonDocument::fromJson(read("../sounds/manifest.json")).object().value("sounds").toArray()) {
        sounds << v.toObject().value("id").toString();
    }
    sounds << "nav_move";   // tourne sur nav_move_1/2/3

    const QVector<Haptics::Pattern> patterns = Haptics::parse(json);
    const QJsonArray raw = QJsonDocument::fromJson(json).object().value("patterns").toArray();
    check(patterns.size() == 14 && patterns.size() == raw.size(), QString("%1 motifs au lieu de 14").arg(patterns.size()));

    for (int i = 0; i < patterns.size(); i++) {
        const Haptics::Pattern& p = patterns.at(i);
        int total = 0;
        for (const Haptics::Step& s : p.steps) {
            total += s.ms;
            check(s.low >= 0 && s.low <= 1 && s.high >= 0 && s.high <= 1, p.id + " : niveau hors de 0..1");
        }
        check(!p.steps.isEmpty() && total == p.totalMs, QString("%1 : %2 ms au lieu de %3").arg(p.id).arg(total).arg(p.totalMs));
        check(p.sound == "—" || sounds.contains(p.sound), p.id + " : son inconnu " + p.sound);

        // Chaque impulsion se retrouve dans les pas : au milieu, à son niveau (rampe comprise).
        int end = 0;
        for (const QJsonValue& v : raw.at(i).toObject().value("pulses").toArray()) {
            const QJsonObject pulse = v.toObject();
            const double start = pulse.value("start").toDouble(), duration = pulse.value("duration").toDouble();
            const double mid = start + duration / 2;
            const double expected = pulse.value("from").toDouble()
                    + (pulse.value("to").toDouble() - pulse.value("from").toDouble()) / 2;
            const double got = levelAt(p, mid, pulse.value("motor").toString() == "L");
            // Un pas de 10 ms échantillonne la rampe : à une demi-pente de pas près.
            const double tolerance = std::abs(pulse.value("to").toDouble() - pulse.value("from").toDouble())
                    * 10 / duration + 1e-9;
            check(got + tolerance >= expected, QString("%1 : %2 au lieu de %3 à %4 ms").arg(p.id).arg(got).arg(expected).arg(mid));
            end = std::max(end, int(start + duration));
        }
        check(end == p.totalMs, QString("%1 : impulsions jusqu'à %2 ms, total_ms %3").arg(p.id).arg(end).arg(p.totalMs));
    }

    if (failures == 0) {
        std::printf("ok\n");
    }
    return failures == 0 ? 0 : 1;
}
