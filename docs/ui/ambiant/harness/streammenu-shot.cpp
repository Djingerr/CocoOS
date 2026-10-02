// Dessine le menu en jeu (app/gui/console/backend/streampainter.cpp) hors de
// l'application, pour le comparer au panneau QML qu'il imite. Depuis ce dossier :
//
//   g++ -std=c++17 -fPIC -I../../../../app/gui/console/backend streammenu-shot.cpp \
//       ../../../../app/gui/console/backend/streampainter.cpp \
//       $(pkg-config --cflags --libs Qt6Gui) -o /tmp/streammenu-shot
//   QT_QPA_PLATFORM=offscreen /tmp/streammenu-shot /tmp/m.png page=menu size=1280x720 layout=xbox
//
// page : menu | confirm | stats | dialog (le dialog de PagesDemo, à comparer avec
// ./shot.sh /tmp/q.png view=PagesDemo page=dialog size=1280x720). stats=1 ajoute
// les statistiques au menu ; latency=N (ms) en change le point ; backdrop=art/x.jpg
// pose cette image en fond flouté, comme une image du jeu. Une étape d'animation :
// reveal=, veil=, blur=, focusY=, pageMix= (avec page=confirm : la liste s'efface),
// swap= (avec stats=1 : « Masquées » sort, « Affichées » entre), de 0 à 1.

#include "streampainter.h"

#include <QDir>
#include <QFontDatabase>
#include <QGuiApplication>

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    const QStringList args = app.arguments();
    if (args.size() < 2) {
        qWarning("usage: streammenu-shot out.png [page=…] [size=WxH] [layout=…] [focus=N]");
        return 1;
    }
    QMap<QString, QString> opt;
    for (const QString& arg : args.mid(2)) {
        opt[arg.section('=', 0, 0)] = arg.section('=', 1);
    }

    const QDir fonts(QStringLiteral("../../../../app/gui/console/fonts"));
    for (const QString& file : fonts.entryList({ QStringLiteral("Sora-*.ttf") })) {
        QFontDatabase::addApplicationFont(fonts.filePath(file));
    }

    const QStringList size = opt.value(QStringLiteral("size"), QStringLiteral("1280x720")).split('x');
    const QString page = opt.value(QStringLiteral("page"), QStringLiteral("menu"));

    StreamPainter::Frame frame;
    StreamPainter::Page& menu = frame.page;
    frame.layout = opt.value(QStringLiteral("layout"), QStringLiteral("xbox"));
    menu.focus = opt.value(QStringLiteral("focus"), QStringLiteral("0")).toInt();
    if (page == QLatin1String("dialog")) {
        menu.title = QStringLiteral("Un jeu est déjà en cours");
        menu.message = QStringLiteral("Hades II est en cours sur votre PC. Le fermer et lancer Elden Ring ? "
                                      "Toute progression non sauvegardée sera perdue.");
        menu.labels = QStringList { QStringLiteral("Annuler"), QStringLiteral("Fermer et jouer") };
        menu.backLabel = QStringLiteral("Annuler");
    }
    else if (page == QLatin1String("confirm")) {
        menu.title = QStringLiteral("Quitter Elden Ring ?");
        menu.message = QStringLiteral("Toute progression non sauvegardée sera perdue.");
        menu.labels = QStringList { QStringLiteral("Annuler"), QStringLiteral("Quitter") };
        menu.backLabel = QStringLiteral("Annuler");
    }
    else {
        menu.title = QStringLiteral("Elden Ring");
        menu.labels = QStringList { QStringLiteral("Reprendre"), QStringLiteral("Statistiques du flux"),
                                    QStringLiteral("Retour à l'accueil"), QStringLiteral("Quitter Elden Ring"),
                                    QStringLiteral("Mettre en veille"), QStringLiteral("Redémarrer"),
                                    QStringLiteral("Éteindre") };
        menu.values = QStringList { QString(), QStringLiteral("Masquées") };
        menu.backLabel = QStringLiteral("Fermer");
    }

    const int latency = opt.value(QStringLiteral("latency"), QStringLiteral("12")).toInt();
    StreamPainter::Stats stats;
    stats.lines = QStringList { QStringLiteral("1920 × 1080 · 59,9 i/s · HEVC · 28,4 Mb/s"),
                                QStringLiteral("Latence réseau %1 ms (± 2 ms)").arg(latency),
                                QStringLiteral("Images perdues : 0,1 % réseau · 0,0 % gigue"),
                                QStringLiteral("Décodage 1,8 ms · Affichage 4,2 ms · PC 3,1 ms") };
    stats.dotLine = 1;
    stats.dot = StreamPainter::networkColor(latency, 2);
    if (opt.value(QStringLiteral("stats")) == QLatin1String("1")) {
        frame.stats = stats;
        menu.values = QStringList { QString(), QStringLiteral("Affichées") };
        frame.swapRow = 1;
        frame.swapFrom = QStringLiteral("Masquées");
    }
    auto number = [&](const char* key, qreal fallback) {
        return opt.contains(QLatin1String(key)) ? opt.value(QLatin1String(key)).toDouble() : fallback;
    };
    frame.reveal = number("reveal", 1);
    frame.veil = number("veil", 1);
    frame.blurMix = number("blur", 1);
    frame.focusY = number("focusY", -1);
    frame.swapProgress = number("swap", 1);
    frame.pageMix = number("pageMix", 1);
    if (frame.pageMix < 1) {
        frame.previous.title = QStringLiteral("Elden Ring");
        frame.previous.labels = QStringList { QStringLiteral("Reprendre"), QStringLiteral("Statistiques du flux"),
                                              QStringLiteral("Retour à l'accueil"), QStringLiteral("Quitter Elden Ring") };
        frame.previous.values = QStringList { QString(), QStringLiteral("Masquées") };
        frame.previous.focus = 3;
        frame.previous.backLabel = QStringLiteral("Fermer");
    }

    const QSize screen(size.value(0).toInt(), size.value(1).toInt());
    const QImage game(opt.value(QStringLiteral("backdrop")));
    if (!game.isNull()) {   // réduite au huitième, comme StreamMenu::snapshot
        frame.backdrop = StreamPainter::blurred(game.scaled(game.size() / 8, Qt::IgnoreAspectRatio,
                                                            Qt::SmoothTransformation), screen);
    }
    const QImage image = page == QLatin1String("stats") ? StreamPainter::paintStats(stats, number("opacity", 1), screen)
                                                         : StreamPainter::paintFrame(frame, screen);
    return image.save(args[1]) ? 0 : 1;
}
