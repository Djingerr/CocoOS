// Vérifie StreamPainter::rowAt (la souris dans le menu en jeu) contre le dessin : le
// surlignage de chaque ligne, repéré dans l'image, doit tomber sur cette ligne. Depuis
// ce dossier :
//
//   g++ -std=c++17 -fPIC -I../../../../app/gui/console/backend streammenu-rows.cpp \
//       ../../../../app/gui/console/backend/streampainter.cpp \
//       $(pkg-config --cflags --libs Qt6Gui) -o /tmp/streammenu-rows
//   QT_QPA_PLATFORM=offscreen /tmp/streammenu-rows        # « ok », sinon l'écart

#include "streampainter.h"

#include <QDir>
#include <QFontDatabase>
#include <QGuiApplication>

#include <cstdio>

namespace {

// Lignes de pixels où le surlignage change l'image, dans la colonne x.
QPair<int, int> highlightSpan(StreamPainter::Frame frame, QSize screen, int x, qreal focusY)
{
    QImage a(screen, QImage::Format_ARGB32_Premultiplied), b = a;
    frame.focusY = focusY;
    StreamPainter::paintFrame(frame, a);
    frame.focusY = 1000;    // hors de l'écran (négatif : la ligne en focus)
    StreamPainter::paintFrame(frame, b);
    int top = -1, bottom = -1;
    for (int y = 0; y < screen.height(); y++) {
        if (a.pixel(x, y) != b.pixel(x, y)) {
            if (top < 0) top = y;
            bottom = y;
        }
    }
    return { top, bottom };
}

int check(const QStringList& labels, const QString& message, QSize screen)
{
    StreamPainter::Frame frame;
    frame.veil = 0;
    frame.page.title = QStringLiteral("Elden Ring");
    frame.page.message = message;
    frame.page.labels = labels;
    frame.page.backLabel = QStringLiteral("Fermer");
    // Juste à droite du bord gauche du surlignage (avant le texte des lignes).
    const qreal scale = screen.height() / 800.0;
    const int x = qRound(screen.width() - (472 - 44 + 16 - 6) * scale);
    int failures = 0;
    for (int row = 0; row < labels.size(); row++) {
        const QPair<int, int> span = highlightSpan(frame, screen, x, row);
        const int inset = qCeil(3 * scale);    // bords arrondis, anticrénelage
        for (int y : { span.first + inset, (span.first + span.second) / 2, span.second - inset }) {
            const int got = StreamPainter::rowAt(frame.page, screen, QPointF(x, y));
            if (got != row) {
                std::printf("%dx%d ligne %d, y=%d : rowAt=%d\n", screen.width(), screen.height(), row, y, got);
                failures++;
            }
        }
    }
    if (StreamPainter::rowAt(frame.page, screen, QPointF(10, screen.height() / 2)) != -2) {
        std::printf("%dx%d : le bord gauche devrait être hors du panneau\n", screen.width(), screen.height());
        failures++;
    }
    return failures;
}

}

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    const QDir fonts(QStringLiteral("../../../../app/gui/console/fonts"));
    for (const QString& file : fonts.entryList({ QStringLiteral("Sora-*.ttf") })) {
        QFontDatabase::addApplicationFont(fonts.filePath(file));
    }
    const QStringList menu { "Reprendre", "Statistiques du flux", "Retour à l'accueil", "Quitter Elden Ring",
                             "Mettre en veille", "Redémarrer", "Éteindre" };
    const QStringList confirm { "Annuler", "Quitter" };
    int failures = 0;
    for (QSize screen : { QSize(1280, 720), QSize(1920, 1080), QSize(1280, 800) }) {
        failures += check(menu, QString(), screen);
        failures += check(confirm, QStringLiteral("Toute progression non sauvegardée sera perdue."), screen);
    }
    std::printf(failures ? "%d écart(s)\n" : "ok\n", failures);
    return failures ? 1 : 0;
}
