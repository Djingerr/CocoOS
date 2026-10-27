#!/usr/bin/env python3
"""Capture les rendus de référence (PNG 1280x720) des pages HTML autonomes.

Usage : python3 tools/capture_reference.py [dossier_html] [dossier_png]
Par défaut : reference/html -> reference/png

Pour chaque écran, capture l'état final (t = 3,0 s, entrée terminée) et une image
au milieu de l'animation d'entrée (t = 0,45 s), avec une horloge figée.
Nécessite : pip install playwright && python3 -m playwright install chromium
"""
import pathlib
import sys

from playwright.sync_api import sync_playwright

NOW = "2026-10-27T21:46:00"
FRAMES = {"final": 3.0, "entree": 0.45}

src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "reference/html").resolve()
dst = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "reference/png").resolve()
dst.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1280, "height": 720})
    for html in sorted(src.glob("*.html")):
        for label, t in FRAMES.items():
            page.goto(f"{html.as_uri()}?now={NOW}&at={t}")
            page.wait_for_function("window.__ready === true")
            page.wait_for_timeout(150)
            out = dst / f"{html.stem}_{label}.png"
            page.screenshot(path=str(out), clip={"x": 0, "y": 0, "width": 1280, "height": 720})
            print(out.relative_to(dst.parent))
    browser.close()
