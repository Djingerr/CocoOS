#!/usr/bin/env python3
"""Tests cockpit : vrais tmux/Git, socket privé, faux CLI IA, aucun modèle."""
import json
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

sys.dont_write_bytecode = True
from memory import draft, START, END

SOURCE = Path(__file__).resolve().parent


@unittest.skipUnless(shutil.which("tmux") and shutil.which("git"), "Git/tmux requis")
class CockpitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp/opencode" if Path("/tmp/opencode").exists() else None)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "product with spaces"
        self.trees = Path(self.temp.name) / "worktrees with spaces"
        self.socket = "cockpit-test-" + uuid.uuid4().hex
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_") and k != "TMUX"}
        self.env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1", TERM="xterm-256color",
                        PYTHONDONTWRITEBYTECODE="1")
        tools = Path(self.temp.name) / "tools"
        tools.mkdir()
        for name in ("opencode", "agy", "node", "npm", "dotnet", "qmake6", "qmllint-qt6"):
            tool = tools / name
            tool.write_text('#!/bin/sh\ncase "$1" in --version|-v|--list-sdks) echo fixture-version;; service) echo http://127.0.0.1:49374;; plugin) echo fixture-plugin;; remote-control) echo "Daemon status: inactive";; *) echo unexpected >> "' + str(Path(self.temp.name) / "agent-started") + '";; esac\n')
            tool.chmod(0o755)
        self.env["PATH"] = str(tools) + os.pathsep + self.env["PATH"]
        for project in ("CocoOS", "HostCompanion"):
            repo = self.root / project
            repo.mkdir(parents=True)
            self.cmd(["git", "init", "-q", "-b", "tooling/environment-finalisation", str(repo)])
            self.cmd(["git", "-C", str(repo), "config", "user.name", "Cockpit fixture"])
            self.cmd(["git", "-C", str(repo), "config", "user.email", "fixture@example.invalid"])
            self.write(repo, "AGENTS.md", "fixture instructions\n")
            self.write(repo, "CLAUDE.md", "@AGENTS.md\n")
            self.write(repo, ".agents/skills/session-memory/SKILL.md", "fixture skill\n")
            self.write(repo, "docs/ai/decisions/README.md", "fixture decision\n")
            self.write(repo, ".agents/seams.txt" if project == "CocoOS" else "docs/protocol.md", "fixture\n")
            roadmap = "next_steps.md" if project == "CocoOS" else "docs/ai/ROADMAP.md"
            self.write(repo, roadmap, START + "\nNext fixture\n" + END)
            self.write(repo, "docs/ai/HANDOFF.md", draft(project, "tooling/environment-finalisation", "0" * 40, roadmap).replace("TODO", "À vérifier"))
            self.write(repo, "scripts/dev/memory.py", (SOURCE / "memory.py").read_text())
            self.write(repo, "scripts/dev/setup.sh", '#!/bin/sh\ngit config --local extensions.worktreeConfig true\ngit config --worktree core.hooksPath .githooks\n')
            hook = self.write(repo, ".githooks/pre-commit", "#!/bin/sh\nexit 0\n")
            hook.chmod(0o755)
            self.cmd(["git", "-C", str(repo), "add", "."])
            self.cmd(["git", "-C", str(repo), "commit", "-qm", "fixture"])
        self.cmd(["tmux", "-L", self.socket, "-f", os.devnull, "new-session", "-d", "-s", "sentinel"])
        self.addCleanup(lambda: self.cmd(["tmux", "-L", self.socket, "kill-server"], check=False))
        self.cmd(["tmux", "-L", self.socket, "set-option", "-g", "base-index", "7"])

    def write(self, root, name, text):
        file = root / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)
        return file

    def cmd(self, command, check=True):
        result = subprocess.run(command, env=self.env, capture_output=True, text=True, timeout=40)
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def command(self, *args):
        return [sys.executable, str(SOURCE / "fleet.py"), "cockpit", "--root", str(self.root),
                "--worktrees", str(self.trees), "--socket", self.socket, *args]

    def cli(self, *args, check=True):
        return self.cmd(self.command(*args), check=check)

    def windows(self):
        return self.cmd(["tmux", "-L", self.socket, "list-windows", "-t", "=console-diy", "-F", "#{window_id}:#{window_name}"]).stdout

    def test_help_and_invalid_args_no_side_effect(self):
        self.cli("--help")
        self.cli("--invalid", check=False)
        self.assertFalse(self.trees.exists())
        self.assertFalse((self.root / ".ai-fleet").exists())

    def test_nonterminal_refused_before_creation(self):
        self.assertNotEqual(self.cli(check=False).returncode, 0)
        self.assertFalse(self.trees.exists())

    def test_create_reopen_unique_worktrees_no_agent(self):
        self.cli("--create-only")
        before = self.windows()
        self.cli("--create-only")
        self.assertEqual(before, self.windows())
        self.assertEqual(len(before.splitlines()), 6)
        dirs = self.cmd(["tmux", "-L", self.socket, "list-panes", "-s", "-t", "=console-diy", "-F", "#{window_name}\t#{pane_current_path}"]).stdout
        for lane in ("coco-opencode", "coco-antigravity", "host-opencode", "host-antigravity"):
            self.assertIn(str(self.trees / lane), dirs)
        self.assertFalse((Path(self.temp.name) / "agent-started").exists())
        self.cmd(["tmux", "-L", self.socket, "has-session", "-t", "=sentinel"])

    def test_bad_repository_preflight_no_partial_creation(self):
        wrong = self.trees / "host-antigravity"
        wrong.mkdir(parents=True)
        self.write(wrong, "preserve.txt", "user data")
        self.assertNotEqual(self.cli("--create-only", check=False).returncode, 0)
        self.assertFalse((self.trees / "coco-opencode").exists())
        self.assertEqual((wrong / "preserve.txt").read_text(), "user data")

    def test_missing_base_no_side_effect(self):
        self.assertNotEqual(self.cli("--base", "absent", "--create-only", check=False).returncode, 0)
        self.assertFalse(self.trees.exists())

    def test_existing_worktree_missing_memory_refused(self):
        path = self.trees / "coco-opencode"
        path.parent.mkdir()
        self.cmd(["git", "-C", str(self.root / "CocoOS"), "worktree", "add", "-b", "ai/coco-opencode", str(path)])
        (path / "scripts/dev/memory.py").unlink()
        before = self.cmd(["git", "-C", str(path), "status", "--porcelain"]).stdout
        self.assertNotEqual(self.cli("--create-only", check=False).returncode, 0)
        self.assertEqual(before, self.cmd(["git", "-C", str(path), "status", "--porcelain"]).stdout)
        self.assertFalse((self.trees / "host-opencode").exists())

    def test_failed_setup_is_retried_and_checked(self):
        marker = Path(self.temp.name) / "fail-setup"
        marker.touch()
        repo = self.root / "CocoOS"
        setup = repo / "scripts/dev/setup.sh"
        setup.write_text('#!/bin/sh\n[ ! -f "' + str(marker) + '" ] || exit 7\ngit config --local extensions.worktreeConfig true\ngit config --worktree core.hooksPath .githooks\n')
        self.cmd(["git", "-C", str(repo), "add", "scripts/dev/setup.sh"])
        self.cmd(["git", "-C", str(repo), "commit", "-qm", "fixture failed setup"])
        self.assertNotEqual(self.cli("--create-only", check=False).returncode, 0)
        self.assertTrue((self.trees / "coco-opencode").exists())
        self.assertNotEqual(self.cli("--create-only", check=False).returncode, 0)
        marker.unlink()
        self.cli("--create-only")
        self.assertEqual(len(self.windows().splitlines()), 6)

    def test_dirty_worktree_preserved(self):
        self.cli("--create-only")
        path = self.trees / "coco-opencode"
        self.write(path, "uncommitted.txt", "preserve")
        before = self.cmd(["git", "-C", str(path), "status", "--porcelain"]).stdout
        self.cli("--create-only")
        self.assertEqual(before, self.cmd(["git", "-C", str(path), "status", "--porcelain"]).stdout)

    def test_foreign_session_marker_refused(self):
        self.cli("--create-only")
        self.cmd(["tmux", "-L", self.socket, "set-option", "-t", "console-diy", "@console_diy_root", "/other/product"])
        before = self.windows()
        self.assertNotEqual(self.cli("--create-only", check=False).returncode, 0)
        self.assertEqual(before, self.windows())

    def test_unrecognized_existing_session_preserved(self):
        self.cmd(["tmux", "-L", self.socket, "new-session", "-d", "-s", "console-diy", "-n", "private-shell"])
        before = self.windows()
        self.assertNotEqual(self.cli("--create-only", check=False).returncode, 0)
        self.assertEqual(before, self.windows())
        self.assertFalse(self.trees.exists())

    def test_concurrent_open_is_serialized(self):
        first = subprocess.Popen(self.command("--create-only"), env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        second = subprocess.Popen(self.command("--create-only"), env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        _, error1 = first.communicate(timeout=30)
        _, error2 = second.communicate(timeout=30)
        self.assertEqual(first.returncode, 0, error1)
        self.assertEqual(second.returncode, 0, error2)
        self.assertEqual(len(self.windows().splitlines()), 6)

    def test_real_terminal_attach_then_detach_keeps_session(self):
        self.cli("--create-only")
        master, slave = pty.openpty()
        process = subprocess.Popen(self.command(), env=self.env, stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        try:
            deadline = time.monotonic() + 10
            attached = False
            while time.monotonic() < deadline:
                # Drain only our fixture terminal; no user session contents are read.
                if select.select([master], [], [], 0.1)[0]:
                    os.read(master, 65536)
                clients = self.cmd(["tmux", "-L", self.socket, "list-clients", "-F", "#{client_session}"]).stdout.splitlines()
                if "console-diy" in clients:
                    attached = True
                    break
            self.assertTrue(attached)
            self.cmd(["tmux", "-L", self.socket, "detach-client", "-s", "console-diy"])
            self.assertEqual(process.wait(timeout=10), 0)
            self.assertEqual(len(self.windows().splitlines()), 6)
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
            os.close(master)

    def test_check_json_read_only(self):
        self.cli("--create-only")
        before = self.windows()
        result = self.cli("--check", "--json", check=False)
        self.assertEqual(result.returncode, 2)  # SDK/plugin deliberately unavailable in fixture.
        rows = json.loads(result.stdout)
        self.assertTrue(any(r["name"] == "coco-opencode/mémoire" and r["status"] == "PASS" for r in rows))
        self.assertTrue(any(r["name"] == "plugin sous-agents" and r["status"] == "BLOCKED" for r in rows))
        self.assertEqual(before, self.windows())


if __name__ == "__main__":
    unittest.main(verbosity=2)
