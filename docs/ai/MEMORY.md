# Mémoire universelle — guide quotidien

La mémoire appartient au **dépôt et à la branche**, pas au fournisseur ni au chat.
Pré-requis : Python **3.9+**, Git, terminal dans le bon worktree. Aucun réseau/LLM
dans `memory.py`, aucune récupération de valeurs secrètes, aucune base vectorielle
ni clé supplémentaire. Ne jamais stocker de secrets dans les documents mémoire.
Les diagnostics Git peuvent lire les fichiers suivis pour calculer leur état,
mais ne retournent ici que noms/statistiques, jamais les contenus. Les filtres
Git clean/process et fsmonitor sont neutralisés, les sous-modules ignorés ;
l'état des fichiers normalement filtrés est donc indicatif. Ce n'est pas une sandbox.

## Démarrer / changer de modèle / changer de CLI

```bash
git rev-parse --show-toplevel
python3 scripts/dev/memory.py resume
```

Lire le résultat : règles communes, bloc courant de la roadmap, dernière passation,
locale éventuelle, commits, index/non-index/non-suivis. Puis seulement les sections
et skills nécessaires. Un autre modèle reçoit les **mêmes fichiers**, pas l'ancien
contexte privé. Instructions universelles pour tout CLI :

> Lis AGENTS.md, applique la Reprise de .agents/skills/session-memory/SKILL.md,
> résume fait / tâche / blocages / prochaine action, puis poursuis ma demande.

| CLI | Entrée persistante | Reprise / preuve de chargement |
|---|---|---|
| OpenCode 2.2.4 | `AGENTS.md` natif + `instructions` vers HANDOFF | `/task-resume` ; catalogue vérifiable sans LLM par `opencode-check.py` |
| Claude Code 2.1.314 | `CLAUDE.md` importe `@AGENTS.md` | Hook SessionStart → `resume --compact` ; `/context` vérifie les imports |
| Codex 0.164.0 | `AGENTS.md` selon convention native | Instruction commune ci-dessus ; pas de hook startup Codex ajouté |
| Autre CLI / modèle | Lecture explicite de `AGENTS.md` | Instruction commune ; aucun auto-chargement présumé |

Le hook Claude est configuré et son script peut être testé directement ; cela ne
prouve pas qu'une session Claude a effectivement chargé les instructions. De même,
un catalogue OpenCode ne prouve pas l'obéissance d'un modèle. Résultats datés dans
`MEMORY-REPORT.md`. Les références documentaires ne sont pas des tests d'exécution.
OpenCode reçoit la courte passation via `instructions` selon sa convention native ;
la roadmap et l'exécution de la reprise restent explicites. Pas d'auto-exécution prétendue.

OpenCode : `/task-resume` et `/task-handoff` n'imposent ni agent ni modèle et restent
dans la session courante. Un rôle lecture seule ne peut pas écrire une passation :
choisir un rôle autorisé ou transmettre les preuves. Les autres commandes historiques
peuvent sélectionner un rôle dont le modèle est épinglé. La whitelist abonnements
reste en place : ajouter un fournisseur exige un accord explicite, sans fallback payant.
Le format mémoire n'en dépend pas. Pas de plugin de fin de message ni hook silencieux.
Le skill `next` et `/task-next` rappellent la passation ; ce n'est pas un déclencheur garanti.

## Terminer / interrompre

OpenCode : `/task-handoff [portée]`. Claude : `/session-memory` si le lien skills est
fonctionnel ; sinon tout CLI : « applique la Passation du skill session-memory ».

```bash
python3 scripts/dev/memory.py handoff                 # trame stdout, aucune écriture
python3 scripts/dev/memory.py check                   # structure canonique seulement
```

L'agent examine les diffs ciblés, met à jour roadmap + `docs/ai/HANDOFF.md`, lie les
décisions et consigne les vrais tests. Le générateur n'infère **aucune validation**
du diff ou d'un ancien log. Il marque les tests NON EXÉCUTÉS. Le contrôle refuse un
brouillon contenant TODO ; un PASS structurel ne certifie ni les faits ni la fraîcheur.
Relire date, branche, base et critères avant de dire « terminé ». Garder HANDOFF sous
100 lignes ; Git conserve les versions précédentes (`git log -p -- docs/ai/HANDOFF.md`).
Archiver seulement une synthèse durable si nécessaire, jamais les conversations.

## Plusieurs agents / worktrees

Un écrivain par worktree, une tâche et un propriétaire explicite. Pour les agents
parallèles qui ne possèdent pas les documents suivis :

```bash
python3 scripts/dev/memory.py local-path              # chemin isolé, hors contenu suivi
python3 scripts/dev/memory.py handoff --save-local    # création exclusive, refuse d'écraser
python3 scripts/dev/memory.py check --local           # après édition factuelle de la locale
```

Le chemin est `<git-dir-du-worktree>/ai-memory/HANDOFF.md`, **pas** `--git-common-dir`.
Deux worktrees ne s'écrasent pas. Deux agents dans le même worktree ne sont PAS isolés :
ne pas leur donner la même écriture. La locale est machine-locale, non versionnée ;
elle disparaît si on supprime son worktree. Avant déplacement/suppression/changement
de machine : intégrer sa synthèse utile dans un commit autorisé de la branche.
Après changement de branche dans le même worktree, la reprise refuse de charger une
locale d'une autre branche ; la revoir et l'archiver manuellement avant remplacement.

Une branche ne voit pas les commits non intégrés de ses voisines. Pour transmettre un
travail non commité, fournir explicitement son worktree **en lecture seule**, pas une
supposition d'intégration. Ne pas modifier les worktrees d'autrui. Après intégration
Git **autorisée**, l'intégrateur désigné réconcilie le bloc courant des deux roadmaps,
les ADR et HANDOFF ; vérifier les preuves/contradictions, pas un « dernier fichier gagne ».
Si un agent n'a pas la propriété de la roadmap, il prépare ses propositions dans la
passation locale au lieu de la modifier simultanément.

## Décisions / produit commun / fraîcheur

- Chercher d'abord `docs/ai/decisions/README.md` puis Git ; les anciens §N désignent
  `docs/ai/PROJECT-REFERENCE.md`, pas un chargement automatique du gros document.
- Nouveau choix majeur : `decisions/YYYY-MM-DD-sujet.md` ; voir le gabarit de l'index.
  Réviser une décision par lien « remplace… », conserver l'ancienne justification.
- Deux roadmaps distinctes : CocoOS `next_steps.md`, HostCompanion `docs/ai/ROADMAP.md`.
  Contrat unique : **HostCompanion `docs/protocol.md`**. Une évolution indique les
  deux branches/commits, l'ordre d'intégration et tests de compatibilité ; jamais
  de copie divergente du protocole. Aucun changement de contrat pour cette mémoire.
- Vérifier le bloc courant, HANDOFF, `git log -5 --oneline`, status et critères
  réels. Un statut hérité ou une date récente n'est pas une preuve de validation.
- Tests mémoire : `python3 scripts/dev/test_memory.py` (fixtures temporaires,
  deux worktrees, aucun fournisseur). Qualité existante : `scripts/dev/check.sh`.

Sources : [OpenCode instructions](https://opencode.ai/v2/docs/instructions),
[commandes](https://opencode.ai/v2/docs/commands), [skills](https://opencode.ai/v2/docs/skills),
[Claude mémoire](https://code.claude.com/docs/en/memory),
[Codex AGENTS](https://developers.openai.com/codex/guides/agents-md/), consultées le 2026-10-31.
