---
name: boot-animation
description: Déboguer et valider l'animation de démarrage « le O » (BootSplash, BootTimeline.js, variables COCOOS_BOOT_*, critère 60 i/s). À charger pour tout travail sur le boot, la veille/réveil ou le rideau de stream.
---

Spécification : `docs/boot-animation/BOOT_ANIMATION.md` (le prototype `docs/boot-animation/prototype.html` fait foi).

## Animation de démarrage : debug et validation

Variables d'environnement (lues par `SystemStatus.env`, cf. `docs/boot-animation/BOOT_ANIMATION.md` §10) :

```bash
COCOOS_BOOT_SPEED=0.25 ./app/moonlight          # ralentie (comparer au prototype à 0,25×)
COCOOS_BOOT_FAKE_DELAY_MS=4000 ./app/moonlight  # système prêt au plus tôt à 4 s : le O fait le chargeur
COCOOS_BOOT_MODE=wake ./app/moonlight           # variante sortie de veille
COCOOS_BOOT_LOOP=1 ./app/moonlight              # séquence en boucle, sans entrer dans l'accueil
```

À la fin de chaque séquence, le journal donne : `[console-ui] Démarrage (cold) : 3135 ms[, avec
chargeur (prêt à … ms)], image la plus longue 17.0 ms`. Sur le laptop (hors écran, hors réseau) :
3135 ms sans chargeur, 5670 ms avec `FAKE_DELAY_MS=4000`, plus longue image ≈ 17 ms.

**Validation sur l'Orange Pi (critère 7, 60 i/s)** : lancer en kiosk avec `QSG_RENDER_TIMING=1`
(temps de rendu par image dans le journal) et lire « image la plus longue » ; aucune image ne doit
dépasser 16,6 ms (une image ratée apparaît vers 33 ms). Si ça saccade : passer les propriétés de
transformation (`x`, `scale`, `opacity`) du logo sur des `Animator` (spec §3), et vérifier que
rien de synchrone ne tourne sur le fil GUI pendant la séquence (`SystemStatus` et `WifiSetup` ne
démarrent qu'à la fin, `start()`).
