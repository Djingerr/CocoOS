#!/usr/bin/env bash
# Plusieurs Claude Code en parallèle dans tmux, chacun dans son worktree (pas de collision de fichiers).
#
#   scripts/cc/tmux-fleet.sh ui idle stream     # 3 fenêtres : claude -w ui, claude -w idle, claude -w stream
#   scripts/cc/tmux-fleet.sh --rc ui idle       # idem, pilotables depuis le téléphone (Remote Control)
#   tmux attach -t cocoos                        # revenir plus tard (même après avoir fermé le terminal)
#
# Fenêtre 0 « main » : session sur la branche courante (intégration, revues, merges).
# Chaque worktree : branche worktree-<nom>, dossier .claude/worktrees/<nom>/.
# Raccourcis tmux utiles : Ctrl-b w (liste), Ctrl-b n/p (suivante/précédente), Ctrl-b d (détacher).
set -u
rc=""
[ "${1:-}" = "--rc" ] && { rc="--remote-control"; shift; }
root=$(git rev-parse --show-toplevel) || exit 1
s=cocoos

if ! tmux has-session -t "$s" 2>/dev/null; then
  tmux new-session -d -s "$s" -n main -c "$root" "claude -n main $rc; exec \$SHELL"
fi
for name in "$@"; do
  if tmux list-windows -t "$s" -F '#W' | grep -qx "$name"; then
    echo "fenêtre « $name » déjà ouverte"; continue
  fi
  # Le hook SessionStart signale les sous-modules manquants ; worktree-init.sh les installe.
  tmux new-window -t "$s" -n "$name" -c "$root" "claude -w $name -n $name $rc; exec \$SHELL"
done
tmux select-window -t "$s:main"
[ -n "${TMUX:-}" ] && tmux switch-client -t "$s" || tmux attach -t "$s"
