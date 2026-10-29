// Vérifie StreamPainter::tileAt (la souris dans le centre de contrôle) contre le dessin :
// l'anneau de chaque tuile, repéré dans l'image, doit entourer une zone où tileAt la trouve ;
// sliderAt et powerAt de même. Depuis ce dossier :
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

StreamPainter::Frame menu()
{
    StreamPainter::Frame frame;
    frame.veil = 0;
    frame.control.game = QStringLiteral("Minecraft");
    for (const char* key : { "resume", "brightness", "volume", "shot", "stats", "home", "quit", "sleep", "power" }) {
        StreamPainter::Tile tile;
        tile.key = QLatin1String(key);
        tile.label = tile.key;
        tile.value = tile.key == QLatin1String("brightness") || tile.key == QLatin1String("volume") ? 0.5 : -1;
        frame.control.tiles.append(tile);
    }
    return frame;
}

// La zone que l'anneau de focus de la tuile `focus` change dans l'image.
QRect focusBox(StreamPainter::Frame frame, QSize screen, int focus)
{
    QImage a(screen, QImage::Format_ARGB32_Premultiplied), b = a;
    frame.control.focus = focus;
    StreamPainter::paintFrame(frame, a);
    frame.control.focus = -1;
    StreamPainter::paintFrame(frame, b);
    QRect box;
    for (int y = 0; y < screen.height(); y++) {
        for (int x = 0; x < screen.width(); x++) {
            if (a.pixel(x, y) != b.pixel(x, y)) {
                box |= QRect(x, y, 1, 1);
            }
        }
    }
    return box;
}

int check(QSize screen)
{
    const StreamPainter::Frame frame = menu();
    int failures = 0;
    for (int tile = 0; tile < frame.control.tiles.size(); tile++) {
        // (l'anneau et l'agrandissement débordent de la tuile : on vise l'intérieur)
        const QRect box = focusBox(frame, screen, tile);
        const QRect inside = box.adjusted(box.width() / 6, box.height() / 6, -box.width() / 6, -box.height() / 6);
        for (QPoint p : { inside.topLeft(), inside.center(), inside.bottomRight() }) {
            const int got = StreamPainter::tileAt(frame.control, screen, p);
            if (got != tile) {
                std::printf("%dx%d tuile %d, (%d, %d) : tileAt=%d\n", screen.width(), screen.height(), tile, p.x(), p.y(), got);
                failures++;
            }
        }
        if (tile == 2) {   // le volume : en haut 1, en bas 0, au milieu 0,5
            const qreal top = StreamPainter::sliderAt(tile, screen, QPointF(box.center().x(), 0));
            const qreal middle = StreamPainter::sliderAt(tile, screen, box.center());
            const qreal bottom = StreamPainter::sliderAt(tile, screen, QPointF(box.center().x(), screen.height()));
            if (top != 1 || qAbs(middle - 0.5) > 0.03 || bottom != 0) {
                std::printf("%dx%d curseur : haut %.3f, milieu %.3f, bas %.3f\n", screen.width(), screen.height(), top, middle, bottom);
                failures++;
            }
        }
    }
    if (StreamPainter::tileAt(frame.control, screen, QPointF(5, 5)) != -1) {
        std::printf("%dx%d : le coin devrait être hors des tuiles\n", screen.width(), screen.height());
        failures++;
    }
    // La carte d'alimentation : chaque pastille, sous son centre (dessinée pleine si elle a le focus).
    StreamPainter::Power power;
    power.keys = QStringList { "suspend", "reboot", "poweroff" };
    power.labels = power.keys;
    const qreal k = screen.height() / 800.0, width = screen.width() / k;
    for (int i = 0; i < 3; i++) {
        const QPointF disc((width / 2 + (i - 1) * (150 + 22)) * k, (220 + 36 + 17 + 30 + 46) * k);
        if (StreamPainter::powerAt(power, screen, disc) != i) {
            std::printf("%dx%d pastille %d : powerAt=%d\n", screen.width(), screen.height(), i,
                        StreamPainter::powerAt(power, screen, disc));
            failures++;
        }
    }
    if (StreamPainter::powerAt(power, screen, QPointF(5, 5)) != -2) {
        std::printf("%dx%d : le coin devrait être hors de la carte\n", screen.width(), screen.height());
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
    StreamPainter::setIconRoot(QStringLiteral("../../../../app/gui/console/icons/"));
    int failures = 0;
    for (QSize screen : { QSize(1280, 720), QSize(1920, 1080), QSize(1280, 800) }) {
        failures += check(screen);
    }
    std::printf(failures ? "%d écart(s)\n" : "ok\n", failures);
    return failures ? 1 : 0;
}
