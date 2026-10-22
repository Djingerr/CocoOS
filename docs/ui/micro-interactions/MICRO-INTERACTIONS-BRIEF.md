# Micro-interactions CocoOS — brief pour Claude Code

> À poser dans `docs/ui/micro-interactions/`, à côté du prototype
> `micro-interactions-prototype.html` (banc d'essai interactif, à ouvrir dans un navigateur :
> flèches, Entrée = A, Échap = B). Lis aussi `CLAUDE.md` en entier : ses règles priment.

## 1. Objectif

Donner à l'interface console un ressenti « premium » par des micro-interactions : appuis qui
répondent, valeurs qui roulent, interrupteurs, sélecteurs élastiques, refus explicites,
notifications système. Le prototype montre le comportement attendu ; ce brief dit **où** chaque
interaction va dans le code existant et **ce qui ne doit pas changer**.

Règle d'interprétation : pour les durées, courbes et distances, **le prototype gagne**. Pour la
direction artistique, **« Ambiant » gagne** (`docs/ui/ambiant/`) : là où le prototype s'en écarte,
ce brief le signale et tranche.

## 2. Règles du projet à respecter (rappel de CLAUDE.md)

- Tout le code dans `app/gui/console/`. Aucun fichier upstream touché, `main.qml` encore moins.
- **Aucune valeur en dur dans les composants** : tous les nouveaux jetons vont dans `Theme.qml`,
  en pixels du canevas 1280 × 800.
- **Une seule police : Sora** (`Theme.fontUi`). Pas de police à chasse fixe. Les chiffres qui
  changent prennent `font.features: { "tnum": 1 }`. Le prototype a été réglé dans ce sens.
- Couleurs : uniquement les jetons existants (`accent`, `inkOnAccent`, `ink`, `ink2`, `ink3`,
  `inkOff`, remplissages des panneaux…). Ajouter un jeton si besoin, jamais un littéral.
- Sons : réutiliser `Sounds.play(...)` (`move`, `tick`, `edge`, `select`, `open`, `close`).
- Nouveaux textes en `qsTr` + traduction dans `languages/qml_en.ts` (cf. §11 de CLAUDE.md).
- Performance Mali-G610 : animer `scale`, `opacity`, `x`/`y`, `width`/`height` de petits éléments.
  **Pas de `MultiEffect` ni de flou** dans ces animations (le flou du prototype est décoratif,
  on le remplace par un simple fondu).
- **Montrer les diffs avant d'appliquer**, un commit par étape, en français.
- Le menu en jeu (`backend/streammenu`, dessiné en QPainter) est **hors périmètre** de ce brief.

## 3. Jetons à ajouter dans `Theme.qml`

Section « Micro-interactions » :

| Jeton | Valeur | Usage |
|---|---|---|
| `pressDuration` | 90 | écrasement à l'appui |
| `pressScale` | 0.955 | échelle à l'appui |
| `curveOut` | `[0.22, 1, 0.36, 1, 1, 1]` | fondus, remplissages (BezierSpline) |
| `curveInOut` | `[0.65, 0, 0.35, 1, 1, 1]` | reflet |
| ressort « vif » | k 380, c 28, m 1 (≈ 394 ms, dépasse de 4 %) | focus, chiffres |
| ressort « rebond » | k 300, c 18, m 1 (≈ 613 ms, dépasse de 15 %) | relâchement, interrupteurs |
| ressort « souple » | k 220, c 24, m 1 (≈ 460 ms, dépasse de 1 %) | île, formes |
| `holdDuration` | 900 | appui maintenu, progression affichée = p^1,4 |
| `holdDrain` | 280 | vidange si on lâche |

Les ressorts du prototype sont **physiques** (raideur k, amortissement c ; voir la fonction
`spring()` dans son script). `SpringAnimation` de Qt ne prend pas ces paramètres. Méthode
au choix, mais le résultat doit coller au prototype :
- soit un petit module `Spring.js` (port pur de `spring()`, comme `BootTimeline.js`) qui
  échantillonne la courbe et l'applique (par exemple via `FrameAnimation` ou une
  `NumberAnimation` sur un paramètre `t` de 0 à 1) ;
