#include "streampainter.h"

#include <QCoreApplication>
#include <QFontMetricsF>
#include <QHash>
#include <QPainter>
#include <QTextLayout>
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

void drawStats(QPainter& p, const StreamPainter::Stats& stats)
{
    if (stats.lines.isEmpty()) {
        return;
    }
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

QImage StreamPainter::paintStats(const Stats& stats, QSize screen)
{
    if (stats.lines.isEmpty() || screen.isEmpty()) {
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
    drawStats(p, stats);
    return image;
}

QImage StreamPainter::paintMenu(const Menu& menu, QSize screen)
{
    QImage image = canvasImage(screen);
    // Voile sur le flux, qui continue de bouger dessous.
    image.fill(QColor(0, 0, 0, qRound(SHEET_DIM * 255)));

    QPainter p(&image);
    beginCanvas(p, screen);
    const qreal canvasWidth = screen.width() * CANVAS_HEIGHT / screen.height();
    drawStats(p, menu.stats);

    // --- Panneau ---
    const QRectF panel(canvasWidth - SHEET_WIDTH, 0, SHEET_WIDTH, CANVAS_HEIGHT);
    p.fillRect(panel, SHEET_FILL);
    p.fillRect(QRectF(panel.x() - 1, 0, 1, CANVAS_HEIGHT), SHEET_EDGE);

    const qreal x = panel.x() + SHEET_PAD_SIDE;
    const qreal width = SHEET_WIDTH - 2 * SHEET_PAD_SIDE;
    qreal y = drawWrapped(p, menu.title, sora(SHEET_TITLE_SIZE, QFont::DemiBold, SHEET_TITLE_SPACING),
                          INK, x, SHEET_PAD_TOP, width);
    y = drawWrapped(p, menu.message, sora(DIALOG_MESSAGE_SIZE), INK2,
                    x, y + DIALOG_MESSAGE_TOP, width, DIALOG_MESSAGE_LINE_HEIGHT);
    y += DIALOG_CHOICES_TOP;

    // --- Choix ---
    p.setPen(Qt::NoPen);
    p.setBrush(FOCUS_FILL);
    p.drawRoundedRect(QRectF(x - SHEET_FOCUS_OUTSET, y + menu.focus * SHEET_ROW_HEIGHT,
                             width + 2 * SHEET_FOCUS_OUTSET, SHEET_ROW_HEIGHT),
                      SHEET_FOCUS_RADIUS, SHEET_FOCUS_RADIUS);
    for (int i = 0; i < menu.labels.size(); i++) {
        const QRectF row(x, y + i * SHEET_ROW_HEIGHT, width, SHEET_ROW_HEIGHT);
        const bool focused = i == menu.focus;
        const QString value = menu.values.value(i);
        p.setFont(sora(SHEET_LABEL_SIZE));
        p.setPen(focused ? INK : INK2);
        p.drawText(row, Qt::AlignLeft | Qt::AlignVCenter, menu.labels[i]);
        if (!value.isEmpty()) {
            p.setFont(sora(SHEET_VALUE_SIZE));
            p.setPen(INK2);
            p.drawText(row, Qt::AlignRight | Qt::AlignVCenter, value);
        }
        else if (focused) {
            drawGlyph(p, QPointF(row.right() - SHEET_HINT_RIGHT - GLYPH_SIZE, row.center().y() - GLYPH_SIZE / 2),
                      QStringLiteral("A"), menu.layout, INK3);
        }
    }

    // --- Légende ---
    const QFont legendFont = sora(LEGEND_SIZE);
    const QFontMetricsF metrics(legendFont, &image);
    qreal legendX = x;
    const qreal legendY = CANVAS_HEIGHT - SHEET_PAD_BOTTOM - GLYPH_SIZE;
    const QList<QPair<QString, QString>> hints = { { "B", menu.backLabel }, { "A", QCoreApplication::translate("StreamMenu", "Valider") } };
    for (const auto& hint : hints) {
        drawGlyph(p, QPointF(legendX, legendY), hint.first, menu.layout, INK2);
        legendX += GLYPH_SIZE + LEGEND_GLYPH_GAP;
        const qreal labelWidth = metrics.horizontalAdvance(hint.second);
        p.setFont(legendFont);
        p.setPen(INK2);
        p.drawText(QRectF(legendX, legendY, labelWidth + 1, GLYPH_SIZE), Qt::AlignLeft | Qt::AlignVCenter, hint.second);
        legendX += labelWidth + LEGEND_GAP;
    }

    return image;
}
