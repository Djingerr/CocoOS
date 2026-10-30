#!/usr/bin/env bash
# Build CocoOS à sortie FILTRÉE (pensé pour Claude Code : quelques lignes au lieu de milliers).
#   scripts/dev/build.sh                  # embedded (UI console), le cas courant
#   scripts/dev/build.sh vanilla          # Moonlight vanilla (doit rester intact)
#   scripts/dev/build.sh embedded --clean # make distclean d'abord
# Log complet : .dev/last-build.log — statut : .dev/last-build.status
set -u
mode=embedded; clean=0
for a in "$@"; do
  case "$a" in
    embedded|vanilla) mode=$a ;;
    --clean) clean=1 ;;
    *) echo "usage: $0 [embedded|vanilla] [--clean]" >&2; exit 64 ;;
  esac
done

root=$(git rev-parse --show-toplevel) || exit 1
cd "$root"
mkdir -p .dev
log=.dev/last-build.log
qmake=$(command -v qmake6 || command -v qmake-qt6 || true)
[ -z "$qmake" ] && { echo "BUILD FAILED : qmake6 introuvable"; exit 127; }

# ccache (sudo dnf install ccache) : recompilations et worktrees parallèles bien plus rapides.
extra=()
if command -v ccache >/dev/null; then
  extra=("QMAKE_CC=ccache gcc" "QMAKE_CXX=ccache g++")
  export CCACHE_BASEDIR="$root"   # partage du cache entre worktrees (chemins relatifs)
fi

start=$(date +%s)
{
  [ $clean -eq 1 ] && [ -f Makefile ] && make distclean
  if [ "$mode" = embedded ]; then
    "$qmake" "CONFIG+=embedded" "${extra[@]}" moonlight-qt.pro
    # Piège qmake subdirs (skill cocoos-build) : les sous-Makefiles ne sont pas régénérés.
    if ! grep -qs CONSOLE_UI app/Makefile*; then
      echo ">> CONSOLE_UI absent des Makefiles de app/ : régénération (piège subdirs)"
      (cd app && "$qmake" "CONFIG+=embedded" "${extra[@]}" app.pro)
    fi
  else
    "$qmake" "${extra[@]}" moonlight-qt.pro
    if grep -qs CONSOLE_UI app/Makefile*; then
      echo ">> Makefiles de app/ encore en embedded : régénération vanilla"
      (cd app && "$qmake" "${extra[@]}" app.pro)
    fi
  fi
  touch app/qml.qrc            # rcc ne suit pas les .qml (skill cocoos-build)
  make release -j"$(nproc)"
} >"$log" 2>&1
rc=$?
dur=$(( $(date +%s) - start ))

# Erreurs : toutes (dédoublonnées, 40 max). Avertissements : seulement ceux du code CocoOS.
grep -E 'error:|Error [0-9]+|undefined reference|No rule to make|Unknown module|cannot find -l|fatal:' "$log" \
  | sed 's#'"$root"'/##' | awk '!seen[$0]++' | head -40
cw=$(grep -E 'warning:' "$log" | grep -E 'gui/console/|CONSOLE_UI' | sed 's#'"$root"'/##' | awk '!seen[$0]++')
[ -n "$cw" ] && { echo "-- avertissements dans app/gui/console :"; echo "$cw" | head -20; }
other=$(grep -E 'warning:' "$log" | grep -vcE 'gui/console/')
[ "$other" -gt 0 ] 2>/dev/null && echo "-- ($other avertissements upstream ignorés, voir $log)"

if [ $rc -eq 0 ]; then
  if [ "$mode" = embedded ] && ! grep -q -- '-DCONSOLE_UI' "$log" && ! grep -qs CONSOLE_UI app/Makefile*; then
    echo "BUILD SUSPECT ($mode, ${dur}s) : CONSOLE_UI non défini, l'app démarrera sur PcView"
    echo "SUSPECT $mode $(date '+%F %T')" > .dev/last-build.status; exit 3
  fi
  echo "BUILD OK ($mode, ${dur}s) → ./app/moonlight"
  echo "OK $mode $(date '+%F %T')" > .dev/last-build.status
else
  echo "BUILD FAILED ($mode, ${dur}s, code $rc) — log complet : $log"
  echo "FAILED $mode $(date '+%F %T')" > .dev/last-build.status
fi
exit $rc
