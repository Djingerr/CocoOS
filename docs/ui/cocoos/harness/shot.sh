#!/usr/bin/env bash
# Harnais CocoOS : capture une vue de ce dossier avec le harnais d'Ambiant (même fenêtre
# 1280 × 800, même rendu GPU sous un mutter « headless », mêmes faux modules Moonlight),
# en lui indiquant d'aller chercher la vue ici (base=).
#
#   ./shot.sh /tmp/a.png view=LibraryDemo
#   python3 ../tools/compare.py ../reference/png/AccueilCarrousel.png /tmp/a.png /tmp/diff.png
#
# À l'écran, interactif :
#   QML_XHR_ALLOW_FILE_READ=1 qml-qt6 -I ../../ambiant/harness/stubs ../../ambiant/harness/Harness.qml \
#       -- base=file://$PWD/ view=LibraryDemo
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$1"; shift
# Les vues lisent ../mock/*.json en local.
export QML_XHR_ALLOW_FILE_READ=1
exec "$here/../../ambiant/harness/shot.sh" "$out" base="file://$here/" "$@"
