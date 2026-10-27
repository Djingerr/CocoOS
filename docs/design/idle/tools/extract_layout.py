#!/usr/bin/env python3
"""Extrait la géométrie et les styles calculés de chaque élément visible des pages de référence.

Sortie : reference/layout/<écran>.json — une entrée par élément visible :
  {"tag", "text", "x", "y", "w", "h", "fontSize", "fontWeight", "letterSpacing",
   "lineHeight", "color", "opacity", "radius", "background", "border", "shadow"}
Mesuré à t = 3,0 s (entrée terminée), dérive anti-marquage désactivée, horloge figée.
Les rectangles incluent les transformations en cours (inclinaison de la jaquette à t = 3 s).

Usage : python3 tools/extract_layout.py
"""
import json
import pathlib

from playwright.sync_api import sync_playwright

NOW = "2026-10-27T21:46:00"
SRC = pathlib.Path("reference/html").resolve()
DST = pathlib.Path("reference/layout").resolve()
DST.mkdir(parents=True, exist_ok=True)

JS = r"""
() => {
  const out = [];
  const root = document.getElementById('root');
  for (const el of root.querySelectorAll('*')) {
    const r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) continue;
    if (el.closest('svg') && el.tagName.toLowerCase() !== 'svg') continue;
    const cs = getComputedStyle(el);
    let text = '';
    for (const n of el.childNodes) if (n.nodeType === 3) text += n.textContent;
    text = text.replace(/\s+/g, ' ').trim();
    const e = { tag: el.tagName.toLowerCase(), x: +r.x.toFixed(1), y: +r.y.toFixed(1),
                w: +r.width.toFixed(1), h: +r.height.toFixed(1) };
    if (text) Object.assign(e, { text, fontSize: cs.fontSize, fontWeight: cs.fontWeight,
      letterSpacing: cs.letterSpacing, lineHeight: cs.lineHeight, color: cs.color });
    if (cs.opacity !== '1') e.opacity = cs.opacity;
    if (cs.borderRadius !== '0px') e.radius = cs.borderRadius;
    if (cs.backgroundColor !== 'rgba(0, 0, 0, 0)') e.background = cs.backgroundColor;
    if (cs.backgroundImage !== 'none') e.backgroundImage = cs.backgroundImage.slice(0, 160);
    if (cs.borderTopWidth !== '0px') e.border = cs.borderTopWidth + ' ' + cs.borderTopColor;
    if (cs.boxShadow !== 'none') e.shadow = cs.boxShadow;
    if (cs.filter !== 'none') e.filter = cs.filter;
    if (el.getAttribute('aria-hidden') === 'true') e.decorative = true;
    out.push(e);
  }
  return out;
}
"""

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1280, "height": 720})
    for html in sorted(SRC.glob("*.html")):
        page.goto(f"{html.as_uri()}?now={NOW}&at=3&drift=false")
        page.wait_for_function("window.__ready === true")
        data = page.evaluate(JS)
        out = DST / f"{html.stem}.json"
        out.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
        print(out.relative_to(DST.parent), len(data), "éléments")
    browser.close()
