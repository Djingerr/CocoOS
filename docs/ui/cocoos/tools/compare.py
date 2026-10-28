#!/usr/bin/env python3
"""Compare une capture QML à la capture de référence et produit une carte des écarts.

Usage : python3 tools/compare.py reference/png/09_jeu_final.png captures/09_jeu.png [diff.png]

Affiche :
  - l'écart moyen absolu en luminance (0-255) sur l'image entière ;
  - le même écart par zone d'une grille 8x4 (repère les régions qui dérivent) ;
et écrit une carte de chaleur (rouge = écart fort) superposée à la référence.

Le grain et le flou font varier quelques pixels d'un moteur à l'autre : ce qui compte,
ce sont les zones à fort écart (élément décalé, mauvaise taille, mauvaise couleur).
"""
import sys

import numpy as np
from PIL import Image

ref_path, cap_path = sys.argv[1], sys.argv[2]
out_path = sys.argv[3] if len(sys.argv) > 3 else cap_path.rsplit(".", 1)[0] + "_diff.png"

ref = Image.open(ref_path).convert("RGB")
cap = Image.open(cap_path).convert("RGB")
if cap.size != ref.size:
    print(f"Attention : taille capture {cap.size} ≠ référence {ref.size}, redimensionnement.")
    cap = cap.resize(ref.size, Image.LANCZOS)

a = np.asarray(ref.convert("L"), dtype=np.float32)
b = np.asarray(cap.convert("L"), dtype=np.float32)
d = np.abs(a - b)
print(f"Écart moyen global : {d.mean():.2f} / 255")

h, w = d.shape
rows, cols = 4, 8
print("Écart moyen par zone (ligne = bande horizontale, de haut en bas) :")
for r in range(rows):
    cells = []
    for c in range(cols):
        z = d[r * h // rows:(r + 1) * h // rows, c * w // cols:(c + 1) * w // cols]
        cells.append(f"{z.mean():5.1f}")
    print("  " + " ".join(cells))

heat = np.clip(d * 3, 0, 255).astype(np.uint8)
overlay = np.asarray(ref, dtype=np.float32) * 0.45
overlay[..., 0] = np.clip(overlay[..., 0] + heat, 0, 255)
Image.fromarray(overlay.astype(np.uint8)).save(out_path)
print(f"Carte des écarts : {out_path}")
