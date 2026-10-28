#!/usr/bin/env python3
"""Jaquettes (600 × 848) et fonds (1280 × 720) de remplacement des jeux de
../mock/library.mock.json, en dégradés abstraits comme dans les maquettes (pas d'image
sous droits). Un jeu sans jaquette dans le mock (« cover »: null, Factorio) n'en a pas
ici non plus : c'est le cas « jaquette composée ».

    ./make-art.py        # écrit art/<id>-cover.png et art/<id>-bg.png
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
OUT = HERE / "art"


def rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) for i in (1, 3, 5))


def blobs(size, accent, seed):
    """Fond très sombre et trois taches floues : la teinte du jeu et deux voisines."""
    w, h = size
    img = Image.new("RGB", size, (14, 14, 18))
    draw = ImageDraw.Draw(img)
    r, g, b = accent
    tints = [(r, g, b), (b, r, g), (g // 2, b // 2, r)]
    for i, tint in enumerate(tints):
        x = (seed[i] / 255) * w
        y = (seed[i + 3] / 255) * h
        radius = (0.25 + seed[i + 6] / 255 * 0.25) * max(w, h)
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=tuple(int(c * 0.7) for c in tint))
    return img.filter(ImageFilter.GaussianBlur(max(w, h) / 9))


def main():
    games = json.loads((HERE.parent / "mock" / "library.mock.json").read_text())["games"]
    OUT.mkdir(exist_ok=True)
    for game in games:
        seed = hashlib.sha1(game["title"].encode()).digest()
        accent = rgb(game["accent"]) if game.get("accent") else (seed[10], seed[11], seed[12])
        if "cover" not in game:
            blobs((600, 848), accent, seed).save(OUT / f"{game['id']}-cover.png", optimize=True)
        if "background" not in game:
            blobs((1280, 720), accent, seed[1:]).save(OUT / f"{game['id']}-bg.png", optimize=True)


if __name__ == "__main__":
    main()
