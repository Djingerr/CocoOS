#!/usr/bin/env bash
# Traduction anglaise de la console (skill cocoos-i18n), sortie résumée.
#   scripts/cc/i18n.sh           # lupdate, puis liste des chaînes non traduites
#   scripts/cc/i18n.sh --release # idem + lrelease et touch qml.qrc (à faire une fois tout traduit)
set -u
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root/app"
ts=gui/console/languages/qml_en.ts
lupdate=$(command -v lupdate-qt6 || command -v lupdate || true)
[ -z "$lupdate" ] && { echo "lupdate-qt6 introuvable"; exit 127; }

"$lupdate" gui/console -source-language fr -target-language en -no-obsolete -ts "$ts" 2>&1 | grep -E 'Found|error' | head -5
n=$(grep -c 'type="unfinished"' "$ts")
echo "Chaînes non traduites : $n"
if [ "$n" -gt 0 ]; then
  # Affiche les sources concernées (le <source> qui précède chaque unfinished), 30 max.
  awk '/<source>/{s=$0} /type="unfinished"/{gsub(/^ *<source>|<\/source>$/,"",s); print "  - " s}' "$ts" | head -30
fi
if [ "${1:-}" = "--release" ]; then
  [ "$n" -gt 0 ] && echo "⚠ $n chaînes encore non traduites : elles s'afficheront en français."
  lrelease=$(command -v lrelease-qt6 || command -v lrelease)
  "$lrelease" "$ts" 2>&1 | tail -1 && touch qml.qrc && echo "qml_en.qm régénéré, qml.qrc touché."
fi
