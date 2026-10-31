# Mémoire universelle Markdown + Git

Date : 2026-10-31 · Statut : Retenue pour `tooling/universal-memory`.
Portée : outillage des deux dépôts, pas de changement produit/protocole.

## Problème

Le contexte des chats et la mémoire privée d'un CLI ne suivent ni les changements
de modèle ni les branches. Les règles détaillées saturent le point d'entrée ; les
passations mélangées à l'historique ne distinguent pas toujours code et validation.

## Options

1. Mémoire fournisseur ou unique journal global : dépendance et ambiguïtés entre branches.
2. Base vectorielle/MCP/service : coût, configuration et synchronisation inutiles ici.
3. Fichiers Git + passation locale isolée : lisible par tous, simple et hors ligne.

## Choix et raisons

Option 3. AGENTS court pour les règles, roadmap existante pour la direction,
HANDOFF pour la dernière session de branche, ADR pour les nouveaux choix majeurs.
Les anciennes consignes sont conservées dans PROJECT-REFERENCE, pas supprimées.
Un skill commun porte la procédure ; `memory.py` ne décide pas d'un résultat de test.
La locale vit dans le git-dir du worktree, jamais dans le répertoire Git commun.
Un seul écrivain par worktree ; intégrateur désigné pour les documents de branche.

## Conséquences et limitations

Aucun service, secret ou fournisseur supplémentaire. Scripts autonomes identiques
dans les deux dépôts (vérifier leur égalité lors d'une évolution de l'outillage).
Les fichiers suivis ne traversent pas les branches sans intégration autorisée ;
les locales ne traversent pas les machines. Pas de synchronisation invisible.
Les modèles doivent appliquer la procédure : aucun Markdown ne garantit leur
obéissance. Contrôle structurel ≠ validation factuelle. Aucune fin de message
ne réécrit une roadmap. Le hook Claude fournit seulement un contexte de reprise.

## Références et dépendances

Demande utilisateur du 2026-10-31, `../MEMORY.md`, `../MEMORY-REPORT.md` pour preuves.
Même ADR dans HostCompanion, branche homonyme ; base CocoOS `230e5aa5`,
HostCompanion `1e7220e`. Aucun changement de `HostCompanion/docs/protocol.md` ;
aucune dépendance d'ordre runtime, intégrations Git humaines séparées.
