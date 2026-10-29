#include "streampainter.h"

#include <QCoreApplication>
#include <QEasingCurve>
#include <QFontMetricsF>
#include <QHash>
#include <QImageReader>
#include <QPainter>
#include <QPainterPath>
#include <QTextLayout>
#include <QVector>

#include <cstring>
#include <QtMath>

namespace {

// Jetons de Theme.qml, en pixels du canevas de 800 de haut.
const qreal CANVAS_HEIGHT = 800;
const QColor INK("#F5F5F7");
const QColor INK2(245, 245, 247, qRound(0.6 * 255));
const QColor INK3(245, 245, 247, qRound(0.5 * 255));
const QColor ACCENT("#F2802A");
const QColor INK_ON_ACCENT("#1B0E04");
const QColor INK_DARK("#1C1C1E");          // texte et icônes sur une tuile claire
const qreal HOLD_SWAP_SHIFT = 16;        // Theme.holdSwapShift × la hauteur du libellé
const qreal HOLD_CHECK_SIZE = 18;
const qreal HOLD_CHECK_GAP = 8;
const qreal CHECK_STROKE = 2.4;          // sur la grille 24 × 24 de CheckMark.qml
const QColor OK("#69D08E");
const QColor FAIR("#E8C547");
const QColor POOR("#FF453A");
const qreal SHEET_DIM = 0.62;            // voile, en attendant l'image floutée
const qreal BACKDROP_DIM = 0.45;         // image floutée : luminosité 0,6 puis voile de 25 % (JeuControle)
const int BACKDROP_BLUR = 3;             // rayon du flou en boîte, en pixels de l'image réduite

// Centre de contrôle (JeuControle) : une grille de 8 colonnes de 80 px (16 entre elles),
// lignes de 80 px, centrée ; l'en-tête au-dessus, la légende en dessous.
const qreal GRID_WIDTH = 752;
const qreal GRID_TOP = 152;
const qreal GRID_CELL = 80;
const qreal GRID_GAP = 16;
const qreal TILE_RADIUS = 28;
const QColor TILE_FILL(255, 255, 255, qRound(0.10 * 255));
const QColor TILE_EDGE(255, 255, 255, qRound(0.10 * 255));
const QColor TILE_EDGE_FOCUS(255, 255, 255, qRound(0.55 * 255));
const QColor TILE_RING(245, 245, 247, qRound(0.28 * 255));
const qreal TILE_RING_WIDTH = 4;
const qreal TILE_FOCUS_SCALE = 1.03;
const QColor TILE_ICON_FILL(255, 255, 255, qRound(0.14 * 255));
const QColor SLIDER_FILL(245, 245, 247, qRound(0.94 * 255));
const QColor RESUME_SUB(0, 0, 0, qRound(0.55 * 255));
const QColor RESUME_GLYPH(0, 0, 0, qRound(0.4 * 255));
const QColor SUB_INK(245, 245, 247, qRound(0.62 * 255));
const QColor STATUS_INK(245, 245, 247, qRound(0.65 * 255));
const qreal HEADER_CENTER = 100;         // milieu de l'en-tête (haut 72, vignette de 56)
const qreal LEGEND_TOP = 680;
const qreal LEGEND_SIZE = 13;
const qreal LEGEND_GAP = 24;
const qreal LEGEND_GLYPH_GAP = 8;
const QColor LEGEND_INK(245, 245, 247, qRound(0.65 * 255));
const QColor GLYPH_EDGE(245, 245, 247, qRound(0.45 * 255));
const qreal GLYPH_SIZE = 22;
const qreal GLYPH_BORDER = 1;
const qreal GLYPH_FONT_SIZE = 11;
const qreal GLYPH_SYMBOL_SCALE = 0.42;
const qreal GLYPH_PILL_PAD = 7;
// Entrée (MotionMenuJeu) : chaque tuile 35 ms après la précédente, fondu de 380 ms, échelle de
// 0,9 à 1 au ressort (560 ms) ; l'en-tête après 60 ms (fondu 380, 10 px vers le bas en 520).
// Fermeture : fondu de 220 ms, échelle vers 0,9 (260 ms).
const qreal ENTRY_STAGGER = 35;
const qreal ENTRY_FADE = 380;
const qreal ENTRY_MOVE = 560;
const qreal ENTRY_FROM = 0.9;
const qreal HEADER_DELAY = 60;
const qreal HEADER_MOVE = 520;
const qreal HEADER_SHIFT = 10;
const qreal CLOSE_FADE = 220;
const qreal CLOSE_MOVE = 260;
// Menu d'alimentation (MenuAlimentation) : carte centrée de 600 × 330, trois pastilles.
const qreal POWER_WIDTH = 600;
const qreal POWER_HEIGHT = 330;
const qreal POWER_TOP = 220;
const qreal POWER_RADIUS = 36;
const QColor POWER_FILL(44, 44, 46, qRound(0.84 * 255));
const QColor POWER_DIM(0, 0, 0, qRound(0.45 * 255));
const qreal POWER_ITEM = 150;
const qreal POWER_GAP = 22;
const qreal POWER_DISC = 92;
const qreal POWER_DISC_FOCUS = 1.08;
const QColor POWER_DISC_FILL(255, 255, 255, qRound(0.12 * 255));
const QColor POWER_LABEL(245, 245, 247, qRound(0.7 * 255));
const QColor POWER_NOTE(245, 245, 247, qRound(0.55 * 255));
const qreal POWER_FROM = 0.96;           // la carte arrive d'une échelle de 0,96
const qreal POWER_RECEDE = 0.7;          // derrière elle, le centre de contrôle s'estompe d'autant
const qreal LEGEND_BOTTOM = 34;          // légende de la carte : centrée en bas

// Panneau des statistiques (absent du prototype, dans le langage des pastilles).
const qreal STATS_MARGIN = 24;
const qreal STATS_PAD_X = 16;
const qreal STATS_PAD_Y = 12;
const qreal STATS_RADIUS = 12;
const QColor STATS_FILL(0, 0, 0, qRound(0.6 * 255));
const qreal STATS_TITLE_SIZE = 14;       // Sora 500, la ligne du flux
const qreal STATS_LINE_SIZE = 13;
const qreal STATS_LINE_HEIGHT = 1.5;
const qreal HOST_DOT_SIZE = 7;
const qreal HOST_DOT_GAP = 8;
const qreal NOTICE_HEIGHT = 40;          // l'avis : une pastille sombre, un point, un texte
const qreal NOTICE_PAD_X = 16;
const qreal NOTICE_SIZE = 14;            // Sora 500
const qreal NOTICE_SHIFT = 10;           // il descend d'autant en apparaissant

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

// Glyphe d'un bouton désigné par sa position (A en bas, B à droite…), comme
// ButtonGlyph.qml : lettres inversées sur une Nintendo, symboles sur une PlayStation ;
// "◀▶" et "▲▼" : une pastille à deux flèches.
qreal glyphWidth(const QString& button)
{
    return button.size() > 1 && button.at(0).unicode() > 0x2000 ? GLYPH_SIZE + 2 * GLYPH_PILL_PAD : GLYPH_SIZE;
}

void drawGlyph(QPainter& p, QPointF topLeft, const QString& button, const QString& layout, const QColor& ink,
               const QColor& edge, qreal size = GLYPH_SIZE, qreal fontSize = GLYPH_FONT_SIZE)
{
    static const QHash<QString, QString> nintendo = { { "A", "B" }, { "B", "A" }, { "X", "Y" }, { "Y", "X" } };
    static const QHash<QString, QString> playstation = { { "A", "cross" }, { "B", "circle" },
                                                         { "X", "square" }, { "Y", "triangle" } };
    const QString face = layout == QLatin1String("nintendo") ? nintendo.value(button, button)
                       : layout == QLatin1String("playstation") ? playstation.value(button, button)
                       : button;
    const bool arrows = button.size() > 1 && button.at(0).unicode() > 0x2000;
    const QRectF r(topLeft, QSizeF(arrows ? glyphWidth(button) * size / GLYPH_SIZE : size, size));
    const QPointF c = r.center();
    const qreal symbol = size * GLYPH_SYMBOL_SCALE;
    const qreal half = GLYPH_BORDER / 2;

    p.setBrush(Qt::NoBrush);
    p.setPen(QPen(edge, GLYPH_BORDER, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    p.drawRoundedRect(r.adjusted(half, half, -half, -half), size / 2 - half, size / 2 - half);
    p.setPen(QPen(ink, 1.5, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));

    if (arrows) {
        // Deux petits triangles pleins, côte à côte (◀▶) ou l'un sur l'autre (▲▼).
        const bool vertical = button.at(0) == QChar(0x25B2);
        const qreal t = size * 0.18;
        p.setPen(Qt::NoPen);
        p.setBrush(ink);
        for (int side = -1; side <= 1; side += 2) {
            QPolygonF tri;
            if (vertical) {
                const QPointF o = c + QPointF(0, side * t * 0.9);
                tri << o + QPointF(-t, -side * t * 0.5) << o + QPointF(t, -side * t * 0.5) << o + QPointF(0, side * t * 0.6);
            }
            else {
                const QPointF o = c + QPointF(side * t * 1.1, 0);
                tri << o + QPointF(-side * t * 0.5, -t) << o + QPointF(-side * t * 0.5, t) << o + QPointF(side * t * 0.6, 0);
            }
            p.drawPolygon(tri);
        }
    }
    else if (face == QLatin1String("cross")) {
        const qreal arm = symbol * 1.15 / 2 / M_SQRT2;
        p.drawLine(c + QPointF(-arm, -arm), c + QPointF(arm, arm));
        p.drawLine(c + QPointF(-arm, arm), c + QPointF(arm, -arm));
    }
    else if (face == QLatin1String("circle")) {
        const qreal radius = symbol * 0.95 / 2;
        p.drawEllipse(c, radius, radius);
    }
    else if (face == QLatin1String("square")) {
        const qreal side = symbol * 0.8;
        p.drawRoundedRect(QRectF(c.x() - side / 2, c.y() - side / 2, side, side), 1, 1);
    }
    else if (face == QLatin1String("triangle")) {
        const qreal h = symbol * 0.88;
        const QPointF points[] = { { c.x(), c.y() - h / 2 }, { c.x() + symbol / 2, c.y() + h / 2 },
                                   { c.x() - symbol / 2, c.y() + h / 2 } };
        p.drawPolygon(points, 3);
    }
    else {
        QFont font(QStringLiteral("Sora"));
        font.setPointSizeF(fontSize);
        font.setWeight(QFont::DemiBold);
        font.setHintingPreference(QFont::PreferNoHinting);
        p.setFont(font);
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

// La coche de CheckMark.qml (polyligne sur une grille 24 × 24), tracée jusqu'à `drawn`.
void drawCheck(QPainter& p, const QRectF& box, const QColor& color, qreal drawn)
{
    const qreal unit = box.width() / 24;
    const QPointF points[] = { { 4.5, 12.5 }, { 9.3, 17.3 }, { 19.5, 7 } };
    const qreal legs[] = { QLineF(points[0], points[1]).length(), QLineF(points[1], points[2]).length() };
    qreal left = drawn * (legs[0] + legs[1]);
    QPainterPath path(box.topLeft() + points[0] * unit);
    for (int i = 0; i < 2 && left > 0; i++) {
        const qreal t = qMin<qreal>(1, left / legs[i]);
        path.lineTo(box.topLeft() + (points[i] + (points[i + 1] - points[i]) * t) * unit);
        left -= legs[i];
    }
    p.save();
    p.setBrush(Qt::NoBrush);
    p.setPen(QPen(color, CHECK_STROKE * unit, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    p.drawPath(path);
    p.restore();
}

// Icônes (SVG blancs d'icons/), rendues à la taille de l'écran puis teintées.
QString s_iconRoot = QStringLiteral(":/gui/console/icons/");
qreal s_pixelScale = 1;                     // pixels de l'écran par pixel du canevas

QImage icon(const QString& name, qreal size, const QColor& color)
{
    static QHash<QString, QImage> cache;
    const int px = qMax(1, qRound(size * s_pixelScale));
    const QString key = QStringLiteral("%1/%2/%3").arg(name).arg(px).arg(color.rgba());
    auto found = cache.constFind(key);
    if (found != cache.constEnd()) {
        return *found;
    }
    QImageReader reader(s_iconRoot + name + QStringLiteral(".svg"));
    reader.setScaledSize(QSize(px, px));
    QImage image = reader.read().convertToFormat(QImage::Format_ARGB32_Premultiplied);
    if (!image.isNull()) {
        QPainter tint(&image);
        tint.setCompositionMode(QPainter::CompositionMode_SourceIn);
        tint.fillRect(image.rect(), color);
    }
    cache.insert(key, image);
    return image;
}

void drawIcon(QPainter& p, const QString& name, QPointF center, qreal size, const QColor& color)
{
    const QImage image = icon(name, size, color);
    if (!image.isNull()) {
        p.drawImage(QRectF(center.x() - size / 2, center.y() - size / 2, size, size), image);
    }
}

void drawText(QPainter& p, const QRectF& box, int align, const QString& text, const QFont& font, const QColor& color)
{
    p.setFont(font);
    p.setPen(color);
    p.drawText(box, align | Qt::TextSingleLine, text);
}

qreal textWidth(QPainter& p, const QString& text, const QFont& font)
{
    return QFontMetricsF(font, p.device()).horizontalAdvance(text);
}

// Courbes CocoOS : curveMain et le ressort des dialogues (Theme.curveSpring).
qreal curve(qreal t, QPointF c1, QPointF c2)
{
    QEasingCurve easing(QEasingCurve::BezierSpline);
    easing.addCubicBezierSegment(c1, c2, QPointF(1, 1));
    return easing.valueForProgress(qBound<qreal>(0, t, 1));
}
qreal curveMain(qreal t) { return curve(t, QPointF(0.32, 0.72), QPointF(0, 1)); }
qreal curveSpring(qreal t) { return curve(t, QPointF(0.3, 1.25), QPointF(0.4, 1)); }

const char* const TILE_ORDER[] = { "resume", "brightness", "volume", "shot", "stats", "home", "quit", "sleep", "power" };
// Place de chaque tuile dans la grille : colonne, ligne, largeur, hauteur (en cases).
const int TILE_CELLS[][4] = { { 0, 0, 4, 2 }, { 4, 0, 2, 4 }, { 6, 0, 2, 4 }, { 0, 2, 2, 2 }, { 2, 2, 2, 2 },
                              { 0, 4, 2, 1 }, { 2, 4, 2, 1 }, { 4, 4, 2, 1 }, { 6, 4, 2, 1 } };

qreal canvasWidth(QSize screen)
{
    return screen.width() * CANVAS_HEIGHT / screen.height();
}

int cellsOf(const QString& key)
{
    for (int i = 0; i < 9; i++) {
        if (key == QLatin1String(TILE_ORDER[i])) {
            return i;
        }
    }
    return -1;
}

QRectF tileRect(const QString& key, qreal width)
{
    const int i = cellsOf(key);
    if (i < 0) {
        return QRectF();
    }
    const qreal step = GRID_CELL + GRID_GAP;
    const qreal left = (width - GRID_WIDTH) / 2;
    return QRectF(left + TILE_CELLS[i][0] * step, GRID_TOP + TILE_CELLS[i][1] * step,
                  TILE_CELLS[i][2] * step - GRID_GAP, TILE_CELLS[i][3] * step - GRID_GAP);
}

QRectF powerCard(qreal width)
{
    return QRectF((width - POWER_WIDTH) / 2, POWER_TOP, POWER_WIDTH, POWER_HEIGHT);
}

// Les pastilles de la carte d'alimentation, centrées dans la carte.
QRectF powerItem(const StreamPainter::Power& power, int i, qreal width)
{
    const QRectF card = powerCard(width);
    const qreal total = power.keys.size() * POWER_ITEM + (power.keys.size() - 1) * POWER_GAP;
    const qreal x = card.center().x() - total / 2 + i * (POWER_ITEM + POWER_GAP);
    return QRectF(x, card.y() + 36 + 17 + 30, POWER_ITEM, POWER_DISC + 14 + 20);
}

// Une légende centrée : glyphe, libellé ; à la ligne `top`.
void drawLegend(QPainter& p, const QList<QPair<QString, QString>>& hints, qreal width, qreal top,
                const QString& layout, qreal gap = LEGEND_GAP)
{
    const QFont font = sora(LEGEND_SIZE, QFont::Medium);
    qreal total = -gap;
    for (const auto& hint : hints) {
        total += gap + glyphWidth(hint.first) + LEGEND_GLYPH_GAP + textWidth(p, hint.second, font);
    }
    qreal x = (width - total) / 2;
    for (const auto& hint : hints) {
        drawGlyph(p, QPointF(x, top), hint.first, layout, INK, GLYPH_EDGE);
        x += glyphWidth(hint.first) + LEGEND_GLYPH_GAP;
        const qreal w = textWidth(p, hint.second, font);
        drawText(p, QRectF(x, top, w + 1, GLYPH_SIZE), Qt::AlignLeft | Qt::AlignVCenter, hint.second, font, LEGEND_INK);
        x += w + gap;
    }
}

// La batterie de la barre haute (le SVG des maquettes) : contour, remplissage, borne.
void drawBattery(QPainter& p, QPointF topLeft, int percent)
{
    const qreal k = 25.0 / 27;
    p.save();
    p.translate(topLeft);
    p.scale(k, k * 12 / 13);
    p.setBrush(Qt::NoBrush);
    p.setPen(QPen(QColor(245, 245, 247, qRound(0.45 * 255)), 1));
    p.drawRoundedRect(QRectF(0.5, 0.5, 23, 12), 3.5, 3.5);
    p.setPen(Qt::NoPen);
    p.setBrush(percent < 20 ? ACCENT : INK);
    p.drawRoundedRect(QRectF(2, 2, 20 * qBound(0, percent, 100) / 100.0, 9), 2, 2);
    p.setBrush(QColor(245, 245, 247, qRound(0.45 * 255)));
    p.drawRoundedRect(QRectF(24.8, 4.5, 1.6, 4), 0.8, 0.8);
    p.restore();
}

void drawHeader(QPainter& p, const StreamPainter::Control& control, qreal width, qreal opacity, qreal shift)
{
    if (opacity <= 0) {
        return;
    }
    p.save();
    p.setOpacity(p.opacity() * opacity);
    p.translate(0, shift);
    const qreal left = (width - GRID_WIDTH) / 2, right = left + GRID_WIDTH;
    qreal x = left;
    if (!control.cover.isNull()) {
        const QRectF thumb(x, HEADER_CENTER - 28, 40, 56);
        QPainterPath clip;
        clip.addRoundedRect(thumb, 6, 6);
        p.save();
        p.setClipPath(clip);
        const QImage cover = control.cover;
        const qreal scale = qMax(thumb.width() / cover.width(), thumb.height() / cover.height());
        const QSizeF size(cover.width() * scale, cover.height() * scale);
        p.drawImage(QRectF(thumb.center() - QPointF(size.width() / 2, size.height() / 2), size), cover);
        p.restore();
        p.setBrush(Qt::NoBrush);
        p.setPen(QPen(QColor(255, 255, 255, qRound(0.12 * 255)), 1));
        p.drawRoundedRect(thumb, 6, 6);
        x += 40 + 14;
    }
    const QFont title = sora(22, QFont::DemiBold, -0.44);
    const QFont status = sora(13, QFont::Medium);
    drawText(p, QRectF(x, HEADER_CENTER - 29, right - x, 28), Qt::AlignLeft | Qt::AlignVCenter, control.game, title, INK);
    drawText(p, QRectF(x, HEADER_CENTER + 1, right - x, 18), Qt::AlignLeft | Qt::AlignVCenter, control.status, status, STATUS_INK);

    // À droite : le PC et sa latence, l'heure, la batterie.
    const QFont small = sora(13, QFont::DemiBold);
    const QFont thin = sora(13, QFont::Medium);
    const QFont clock = sora(15, QFont::DemiBold);
    qreal r = right;
    const QRectF line(0, HEADER_CENTER - 10, 0, 20);
    if (control.battery >= 0) {
        r -= 25;
        drawBattery(p, QPointF(r, HEADER_CENTER - 6), control.battery);
        const QString label = QStringLiteral("%1 %").arg(control.battery);
        r -= 6 + textWidth(p, label, small);
        drawText(p, QRectF(r, line.y(), 100, line.height()), Qt::AlignLeft | Qt::AlignVCenter, label, small, INK);
        r -= 16;
    }
    if (!control.time.isEmpty()) {
        r -= textWidth(p, control.time, clock);
        drawText(p, QRectF(r, line.y(), 100, line.height()), Qt::AlignLeft | Qt::AlignVCenter, control.time, clock, INK);
        r -= 16;
    }
    if (!control.host.isEmpty()) {
        if (!control.latency.isEmpty()) {
            r -= textWidth(p, control.latency, thin);
            drawText(p, QRectF(r, line.y(), 100, line.height()), Qt::AlignLeft | Qt::AlignVCenter,
                     control.latency, thin, QColor(245, 245, 247, qRound(0.6 * 255)));
            r -= 8;
        }
        r -= textWidth(p, control.host, small);
        drawText(p, QRectF(r, line.y(), 200, line.height()), Qt::AlignLeft | Qt::AlignVCenter, control.host, small, INK);
        r -= 8 + 6;
        p.setPen(Qt::NoPen);
        p.setBrush(ACCENT);
        p.drawEllipse(QRectF(r, HEADER_CENTER - 3, 6, 6));
    }
    p.restore();
}

// Le remplissage d'un appui maintenu sur la tuile `box` (HoldFill.qml) : orange, de gauche à
// droite ; plein, le libellé cède la place à une coche et au libellé de fin.
void drawHold(QPainter& p, const QRectF& box, const QString& icon, const QString& label, const StreamPainter::Frame& frame)
{
    p.save();
    QPainterPath shape;
    shape.addRoundedRect(box, TILE_RADIUS, TILE_RADIUS);
    p.setClipPath(shape);
    p.setClipRect(QRectF(box.x(), box.y(), box.width() * frame.hold, box.height()), Qt::IntersectClip);
    p.fillRect(box, ACCENT);
    const QFont font = sora(14, QFont::DemiBold);
    const qreal done = frame.holdDone;
    const qreal base = p.opacity();
    p.setOpacity(base * (1 - done));         // le libellé monte en s'effaçant…
    drawIcon(p, icon, QPointF(box.x() + 16 + 10, box.center().y() - HOLD_SWAP_SHIFT * done), 20, INK_ON_ACCENT);
    drawText(p, QRectF(box.x() + 48, box.y() - HOLD_SWAP_SHIFT * done, box.width() - 56, box.height()),
             Qt::AlignLeft | Qt::AlignVCenter, label, font, INK_ON_ACCENT);
    if (done > 0) {                          // …la coche et le libellé de fin arrivent d'en dessous
        const qreal y = box.y() + HOLD_SWAP_SHIFT * (1 - done);
        p.setOpacity(base * done);
        drawCheck(p, QRectF(box.x() + 16, y + box.height() / 2 - HOLD_CHECK_SIZE / 2, HOLD_CHECK_SIZE, HOLD_CHECK_SIZE),
                  INK_ON_ACCENT, done);
        drawText(p, QRectF(box.x() + 16 + HOLD_CHECK_SIZE + HOLD_CHECK_GAP, y, box.width() - 50, box.height()),
                 Qt::AlignLeft | Qt::AlignVCenter, frame.doneLabel, font, INK_ON_ACCENT);
    }
    p.restore();
}

// Le sous-titre d'une tuile, qui glisse quand il change (SwapBox) : l'ancien monte en
// s'effaçant, le nouveau arrive d'en dessous.
void drawSub(QPainter& p, const QRectF& box, int align, const QString& text, const QString& from, qreal swap,
             const QFont& font, const QColor& color)
{
    if (swap >= 1 || from.isEmpty()) {
        drawText(p, box, align, text, font, color);
        return;
    }
    const qreal base = p.opacity();
    const qreal shift = 8;
    p.setOpacity(base * (1 - qMin<qreal>(1, swap / 0.45)));
    drawText(p, box.translated(0, -shift * ease(QEasingCurve::OutCubic, swap / 0.8)), align, from, font, color);
    p.setOpacity(base * qMin<qreal>(1, swap / 0.7));
    drawText(p, box.translated(0, shift * (1 - ease(QEasingCurve::OutQuint, swap))), align, text, font, color);
    p.setOpacity(base);
}

void drawTile(QPainter& p, const StreamPainter::Tile& tile, int index, const StreamPainter::Frame& frame, qreal width)
{
    const QRectF box = tileRect(tile.key, width);
    if (box.isEmpty()) {
        return;
    }
    const qreal focus = frame.tileFocus.value(index, index == frame.control.focus ? 1 : 0);
    // Entrée en cascade (au ressort), ou fermeture.
    const qreal t = frame.openMs - index * ENTRY_STAGGER;
    qreal opacity = qBound<qreal>(0, t / ENTRY_FADE, 1);
    qreal scale = ENTRY_FROM + (1 - ENTRY_FROM) * curveSpring(t / ENTRY_MOVE);
    if (frame.closing > 0) {
        opacity *= 1 - qMin<qreal>(1, frame.closing * CLOSE_MOVE / CLOSE_FADE);
        scale *= 1 - (1 - ENTRY_FROM) * curveMain(frame.closing);
    }
    scale *= 1 + (TILE_FOCUS_SCALE - 1) * focus;
    if (!tile.enabled) {
        opacity *= 0.4;
    }
    if (opacity <= 0) {
        return;
    }
    p.save();
    p.setOpacity(p.opacity() * opacity);
    p.translate(box.center());
    p.scale(scale, scale);
    p.translate(-box.center());

    const bool resume = tile.key == QLatin1String("resume");
    const bool slider = tile.value >= 0;
    // Anneau de focus (4 px, clair) autour de la tuile.
    if (focus > 0) {
        const qreal ring = TILE_RING_WIDTH;
        QColor color = TILE_RING;
        color.setAlphaF(color.alphaF() * focus);
        p.setPen(QPen(color, ring));
        p.setBrush(Qt::NoBrush);
        p.drawRoundedRect(box.adjusted(-ring / 2, -ring / 2, ring / 2, ring / 2), TILE_RADIUS + ring / 2, TILE_RADIUS + ring / 2);
    }
    p.setPen(resume ? Qt::NoPen : QPen(mix(TILE_EDGE, TILE_EDGE_FOCUS, focus), 1));
    p.setBrush(resume ? INK : TILE_FILL);
    p.drawRoundedRect(box.adjusted(0.5, 0.5, -0.5, -0.5), TILE_RADIUS, TILE_RADIUS);

    const QString swapFrom = index == frame.swapTile ? frame.swapFrom : QString();
    if (resume) {
        // Reprendre : rond noir et ▶, libellé en bas à gauche, glyphe A en bas à droite.
        const qreal pad = 22;
        p.setPen(Qt::NoPen);
        p.setBrush(Qt::black);
        p.drawEllipse(QRectF(box.x() + pad, box.y() + pad, 52, 52));
        drawIcon(p, QStringLiteral("game-play"), QPointF(box.x() + pad + 26, box.y() + pad + 26), 20, INK);
        drawText(p, QRectF(box.x() + pad, box.bottom() - pad - 18 - 2 - 36, box.width() - 2 * pad, 36),
                 Qt::AlignLeft | Qt::AlignVCenter, tile.label, sora(28, QFont::DemiBold, -0.84), Qt::black);
        drawText(p, QRectF(box.x() + pad, box.bottom() - pad - 18, box.width() - 2 * pad, 18),
                 Qt::AlignLeft | Qt::AlignVCenter, tile.sub, sora(13, QFont::Medium), RESUME_SUB);
        drawGlyph(p, QPointF(box.right() - pad - 26, box.bottom() - pad - 26), QStringLiteral("A"), frame.layout,
                  Qt::black, RESUME_GLYPH, 26, 12);
    }
    else if (slider) {
        // Curseur vertical : remplissage clair depuis le bas ; ce qu'il recouvre passe en sombre.
        QPainterPath shape;
        shape.addRoundedRect(box, TILE_RADIUS, TILE_RADIUS);
        const qreal fill = box.height() * qBound<qreal>(0, tile.value, 1);
        const QRectF filled(box.x(), box.bottom() - fill, box.width(), fill);
        p.save();
        p.setClipPath(shape);
        p.fillRect(filled, SLIDER_FILL);
        p.restore();
        const QString iconName = tile.key == QLatin1String("volume") ? QStringLiteral("game-speaker") : QStringLiteral("game-sun");
        for (int pass = 0; pass < 2; pass++) {
            p.save();
            if (pass == 1) {
                p.setClipRect(filled);
            }
            const bool dark = pass == 1;
            drawText(p, QRectF(box.x(), box.y() + 18, box.width(), 18), Qt::AlignHCenter | Qt::AlignVCenter,
                     tile.label, sora(13, QFont::DemiBold), dark ? INK_DARK : INK);
            drawSub(p, QRectF(box.x(), box.y() + 38, box.width(), 16), Qt::AlignHCenter | Qt::AlignVCenter,
                    tile.sub, swapFrom, frame.swapProgress, sora(12, QFont::Medium),
                    dark ? QColor(28, 28, 30, qRound(0.6 * 255)) : STATUS_INK);
            drawIcon(p, iconName, QPointF(box.center().x(), box.bottom() - 24 - 13), 26, dark ? INK_DARK : INK);
            p.restore();
        }
    }
    else if (box.height() > GRID_CELL) {
        // Tuile carrée : rond d'icône en haut, libellé et sous-titre en bas.
        const qreal pad = 20;
        p.setPen(Qt::NoPen);
        p.setBrush(TILE_ICON_FILL);
        p.drawEllipse(QRectF(box.x() + pad, box.y() + pad, 52, 52));
        drawIcon(p, tile.key == QLatin1String("shot") ? QStringLiteral("game-camera") : QStringLiteral("game-stats"),
                 QPointF(box.x() + pad + 26, box.y() + pad + 26), 22, INK);
        drawText(p, QRectF(box.x() + pad, box.bottom() - pad - 18 - 2 - 20, box.width() - 2 * pad, 20),
                 Qt::AlignLeft | Qt::AlignVCenter, tile.label, sora(15, QFont::DemiBold), INK);
        drawSub(p, QRectF(box.x() + pad, box.bottom() - pad - 18, box.width() - 2 * pad, 18),
                Qt::AlignLeft | Qt::AlignVCenter, tile.sub, swapFrom, frame.swapProgress, sora(13, QFont::Medium), SUB_INK);
    }
    else {
        // Tuile basse : icône et libellé (et, pour l'alimentation, ses choix en dessous).
        static const QHash<QString, QString> icons = { { "home", "game-home" }, { "quit", "game-quit" },
                                                       { "sleep", "game-moon" }, { "power", "game-power" } };
        const QString iconName = icons.value(tile.key);
        drawIcon(p, iconName, QPointF(box.x() + 16 + 10, box.center().y()), 20, INK);
        const qreal x = box.x() + 16 + 20 + 12;
        if (tile.sub.isEmpty()) {
            drawText(p, QRectF(x, box.y(), box.right() - x - 12, box.height()), Qt::AlignLeft | Qt::AlignVCenter,
                     tile.label, sora(14, QFont::DemiBold), INK);
        }
        else {
            const QFont font = sora(11, QFont::Medium);
            const QRectF textBox(x, 0, box.right() - x - 14, 1000);
            const QRectF sub = QFontMetricsF(font, p.device()).boundingRect(textBox, Qt::TextWordWrap, tile.sub);
            const qreal height = 18 + 1 + sub.height();
            const qreal top = box.center().y() - height / 2;
            drawText(p, QRectF(x, top, textBox.width(), 18), Qt::AlignLeft | Qt::AlignVCenter, tile.label,
                     sora(14, QFont::DemiBold), INK);
            p.setFont(font);
            p.setPen(QColor(245, 245, 247, qRound(0.6 * 255)));
            p.drawText(QRectF(x, top + 19, textBox.width(), sub.height() + 1), Qt::AlignLeft | Qt::TextWordWrap, tile.sub);
        }
        if (index == frame.control.focus && frame.hold > 0) {
            drawHold(p, box, iconName, tile.label, frame);
        }
    }
    p.restore();
}

void drawPower(QPainter& p, const StreamPainter::Frame& frame, qreal width)
{
    const qreal shown = frame.powerMix;
    if (shown <= 0) {
        return;
    }
    p.save();
    p.setOpacity(shown);
    p.resetTransform();
    p.fillRect(QRectF(0, 0, p.device()->width(), p.device()->height()), POWER_DIM);
    p.restore();

    const StreamPainter::Power& power = frame.power;
    const QRectF card = powerCard(width);
    p.save();
    p.setOpacity(shown);
    const qreal scale = POWER_FROM + (1 - POWER_FROM) * curveSpring(shown);
    p.translate(card.center());
    p.scale(scale, scale);
    p.translate(-card.center());
    p.setPen(QPen(QColor(255, 255, 255, qRound(0.1 * 255)), 1));
    p.setBrush(POWER_FILL);
    p.drawRoundedRect(card.adjusted(0.5, 0.5, -0.5, -0.5), POWER_RADIUS, POWER_RADIUS);
    drawText(p, QRectF(card.x(), card.y() + 36, card.width(), 17), Qt::AlignHCenter | Qt::AlignVCenter,
             power.header.toUpper(), sora(13, QFont::DemiBold, 0.78), INK3);
    static const QHash<QString, QString> icons = { { "suspend", "power-moon" }, { "reboot", "power-reboot" },
                                                   { "poweroff", "power-off" } };
    for (int i = 0; i < power.keys.size(); i++) {
        const QRectF item = powerItem(power, i, width);
        const qreal f = frame.powerFocus.value(i, i == power.focus ? 1 : 0);
        const QPointF center(item.center().x(), item.y() + POWER_DISC / 2);
        const qreal disc = POWER_DISC * (1 + (POWER_DISC_FOCUS - 1) * f);
        p.setPen(Qt::NoPen);
        p.setBrush(mix(POWER_DISC_FILL, INK, f));
        p.drawEllipse(center, disc / 2, disc / 2);
        drawIcon(p, icons.value(power.keys[i]), center, 30, mix(INK, Qt::black, f));
        drawText(p, QRectF(item.x() - 20, item.y() + POWER_DISC + 14, item.width() + 40, 20), Qt::AlignHCenter | Qt::AlignVCenter,
                 power.labels.value(i), sora(15, f > 0.5 ? QFont::DemiBold : QFont::Medium), mix(POWER_LABEL, INK, f));
    }
    drawText(p, QRectF(card.x(), card.bottom() - 28 - 18, card.width(), 18), Qt::AlignHCenter | Qt::AlignVCenter,
             power.note, sora(13, QFont::Medium), POWER_NOTE);
    p.restore();
}

}

void StreamPainter::setIconRoot(const QString& root)
{
    s_iconRoot = root.endsWith(QLatin1Char('/')) ? root : root + QLatin1Char('/');
}

int StreamPainter::tileAt(const Control& control, QSize screen, QPointF pos)
{
    if (screen.isEmpty()) {
        return -1;
    }
    const QPointF c = pos * (CANVAS_HEIGHT / screen.height());
    for (int i = 0; i < control.tiles.size(); i++) {
        if (tileRect(control.tiles[i].key, canvasWidth(screen)).contains(c)) {
            return i;
        }
    }
    return -1;
}

qreal StreamPainter::sliderAt(int tile, QSize screen, QPointF pos)
{
    if (screen.isEmpty() || tile < 0 || tile >= 9) {
        return -1;
    }
    const QRectF box = tileRect(QLatin1String(TILE_ORDER[tile]), canvasWidth(screen));
    const qreal y = pos.y() * CANVAS_HEIGHT / screen.height();
    return qBound<qreal>(0, (box.bottom() - y) / box.height(), 1);
}

int StreamPainter::powerAt(const Power& power, QSize screen, QPointF pos)
{
    if (screen.isEmpty()) {
        return -2;
    }
    const QPointF c = pos * (CANVAS_HEIGHT / screen.height());
    const qreal width = canvasWidth(screen);
    for (int i = 0; i < power.keys.size(); i++) {
        if (powerItem(power, i, width).contains(c)) {
            return i;
        }
    }
    return powerCard(width).contains(c) ? -1 : -2;
}

QImage StreamPainter::paintStats(const Stats& stats, qreal opacity, QSize screen,
                                 const Notice& notice, qreal noticeOpacity)
{
    const bool showStats = !stats.lines.isEmpty() && opacity > 0;
    const bool showNotice = !notice.text.isEmpty() && noticeOpacity > 0;
    if ((!showStats && !showNotice) || screen.isEmpty()) {
        return QImage();
    }
    const qreal scale = screen.height() / CANVAS_HEIGHT;
    QImage image = canvasImage(QSize(1, 1));
    const QSizeF size = showStats ? statsSize(stats, &image) : QSizeF();
    // L'avis est à droite : l'image prend alors toute la largeur (une bande, en haut).
    const qreal width = showNotice ? screen.width() / scale : STATS_MARGIN + size.width();
    const qreal height = qMax(showStats ? STATS_MARGIN + size.height() : 0.0,
                              showNotice ? STATS_MARGIN + NOTICE_HEIGHT : 0.0);
    image = canvasImage(QSize(qCeil(width * scale), qCeil(height * scale)));
    image.fill(Qt::transparent);
    QPainter p(&image);
    beginCanvas(p, screen);
    if (showStats) {
        drawStats(p, stats, opacity);
    }
    if (showNotice) {
        const QFont font = sora(NOTICE_SIZE, QFont::Medium);
        const qreal textWidth = QFontMetricsF(font, p.device()).horizontalAdvance(notice.text);
        const qreal pill = NOTICE_PAD_X + HOST_DOT_SIZE + HOST_DOT_GAP + textWidth + NOTICE_PAD_X;
        const QRectF box(width - STATS_MARGIN - pill, STATS_MARGIN - NOTICE_SHIFT * (1 - noticeOpacity),
                         pill, NOTICE_HEIGHT);
        p.setOpacity(noticeOpacity);
        p.setPen(Qt::NoPen);
        p.setBrush(STATS_FILL);
        p.drawRoundedRect(box, NOTICE_HEIGHT / 2, NOTICE_HEIGHT / 2);
        p.setBrush(notice.tone == Notice::Good ? OK : notice.tone == Notice::Warn ? ACCENT : POOR);
        p.drawEllipse(QRectF(box.x() + NOTICE_PAD_X, box.center().y() - HOST_DOT_SIZE / 2, HOST_DOT_SIZE, HOST_DOT_SIZE));
        p.setFont(font);
        p.setPen(INK);
        p.drawText(QRectF(box.x() + NOTICE_PAD_X + HOST_DOT_SIZE + HOST_DOT_GAP, box.y(), textWidth + 1, box.height()),
                   Qt::AlignLeft | Qt::AlignVCenter, notice.text);
    }
    return image;
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
    s_pixelScale = screen.height() / CANVAS_HEIGHT;

    // --- Centre de contrôle ---
    const qreal width = canvasWidth(screen);
    const qreal headerT = frame.openMs - HEADER_DELAY;
    qreal headerOpacity = qBound<qreal>(0, headerT / ENTRY_FADE, 1);
    qreal headerShift = -HEADER_SHIFT * (1 - curveMain(headerT / HEADER_MOVE));
    if (frame.closing > 0) {
        headerOpacity *= 1 - qMin<qreal>(1, frame.closing * CLOSE_MOVE / 200);
        headerShift = -HEADER_SHIFT * frame.closing;
    }
    // Les statistiques s'effacent derrière le centre de contrôle, et reviennent à sa fermeture.
    drawStats(p, frame.stats, frame.statsOpacity * (1 - headerOpacity));
    // Sous la carte d'alimentation, le centre de contrôle s'estompe (la maquette le floute).
    p.setOpacity(1 - POWER_RECEDE * frame.powerMix);
    drawHeader(p, frame.control, width, headerOpacity, headerShift);
    for (int i = 0; i < frame.control.tiles.size(); i++) {
        drawTile(p, frame.control.tiles[i], i, frame, width);
    }
    p.setOpacity(1);
    const qreal legendOpacity = headerOpacity * (1 - frame.powerMix);
    if (legendOpacity > 0) {
        p.setOpacity(legendOpacity);
        drawLegend(p, { { QStringLiteral("B"), QCoreApplication::translate("StreamMenu", "Reprendre") },
                        { QStringLiteral("A"), frame.control.activateLabel },
                        { QString(QChar(0x25B2)) + QChar(0x25BC), QCoreApplication::translate("StreamMenu", "Régler") } },
                   width, LEGEND_TOP, frame.layout);
        p.setOpacity(1);
    }

    // --- Menu d'alimentation ---
    drawPower(p, frame, width);
    if (frame.powerMix > 0) {
        p.setOpacity(frame.powerMix);
        drawLegend(p, { { QString(QChar(0x25C0)) + QChar(0x25B6), QCoreApplication::translate("StreamMenu", "Choisir") },
                        { QStringLiteral("A"), QCoreApplication::translate("StreamMenu", "Confirmer") },
                        { QStringLiteral("B"), QCoreApplication::translate("StreamMenu", "Annuler") } },
                   width, CANVAS_HEIGHT - LEGEND_BOTTOM - GLYPH_SIZE, frame.layout, 26);
        p.setOpacity(1);
    }

    if (frame.curtain > 0) {
        p.resetTransform();
        p.fillRect(image.rect(), QColor(0, 0, 0, qRound(255 * frame.curtain)));
    }
    return solid;
}
