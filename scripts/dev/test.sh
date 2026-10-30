#!/usr/bin/env bash
# Tests QML de la console à sortie RÉSUMÉE.
#   scripts/dev/test.sh              # tous : harnais Ambiant (tst_*.qml) + veille (idle/tests)
#   scripts/dev/test.sh GameShelf    # ceux dont le nom contient « GameShelf » (insensible à la casse)
# Chaque test tourne avec un XDG_CONFIG_HOME vierge (sinon favoris / récents d'un passage précédent
# faussent les résultats) et QT_QPA_PLATFORM=offscreen. Détail d'un échec : .dev/tests/<test>.log
set -u
case "${1:-}" in -h|--help) echo "usage: $0 [filtre-littéral]"; exit 0 ;; esac
[ "$#" -le 1 ] || { echo "usage: $0 [filtre-littéral]" >&2; exit 64; }
filter="${1:-}"
root=$(git rev-parse --show-toplevel) || exit 1
runner=$(command -v qmltestrunner-qt6 || true)
[ -n "$runner" ] || { echo "TESTS BLOCKED : qmltestrunner-qt6 introuvable (Qt5 non accepté)"; exit 2; }
command -v timeout >/dev/null || { echo 'TESTS BLOCKED : timeout absent'; exit 2; }
mkdir -p "$root/.dev/tests"

harness="$root/docs/ui/ambiant/harness"
idle="$root/app/gui/console/idle/tests"
pass=0; fail=0; failed=()
tmpbase=/tmp
if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && [ -w "$TMPDIR" ] && [ -x "$TMPDIR" ]; then
  tmpbase=$TMPDIR
elif [ -d /tmp/opencode ] && [ -w /tmp/opencode ] && [ -x /tmp/opencode ]; then
  tmpbase=/tmp/opencode
fi

run_one() { # $1 = dossier, $2 = fichier, $3.. = options en plus
  local dir=$1 file=$2; shift 2
  local name; name=$(basename "$file" .qml)
  if [ -n "$filter" ] && ! echo "$name" | grep -qiF -- "$filter"; then return; fi
  local cfg; cfg=$(mktemp -d "$tmpbase/cocoos-test.XXXXXX") || exit 2
  local log="$root/.dev/tests/$name.log"
  (cd "$dir" && XDG_CONFIG_HOME="$cfg" QT_QPA_PLATFORM=offscreen timeout 180 \
     "$runner" "$@" -input "$file") >"$log" 2>&1
  local rc=$?
  rm -rf "$cfg"
  local totals; totals=$(grep -E '^Totals:' "$log" | tail -1)
  if [ $rc -eq 0 ] && [ -n "$totals" ] && grep -qE '^Totals: [1-9][0-9]* passed, 0 failed' "$log"; then
    pass=$((pass+1)); printf 'PASS %-28s %s\n' "$name" "${totals#Totals: }"
  else
    fail=$((fail+1)); failed+=("$name")
    printf 'FAIL %-28s %s\n' "$name" "${totals#Totals: }"
    grep -E '^(FAIL!|   Actual|   Expected|   Loc:)|QML.*Error|is not defined|not installed' "$log" | head -8 | sed 's/^/     /'
    echo "     code $rc — $log"
    tail -5 "$log" | sed 's/^/     /'
  fi
}

for f in "$harness"/tst_*.qml; do [ -e "$f" ] && run_one "$harness" "$(basename "$f")" -import stubs; done
for f in "$idle"/tst_*.qml;    do [ -e "$f" ] && run_one "$idle"    "$(basename "$f")"; done

total=$((pass+fail))
[ $total -eq 0 ] && { echo "TESTS BLOCKED : aucun test ne correspond à « $filter »"; exit 2; }
if [ $fail -eq 0 ]; then echo "TESTS OK ($pass/$total)"; else echo "TESTS FAILED ($fail/$total) : ${failed[*]} — logs dans .dev/tests/"; fi
[ $fail -eq 0 ]
