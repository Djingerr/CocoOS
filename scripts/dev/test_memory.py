#!/usr/bin/env python3
"""Régressions mémoire : dépôts jetables, vrais Git/worktrees, aucun modèle/API."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("memory", SOURCE / "memory.py")
memory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(memory)


class MemoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp/opencode" if Path("/tmp/opencode").is_dir() else None)
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / "repo with spaces"
        self.repo.mkdir()
        self.env = os.environ.copy()
        for key in list(self.env):
            if key.startswith("GIT_"):
                self.env.pop(key)
        self.env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull,
                        GIT_CONFIG_NOSYSTEM="1", PYTHONDONTWRITEBYTECODE="1",
                        GIT_AUTHOR_NAME="Memory Fixture", GIT_COMMITTER_NAME="Memory Fixture",
                        GIT_AUTHOR_EMAIL="fixture@example.invalid", GIT_COMMITTER_EMAIL="fixture@example.invalid")
        template = Path(self.temp.name) / "empty-template"
        template.mkdir()
        self.git("init", "-b", "fixture-main", "--template=" + str(template))
        self.write(".agents/seams.txt", "fixture, not product code\n")
        self.write("AGENTS.md", (ROOT / "AGENTS.md").read_text())
        self.write("next_steps.md", memory.START + "\nProchaine action : NEXT_SENTINEL\n" + memory.END)
        self.write("controlled.txt", "initial\n")
        self.write("scripts/dev/memory.py", (SOURCE / "memory.py").read_text())
        self.git("add", ".")
        self.git("commit", "-m", "fixture initiale")
        self.base = self.git("rev-parse", "HEAD").stdout.strip()
        self.write("docs/ai/HANDOFF.md", self.complete())
        self.git("add", "docs/ai/HANDOFF.md")
        self.git("commit", "-m", "passation contrôlée")

    def run_cmd(self, *args, cwd=None, check=True, env=None):
        result = subprocess.run(args, cwd=cwd or self.repo, env=env or self.env,
                                capture_output=True, text=True, timeout=30)
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def git(self, *args, **kwargs):
        return self.run_cmd("git", *args, **kwargs)

    def cli(self, *args, cwd=None, **kwargs):
        root = cwd or self.repo
        return self.run_cmd(sys.executable, str(root / "scripts/dev/memory.py"), *args, cwd=root, **kwargs)

    def write(self, name, value, root=None):
        path = (root or self.repo) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8")
        return path

    def complete(self, branch="fixture-main", project="CocoOS"):
        return memory.draft(project, branch, self.base, "next_steps.md").replace("TODO", "À vérifier")

    def snapshot(self):
        return (self.git("status", "--porcelain=v1", "--untracked-files=all").stdout,
                self.git("rev-parse", "HEAD").stdout,
                (self.repo / ".git/index").read_bytes(),
                {str(p.relative_to(self.repo)): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in self.repo.rglob("*") if p.is_file()})

    def local(self, root=None):
        return Path(self.cli("local-path", cwd=root).stdout.strip())

    def test_resume_same_repo_read_only(self):
        before = self.snapshot()
        result = self.cli("resume").stdout
        self.assertIn("NEXT_SENTINEL", result)
        self.assertIn("instructions communes", result)
        self.assertIn("fixture-main", result)
        self.assertEqual(before, self.snapshot())

    def test_reduced_context_new_process(self):
        # Nouveau processus déterministe, PAS un autre fournisseur IA.
        result = self.cli("resume", "--compact").stdout
        self.assertIn("NEXT_SENTINEL", result)
        self.assertNotIn("--- AGENTS.md ---", result)
        self.assertIn("NON EXÉCUTÉ", result)

    def test_dirty_staged_untracked_preserved(self):
        self.write("controlled.txt", "modified\n")
        self.write("staged.txt", "staged\n")
        self.write("untracked.txt", "not committed\n")
        self.git("add", "staged.txt")
        before = self.snapshot()
        result = self.cli("resume").stdout
        for path in ("controlled.txt", "staged.txt", "untracked.txt"):
            self.assertIn(path, result)
        self.assertEqual(before, self.snapshot())

    def test_no_content_from_secret_like_files(self):
        self.write(".env", "SYNTHETIC_PRIVATE_SENTINEL\n")
        self.write("controlled.txt", "SYNTHETIC_PRIVATE_SENTINEL\n")
        for action in ("resume", "handoff"):
            self.assertNotIn("SYNTHETIC_PRIVATE_SENTINEL", self.cli(action).stdout)

    def test_draft_does_not_claim_tests_or_write(self):
        before = self.snapshot()
        result = self.cli("handoff").stdout
        self.assertIn("NON EXÉCUTÉ", result)
        self.assertIn("TODO", result)
        self.assertEqual(before, self.snapshot())
        with self.assertRaises(ValueError):
            memory.validate_handoff(result)

    def test_explicit_local_creation_no_overwrite(self):
        canonical = (self.repo / "docs/ai/HANDOFF.md").read_bytes()
        self.cli("handoff", "--save-local")
        local = self.local()
        saved = local.read_bytes()
        self.assertNotEqual(self.cli("handoff", "--save-local", check=False).returncode, 0)
        self.assertEqual(saved, local.read_bytes())
        self.assertEqual(canonical, (self.repo / "docs/ai/HANDOFF.md").read_bytes())

    def test_local_draft_rejected_then_completed(self):
        self.cli("handoff", "--save-local")
        self.assertNotEqual(self.cli("check", "--local", check=False).returncode, 0)
        self.local().write_text(self.complete())
        self.assertIn("STRUCTURE PASS", self.cli("check", "--local").stdout)

    def test_controlled_change_handoff_next_task(self):
        self.write("controlled.txt", "fictional modification\n")
        text = self.complete().replace("À vérifier : une action concrète + gate", "NEXT_AFTER_CHANGE")
        self.write("docs/ai/HANDOFF.md", text)
        self.cli("check")
        self.assertIn("NEXT_AFTER_CHANGE", self.cli("resume").stdout)
        self.assertIn("NON EXÉCUTÉ", self.cli("resume").stdout)

    def test_two_worktrees_isolated(self):
        other = Path(self.temp.name) / "other worktree"
        self.git("worktree", "add", "-b", "fixture-other", str(other))
        self.cli("handoff", "--save-local")
        self.cli("handoff", "--save-local", cwd=other)
        self.assertNotEqual(self.local(), self.local(other))
        self.local().write_text(self.complete().replace("À vérifier : objectif", "ONLY_FIRST_WORKTREE"))
        self.local(other).write_text(self.complete(branch="fixture-other").replace("À vérifier : objectif", "ONLY_SECOND_WORKTREE"))
        first = self.cli("resume").stdout
        second = self.cli("resume", cwd=other).stdout
        self.assertIn("ONLY_FIRST_WORKTREE", first)
        self.assertNotIn("ONLY_SECOND_WORKTREE", first)
        self.assertIn("ONLY_SECOND_WORKTREE", second)
        self.assertNotIn("ONLY_FIRST_WORKTREE", second)
        self.assertIn("passation héritée", second)
        self.cli("check", "--local", cwd=other)
        self.write("controlled.txt", "exclusive first branch\n")
        self.git("add", "controlled.txt")
        self.git("commit", "-m", "exclusive first branch")
        self.assertEqual((other / "controlled.txt").read_text(), "initial\n")

    def test_branch_change_does_not_load_foreign_local(self):
        self.cli("handoff", "--save-local")
        self.local().write_text(self.complete().replace("À vérifier : objectif", "FOREIGN_LOCAL_SENTINEL"))
        self.git("switch", "-c", "fixture-switched")
        self.assertNotIn("FOREIGN_LOCAL_SENTINEL", self.cli("resume").stdout)
        self.assertNotEqual(self.cli("check", "--local", check=False).returncode, 0)

    def test_symlink_document_refused(self):
        target = self.repo / "AGENTS.md"
        target.unlink()
        target.symlink_to(self.repo / "controlled.txt")
        self.assertNotEqual(self.cli("resume", check=False).returncode, 0)

    def test_symlink_local_parent_refused(self):
        parent = self.local().parent
        parent.symlink_to(self.repo, target_is_directory=True)
        self.assertNotEqual(self.cli("handoff", "--save-local", check=False).returncode, 0)
        self.assertFalse((self.repo / "HANDOFF.md").exists())

    def test_missing_roadmap_block_fails(self):
        self.write("next_steps.md", "no current block\n")
        self.assertNotEqual(self.cli("resume", check=False).returncode, 0)

    def test_duplicate_block_fails(self):
        self.write("next_steps.md", (memory.START + "\ncurrent\n" + memory.END) * 2)
        self.assertNotEqual(self.cli("check", check=False).returncode, 0)

    def test_missing_section_fails(self):
        self.write("docs/ai/HANDOFF.md", self.complete().replace("## Tests", "## Autre"))
        self.assertNotEqual(self.cli("check", check=False).returncode, 0)

    def test_wrong_project_fails(self):
        self.write("docs/ai/HANDOFF.md", self.complete(project="Other"))
        self.assertNotEqual(self.cli("check", check=False).returncode, 0)
        result = self.cli("resume", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Project: Other", result.stdout)

    def test_git_clean_process_filters_not_executed(self):
        helper = self.repo / ".git/filter-probe.sh"
        helper.write_text('#!/bin/sh\necho executed >> "' + str(self.repo / ".git/filter-executed") + '"\ncat\n')
        helper.chmod(0o700)
        self.write(".gitattributes", "controlled.txt filter=probe\n")
        self.git("add", ".gitattributes")
        self.git("config", "filter.probe.clean", '"' + str(helper) + '"')
        self.git("config", "filter.probe.process", '"' + str(helper) + '"')
        self.git("config", "filter.probe.required", "true")
        self.write("controlled.txt", "changed\n")
        self.cli("resume")
        self.assertFalse((self.repo / ".git/filter-executed").exists())

    def test_subdirectory_uses_active_root(self):
        result = self.run_cmd(sys.executable, str(self.repo / "scripts/dev/memory.py"),
                              "resume", cwd=self.repo / "docs/ai").stdout
        self.assertIn("NEXT_SENTINEL", result)
        self.assertIn(str(self.repo), result)

    def test_inherited_git_environment_does_not_redirect(self):
        env = dict(self.env, GIT_DIR="/not/a/repository", GIT_WORK_TREE="/not/a/worktree")
        self.assertIn("NEXT_SENTINEL", self.cli("resume", env=env).stdout)

    def test_host_detection_and_rules(self):
        (self.repo / ".agents/seams.txt").unlink()
        self.write("docs/protocol.md", "fixture protocol\n")
        self.write("docs/ai/ROADMAP.md", (self.repo / "next_steps.md").read_text())
        self.write("docs/ai/HANDOFF.md", self.complete(project="HostCompanion"))
        self.assertIn("[HostCompanion]", self.cli("resume").stdout)
        self.cli("check")

    def test_cli_options_fail_without_write(self):
        before = self.snapshot()
        self.assertNotEqual(self.cli("resume", "--save-local", check=False).returncode, 0)
        self.assertEqual(before, self.snapshot())

    def test_installed_config_and_canonical_skill(self):
        config = json.loads((ROOT / "opencode.json").read_text())
        for name in ("task-resume", "task-handoff"):
            command = config["commands"][name]
            self.assertNotIn("model", command)
            self.assertNotIn("agent", command)
            self.assertIs(command["subagent"], False)
            self.assertIn("session-memory", command["template"])
        skill = (ROOT / ".agents/skills/session-memory/SKILL.md").read_text()
        self.assertIn("## Reprise", skill)
        self.assertIn("## Passation", skill)
        self.assertIn("NON EXÉCUTÉ", skill)
        self.assertLess(len((ROOT / "AGENTS.md").read_text().splitlines()), 90)
        rules = (ROOT / "AGENTS.md").read_text()
        for rule in (("Additive-only", "qmake", "app/gui/main.qml") if (ROOT / ".agents/seams.txt").exists()
                     else ("No-fork", "DPAPI", "djing", "READY")):
            self.assertIn(rule, rules)


if __name__ == "__main__":
    unittest.main(verbosity=2)
