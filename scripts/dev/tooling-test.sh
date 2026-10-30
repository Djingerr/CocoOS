#!/usr/bin/env bash
set -u
case "${1:-}" in -h|--help) echo "usage: $0 (tests isolés dans un répertoire temporaire disponible)"; exit 0 ;; esac
[ "$#" -eq 0 ] || exit 64
command -v python3 >/dev/null || { echo 'TOOLING BLOCKED : python3 absent'; exit 2; }
root=$(git rev-parse --show-toplevel) || exit 1
mkdir -p "$root/.dev"
log="$root/.dev/last-tooling-test.log"
python3 "$root/scripts/dev/tests/test_tooling.py" >"$log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then tail -60 "$log"; else tail -5 "$log"; fi
if [ "$rc" -eq 0 ]; then echo "TOOLING PASS — $log"; else echo "TOOLING FAIL (code $rc) — $log"; fi
exit "$rc"
