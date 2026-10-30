---
name: verify
description: Vérifier objectivement l'état de CocoOS — build embedded (et vanilla sur demande), tests QML du harnais, test de fumée hors réseau — et rendre un verdict PASS/FAIL compact. À faire avant de déclarer une tâche finie ou de passer une porte de phase.
---

# Vérification objective

On vérifie, on ne corrige pas pendant cette étape. Depuis la racine du dépôt, dans l'ordre :

1. `scripts/dev/build.sh embedded`
2. `scripts/dev/test.sh`
3. `scripts/dev/smoke.sh 8` (seulement si le build embedded est OK)
4. Sur demande, ou si une couture upstream a changé : `scripts/dev/build.sh vanilla`
   (le Moonlight vanilla doit rester intact).

En cas d'échec, lire au plus ~40 lignes pertinentes de `.dev/last-build.log` ou de `.dev/tests/<test>.log`
(recherche sur `error`, `FAIL`, le nom du test) pour localiser la cause.

Rapport, 15 lignes max :
```
BUILD embedded : PASS|FAIL
TESTS          : PASS (n/n) | FAIL (liste)
SMOKE          : PASS|FAIL|non lancé
Cause probable : fichier:ligne — message (si échec)
```
Un outil absent (qmake6, qmltestrunner-qt6…) donne « NON VÉRIFIÉ », jamais « PASS ».
