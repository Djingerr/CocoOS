#!/usr/bin/env bash
# Prépare un worktree neuf (créé par `claude -w <nom>`, `git worktree add`, ou un autre outil) :
# setup commun (hooks git, sous-modules…) puis premier build embedded (rapide si ccache est chaud).
set -u
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root"
scripts/dev/setup.sh
[ "${1:-}" = "--no-build" ] && exit 0
exec scripts/dev/build.sh embedded
