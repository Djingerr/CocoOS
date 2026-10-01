#!/usr/bin/env bash
# Capture une vue du harnais avec le vrai rendu GPU (OpenGL), sans rien afficher
# à l'écran : un compositeur mutter « headless » tourne le temps de la capture.
#
#   ./shot.sh /tmp/a.png view=HomeDemo focus=0 drift=0
#
# Sans mutter, utiliser le rendu logiciel (moins fidèle sur les détails fins) :
#   QT_QPA_PLATFORM=offscreen qml-qt6 Harness.qml -- view=HomeDemo out=/tmp/a.png
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$1"; shift
sock="cocoos-harness-$$"

# Moniteur virtuel plus grand que la fenêtre, pour qu'elle ne soit pas réduite.
mutter --headless --wayland --no-x11 --virtual-monitor 1600x1000 \
       --wayland-display "$sock" >/dev/null 2>&1 &
mutter_pid=$!
trap 'kill "$mutter_pid" 2>/dev/null || true' EXIT
for _ in $(seq 50); do
    [ -S "$XDG_RUNTIME_DIR/$sock" ] && break
    sleep 0.1
done

# Configuration utilisateur vierge : rendu des polices neutre (pas de sous-pixel
# hérité du bureau) et aucun réglage écrit dans ~/.config.
cfg="$(mktemp -d)"
trap 'kill "$mutter_pid" 2>/dev/null || true; rm -rf "$cfg"' EXIT

WAYLAND_DISPLAY="$sock" QT_QPA_PLATFORM=wayland XDG_CONFIG_HOME="$cfg" \
    timeout -k 3 30 qml-qt6 -I "$here/stubs" "$here/Harness.qml" -- out="$out" "$@"
