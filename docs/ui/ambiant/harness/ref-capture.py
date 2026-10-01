#!/usr/bin/env python3
"""Captures de référence du prototype (version n° 2 « Ambiant ») avec Brave headless.

    ./ref-capture.py    -> ../ref/home-<i>-<id>.png  (1280×800, un par jeu)
                           ../ref/<scène>.png        (options, lancement : cf. SCENES)
                           art/<id>.jpg              (illustrations de démo, 1600×1000)

Brave est piloté par le protocole DevTools (son option --screenshot ne rend
jamais la main). Le prototype n'est PAS modifié : on choisit la version et le
jeu via son localStorage, et on fige ce qui n'est pas comparable image par image :
  - grain coupé (désactivé par défaut côté QML, cf. brief §3) ;
  - dérive du fond figée à son point de départ (scale 1.03) ;
  - horloge forcée à 21:30 ; hôte connecté, 9 ms (Math.random figé).

Dépendances : brave-browser (ou $BRAVE), module Python « websockets ».
"""
import asyncio
import base64
import json
import os
import signal
import subprocess
import tempfile
import time
from pathlib import Path

import websockets

HERE = Path(__file__).resolve().parent
PROTO = HERE.parent / "ambiant-prototype.html"
REF = HERE.parent / "ref"
ART = HERE / "art"
IDS = ["minecraft", "elden", "cyberpunk", "hades2", "bg3", "fh5", "rdr2", "sot", "outerwilds", "hollow"]

# Scènes capturées en plus de l'accueil : (nom, jeu, [(touche, attente en s), …]).
# Les touches sont celles du prototype : y = options, Enter = A, flèches.
DOWN = ("ArrowDown", 0.15)
SCENES = [
    ("options-ouvert", 0, [("y", 1.0)]),
    ("options-codec", 0, [("y", 0.6), DOWN, DOWN, ("ArrowDown", 0.6)]),
    ("options-oublier", 0, [("y", 0.6), DOWN, DOWN, DOWN, DOWN, DOWN, ("Enter", 0.6)]),
    # Lancement (A) : l'écran s'ouvre à 0,12 s, la progression apparaît à 0,76 s,
    # puis une étape toutes les 0,68 s.
    ("lancement-ouverture", 0, [("Enter", 0.55)]),
    ("lancement-etape-1", 0, [("Enter", 1.25)]),
    ("lancement-etape-2", 0, [("Enter", 1.95)]),
    ("lancement-etape-3", 0, [("Enter", 2.65)]),
    ("lancement-flux", 0, [("Enter", 4.0)]),
    ("lancement-maj", 2, [("Enter", 1.95)]),
]
KEY = """
(() => {
  window.dispatchEvent(new KeyboardEvent('keydown', { key: '%s' }));
  window.dispatchEvent(new KeyboardEvent('keyup', { key: '%s' }));
})()
"""

# Avant le script du prototype : version Ambiant, jeu sélectionné, pas de son.
PRE = """
Math.random = () => 0.3;
try {
  localStorage.setItem('cocoos-proto.version', '"ambiant"');
  localStorage.setItem('cocoos-proto.focus', '%d');
  localStorage.setItem('cocoos-proto.sound', 'false');
} catch (e) {}
"""
# Après le chargement : plein cadre (échelle 1), éléments non déterministes figés.
# On n'utilise pas le mode plein écran du prototype (classe is-full) : l'en-tête
# masqué y fait tomber l'écran dans une rangée de grille de hauteur 0 (écran noir).
# La promesse attend les polices puis la fin de l'entrée d'écran (l'hôte passe
# « connecté » à 1,5 s ; la latence devient aléatoire à 4 s : on capture avant).
POST = """
new Promise(done => {
  const st = document.createElement('style');
  st.textContent = '.ct,.cb{display:none!important}.app{grid-template-rows:minmax(0,1fr)!important}' +
    '.viewport{padding:0!important}.frame{border-radius:0!important;box-shadow:none!important}' +
    '.grain::after{display:none!important}.vb-layer .art{animation-play-state:paused!important}';
  document.head.appendChild(st);
  document.querySelectorAll('.js-clock').forEach(e => { e.textContent = '21:30'; });
  document.fonts.ready.then(() => setTimeout(() => done(document.fonts.size), 2500));
})
"""
ART_ONLY = """
(() => {
  const svg = document.querySelector('.vb-item[data-i="%d"] svg.art').outerHTML;
  document.body.innerHTML = '<div style="position:fixed;inset:0;background:#000">' + svg + '</div>';
})()
"""


