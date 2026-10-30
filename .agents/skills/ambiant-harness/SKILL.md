---
name: ambiant-harness
description: Voir, capturer et tester l'UI console sans PC hôte : harnais docs/ui/ambiant/harness (qml-qt6, shot.sh, compare.py, qmltestrunner, menu en jeu). À utiliser pour vérifier objectivement un changement d'interface avant de le déclarer fini.
---

# Harnais de vérification de l'UI

Boucle conseillée après une modif d'UI :
1. `scripts/dev/test.sh` (ou le test ciblé) → doit être vert.
2. Capture `./shot.sh` de l'écran touché puis `./compare.py` contre la référence du prototype
   (`docs/ui/ambiant/ref/`) ; ouvrir et regarder l'image produite avant de conclure (si ton outil ne sait pas lire une image, te fier à
   l'écart chiffré de `compare.py` et le dire).
3. Si un test manque pour le comportement ajouté, l'écrire (`tst_<Composant>.qml`, même style que les existants).

## Harnais « Ambiant » : voir et vérifier l'UI sans PC hôte

Tout est dans `docs/ui/ambiant/harness/` (hors de `app/`, rien n'entre dans le build) :

```bash
cd docs/ui/ambiant/harness
qml-qt6 -I stubs Harness.qml -- view=HomeDemo          # l'accueil, 10 jeux de démo, au clavier
qml-qt6 -I stubs Harness.qml -- view=HomeDemo running=0   # Minecraft en cours : ↑ pour Reprendre / Quitter
qml-qt6 -I stubs Harness.qml -- view=ConsoleHomeDemo   # le vrai ConsoleHome sur faux modules
qml-qt6 Harness.qml -- view=PagesDemo page=code        # search|loading|pin|pin-error|code|code-busy|code-error|dialog|curtain
./shot.sh /tmp/a.png view=HomeDemo focus=6 drift=0 delay=2500   # capture (rendu GPU, sans fenêtre)
./compare.py /tmp/a.png ../ref/home-6-rdr2.png -o /tmp/diff.png # écart avec le prototype
./shot.sh /tmp/b.png view=HomeDemo do=options,down at=2500 delay=3700   # idem, après des actions
./shot.sh /tmp/c.png view=ConsoleHomeDemo do=right,pin noart=Hades\ II at=2600 delay=6500   # vrai ConsoleHome
./ref-capture.py                                       # régénère ../ref/ et art/ depuis le prototype
./make-sounds.py                                       # régénère app/gui/console/sounds/*.wav (dont boot-*)
./make-shadows.py                                      # régénère app/gui/console/shadows/*.png (ombres portées)
# menu en jeu (C++, hors appli) : compiler streammenu-shot.cpp (commande en tête du fichier), puis
# (streammenu-rows.cpp, compilé de même : vérifie la ligne sous la souris contre le dessin, « ok »)
# appui maintenu : page=confirm focus=1 hold=0.45, puis hold=1 holdDone=1 (la coche)
QT_QPA_PLATFORM=offscreen /tmp/streammenu-shot /tmp/m.png page=menu stats=1 backdrop=art/hades2.jpg
QT_QPA_PLATFORM=offscreen /tmp/streammenu-shot /tmp/m.png reveal=0.4 veil=0.5 blur=0.5 backdrop=art/hades2.jpg   # une étape d'animation
./shot.sh /tmp/d.png view=BootDemo size=1280x720 t=1400   # animation de démarrage, instant figé
../../../boot-animation/ref-capture.py [--slow]        # références du prototype de démarrage (ref/cold-<t>.png, slow-<t>.png)
node ../../../boot-animation/reference-values.js       # valeurs du prototype pour tst_BootTimeline
XDG_CONFIG_HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -import stubs -input tst_GameShelf.qml
# idem tst_Format, tst_Library, tst_ConsoleHome, tst_BootTimeline, tst_BootSplash… XDG_CONFIG_HOME vierge : sinon les réglages
# (favoris, jeux récents, dernier jeu) écrits par un passage précédent faussent les tests.
```

- `shot.sh` lance un **mutter headless** le temps de la capture : `QT_QPA_PLATFORM=offscreen`
  ne sait rendre qu'en logiciel (petits tracés approximatifs, pas de `MultiEffect`).
- `ref-capture.py` pilote **Brave** par le protocole DevTools (module Python `websockets`) :
  son option `--screenshot` ne rend jamais la main. Le mode plein écran du prototype (touche
  `F`) donne un écran noir, la capture ne l'utilise pas.
- `tst_GameShelf::test_springMatchesPrototype` mesure le temps réel. Ses échecs « à froid » (écart
  0,0828) venaient d'une mesure lancée juste après la reconstruction des vignettes par `init()`
  (étagère déjà sur 0, quand le test précédent y finit) : il attend désormais 500 ms (20 sur 20).
