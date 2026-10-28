#!/usr/bin/env python3
"""Convertit un artboard .dc.html (canevas de design) en page HTML autonome et VIVANTE.

Différence avec la version de l'écran de veille : la page fait tourner le cycle de vie
complet (componentDidMount, setInterval, setState) et met à jour le DOM par différence
(morphdom), donc les transitions CSS jouent comme dans le canevas. <sc-for> et <sc-if>
sont pris en charge.

Paramètres d'URL :
  ?now=2026-10-28T21:42:00   horloge figée pour les heures affichées (n'affecte pas les timers)
  ?accent=%23F2802A          surcharge d'une prop (toute prop de data-props)

Usage : python3 dc_to_standalone.py source.dc.html sortie.html
"""
import html
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MORPHDOM = open(os.path.join(HERE, "morphdom-umd.min.js"), encoding="utf-8").read()

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
    const real = Date.now.bind(Date), t0 = real();
    // fixed wall clock that still advances, so timers keep working
    Date.now = () => fixed + (real() - t0);
  }
  window.DCLogic = class {
    constructor(props){ this.props = props; this.state = null; }
    setState(s){ this.state = Object.assign({}, this.state, typeof s === 'function' ? s(this.state) : s); window.__dcRender && window.__dcRender(); }
    forceUpdate(){ window.__dcRender && window.__dcRender(); }
  };
})();
"""

BOOT = r"""
(function(){
  const P = new URLSearchParams(location.search);
  const props = {};
  for (const [k, spec] of Object.entries(PROPS)) {
    if (k.startsWith('$')) continue;
    let v = spec.default;
    if (P.has(k)) { const raw = P.get(k); v = typeof v === 'number' ? Number(raw) : typeof v === 'boolean' ? raw === 'true' : raw; }
    props[k] = v;
  }
  const tplNode = document.getElementById('tpl').content;
  const lookup = (scope, path) => {
    path = path.trim();
    if (path === 'true') return true; if (path === 'false') return false;
    if (/^-?\d+(\.\d+)?$/.test(path)) return Number(path);
    return path.split('.').reduce((o, k) => (o == null ? o : o[k]), scope);
  };
  const HOLE = /\{\{\s*([\w.$]+)\s*\}\}/g;
  const whole = /^\s*\{\{\s*([\w.$]+)\s*\}\}\s*$/;
  const interp = (s, scope) => s.replace(HOLE, (m, p) => { const v = lookup(scope, p); return v == null ? '' : String(v); });
  function renderNodes(nodes, scope, out) {
    for (const n of nodes) {
      if (n.nodeType === 3) { out.appendChild(document.createTextNode(interp(n.nodeValue, scope))); continue; }
      if (n.nodeType !== 1) continue;
      const tag = n.tagName.toLowerCase();
      if (tag === 'sc-for') {
        const m = whole.exec(n.getAttribute('list') || ''); const list = m ? lookup(scope, m[1]) : [];
        const as = n.getAttribute('as') || 'item';
        (list || []).forEach((it, i) => renderNodes(n.childNodes, Object.assign(Object.create(scope), { [as]: it, $index: i }), out));
        continue;
      }
      if (tag === 'sc-if') {
        const m = whole.exec(n.getAttribute('value') || ''); if (m && lookup(scope, m[1])) renderNodes(n.childNodes, scope, out);
        continue;
      }
      const el = n.namespaceURI === 'http://www.w3.org/2000/svg' ? document.createElementNS(n.namespaceURI, n.tagName) : document.createElement(n.tagName);
      for (const a of n.attributes) {
        if (/^on[A-Z]/.test(a.name) || /^on[a-z]+$/.test(a.name)) continue;
        el.setAttribute(a.name, interp(a.value, scope));
      }
      renderNodes(n.childNodes, scope, el);
      out.appendChild(el);
    }
  }
  const comp = new Component(props);
  const root = document.getElementById('root');
  let pending = false;
  function render() {
    const vals = comp.renderVals();
    const frag = document.createElement('div'); frag.id = 'root';
    renderNodes(tplNode.childNodes, vals, frag);
    morphdom(root, frag);
  }
  window.__dcRender = () => { if (pending) return; pending = true; requestAnimationFrame(() => { pending = false; render(); }); };
  render();
  if (comp.componentDidMount) comp.componentDidMount();
  document.fonts.ready.then(() => { window.__ready = true; });
})();
"""


def convert(src_path, out_path):
    src = open(src_path, encoding="utf-8").read()
    title = re.search(r"<title>(.*?)</title>", src, re.S).group(1)
    helmet = re.search(r"<helmet>(.*?)</helmet>", src, re.S).group(1)
    helmet = re.sub(r'<link[^>]+fonts\.googleapis\.com[^>]*>', "", helmet)
    xdc = re.search(r"<x-dc>(.*?)</x-dc>", src, re.S).group(1)
    markup = re.sub(r"<helmet>.*?</helmet>", "", xdc, flags=re.S).strip()
    # the canvas-only sound button is not part of the product UI
    markup = re.sub(r'<button type="button" aria-label="\{\{sndLabel\}\}".*?</button>\n?', "", markup, flags=re.S)
    m = re.search(r"<script type=\"text/x-dc\"[^>]*data-props='(.*?)'>(.*?)</script>", src, re.S)
    props = json.loads(html.unescape(m.group(1)))
    logic = m.group(2)
    pv = props.get("$preview", {"width": 1280, "height": 800})
    out = f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width={pv['width']}">
<title>{title}</title>
<style>{FONT_CSS}
html,body{{margin:0;background:#000}}
#root{{width:{pv['width']}px;height:{pv['height']}px;overflow:hidden;position:relative}}
</style>
{helmet.strip()}
</head>
<body>
<div id="root"></div>
<template id="tpl">
{markup}
</template>
<script>{MORPHDOM}</script>
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
    return pv


if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2])
