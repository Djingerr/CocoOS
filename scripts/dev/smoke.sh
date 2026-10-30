#!/usr/bin/env bash
# Test de fumée : lance ./app/moonlight N secondes, HORS RÉSEAU (unshare -rn : aucun risque
# d'appairage ou de lancement sur le vrai PC) et hors écran, puis ne remonte que les problèmes.
#   scripts/dev/smoke.sh [secondes=8]
set -u
secs="${1:-8}"
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root"
[ -x app/moonlight ] || { echo "SMOKE NON LANCÉ : app/moonlight absent (scripts/dev/build.sh d'abord)"; exit 127; }
mkdir -p .dev
log=.dev/last-smoke.log
cfg=$(mktemp -d)
# Sortie redirigée vers un fichier : à travers un pipe, moonlight n'écrit rien (skill cocoos-build).
XDG_CONFIG_HOME="$cfg" QT_QPA_PLATFORM=offscreen COCOOS_BOOT_SPEED=4 \
  timeout "$secs" unshare -rn ./app/moonlight >"$log" 2>&1
rc=$?
rm -rf "$cfg"

problems=$(grep -E 'qml: .*(Error|error)|\.qml:[0-9]+.*(Error|TypeError|ReferenceError|is not defined|Cannot assign|not installed|Non-existent)|Segmentation|Aborted|terminate called|ASSERT' "$log" \
  | grep -v -E 'D-?Bus|org\.freedesktop' | awk '!seen[$0]++' | head -25)
console=$(grep -c '\[console-ui\]' "$log")

if [ -n "$problems" ]; then
  echo "$problems"
  echo "SMOKE FAILED (${secs}s, $console lignes [console-ui]) — log complet : $log"
  exit 1
fi
# timeout renvoie 124 : c'est le cas normal (l'app tournait encore).
if [ $rc -ne 124 ] && [ $rc -ne 0 ]; then
  tail -5 "$log"; echo "SMOKE FAILED : l'app s'est arrêtée seule (code $rc) — $log"; exit 1
fi
grep -E '\[console-ui\] Démarrage' "$log" | tail -1
echo "SMOKE OK (${secs}s, $console lignes [console-ui], D-Bus système injoignable : normal hors réseau)"
