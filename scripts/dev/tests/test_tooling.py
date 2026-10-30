"""Real Git hooks in disposable repositories; no project commits or global config."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

SOURCE = Path(__file__).resolve().parents[3]


def temporary_base():
    for candidate in (os.environ.get('TMPDIR'), '/tmp/opencode'):
        if candidate and Path(candidate).is_dir() and os.access(candidate, os.W_OK | os.X_OK):
            return candidate
    return None  # tempfile sélectionne alors le temporaire système existant.


class Tooling(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='cocoos tooling ', dir=temporary_base())
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'repository with spaces'
        self.root.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1',
                        GIT_TERMINAL_PROMPT='0', TMPDIR=self.temp.name)
        for key in list(self.env):
            if key.startswith(('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_CONFIG_COUNT',
                               'GIT_CONFIG_KEY_', 'GIT_CONFIG_VALUE_', 'GIT_CONFIG_PARAMETERS')):
                self.env.pop(key)
        self.run_cmd('git', 'init', '-b', 'topic')
        self.git('config', 'user.name', 'Tooling Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        for name in ('build', 'test', 'smoke', 'i18n', 'setup', 'upstream-policy', 'check', 'tooling-test', 'status'):
            dest = self.root / f'scripts/dev/{name}.sh'
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(SOURCE / f'scripts/dev/{name}.sh', dest)
            dest.chmod(0o755)
        self.write('.agents/seams.txt', 'app/main.cpp\n')
        self.write('.githooks/pre-commit', (SOURCE / '.githooks/pre-commit').read_text(), executable=True)
        for path in ('upstream.c', 'upstream with spaces.c', 'app/main.cpp', 'app/gui/main.qml', 'app/qml.qrc'):
            self.write(path, 'original\n')
        self.git('add', '.')
        self.git('-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'baseline fixture only')
        self.git('update-ref', 'refs/remotes/upstream/master', 'HEAD')
        self.git('config', 'core.hooksPath', '.githooks')

    def run_cmd(self, *args, check=True, env=None):
        result = subprocess.run(args, cwd=self.root, env=env or self.env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout)
        return result

    def git(self, *args, **kwargs):
        return self.run_cmd('git', *args, **kwargs)

    def write(self, path, content, executable=False):
        dest = self.root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content)
        if executable:
            dest.chmod(0o755)

    def commit(self, allowed, text=''):
        self.git('add', '-A')
        result = self.git('commit', '-m', 'hook fixture only', check=False)
        self.assertEqual(result.returncode == 0, allowed, result.stdout)
        self.assertIn(text, result.stdout)

    def test_upstream_modification(self):
        self.write('upstream.c', 'changed\n')
        self.commit(False, 'upstream')

    def test_upstream_deletion(self):
        (self.root / 'upstream with spaces.c').unlink()
        self.commit(False, 'upstream with spaces.c')

    def test_deletion_without_upstream_ref(self):
        self.git('update-ref', '-d', 'refs/remotes/upstream/master')
        (self.root / 'upstream.c').unlink()
        self.commit(False, 'upstream')

    def test_upstream_rename_into_owned_zone(self):
        (self.root / 'app/gui/console').mkdir(parents=True)
        self.git('mv', 'upstream.c', 'app/gui/console/renamed.cpp')
        self.commit(False, 'upstream.c')

    def test_forbidden_rename(self):
        (self.root / 'docs').mkdir()
        self.git('mv', 'app/gui/main.qml', 'docs/renamed.qml')
        self.commit(False, 'forbidden')

    def test_forbidden_deletion(self):
        (self.root / 'app/gui/main.qml').unlink()
        self.commit(False, 'forbidden')

    def test_forbidden_modification(self):
        self.write('app/gui/main.qml', 'changed\n')
        self.commit(False, 'forbidden')

    def test_seam_additive(self):
        self.write('app/main.cpp', 'original\n#ifdef CONSOLE_UI\n// console\n#endif\n')
        self.commit(True, 'Couture additive')

    def test_seam_nonadditive(self):
        self.write('app/main.cpp', 'replacement\n')
        self.commit(False, 'non additive')

    def test_seam_deletion(self):
        (self.root / 'app/main.cpp').unlink()
        self.commit(False, 'non additive')

    def test_seam_rename(self):
        self.git('mv', 'app/main.cpp', 'app/renamed.cpp')
        self.commit(False, 'non additive')

    def test_owned_file(self):
        self.write('app/gui/console/new.qml', 'Item {}\n')
        self.commit(True)

    def test_new_file_reported(self):
        self.write('new outside zone.cpp', '// new\n')
        self.commit(True, 'Nouveau fichier')

    def test_opencode_config_classified_guard_with_or_without_upstream(self):
        for has_ref in (True, False):
            if not has_ref:
                self.git('update-ref', '-d', 'refs/remotes/upstream/master')
            for path in ('opencode.json', 'opencode.jsonc', '.opencode/permissions.json', '.opencode/nested/config.json'):
                with self.subTest(upstream=has_ref, path=path):
                    self.assertEqual(self.run_cmd('scripts/dev/upstream-policy.sh', path).stdout.strip(), 'guard')

    def test_master(self):
        self.git('branch', '-m', 'master')
        self.write('docs/fixture.md', 'new\n')
        self.commit(False, 'master')

    def test_missing_policy(self):
        (self.root / 'scripts/dev/upstream-policy.sh').unlink()
        self.commit(False, 'absente')

    def test_missing_seams(self):
        (self.root / '.agents/seams.txt').unlink()
        self.commit(False, 'absente')

    def test_invalid_policy_class(self):
        self.write('scripts/dev/upstream-policy.sh', '#!/bin/sh\necho unexpected\n', executable=True)
        self.commit(False, 'invalide')

    def test_failed_policy(self):
        self.write('scripts/dev/upstream-policy.sh', '#!/bin/sh\nexit 42\n', executable=True)
        self.commit(False, 'en échec')

    def test_guard_reported(self):
        with (self.root / '.githooks/pre-commit').open('a') as stream:
            stream.write('\n# fixture comment\n')
        self.commit(True, 'Garde-fou')

    def test_guard_deleted(self):
        # Keep the running hook; deleting the seams source is checked separately.
        self.write('.claude/hooks/guard.sh', 'guard\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'guard fixture only')
        (self.root / '.claude/hooks/guard.sh').unlink()
        self.commit(False, 'garde-fou refusé')

    def test_hook_staged_deletion(self):
        # Git ne peut appeler un hook physiquement absent : le conserver dans le worktree.
        self.git('rm', '--cached', '.githooks/pre-commit')
        self.write('docs/fixture.md', 'new\n')
        self.git('add', 'docs/fixture.md')
        result = self.git('commit', '-m', 'hook fixture only', check=False)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('100755 requis', result.stdout)

    def test_indexed_guard_executable_bit_required(self):
        for guard in ('.githooks/pre-commit', 'scripts/dev/upstream-policy.sh'):
            with self.subTest(guard=guard):
                self.git('update-index', '--chmod=-x', guard)
                self.assertTrue(os.access(self.root / guard, os.X_OK))
                result = self.git('commit', '-m', 'indexed mode fixture only', check=False)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn('100755 requis', result.stdout)
                self.assertIn(guard, result.stdout)
                self.git('update-index', '--chmod=+x', guard)

    def test_added_seam_symlink_rejected(self):
        # Une couture déclarée mais absente de HEAD ne doit pas accepter A/120000.
        with (self.root / '.agents/seams.txt').open('a') as stream:
            stream.write('app/added-seam.cpp\n')
        (self.root / 'app/added-seam.cpp').symlink_to('main.cpp')
        self.commit(False, 'non régulière')

    def test_help_has_no_side_effects(self):
        outside = Path(self.temp.name) / 'not a repository'
        outside.mkdir()
        before = self.git('status', '--porcelain').stdout
        for script in (self.root / 'scripts/dev').glob('*.sh'):
            result = subprocess.run(['bash', str(script), '--help'], cwd=outside, env=self.env,
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
            self.assertEqual(result.returncode, 0, f'{script}: {result.stdout}')
        self.assertEqual(before, self.git('status', '--porcelain').stdout)
        self.assertFalse((self.root / '.dev').exists())
        self.assertFalse(list(outside.iterdir()))

    def test_setup_offline_and_skills_preserved(self):
        self.write('.claude/skills', 'existing Windows symlink fallback\n')
        self.git('add', '.claude/skills')
        self.git('config', 'core.hooksPath', 'shared sentinel')
        real_git = shutil.which('git')
        self.fake('git', '''case "$1" in fetch|submodule) touch forbidden-network-attempt; exit 99 ;; esac
exec "''' + real_git + '" "$@"\n')
        result = self.run_cmd('bash', 'scripts/dev/setup.sh')
        self.assertIn('SETUP OK', result.stdout)
        self.assertEqual(self.git('config', '--local', '--get', 'core.hooksPath').stdout.strip(), 'shared sentinel')
        self.assertEqual(self.git('config', '--worktree', '--get', 'core.hooksPath').stdout.strip(), str(self.root / '.githooks'))
        self.assertEqual((self.root / '.claude/skills').read_text(), 'existing Windows symlink fallback\n')
        self.assertFalse(self.git('ls-files', '-v', '.claude/skills').stdout.startswith('S '))
        self.assertNotIn('upstream', self.git('remote').stdout)
        self.assertFalse((self.root / 'moonlight-common-c/moonlight-common-c').exists())
        self.assertFalse((self.root / 'forbidden-network-attempt').exists())
        self.run_cmd('bash', 'scripts/dev/setup.sh', '--quiet')
        self.assertEqual((self.root / '.git/info/exclude').read_text().count('cocoos-dev-exclude'), 1)

    def test_setup_preserves_skills_directory_and_skip_worktree(self):
        self.write('.claude/skills/user-skill/SKILL.md', 'user-owned skill\n')
        self.git('add', '.claude/skills')
        self.git('update-index', '--skip-worktree', '.claude/skills/user-skill/SKILL.md')
        before = self.git('ls-files', '-v', '.claude/skills').stdout
        self.run_cmd('bash', 'scripts/dev/setup.sh')
        self.assertEqual((self.root / '.claude/skills/user-skill/SKILL.md').read_text(), 'user-owned skill\n')
        self.assertEqual(self.git('ls-files', '-v', '.claude/skills').stdout, before)

    def test_setup_linked_worktree_isolation(self):
        self.git('config', 'core.hooksPath', 'shared sentinel')
        other = Path(self.temp.name) / 'other worktree'
        self.git('worktree', 'add', '-b', 'other', str(other))
        result = subprocess.run(['bash', 'scripts/dev/setup.sh'], cwd=other, env=self.env,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.git('config', '--local', '--get', 'core.hooksPath').stdout.strip(), 'shared sentinel')
        self.assertEqual(self.git('config', '--get', 'core.hooksPath').stdout.strip(), 'shared sentinel')
        result = self.git('-C', str(other), 'config', '--worktree', '--get', 'core.hooksPath')
        self.assertEqual(result.stdout.strip(), str(other / '.githooks'))

    def test_setup_blocks_dormant_main_config(self):
        dormant = self.root / '.git/config.worktree'
        dormant.write_text('[core]\n\thooksPath = dormant sentinel\n')
        before = (self.root / '.git/config').read_bytes()
        result = self.run_cmd('bash', 'scripts/dev/setup.sh', check=False)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('config.worktree dormant', result.stdout)
        self.assertEqual((self.root / '.git/config').read_bytes(), before)
        self.assertEqual(dormant.read_text(), '[core]\n\thooksPath = dormant sentinel\n')

    def test_setup_blocks_dormant_sibling_config(self):
        other = Path(self.temp.name) / 'neighbor worktree'
        self.git('worktree', 'add', '-b', 'neighbor', str(other))
        gitdir = Path(self.git('-C', str(other), 'rev-parse', '--absolute-git-dir').stdout.strip())
        dormant = gitdir / 'config.worktree'
        dormant.write_text('[core]\n\thooksPath = dormant neighbor\n')
        self.git('config', 'extensions.worktreeConfig', 'false')
        before = (self.root / '.git/config').read_bytes()
        result = self.run_cmd('bash', 'scripts/dev/setup.sh', check=False)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('config.worktree dormant', result.stdout)
        self.assertEqual((self.root / '.git/config').read_bytes(), before)
        self.assertEqual(dormant.read_text(), '[core]\n\thooksPath = dormant neighbor\n')

    def test_setup_enabled_extension_preserves_neighbor_config(self):
        other = Path(self.temp.name) / 'neighbor worktree'
        self.git('worktree', 'add', '-b', 'neighbor', str(other))
        self.git('config', 'extensions.worktreeConfig', 'true')
        self.git('-C', str(other), 'config', '--worktree', 'core.hooksPath', 'neighbor sentinel')
        gitdir = Path(self.git('-C', str(other), 'rev-parse', '--absolute-git-dir').stdout.strip())
        before_common = (self.root / '.git/config').read_bytes()
        before_neighbor = (gitdir / 'config.worktree').read_bytes()
        self.run_cmd('bash', 'scripts/dev/setup.sh')
        self.assertEqual((self.root / '.git/config').read_bytes(), before_common)
        self.assertEqual((gitdir / 'config.worktree').read_bytes(), before_neighbor)

    def test_setup_invalid_boolean_flags_blocked(self):
        real_git = shutil.which('git')
        for flag in ('core.bare', 'extensions.worktreeConfig'):
            with self.subTest(flag=flag):
                self.fake('git', '''if [ "$*" = 'config --local --bool --get-all ''' + flag + '''' ]; then echo 'invalid boolean' >&2; exit 128; fi
exec "''' + real_git + '" "$@"\n')
                before = (self.root / '.git/config').read_bytes()
                result = self.run_cmd('bash', 'scripts/dev/setup.sh', check=False)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertEqual((self.root / '.git/config').read_bytes(), before)

    def test_setup_valid_boolean_spellings(self):
        self.git('config', 'core.bare', 'no')
        self.git('config', 'extensions.worktreeConfig', 'off')
        self.run_cmd('bash', 'scripts/dev/setup.sh')
        self.assertEqual(self.git('config', '--local', '--bool', '--get', 'core.bare').stdout.strip(), 'false')
        self.assertEqual(self.git('config', '--local', '--bool', '--get', 'extensions.worktreeConfig').stdout.strip(), 'true')

    def test_setup_migrates_existing_exclude_marker(self):
        exclude = self.root / '.git/info/exclude'
        exclude.write_text('# cocoos-dev-exclude old\n.dev/\nuser pattern without newline')
        self.run_cmd('bash', 'scripts/dev/setup.sh')
        first = exclude.read_bytes()
        self.run_cmd('bash', 'scripts/dev/setup.sh')
        self.assertEqual(exclude.read_bytes(), first)
        lines = exclude.read_text().splitlines()
        for pattern in ('.dev/', '.worktrees/', '.claude/worktrees/', 'Makefile', 'app/moonlight', 'user pattern without newline'):
            self.assertEqual(lines.count(pattern), 1, lines)

    def test_status_resolves_relative_and_absolute_hook_paths(self):
        for path in ('.githooks', './.githooks', str(self.root / '.githooks'), str(self.root / 'app/../.githooks')):
            with self.subTest(path=path):
                self.git('config', 'core.hooksPath', path)
                result = self.run_cmd('bash', 'scripts/dev/status.sh')
                self.assertNotIn('garde-fous git inactifs', result.stdout)
                self.assertIn('setup.sh --submodules', result.stdout)
        self.git('config', 'core.hooksPath', 'elsewhere')
        self.assertIn('garde-fous git inactifs', self.run_cmd('bash', 'scripts/dev/status.sh').stdout)

    def test_setup_unsafe_core_worktree(self):
        self.git('config', 'core.worktree', str(self.root))
        self.git('config', 'core.hooksPath', 'shared sentinel')
        result = self.run_cmd('bash', 'scripts/dev/setup.sh', check=False)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('core.bare/core.worktree', result.stdout)
        self.assertEqual(self.git('config', '--get', 'core.hooksPath').stdout.strip(), 'shared sentinel')
        self.assertNotEqual(self.git('config', '--local', '--get', 'extensions.worktreeConfig', check=False).stdout.strip(), 'true')

    def test_setup_unsafe_core_bare(self):
        # Simuler la config commune sensible sans rendre le dépôt de fixture inaccessible.
        real_git = shutil.which('git')
        self.fake('git', '''if [ "$*" = 'config --local --bool --get-all core.bare' ]; then echo true; exit 0; fi
exec "''' + real_git + '" "$@"\n')
        result = self.run_cmd('bash', 'scripts/dev/setup.sh', check=False)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('core.bare/core.worktree', result.stdout)
        self.assertNotEqual(self.git('config', '--local', '--get', 'extensions.worktreeConfig', check=False).stdout.strip(), 'true')

    def fake(self, tool, body):
        self.write(f'bin/{tool}', '#!/usr/bin/env bash\n' + body, executable=True)
        self.env['PATH'] = str(self.root / 'bin') + os.pathsep + os.environ['PATH']

    def build_dependencies(self):
        for path in ('moonlight-common-c/moonlight-common-c/CMakeLists.txt',
                     'qmdnsengine/qmdnsengine/src/include/qmdnsengine/abstractserver.h',
                     'app/SDL_GameControllerDB/gamecontrollerdb.txt'):
            self.write(path, 'fixture\n')

    def test_qmake_failure_not_masked(self):
        self.build_dependencies()
        self.fake('qmake6', 'if [ "${1:-}" = -query ]; then echo 6.10.0; exit 0; fi\necho qmake-failure-context; exit 42\n')
        self.fake('make', 'touch make-was-run; exit 0\n')
        result = self.run_cmd('bash', 'scripts/dev/build.sh', check=False)
        self.assertEqual(result.returncode, 42, result.stdout)
        self.assertIn('qmake-failure-context', result.stdout)
        self.assertFalse((self.root / 'make-was-run').exists())

    def test_app_qmake_failure_not_masked(self):
        self.build_dependencies()
        self.fake('qmake6', 'if [ "${1:-}" = -query ]; then echo 6.10.0; exit 0; fi\nif [ "${PWD##*/}" = app ]; then echo app-qmake-failure; exit 43; fi\nexit 0\n')
        self.fake('make', 'touch make-was-run; exit 0\n')
        result = self.run_cmd('bash', 'scripts/dev/build.sh', check=False)
        self.assertEqual(result.returncode, 43, result.stdout)
        self.assertIn('app-qmake-failure', result.stdout)
        self.assertFalse((self.root / 'make-was-run').exists())

    def test_modes_incremental(self):
        self.build_dependencies()
        self.fake('qmake6', '''if [ "${1:-}" = -query ]; then echo 6.10.0; exit 0; fi
echo "$PWD $*" >> "$PWD/qmake-calls"
if [ "${PWD##*/}" = app ]; then
  case "$*" in *CONFIG+=embedded*) echo 'DEFINES = -DCONSOLE_UI' > Makefile ;;
    *) echo 'DEFINES = -DQT_CORE_LIB' > Makefile ;; esac
fi
''')
        self.fake('make', 'echo "$*" >> make-calls; exit 0\n')
        for mode in ('embedded', 'embedded', 'vanilla', 'vanilla', 'embedded'):
            result = self.run_cmd('bash', 'scripts/dev/build.sh', mode)
            self.assertIn('BUILD OK', result.stdout)
            self.assertEqual('CONSOLE_UI' in (self.root / 'app/Makefile').read_text(), mode == 'embedded')
        self.assertEqual(len((self.root / 'app/qmake-calls').read_text().splitlines()), 5)
        calls = (self.root / 'app/qmake-calls').read_text()
        for mode in ('embedded', 'vanilla'):
            for kind, folder in (('OBJECTS', 'objects'), ('MOC', 'moc'), ('RCC', 'rcc'), ('UI', 'ui')):
                self.assertIn(f'{kind}_DIR=../.dev/build/{mode}/{folder}', calls)
        self.assertNotIn('distclean', (self.root / 'make-calls').read_text())

    def test_distclean_failure(self):
        self.build_dependencies()
        self.write('Makefile', 'fixture\n')
        self.fake('qmake6', 'echo 6.10.0\n')
        self.fake('make', 'echo clean-context; exit 44\n')
        result = self.run_cmd('bash', 'scripts/dev/build.sh', '--clean', check=False)
        self.assertEqual(result.returncode, 44, result.stdout)
        self.assertIn('clean-context', result.stdout)

    def test_missing_tests_blocked(self):
        self.fake('qmltestrunner-qt6', 'echo fake-runner\n')
        result = self.run_cmd('bash', 'scripts/dev/test.sh', check=False)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('BLOCKED', result.stdout)

    def test_runner_success_without_totals_not_pass(self):
        self.write('docs/ui/ambiant/harness/tst_Fixture.qml', 'import QtTest\nTestCase {}\n')
        self.fake('qmltestrunner-qt6', 'echo no-tests-executed; exit 0\n')
        result = self.run_cmd('bash', 'scripts/dev/test.sh', check=False)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn('TESTS OK', result.stdout)

    def test_unshare_blocked(self):
        self.write('app/moonlight', '#!/bin/sh\ntouch application-ran\n', executable=True)
        self.fake('unshare', 'echo isolation-denied; exit 1\n')
        result = self.run_cmd('bash', 'scripts/dev/smoke.sh', '1', check=False)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('BLOCKED', result.stdout)
        self.assertFalse((self.root / 'application-ran').exists())

    def test_unshare_failure_after_preflight_blocked(self):
        self.write('app/moonlight', '#!/bin/sh\ntouch application-ran\n', executable=True)
        self.fake('unshare', 'if [ "$2" = true ]; then exit 0; fi\necho "unshare: Operation not permitted"; exit 1\n')
        result = self.run_cmd('bash', 'scripts/dev/smoke.sh', '1', check=False)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertFalse((self.root / 'application-ran').exists())

    def test_smoke_early_clean_exit_not_pass(self):
        self.write('app/moonlight', '#!/bin/sh\necho "[console-ui] started"\nexit 0\n', executable=True)
        self.fake('unshare', 'shift; exec "$@"\n')
        result = self.run_cmd('bash', 'scripts/dev/smoke.sh', '1', check=False)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('SMOKE FAILED', result.stdout)

    def test_temp_fallback_when_both_preferred_directories_absent(self):
        # Simuler /tmp/opencode absent sans supprimer/renommer le répertoire de l'hôte.
        self.write('test-bash-env', '''function [() {
  if [[ "${1:-}" == -d && "${2:-}" == /tmp/opencode ]]; then return 1; fi
  builtin [ "$@"
}
''')
        self.env['BASH_ENV'] = str(self.root / 'test-bash-env')
        missing = Path(self.temp.name) / 'missing TMPDIR'
        self.env['TMPDIR'] = str(missing)
        real_mktemp = shutil.which('mktemp')
        self.fake('mktemp', 'printf "%s\\n" "$*" >> "' + str(self.root / 'temp-choices') + '"\nexec "' + real_mktemp + '" "$@"\n')
        self.write('docs/fixture.md', 'owned\n')
        self.commit(True)
        self.write('docs/ui/ambiant/harness/tst_Temp.qml', 'fixture\n')
        self.fake('qmltestrunner-qt6', 'echo "Totals: 1 passed, 0 failed, 0 skipped"\n')
        self.run_cmd('bash', 'scripts/dev/test.sh')
        self.write('app/gui/console/languages/qml_en.ts', '<TS/>')
        self.fake('lupdate-qt6', 'exit 0\n')
        self.run_cmd('bash', 'scripts/dev/i18n.sh', '--check')
        self.write('app/moonlight', '#!/bin/sh\necho "[console-ui] started"\n', executable=True)
        self.fake('unshare', 'shift; exec "$@"\n')
        self.fake('timeout', 'shift; "$@"; exit 124\n')
        self.run_cmd('bash', 'scripts/dev/smoke.sh', '1')
        choices = (self.root / 'temp-choices').read_text().splitlines()
        for kind in ('hook', 'test', 'i18n', 'smoke'):
            self.assertTrue(any(f'/tmp/cocoos-{kind}.' in line for line in choices), choices)
        self.assertFalse(missing.exists())

    def test_python_temp_base_falls_back_without_creating_directory(self):
        original = Path.is_dir
        with mock.patch.dict(os.environ, {'TMPDIR': str(self.root / 'missing')}), \
             mock.patch.object(Path, 'is_dir', lambda path: False if str(path) == '/tmp/opencode' else original(path)):
            self.assertIsNone(temporary_base())
        self.assertFalse((self.root / 'missing').exists())

    def test_i18n_check_readonly(self):
        self.write('app/gui/console/languages/qml_en.ts', '<TS><context><name>Fixture</name><message><source>Bonjour</source><translation>Hello</translation></message></context></TS>')
        before = (self.root / 'app/gui/console/languages/qml_en.ts').read_bytes()
        self.fake('lupdate-qt6', 'exit 0\n')
        result = self.run_cmd('bash', 'scripts/dev/i18n.sh', '--check')
        self.assertIn('I18N OK', result.stdout)
        self.assertEqual(before, (self.root / 'app/gui/console/languages/qml_en.ts').read_bytes())
        self.assertFalse((self.root / 'app/gui/console/languages/qml_en.qm').exists())

    def test_lupdate_failure_not_masked(self):
        self.write('app/gui/console/languages/qml_en.ts', '<TS/>')
        self.fake('lupdate-qt6', 'echo lupdate-context; exit 45\n')
        result = self.run_cmd('bash', 'scripts/dev/i18n.sh', '--check', check=False)
        self.assertEqual(result.returncode, 45, result.stdout)
        self.assertIn('lupdate-context', result.stdout)

    def test_i18n_stale_and_unfinished_readonly(self):
        original = '<TS><context><name>Fixture</name></context></TS>'
        self.write('app/gui/console/languages/qml_en.ts', original)
        self.fake('lupdate-qt6', '''for arg in "$@"; do last=$arg; done
echo '<TS><context><name>Fixture</name><message><source>Bonjour</source><translation type="unfinished"/></message></context></TS>' > "$last"
''')
        result = self.run_cmd('bash', 'scripts/dev/i18n.sh', '--check', check=False)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('TS périmé', result.stdout)
        self.assertEqual((self.root / 'app/gui/console/languages/qml_en.ts').read_text(), original)

    def test_lrelease_failure_not_masked(self):
        self.write('app/gui/console/languages/qml_en.ts', '<TS/>')
        before = (self.root / 'app/qml.qrc').stat().st_mtime_ns
        self.fake('lupdate-qt6', 'exit 0\n')
        self.fake('lrelease-qt6', 'echo lrelease-context; exit 46\n')
        result = self.run_cmd('bash', 'scripts/dev/i18n.sh', '--release', check=False)
        self.assertEqual(result.returncode, 46, result.stdout)
        self.assertIn('lrelease-context', result.stdout)
        self.assertEqual((self.root / 'app/qml.qrc').stat().st_mtime_ns, before)

    def lint_fixture(self, warnings, expected, tool_rc=0):
        self.write('app/gui/console/Fixture.qml', 'import QtQuick\nItem {}\n')
        data = json.dumps({'files': [{'filename': 'Fixture.qml', 'success': not warnings, 'warnings': warnings}]})
        self.fake('qmllint-qt6', '''if [ "${1:-}" = --version ]; then echo 'qmllint 6.10.0'; exit 0; fi
while [ "$#" -gt 0 ]; do
  if [ "$1" = --json ]; then shift; target=$1; break; fi
  shift
done
cat > "$target" <<'JSON'
''' + data + '\nJSON\nexit ' + str(tool_rc) + '\n')
        result = self.run_cmd('bash', 'scripts/dev/check.sh', '--qml', 'app/gui/console/Fixture.qml', check=False)
        self.assertEqual(result.returncode, expected, result.stdout)
        return result

    def test_lint_missing_cpp_import_blocked(self):
        result = self.lint_fixture([{'id': 'import', 'type': 'warning', 'line': 1,
                                     'message': 'Failed to import ComputerModel.'}], 2)
        self.assertIn('BLOCKED', result.stdout)

    def test_lint_syntax_error_with_missing_import_fails(self):
        result = self.lint_fixture([{'id': 'import', 'type': 'warning', 'line': 1,
                                     'message': 'Failed to import ComputerModel.'},
                                    {'id': 'syntax', 'type': 'error', 'line': 3,
                                     'message': 'Expected token }'}], 1)
        self.assertIn('QML FAIL', result.stdout)

    def test_lint_real_semantic_defect_fails(self):
        self.lint_fixture([{'id': 'missing-property', 'type': 'warning', 'line': 2,
                            'message': 'Binding assigned to a non-existent property'}], 1)

    def test_lint_advisory_not_false_failure(self):
        self.lint_fixture([{'id': 'unqualified', 'type': 'warning', 'line': 2,
                            'message': 'Unqualified access'}], 0)

    def test_lint_crash_with_valid_json_never_passes(self):
        for rc in (1, 42, 134, 139, 143):
            with self.subTest(code=rc):
                result = self.lint_fixture([{'id': 'unqualified', 'type': 'warning', 'line': 2,
                                             'message': 'Unqualified access'}], 2, tool_rc=rc)
                self.assertIn('code inattendu', result.stdout)

    def test_lint_expected_diagnostics_exit_code(self):
        self.lint_fixture([{'id': 'unqualified', 'type': 'warning', 'line': 2,
                            'message': 'Unqualified access'}], 0, tool_rc=255)

    def test_lint_crash_does_not_reuse_old_json(self):
        self.write('app/gui/console/Fixture.qml', 'import QtQuick\nItem {}\n')
        self.write('.dev/last-qmllint.json', '{"files":[{"filename":"old.qml","success":true,"warnings":[]}]}')
        self.fake('qmllint-qt6', 'if [ "${1:-}" = --version ]; then echo "qmllint 6.10.0"; exit 0; fi\nexit 42\n')
        result = self.run_cmd('bash', 'scripts/dev/check.sh', '--qml', 'app/gui/console/Fixture.qml', check=False)
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('BLOCKED', result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
