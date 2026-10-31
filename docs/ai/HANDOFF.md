# Passation — mémoire universelle

Updated: 2026-10-31
Project: CocoOS
Branch: tooling/universal-memory
Base: 230e5aa5db0307a07c57fc7333339a4d1fdf2698

Portée : outillage et documentation de cette branche ; pas intégrée aux autres worktrees.

## Objectif

Permettre la reprise inter-modèles/CLI avec Markdown + Git, sans service ni clé supplémentaire.

## Termine

Mémoire implémentée et vérifiée localement : reprise, passation, ADR, branche/worktree,
adaptateurs natifs et guide. Industrialisation, roadmap et toutes les anciennes sections conservées.

## Fichiers

`AGENTS.md`, `docs/ai/PROJECT-REFERENCE.md`, `next_steps.md`, `docs/ai/MEMORY.md`,
`docs/ai/decisions/`, scripts mémoire, skill et adaptateurs CLI. Voir le diff Git, pas de copie ici.

## Decisions

ADR `decisions/2026-10-31-universal-memory.md` : Markdown versionné + passation locale par worktree.
Anciennes sections conservées dans `PROJECT-REFERENCE.md`, pas d'effacement de décisions.

## Tests

2026-10-31 Fedora : `python3 scripts/dev/test_memory.py` 22/22 PASS (code 0) ;
`scripts/dev/check.sh` PASS (59 tests + shell). `opencode-check.py --permissions`
PASS (serveur 2.2.4, 11 skills, 6 commandes, 19 permissions ; aucun appel LLM).
Reprise/hook direct et session IA indépendante à contexte réduit : PASS simulation.
Preuves/limites : `MEMORY-REPORT.md`. Aucun nouveau build Qt/Windows/matériel/E2E.

## Problemes

Revue : filtres Git potentiellement exécutables, projet canonique non contrôlé, tests
d'isolation incomplets. Corrigés et couverts par 22 régressions. Symlink skills Linux conservé.

## Non resolu

Autres fournisseurs et vraies sessions Claude/Codex NON EXÉCUTÉS ; CI GitHub non exécutée.
Mémoire non intégrée aux clones principaux. Windows/E2E/manette/Orange Pi toujours non prouvés ici.

## Prochaine action

Faire relire puis autoriser l'intégration de cette branche ; aucune fusion automatique.
Reprise : `python3 scripts/dev/memory.py resume` ; guide quotidien `MEMORY.md`.
Produit : organiser deux appareils pour E2E Companion ; ne pas recommencer l'UI existante.

## Commits

Base outillage `230e5aa5` ; commit mémoire à retrouver avec
`git log -3 --oneline` (message « mémoire: … »), sans hash auto-référent.

## Dependances croisees

HostCompanion : branche homonyme issue de `1e7220e`, mécanisme mémoire parallèle.
Aucun contrat modifié ; protocole canonique HostCompanion `docs/protocol.md`, READY avant stream.
