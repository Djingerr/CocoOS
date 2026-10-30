#!/usr/bin/env bash
# Mise en place d'un clone ou d'un worktree CocoOS — à lancer une fois, quel que soit l'outil (ou l'IA).
#   scripts/dev/setup.sh            # tout
#   scripts/dev/setup.sh --quiet    # idem sans messages (utilisé par le hook SessionStart de Claude Code)
# Idempotent : relançable sans risque.
set -u
q=0; [ "${1:-}" = "--quiet" ] && q=1
say() { [ $q -eq 1 ] || echo "$@"; }
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root"

# 1) Garde-fou commun à toutes les IA : hooks git versionnés (.githooks/pre-commit).
if [ "$(git config core.hooksPath)" != ".githooks" ]; then
  git config core.hooksPath .githooks && say "✓ hooks git activés (.githooks/pre-commit)"
fi

# 2) Artefacts de build in-source ignorés localement, sans toucher au .gitignore upstream (AGENTS.md §4).
gitdir=$(git rev-parse --git-common-dir)
if ! grep -q 'cocoos-dev-exclude' "$gitdir/info/exclude" 2>/dev/null; then
  mkdir -p "$gitdir/info"
  cat >> "$gitdir/info/exclude" <<'EOF'
# cocoos-dev-exclude — qmake / make in-source build artifacts
Makefile
Makefile.Debug
Makefile.Release
release/
debug/
.qmake.cache
.qmake.stash
*.o
*.a
config.log
app/moonlight
config.tests/*/EGL
# sorties de scripts/dev/, réglages et worktrees locaux des outils d'IA
.dev/
.claude/worktrees/
.claude/settings.local.json
.aider*
!.aider.conf.yml
EOF
  say "✓ .git/info/exclude complété"
fi

# 3) Remote upstream (moonlight-qt officiel), nécessaire à la politique additive et à la synchro.
if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/moonlight-stream/moonlight-qt.git && say "✓ remote upstream ajouté"
fi
if ! git rev-parse -q --verify upstream/master >/dev/null; then
  say "… git fetch upstream master (une fois, pour que la politique reconnaisse les fichiers upstream)"
  timeout 120 git fetch -q --depth 1 upstream master 2>/dev/null || say "  (hors ligne : réessayer plus tard)"
fi

# 4) Sous-modules (absents dans un worktree neuf).
if [ -z "$(ls -A moonlight-common-c/moonlight-common-c 2>/dev/null)" ]; then
  say "… sous-modules"
  git submodule update --init --recursive --depth 1 >/dev/null 2>&1 || say "  ⚠ échec des sous-modules (réseau ?)"
fi

# 5) Outils attendus par les scripts.
missing=""
for t in jq qmake6 qmltestrunner-qt6 ccache; do command -v "$t" >/dev/null || missing="$missing $t"; done
[ -n "$missing" ] && say "ℹ outils absents :$missing (Fedora : sudo dnf install jq ccache qt6-qtbase-devel qt6-qtdeclarative-devel)"
# Skills pour Claude Code : .claude/skills est un lien vers .agents/skills. Si ce poste a les liens
# symboliques désactivés (Windows par défaut), git l'extrait comme un petit fichier texte : on le remplace
# par une copie (marquée skip-worktree pour ne pas salir git status), resynchronisée à chaque setup.
if [ ! -L .claude/skills ] && { [ -f .claude/skills ] || git ls-files -v .claude/skills | grep -q '^S'; }; then
  git update-index --skip-worktree .claude/skills 2>/dev/null
  rm -rf .claude/skills && cp -r .agents/skills .claude/skills && say "✓ .claude/skills recopié depuis .agents/skills (liens symboliques désactivés)"
fi
exit 0
