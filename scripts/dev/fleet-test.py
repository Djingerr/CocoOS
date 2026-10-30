#!/usr/bin/env python3
"""Tests de flotte : vrais Git/worktrees/tmux, faux OpenCode (zéro appel modèle)."""
import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid

FLEET = Path(__file__).with_name("fleet.py").resolve()


@unittest.skipUnless(shutil.which("tmux") and shutil.which("git"), "Git/tmux absents")
class FleetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="fleet test ", dir="/tmp/opencode" if Path("/tmp/opencode").exists() else None)
        self.home = Path(self.tmp.name)
        self.repo = self.home / "repo avec espaces"
        self.repo.mkdir()
        self.socket = "fleet-test-" + uuid.uuid4().hex
        self.bin = self.home / "bin"
        self.bin.mkdir()
        real_tmux = shutil.which("tmux")
        (self.bin / "tmux").write_text(f'#!/bin/sh\nexec "{real_tmux}" -L {self.socket} "$@"\n')
        (self.bin / "opencode").write_text('#!/bin/sh\nif [ "$1" = models ]; then echo openai/gpt-6.1-sol; exit; fi\nexit 0\n')
        for f in self.bin.iterdir():
            f.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_PREFIX", "TMUX"):
            self.env.pop(key, None)
        self.git("init", "-q", "-b", "fixture")
        self.git("config", "user.name", "Tooling Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", str(self.home / "no-hooks"))
        (self.repo / "opencode.json").write_text("{}\n")
        setup = self.repo / "scripts/dev/setup.sh"
        setup.parent.mkdir(parents=True)
        setup.write_text("#!/bin/sh\nexit 0\n")
        self.git("add", ".")
        self.git("commit", "-qm", "fixture initiale temporaire")

    def tearDown(self):
        subprocess.run([str(self.bin / "tmux"), "kill-server"], env=self.env, capture_output=True)
        self.tmp.cleanup()

    def git(self, *args, cwd=None):
        return subprocess.run(["git", "-C", str(cwd or self.repo), *args], env=self.env, check=True, capture_output=True, text=True).stdout.strip()

    def fleet(self, *args, confirmation=None):
        cmd = [sys.executable, str(FLEET), "--repo", str(self.repo), *args]
        if confirmation is None:
            return subprocess.run(cmd, env=self.env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(cmd, env=self.env, stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            os.write(master, (confirmation + "\n").encode())
            out, err = process.communicate(timeout=20)
            return subprocess.CompletedProcess(cmd, process.returncode, out, err)
        finally:
            os.close(master)
            os.close(slave)

    def test_help_and_list_no_side_effect(self):
        self.assertEqual(self.fleet("--help").returncode, 0)
        self.assertEqual(self.fleet("list").returncode, 0)
        self.assertFalse((self.repo / ".git/ai-fleet").exists())

    def test_dry_run_and_model_validation(self):
        r = self.fleet("--dry-run", "--model", "openai/gpt-6.1-sol", "alpha")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse((self.repo / ".worktrees").exists())
        self.assertNotEqual(self.fleet("--model", "new-paid/model", "alpha").returncode, 0)

    def test_input_injection_and_missing_flag(self):
        for args in (("bad;touch-owned",), ("--tool", "opencode;evil", "alpha"), ("--tool",), ("../elsewhere",), ("--model", "openai/not-listed", "alpha")):
            self.assertNotEqual(self.fleet(*args).returncode, 0)
        self.assertFalse((self.repo / ".worktrees").exists())

    def test_stop_clean_dry_run_rejected_without_side_effects(self):
        self.assertEqual(self.fleet("alpha").returncode, 0)

        def snapshot():
            return {str(path.relative_to(self.home)): (path.read_bytes(), path.stat().st_mtime_ns)
                    for path in self.home.rglob("*") if path.is_file()}

        before = snapshot()
        for action in ("stop", "clean"):
            result = self.fleet("--dry-run", action, "alpha")
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn("--dry-run", result.stderr)
            self.assertEqual(snapshot(), before)
        self.assertIn("RUNNING", self.fleet("list").stdout)

    def test_real_worktree_tmux_lifecycle(self):
        r = self.fleet("--model", "openai/gpt-6.1-sol", "alpha")
        self.assertEqual(r.returncode, 0, r.stderr)
        path = self.repo / ".worktrees/alpha"
        self.assertEqual(self.git("symbolic-ref", "--short", "HEAD", cwd=path), "ai/alpha")
        self.assertIn("RUNNING", self.fleet("list").stdout)
        self.assertEqual(self.fleet("inspect", "alpha").returncode, 0)
        self.assertNotEqual(self.fleet("alpha").returncode, 0)
        self.assertNotEqual(self.fleet("stop", "alpha").returncode, 0)
        self.assertEqual(self.fleet("stop", "alpha", confirmation="alpha").returncode, 0)
        self.assertNotEqual(self.fleet("clean", "alpha").returncode, 0)
        (path / "travail.txt").write_text("préserver\n")
        self.assertNotEqual(self.fleet("clean", "alpha", confirmation="alpha").returncode, 0)
        (path / "travail.txt").unlink()  # notre fixture uniquement
        self.assertEqual(self.fleet("clean", "alpha", confirmation="alpha").returncode, 0)
        self.assertFalse(path.exists())
        self.assertEqual(self.git("rev-parse", "ai/alpha"), self.git("rev-parse", "HEAD"))

    def test_limits_and_reviewer(self):
        self.assertEqual(self.fleet("alpha", "beta").returncode, 0)
        self.assertNotEqual(self.fleet("gamma").returncode, 0)
        self.assertEqual(self.fleet("--role", "reviewer", "review-one").returncode, 0)
        self.assertNotEqual(self.fleet("--role", "reviewer", "review-two").returncode, 0)

    def test_ignored_artifacts_preserved(self):
        self.assertEqual(self.fleet("alpha").returncode, 0)
        self.assertEqual(self.fleet("stop", "alpha", confirmation="alpha").returncode, 0)
        path = self.repo / ".worktrees/alpha"
        exclude = self.repo / ".git/info/exclude"
        with exclude.open("a") as f:
            f.write("\n.dev/\n")
        (path / ".dev").mkdir()
        (path / ".dev/result.log").write_text("résultat à conserver\n")
        r = self.fleet("clean", "alpha", confirmation="alpha")
        self.assertNotEqual(r.returncode, 0)
        self.assertTrue((path / ".dev/result.log").exists())

    def test_limit_across_sibling_repositories(self):
        self.assertEqual(self.fleet("alpha", "beta").returncode, 0)
        sibling = self.home / "depot frere"
        subprocess.run(["git", "clone", "-q", str(self.repo), str(sibling)], env=self.env, check=True, capture_output=True)
        r = subprocess.run([sys.executable, str(FLEET), "--repo", str(sibling), "gamma"], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("limite developer", r.stderr)
        self.assertFalse((sibling / ".worktrees").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
