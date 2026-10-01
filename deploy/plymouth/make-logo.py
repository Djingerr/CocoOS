#!/usr/bin/env python3
"""Dessine cocoos/logo.png, le mot-symbole « CocoOS » du thème Plymouth.

Même dessin que BootSplash.qml : Sora 600, « Coco » en encre, « OS » en accent,
sur fond transparent. Relancer après un changement de police ou de couleur :

    ./make-logo.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FONT = HERE.parents[1] / "app/gui/console/fonts/Sora-SemiBold.ttf"
INK = (0xF2, 0xF0, 0xEC, 255)       # Theme.ink
ACCENT = (0xF2, 0x80, 0x2A, 255)    # Theme.accent
SIZE = 96                           # px : un logo d'environ 400 px de large
SPACING = -2.7                      # Theme.splashSpacing, à cette taille


def main():
    font = ImageFont.truetype(str(FONT), SIZE)
    parts = [("Coco", INK), ("OS", ACCENT)]
    # Largeur : chaque lettre, plus l'espacement (négatif) entre elles.
    letters = [(c, color) for text, color in parts for c in text]
    width = sum(font.getlength(c) for c, _ in letters) + SPACING * (len(letters) - 1)
    ascent, descent = font.getmetrics()
    image = Image.new("RGBA", (int(width) + 8, ascent + descent + 8), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    x = 4.0
    for c, color in letters:
        draw.text((x, 4), c, font=font, fill=color)
        x += font.getlength(c) + SPACING
    image.save(HERE / "cocoos/logo.png")
    print(f"cocoos/logo.png : {image.width} × {image.height}")


if __name__ == "__main__":
    main()
