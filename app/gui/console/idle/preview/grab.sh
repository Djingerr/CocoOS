#!/usr/bin/env bash
# Lance IdlePreview avec le vrai rendu GPU, sans rien afficher : un mutter « headless »
# tourne le temps de la capture (le rendu `offscreen` de Qt ne fait pas MultiEffect).
#
#   app/gui/console/idle/preview/grab.sh --component CoverCard --grab-after 3000 --grab /tmp/a.png
#   app/gui/console/idle/preview/grab.sh --state game --now 2026-10-27T21:46:00 --no-drift \
#       --grab-after 3000 --grab captures/09_jeu.png
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
sock="cocoos-idle-$$"
mutter --headless --wayland --no-x11 --virtual-monitor 2600x1700 \
       --wayland-display "$sock" >/dev/null 2>&1 &
mutter_pid=$!
cfg="$(mktemp -d)"
trap 'kill "$mutter_pid" 2>/dev/null || true; rm -rf "$cfg"' EXIT
for _ in $(seq 50); do
    [ -S "$XDG_RUNTIME_DIR/$sock" ] && break
    sleep 0.1
done
WAYLAND_DISPLAY="$sock" QT_QPA_PLATFORM=wayland XDG_CONFIG_HOME="$cfg" QT_FORCE_STDERR_LOGGING=1 \
    timeout -k 3 60 qml-qt6 "$here/IdlePreview.qml" -- "$@"
