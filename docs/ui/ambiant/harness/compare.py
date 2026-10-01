#!/usr/bin/env python3
"""Compare une capture QML à une capture de référence du prototype.

    ./compare.py capture.png ../ref/home-0-minecraft.png [x,y,l,h ...] [-o diff.png]

Pour chaque zone (toute l'image par défaut) : écart moyen par canal (0-255) et
part des pixels qui diffèrent de plus de 24 niveaux. Avec -o, écrit une image
« capture | référence | écart ×4 » pour repérer où ça diverge.
"""
import sys

from PIL import Image, ImageChops

args = sys.argv[1:]
out = None
if "-o" in args:
    i = args.index("-o")
    out = args[i + 1]
    del args[i:i + 2]
shot, ref = (Image.open(p).convert("RGB") for p in args[:2])
if shot.size != ref.size:
    sys.exit(f"tailles différentes : {shot.size} contre {ref.size}")
boxes = [tuple(int(v) for v in a.split(",")) for a in args[2:]] or [(0, 0, *shot.size)]

diff = ImageChops.difference(shot, ref)
for x, y, w, h in boxes:
    px = list(diff.crop((x, y, x + w, y + h)).getdata())
    mean = sum(sum(p) for p in px) / (3 * len(px))
    far = sum(1 for p in px if max(p) > 24) / len(px)
    print(f"zone {x},{y} {w}×{h} : écart moyen {mean:.2f}, pixels à plus de 24 niveaux {far:.1%}")

if out:
    w, h = shot.size
    sheet = Image.new("RGB", (w * 3, h))
    sheet.paste(shot, (0, 0))
    sheet.paste(ref, (w, 0))
    sheet.paste(diff.point(lambda v: min(255, v * 4)), (w * 2, 0))
    sheet.save(out)
