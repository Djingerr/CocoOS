#!/usr/bin/env bash
# Build CocoOS à sortie FILTRÉE (pensé pour Claude Code : quelques lignes au lieu de milliers).
#   scripts/dev/build.sh                  # embedded (UI console), le cas courant
#   scripts/dev/build.sh vanilla          # Moonlight vanilla (doit rester intact)
#   scripts/dev/build.sh embedded --clean # make distclean d'abord
# Log complet : .dev/last-build.log — statut : .dev/last-build.status
set -u
for a in "$@"; do
  case "$a" in -h|--help) echo "usage: $0 [embedded|vanilla] [--clean]"; exit 0 ;; esac
done
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
blocked() {
  echo "BUILD BLOCKED ($mode) : $*" | tee "$log"
  echo "BLOCKED $mode $(date '+%F %T')" > .dev/last-build.status
  exit 2
}
[ -n "$qmake" ] || blocked "qmake6 introuvable"
command -v make >/dev/null || blocked "make introuvable"
for dep in moonlight-common-c/moonlight-common-c/CMakeLists.txt qmdnsengine/qmdnsengine/src/include/qmdnsengine/abstractserver.h app/SDL_GameControllerDB/gamecontrollerdb.txt; do
  [ -f "$dep" ] || blocked "sous-module absent : $dep ; setup.sh --submodules (réseau explicite)"
done

# ccache (sudo dnf install ccache) : recompilations et worktrees parallèles bien plus rapides.
extra=()
if command -v ccache >/dev/null; then
  extra=("QMAKE_CC=ccache gcc" "QMAKE_CXX=ccache g++")
  export CCACHE_BASEDIR="$root"   # partage du cache entre worktrees (chemins relatifs)
fi

start=$(date +%s)
(
  # Sous-shell strict : une étape échouée ne peut jamais être masquée par la suivante.
  set -e
  trap 'echo ">> étape échouée (code $?) : $BASH_COMMAND" >&2' ERR
  version=$("$qmake" -query QT_VERSION)
  [[ "$version" = 6.* ]] || { echo "Qt 6 requis, trouvé : $version"; exit 2; }
  if [ $clean -eq 1 ] && [ -f Makefile ]; then
    echo '>> make distclean'
    make distclean
  fi
  config=("CONFIG-=embedded")
  [ "$mode" != embedded ] || config=("CONFIG+=embedded")
  echo ">> qmake racine ($mode)"
  "$qmake" "${config[@]}" "${extra[@]}" moonlight-qt.pro
  # Régénérer systématiquement app : un Makefile peut être présent mais périmé.
  echo ">> qmake app ($mode)"
  # make ne suit pas les changements de -D : isoler objets ET MOC par mode.
  # Chemins relatifs (sans le chemin absolu du worktree, qui peut contenir des espaces).
  (cd app && "$qmake" "${config[@]}" "${extra[@]}" \
    "OBJECTS_DIR=../.dev/build/$mode/objects" "MOC_DIR=../.dev/build/$mode/moc" \
    "RCC_DIR=../.dev/build/$mode/rcc" "UI_DIR=../.dev/build/$mode/ui" app.pro)
  if [ "$mode" = embedded ]; then
    grep -qs -- '-DCONSOLE_UI' app/Makefile* || { echo 'CONSOLE_UI absent'; exit 3; }
  elif grep -qs -- '-DCONSOLE_UI' app/Makefile*; then
    echo 'CONSOLE_UI encore défini en vanilla'; exit 3
  fi
  touch app/qml.qrc            # rcc ne suit pas les .qml (skill cocoos-build)
  echo '>> make release'
  make release -j"$(nproc)"
) >"$log" 2>&1
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
  echo '-- contexte de la dernière étape :'
  tail -12 "$log"
  echo "BUILD FAILED ($mode, ${dur}s, code $rc) — log complet : $log"
  echo "FAILED $mode $(date '+%F %T')" > .dev/last-build.status
fi
exit $rc