- soit des `SpringAnimation` réglées, **vérifiées** contre les valeurs du prototype.

Dans les deux cas, ajouter un test `tst_Spring` qui compare quelques points (dépassement max,
temps de stabilisation) aux valeurs du prototype, sur le modèle de `tst_BootTimeline`.
Ne pas toucher au ressort de l'étagère (`springStrength` / `springDamping`), déjà validé.

## 4. Les étapes

Ordre conseillé : du plus additif au plus structurant. Chaque étape = un commit, une vue ou un
cas dans le harnais (`docs/ui/ambiant/harness/`), une capture `shot.sh` montrée à Marco.

### Étape 1 — Appui (press feedback)

Prototype : carte « Appui et appui maintenu », bouton « Reprendre la partie ».

- Composant réutilisable (ex. `Pressable.qml` ou propriété `pressed` + `State`/`Transition`) :
  à l'appui de A, `scale` → `pressScale` en `pressDuration` (OutCubic) ; au relâché, retour à 1
  avec le ressort « rebond ». L'action part **au relâché**.
- Où : bouton Jouer de `HeroBlock`, lignes « action » d'`OptionsSheet`, boutons de
  `ConsoleDialog`, actions de `MessageScreen`.
- Ne change pas : sons et logique existants.

### Étape 2 — Reflet sur la vignette active

Prototype : carte « Carrousel », reflet qui balaie la jaquette après un arrêt.

- Sur la vignette active de `GameShelf` : un dégradé diagonal clair (≈ 16 % de blanc) balaie la
  vignette une fois, 950 ms en `curveInOut`, **520 ms après l'arrêt du ressort**. Annulé dès
  qu'on bouge. Pas de reflet en veille ni pendant un lancement.
- **Ne pas reprendre l'anneau de focus du prototype** : l'étagère garde son soulignement orange
  et sa vignette calée à gauche (direction Ambiant validée). Le lancement depuis la vignette
  existe déjà (620 ms easeQuint) : ne pas le refaire.

### Étape 3 — Interrupteurs dans les options

Prototype : carte « Interrupteurs ».

- Les lignes à deux valeurs booléennes d'`OptionsSheet` (HDR, Sons, et les futures) affichent un
  interrupteur à la place du texte « Activé / Désactivé » : marquer la ligne `toggle: true` dans
  le modèle construit par `ConsoleHome` (additif, les autres lignes ne changent pas).
- Comportement : A bascule ; → force « activé », ← force « désactivé » ; pousser vers l'état
  déjà actif = petite butée de 3 px aller-retour (260 ms) + son `edge`.
- Visuel : piste 48 × 28, contour fin ; pouce 22 px qui glisse avec le ressort « rebond » et
  s'étire à 28 px pendant l'appui (150 ms) ; l'orange se répand depuis le pouce (320 ms
  `curveOut`) ; pouce `ink2` éteint, `inkOnAccent` allumé.
- Lecteurs d'écran : garder le libellé de la valeur accessible.

### Étape 4 — Valeurs qui roulent et butée élastique

Prototype : carte « Curseur de débit » (compteur, crans, butée).

- Dans `OptionsSheet`, les valeurs **numériques** (débit, images/s, luminosité, volume) roulent
  chiffre par chiffre (colonne 0–9 par chiffre, ressort « vif », Sora `tnum`) au lieu de glisser
  en bloc. Les valeurs texte gardent `SwapBox`.
- Aux extrémités d'une liste de valeurs, en plus du son `edge` : la valeur avance de quelques px
  dans la direction poussée puis revient (ressort « rebond »), comme `edgeBump` sur l'étagère.
- **À confirmer avec Marco avant de coder** : transformer la ligne « Débit » en vrai curseur
  continu (5 à 150 Mb/s, pas qui accélère 1 → 2 → 5 avec `PadRepeat`, arrêt de 260 ms sur
  10 / 20 / 40 / 80, butée élastique de 16 px max). Ça change le modèle de la ligne (aujourd'hui
  Auto + 4 valeurs) et la place de « Auto » : proposer une solution avant d'écrire.

