#!/usr/bin/env python3
"""Jaquettes (600 × 848) et fonds (1480 × 1000 : l'écran et son débord de 100 px) des jeux
de ../mock/library.mock.json, rendus d'après les dégradés `ART` des maquettes
(../reference/dc-source/MotionNavigation.dc.html) : les captures du harnais se comparent
alors aux références. Un jeu absent de `ART` (Zelda) prend un dégradé tiré de sa teinte ;
un jeu sans jaquette dans le mock (« cover »: null, Factorio) n'en a pas non plus ici.

    ./make-art.py        # écrit art/<id>-cover.png et art/<id>-bg.png
"""
import hashlib
import json
import math
import re
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE / "art"
SOURCE = HERE.parent / "reference" / "dc-source" / "MotionNavigation.dc.html"


def rgb(hex_color):
    return np.array([int(hex_color[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)


def render(css, w, h):
    """radial-gradient(circle at X% Y%, #C 0%, transparent R%), …, linear-gradient(Adeg, #A 0%, #B 100%)."""
    ys, xs = np.mgrid[0:h, 0:w].astype(float) + 0.5
    layers = re.findall(r"(radial|linear)-gradient\(([^()]*)\)", css)
    out = np.zeros((h, w, 3))
    for kind, args in reversed(layers):           # le premier dégradé listé est au-dessus
        if kind == "linear":
            angle, a, b = re.match(r"(\d+)deg, (#\w+) 0%, (#\w+) 100%", args).groups()
            t = math.radians(float(angle))
            d = np.array([math.sin(t), -math.cos(t)])
            length = abs(w * d[0]) + abs(h * d[1])
            pos = ((xs - w / 2) * d[0] + (ys - h / 2) * d[1]) / length + 0.5
            pos = np.clip(pos, 0, 1)[..., None]
            out = rgb(a) * (1 - pos) + rgb(b) * pos
        else:
            x, y, color, stop = re.match(r"circle at (\d+)% (\d+)%, (#\w+) 0%, transparent (\d+)%", args).groups()
            cx, cy = w * float(x) / 100, h * float(y) / 100
            far = max(math.hypot(cx - px, cy - py) for px in (0, w) for py in (0, h))
            alpha = np.clip(1 - np.hypot(xs - cx, ys - cy) / (far * float(stop) / 100), 0, 1)[..., None]
            out = rgb(color) * alpha + out * (1 - alpha)
    return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8))


def fallback(accent):
    """Dégradé dans l'esprit des maquettes pour un jeu qu'elles ne dessinent pas."""
    r, g, b = (int(accent[i:i + 2], 16) for i in (1, 3, 5))
    dark = "#%02X%02X%02X" % (r // 5, g // 5, b // 5)
    deep = "#%02X%02X%02X" % (r // 14, g // 14, b // 14)
    return (f"radial-gradient(circle at 40% 30%, {accent} 0%, transparent 42%), "
            f"linear-gradient(160deg, {dark} 0%, {deep} 100%)")


def main():
    art = dict(re.findall(r"(\w+): '((?:radial|linear)[^']*)'", SOURCE.read_text()))
    games = json.loads((HERE.parent / "mock" / "library.mock.json").read_text())["games"]
    OUT.mkdir(exist_ok=True)
    for game in games:
        accent = game.get("accent") or "#" + hashlib.sha1(game["title"].encode()).hexdigest()[:6]
        css = art.get(game["id"]) or fallback(accent)
        if "cover" not in game:
            render(css, 600, 848).save(OUT / f"{game['id']}-cover.png", optimize=True)
        if "background" not in game:
            render(css, 1480, 1000).save(OUT / f"{game['id']}-bg.png", optimize=True)


if __name__ == "__main__":
    main()
