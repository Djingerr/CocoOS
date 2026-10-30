#!/usr/bin/env bash
# SessionStart — prépare le clone et donne à Claude un état de départ compact (stdout = contexte).
set -u
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
cd "$root" 2>/dev/null || exit 0

# 1) .git/info/exclude : artefacts de build in-source (CLAUDE.md, skill cocoos-build), idempotent.
gitdir=$(git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$gitdir" ] && ! grep -q 'cocoos-claude-exclude' "$gitdir/info/exclude" 2>/dev/null; then
  mkdir -p "$gitdir/info"
  cat >> "$gitdir/info/exclude" <<'EOF'
# cocoos-claude-exclude — qmake / make in-source build artifacts
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
# sorties des scripts scripts/cc/ et worktrees Claude
.cc/
.claude/worktrees/
.claude/settings.local.json
EOF
fi

# 2) Remote upstream (stratégie §4) : l'ajouter s'il manque, sans réseau.
git remote get-url upstream >/dev/null 2>&1 || \
  git remote add upstream https://github.com/moonlight-stream/moonlight-qt.git 2>/dev/null

# 3) État compact.
branch=$(git symbolic-ref --short -q HEAD || echo "(détaché)")
echo "[CocoOS] branche: $branch"
dirty=$(git status --porcelain | head -12)
[ -n "$dirty" ] && { echo "[CocoOS] fichiers modifiés :"; echo "$dirty"; }
if [ -f next_steps.md ]; then
  last=$(grep -E '^## ' next_steps.md | tail -1)
  [ -n "$last" ] && echo "[CocoOS] dernière section de next_steps.md : ${last#\#\# }"
fi
[ -f .cc/last-build.status ] && echo "[CocoOS] dernier build : $(cat .cc/last-build.status)"
# Worktree neuf (claude -w) : les sous-modules ne sont pas initialisés → le build échouerait.
if [ -z "$(ls -A moonlight-common-c/moonlight-common-c 2>/dev/null)" ]; then
  echo "[CocoOS] sous-modules absents (worktree neuf ?) : lancer scripts/cc/worktree-init.sh avant de compiler"
fi
exit 0
