#!/usr/bin/env bash
# SessionStart : contexte compact uniquement ; setup explicite une fois par worktree.
set -u
root="$(git rev-parse --show-toplevel 2>/dev/null)"
cd "$root" 2>/dev/null || exit 0
command -v python3 >/dev/null || { echo 'MEMORY BLOCKED : python3 absent ; lire AGENTS.md, roadmap et HANDOFF.md'; exit 0; }
exec python3 scripts/dev/memory.py resume --compact
