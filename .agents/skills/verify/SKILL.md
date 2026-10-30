---
name: verify
description: Vérifier objectivement l'état de CocoOS — outillage, build embedded (et vanilla sur demande), tests QML, fumée isolée — et rendre un verdict PASS/FAIL/BLOCKED. À faire avant de déclarer une tâche finie ou de passer une porte de phase.
---

# Vérification objective

On vérifie, on ne corrige pas pendant cette étape. Depuis la racine du dépôt, dans l'ordre :

0. Si outillage modifié : `scripts/dev/check.sh` (syntaxe + tests isolés des hooks/scripts).
1. `scripts/dev/build.sh embedded`
2. `scripts/dev/test.sh`
3. `scripts/dev/smoke.sh 8` (seulement si le build embedded est OK)
4. Sur demande, ou si une couture upstream a changé : `scripts/dev/build.sh vanilla`
   (le Moonlight vanilla doit rester intact).
5. Si QML modifié : `scripts/dev/check.sh --qml <fichiers.qml ...>` (Qt6 uniquement ;
   imports C++ absents = BLOCKED, pas un bug QML prouvé). Conserver tests runtime/build.
6. Si chaînes modifiées : `scripts/dev/i18n.sh --check` (read-only pour TS/QM/QRC).

Ne pas lancer smoke après vanilla : reconstruire embedded d'abord. Archiver le log/statut
du premier build avant le suivant (ex. `.dev/build-embedded.log`). Aucune suite sélectionnée,
outil/sous-module absent ou `unshare` interdit = BLOCKED (code 2), jamais PASS.

En cas d'échec, lire au plus ~40 lignes pertinentes de `.dev/last-build.log` ou de `.dev/tests/<test>.log`
(recherche sur `error`, `FAIL`, le nom du test) pour localiser la cause.

Rapport, 15 lignes max :
```
BUILD embedded : PASS|FAIL|BLOCKED
TESTS          : PASS (n/n) | FAIL (liste) | BLOCKED
SMOKE          : PASS|FAIL|BLOCKED|non lancé
Cause probable : fichier:ligne — message (si échec)
```
Un contrôle non exécuté donne BLOCKED / « NON VÉRIFIÉ », jamais PASS. Rapporter commande,
code, cause et chemin du log ; ne pas confondre fixtures simulées avec validation réelle.
Contrats et limites : `docs/ai/QUALITY.md`. Pour initialiser explicitement les sous-modules
avec réseau autorisé : `scripts/dev/setup.sh --submodules` ; aucun SDK/sudo automatique.
