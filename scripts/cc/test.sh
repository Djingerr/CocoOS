#!/usr/bin/env bash
# Tests QML de la console à sortie RÉSUMÉE.
#   scripts/cc/test.sh              # tous : harnais Ambiant (tst_*.qml) + veille (idle/tests)
#   scripts/cc/test.sh GameShelf    # ceux dont le nom contient « GameShelf » (insensible à la casse)
# Chaque test tourne avec un XDG_CONFIG_HOME vierge (sinon favoris / récents d'un passage précédent
# faussent les résultats) et QT_QPA_PLATFORM=offscreen. Détail d'un échec : .cc/tests/<test>.log
set -u
filter="${1:-}"
root=$(git rev-parse --show-toplevel) || exit 1
runner=$(command -v qmltestrunner-qt6 || command -v qmltestrunner || true)
[ -z "$runner" ] && { echo "TESTS NON LANCÉS : qmltestrunner-qt6 introuvable"; exit 127; }
mkdir -p "$root/.cc/tests"

harness="$root/docs/ui/ambiant/harness"
idle="$root/app/gui/console/idle/tests"
pass=0; fail=0; failed=()

run_one() { # $1 = dossier, $2 = fichier, $3.. = options en plus
  local dir=$1 file=$2; shift 2
  local name; name=$(basename "$file" .qml)
  if [ -n "$filter" ] && ! echo "$name" | grep -qi -- "$filter"; then return; fi
  local cfg; cfg=$(mktemp -d)
  local log="$root/.cc/tests/$name.log"
  (cd "$dir" && XDG_CONFIG_HOME="$cfg" QT_QPA_PLATFORM=offscreen timeout 180 \
     "$runner" "$@" -input "$file") >"$log" 2>&1
  local rc=$?
  rm -rf "$cfg"
  local totals; totals=$(grep -E '^Totals:' "$log" | tail -1)
  if [ $rc -eq 0 ]; then
    pass=$((pass+1)); printf 'PASS %-28s %s\n' "$name" "${totals#Totals: }"
  else
    fail=$((fail+1)); failed+=("$name")
    printf 'FAIL %-28s %s\n' "$name" "${totals#Totals: }"
    grep -E '^(FAIL!|   Actual|   Expected|   Loc:)|QML.*Error|is not defined|not installed' "$log" | head -8 | sed 's/^/     /'
  fi
}

for f in "$harness"/tst_*.qml; do [ -e "$f" ] && run_one "$harness" "$(basename "$f")" -import stubs; done
for f in "$idle"/tst_*.qml;    do [ -e "$f" ] && run_one "$idle"    "$(basename "$f")"; done

total=$((pass+fail))
[ $total -eq 0 ] && { echo "Aucun test ne correspond à « $filter »"; exit 1; }
if [ $fail -eq 0 ]; then echo "TESTS OK ($pass/$total)"; else echo "TESTS FAILED ($fail/$total) : ${failed[*]} — logs dans .cc/tests/"; fi
[ $fail -eq 0 ]
