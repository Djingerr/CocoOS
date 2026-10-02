#!/usr/bin/env python3
"""Captures de référence du prototype de l'animation de démarrage (prototype.html).

    ./ref-capture.py [t ...]          -> ref/cold-<t>.png (1280×720), aux instants donnés en ms
                                         (par défaut les points de contrôle de BOOT_ANIMATION.md §11)
    ./ref-capture.py --slow [t ...]   -> ref/slow-<t>.png : boot lent, système prêt 4000 ms après
                                         normalE (6385 ms) ; le O devient le chargeur

Le prototype n'est PAS modifié. Son temps avance par requestAnimationFrame : on le
remplace avant le chargement par une horloge pilotée d'ici, ce qui fige l'animation
exactement à l'instant voulu. Réglages : Sora, flou de mouvement coupé (désactivé
par défaut côté QML), boot rapide (système prêt d'emblée), démarrage à froid.
La scène est mise à 1280 × 720 pixels, le repère du prototype.

À comparer aux captures QML : ../ui/ambiant/harness/shot.sh … view=BootDemo
size=1280x720 t=<t>, puis ../ui/ambiant/harness/compare.py.

Dépendances : brave-browser (ou $BRAVE), module Python « websockets ».
"""
import asyncio
import base64
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import websockets

HERE = Path(__file__).resolve().parent
PROTO = HERE / "prototype.html"
REF = HERE / "ref"
TIMES = [500, 600, 1000, 1200, 1400, 1985, 2385]
SLOW_TIMES = [3000, 4000, 6645, 7085]

# Avant le script du prototype : une horloge à nous à la place de requestAnimationFrame.
PRE = """
window.__cbs = [];
window.__now = 0;
window.requestAnimationFrame = cb => { window.__cbs.push(cb); return window.__cbs.length; };
window.__frame = () => { const cbs = window.__cbs; window.__cbs = []; cbs.forEach(cb => cb(window.__now)); };
window.__advance = ms => {
  while (ms > 0) { const d = Math.min(16, ms); ms -= d; window.__now += d; window.__frame(); }
};
"""
# Après le chargement : scène à 1280 × 720, boot rapide, flou coupé, puis on attend
# les polices et la première image (le prototype lance sa boucle une fois Sora chargée).
SETUP = """
new Promise(done => {
  const st = document.createElement('style');
  st.textContent = '.wrap{max-width:none!important;padding:0!important;margin:0!important}' +
    'header,.timeline,.controls,.note,.readout{display:none!important}' +
    '.stage{width:1280px!important;height:720px!important;aspect-ratio:auto!important;' +
    'border:0!important;border-radius:0!important}';
  document.head.appendChild(st);
  window.dispatchEvent(new Event('resize'));
  const set = (id, prop, value) => {
    const el = document.getElementById(id); el[prop] = value; el.dispatchEvent(new Event('change'));
  };
  set('boot', 'value', '%s');
  set('blur', 'checked', false);
  set('loop', 'checked', false);
  document.fonts.ready.then(() => setTimeout(() => {
    window.__frame();
    done(document.querySelector('#c').width);
  }, 1500));
})
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


async def shot(cdp, t, out, boot):
    target = (await cdp.call("Target.createTarget", {"url": "about:blank"}))["targetId"]
    s = (await cdp.call("Target.attachToTarget", {"targetId": target, "flatten": True}))["sessionId"]
    await cdp.call("Emulation.setDeviceMetricsOverride",
                   {"width": 1280, "height": 720, "deviceScaleFactor": 1, "mobile": False}, s)
    await cdp.call("Page.enable", session=s)
    await cdp.call("Page.addScriptToEvaluateOnNewDocument", {"source": PRE}, s)
    await cdp.call("Page.navigate", {"url": PROTO.as_uri()}, s)
    await cdp.event("Page.loadEventFired", s)
    r = await cdp.call("Runtime.evaluate", {"expression": SETUP % boot, "awaitPromise": True}, s)
    assert r["result"].get("value") == 1280, f"scène mal dimensionnée : {r}"
    # (après SETUP, l'animation est à 0 : on l'avance jusqu'à t)
    await cdp.call("Runtime.evaluate", {"expression": f"window.__advance({t})"}, s)
    clip = {"x": 0, "y": 0, "width": 1280, "height": 720, "scale": 1}
    data = (await cdp.call("Page.captureScreenshot", {"format": "png", "clip": clip}, s))["data"]
    out.write_bytes(base64.b64decode(data))
    await cdp.call("Target.closeTarget", {"targetId": target})


async def main():
    REF.mkdir(exist_ok=True)
    slow = "--slow" in sys.argv
    times = [int(a) for a in sys.argv[1:] if a != "--slow"] or (SLOW_TIMES if slow else TIMES)
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
                for t in times:
                    name = f"slow-{t}.png" if slow else f"cold-{t}.png"
                    await shot(cdp, t, REF / name, "4000" if slow else "fast")
                    print(f"ok {t} ms", flush=True)
        finally:
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=10)


asyncio.run(main())