class Cdp:
    def __init__(self, ws):
        self.ws, self.n, self.events = ws, 0, []

    async def call(self, method, params=None, session=None):
        self.n += 1
        msg = {"id": self.n, "method": method, "params": params or {}}
        if session:
            msg["sessionId"] = session
        await self.ws.send(json.dumps(msg))
        while True:
            r = json.loads(await self.ws.recv())
            if r.get("id") == self.n:
                if "error" in r:
                    raise RuntimeError(f"{method}: {r['error']}")
                return r["result"]
            self.events.append(r)

    async def event(self, method, session):
        while True:
            for e in self.events:
                if e.get("method") == method and e.get("sessionId") == session:
                    self.events.remove(e)
                    return e
            self.events.append(json.loads(await self.ws.recv()))


async def shot(cdp, focus, out, art=False, keys=()):
    w, h = (1600, 1000) if art else (1280, 800)
    target = (await cdp.call("Target.createTarget", {"url": "about:blank"}))["targetId"]
    s = (await cdp.call("Target.attachToTarget", {"targetId": target, "flatten": True}))["sessionId"]
    await cdp.call("Emulation.setDeviceMetricsOverride",
                   {"width": w, "height": h, "deviceScaleFactor": 1, "mobile": False}, s)
    await cdp.call("Page.enable", session=s)
    await cdp.call("Page.addScriptToEvaluateOnNewDocument", {"source": PRE % focus}, s)
    await cdp.call("Page.navigate", {"url": PROTO.as_uri()}, s)
    await cdp.event("Page.loadEventFired", s)
    r = await cdp.call("Runtime.evaluate", {"expression": POST, "awaitPromise": True}, s)
    assert r["result"].get("value", 0) > 0, f"polices non chargées : {r}"
    if art:
        await cdp.call("Runtime.evaluate", {"expression": ART_ONLY % focus}, s)
    for key, wait in keys:
        await cdp.call("Runtime.evaluate", {"expression": KEY % (key, key)}, s)
        await asyncio.sleep(wait)
    fmt = {"format": "jpeg", "quality": 90} if art else {"format": "png"}
    data = (await cdp.call("Page.captureScreenshot", fmt, s))["data"]
    out.write_bytes(base64.b64decode(data))
    await cdp.call("Target.closeTarget", {"targetId": target})


async def main():
    REF.mkdir(exist_ok=True)
    ART.mkdir(exist_ok=True)
    # Brave écrit encore dans son profil en s'arrêtant : on tolère un ménage incomplet.
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        proc = subprocess.Popen(
            [os.environ.get("BRAVE", "brave-browser"), "--headless=new", "--remote-debugging-port=0",
             f"--user-data-dir={tmp}/profile", "--no-first-run", "--disable-gpu", "--hide-scrollbars",
             "--force-device-scale-factor=1", "about:blank"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        try:
            port_file = Path(tmp) / "profile" / "DevToolsActivePort"
            deadline = time.time() + 30
            while not port_file.exists():
                if time.time() > deadline:
                    raise RuntimeError("Brave n'a pas ouvert son port DevTools")
                time.sleep(0.2)
            port, path = port_file.read_text().split()
            async with websockets.connect(f"ws://127.0.0.1:{port}{path}", max_size=None) as ws:
                cdp = Cdp(ws)
                for i, gid in enumerate(IDS):
                    await shot(cdp, i, REF / f"home-{i}-{gid}.png")
                    await shot(cdp, i, ART / f"{gid}.jpg", art=True)
                    print(f"ok {i} {gid}", flush=True)
                for name, focus, keys in SCENES:
                    await shot(cdp, focus, REF / f"{name}.png", keys=keys)
                    print(f"ok {name}", flush=True)
        finally:
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=10)


asyncio.run(main())
