#!/usr/bin/env node
// Valeurs de référence tirées du JavaScript de prototype.html lui-même (rien n'est
// recopié à la main) : les tests de BootTimeline.js (tst_BootTimeline.qml) les
// comparent à leur port. Relancer après une modification du prototype :
//
//     node reference-values.js
//
// On extrait du <script> du prototype les blocs purs (constantes, easings, ressort,
// état d'attente, chargeur) et on les évalue avec un réglage de démarrage choisi.
const fs = require("fs");
const path = require("path");

const html = fs.readFileSync(path.join(__dirname, "prototype.html"), "utf8");
const script = html.slice(html.indexOf("<script>") + 8, html.indexOf("</script>"));
const block = (from, to) => {
  const a = script.indexOf(from), b = script.indexOf(to, a);
  if (a < 0 || b < 0) throw new Error(`bloc introuvable : ${from}`);
  return script.slice(a, b);
};
const source = [
  block("const REF_W", "// ---------- Easings"),
  block("function cubicBezier", "// ---------- Canvas"),
  block("let anim = 0", "// ---------- Primitives"),
  block("// Indicateur indéterminé", "function drawLoader"),
].join("\n");

// Le prototype en mode « boot lent » : `slow` ms après normalE, le système est prêt.
function evaluate(slow) {
  const f = new Function("slow", source + `
    bootMode = slow;
    return { E_OUT, E_INOUT, E_EMPH, E_DRAW, E_STD, spring, spinner, loaderState, getE,
             completeAt, normalE, barShowAt, revealEnd, release, T };`);
  return f(slow);
}

const r4 = evaluate(4000), r1 = evaluate(1000), fast = evaluate("fast");
const x = [0.1, 0.3, 0.5, 0.8];
const out = {
  easings: Object.fromEntries(["E_OUT", "E_INOUT", "E_EMPH", "E_DRAW", "E_STD"]
    .map(n => [n, x.map(v => r4[n](v))])),
  springs: [[300, 620, 0.9], [300, 520, 0.78], [700, 520, 0.78]].map(a => [...a, r4.spring(...a)]),
  instants: { release: r4.release, revealEnd: r4.revealEnd, normalE: r4.normalE, loaderShowAt: r4.barShowAt },
  // Début de la sortie selon l'instant où le système est prêt
  exitStart: [
    ["fast", fast.normalE, fast.getE()],
    [1000, r1.normalE + 1000, r1.getE()],
    [4000, r4.normalE + 4000, r4.getE()],
  ],
  spinner: [0, 500, 2000].map(tau => [tau, r4.spinner(tau)]),
  // Chargeur (système prêt 4000 ms après normalE) : t, état
  loader: [3000, 4000, r4.completeAt() + 260, r4.completeAt() + 700].map(t => [t, r4.loaderState(t)]),
};
console.log(JSON.stringify(out, null, 1));