### Étape 5 — Soulignement élastique des onglets

Prototype : carte « Sélecteur de profil » (pilule qui s'étire).

- Les onglets d'`OptionsSheet` (Flux / Console, L1 / R1) ont aujourd'hui un soulignement par
  onglet en fondu. Le remplacer par **un seul** soulignement qui se déplace avec deux bords
  animés séparément : le bord avant part en premier (ressort « vif »), le bord arrière suit
  (420 ms `curveOut`, départ +40 ms), d'où l'étirement. Couleur du libellé : 220 ms, départ +90 ms.
- C'est l'interaction du prototype, mais dans le langage Ambiant (soulignement, pas pilule).
- Faire un composant réutilisable (`ElasticIndicator.qml` ou similaire) : il servira aux profils
  de flux Manuel / Auto du chantier §12.

### Étape 6 — Refus et coche

Prototype : carte « Sélection et refus ».

- Secousse de refus (440 ms : −9, 8, −5, 3, −1 px puis 0) : sur les cases du code quand la saisie
  du code Companion est fausse (`CompanionPairing`, cas `page=code-error` du harnais), et sur toute ligne ou
  action indisponible. Le message d'explication apparaît en dépliant (340 ms `curveOut`).
- Coche tracée (300 ms `curveOut`, départ +60 ms, couleur `accent`) : devant le réseau connecté
  dans la liste Wi-Fi, et partout où une liste montre la valeur choisie.

### Étape 7 — Appui maintenu pour les actions destructives

Prototype : carte « Appui et appui maintenu », bouton « Quitter le stream ».

- **À confirmer avec Marco avant de coder.** Proposition : dans `ConsoleDialog`, le bouton qui
  confirme une action destructive (quitter le jeu, redémarrer, éteindre, oublier ce PC,
  désinstaller) demande de maintenir A `holdDuration`. Remplissage orange de gauche à droite,
  le libellé passe en `inkOnAccent` sous le remplissage (deux couches de texte, celle du dessus
  découpée), vidange en `holdDrain` si on lâche, petit rebond à la fin, puis l'action.
  « Annuler » reste le choix par défaut.

### Étape 8 — Île de notification sur la pastille de l'hôte

Prototype : carte « Île de notification ».

- **À confirmer avec Marco avant de coder** (nouveau motif à côté de `Toast`). Proposition : la
  pastille de l'hôte de `StatusBar` s'ouvre en notification pour les événements système
  (manette connectée ou batterie faible via `InputStatus`, PC connecté ou perdu, réseau dégradé ;
  plus tard « débit ajusté » du profil Auto), puis se referme seule après 2,8 s. `Toast` reste
  pour les messages liés à l'étagère (favoris…).
- Forme : largeur et hauteur avec le ressort « souple », rayon 380 ms ; contenu en fondu
  +110 ms, 45 ms d'écart entre éléments, **sans flou** ; une nouvelle notification remplace la
  précédente sans refermer (sortie 120 ms, léger rebond d'échelle 1,025). B la referme.
- Attention à la relève du logo de démarrage vers la barre haute (`statusBarLogo`) : rien ne doit
  bouger dans la barre pendant ce vol.

## 5. Vérification

Pour chaque étape :
- harnais : une vue ou un `do=` qui déclenche l'interaction, capture `shot.sh` à 2 ou 3 instants ;
- tests QML ajoutés ou étendus (`tst_Spring`, et un test par comportement : bascule, butée,
  refus, maintien interrompu) ; toute la suite existante reste verte ;
- build `embedded` OK et démarrage sans erreur QML ;
- noter dans CLAUDE.md (§2 et liste des fichiers du §5) ce qui a été fait, et marquer ⚠️ ce qui
  n'a pas été vu à la manette ni mesuré à 60 i/s sur l'Orange Pi.
