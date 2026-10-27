#!/usr/bin/env python3
"""Compare la boîte de chaque texte de la veille (ligne IDLE_LAYOUT du journal d'IdlePreview)
à celle mesurée sur la maquette (docs/design/idle/reference/layout/<écran>.json).

Usage : layout_check.py <journal> <layout.json>
Critère du brief (phase 4) : position à ±2 px, même taille, même graisse. On compare x et y
(la largeur d'un texte en bloc vaut celle de la colonne dans la maquette, pas celle du texte).
Code de sortie 1 si un texte est hors tolérance ou absent.
"""
import json
import sys

TOLERANCE = 2.0
WEIGHTS = {400: 400, 500: 500, 600: 600, 700: 700, 57: 500, 63: 600, 75: 700, 50: 400}   # Font.Weight Qt 6 = CSS


def norm(text):
    return " ".join(text.replace(" ", " ").split())


log_path, layout_path = sys.argv[1], sys.argv[2]
ours = None
for line in open(log_path, encoding="utf-8"):
    if "IDLE_LAYOUT " in line:
        ours = json.loads(line.split("IDLE_LAYOUT ", 1)[1])
if ours is None:
    sys.exit("pas de ligne IDLE_LAYOUT dans le journal")

ref = [e for e in json.load(open(layout_path, encoding="utf-8")) if "text" in e]
by_text = {}
for e in ours:
    by_text.setdefault(norm(e["text"]), []).append(e)

failed = 0
for r in ref:
    t = norm(r["text"])
    candidates = by_text.get(t, [])
    if not candidates:
        print(f"  ABSENT  {t!r}")
        failed += 1
        continue
    o = min(candidates, key=lambda e: abs(e["x"] - r["x"]) + abs(e["y"] - r["y"]))
    dx, dy = o["x"] - r["x"], o["y"] - r["y"]
    # Texte centré dans un bloc plus large (libellé de la jaquette) : on compare les centres.
    centered = r["w"] - o["w"] > 2 * TOLERANCE and abs(dx) > TOLERANCE
    if centered:
        dx = (o["x"] + o["w"] / 2) - (r["x"] + r["w"] / 2)
    size_ok = abs(o["size"] - float(r["fontSize"].rstrip("px"))) < 0.01
    weight_ok = WEIGHTS.get(o["weight"], o["weight"]) == int(r["fontWeight"])
    ok = abs(dx) <= TOLERANCE and abs(dy) <= TOLERANCE and size_ok and weight_ok
    failed += not ok
    print(f"  {'ok  ' if ok else 'ÉCART'}  {t[:34]!r:38} dx {dx:+6.1f}  dy {dy:+6.1f}"
          + ("" if size_ok else f"  taille {o['size']} ≠ {r['fontSize']}")
          + ("" if weight_ok else f"  graisse {o['weight']} ≠ {r['fontWeight']}"))
print(f"{len(ref) - failed}/{len(ref)} textes dans la tolérance")
sys.exit(1 if failed else 0)
