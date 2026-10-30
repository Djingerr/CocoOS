#!/usr/bin/env bash
# Setup hors ligne par défaut ; aucune copie/destruction de skills ou skip-worktree.
set -u
q=0; fetch=0; submodules=0
for a in "$@"; do
  case "$a" in
    -h|--help)
      echo "usage: $0 [--quiet] [--fetch-upstream] [--submodules]"
      echo 'Hors ligne par défaut. Les deux derniers flags autorisent explicitement le réseau.'
      echo 'Hooks : configuration worktree uniquement ; aucun fallback automatique.'
      exit 0 ;;
  esac
done
for a in "$@"; do
  case "$a" in
    --quiet) q=1 ;;
    --fetch-upstream) fetch=1 ;;
    --submodules) submodules=1 ;;
    *) echo "Option inconnue : $a" >&2; exit 64 ;;
  esac
done
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1
mkdir -p .dev
log=.dev/last-setup.log
: >"$log"
say() { echo "$*" >>"$log"; if [ "$q" -eq 0 ]; then echo "$*"; fi; }
blocked=0
block() { blocked=1; echo "SETUP BLOCKED : $*" >&2; echo "SETUP BLOCKED : $*" >>"$log"; }

# Même préflight que HostCompanion configure_hooks : aucun paramètre commun sensible
# ni config.worktree dormant ne doit être activé implicitement pour un voisin.
configure_hooks() {
  local worktree bare enabled rc dormant
  worktree=$(git config --local --get-all core.worktree 2>>"$log"); rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then block 'core.worktree illisible ; aucun hooksPath modifié.'; return; fi
  if [ "$rc" -eq 0 ]; then block 'core.bare/core.worktree communs non sûrs ; migration manuelle requise.'; return; fi
  bare=$(git config --local --bool --get-all core.bare 2>>"$log"); rc=$?
  if { [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; } || { [ "$rc" -eq 0 ] && [ "$bare" != false ]; }; then
    block 'core.bare/core.worktree communs non sûrs ou booléen invalide ; migration manuelle requise.'; return
  fi
  enabled=$(git config --local --bool --get-all extensions.worktreeConfig 2>>"$log"); rc=$?
  if { [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; } ||
     { [ "$rc" -eq 0 ] && [ "$enabled" != true ] && [ "$enabled" != false ]; }; then
    block 'extensions.worktreeConfig illisible/invalide ; aucun hooksPath modifié.'; return
  fi
  if [ "$enabled" != true ]; then
    for dormant in "$gitdir/config.worktree" "$gitdir"/worktrees/*/config.worktree; do
      if [ -e "$dormant" ] || [ -L "$dormant" ]; then
        block "config.worktree dormant : $dormant ; revue/migration manuelle requise avant activation."; return
      fi
    done
  fi
  for guard in .githooks/pre-commit scripts/dev/upstream-policy.sh; do
    if [ ! -f "$guard" ] || [ -L "$guard" ] || [ ! -x "$guard" ]; then
      block "garde-fou absent/non régulier/non exécutable : $guard"; return
    fi
  done
  if [ "$enabled" != true ] && ! git config --local extensions.worktreeConfig true >>"$log" 2>&1; then
    block 'Activation worktreeConfig impossible ; aucun fallback partagé.'; return
  fi
  if git config --worktree core.hooksPath "$root/.githooks" >>"$log" 2>&1; then
    say '✓ hooks isolés dans la configuration de ce worktree (core.hooksPath commun inchangé).'
  else
    block 'Git ne permet pas les hooks isolés ; aucun fallback partagé. Demander une décision explicite.'
  fi
}
gitdir=$(git rev-parse --git-common-dir) || exit 1
configure_hooks

# Exclude est partagé par Git entre worktrees, uniquement des artefacts sans source.
mkdir -p "$gitdir/info" || exit 1
exclude="$gitdir/info/exclude"
if ! grep -q 'cocoos-dev-exclude' "$gitdir/info/exclude" 2>/dev/null; then
  printf '\n%s\n' '# cocoos-dev-exclude — artefacts locaux (partagés entre worktrees)' >>"$exclude" || exit 1
fi
# Le marqueur n'est pas une version : migrer aussi les anciens clones motif par motif.
while IFS= read -r pattern; do
  if ! grep -qxF -- "$pattern" "$exclude"; then
    # Préserver un éventuel dernier motif utilisateur sans saut de ligne final.
    [ -z "$(tail -c 1 "$exclude")" ] || printf '\n' >>"$exclude"
    printf '%s\n' "$pattern" >>"$exclude" || exit 1
  fi
done <<'EOF'
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
.dev/
.worktrees/
.claude/worktrees/
.claude/settings.local.json
.aider*
!.aider.conf.yml
EOF
say '✓ info/exclude vérifié (motifs manquants ajoutés individuellement).'

if [ "$fetch" -eq 1 ]; then
  if ! git remote get-url upstream >>"$log" 2>&1; then
    git remote add upstream https://github.com/moonlight-stream/moonlight-qt.git >>"$log" 2>&1 || exit 1
  fi
  if ! timeout 120 git fetch upstream master >>"$log" 2>&1; then block "fetch upstream échoué — $log"; fi
elif ! git rev-parse -q --verify refs/remotes/upstream/master >/dev/null; then
  say 'ℹ upstream/master absent : politique conservatrice, fetch uniquement avec --fetch-upstream.'
fi
if [ "$submodules" -eq 1 ]; then
  if ! timeout 300 git submodule update --init --recursive >>"$log" 2>&1; then block "sous-modules incomplets — $log"; fi
else
  say 'ℹ aucun sous-module initialisé automatiquement (opt-in : --submodules).'
fi
if [ ! -L .claude/skills ]; then
  say 'ℹ .claude/skills non symbolique : préservé tel quel ; demander avant tout fallback/copie.'
fi
for tool in qmake6 qmltestrunner-qt6 qmllint-qt6; do
  command -v "$tool" >/dev/null || say "ℹ outil absent : $tool (aucune installation automatique)."
done
if [ "$blocked" -eq 1 ]; then exit 2; fi
say "SETUP OK (logs : $log)"
