#!/usr/bin/env bash
# Test de fumée : lance ./app/moonlight N secondes, HORS RÉSEAU (unshare -rn : aucun risque
# d'appairage ou de lancement sur le vrai PC) et hors écran, puis ne remonte que les problèmes.
#   scripts/dev/smoke.sh [secondes=8]
set -u
case "${1:-}" in -h|--help) echo "usage: $0 [secondes=8] (isolation réseau obligatoire)"; exit 0 ;; esac
[ "$#" -le 1 ] && [[ "${1:-8}" =~ ^[1-9][0-9]*$ ]] || { echo 'Durée entière positive requise' >&2; exit 64; }
secs="${1:-8}"
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root"
[ -x app/moonlight ] || { echo "SMOKE BLOCKED : app/moonlight absent (scripts/dev/build.sh d'abord)"; exit 2; }
mkdir -p .dev
log=.dev/last-smoke.log
for tool in timeout unshare; do
  command -v "$tool" >/dev/null || { echo "SMOKE BLOCKED : $tool absent"; exit 2; }
done
# Préflight avant de lancer le binaire : pas de repli connecté si unshare est interdit.
if ! unshare -rn true >"$log" 2>&1; then
  tail -5 "$log"; echo "SMOKE BLOCKED : isolation unshare indisponible — $log"; exit 2
fi
tmpbase=/tmp
if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && [ -w "$TMPDIR" ] && [ -x "$TMPDIR" ]; then
  tmpbase=$TMPDIR
elif [ -d /tmp/opencode ] && [ -w /tmp/opencode ] && [ -x /tmp/opencode ]; then
  tmpbase=/tmp/opencode
fi
cfg=$(mktemp -d "$tmpbase/cocoos-smoke.XXXXXX") || exit 2
trap 'rm -rf -- "$cfg"' EXIT
# Sortie redirigée vers un fichier : à travers un pipe, moonlight n'écrit rien (skill cocoos-build).
XDG_CONFIG_HOME="$cfg" QT_QPA_PLATFORM=offscreen COCOOS_BOOT_SPEED=4 \
  timeout "$secs" unshare -rn ./app/moonlight >"$log" 2>&1
rc=$?
rm -rf "$cfg"
if grep -q '^unshare:' "$log"; then
  tail -5 "$log"; echo "SMOKE BLOCKED : échec unshare au lancement — $log"; exit 2
fi

problems=$(grep -E 'qml: .*(Error|error)|\.qml:[0-9]+.*(Error|TypeError|ReferenceError|is not defined|Cannot assign|not installed|Non-existent)|Segmentation|Aborted|terminate called|ASSERT' "$log" \
  | grep -v -E 'D-?Bus|org\.freedesktop' | awk '!seen[$0]++' | head -25)
console=$(grep -c '\[console-ui\]' "$log")

if [ -n "$problems" ]; then
  echo "$problems"
  echo "SMOKE FAILED (${secs}s, $console lignes [console-ui]) — log complet : $log"
  exit 1
fi
# timeout renvoie 124 : c'est le cas normal (l'app tournait encore).
if [ $rc -ne 124 ]; then
  tail -5 "$log"; echo "SMOKE FAILED : l'app s'est arrêtée seule (code $rc) — $log"; exit 1
fi
if [ "$console" -eq 0 ]; then
  tail -8 "$log"; echo "SMOKE FAILED : aucun marqueur console (binaire vanilla ou démarrage incomplet) — $log"; exit 1
fi
grep -E '\[console-ui\] Démarrage' "$log" | tail -1
echo "SMOKE OK (${secs}s, $console lignes [console-ui], D-Bus système injoignable : normal hors réseau)"
