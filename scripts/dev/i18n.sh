#!/usr/bin/env bash
# --check travaille sur une copie : aucune traduction/ressource suivie n'est modifiée.
set -u
mode=update
case "${1:-}" in
  -h|--help) echo "usage: $0 [--check|--release] (sans option : met à jour le TS)"; exit 0 ;;
  --check) mode=check ;;
  --release) mode=release ;;
  '') ;;
  *) echo "Option inconnue : $1" >&2; exit 64 ;;
esac
[ "$#" -le 1 ] || exit 64
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root/app" || exit 1
mkdir -p "$root/.dev"
log="$root/.dev/last-i18n.log"
: >"$log"
lupdate=$(command -v lupdate-qt6 || true)
if [ -z "$lupdate" ] || ! command -v python3 >/dev/null; then
  echo 'I18N BLOCKED : lupdate-qt6 et python3 requis' | tee -a "$log"; exit 2
fi
if [ "$mode" = release ]; then
  lrelease=$(command -v lrelease-qt6 || true)
  [ -n "$lrelease" ] || { echo 'I18N BLOCKED : lrelease-qt6 absent' | tee -a "$log"; exit 2; }
fi
ts=gui/console/languages/qml_en.ts
[ -f "$ts" ] || { echo "I18N BLOCKED : $ts absent" | tee -a "$log"; exit 2; }
target=$ts
if [ "$mode" = check ]; then
  tmpbase=/tmp
  if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && [ -w "$TMPDIR" ] && [ -x "$TMPDIR" ]; then
    tmpbase=$TMPDIR
  elif [ -d /tmp/opencode ] && [ -w /tmp/opencode ] && [ -x /tmp/opencode ]; then
    tmpbase=/tmp/opencode
  fi
  tmp=$(mktemp -d "$tmpbase/cocoos-i18n.XXXXXX") || exit 2
  trap 'rm -rf -- "$tmp"' EXIT
  target="$tmp/qml_en.ts"
  cp "$ts" "$target" || exit 1
fi
"$lupdate" gui/console -source-language fr -target-language en -no-obsolete -ts "$target" >>"$log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  tail -12 "$log"; echo "I18N FAILED : lupdate code $rc — $log"; exit "$rc"
fi
python3 - "$ts" "$target" "$mode" >>"$log" 2>&1 <<'PY'
import sys
import xml.etree.ElementTree as ET
original, target, mode = sys.argv[1:]
a, b = ET.parse(original).getroot(), ET.parse(target).getroot()
# Les chemins/numéros de ligne dépendent de l'emplacement de la copie temporaire.
def canonical(node):
    return (node.tag, sorted(node.attrib.items()),
            (node.text or '') if not len(node) else (node.text or '').strip(),
            [canonical(c) for c in node if c.tag != 'location'])
stale = canonical(a) != canonical(b)
unfinished = []
for message in b.findall('.//message'):
    tr = message.find('translation')
    if tr is None or tr.get('type') == 'unfinished' or not ''.join(tr.itertext()).strip():
        unfinished.append(message.findtext('source', ''))
print(f'Chaînes non traduites : {len(unfinished)}')
for text in unfinished[:30]:
    print('  - ' + text.replace('\n', ' '))
if mode == 'check' and stale:
    print('TS périmé : lancer i18n.sh puis revoir le diff.')
sys.exit(1 if mode == 'check' and (stale or unfinished) else 0)
PY
rc=$?
if [ "$rc" -eq 0 ] && [ "$mode" = release ]; then
  "$lrelease" "$ts" >>"$log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then touch qml.qrc || rc=$?; fi
fi
tail -8 "$log"
if [ "$rc" -eq 0 ]; then echo "I18N OK ($mode) — $log"; else echo "I18N FAILED ($mode, code $rc) — $log"; fi
exit "$rc"
