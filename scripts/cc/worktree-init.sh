#!/usr/bin/env bash
# Prépare un worktree neuf (créé par `claude -w <nom>` ou `git worktree add`) :
# sous-modules + premier build embedded (ccache le rend rapide si le cache est chaud).
set -u
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root"
echo ">> sous-modules…"
git submodule update --init --recursive --depth 1 2>&1 | tail -3
[ "${1:-}" = "--no-build" ] && exit 0
exec scripts/cc/build.sh embedded
