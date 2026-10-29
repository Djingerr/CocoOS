// Dessine le menu en jeu (app/gui/console/backend/streampainter.cpp) hors de l'application,
// pour le comparer aux planches CocoOS (JeuControle, MotionMenuJeu, StatsOverlay…). Depuis ce
// dossier :
//
//   g++ -std=c++17 -fPIC -I../../../../app/gui/console/backend streammenu-shot.cpp \
//       ../../../../app/gui/console/backend/streampainter.cpp \
//       $(pkg-config --cflags --libs Qt6Gui) -o /tmp/streammenu-shot
//   QT_QPA_PLATFORM=offscreen /tmp/streammenu-shot /tmp/m.png size=1280x800 backdrop=art/minecraft.jpg
//
// page : menu (le centre de contrôle) | power (la carte d'alimentation par-dessus) | stats (hors
// du menu : les statistiques, compact=1 en pastille) | overlay (bannière, carte de la manette,
// capture : voir plus bas).
// focus=N : la tuile en focus (0 Reprendre, 1 Luminosité, 2 Volume, 3 Capture, 4 Statistiques,
// 5 Accueil, 6 Quitter, 7 Veille, 8 Alimentation) ; volume=, brightness= (en %) ; cover=… la
// jaquette de l'en-tête ; layout=xbox|playstation|nintendo. Une étape d'animation : open=ms
// (depuis l'ouverture), closing=, veil=, blur=, powerMix=, swap= (avec stats=1 : « Masquées »
// sort, « Détaillées » entre), hold= et holdDone= (focus=6 : l'appui maintenu sur Quitter).

#include "streampainter.h"

