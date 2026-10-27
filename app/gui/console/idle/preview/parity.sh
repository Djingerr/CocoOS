#!/usr/bin/env bash
# Phase 4 du brief : capture les quatre états (t = 3 s, ou `at` ms) et les compare aux
# références de docs/design/idle/ (écart global, grille 8 × 4, carte d'écart).
#
#   app/gui/console/idle/preview/parity.sh            # final : t = 3000 ms
#   app/gui/console/idle/preview/parity.sh 450 entree # rythme d'entrée
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
design="$here/../../../../../docs/design/idle"
at="${1:-3000}"; kind="${2:-final}"
mkdir -p "$design/captures"
for pair in game:09_jeu gameDownload:10_jeu_telechargement download:11_telechargement rest:12_repos; do
    state="${pair%%:*}"; name="${pair##*:}"
    out="$design/captures/${name}_${kind}.png"
    log="$design/captures/${name}_${kind}.log"
    "$here/grab.sh" --state "$state" --now 2026-10-27T21:46:00 --no-drift \
        --grab-after "$at" --grab "$out" --layout > "$log" 2>&1 || true
    grep -v -e textinput -e IDLE_LAYOUT "$log" || true
    echo "== $name ($kind)"
    python3 "$design/tools/compare.py" "$design/reference/png/${name}_${kind}.png" "$out" \
        "$design/captures/${name}_${kind}_diff.png"
    if [ "$kind" = final ]; then
        python3 "$here/layout_check.py" "$log" "$design/reference/layout/${name}.json" || true
    fi
done
