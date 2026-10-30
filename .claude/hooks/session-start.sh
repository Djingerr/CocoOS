#!/usr/bin/env bash
# Claude Code — SessionStart : mise en place (commune à toutes les IA, scripts/dev/setup.sh) puis
# état de départ compact (stdout = contexte donné à Claude).
set -u
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
cd "$root" 2>/dev/null || exit 0
[ -x scripts/dev/setup.sh ] && scripts/dev/setup.sh --quiet
exec scripts/dev/status.sh
