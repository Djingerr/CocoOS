#!/usr/bin/env bash
# État de départ en quelques lignes, pour reprendre le travail (humain ou IA, n'importe quel outil).
set -u
case "${1:-}" in -h|--help) echo "usage: $0 (état du worktree, lecture seule)"; exit 0 ;; esac
[ "$#" -eq 0 ] || exit 64
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root"
echo "[CocoOS] branche : $(git symbolic-ref --short -q HEAD || echo '(détachée)')"
dirty=$(git status --porcelain | head -12)
[ -n "$dirty" ] && { echo "[CocoOS] fichiers modifiés :"; echo "$dirty"; }
if [ -f next_steps.md ]; then
  last=$(grep -E '^## ' next_steps.md | tail -1)
  [ -n "$last" ] && echo "[CocoOS] dernière section de next_steps.md : ${last#\#\# }"
fi
[ -f .dev/last-build.status ] && echo "[CocoOS] dernier build : $(cat .dev/last-build.status)"
hooks=$(git config --path --get core.hooksPath || true)
case "$hooks" in '') resolved='' ;; /*) resolved=$(realpath -m -- "$hooks") ;; *) resolved=$(realpath -m -- "$root/$hooks") ;; esac
if [ "$resolved" != "$(realpath -m -- "$root/.githooks")" ] || [ ! -x "$root/.githooks/pre-commit" ]; then
  echo "[CocoOS] ⚠ garde-fous git inactifs : lancer scripts/dev/setup.sh"
fi
if [ -z "$(ls -A moonlight-common-c/moonlight-common-c 2>/dev/null)" ]; then
  echo "[CocoOS] sous-modules absents : lancer scripts/dev/setup.sh --submodules (réseau explicite) avant de compiler"
fi
exit 0
