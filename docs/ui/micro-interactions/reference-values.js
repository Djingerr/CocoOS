#!/usr/bin/env node
// Valeurs de référence tirées du JavaScript de micro-interactions-prototype.html
// lui-même (rien n'est recopié à la main) : tst_Spring.qml les compare à Spring.js.
// Relancer après une modification du prototype, puis recopier la sortie dans `ref` :
//
//     node reference-values.js
//
// On extrait du <script> la fonction spring() et le tableau SPRINGS, et on garde de
// chaque ressort sa durée, son dépassement et les 51 points de sa courbe linear().
const fs = require("fs");
const path = require("path");

const html = fs.readFileSync(path.join(__dirname, "micro-interactions-prototype.html"), "utf8");
const script = html.slice(html.indexOf("<script>") + 8, html.indexOf("</script>"));
const a = script.indexOf("function spring("), b = script.indexOf("const FALLBACK", a);
if (a < 0 || b < 0) throw new Error("spring() introuvable dans le prototype");
const { spring, SPRINGS } = new Function(script.slice(a, b) + "return { spring, SPRINGS };")();

const out = {};
for (const name in SPRINGS) {
  const [k, c] = SPRINGS[name], s = spring(k, c);
  out[name] = { k, c, ms: s.ms, over: s.over,
                points: s.easing.slice(7, -1).split(", ").map(Number) };
}
console.log(JSON.stringify(out));
