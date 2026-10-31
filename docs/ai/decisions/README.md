# Décisions techniques — index léger

Ne pas recopier les choix déjà documentés :

| Décision existante | Source / justification |
|---|---|
| Fork UI isolé, coutures additives, vanilla préservé, qmake | `../PROJECT-REFERENCE.md` §3–4 et skill `cocoos-build` |
| Ambiant et veille | skill `cocoos-ui`, `../../../next_steps.md` (choix et gates datés) |
| Produit GPLv3, hardware + service | `../PROJECT-REFERENCE.md` §1 et §7 |
| Companion READY avant stream, repli si absent | `../PROJECT-REFERENCE.md` §9 ; contrat HostCompanion `docs/protocol.md` |
| Flux / aucune nouvelle couture sans gate | `../../stream/STREAM-OPTIMISATION.md` |
| Autres raisons historiques | `../HISTORY.md` (recherche ciblée) et Git |
| Mémoire commune, branche + local worktree | [ADR 2026-10-31](2026-10-31-universal-memory.md) |
| Cockpit sobre, flotte existante, aucun agent automatique | [ADR cockpit](2026-10-31-cockpit-service.md) |

Nouvelle décision majeure : fichier `YYYY-MM-DD-sujet.md`, statut **Proposée** ou
**Retenue**, portée/branche/date, puis : Problème, Options, Choix, Raisons,
Conséquences et limitations, Preuves/références. Pour un contrat : dépendances
dans les deux dépôts, commits attendus, compatibilité et ordre d'intégration.
Une révision lie l'ancienne décision (« remplace… »), sans effacer son raisonnement.
