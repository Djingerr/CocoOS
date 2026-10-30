#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit) — fait respecter la stratégie additive (CLAUDE.md §4).
#   - zones CocoOS (console, docs, outillage…) : rien à dire
#   - couture listée dans .claude/seams.txt   : demande confirmation (ask)
#   - app/gui/main.qml, autre fichier upstream : refus (deny)
#   - nouveau fichier hors zones CocoOS        : demande confirmation (ask)
#   - branche master (miroir d'upstream)       : refus
set -u
input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -z "$f" ] && exit 0

base="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$f" in /*) abs="$f" ;; *) abs="$base/$f" ;; esac
abs=$(realpath -m "$abs")
# Racine = le dépôt (ou worktree, ex. .claude/worktrees/<nom>) qui contient VRAIMENT le fichier,
# pas forcément CLAUDE_PROJECT_DIR : sinon un worktree contournerait la règle.
d=$(dirname "$abs"); while [ ! -d "$d" ] && [ "$d" != / ]; do d=$(dirname "$d"); done
root=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0
root=$(realpath -m "$root")
case "$abs" in "$root"/*) rel="${abs#"$root"/}" ;; *) exit 0 ;; esac   # hors du repo : pas notre affaire

decide() { # $1 = allow|ask|deny, $2 = raison
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}

branch=$(git -C "$root" symbolic-ref --short -q HEAD 2>/dev/null)
if [ "$branch" = "master" ]; then
  decide deny "Branche master = miroir propre d'upstream (CLAUDE.md §4) : on n'y code jamais. Passer sur console-ui ou une branche de travail."
fi

case "$rel" in
  .claude/seams.txt|.claude/settings.json|.claude/hooks/*)
    decide ask "Fichier de garde-fous ($rel) : c'est Coco qui décide des coutures et des règles. Montrer le diff et attendre son accord." ;;
  app/gui/main.qml)
    decide deny "app/gui/main.qml est intouchable (CLAUDE.md §4). Passer par app/gui/console/ ou une couture existante." ;;
  app/gui/console/*|docs/*|.claude/*|scripts/cc/*|deploy/plymouth/*|CLAUDE.md|next_steps.md|.worktreeinclude)
    exit 0 ;;
esac

seams="$root/.claude/seams.txt"
[ -f "$seams" ] || seams="${CLAUDE_PROJECT_DIR:-$root}/.claude/seams.txt"
if [ -f "$seams" ] && grep -qxF "$rel" <(grep -v '^\s*#' "$seams"); then
  decide ask "Couture upstream ($rel) : modif strictement ADDITIVE, sous #ifdef CONSOLE_UI ou scope embedded, la plus petite possible ; montrer le diff à Coco (CLAUDE.md §4)."
fi

is_upstream=0
if git -C "$root" rev-parse -q --verify upstream/master >/dev/null 2>&1; then
  git -C "$root" cat-file -e "upstream/master:$rel" 2>/dev/null && is_upstream=1
elif git -C "$root" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
  is_upstream=1   # pas de remote upstream : tout fichier suivi hors zones CocoOS est présumé upstream
fi

if [ $is_upstream -eq 1 ]; then
  decide deny "Refusé : $rel est un fichier upstream de moonlight-qt hors des coutures admises (.claude/seams.txt). Créer plutôt un fichier neuf dans app/gui/console/. Si une nouvelle couture est vraiment nécessaire, s'arrêter et la proposer à Coco (diff, taille, justification) ; c'est lui qui l'ajoute à .claude/seams.txt."
fi

decide ask "Nouveau fichier hors des zones CocoOS ($rel). Le code console vit dans app/gui/console/ (CLAUDE.md §4) : confirmer que cet emplacement est voulu."
