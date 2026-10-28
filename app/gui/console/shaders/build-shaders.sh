#!/usr/bin/env bash
# Compile les shaders de la console en .qsb (à relancer après toute
# modification d'un .frag ; les .qsb sont versionnés et embarqués par qml.qrc).
# GLSL ES pour la carte (Mali), GLSL desktop pour le développement ; SPIR-V d'office.
set -euo pipefail
cd "$(dirname "$0")"
QSB="${QSB:-$(command -v qsb-qt6 || command -v qsb || echo /usr/lib64/qt6/bin/qsb)}"
for f in ConicMask EllipseMask Backdrop Cover; do
    "$QSB" --glsl "100 es,120,150,300 es" -o "$f.frag.qsb" "$f.frag"
done
