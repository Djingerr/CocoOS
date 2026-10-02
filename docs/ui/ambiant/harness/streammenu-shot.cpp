// Dessine le menu en jeu (app/gui/console/backend/streampainter.cpp) hors de
// l'application, pour le comparer au panneau QML qu'il imite. Depuis ce dossier :
//
//   g++ -std=c++17 -fPIC -I../../../../app/gui/console/backend streammenu-shot.cpp \
//       ../../../../app/gui/console/backend/streampainter.cpp \
//       $(pkg-config --cflags --libs Qt6Gui) -o /tmp/streammenu-shot
//   QT_QPA_PLATFORM=offscreen /tmp/streammenu-shot /tmp/m.png page=menu size=1280x720 layout=xbox
//
// page : menu | confirm | dialog (le dialog de PagesDemo, à comparer avec
// ./shot.sh /tmp/q.png view=PagesDemo page=dialog size=1280x720).

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

    StreamPainter::Menu menu;
    menu.layout = opt.value(QStringLiteral("layout"), QStringLiteral("xbox"));
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

    const QImage image = StreamPainter::paintMenu(menu, QSize(size.value(0).toInt(), size.value(1).toInt()));
    return image.save(args[1]) ? 0 : 1;
}
