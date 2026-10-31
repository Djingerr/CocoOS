#!/usr/bin/env python3
"""Console DIY : extension cockpit de fleet.py, sans démarrage automatique d'IA.

Un seul point d'entrée : console-diy -> fleet.py cockpit. Aucun service distant.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
from memory import git

LANES = (("coco-opencode", "CocoOS", "opencode"),
         ("coco-antigravity", "CocoOS", "agy"),
         ("host-opencode", "HostCompanion", "opencode"),
         ("host-antigravity", "HostCompanion", "agy"))


def run(args, check=True, cwd=None, timeout=30):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError("Commande en échec : " + args[0] + " " + args[1] + " (code " + str(result.returncode) + ")")
    return result


def tmux(args, *command, check=True):
    prefix = ["tmux"] + (["-L", args.socket] if args.socket else [])
    return run(prefix + list(command), check=check)


def identity(path):
    return Path(git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")).resolve()


def plan(args):
    """Préflight complet, aucune création ni modification de branche existante."""
    entries = []
    repos = {}
    for project in ("CocoOS", "HostCompanion"):
        root = args.root / project
        repos[project] = identity(root)
        base = git(root, "rev-parse", "--verify", args.base + "^{commit}")
        for required in ("AGENTS.md", "docs/ai/HANDOFF.md", "scripts/dev/memory.py"):
            git(root, "cat-file", "-e", base + ":" + required)
    for name, project, tool in LANES:
        path = args.worktrees / name
        branch = "ai/" + name
        if path.exists():
            if path.is_symlink() or identity(path) != repos[project]:
                raise RuntimeError("Worktree d'un autre dépôt ou lien symbolique : " + str(path))
            if Path(git(path, "rev-parse", "--show-toplevel")).resolve() != path.resolve():
                raise RuntimeError("Racine de worktree incorrecte : " + str(path))
            if git(path, "branch", "--show-current") != branch:
                raise RuntimeError("Branche inattendue dans " + str(path))
            for required in ("AGENTS.md", "docs/ai/HANDOFF.md", "scripts/dev/memory.py"):
                if not (path / required).is_file() or (path / required).is_symlink():
                    raise RuntimeError("Worktree existant sans mémoire régulière : " + str(path / required) + "; aucune intégration automatique")
        elif run(["git", "-C", str(args.root / project), "show-ref", "--verify", "--quiet", "refs/heads/" + branch], check=False).returncode == 0:
            raise RuntimeError("Branche déjà présente ailleurs : " + branch)
        entries.append((name, project, tool, path, branch))
    return entries


def hooks_ready(path):
    value = run(["git", "-C", str(path), "config", "--path", "--get", "core.hooksPath"], check=False).stdout.strip()
    hookdir = Path(value) if Path(value).is_absolute() else path / value
    return bool(value) and hookdir.resolve() == (path / ".githooks").resolve() and os.access(path / ".githooks/pre-commit", os.X_OK)


def windows(args):
    result = tmux(args, "list-windows", "-t", "=" + args.session,
                  "-F", "#{window_name}\t#{window_id}")
    result_map = {}
    for line in result.stdout.splitlines():
        name, wid = line.split("\t", 1)
        if name in result_map:
            raise RuntimeError("Fenêtres homonymes : " + name + "; aucune suppression automatique")
        result_map[name] = wid
    return result_map


def ensure(args):
    if not shutil.which("tmux"):
        raise RuntimeError("tmux absent")
    entries = plan(args)
    shared = args.root / ".ai-fleet"
    shared.mkdir(exist_ok=True)
    if shared.is_symlink():
        raise RuntimeError("Répertoire de verrou symbolique refusé")
    fd = os.open(shared / "lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        entries = plan(args)
        exists = tmux(args, "has-session", "-t", "=" + args.session, check=False).returncode == 0
        present = windows(args) if exists else {}
        if exists:
            marker = tmux(args, "show-options", "-qv", "-t", args.session, "@console_diy_root").stdout.strip()
            if marker and marker != str(args.root):
                raise RuntimeError("Session appartenant à un autre espace ; session préservée")
            if not marker and not any(name in present for name, *_ in entries):
                raise RuntimeError("Session existante non identifiée comme cockpit ; préservée sans adoption")
            # Adopter l'ancien cockpit uniquement si ses fenêtres pointent aux bons worktrees.
            for name, project, tool, path, branch in entries:
                if name in present:
                    dirs = tmux(args, "list-panes", "-t", present[name], "-F", "#{pane_current_path}").stdout.splitlines()
                    if not dirs or any(not Path(p).resolve().is_relative_to(path.resolve()) for p in dirs):
                        raise RuntimeError("Fenêtre " + name + " dans un autre dossier ; aucun shell déplacé")
        for name, project, tool, path, branch in entries:
            if not path.exists():
                args.worktrees.mkdir(parents=True, exist_ok=True)
                run(["git", "-C", str(args.root / project), "worktree", "add", "-b", branch, str(path), args.base])
            # Reprendre aussi un worktree créé lors d'un setup précédemment échoué.
            if not hooks_ready(path):
                run(["bash", "scripts/dev/setup.sh", "--quiet"], cwd=path)
                if not hooks_ready(path):
                    raise RuntimeError("Setup incomplet : hooks inactifs dans " + str(path))
        source = Path(__file__).resolve()
        monitor = [sys.executable, str(source), "--root", str(args.root), "--worktrees", str(args.worktrees),
                   "--base", args.base, "--session", args.session, "--watch", "5"]
        if args.socket:
            monitor += ["--socket", args.socket]
        monitor_command = shlex.join(monitor) + "; exec bash --noprofile --norc"
        if not exists:
            tmux(args, "new-session", "-d", "-s", args.session, "-n", "cockpit", "-c", str(args.root), monitor_command)
            present = windows(args)
        elif "cockpit" not in present:
            tmux(args, "new-window", "-d", "-t", "=" + args.session, "-n", "cockpit", "-c", str(args.root), monitor_command)
        for name, project, tool, path, branch in entries:
            if name not in present:
                tmux(args, "new-window", "-d", "-t", "=" + args.session, "-n", name, "-c", str(path),
                     "exec bash --noprofile --norc")
        if "integration" not in present:
            tmux(args, "new-window", "-d", "-t", "=" + args.session, "-n", "integration", "-c", str(args.root),
                 "exec bash --noprofile --norc")
        tmux(args, "set-option", "-t", args.session, "@console_diy_root", str(args.root))
        cockpit_id = windows(args)["cockpit"]
        tmux(args, "select-window", "-t", cockpit_id)
    print("PASS cockpit " + args.session + " prêt ; aucun modèle lancé, shells existants préservés.")


def doctor(args, display=True):
    rows = []
    def row(state, name, detail):
        rows.append({"status": state, "name": name, "detail": detail})
    for name, flag in (("git", "--version"), ("tmux", "-V"), ("node", "--version"),
                       ("npm", "--version"), ("opencode", "--version"), ("agy", "--version"),
                       ("qmake6", "-v"), ("qmllint-qt6", "--version"), ("dotnet", "--list-sdks")):
        if not shutil.which(name):
            row("BLOCKED", name, "outil absent, aucune installation automatique")
            continue
        result = run([name, flag], check=False)
        row("PASS" if result.returncode == 0 else "FAIL", name,
            (result.stdout + result.stderr).strip().splitlines()[0][:120] if result.stdout or result.stderr else "sans sortie")
    try:
        entries = plan(args)
    except (OSError, ValueError, RuntimeError) as error:
        row("BLOCKED", "worktrees", str(error))
        entries = []
    for name, project, tool, path, branch in entries:
        if not path.exists():
            row("BLOCKED", name, "worktree absent ; console-diy --create-only pour préparer")
            continue
        changes = git(path, "status", "--porcelain", "--ignore-submodules=all").splitlines()
        row("PASS", name, branch + " @" + git(path, "rev-parse", "--short", "HEAD")
            + " ; " + str(len(changes)) + " entrées modifiées/non suivies (préservées)")
        if not (path / "scripts/dev/memory.py").is_file():
            row("BLOCKED", name + "/mémoire", "base ancienne, aucune intégration automatique")
        else:
            result = run([sys.executable, "scripts/dev/memory.py", "check"], cwd=path, check=False)
            required = ["AGENTS.md", "CLAUDE.md", ".agents/skills/session-memory/SKILL.md", "docs/ai/decisions/README.md"]
            missing = [p for p in required if not (path / p).is_file()]
            row("PASS" if result.returncode == 0 and not missing else "FAIL", name + "/mémoire",
                "structure seulement, pas preuve des faits" if not missing else "mémoire incomplète : " + ", ".join(missing))
        hooks = run(["git", "-C", str(path), "config", "--path", "--get", "core.hooksPath"], check=False).stdout.strip()
        hookdir = Path(hooks) if Path(hooks).is_absolute() else path / hooks
        valid = hookdir.resolve() == (path / ".githooks").resolve() and os.access(path / ".githooks/pre-commit", os.X_OK)
        row("PASS" if valid else "BLOCKED", name + "/hooks", "actifs" if valid else "setup.sh explicite requis")
        # Un ancien résultat reste étiqueté comme historique, jamais comme test frais.
        status = path / ".dev/last-build.status"
        previous = status.read_text(errors="replace").split()[:1] if status.is_file() else []
        label = previous[0] if previous and previous[0] in ("PASS", "FAIL", "BLOCKED", "OK", "FAILED", "RUNNING") else "absent/inconnu"
        row("NOT TESTED", name + "/build", "historique local : " + label + " ; pas un test frais")
    if shutil.which("opencode"):
        service = run(["opencode", "service", "status"], check=False)
        local = service.returncode == 0 and re.fullmatch(r"http://(?:127\.0\.0\.1|localhost):\d+/?", service.stdout.strip())
        row("PASS" if local else "BLOCKED", "OpenCode distant", "service loopback seulement" if local else "service absent ou adresse non loopback à revoir ; aucun serveur démarré")
        plugins = run(["opencode", "plugin", "list"], check=False)
        row("PASS" if plugins.returncode == 0 else "BLOCKED", "catalogue plugins", "commande native vérifiée ; rendu live NOT TESTED")
        row("PASS" if plugins.returncode == 0 and "opencode-subagent-statusline" in plugins.stdout else "BLOCKED",
            "plugin sous-agents", "présence catalogue, rendu NOT TESTED" if "opencode-subagent-statusline" in plugins.stdout else "non installé/résolution incompatible ; voir ENVIRONMENT-AUDIT.md")
    if shutil.which("dotnet"):
        sdkroot = Path(shutil.which("dotnet")).resolve().parent / "sdk"
        present = any(sdkroot.glob("*/Sdks/Microsoft.NET.Sdk.WindowsDesktop/targets/Microsoft.NET.Sdk.WindowsDesktop.targets"))
        row("NOT TESTED" if present else "BLOCKED", "SDK WindowsDesktop", "targets présentes, build distinct requis" if present else "targets absentes ; tests Shared possibles, build Windows non validé")
    if shutil.which("agy"):
        remote = run(["agy", "remote-control", "status"], check=False)
        inactive = "inactive" in remote.stdout.lower()
        row("PASS" if inactive else "NOT TESTED", "Antigravity distant", "daemon inactif (conservé)" if inactive else "état à vérifier manuellement ; aucune activation")
    if display:
        if args.json:
            print(json.dumps(rows, ensure_ascii=False, indent=2))
        elif args.watch:
            print("CONSOLE DIY — " + time.strftime("%H:%M:%S") + " — aucun modèle démarré automatiquement")
            print("Outils : " + " | ".join(r["name"] + ":" + r["status"] for r in rows[:9]))
            for name, *_ in entries:
                state = next(r for r in rows if r["name"] == name)
                memory = next((r for r in rows if r["name"] == name + "/mémoire"), {"status": "BLOCKED"})
                hooks = next((r for r in rows if r["name"] == name + "/hooks"), {"status": "BLOCKED"})
                print(name + " : " + state["detail"])
                print("  mémoire=" + memory["status"] + " hooks=" + hooks["status"] + " ; build local non revérifié")
            for item in rows:
                if item["status"] in ("FAIL", "BLOCKED"):
                    print(item["status"] + " " + item["name"] + " : " + item["detail"])
            print("Ctrl-b w : fenêtres | Ctrl-b d : détacher | console-diy --check : audit détaillé")
            print("Lancer opencode/agy manuellement ; deux développeurs actifs max. /task-handoff avant arrêt.")
            print("Limites builds/SDK/plugins/téléphone : docs/ai/ENVIRONMENT-AUDIT.md (pas de PASS implicite).")
        else:
            print("CONSOLE DIY — surveillance sans IA / sans contenu privé")
            for item in rows:
                print(f"{item['status']:10} {item['name']:26} {item['detail']}")
            print("Agents : lancer opencode ou agy MANUELLEMENT dans leur fenêtre. Deux développeurs actifs max.")
            print("Reprise : memory.py resume ; passation : session-memory. Intégration : revue puis accord humain.")
    return rows


def verify(args):
    entries = plan(args)
    failed = False
    for project in ("CocoOS", "HostCompanion"):
        path = next(item[3] for item in entries if item[1] == project)
        commands = [["bash", "scripts/dev/check.sh"], ["python3", "scripts/dev/test_memory.py"],
                    ["python3", "scripts/dev/fleet-test.py"]]
        commands.append(["python3", "scripts/dev/cockpit-test.py"] if project == "CocoOS" else ["bash", "scripts/dev/tooling-test.sh"])
        for command in commands:
            if not path.exists() or not (path / command[1]).is_file():
                print("BLOCKED " + project + " : scripts de vérification absents")
                failed = True
                continue
            result = run(command, cwd=path, check=False, timeout=180)
            log = path / ".dev" / ("cockpit-" + Path(command[1]).stem + ".log")
            log.parent.mkdir(exist_ok=True)
            log.write_text(result.stdout + result.stderr)
            print(("PASS " if result.returncode == 0 else "FAIL ") + project + " " + shlex.join(command) + " — " + str(log))
            failed |= result.returncode != 0
    if failed:
        raise RuntimeError("vérifications en échec ou bloquées ; consulter les logs locaux")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(os.environ.get("CONSOLE_DIY_ROOT", str(Path.home() / "Documents/Projets/CONSOLE DIY"))))
    parser.add_argument("--worktrees", type=Path, default=None)
    parser.add_argument("--base", default="tooling/environment-finalisation")
    parser.add_argument("--session", default="console-diy")
    parser.add_argument("--socket", help="socket tmux distinct pour tests isolés")
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--create-only", action="store_true", help="préparer sans attachement ; aucun modèle")
    actions.add_argument("--check", action="store_true", help="audit local en lecture seule, sans créer de session")
    actions.add_argument("--verify", action="store_true", help="tests existants isolés ; ni build, réseau ni fournisseur")
    actions.add_argument("--watch", type=int, metavar="SECONDS", help="surveillance, Ctrl-C pour arrêter ce moniteur seulement")
    parser.add_argument("--json", action="store_true", help="sortie structurée avec --check uniquement")
    args = parser.parse_args(argv)
    if args.json and not args.check:
        parser.error("--json exige --check")
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,60}", args.session) or (args.socket and not re.fullmatch(r"[a-zA-Z0-9_-]{1,60}", args.socket)):
        parser.error("nom de session/socket invalide")
    if args.watch is not None and args.watch < 1:
        parser.error("intervalle >=1 seconde requis")
    args.root = args.root.expanduser().resolve()
    args.worktrees = (args.worktrees or Path(os.environ.get("CONSOLE_DIY_WORKTREES", str(args.root.parent / (args.root.name + "-worktrees"))))).expanduser().resolve()
    if args.check:
        rows = doctor(args)
        if any(row["status"] in ("FAIL", "BLOCKED") for row in rows):
            raise SystemExit(2)
    elif args.verify:
        verify(args)
    elif args.watch:
        while True:
            print("\033[2J\033[H", end="", flush=True)
            doctor(args)
            time.sleep(args.watch)
    else:
        if not args.create_only and not sys.stdin.isatty():
            raise RuntimeError("terminal requis ; utiliser --create-only ou --check (aucune création effectuée)")
        ensure(args)
        if not args.create_only:
            prefix = ["tmux"] + (["-L", args.socket] if args.socket else [])
            action = "switch-client" if os.environ.get("TMUX") and not args.socket else "attach-session"
            os.execvp("tmux", prefix + [action, "-t", "=" + args.session])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print("BLOCKED cockpit : " + str(error), file=sys.stderr)
        sys.exit(2)
