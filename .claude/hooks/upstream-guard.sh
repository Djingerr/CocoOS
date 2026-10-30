#!/usr/bin/env bash
# Claude Code — PreToolUse (Edit|Write|MultiEdit|NotebookEdit).
# Traduit la politique commune (scripts/dev/upstream-policy.sh) en décision Claude Code, AVANT l'édition.
# Les autres IA sont couvertes au moment du commit par .githooks/pre-commit (même politique).
set -u
f=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -z "$f" ] && exit 0
base="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$f" in /*) ;; *) f="$base/$f" ;; esac

# Politique du dépôt qui contient le fichier (worktree compris), sinon celle du projet.
d=$(dirname "$f"); while [ ! -d "$d" ] && [ "$d" != / ]; do d=$(dirname "$d"); done
root=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)
policy="$root/scripts/dev/upstream-policy.sh"
[ -x "$policy" ] || policy="$base/scripts/dev/upstream-policy.sh"
[ -x "$policy" ] || exit 0
class=$("$policy" "$f")
rel="${f#"$root"/}"

decide() {
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}

if [ "$(git -C "$root" symbolic-ref --short -q HEAD 2>/dev/null)" = master ] && [ "$class" != outside ]; then
  decide deny "Branche master = miroir propre d'upstream (AGENTS.md §4) : on n'y code jamais. Passer sur console-ui ou une branche de travail."
fi

case "$class" in
  own|outside) exit 0 ;;
  guard)     decide ask  "Fichier de garde-fous ($rel) : c'est Coco qui décide des coutures et des règles. Montrer le diff et attendre son accord." ;;
  seam)      decide ask  "Couture upstream ($rel) : modif strictement ADDITIVE, sous #ifdef CONSOLE_UI ou scope embedded, la plus petite possible ; montrer le diff à Coco (AGENTS.md §4)." ;;
  forbidden) decide deny "app/gui/main.qml est intouchable (AGENTS.md §4). Passer par app/gui/console/ ou une couture existante." ;;
  upstream)  decide deny "Refusé : $rel est un fichier upstream de moonlight-qt hors des coutures admises (.agents/seams.txt). Créer plutôt un fichier neuf dans app/gui/console/. Si une nouvelle couture est vraiment nécessaire, s'arrêter et la proposer à Coco (diff, taille, justification) ; c'est lui qui l'ajoute à .agents/seams.txt." ;;
  new)       decide ask  "Nouveau fichier hors des zones CocoOS ($rel). Le code console vit dans app/gui/console/ (AGENTS.md §4) : confirmer que cet emplacement est voulu." ;;
esac
exit 0
