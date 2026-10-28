#!/usr/bin/env python3
"""Produit reference/ : HTML autonomes, PNG, vidéos MP4 d'un cycle et planches de 12 images.

Usage : python3 tools/capture_reference.py <dossier des .dc.html> [id ...]
"""
import json, os, re, subprocess, sys, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from dc_to_standalone import convert

SRC = sys.argv[1]
ONLY = set(sys.argv[2:])
REF = os.path.join(ROOT, "reference")
for d in ("html", "png", "video", "filmstrip", "dc-source"):
    os.makedirs(os.path.join(REF, d), exist_ok=True)
boards = json.load(open(os.path.join(HERE, "boards.json")))

jobs = []
for bid, kind, label in boards:
    if ONLY and bid not in ONLY:
        continue
    src = os.path.join(SRC, bid + ".dc.html")
    s = open(src, encoding="utf-8").read()
    # keep a clean source copy without the canvas-only sound code
    clean = re.sub(r'<button type="button" aria-label="\{\{sndLabel\}\}".*?</button>\n?', "", s, flags=re.S)
    open(os.path.join(REF, "dc-source", bid + ".dc.html"), "w").write(clean)
    pv = convert(src, os.path.join(REF, "html", bid + ".html"))
    period = None
    if kind == "motion":
        m = re.search(r"% (\d{4,5})\)", s)
        period = int(m.group(1)) if m else 10000
        if bid == "Demarrage":
            period = 10000
        if bid == "MotionNavigation":
            period = 10200
    jobs.append({"id": bid, "kind": kind, "w": pv["width"], "h": pv["height"], "period": period})
json.dump(jobs, open(os.path.join(HERE, "_jobs.json"), "w"))

js = r"""
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const REF = process.argv[3];
(async () => {
  const b = await chromium.launch();
  const run = async (j) => {
    const url = 'file://' + path.join(REF, 'html', j.id + '.html') + '?now=2026-10-28T21:42:00';
    if (j.kind === 'motion') {
      const ctx = await b.newContext({ viewport: { width: j.w, height: j.h }, recordVideo: { dir: path.join(REF, 'video', '_raw_' + j.id), size: { width: j.w, height: j.h } } });
      const p = await ctx.newPage();
      const t0 = Date.now();
      await p.goto(url);
      fs.writeFileSync(path.join(REF, 'video', '_raw_' + j.id, 'offset.txt'), String((Date.now() - t0) / 1000));
      await p.waitForTimeout(j.period + 600);
      await p.screenshot({ path: path.join(REF, 'png', j.id + '.png') });
      await ctx.close();
    } else {
      const ctx = await b.newContext({ viewport: { width: j.w, height: j.h } });
      const p = await ctx.newPage();
      await p.goto(url);
      await p.waitForTimeout(2500);
      await p.screenshot({ path: path.join(REF, 'png', j.id + '.png') });
      await ctx.close();
    }
    console.log('done', j.id);
  };
  const queue = jobs.slice();
  await Promise.all([0, 1, 2].map(async () => { while (queue.length) await run(queue.shift()); }));
  await b.close();
})();
"""
open(os.path.join(HERE, "_cap.js"), "w").write(js)
subprocess.run(["node", os.path.join(HERE, "_cap.js"), os.path.join(HERE, "_jobs.json"), REF], check=True)

for j in jobs:
    if j["kind"] != "motion":
        continue
    raw = os.path.join(REF, "video", "_raw_" + j["id"])
    webm = [f for f in os.listdir(raw) if f.endswith(".webm")][0]
    off = float(open(os.path.join(raw, "offset.txt")).read()) + 0.15
    mp4 = os.path.join(REF, "video", j["id"] + ".mp4")
    dur = j["period"] / 1000
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{off:.2f}", "-i", os.path.join(raw, webm), "-t", f"{dur:.2f}",
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p", "-movflags", "+faststart", mp4], check=True)
    fps = 12 / dur
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", mp4, "-vf",
                    f"fps={fps:.4f},scale=320:-1,drawtext=text='%{{pts\\:hms}}':x=8:y=8:fontsize=14:fontcolor=white:box=1:boxcolor=black@0.5,tile=4x3:padding=4:color=black",
                    "-frames:v", "1", os.path.join(REF, "filmstrip", j["id"] + ".png")], check=True)
    shutil.rmtree(raw)
os.remove(os.path.join(HERE, "_cap.js")); os.remove(os.path.join(HERE, "_jobs.json"))
print("ok", len(jobs))
