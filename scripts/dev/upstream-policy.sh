#!/usr/bin/env bash
# Politique « additive-only » de CocoOS (AGENTS.md §4), indépendante de l'outil.
# Utilisée par le hook git pre-commit (toutes IA, humains) ET par le hook Claude Code.
#
#   scripts/dev/upstream-policy.sh <chemin>     → affiche UNE classe sur stdout :
#     own        zone CocoOS (console, docs, outillage) : libre
#     guard      fichier de garde-fous (coutures, hooks) : décision de Coco
#     seam       couture upstream admise (.agents/seams.txt) : additive, sous #ifdef CONSOLE_UI
#     forbidden  app/gui/main.qml : intouchable
#     upstream   autre fichier de moonlight-qt : interdit
#     new        fichier neuf hors zones CocoOS : à confirmer
#     outside    hors du dépôt
#   Le chemin peut être absolu ou relatif au répertoire courant.
set -u
case "${1:-}" in -h|--help) echo "usage: $0 <chemin> → own|guard|seam|forbidden|upstream|new|outside"; exit 0 ;; esac
[ "$#" -eq 1 ] || { echo "usage: $0 <chemin>" >&2; exit 64; }
# Dans un hook git, GIT_DIR / GIT_INDEX_FILE sont exportés et faussent `git -C <dossier>` : on les retire.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
f="${1:?usage: $0 <chemin>}"
case "$f" in /*) abs="$f" ;; *) abs="$PWD/$f" ;; esac
# Classer le chemin Git lui-même, pas la cible d'un éventuel lien symbolique.
abs=$(realpath -ms "$abs") || exit 1
d=$(dirname "$abs"); while [ ! -d "$d" ] && [ "$d" != / ]; do d=$(dirname "$d"); done
root=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || { echo outside; exit 0; }
root=$(realpath -ms "$root")
case "$abs" in "$root"/*) rel="${abs#"$root"/}" ;; *) echo outside; exit 0 ;; esac

case "$rel" in
  .agents/seams.txt|.githooks/*|.claude/settings.json|.claude/hooks/*|scripts/dev/upstream-policy.sh|\
  opencode.json|opencode.jsonc|.opencode/*)
    echo guard; exit 0 ;;
  app/gui/main.qml)
    echo forbidden; exit 0 ;;
  app/gui/console/*|docs/*|.agents/*|.claude/*|.gemini/*|scripts/dev/*|deploy/plymouth/*|\
  AGENTS.md|CLAUDE.md|GEMINI.md|next_steps.md|.aider.conf.yml|.worktreeinclude)
    echo own; exit 0 ;;
esac

seams="$root/.agents/seams.txt"
if [ -f "$seams" ] && grep -v '^[[:space:]]*#' "$seams" | grep -qxF "$rel"; then
  echo seam; exit 0
fi

if git -C "$root" rev-parse -q --verify upstream/master >/dev/null 2>&1; then
  git -C "$root" cat-file -e "upstream/master:$rel" 2>/dev/null && { echo upstream; exit 0; }
  echo new; exit 0
fi
# Sans remote upstream : considérer aussi HEAD (l'index ne contient plus les suppressions).
if git -C "$root" cat-file -e "HEAD:$rel" 2>/dev/null ||
   git -C "$root" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
  echo upstream
else
  echo new
fi
