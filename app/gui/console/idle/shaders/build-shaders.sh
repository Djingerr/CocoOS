#!/usr/bin/env bash
# Compile les shaders de l'écran de veille en .qsb (à relancer après toute modification
# d'un .frag ; les .qsb sont versionnés et embarqués par qml.qrc). Mêmes cibles que
# ../../shaders/build-shaders.sh : GLSL ES pour la Mali, GLSL desktop, SPIR-V.
set -euo pipefail
cd "$(dirname "$0")"
QSB="${QSB:-$(command -v qsb-qt6 || command -v qsb || echo /usr/lib64/qt6/bin/qsb)}"
for f in blur glowsource backdrop card textgradient; do
    "$QSB" --glsl "100 es,120,150,300 es" -o "$f.frag.qsb" "$f.frag"
done
