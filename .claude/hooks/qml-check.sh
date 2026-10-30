#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit) — après l'édition d'un .qml de la console, signale à Claude
# les ERREURS de qmllint (syntaxe, propriété inconnue…), jamais les simples avertissements :
# retour immédiat, sans build, et sans noyer le contexte.
set -u
f=$(jq -r '.tool_input.file_path // empty')
case "$f" in *.qml) ;; *) exit 0 ;; esac
[ -f "$f" ] || exit 0
lint=$(command -v qmllint-qt6 || command -v qmllint || command -v /usr/lib64/qt6/bin/qmllint || true)
[ -z "$lint" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
out=$(timeout 20 "$lint" -I "$root/app/gui/console" -I "$root/docs/ui/ambiant/harness/stubs" "$f" 2>&1)
errs=$(printf '%s\n' "$out" | grep -E '^(Error|error)|[Ss]yntax|Expected token|Unexpected token' | grep -v -i '^warning' | head -15)
if [ -n "$errs" ]; then
  echo "qmllint a trouvé des erreurs dans $(basename "$f") :" >&2
  echo "$errs" >&2
  exit 2   # PostToolUse : ne bloque pas, mais montre stderr à Claude pour qu'il corrige
fi
exit 0
