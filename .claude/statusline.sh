#!/usr/bin/env bash
# Barre d'état Claude Code : worktree/branche · contexte utilisé · dernier build.
# Utile avec plusieurs sessions en parallèle (tmux) : on voit d'un coup d'œil qui est où.
in=$(cat)
dir=$(printf '%s' "$in" | jq -r '.workspace.current_dir // .cwd // "."')
ctx=$(printf '%s' "$in" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
model=$(printf '%s' "$in" | jq -r '.model.display_name // empty')
branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || echo "?")
root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
build=""
[ -f "$root/.dev/last-build.status" ] && build=" · build $(cut -d' ' -f1 "$root/.dev/last-build.status")"
warn=""
[ -n "$ctx" ] && [ "$ctx" -ge 60 ] && warn=" ⚠ /compact"
printf '%s · %s · ctx %s%%%s%s' "$(basename "$root")@$branch" "$model" "${ctx:-?}" "$warn" "$build"