#include <QDir>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QPainter>

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
    StreamPainter::setIconRoot(QStringLiteral("../../../../app/gui/console/icons/"));

    const QStringList size = opt.value(QStringLiteral("size"), QStringLiteral("1280x800")).split('x');
    const QString page = opt.value(QStringLiteral("page"), QStringLiteral("menu"));
    auto number = [&](const char* key, qreal fallback) {
        return opt.contains(QLatin1String(key)) ? opt.value(QLatin1String(key)).toDouble() : fallback;
    };

    StreamPainter::Frame frame;
    frame.layout = opt.value(QStringLiteral("layout"), QStringLiteral("xbox"));
    StreamPainter::Control& control = frame.control;
    control.game = QStringLiteral("Minecraft");
    control.status = QStringLiteral("En pause · 1 h 24 min");
    control.cover = QImage(opt.value(QStringLiteral("cover")));
    control.host = QStringLiteral("PC-Salon");
    control.latency = QStringLiteral("4 ms");
    control.time = opt.value(QStringLiteral("time"), QStringLiteral("21:42"));
    control.battery = int(number("battery", 82));
    control.focus = int(number("focus", 0));
    const int brightness = int(number("brightness", 100)), volume = int(number("volume", 30));
    const bool statsShown = opt.value(QStringLiteral("stats")) == QLatin1String("1");
    control.tiles = {
        { QStringLiteral("resume"), QStringLiteral("Reprendre"), QStringLiteral("Retour au jeu") },
        { QStringLiteral("brightness"), QStringLiteral("Luminosité"), QStringLiteral("%1 %").arg(brightness), brightness / 100.0 },
        { QStringLiteral("volume"), QStringLiteral("Volume"), QStringLiteral("%1 %").arg(volume), volume / 100.0 },
        { QStringLiteral("shot"), QStringLiteral("Capture"), QStringLiteral("Sur la console") },
        { QStringLiteral("stats"), QStringLiteral("Statistiques"), statsShown ? QStringLiteral("Détaillées") : QStringLiteral("Masquées") },
        { QStringLiteral("home"), QStringLiteral("Accueil"), QString() },
        { QStringLiteral("quit"), QStringLiteral("Quitter le jeu"), QString() },
        { QStringLiteral("sleep"), QStringLiteral("Veille"), QString() },
        { QStringLiteral("power"), QStringLiteral("Alimentation"), QStringLiteral("Redémarrer · Éteindre") },
    };
    control.activateLabel = control.focus == 6 ? QStringLiteral("Maintenir") : QStringLiteral("Activer");
    if (statsShown) {
        frame.swapTile = 4;
        frame.swapFrom = QStringLiteral("Masquées");
    }
    frame.openMs = number("open", 1e9);
    frame.closing = number("closing", 0);
    frame.veil = number("veil", 1);
    frame.blurMix = number("blur", 1);
    frame.swapProgress = number("swap", 1);
    frame.hold = number("hold", 0);
    frame.holdDone = number("holdDone", 0);
    frame.doneLabel = QStringLiteral("Fermeture du jeu");

    StreamPainter::Power& power = frame.power;
    power.header = QStringLiteral("Batterie 82 % · environ 3 h 10");
    power.keys = QStringList { QStringLiteral("suspend"), QStringLiteral("reboot"), QStringLiteral("poweroff") };
    power.labels = QStringList { QStringLiteral("Mise en veille"), QStringLiteral("Redémarrer"), QStringLiteral("Éteindre") };
    power.focus = int(number("powerFocus", 1));
    power.note = QStringLiteral("Le stream en cours sera fermé proprement avant l’arrêt.");
    frame.powerMix = page == QLatin1String("power") ? number("powerMix", 1) : 0;

    // Les statistiques de la maquette (StatsOverlay) ; compact=1 : la pastille.
    StreamPainter::Stats stats;
    stats.mode = opt.value(QStringLiteral("compact")) == QLatin1String("1") ? StreamPainter::Stats::Compact
                                                                           : StreamPainter::Stats::Detailed;
    stats.host = QStringLiteral("PC-Salon");
    stats.total = int(number("latency", 11));
    stats.quality = QStringLiteral("EXCELLENT");
    stats.history = { 8, 9, 7, 10, 9, 11, 8, 10, 9, 22, 12, 9, 10, 8, 9, 10, 9, 8, 10, 9, 9 };
    stats.labels = QStringList { "Réseau", "Encodage sur le PC", "Décodage", "", "Image", "Débit", "Images perdues", "Batterie" };
    stats.values = QStringList { "4 ms", "3,8 ms", "3,1 ms", "", "720p · 60 i/s · HEVC", "18,4 Mb/s", "0,1 %", "82 % · 3 h 10" };
    stats.compact = QStringList { "11 ms", "60 i/s", "18 Mb/s", "82 %" };

    const QSize screen(size.value(0).toInt(), size.value(1).toInt());
    const QImage game(opt.value(QStringLiteral("backdrop")));
    if (!game.isNull()) {   // réduite au huitième, comme StreamMenu::snapshot
        frame.backdrop = StreamPainter::blurred(game.scaled(game.size() / 8, Qt::IgnoreAspectRatio,
                                                            Qt::SmoothTransformation), screen);
    }
    QImage image(screen, QImage::Format_ARGB32_Premultiplied);
    if (page == QLatin1String("stats") || page == QLatin1String("overlay")) {
        // page=overlay : par-dessus le jeu. banner=battery|network|pad (in=, out=) ; pause=0..1
        // (back=0..1) ; shot=1 (flash=, fly=, label=, out=) ; game=image du jeu sous tout ça.
        StreamPainter::Overlay overlay;
        overlay.stats = stats;
        if (page == QLatin1String("overlay") && opt.value(QStringLiteral("stats")) != QLatin1String("1")) {
            overlay.stats.mode = StreamPainter::Stats::Hidden;
        }
        overlay.statsOpacity = number("opacity", 1);
        const QString banner = opt.value(QStringLiteral("banner"));
        if (banner == QLatin1String("battery")) {
            overlay.banner = { StreamPainter::Banner::Battery, false, true, QStringLiteral("Batterie très faible · 5 %"),
                               QStringLiteral("Branchez la console.") };
        }
        else if (banner == QLatin1String("network")) {
            overlay.banner = { StreamPainter::Banner::Network, false, false, QStringLiteral("Réseau instable"),
                               QStringLiteral("Latence 64 ms · gigue 18 ms") };
        }
        else if (banner == QLatin1String("pad")) {
            overlay.banner = { StreamPainter::Banner::Pad, true, false, QStringLiteral("Manette presque vide"),
                               QStringLiteral("Pensez à la recharger") };
        }
        overlay.bannerIn = number("in", 1);
        overlay.bannerOut = number("out", 0);
        overlay.pause = { QStringLiteral("Manette déconnectée"), QStringLiteral("Reconnectez la manette pour reprendre."),
                          QStringLiteral("Manette reconnectée"), QStringLiteral("Reprise du jeu…"),
                          QStringLiteral("Recherche de la manette…") };
        overlay.pauseShow = number("pause", 0);
        overlay.pauseBack = number("back", 0);
        overlay.spin = 0.3;
        const QImage still(opt.value(QStringLiteral("game")));
        if (overlay.pauseShow > 0 && !still.isNull()) {
            overlay.backdrop = StreamPainter::blurred(still.scaled(still.size() / 8, Qt::IgnoreAspectRatio, Qt::SmoothTransformation), screen);
            overlay.backdropShow = 1;
        }
        if (opt.value(QStringLiteral("shot")) == QLatin1String("1") && !still.isNull()) {
            overlay.shot.image = still.scaledToWidth(640, Qt::SmoothTransformation);
            overlay.shot.title = QStringLiteral("Capture enregistrée");
            overlay.shot.sub = QStringLiteral("sur la console");
            overlay.flash = number("flash", 0);
            overlay.shotFly = number("fly", 1);
            overlay.shotLabel = number("label", 1);
            overlay.shotOut = number("shotOut", 0);
        }
        const QImage layer = StreamPainter::paintOverlay(overlay, screen);
        // Posé sur l'image du jeu (game=…), comme Moonlight le compose.
        image = still.isNull() ? QImage(screen, QImage::Format_ARGB32_Premultiplied)
                               : still.scaled(screen, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                                      .convertToFormat(QImage::Format_ARGB32_Premultiplied);
        if (still.isNull()) {
            image.fill(Qt::transparent);
        }
        QPainter p(&image);
        p.drawImage(0, 0, layer);
    }
    else {
        if (statsShown) {
            frame.stats = stats;
        }
        StreamPainter::paintFrame(frame, image);
    }
    return image.save(args[1]) ? 0 : 1;
}
