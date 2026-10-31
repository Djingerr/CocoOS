#!/usr/bin/env python3
"""Mémoire portable v1 : lecture seule, sauf création explicite d'un brouillon local.

Copie autonome identique dans les deux dépôts ; Python standard + Git, aucun LLM.
N'ouvre directement que les documents mémoire ; aucun contenu de diff ou log retourné.
Git peut lire les fichiers suivis pour calculer leur état, sans en restituer les valeurs.
"""
import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import subprocess
import sys

START = "<!-- memory:current:start -->"
END = "<!-- memory:current:end -->"
SECTIONS = ("Objectif", "Termine", "Fichiers", "Decisions", "Tests", "Problemes",
            "Non resolu", "Prochaine action", "Commits", "Dependances croisees")


def git(cwd, *args):
    env = os.environ.copy()
    for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_PREFIX"):
        env.pop(key, None)
    env["GIT_OPTIONAL_LOCKS"] = "0"
    command = ["git", "--no-pager", "-c", "core.fsmonitor=false", "-C", str(cwd)]
    # Les filtres clean/process peuvent exécuter des programmes même pendant status.
    # Ne lire que leurs NOMS de configuration, jamais leurs valeurs/commandes.
    names = subprocess.run(command + ["config", "--name-only", "--get-regexp",
                                      r"^filter\..*\.(clean|process|required)$"],
                           env=env, capture_output=True, text=True, timeout=20)
    if names.returncode not in (0, 1):
        raise ValueError("Configuration des filtres Git illisible")
    filters = {key.rsplit(".", 1)[0] for key in names.stdout.splitlines() if key.startswith("filter.")}
    for prefix in sorted(filters):
        command += ["-c", prefix + ".clean=", "-c", prefix + ".process=", "-c", prefix + ".required=false"]
    result = subprocess.run(
        [*command, *args],
        env=env, capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise ValueError("Git en échec : " + args[0] + " (détails non affichés)")
    return result.stdout.strip()


def read_safe(path, base):
    path = path.absolute()
    base = base.resolve()
    if not path.is_relative_to(base):
        raise ValueError("Lecture hors portée refusée")
    for part in (path, *path.parents):
        if part == base:
            break
        if part.is_symlink():
            raise ValueError("Lien symbolique mémoire refusé : " + path.name)
    if not path.is_file() or path.stat().st_size > 65536:
        raise ValueError("Document mémoire absent/trop volumineux : " + path.name)
    return path.read_text(encoding="utf-8")


def current(text):
    if text.count(START) != 1 or text.count(END) != 1:
        raise ValueError("Roadmap : un seul bloc memory:current est requis")
    before, rest = text.split(START)
    block, after = rest.split(END)
    if not block.strip() or len(block.splitlines()) > 45:
        raise ValueError("Roadmap : bloc courant vide ou >45 lignes")
    return block.strip()


def validate_handoff(text):
    if len(text.splitlines()) > 100:
        raise ValueError("Passation >100 lignes : utiliser Git comme historique")
    for field in ("Updated", "Project", "Branch", "Base"):
        if len(re.findall(r"^" + field + r": .+$", text, re.M)) != 1:
            raise ValueError("Métadonnée absente/dupliquée : " + field)
    datetime.fromisoformat(meta(text, "Updated"))
    if not re.fullmatch(r"[0-9a-f]{40,64}", meta(text, "Base")):
        raise ValueError("Base Git invalide")
    for name in SECTIONS:
        if len(re.findall(r"^## " + name + r"$", text, re.M)) != 1:
            raise ValueError("Section absente/dupliquée : " + name)
        body = re.split(r"^## ", text.split("## " + name + "\n", 1)[1], maxsplit=1, flags=re.M)[0]
        if not body.strip():
            raise ValueError("Section vide : " + name)
    if "TODO" in text:
        raise ValueError("Brouillon TODO : à compléter avant une passation validée")


def meta(text, key):
    match = re.search(r"^" + key + r": (.+)$", text, re.M)
    return match[1].strip() if match else "(absent)"


def context():
    root = Path(git(Path.cwd(), "rev-parse", "--show-toplevel")).resolve()
    if (root / ".agents/seams.txt").is_file():
        project, roadmap = "CocoOS", "next_steps.md"
    elif (root / "docs/protocol.md").is_file():
        project, roadmap = "HostCompanion", "docs/ai/ROADMAP.md"
    else:
        raise ValueError("Dépôt CocoOS/HostCompanion non identifié ; lancer dans le bon worktree")
    branch = git(root, "rev-parse", "--abbrev-ref", "HEAD")
    head = git(root, "rev-parse", "HEAD")
    gitdir = Path(git(root, "rev-parse", "--absolute-git-dir")).resolve()
    return root, project, roadmap, branch, head, gitdir


def draft(project, branch, head, roadmap):
    values = {
        "Objectif": "TODO : objectif et portée de cette session.",
        "Termine": "TODO : seulement le travail démontré ; sinon À vérifier.",
        "Fichiers": "TODO : chemins pertinents, pas de diff ni contenu privé.",
        "Decisions": "TODO : liens ADR majeurs, raisons ; sinon aucune nouvelle décision.",
        "Tests": "NON EXÉCUTÉ par ce générateur. TODO : commandes, résultats et portée de preuve.",
        "Problemes": "TODO : problèmes observés, sans diagnostic inventé.",
        "Non resolu": "TODO : points ouverts et blocages.",
        "Prochaine action": "TODO : une action concrète + gate ; roadmap : " + roadmap,
        "Commits": "Base de reprise : `" + head + "`. TODO : commits utiles, ou non commité.",
        "Dependances croisees": "TODO : contrat/commit/action dans l'autre dépôt, ou aucun changement de contrat.",
    }
    text = ("# Passation\n\nUpdated: " + datetime.now(timezone.utc).isoformat(timespec="seconds")
            + "\nProject: " + project + "\nBranch: " + branch + "\nBase: " + head
            + "\n\nPortée : ce worktree ; brouillon NON VALIDÉ.\n")
    return text + "".join("\n## " + name + "\n\n" + values[name] + "\n" for name in SECTIONS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("resume", "handoff", "local-path", "check"))
    parser.add_argument("--save-local", action="store_true", help="handoff : créer sans écraser le brouillon local")
    parser.add_argument("--local", action="store_true", help="check : contrôler la passation locale plutôt que canonique")
    parser.add_argument("--compact", action="store_true", help="resume : ne pas répéter AGENTS.md (hook Claude)")
    args = parser.parse_args()
    if ((args.save_local and args.action != "handoff") or (args.local and args.action != "check")
            or (args.compact and args.action != "resume")):
        parser.error("Option incompatible avec l'action")
    root, project, roadmap, branch, head, gitdir = context()
    local = gitdir / "ai-memory/HANDOFF.md"
    if args.action == "local-path":
        print(local)
        return
    if args.action == "handoff":
        text = draft(project, branch, head, roadmap)
        if args.save_local:
            parent = local.parent
            if parent.is_symlink() or local.is_symlink():
                raise ValueError("Lien symbolique local refusé")
            parent.mkdir(mode=0o700, exist_ok=True)
            fd = os.open(local, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as output:
                output.write(text)
            print("Brouillon créé (aucun test exécuté) : " + str(local))
        else:
            print(text, end="")
        return
    block = current(read_safe(root / roadmap, root))
    canonical = read_safe(root / "docs/ai/HANDOFF.md", root)
    validate_handoff(canonical)
    if meta(canonical, "Project") != project:
        raise ValueError("Passation canonique d'un autre projet ; contenu non chargé")
    if args.action == "check":
        text = read_safe(local, gitdir) if args.local else canonical
        validate_handoff(text)
        if meta(text, "Project") != project:
            raise ValueError("Passation d'un autre projet")
        if args.local and meta(text, "Branch") != branch:
            raise ValueError("Passation locale d'une autre branche")
        if meta(text, "Branch") != branch:
            print("ATTENTION : passation héritée de " + meta(text, "Branch"))
        print("MEMORY STRUCTURE PASS (pas une validation des faits/tests ni de fraîcheur)")
        return
    print(f"[{project}] Worktree: {root}\nBranch: {branch}\nHEAD: {head}")
    if branch == "HEAD":
        print("ATTENTION : HEAD détachée, aucune tâche de branche à déduire")
    if not args.compact:
        print("\n--- AGENTS.md ---\n" + read_safe(root / "AGENTS.md", root))
    print("\n--- " + roadmap + " : état courant ---\n" + block)
    print("\n--- Passation canonique (contexte de sa branche) ---")
    if meta(canonical, "Branch") != branch:
        print("ATTENTION : passation héritée de " + meta(canonical, "Branch") + "; vérifier la tâche locale")
    print(canonical)
    print("\n--- Passation locale : " + str(local) + " ---")
    if local.exists() or local.is_symlink():
        text = read_safe(local, gitdir)
        if meta(text, "Branch") == branch and meta(text, "Project") == project:
            print(text)
        else:
            print("ATTENTION : portée locale différente ; contenu non chargé")
    else:
        print("Absente ; ne rien déduire sur les autres agents/worktrees.")
    print("\n--- Commits récents (historique, pas preuve de tests) ---\n"
          + git(root, "log", "-5", "--format=%h %s"))
    print("\n--- Git status (inclut index et non-suivis) ---\n"
          + (git(root, "status", "--short", "--untracked-files=normal", "--ignore-submodules=all") or "Propre"))
    for label, flags in (("Diff non indexé", []), ("Diff indexé", ["--cached"])):
        print("\n--- " + label + " : statistiques uniquement ---\n"
              + (git(root, "diff", *flags, "--no-ext-diff", "--no-textconv", "--ignore-submodules=all", "--stat") or "Aucun"))
    print("\nLire ensuite uniquement les sections/skills utiles ; examiner les diffs ciblés sans secrets.\n"
          "Filtres personnalisés et sous-modules ignorés : état indicatif des fichiers filtrés.\n"
          "Résumer fait / tâche / blocages / prochaine action ; terminer par session-memory.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print("MEMORY BLOCKED/FAIL : " + str(error), file=sys.stderr)
        sys.exit(1)
