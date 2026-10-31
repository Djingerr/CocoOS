---
name: session-memory
description: Reprendre une session, changer de modèle ou de CLI, préparer une passation ou terminer une tâche avec une mémoire Git factuelle et propre au worktree.
---

# Mémoire commune — reprise / passation

Chemins relatifs à la **racine Git active**, pas au répertoire du skill.

## Reprise

1. Identifier le worktree demandé : `git rev-parse --show-toplevel` ; ne pas utiliser
   un clone frère par commodité. Lancer `python3 scripts/dev/memory.py resume`.
2. Vérifier date, projet, branche et base des passations. La locale décrit la tâche
   du worktree, la canonique le dernier état partagé de **sa** branche. En cas de
   divergence, conserver les deux et demander si la priorité n'est pas claire.
3. Lire le bloc courant de la roadmap puis seulement les sections/commits utiles.
   Examiner index, diff non indexé et non-suivis pertinents, sans lire de secrets.
   Un diff vide ne signifie pas que les fichiers non suivis sont commités.
4. Charger seulement les skills nécessaires. Résumer en 4 lignes : fait, en cours,
   blocages, prochaine action. Continuer la demande, pas une ancienne tâche arbitraire.

## Passation

1. Relire AGENTS et `docs/ai/MEMORY.md` si la politique worktree n'est pas connue.
   Lancer `python3 scripts/dev/memory.py resume --compact` pour l'état actuel.
2. Examiner **les deux diffs ciblés** : `git diff --no-ext-diff --no-textconv -- <chemins sûrs>`
   et variante `--cached` ; inclure les non-suivis pertinents. Pas de dump global
   pouvant contenir secrets/credentials ; ne jamais lire ceux-ci.
3. `python3 scripts/dev/memory.py handoff` fournit une trame, **pas une preuve**.
   Il n'exécute aucun test. Pour les tests réellement exécutés : commande, code
   retour, date/environnement, résultat PASS/FAIL/BLOCKED/NON EXÉCUTÉ, portée.
   Sans preuve de session ou log sûr explicitement identifié : NON EXÉCUTÉ, pas PASS.
4. Actualiser le bloc courant et la section utile de la roadmap, sans effacer les
   anciens choix : À faire / En cours / Terminée / Bloquée / À vérifier. Terminée
   exige des critères de validation démontrés, pas seulement du code écrit.
5. Décision majeure nouvelle seulement : ADR problème/options/choix/raisons/
   conséquences ; sinon lien vers le choix existant. Aucun ADR par petite retouche.
6. Écrivain désigné de branche : actualiser `docs/ai/HANDOFF.md` (<100 lignes).
   Agent parallèle : créer au besoin `handoff --save-local`, éditer **seulement**
   le chemin de `local-path`. Ne pas écraser une passation existante. Ne pas
   réutiliser une locale après changement de branche sans la revoir.
   Si les documents suivis ont un autre propriétaire actif, préparer les changements
   de roadmap/ADR dans la locale pour l'intégrateur, sans les éditer simultanément.
7. Inclure date, projet/branche/base, objectif, fait, fichiers, décisions/raisons,
   tests, problèmes/non-résolu, prochaine action et commits. Contrat croisé : dépôt,
   branche/commit attendu, action dépendante et validation de chaque côté.
8. `python3 scripts/dev/memory.py check` (ou `check --local`) contrôle la structure,
   **pas la vérité ni la fraîcheur**. Relire le diff documentation. Commit ciblé si
   autorisé seulement ; pas de push/merge automatique. Base + `git log` suffisent :
   ne pas essayer d'inscrire le futur hash d'un commit dans le commit lui-même.
9. Résumé : fait / réellement testé / bloqué ou non testé / prochaine action.
   Si l'écriture est impossible, donner la passation dans la réponse et préciser
   qu'elle **n'est pas persistée**. Aucun faux succès de sauvegarde.
