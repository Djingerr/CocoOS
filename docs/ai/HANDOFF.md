# Passation — audit final et cockpit

Updated: 2026-10-31
Project: CocoOS
Branch: tooling/environment-finalisation
Base: c9335cb3f10762e72ceb39718770207eeaea7054

Portée : outillage produit ; quatre branches ai/* avancées par fast-forward explicitement autorisé.

## Objectif

Auditer l'installation et mettre console-diy en service sans modèle automatique ni exposition distante.

## Termine

Cockpit unique via flotte existante, six fenêtres, monitoring, --check et --verify opérationnels.
Mémoire et hooks présents dans les quatre worktrees ; sessions/fichiers utilisateur préservés.

## Fichiers

`scripts/dev/fleet.py`, `cockpit.py`, `cockpit-test.py`, `console-diy`, CI, guides/ADR.
Global : lanceur et cli.json sauvegardés puis corrigés après accord. Voir ENVIRONMENT-AUDIT.md.

## Decisions

ADR `decisions/2026-10-31-cockpit-service.md` : étendre la flotte, aucun agent/tunnel/merge automatique.
Plugin sous-agents non forcé après conflit de dépendances ; statistiques natives conservées.

## Tests

2026-10-31 : 13 tests cockpit, 59 outillage, 22 mémoire, huit flotte PASS.
--verify et deux réouvertures réelles PASS ; --check code 2 attendu (SDK/plugin BLOCKED).
OpenCode : 19 permissions PASS sans LLM. Build embedded + smoke sur CocoOS-tooling PASS ;
dernière suite QML 17/17 PASS sur CocoOS-ops ; qmllint KeyHint PASS. Rapport : ENVIRONMENT-AUDIT.md.

## Problemes

Ancien lanceur ignorait --help/index tmux non nul : corrigé ; reprise setup et worktrees sans mémoire corrigées après revue indépendante. Premier passage QML :
échec test_9o puis timeout externe ; passe complète suivante verte, instabilité à surveiller.

## Non resolu

Plugin sous-agents FAIL installation (dépendances), service BLOCKED. SDK WindowsDesktop absent côté HC.
Téléphone/SSH, inférence/quota, statistiques live, Windows/E2E/manette/Orange Pi et CI NOT TESTED.
Les clones principaux restent anciens/inchangés ; utiliser les worktrees du cockpit.

## Prochaine action

Utiliser console-diy ; décider séparément du SDK Windows et du plugin compatible.
Configurer SSH/ACL Tailscale et appairer le téléphone seulement après accord : guide COCKPIT.md.
Produit : validation E2E à deux appareils toujours ouverte ; ne pas recommencer l'UI.

## Commits

Mémoire `3a373499`, code cockpit `c9335cb3` ; complément final : git log -3 --oneline.
Fast-forwards ai/coco-opencode et ai/coco-antigravity autorisés, pas de push/merge de feat/cocoos-ui.

## Dependances croisees

HostCompanion : tooling/environment-finalisation, code de4a4ee ; 125 Shared PASS, build/style BLOCKED SDK.
Aucun contrat modifié ; protocole canonique HostCompanion `docs/protocol.md`, READY avant stream.
