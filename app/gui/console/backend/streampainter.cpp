#include "streampainter.h"

#include <QCoreApplication>
#include <QEasingCurve>
#include <QFontMetricsF>
#include <QHash>
#include <QPainter>
#include <QTextLayout>
#include <QVector>

#include <cstring>
#include <QtMath>

namespace {

// Jetons de Theme.qml, en pixels du canevas de 800 de haut.
const qreal CANVAS_HEIGHT = 800;
const QColor INK("#F2F0EC");
const QColor INK2("#A19D97");
const QColor INK3("#7C7973");
const QColor OK("#69D08E");
const QColor FAIR("#E8C547");
const QColor POOR("#E5574F");
const QColor SHEET_FILL(18, 18, 20, qRound(0.95 * 255));
const QColor SHEET_EDGE(255, 255, 255, qRound(0.08 * 255));
const QColor FOCUS_FILL(255, 255, 255, qRound(0.10 * 255));
const qreal SHEET_DIM = 0.62;
const qreal BACKDROP_DIM = 0.45;         // moins que SHEET_DIM : le jeu flouté reste visible
const int BACKDROP_BLUR = 3;             // rayon du flou en boîte, en pixels de l'image réduite
const qreal SHEET_WIDTH = 472;
const qreal SHEET_PAD_TOP = 44;
const qreal SHEET_PAD_SIDE = 44;
const qreal SHEET_PAD_BOTTOM = 34;
const qreal SHEET_TITLE_SIZE = 26;
const qreal SHEET_TITLE_SPACING = -0.26;
const qreal SHEET_ROW_HEIGHT = 60;
const qreal SHEET_LABEL_SIZE = 17;
const qreal SHEET_VALUE_SIZE = 14;
const qreal SHEET_FOCUS_RADIUS = 14;
const qreal SHEET_FOCUS_OUTSET = 16;
const qreal SHEET_HINT_RIGHT = 24;
const qreal SHEET_HIDDEN_SHIFT = 0.04;   // fermé, il attend juste au-delà du bord droit
const qreal SHEET_VALUE_BOX = 136;       // Theme.sheetValueBox.width
const qreal SHEET_VALUE_TRAVEL = 36;
const qreal SWAP_ENTER_FADE = 0.7;       // Theme.swapEnterFade, swapExitTravel…
const qreal SWAP_EXIT_TRAVEL = 0.8;
const qreal SWAP_EXIT_DURATION = 0.8;
const qreal SWAP_EXIT_FADE = 0.45;
const qreal DIALOG_MESSAGE_TOP = 14;
const qreal DIALOG_MESSAGE_SIZE = 15;
const qreal DIALOG_MESSAGE_LINE_HEIGHT = 1.45;
const qreal DIALOG_CHOICES_TOP = 30;
const qreal LEGEND_SIZE = 14;
const qreal LEGEND_GAP = 24;
const qreal LEGEND_GLYPH_GAP = 10;
const qreal GLYPH_SIZE = 22;
const qreal GLYPH_BORDER = 1.5;
const qreal GLYPH_FONT_SIZE = 10.5;
const qreal GLYPH_SYMBOL_SCALE = 0.42;
const qreal HOST_DOT_SIZE = 7;
const qreal HOST_DOT_GAP = 8;

// Panneau des statistiques (absent du prototype, dans le langage des pastilles).
const qreal STATS_MARGIN = 24;
const qreal STATS_PAD_X = 16;
const qreal STATS_PAD_Y = 12;
const qreal STATS_RADIUS = 12;
const QColor STATS_FILL(0, 0, 0, qRound(0.6 * 255));
const qreal STATS_TITLE_SIZE = 14;       // Sora 500, la ligne du flux
const qreal STATS_LINE_SIZE = 13;
const qreal STATS_LINE_HEIGHT = 1.5;

// Les tailles sont en points sur une image à 72 ppp (1 point = 1 pixel) : QFont
// n'accepte que des tailles de pixel entières, le canevas a des demi-pixels.
QFont sora(qreal size, QFont::Weight weight = QFont::Normal, qreal spacing = 0)
{
    QFont font(QStringLiteral("Sora"));
    font.setPointSizeF(size);
    font.setWeight(weight);
    font.setHintingPreference(QFont::PreferNoHinting);
    if (spacing != 0) {
        font.setLetterSpacing(QFont::AbsoluteSpacing, spacing);
    }
    return font;
}

// Un texte à la manière d'un Text QML en WordWrap ; renvoie le bas du bloc.
qreal drawWrapped(QPainter& p, const QString& text, const QFont& font, const QColor& color,
                  qreal x, qreal y, qreal width, qreal lineHeight = 1)
{
    if (text.isEmpty()) {
        return y;
    }
    QTextLayout layout(text, font, p.device());
    QTextOption option;
    option.setWrapMode(QTextOption::WordWrap);
    layout.setTextOption(option);
    qreal bottom = 0;
    layout.beginLayout();
    for (QTextLine line = layout.createLine(); line.isValid(); line = layout.createLine()) {
        line.setLineWidth(width);
        line.setPosition(QPointF(0, bottom));
        bottom += line.height() * lineHeight;
    }
    layout.endLayout();
    p.setPen(color);
    layout.draw(&p, QPointF(x, y));
    return y + bottom;
}

// Glyphe d'un bouton désigné par sa position (A en bas, B à droite…), comme
// ButtonGlyph.qml : lettres inversées sur une Nintendo, symboles sur une PlayStation.
void drawGlyph(QPainter& p, QPointF topLeft, const QString& button, const QString& layout, const QColor& ink)
{
    static const QHash<QString, QString> nintendo = { { "A", "B" }, { "B", "A" }, { "X", "Y" }, { "Y", "X" } };
    static const QHash<QString, QString> playstation = { { "A", "cross" }, { "B", "circle" },
                                                         { "X", "square" }, { "Y", "triangle" } };
    const QString face = layout == QLatin1String("nintendo") ? nintendo.value(button, button)
                       : layout == QLatin1String("playstation") ? playstation.value(button, button)
                       : button;

    const QRectF r(topLeft, QSizeF(GLYPH_SIZE, GLYPH_SIZE));
    const QPointF c = r.center();
    const qreal symbol = GLYPH_SIZE * GLYPH_SYMBOL_SCALE;
    const qreal half = GLYPH_BORDER / 2;

    p.setBrush(Qt::NoBrush);
    p.setPen(QPen(ink, GLYPH_BORDER, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    p.drawEllipse(r.adjusted(half, half, -half, -half));   // le trait reste dans le rond

    if (face == QLatin1String("cross")) {
        const qreal arm = (symbol * 1.15 - GLYPH_BORDER) / 2 / M_SQRT2;
        p.drawLine(c + QPointF(-arm, -arm), c + QPointF(arm, arm));
        p.drawLine(c + QPointF(-arm, arm), c + QPointF(arm, -arm));
    }
    else if (face == QLatin1String("circle")) {
        const qreal radius = symbol * 0.95 / 2 - half;
        p.drawEllipse(c, radius, radius);
    }
    else if (face == QLatin1String("square")) {
        const qreal side = symbol * 0.8 - GLYPH_BORDER;
        p.drawRoundedRect(QRectF(c.x() - side / 2, c.y() - side / 2, side, side), 1, 1);
    }
    else if (face == QLatin1String("triangle")) {
        const qreal h = symbol * 0.88;
        const QPointF points[] = { { c.x(), c.y() - h / 2 }, { c.x() + symbol / 2, c.y() + h / 2 },
                                   { c.x() - symbol / 2, c.y() + h / 2 } };
        p.drawPolygon(points, 3);
    }
    else {
        p.setFont(sora(GLYPH_FONT_SIZE, QFont::Medium));
        p.setPen(ink);
        p.drawText(r, Qt::AlignCenter, face);
    }
}

QFont statsFont(int line)
{
    return line == 0 ? sora(STATS_TITLE_SIZE, QFont::Medium) : sora(STATS_LINE_SIZE);
}

// Taille du panneau des statistiques, en pixels du canevas.
QSizeF statsSize(const StreamPainter::Stats& stats, QPaintDevice* device)
{
    qreal width = 0, height = 0;
    for (int i = 0; i < stats.lines.size(); i++) {
        const QFontMetricsF metrics(statsFont(i), device);
        const qreal dot = i == stats.dotLine ? HOST_DOT_SIZE + HOST_DOT_GAP : 0;
        width = qMax(width, dot + metrics.horizontalAdvance(stats.lines[i]));
        height += metrics.height() * STATS_LINE_HEIGHT;
    }
    return QSizeF(width + 2 * STATS_PAD_X, height + 2 * STATS_PAD_Y);
}

void drawStats(QPainter& p, const StreamPainter::Stats& stats, qreal opacity)
{
    if (stats.lines.isEmpty() || opacity <= 0) {
        return;
    }
    p.setOpacity(opacity);
    const QSizeF size = statsSize(stats, p.device());
    p.setPen(Qt::NoPen);
    p.setBrush(STATS_FILL);
    p.drawRoundedRect(QRectF(QPointF(STATS_MARGIN, STATS_MARGIN), size), STATS_RADIUS, STATS_RADIUS);

    qreal y = STATS_MARGIN + STATS_PAD_Y;
    for (int i = 0; i < stats.lines.size(); i++) {
        const QFont font = statsFont(i);
        const qreal lineHeight = QFontMetricsF(font, p.device()).height() * STATS_LINE_HEIGHT;
        const QRectF line(STATS_MARGIN + STATS_PAD_X, y, size.width() - 2 * STATS_PAD_X, lineHeight);
        qreal x = line.x();
        if (i == stats.dotLine) {
            p.setPen(Qt::NoPen);
            p.setBrush(stats.dot);
            p.drawEllipse(QRectF(x, line.center().y() - HOST_DOT_SIZE / 2, HOST_DOT_SIZE, HOST_DOT_SIZE));
            x += HOST_DOT_SIZE + HOST_DOT_GAP;
        }
        p.setFont(font);
        p.setPen(i == 0 ? INK : INK2);
        p.drawText(QRectF(x, line.y(), line.right() - x, lineHeight), Qt::AlignLeft | Qt::AlignVCenter, stats.lines[i]);
        y += lineHeight;
    }
    p.setOpacity(1);
}

// Une image à 72 ppp (1 point = 1 pixel) et un peintre à l'échelle du canevas.
QImage canvasImage(QSize size)
{
    QImage image(size, QImage::Format_ARGB32_Premultiplied);
    image.setDotsPerMeterX(2835);
    image.setDotsPerMeterY(2835);
    return image;
}

void beginCanvas(QPainter& p, QSize screen)
{
    p.setRenderHints(QPainter::Antialiasing | QPainter::TextAntialiasing);
    const qreal scale = screen.height() / CANVAS_HEIGHT;
    p.scale(scale, scale);
}

// Flou en boîte, ligne par ligne puis colonne par colonne, bords prolongés.
void boxBlur(QImage& image, int radius)
{
    const int width = image.width(), height = image.height();
    const int stride = image.bytesPerLine() / 4;
    QRgb* bits = reinterpret_cast<QRgb*>(image.bits());
    QVector<QRgb> line(qMax(width, height));
    const int count = 2 * radius + 1;
    for (int pass = 0; pass < 2; pass++) {
        const bool rows = pass == 0;
        const int lines = rows ? height : width, length = rows ? width : height;
        const int step = rows ? 1 : stride;
        for (int i = 0; i < lines; i++) {
            QRgb* start = bits + (rows ? i * stride : i);
            for (int j = 0; j < length; j++) {
                line[j] = start[j * step];
            }
            int r = 0, g = 0, b = 0;
            for (int k = -radius; k <= radius; k++) {
                const QRgb c = line[qBound(0, k, length - 1)];
                r += qRed(c); g += qGreen(c); b += qBlue(c);
            }
            for (int j = 0; j < length; j++) {
                start[j * step] = qRgb(r / count, g / count, b / count);
                const QRgb out = line[qMax(j - radius, 0)];
                const QRgb in = line[qMin(j + radius + 1, length - 1)];
                r += qRed(in) - qRed(out); g += qGreen(in) - qGreen(out); b += qBlue(in) - qBlue(out);
            }
        }
    }
}

}

QImage StreamPainter::blurred(QImage small, QSize screen)
{
    small = small.convertToFormat(QImage::Format_RGB32);
    for (int pass = 0; pass < 3; pass++) {   // trois passes : presque un flou gaussien
        boxBlur(small, BACKDROP_BLUR);
    }
    // Agrandie en deux temps : d'un coup, l'interpolation laisserait voir la grille.
    QImage backdrop = small.scaled(small.size() * 2, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    boxBlur(backdrop, 1);
    backdrop = backdrop.scaled(screen, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                       .convertToFormat(QImage::Format_ARGB32_Premultiplied);
    QPainter p(&backdrop);
    p.fillRect(backdrop.rect(), QColor(0, 0, 0, qRound(BACKDROP_DIM * 255)));
    return backdrop;
}

QColor StreamPainter::networkColor(int latencyMs, int jitterMs)
{
    if (latencyMs <= 0) {
        return INK3;
    }
    const int jitter = qMax(0, jitterMs);
    if (latencyMs <= 20 && jitter <= 5) {
        return OK;
    }
    if (latencyMs <= 50 && jitter <= 15) {
        return FAIR;
    }
    return POOR;
}

QImage StreamPainter::paintStats(const Stats& stats, qreal opacity, QSize screen)
{
    if (stats.lines.isEmpty() || opacity <= 0 || screen.isEmpty()) {
        return QImage();
    }
    const qreal scale = screen.height() / CANVAS_HEIGHT;
    QImage image = canvasImage(QSize(1, 1));
    const QSizeF size = statsSize(stats, &image);
    image = canvasImage(QSize(qCeil((STATS_MARGIN + size.width()) * scale),
                              qCeil((STATS_MARGIN + size.height()) * scale)));
    image.fill(Qt::transparent);
    QPainter p(&image);
    beginCanvas(p, screen);
    drawStats(p, stats, opacity);
    return image;
}

namespace {

QColor mix(const QColor& a, const QColor& b, qreal t)
{
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t, a.alphaF() + (b.alphaF() - a.alphaF()) * t);
}

qreal ease(QEasingCurve::Type type, qreal t)
{
    return QEasingCurve(type).valueForProgress(qBound<qreal>(0, t, 1));
}

void drawValue(QPainter& p, const QRectF& row, const QString& value, qreal dx, qreal opacity, const QColor& ink)
{
    if (value.isEmpty() || opacity <= 0) {
        return;
    }
    const qreal base = p.opacity();
    p.setOpacity(base * opacity);
    p.setFont(sora(SHEET_VALUE_SIZE));
    p.setPen(ink);
    p.drawText(row.translated(dx, 0), Qt::AlignRight | Qt::AlignVCenter, value);
    p.setOpacity(base);
}

// Le contenu du panneau (titre, message, choix, légende), à l'opacité donnée.
void drawPage(QPainter& p, const StreamPainter::Page& page, const StreamPainter::Frame& frame,
              qreal focusY, const QVector<qreal>& highlight, qreal panelX, qreal opacity, bool current)
{
    if (opacity <= 0) {
        return;
    }
    p.setOpacity(opacity);
    const qreal x = panelX + SHEET_PAD_SIDE;
    const qreal width = SHEET_WIDTH - 2 * SHEET_PAD_SIDE;
    qreal y = drawWrapped(p, page.title, sora(SHEET_TITLE_SIZE, QFont::DemiBold, SHEET_TITLE_SPACING),
                          INK, x, SHEET_PAD_TOP, width);
    y = drawWrapped(p, page.message, sora(DIALOG_MESSAGE_SIZE), INK2,
                    x, y + DIALOG_MESSAGE_TOP, width, DIALOG_MESSAGE_LINE_HEIGHT);
    y += DIALOG_CHOICES_TOP;

    // --- Choix ---
    p.setPen(Qt::NoPen);
    p.setBrush(FOCUS_FILL);
    p.drawRoundedRect(QRectF(x - SHEET_FOCUS_OUTSET, y + focusY * SHEET_ROW_HEIGHT,
                             width + 2 * SHEET_FOCUS_OUTSET, SHEET_ROW_HEIGHT),
                      SHEET_FOCUS_RADIUS, SHEET_FOCUS_RADIUS);
    for (int i = 0; i < page.labels.size(); i++) {
        const QRectF row(x, y + i * SHEET_ROW_HEIGHT, width, SHEET_ROW_HEIGHT);
        const qreal h = highlight.value(i, i == page.focus ? 1 : 0);
        const QColor ink = mix(INK2, INK, h);
        const QString value = page.values.value(i);
        p.setFont(sora(SHEET_LABEL_SIZE));
        p.setPen(ink);
        p.drawText(row, Qt::AlignLeft | Qt::AlignVCenter, page.labels[i]);
        if (!value.isEmpty()) {
            if (current && i == frame.swapRow && frame.swapProgress < 1) {
                // SwapBox : la nouvelle valeur entre par la droite, l'ancienne sort à gauche.
                const qreal t = frame.swapProgress;
                p.save();
                p.setClipRect(QRectF(row.right() - SHEET_VALUE_BOX, row.y(), SHEET_VALUE_BOX, row.height()));
                drawValue(p, row, frame.swapFrom,
                          -SHEET_VALUE_TRAVEL * SWAP_EXIT_TRAVEL * ease(QEasingCurve::OutCubic, t / SWAP_EXIT_DURATION),
                          1 - qMin<qreal>(1, t / SWAP_EXIT_FADE), ink);
                drawValue(p, row, value, SHEET_VALUE_TRAVEL * (1 - ease(QEasingCurve::OutQuint, t)),
                          qMin<qreal>(1, t / SWAP_ENTER_FADE), ink);
                p.restore();
            }
            else {
                drawValue(p, row, value, 0, 1, ink);
            }
        }
        else if (h > 0) {
            p.setOpacity(opacity * h);
            drawGlyph(p, QPointF(row.right() - SHEET_HINT_RIGHT - GLYPH_SIZE, row.center().y() - GLYPH_SIZE / 2),
                      QStringLiteral("A"), frame.layout, INK3);
            p.setOpacity(opacity);
        }
    }

    // --- Légende ---
    const QFont legendFont = sora(LEGEND_SIZE);
    const QFontMetricsF metrics(legendFont, p.device());
    qreal legendX = x;
    const qreal legendY = CANVAS_HEIGHT - SHEET_PAD_BOTTOM - GLYPH_SIZE;
    const QList<QPair<QString, QString>> hints = {
        { "B", page.backLabel }, { "A", QCoreApplication::translate("StreamMenu", "Valider") }
    };
    for (const auto& hint : hints) {
        drawGlyph(p, QPointF(legendX, legendY), hint.first, frame.layout, INK2);
        legendX += GLYPH_SIZE + LEGEND_GLYPH_GAP;
        const qreal labelWidth = metrics.horizontalAdvance(hint.second);
        p.setFont(legendFont);
        p.setPen(INK2);
        p.drawText(QRectF(legendX, legendY, labelWidth + 1, GLYPH_SIZE), Qt::AlignLeft | Qt::AlignVCenter, hint.second);
        legendX += labelWidth + LEGEND_GAP;
    }
    p.setOpacity(1);
}

}

bool StreamPainter::paintFrame(const Frame& frame, QImage& image)
{
    const QSize screen = image.size();
    image.setDotsPerMeterX(2835);   // 72 ppp, comme canvasImage
    image.setDotsPerMeterY(2835);
    if (frame.curtain >= 1) {
        image.fill(Qt::black);
        return true;
    }

    // --- Fond : l'image du jeu floutée, ou un voile en attendant ---
    // Posée entièrement (presque tout le temps), elle est simplement recopiée : c'est
    // le plus gros de l'image, inutile de la mélanger à quoi que ce soit.
    const bool solid = frame.backdrop.size() == screen && frame.veil >= 1 && frame.blurMix >= 1;
    if (solid) {
        const QImage backdrop = frame.backdrop.convertToFormat(QImage::Format_ARGB32_Premultiplied);
        for (int y = 0; y < screen.height(); y++) {
            memcpy(image.scanLine(y), backdrop.constScanLine(y), screen.width() * 4);
        }
    }
    else if (frame.backdrop.size() != screen || frame.blurMix <= 0) {
        image.fill(QColor(0, 0, 0, qRound(SHEET_DIM * 255 * frame.veil)));
    }
    QPainter p(&image);
    if (!solid && frame.backdrop.size() == screen && frame.blurMix > 0) {
        // En fondu : l'image floutée remplace ce qu'il y avait (une seule passe)…
        p.setCompositionMode(QPainter::CompositionMode_Source);
        p.setOpacity(frame.veil * frame.blurMix);
        p.drawImage(0, 0, frame.backdrop);
        p.setCompositionMode(QPainter::CompositionMode_SourceOver);
        p.setOpacity(1);
        // …et le voile qu'elle remplace s'efface par-dessus.
        if (frame.blurMix < 1) {
            p.fillRect(image.rect(), QColor(0, 0, 0, qRound(SHEET_DIM * 255 * frame.veil * (1 - frame.blurMix))));
        }
    }

    beginCanvas(p, screen);
    drawStats(p, frame.stats, frame.statsOpacity);

    // --- Panneau ---
    const qreal canvasWidth = screen.width() * CANVAS_HEIGHT / screen.height();
    const qreal panelX = canvasWidth - SHEET_WIDTH * frame.reveal + SHEET_WIDTH * SHEET_HIDDEN_SHIFT * (1 - frame.reveal);
    if (panelX < canvasWidth) {
        p.fillRect(QRectF(panelX, 0, SHEET_WIDTH, CANVAS_HEIGHT), SHEET_FILL);
        p.fillRect(QRectF(panelX - 1, 0, 1, CANVAS_HEIGHT), SHEET_EDGE);
    }

    // Changement de page : l'ancienne s'efface sur la première moitié, la nouvelle
    // apparaît sur la seconde (un fondu croisé superposerait deux textes).
    if (frame.pageMix < 0.5) {
        drawPage(p, frame.previous, frame, frame.previous.focus, QVector<qreal>(), panelX, 1 - 2 * frame.pageMix, false);
    }
    drawPage(p, frame.page, frame, frame.focusY < 0 ? frame.page.focus : frame.focusY, frame.highlight,
             panelX, frame.pageMix < 1 ? qMax<qreal>(0, 2 * frame.pageMix - 1) : 1, true);
    if (frame.curtain > 0) {
        p.resetTransform();
        p.fillRect(image.rect(), QColor(0, 0, 0, qRound(255 * frame.curtain)));
    }
    return solid;
}
