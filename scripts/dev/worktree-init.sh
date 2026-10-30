#!/usr/bin/env bash
# Prépare un worktree neuf (créé par `claude -w <nom>`, `git worktree add`, ou un autre outil) :
# setup commun (hooks git, sous-modules…) puis premier build embedded (rapide si ccache est chaud).
set -euo pipefail
case "${1:-}" in
  -h|--help) echo 'usage: scripts/dev/worktree-init.sh [--no-build]'; echo 'Setup hors ligne puis build embedded ; --no-build prépare uniquement les hooks.'; exit 0 ;;
  ''|--no-build) ;;
  *) echo 'usage: scripts/dev/worktree-init.sh [--no-build]' >&2; exit 64 ;;
esac
[ "$#" -le 1 ] || { echo 'Un seul argument accepté.' >&2; exit 64; }
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root"
scripts/dev/setup.sh
[ "${1:-}" = "--no-build" ] && exit 0
exec scripts/dev/build.sh embedded
