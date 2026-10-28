#!/usr/bin/env python3
"""Ombres portées de l'interface, pré-calculées (aucun flou à l'exécution : la Mali
n'a qu'à poser une image). Relancer si une taille ou une ombre change dans Theme.qml :

    ./make-shadows.py

Chaque ombre suit le box-shadow du prototype des micro-interactions (décalage, flou,
étalement, opacité) sur la forme qu'elle accompagne, et déborde de `pad` px de chaque
côté de cette forme (jetons Theme.*ShadowPad). Rendu à SCALE fois la taille du canevas.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[3] / "app" / "gui" / "console" / "shadows"
SCALE = 2

# nom : (largeur, hauteur, rayon, décalage y, flou, étalement, opacité, pad)
SHADOWS = {
    # Vignette de l'étagère (Theme.shelfThumbSize, shelfThumbRadius) : 0 18px 40px -12px, 90 %.
    "thumb": (108, 144, 10, 18, 40, -12, 0.90, 78),
    # Île de notification (Theme.islandSize, islandRadius) : 0 14px 34px -8px, 80 %.
    "island": (340, 72, 28, 14, 34, -8, 0.80, 65),
    # Jaquettes du carrousel CocoOS (Theme.coverSlots, radiusCover) : la centrale
    # 0 40px 90px, 60 % ; les latérales 0 20px 40px, 50 % (AccueilCarrousel).
    "cover": (240, 340, 12, 40, 90, 0, 0.60, 150),
    "coverSide": (190, 269, 12, 20, 40, 0, 0.50, 70),
}


def shadow(w, h, radius, dy, blur, spread, alpha, pad):
    size = ((w + 2 * pad) * SCALE, (h + 2 * pad) * SCALE)
    mask = Image.new("L", size, 0)
    left, top = pad - spread, pad - spread + dy
    box = [left * SCALE, top * SCALE, (left + w + 2 * spread) * SCALE, (top + h + 2 * spread) * SCALE]
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=max(0, radius + spread) * SCALE, fill=round(255 * alpha))
    # Flou CSS de rayon `blur` : une gaussienne d'écart type blur / 2.
    mask = mask.filter(ImageFilter.GaussianBlur(blur / 2 * SCALE))
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    image.putalpha(mask)
    return image


OUT.mkdir(exist_ok=True)
for name, spec in SHADOWS.items():
    path = OUT / f"{name}.png"
    shadow(*spec).save(path, optimize=True)
    print(path.relative_to(HERE.parents[3]), shadow(*spec).size)
