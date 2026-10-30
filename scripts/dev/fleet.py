#!/usr/bin/env python3
"""Flotte locale sobre : un worktree et une session tmux par tâche (Fedora)."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


def run(args, cwd=None, check=True):
    return subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=check)


def git(root, *args):
    return run(["git", "-C", str(root), *args]).stdout.strip()


def confirm(text, expected):
    print(text)
    if not sys.stdin.isatty() or input(f"Taper {expected!r} pour confirmer : ") != expected:
        raise RuntimeError("confirmation explicite absente ; aucune suppression/arrêt")


def alive(session):
    return run(["tmux", "has-session", "-t", "=" + session], check=False).returncode == 0


def main():
    p = argparse.ArgumentParser(description=__doc__, epilog=(
        "Exemples : --tool opencode ui ; list ; inspect ui ; attach ui ; stop ui ; clean ui. "
        "Pas de merge, push ni suppression de branche. Deux développeurs et un reviewer max entre dépôts frères."))
    p.add_argument("items", nargs="*", metavar="[action] [tâche...]")
    p.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument("--tool", choices=("opencode", "claude", "codex", "aider"), default="opencode")
    p.add_argument("--role", choices=("developer", "reviewer"), default="developer")
    p.add_argument("--model", help="OpenCode : identifiant exact listé par opencode models, abonnements uniquement")
    p.add_argument("--base", default="HEAD", help="commit/branche de départ ; HEAD par défaut")
    p.add_argument("--goal", default="", help="objectif et critères d'acceptation consignés, pas soumis automatiquement")
    p.add_argument("--dry-run", action="store_true", help="afficher sans créer ni lancer")
    a = p.parse_args()
    actions = {"start", "list", "attach", "inspect", "stop", "clean"}
    action = a.items[0] if a.items and a.items[0] in actions else "start"
    names = a.items[1:] if a.items and a.items[0] in actions else a.items
    if a.dry_run and action != "start":
        p.error("--dry-run est réservé à start ; aucune action effectuée")
    if action == "list" and names:
        p.error("list n'accepte pas de tâche")
    if action != "list" and not names:
        p.error("une tâche nommée est requise (ou utiliser list)")
    if action not in ("start", "list") and len(names) != 1:
        p.error("une seule tâche pour cette action")
    for name in names:
        if not re.fullmatch(r"[a-z][a-z0-9-]{0,39}", name) or name in actions:
            p.error("nom : lettre minuscule puis lettres/chiffres/tirets, 40 caractères max, hors actions")
    root = Path(git(a.repo, "rev-parse", "--show-toplevel")).resolve()
    common = Path(git(root, "rev-parse", "--path-format=absolute", "--git-common-dir")).resolve()
    canonical = common.parent
    identity = hashlib.sha256(str(common).encode()).hexdigest()[:10]
    state = common / "ai-fleet"
    trees = canonical / ".worktrees"
    if action == "start":
        if not shutil.which(a.tool):
            raise RuntimeError(f"outil absent : {a.tool}")
        if a.role == "reviewer" and a.tool != "opencode":
            p.error("reviewer sécurisé disponible avec OpenCode uniquement")
        if a.model and a.tool != "opencode":
            p.error("--model implémenté pour OpenCode uniquement ; autres outils : sélection interactive")
        if a.model:
            if a.model.split("/", 1)[0] not in ("openai", "claude-agent"):
                raise RuntimeError("fournisseur non autorisé ; accord explicite requis")
            available = run(["opencode", "models"], cwd=root).stdout.splitlines()
            if a.model.split("#", 1)[0] not in available:
                raise RuntimeError("modèle absent du catalogue connecté")
        base = git(root, "rev-parse", "--verify", a.base + "^{commit}")
        # Les fichiers non commités ne sont jamais copiés dans le worktree d'un autre agent.
        if run(["git", "-C", str(root), "cat-file", "-e", base + ":opencode.json"], check=False).returncode:
            raise RuntimeError("base sans configuration OpenCode ; committer l'outillage sur une branche sûre d'abord")
        if a.dry_run:
            for name in names:
                print(f"DRY-RUN {a.role} {a.tool}: branche ai/{name}, worktree {trees / name}, base {base[:12]}")
            return
    if not shutil.which("tmux"):
        raise RuntimeError("tmux absent (Fedora : sudo dnf install tmux ; installation non exécutée)")
    # Lecture et aide ne créent ni registre ni worktree.
    if not state.exists() and action == "list":
        print("Aucune tâche de flotte dans ce dépôt.")
        return
    if not state.exists() and action != "start":
        raise RuntimeError("aucune tâche enregistrée")
    state.mkdir(exist_ok=True)
    # Les dépôts frères partagent la capacité, jamais leurs fichiers de travail.
    shared = canonical.parent / ".ai-fleet"
    shared.mkdir(exist_ok=True)
    with (shared / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        (shared / f"{identity}.json").write_text(json.dumps({"state": str(state)}) + "\n")
        records = {f.stem: json.loads(f.read_text()) for f in state.glob("*.json")}
        if action == "list":
            for name, r in sorted(records.items()):
                print(f"{name:40} {r['role']:9} {'RUNNING' if alive(r['session']) else 'STOPPED':7} {r['branch']} {r['path']}")
            return
        if action == "start":
            if len(set(names)) != len(names) or any(n in records for n in names):
                raise RuntimeError("tâche existante/dupliquée ; utiliser attach ou nettoyer explicitement")
            all_records = []
            for source in shared.glob("*.json"):
                sibling_state = Path(json.loads(source.read_text())["state"])
                if sibling_state.exists():
                    all_records.extend(json.loads(f.read_text()) for f in sibling_state.glob("*.json"))
            count = sum(r["role"] == a.role and alive(r["session"]) for r in all_records)
            limit = 2 if a.role == "developer" else 1
            if count + len(names) > limit:
                raise RuntimeError(f"limite {a.role} atteinte ({limit} entre dépôts frères)")
            # Préflight de TOUT le lot, pas d'échec silencieux ni réutilisation d'un dossier.
            for name in names:
                if (trees / name).exists() or run(["git", "-C", str(root), "show-ref", "--verify", "--quiet", f"refs/heads/ai/{name}"], check=False).returncode == 0:
                    raise RuntimeError(f"branche/dossier déjà présent : {name}")
            for name in names:
                path = trees / name
                branch = f"ai/{name}"
                session = f"ai-{identity}-{name}"
                run(["git", "-C", str(root), "worktree", "add", "-b", branch, str(path), base])
                record = dict(path=str(path), branch=branch, base=base, session=session,
                              role=a.role, tool=a.tool, model=a.model, goal=a.goal)
                (state / f"{name}.json").write_text(json.dumps(record, indent=2) + "\n")
                # En cas d'échec setup/tmux, conserver branche + fiche pour diagnostic, jamais rollback destructif.
                setup = run(["bash", "scripts/dev/setup.sh", "--quiet"], cwd=path, check=False)
                if setup.returncode:
                    raise RuntimeError(f"setup échoué ({setup.returncode}) ; tâche conservée : {path}")
                if a.tool == "opencode":
                    cmd = ["opencode", "mini", "--agent", a.role]
                    # Le CLI TUI complet 2.2.4 n'a pas --model/--agent ; mini les expose.
                    if a.model:
                        cmd += ["--model", a.model]
                else:
                    cmd = [a.tool]
                # shlex.join protège espaces et métacaractères ; aucun eval de chaînes utilisateur.
                shell_cmd = shlex.join(cmd) + "; exec bash --noprofile --norc"
                run(["tmux", "new-session", "-d", "-s", session, "-c", str(path), shell_cmd])
                print(f"STARTED {name}: {session}\n  {path}\n  {branch} ; objectif : {a.goal or '(à préciser avant de coder)'}")
            return
        if names[0] not in records:
            raise RuntimeError("tâche non enregistrée dans ce dépôt")
        name = names[0]
        r = records[name]
        path = Path(r["path"])
        if path.resolve() != (trees / name).resolve():
            raise RuntimeError("chemin de registre inattendu ; intervention humaine requise")
        if action == "inspect":
            print(json.dumps(r, indent=2, ensure_ascii=False))
            print(git(path, "status", "--short", "--branch"))
            print(git(path, "diff", "--stat", r["base"]))
            print(git(path, "log", "--oneline", r["base"] + "..HEAD"))
            print("Revue : git diff <base>...<branche> ; validations puis reviewer ; proposer l'intégration, pas de merge automatique.")
        elif action == "attach":
            if not alive(r["session"]):
                raise RuntimeError("session arrêtée ; worktree et branche conservés")
            # Ne pas conserver le verrou pendant toute la session interactive.
            fcntl.flock(lock, fcntl.LOCK_UN)
            os.execvp("tmux", ["tmux", "switch-client" if os.environ.get("TMUX") else "attach-session", "-t", "=" + r["session"]])
        elif action == "stop":
            if not alive(r["session"]):
                print("Déjà arrêtée ; fichiers conservés.")
                return
            confirm("Quitter d'abord l'agent (/exit ou Ctrl-C), puis détacher tmux. L'arrêt ferme le shell, jamais le worktree.", name)
            commands = run(["tmux", "list-panes", "-s", "-t", "=" + r["session"], "-F", "#{pane_current_command}"]).stdout.splitlines()
            if any(c not in ("bash", "zsh", "fish", "sh") for c in commands):
                raise RuntimeError("agent/processus encore actif ; le quitter proprement avant stop")
            run(["tmux", "kill-session", "-t", "=" + r["session"]])
            print("STOPPED ; worktree et branche conservés.")
        elif action == "clean":
            if alive(r["session"]):
                raise RuntimeError("session active ; la quitter puis stop avant clean")
            status = git(path, "status", "--porcelain", "--untracked-files=all")
            if status:
                print(status)
                raise RuntimeError("worktree modifié/non suivi : nettoyage refusé")
            if git(path, "symbolic-ref", "--short", "HEAD") != r["branch"]:
                raise RuntimeError("branche du worktree changée ; nettoyage refusé")
            ignored = git(path, "ls-files", "--others", "--ignored", "--exclude-standard")
            print(f"Branche conservée : {r['branch']}\n{git(path, 'log', '--oneline', r['base'] + '..HEAD')}")
            if ignored:
                print("Fichiers ignorés présents (logs/builds inclus) :\n" + ignored[:4000])
                raise RuntimeError("archiver/enlever explicitement les artefacts avant clean ; aucune perte implicite")
            confirm(f"Supprimer uniquement le worktree {path} ? La branche et ses commits restent disponibles.", name)
            run(["git", "-C", str(root), "worktree", "remove", str(path)])
            (state / f"{name}.json").unlink()
            print("CLEANED ; branche conservée, aucune intégration effectuée.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError, ValueError) as exc:
        # Ne pas réimprimer stderr arbitraire : il peut contenir des informations d'environnement.
        print(f"FLEET BLOCKED : {exc}", file=sys.stderr)
        sys.exit(1)
