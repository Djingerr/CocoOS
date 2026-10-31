# Cockpit : étendre la flotte existante, sans agent automatique

Date : 2026-10-31 · Statut : Retenue · Portée : environnement produit, pas protocole.

## Problème et options

Un lanceur global existant créait les fenêtres mais ignorait l'aide, supposait un
index zéro et utilisait des branches sans mémoire récente. Options : le remplacer
par un second orchestrateur ; adopter un framework ; étendre la flotte Git/tmux.

## Choix et raisons

Étendre `fleet.py` avec `cockpit.py`, une seule implémentation dans CocoOS et un
lanceur global qui délègue. Même verrou `.ai-fleet/lock`. Préflight des quatre
worktrees, shells sans chargement automatique d'agent, adoption non destructive
de la session reconnue, création idempotente des seules fenêtres absentes.
Les mises à niveau de branches sont un déploiement humain explicitement autorisé,
pas un comportement automatique du cockpit.

## Conséquences et limites

Sans fournisseur ni serveur supplémentaire. Les deux roadmaps restent indépendantes.
Le launcher installé dépend de son worktree source : le conserver ou réinstaller
depuis une nouvelle copie vérifiée. Quatre fenêtres n'autorisent pas quatre agents
actifs ; les lancements manuels ne sont pas mécaniquement limités par la flotte.
Téléphone : Web local + SSH/Tailscale après accord, ou remote-control agy explicite.
Ni tunnel public ni daemon permanent par défaut. Tests et limites :
`../ENVIRONMENT-AUDIT.md`, usages : `../COCKPIT.md`.
