#!/usr/bin/env bash
# Interface Fedora ; aucune chaîne de commande fournie par l'utilisateur n'est évaluée.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$here/fleet.py" "$@"
