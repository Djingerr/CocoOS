#!/usr/bin/env bash
# Contrôles d'outillage sans SDK ; --qml active un contrôle Qt6 ciblé, pas un build.
set -u
case "${1:-}" in
  -h|--help) echo "usage: $0 [--qml [fichier.qml ...]]"; echo 'Sans option : syntaxe shell + tests outillage. --qml : analyse Qt6 (défaut : console).'; exit 0 ;;
  ''|--qml) ;;
  *) echo "usage: $0 [--qml [fichier.qml ...]]" >&2; exit 64 ;;
esac
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1
mkdir -p .dev
if [ "$#" -eq 0 ]; then
  log=.dev/last-check.log
  : >"$log"
  for file in scripts/dev/*.sh .githooks/*; do
    [ -f "$file" ] || continue
    bash -n "$file" >>"$log" 2>&1 || { tail -12 "$log"; echo "CHECK FAILED : $file — $log"; exit 1; }
  done
  echo 'SHELL syntax : PASS'
  bash scripts/dev/tooling-test.sh
  exit $?
fi
shift
lint=$(command -v qmllint-qt6 || true)
if [ -z "$lint" ] || ! command -v python3 >/dev/null; then
  echo 'QML BLOCKED : qmllint-qt6 et python3 requis (Qt5 non accepté)'; exit 2
fi
files=("$@")
if [ "${#files[@]}" -eq 0 ]; then
  while IFS= read -r -d '' f; do files+=("$f"); done < <(find app/gui/console -name '*.qml' -type f -print0)
fi
[ "${#files[@]}" -gt 0 ] || { echo 'QML BLOCKED : aucun fichier'; exit 2; }
for file in "${files[@]}"; do
  [ -f "$file" ] && [[ "$file" = *.qml ]] || { echo "QML BLOCKED : fichier QML absent/invalide : $file"; exit 2; }
done
log=.dev/last-qmllint.log
json=.dev/last-qmllint.json
"$lint" --version >"$log" 2>&1 || { cat "$log"; echo 'QML BLOCKED : version qmllint indisponible'; exit 2; }
grep -qE '(^|[^0-9])6\.[0-9]+' "$log" || { echo 'QML BLOCKED : Qt6 requis'; exit 2; }
: >"$json" # Un crash/options incompatibles ne doivent pas réutiliser un ancien résultat.
"$lint" --ignore-settings --json "$json" "${files[@]}" >>"$log" 2>&1
rc=$?
# Ne pas déduire PASS du seul code qmllint (les warnings ne sont pas tous bloquants).
python3 - "$json" "$rc" <<'PY'
import json
import sys
tool_rc = int(sys.argv[2])
# Qt6 qmllint : 0 = analyse terminée, 255 = diagnostics (main retourne -1).
# Tout autre code est une exécution défaillante, même avec un JSON partiel valide.
if tool_rc not in (0, 255):
    print(f'QML BLOCKED : qmllint arrêté avec code inattendu {tool_rc} — .dev/last-qmllint.log')
    sys.exit(2)
try:
    files = json.load(open(sys.argv[1], encoding='utf-8'))['files']
    if not files:
        raise ValueError('aucun résultat')
except (OSError, ValueError, KeyError) as error:
    print(f'QML BLOCKED : résultat qmllint invalide : {error} — .dev/last-qmllint.log')
    sys.exit(2)
# Les défauts structurels restent des FAIL même si les singletons C++ sont absents.
structural = {'syntax', 'duplicate-property-binding', 'duplicated-name',
              'duplicate-inline-component', 'alias-cycle', 'inheritance-cycle',
              'invalid-lint-directive', 'component-children-count'}
semantic = {'missing-property', 'incompatible-type', 'read-only-property',
            'required', 'unresolved-alias', 'unresolved-type', 'missing-type'}
fail, blocked, advisory = [], [], 0
for file in files:
    warnings = file.get('warnings', [])
    imports = [w for w in warnings if w.get('id') == 'import'
               and ('Failed to import' in w.get('message', '') or w.get('type') == 'error')]
    for w in imports:
        blocked.append((file, w))
    for w in warnings:
        category = w.get('id', '')
        if category in structural or (w.get('type') in ('error', 'critical') and category != 'import' and not imports):
            fail.append((file, w))
        elif category in semantic and not imports:
            fail.append((file, w))
        else:
            advisory += 1
    if not file.get('success', False) and not warnings:
        blocked.append((file, {'line': 0, 'message': 'analyse incomplète sans diagnostic'}))
for file, w in (fail + blocked)[:20]:
    print(f"{file['filename']}:{w.get('line', 0)}:{w.get('column', 0)} [{w.get('id', '?')}] {w['message']}")
if fail:
    verdict, rc = 'FAIL', 1
elif blocked or (tool_rc != 0 and not any(f.get('warnings') for f in files)):
    verdict, rc = 'BLOCKED', 2
else:
    verdict, rc = 'PASS', 0
print(f'QML {verdict} ({len(files)} fichiers, {advisory} avis non bloquants) — .dev/last-qmllint.json, .dev/last-qmllint.log')
if blocked:
    print('Imports/types indisponibles : analyse sémantique incomplète ; un singleton C++ enregistré au runtime n’est pas un défaut QML prouvé.')
sys.exit(rc)
PY
