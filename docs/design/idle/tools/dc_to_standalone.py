#!/usr/bin/env python3
"""Convertit un artboard .dc.html (format du canvas de design) en page HTML autonome.

La page générée n'a besoin d'aucun runtime : elle évalue renderVals() une fois,
remplit les {{trous}} du template et laisse tourner les animations CSS.

Paramètres d'URL reconnus par la page générée :
  ?now=2026-10-27T21:46:00   horloge figée (heure, date, timers déterministes)
  ?at=3.0                    met en pause toutes les animations à t = 3,0 s
  ?accent=%23F2802A          surcharge d'une prop (n'importe quelle prop data-props)

Usage : python3 dc_to_standalone.py source.dc.html sortie.html
"""
import html
import json
import re
import sys

FONT_CSS = """
@font-face{font-family:'Sora';font-style:normal;font-weight:100 800;font-display:block;
  src:url(fonts/sora-latin-wght-normal.woff2) format('woff2');
  unicode-range:U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD;}
@font-face{font-family:'Sora';font-style:normal;font-weight:100 800;font-display:block;
  src:url(fonts/sora-latin-ext-wght-normal.woff2) format('woff2');
  unicode-range:U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF;}
"""

RUNTIME = r"""
(function(){
  const P = new URLSearchParams(location.search);
  if (P.get('now')) {
    const fixed = Date.parse(P.get('now'));
    Date.now = () => fixed;
  }
  window.DCLogic = class { constructor(props){ this.props = props; this.state = null; }
    setState(s){ this.state = Object.assign({}, this.state, s); } forceUpdate(){} };
})();
"""

BOOT = r"""
(function(){
  const P = new URLSearchParams(location.search);
  const props = {};
  for (const [k, spec] of Object.entries(PROPS)) {
    if (k.startsWith('$')) continue;
    let v = spec.default;
    if (P.has(k)) {
      const raw = P.get(k);
      v = typeof v === 'number' ? Number(raw) : typeof v === 'boolean' ? raw === 'true' : raw;
    }
    props[k] = v;
  }
  const comp = new Component(props);
  const vals = comp.renderVals();
  const get = (path) => path.split('.').reduce((o, k) => (o == null ? o : o[k]), vals);
  const tpl = document.getElementById('tpl').innerHTML;
  document.getElementById('root').innerHTML =
    tpl.replace(/\{\{\s*([\w.$]+)\s*\}\}/g, (m, p) => { const v = get(p); return v == null ? '' : String(v); });
  const at = P.get('at');
  document.fonts.ready.then(() => {
    if (at !== null) {
      document.getAnimations().forEach(a => { a.pause(); a.currentTime = Number(at) * 1000; });
    }
    window.__ready = true;
  });
})();
"""


def convert(src_path, out_path):
    src = open(src_path, encoding="utf-8").read()
    title = re.search(r"<title>(.*?)</title>", src, re.S).group(1)
    helmet = re.search(r"<helmet>(.*?)</helmet>", src, re.S).group(1)
    helmet = re.sub(r'<link[^>]+fonts\.googleapis\.com[^>]*>', "", helmet)
    xdc = re.search(r"<x-dc>(.*?)</x-dc>", src, re.S).group(1)
    markup = re.sub(r"<helmet>.*?</helmet>", "", xdc, flags=re.S).strip()
    m = re.search(r"<script type=\"text/x-dc\"[^>]*data-props='(.*?)'>(.*?)</script>", src, re.S)
    props = json.loads(html.unescape(m.group(1)))
    logic = m.group(2)

    out = f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=1280">
<title>{title}</title>
<style>{FONT_CSS}
html,body{{margin:0;background:#000}}
#root{{width:1280px;height:720px;overflow:hidden}}
</style>
{helmet.strip()}
</head>
<body>
<div id="root"></div>
<template id="tpl">
{markup}
</template>
<script>{RUNTIME}</script>
<script>
const PROPS = {json.dumps(props, ensure_ascii=False)};
{logic.strip()}
</script>
<script>{BOOT}</script>
</body>
</html>
"""
    open(out_path, "w", encoding="utf-8").write(out)


if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2])
