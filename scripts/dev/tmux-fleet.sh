#!/usr/bin/env bash
# Plusieurs assistants IA en parallèle dans tmux, chacun dans son propre worktree (aucune collision).
#
#   scripts/dev/tmux-fleet.sh ui idle stream            # Claude Code : `claude -w <nom>` par fenêtre
#   scripts/dev/tmux-fleet.sh --rc ui idle              # idem, pilotable depuis le téléphone (Remote Control)
#   scripts/dev/tmux-fleet.sh --tool codex i18n         # autre outil : codex, aider, opencode, gemini…
#   scripts/dev/tmux-fleet.sh --tool "aider --model deepseek/deepseek-chat" doc
#   tmux attach -t cocoos                                # revenir plus tard (Ctrl-b w : liste des fenêtres)
#
# Claude crée ses worktrees dans .claude/worktrees/<nom> (branche worktree-<nom>) ; pour les autres outils,
# ce script crée .worktrees/<nom> (branche wt-<nom>) puis y lance scripts/dev/setup.sh.
set -u
tool=claude; rc=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rc) rc="--remote-control"; shift ;;
    --tool) tool="$2"; shift 2 ;;
    *) break ;;
  esac
done
root=$(git rev-parse --show-toplevel) || exit 1
s=cocoos
grep -qx '.worktrees/' "$(git rev-parse --git-common-dir)/info/exclude" 2>/dev/null || \
  echo '.worktrees/' >> "$(git rev-parse --git-common-dir)/info/exclude"

if ! tmux has-session -t "$s" 2>/dev/null; then
  first=${tool%% *}
  if [ "$first" = claude ]; then main="claude -n main $rc"; else main="$tool"; fi
  tmux new-session -d -s "$s" -n main -c "$root" "$main; exec \$SHELL"
fi

for name in "$@"; do
  if tmux list-windows -t "$s" -F '#W' | grep -qx "$name"; then echo "fenêtre « $name » déjà ouverte"; continue; fi
  if [ "${tool%% *}" = claude ]; then
    # Le hook SessionStart de Claude lance scripts/dev/setup.sh dans le worktree.
    tmux new-window -t "$s" -n "$name" -c "$root" "claude -w $name -n $name $rc; exec \$SHELL"
  else
    wt="$root/.worktrees/$name"
    [ -d "$wt" ] || git -C "$root" worktree add -q "$wt" -b "wt-$name" 2>/dev/null || git -C "$root" worktree add -q "$wt" "wt-$name"
    tmux new-window -t "$s" -n "$name" -c "$wt" "scripts/dev/setup.sh; $tool; exec \$SHELL"
  fi
done
tmux select-window -t "$s:main"
[ -n "${TMUX:-}" ] && tmux switch-client -t "$s" || tmux attach -t "$s"
