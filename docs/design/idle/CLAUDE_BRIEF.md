# Brief Claude Code — Écran de veille CocoOS en QML

> Point d'entrée. Lis ce fichier en entier, puis `SPEC.md` et `tokens.json`, avant d'écrire du code.
> Travaille phase par phase. Une phase n'est terminée que lorsque sa **porte de validation** est passée.
> Note l'avancement dans le `next_steps.md` du dépôt (ou crée-le s'il n'existe pas).

## Mission

Implémenter dans la console CocoOS (fork moonlight-qt, Qt 6, QML) l'écran de veille affiché quand
l'utilisateur est inactif, en reproduisant **le plus fidèlement possible** les quatre maquettes
validées (écrans 09 à 12, style Premium inspiré d'Apple) :

| Écran | État | Référence |
|---|---|---|
| 09 | Jeu en cours | `reference/png/09_jeu_final.png` |
| 10 | Jeu en cours + téléchargement | `reference/png/10_jeu_telechargement_final.png` |
| 11 | Téléchargement seul | `reference/png/11_telechargement_final.png` |
| 12 | Repos (ni jeu ni téléchargement) | `reference/png/12_repos_final.png` |

## Contenu du dossier

| Chemin | Rôle |
|---|---|
| `SPEC.md` | Spécification écran par écran : structure, styles, animations, formats de texte, correspondances CSS → QML. |
| `tokens.json` | Couleurs, typo (interlettrage déjà en px), rayons, effets, courbes et durées d'animation. |
| `reference/png/*_final.png` | Rendu cible à t = 3 s (entrée terminée), 1280 × 720, horloge figée au 27/10/2026 21:46. |
| `reference/png/*_entree.png` | Même écran à t = 0,45 s, pour le rythme de l'animation d'entrée. |
| `reference/layout/*.json` | Rectangle, police, graisse, interlettrage, couleur de **chaque élément**, mesurés sur la maquette. Source de vérité pour les positions. |
| `reference/html/*.html` | Maquettes autonomes ouvrables dans Chromium. Paramètres : `?now=2026-10-27T21:46:00&at=3&drift=false`. |
| `reference/dc-source/*.dc.html` | Sources originales des maquettes (HTML/CSS). Lis-les pour toute valeur absente de la spec. |
| `mock/idle_status.mock.json` | Données de test pour les quatre états. |
| `assets/` | `grain_256.png`, `cover_shadow_626x760.png` (ombre pré-rendue), `placeholder_cover_600x848.png` (jaquette de test), `icons/*.svg`. |
| `tools/compare.py` | Compare une capture QML à la référence (écart global, écart par zone, carte de chaleur). |
| `tools/capture_reference.py`, `tools/extract_layout.py`, `tools/dc_to_standalone.py` | Ont servi à produire `reference/` ; utiles seulement si les maquettes changent. |

Les chemins `reference/`, `assets/`, `mock/` et `tools/` sont relatifs à ce dossier. Les assets et le mock sont à **copier** dans `app/gui/console/idle/` (et à déclarer dans le `.qrc`) : le code ne doit jamais lire ce dossier de documentation à l'exécution.

**Ordre de priorité en cas de contradiction :** PNG de référence et `layout/*.json` > `dc-source` > `SPEC.md` > `tokens.json`.

## Contraintes non négociables

1. **Stratégie additive** : tout le code nouveau vit sous `app/gui/console/` (proposé :
   `app/gui/console/idle/`). Aucune modification de fichiers upstream de moonlight-qt en dehors
   des « coutures » déjà existantes (`app.pro`, `qml.qrc`, `main.cpp`), et seulement pour
   enregistrer de nouveaux fichiers si c'est indispensable. Si la console a déjà son propre `.qrc`,
   y ajouter les fichiers plutôt que dans `qml.qrc`.
2. **Police** : Sora uniquement, celle déjà utilisée par CocoOS dans le dépôt. Ne pas introduire
   d'autre police. Si elle est absente, le signaler et s'arrêter sur ce point.
3. **Thème** : si un thème QML synchronisé depuis Figma existe déjà, y mapper les tokens au lieu
   de dupliquer les valeurs.
4. **OLED** : noir pur `#000` en fond. Jamais de voile gris sur les zones noires (attention au
   grain : fusion *overlay* uniquement, voir SPEC §2).
5. **Pas d'invention** : aucun élément, texte ou effet qui n'est pas dans les maquettes. Les textes
   sont en français, exactement comme dans la spec.
6. **Matériel** : cible RK3588S (GPU Mali-G610, Panfrost/Panthor), 60 fps visés. Tout ce qui est
   performance sur l'appareil reste validé par un humain (phase 6) ; ne pas déclarer « fluide »
   sans mesure sur l'Orange Pi.
7. Branche de travail : partir de `console-ui`, créer `feat/idle-screen`.

## Arborescence cible (proposition, à adapter à l'existant)

```
app/gui/console/idle/
  IdleScreen.qml            racine : choix de l'état, fondu entre états, sortie, dérive, mise à l'échelle
  IdleTheme.qml             singleton de tokens (ou mapping vers le thème existant)
  IdleStatus.qml            modèle de données (interface ci-dessous), alimenté par le mock pour l'instant
  IdleStatusMock.qml        charge mock/idle_status.mock.json, simule progression et gigue de latence
  Format.js                 formats de texte français (SPEC §5)
  screens/
    IdleGameScreen.qml      écrans 09 et 10 (propriété showDownload)
    IdleDownloadScreen.qml  écran 11
    IdleRestScreen.qml      écran 12
  components/
    BlurredBackdrop.qml     jaquette floue + pan + composition vignettage/grain
    CoverCard.qml           jaquette : ombre, liseré, lumière, reflet glissant, reflet au sol, inclinaison 3D
    EntryReveal.qml         enveloppe d'animation d'entrée (délai, durée, flou optionnel)
    StatusLine.qml, KeyHint.qml, TopRightClock.qml, DurationText.qml,
    ProgressRing.qml, HairlineProgress.qml, GlassCapsule.qml, GradientText.qml
  shaders/                  sources .frag + .qsb précompilés (si shaders personnalisés)
  assets/                   copie de assets/ de ce dossier
  preview/IdlePreview.qml   lanceur autonome pour le développement et les captures
  tests/tst_format.qml      tests des formats de texte (qmltestrunner)
```

## Modèle de données (interface à respecter)

`IdleStatus` expose ces propriétés. Plus tard, un fournisseur C++ alimenté par HostCompanion
remplacera le mock sans toucher aux écrans.

```
state: "game" | "gameDownload" | "download" | "rest"   (dérivé, voir SPEC §1)
now: date                                             (surchargeable pour les captures)
host     { name, reachable, inGame, sleeping }
network  { kind: "wifi" | "lte", latencyMs, rssiDbm | quality }
battery  { percent, charging, minutesLeft }
session  { active, connectedAt: date, game { title, publisher, genre, coverUrl } }
download { active, kind: "update" | "install", title, progress 0..1, bytesPerSec, etaSeconds, game {…} }
lastGame { title, coverUrl, lastPlayedAt: date }
```

## Phases

### Phase 0 — Reconnaissance (aucun code)
- Version de Qt sur le poste de dev **et** sur l'image de l'Orange Pi (`qmake6 -query QT_VERSION`).
- Disponibilité de `QtQuick.Effects` (`MultiEffect`, Qt ≥ 6.5), `QtQuick.Shapes`, de l'outil `qsb`
  (Qt Shader Tools), de `font.features` (Qt ≥ 6.6), du module Qt SVG.
- Emplacement de Sora dans le dépôt, du thème existant, de `ConsoleHome`, organisation des `.qrc`.
- Comment l'interface console reçoit la manette (moonlight-qt convertit normalement la manette en
  événements clavier pour l'interface via `SdlGamepadKeyNavigation` : à confirmer).

**Porte :** une section « Écran de veille — reconnaissance » dans `next_steps.md` avec les versions,
les modules disponibles et le choix technique qui en découle : chemin `MultiEffect`, ou repli
(`Qt5Compat.GraphicalEffects` / shaders maison) si la cible est sous Qt 6.5.

### Phase 1 — Fondations
`IdleTheme`, `IdleStatus`, `IdleStatusMock`, `Format.js`, `tests/tst_format.qml` couvrant chaque
ligne du tableau SPEC §5 (durées, débits, temps restants, dates relatives, date longue).

**Porte :** compilation propre, `qmllint` sans avertissement sur `idle/`, tous les tests verts.

### Phase 2 — Composants
Construire chaque composant de l'arborescence, avec les recommandations SPEC §6. Points à soigner :
- **Backdrop** : flouter une seule fois une version basse résolution de la jaquette, puis animer
  seulement la transformation de la couche floue. Vignettage + grain overlay + saturation dans un
  seul passage de composition.
- **CoverCard** : inclinaison via `Matrix4x4` (perspective 1400 px), pas `Rotation` (1024 px fixes).
  Ombre = image pré-rendue. Reflet glissant rogné par les coins arrondis.
- **EntryReveal** : délai, durée, courbe `appleOut`, flou d'entrée derrière un drapeau
  `IdleTheme.entryBlur` (activé par défaut).

**Porte :** chaque composant s'affiche isolément dans `IdlePreview` sans erreur dans la console QML.

### Phase 3 — Écrans et machine d'état
`IdleGameScreen` (09 et 10), `IdleDownloadScreen` (11), `IdleRestScreen` (12), puis `IdleScreen` :
sélection de l'état, fondu 600 ms entre états avec entrée rejouée, dérive anti-marquage, mise à
l'échelle 1280 × 720 → écran réel, sortie (320 ms) sur toute touche puis signal `wakeRequested()`.

**Porte :** les quatre états s'affichent depuis le mock, le basculement d'état et la sortie
fonctionnent.

### Phase 4 — Parité visuelle (boucle fermée)
`IdlePreview.qml` doit accepter :

```
qml app/gui/console/idle/preview/IdlePreview.qml -- \
    --state game|gameDownload|download|rest \
    --now 2026-10-27T21:46:00 --no-drift --grab-after 3000 --grab captures/09_jeu.png
```

`--grab-after` capture la fenêtre 1280 × 720 (via `grabToImage`) le nombre de ms indiqué après
le démarrage, puis quitte. En interactif : touches 1 à 4 pour l'état, R pour rejouer l'entrée,
B pour basculer `entryBlur`.

Pour chaque écran :

```
python3 tools/compare.py reference/png/09_jeu_final.png captures/09_jeu.png
```

Corriger en partant des zones de la grille 8 × 4 qui ont le plus d'écart. Contrôler les positions
de texte avec `reference/layout/*.json` : tolérance ±2 px, même taille et même graisse. Recommencer
avec `--grab-after 450` contre `*_entree.png` pour le rythme d'entrée.

**Porte :**
- écart moyen global ≤ 6/255 sur chaque écran à t = 3 s ;
- aucune zone de la grille au-dessus de 15 ;
- tous les textes à ±2 px de `layout/*.json`.

Joindre les captures et cartes d'écart dans `captures/`. Si une porte est inatteignable pour une
raison technique (rendu de police, flou), l'expliquer avec la carte d'écart plutôt que de forcer.

### Phase 5 — Intégration dans la console
- Minuterie d'inactivité, 120 s par défaut, configurable. Toute entrée réarme la minuterie.
- `IdleScreen` passe au-dessus de l'accueil en fondu. `wakeRequested()` le ferme et rend le focus
  à l'accueil.
- Brancher `IdleStatus` sur les données réelles déjà disponibles côté console (batterie, Wi-Fi,
  latence). Garder le mock pour tout ce qui viendra de HostCompanion (session, téléchargements,
  jaquettes Playnite) et le marquer `TODO(HostCompanion)`.

**Porte :** l'application compile avec `qmake6` et lance la veille après inactivité. `git diff
--stat` ne montre aucune modification hors de `app/gui/console/` en dehors des coutures autorisées.

### Phase 6 — Validation sur l'appareil (humain dans la boucle)
Préparer pour l'utilisateur une procédure courte à exécuter sur l'Orange Pi :
- lancer la veille ;
- mesurer le temps de rendu avec `QSG_RENDER_TIMING=1` ;
- comparer `entryBlur` activé et désactivé ;
- relever la charge GPU.

S'arrêter là et attendre le retour avant toute optimisation spéculative.

## Hors périmètre
- Mode nuit et paliers de veille plus profonds.
- Transition de réveil vers l'accueil au-delà du simple fondu.
- L'API HostCompanion elle-même.
- La récupération des vraies jaquettes Playnite. La jaquette de test et son libellé sont
  provisoires, et la luminosité d'une vraie jaquette (0,92) est à valider à l'œil.

## Livrable de fin
Court compte rendu dans `next_steps.md` : fichiers créés, coutures touchées, résultats de
`compare.py` par écran, écarts restants connus, procédure de test sur l'appareil.
