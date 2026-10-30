#!/usr/bin/env python3
"""Vérifier OpenCode V2 réellement chargé, sans appel LLM ni lecture de credentials."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--directory", type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument("--permissions", action="store_true", help="évaluations synthétiques ; session de test créée puis supprimée, aucune commande dangereuse exécutée")
    a = p.parse_args()
    directory = a.directory.resolve()
    root = Path(subprocess.check_output(["git", "-C", str(directory), "rev-parse", "--show-toplevel"], text=True).strip())
    config = json.loads((root / "opencode.json").read_text())

    def api(method, path, body=None):
        args = ["opencode", "api", method, path, "--header", "x-opencode-directory:" + str(directory)]
        if body is not None:
            args += ["--data", json.dumps(body)]
        # Certains retours volumineux du CLI 2.2.4 sont parfois tronqués. Deux lectures max.
        for _ in range(2):
            if method == "get" and path in ("/api/agent", "/api/model", "/api/skill", "/api/command"):
                # CLI 2.2.4 can exit before flushing a large stdout pipe. Only these
                # known catalogues are spooled to a private file, never credentials.
                temp_directory = "/tmp/opencode" if Path("/tmp/opencode").is_dir() else None
                with tempfile.TemporaryFile(mode="w+", encoding="utf-8", dir=temp_directory) as output:
                    r = subprocess.run(args, text=True, stdout=output, stderr=subprocess.PIPE, timeout=90)
                    output.seek(0)
                    stdout = output.read()
            else:
                r = subprocess.run(args, text=True, capture_output=True, timeout=90)
                stdout = r.stdout
            if r.returncode:
                raise RuntimeError(f"API {method} {path} : code {r.returncode} (aucun secret affiché)")
            if not stdout.strip():
                return None
            try:
                result = json.loads(stdout)
                if isinstance(result, dict) and ("error" in result or "_tag" in result):
                    raise RuntimeError(f"API {path} : réponse d'erreur")
                return result
            except json.JSONDecodeError:
                pass
        raise RuntimeError(f"API {path} : réponse JSON tronquée/invalide (BLOCKED)")

    info = api("get", "/api/info")
    print("OpenCode serveur :", info["version"])
    if not info["version"].startswith("2."):
        raise RuntimeError("configuration destinée à V2 uniquement")
    agents = {x["id"]: x for x in api("get", "/api/agent")["data"]}
    models = {(x["providerID"], x["id"]): x for x in api("get", "/api/model")["data"]}
    roles = ("architect", "developer", "explorer", "reviewer", "verifier", "documentation")
    for role in roles:
        agent = agents.get(role)
        if agent is None:
            raise RuntimeError(f"agent non chargé : {role}")
        model = agent.get("model", {})
        ref = (model.get("providerID"), model.get("id"))
        if ref not in models:
            raise RuntimeError(f"modèle indisponible pour {role}")
        print(f"PASS agent {role}: {'/'.join(ref)}")
    if any(provider not in ("openai", "claude-agent") for provider, _ in models):
        raise RuntimeError("un fournisseur hors abonnements reste visible ; vérifier les politiques globales")
    skills = {x["id"]: x for x in api("get", "/api/skill")["data"]}
    local = list((root / ".agents/skills").glob("*/SKILL.md"))
    for path in local:
        loaded = skills.get(path.parent.name)
        if loaded is None or Path(loaded["path"]).resolve() != path.resolve():
            raise RuntimeError(f"skill local masqué/absent : {path.parent.name}")
    print(f"PASS skills : {len(local)} sources canoniques .agents/skills détectées")
    commands = {x["name"] for x in api("get", "/api/command")["data"]}
    if not set(config["commands"]).issubset(commands):
        raise RuntimeError("commandes locales manquantes")
    print(f"PASS commandes : {', '.join(config['commands'])}")
    if not a.permissions:
        print("Permissions : NON TESTÉES (ajouter --permissions). Aucune requête LLM effectuée.")
        return
    session = api("post", "/api/session", {"title": "tooling-permission-check-no-model", "location": {"directory": str(directory)}, "agent": "developer"})["data"]["id"]
    cases = [
        ("shell", "git push origin HEAD", "developer", "deny"),
        ("shell", "git -C . push origin HEAD", "developer", "deny"),
        ("shell", "git reset --hard", "developer", "deny"),
        ("shell", "git clean -fd", "developer", "deny"),
        ("shell", "git commit --no-verify", "developer", "deny"),
        ("shell", "sudo dnf install example", "developer", "deny"),
        ("shell", "git status --short", "developer", "allow"),
        ("shell", "git merge example", "developer", "ask"),
        ("external_directory", "/tmp/outside-project/*", "developer", "ask"),
        ("read", ".env", "developer", "deny"),
        ("edit", "docs/permission-fixture.md", "architect", "deny"),
        ("edit", "docs/permission-fixture.md", "explorer", "deny"),
        ("edit", "docs/permission-fixture.md", "reviewer", "deny"),
        ("edit", "docs/permission-fixture.md", "verifier", "deny"),
        ("execute", "*", "reviewer", "deny"),
        ("shell", "touch permission-fixture", "reviewer", "deny"),
    ]
    if (root / ".agents/seams.txt").exists():
        cases += [("edit", "app/gui/main.qml", "developer", "deny"),
                  ("edit", "app/streaming/session.cpp", "developer", "deny"),
                  ("edit", "app/gui/console/PermissionFixture.qml", "developer", "allow")]
    else:
        cases += [("edit", "third-party/new.dll", "developer", "deny"),
                  ("edit", "third-party/versions.lock.json", "developer", "ask"),
                  ("edit", "docs/protocol.md", "developer", "ask"),
                  ("edit", "src/PermissionFixture.cs", "developer", "allow")]
    try:
        for action, resource, agent, expected in cases:
            effect = api("post", f"/api/session/{session}/permission", {"action": action, "resources": [resource], "agent": agent})["data"]["effect"]
            if effect != expected:
                raise RuntimeError(f"{agent} {action}:{resource} : {effect}, attendu {expected}")
        print(f"PASS permissions : {len(cases)} évaluations synthétiques serveur ; aucune opération exécutée")
    finally:
        api("delete", "/api/session/" + session)
    print("PASS OpenCode ; aucun appel LLM, credential ou fournisseur supplémentaire.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print(f"OpenCode CHECK BLOCKED/FAIL : {exc}", file=sys.stderr)
        sys.exit(1)
