# Écran de veille CocoOS — spécification (version Premium, écrans 09 à 12)

Toutes les valeurs sont en px de la grille de référence **1280 × 720**. Les positions exactes de
chaque élément (rectangle, taille de police, graisse, interlettrage, couleur) sont dans
`reference/layout/<écran>.json`, mesurées sur la maquette à t = 3 s. **En cas de doute, ces
fichiers et les PNG de `reference/png/` font foi**, pas ce texte.

Tokens (couleurs, typo, courbes, durées) : `tokens.json`.

---

## 1. Les quatre états et la règle de sélection

| État | Écran | Condition |
|---|---|---|
| `Game` | 09 | session de jeu active, pas de téléchargement |
| `GameDownload` | 10 | session de jeu active **et** téléchargement en cours |
| `Download` | 11 | pas de session, téléchargement en cours |
| `Rest` | 12 | ni session ni téléchargement |

Quand l'état change pendant la veille : fondu enchaîné 600 ms (`appleOut`), puis l'animation
d'entrée du nouvel état est rejouée.

## 2. Structure commune des écrans 09, 10, 11 (de l'arrière vers l'avant)

1. **Fond noir** `#000`.
2. **Backdrop flou** : la jaquette du jeu étirée en *cover* sur un rectangle (−100, −100, 1480, 920),
   flou CSS 100 px, saturation × 1,1. Animation `backdropPan` (60 s, aller-retour, ease-in-out) :
   échelle 1,25 → 1,34 et translation (0, 0) → (−30, +16), origine au centre.
3. **Vignettage** : dégradé radial elliptique centré en (358, 324) (28 % / 45 %),
   rayons rx = 1304, ry = 560. Couleur `rgba(0,0,0,0.30)` au centre → `rgba(0,0,0,0.82)` à
   72 % du rayon, constante au-delà.
4. **Grain** : `assets/grain_256.png` en mosaïque, mode de fusion *overlay*, opacité 0,07.
   Sur noir pur, l'overlay ne produit rien : le grain n'apparaît que sur les zones colorées. Ne
   **jamais** le passer en fusion normale avec un gris moyen, cela lèverait les noirs de l'OLED.
5. **Groupe de contenu** avec la dérive anti-marquage `drift` (90 s, aller-retour) : (0,0) → (6,−4)
   → (−5,5) → (4,6) aux temps 0 / 33 % / 66 % / 100 %. Tout ce qui suit est dans ce groupe.

### 2.1 Coin haut droit (heure + batterie)
- Bord droit à x = 1224 (droite 56), haut y = 36. De gauche à droite : l'heure (15 px, 600,
  `textPrimary`, chiffres tabulaires), 12 px, puis l'icône batterie.
- Batterie : `assets/icons/battery_frame.svg` affichée en 25 × 12, remplissage intérieur
  dessiné en QML (rectangle arrondi 2 px, `#F5F5F7`, largeur ∝ pourcentage, 16,4 px à 82 % à
  l'échelle 27 px du SVG).

### 2.2 Jaquette (format A4, 326 × 460, ratio 1:1,41)
- Position (112, 104). Rayon 12. Liseré intérieur 1 px `rgba(255,255,255,0.07)`.
- Ombre : `0 40px 90px rgba(0,0,0,0.6)`. Version pré-rendue fournie :
  `assets/cover_shadow_626x760.png`, à placer en (carte.x − 150, carte.y − 150), dans le groupe
  incliné pour suivre l'inclinaison.
- Image : jaquette en `PreserveAspectCrop`. Luminosité 0,62 pour la jaquette de test (elle porte un
  libellé), **0,92 pour une vraie jaquette** — à valider à l'œil sur l'appareil.
- Lumière : dégradé linéaire à 135° `rgba(255,255,255,0.10)` → transparent à 42 %.
- Reflet glissant (`coverSheen`, 11 s, en boucle) : bande de 30 % de la largeur de la carte, 140 % de
  sa hauteur, inclinée de −18° (skewX), dégradé horizontal transparent → blanc 13 % → transparent.
  Position X (en multiples de la largeur de bande) : −1,6 tenu jusqu'à 55 % du cycle, glisse jusqu'à
  +4,2 entre 55 % et 85 %, tenu jusqu'à 100 %. Rogné par les coins arrondis de la carte.
- Libellé de test « Jaquette Minecraft · 600 × 848 » centré en bas (bas 18 px, 11 px, 500,
  interlettrage 0,44 px, `textTertiary`). **Uniquement** avec la jaquette de test.
- Reflet au sol : copie retournée verticalement de l'image (sans libellé ni lumière), placée
  6 px sous la carte (y = 570), même taille et même rayon. Masque alpha : 22 % au bord collé à la
  carte → 0 à 28 % de sa hauteur (≈ 129 px visibles).
- Inclinaison 3D (`coverTilt`, 18 s, aller-retour) appliquée au groupe carte + ombre + reflet :
  `perspective(1400px) rotateY(9° → 3°) rotateX(1° → −1°)`, origine au centre de la carte.
  Attention : `Rotation` de Qt Quick projette avec une distance fixe de 1024 px. Pour coller à la
  maquette, calculer une `Matrix4x4` : T(centre) · P(1400) · Ry · Rx · T(−centre), avec
  P = perspective simple (w = 1 − z/1400).

### 2.3 Colonne de texte (x = 520, largeur 660)
Hauteur de départ : y = 170 en 09 et 11, **y = 150 en 10** (pour laisser la ligne de téléchargement).

| Élément | Style | Détail |
|---|---|---|
| Surtitre | `eyebrow` 12/600, +0,96 px, `textSecondary`, MAJUSCULES | 09/10 : pastille 6 px `accent` (pulse d'opacité 0,35↔1, 2,4 s) + 10 px + « EN COURS SUR PC-SALON ». 11 : flèche de téléchargement 12 px `accent` (rebond −1↔+2 px, 1,8 s) + « TÉLÉCHARGEMENT SUR PC-SALON ». |
| Titre | `title` 68/600, −3,06 px, interligne 1,05 | 14 px sous le surtitre. « Minecraft ». |
| Méta | `meta` 17/500, `textSecondary` | 8 px sous le titre. « Mojang Studios · Bac à sable » (éditeur · genre). |
| Grand bloc | voir ci-dessous | 56 px sous la méta (52 px en 10). |
| Ligne d'état | `status` 15/500, `textStatus` | 48 px sous le grand bloc (44 px en 10 et 11). Trois items espacés de 28 px, chacun icône + 8 px + texte. |

**Grand bloc, écrans 09 et 10 — durée de session** : chiffres `bigNumber` 72/600 (−3,24 px),
unités `unit` 28/500 `textUnit`, alignés sur la ligne de base, 6 px entre chiffre et unité,
14 px de marge après « h ». « 1 h 24 min ». Sous la ligne (8 px) : « de jeu depuis la connexion »
15/500 `textSecondary`. Sous 1 h : afficher seulement « 24 min ». Les minutes ont deux chiffres
dès qu'il y a des heures.

**Grand bloc, écran 11 — progression** : « 42 » en `bigNumber` + « % » en `unit`. 8 px dessous :
« Mise à jour · 1,2 Go/s · environ 6 min » 15/500 `textSecondary`. 14 px dessous : barre de
420 × 2, rayon 1, piste `track`, remplissage `accent` (largeur interpolée en 1 s linéaire à chaque
mise à jour). Reflet sur le remplissage : bande de 30 % de la largeur remplie, blanc à 70 % au
centre, de −100 % à +350 % en 2,4 s en boucle.

**Ligne d'état** :
- 09/10 : `monitor` « PC-Salon » · `signal` « 4 ms » · `wifi` « Excellent ».
- 11 : `monitor` « PC-Salon · En ligne » · `signal` « 4 ms » · `wifi` « Excellent ».
- Icônes en `currentColor` = `textStatus` (17 × 15, 15 × 13, 17 × 12).

**Ligne de téléchargement (écran 10 uniquement)** : 36 px sous la ligne d'état. Anneau 20 × 20
(r = 7, trait 2, piste `ringTrack`, arc `accent` à bouts ronds, départ à midi, sens horaire,
interpolation 1 s linéaire) + 12 px + « Mise à jour de [Autre jeu] » 14/500 `textStatus` + 12 px +
« 68 % · 4 min » 14/500 `textTertiary`.

### 2.4 Indication du bas
Centrée, bas 44 px (texte à y ≈ 656). « Appuyez sur » + pastille « A » + « pour reprendre »
(09, 10) ou « pour ouvrir l'accueil » (11). Texte 14/500 `textHint`, espacement 8 px.
Pastille : cercle 22 px, contour 1 px `keyHintStroke`, « A » 11/600 `textPrimary`.

## 3. Écran 12 — Repos

1. Fond `#000`.
2. **Lueur** : ellipse 1100 × 520 centrée horizontalement (x 90 → 1190), haut y = 470 (déborde
   en bas). Dégradé radial `accent` → transparent à 65 %, flou CSS 120 px, opacité 0,22 ×
   facteur animé (`restGlow` : 0,7 ↔ 1 et échelle 1 ↔ 1,08, 14 s, en boucle).
3. **Grain** identique (overlay 0,07) : visible seulement sur la lueur.
4. Groupe de contenu avec `drift`.
5. **Date** « Mardi 27 octobre » (première lettre en majuscule) 20/600 `rgba(245,245,247,0.6)`,
   centrée, haut y = 120.
6. **Heure** « 21:46 » 176/600, interlettrage −9,68 px, interligne 1, chiffres tabulaires,
   centrée, 2 px sous la date. Remplissage en **dégradé vertical** `#FFFFFF` → `#A9A9AE` (texte
   utilisé comme masque d'un rectangle dégradé).
7. **Capsule de verre** centrée, haut y = 452, hauteur 76, rayon 38, remplissage `glassFill`,
   contour 1 px `glassStroke`, marge horizontale intérieure 8 px. Flou d'arrière-plan 40 px +
   saturation 1,6 sur la maquette : sur appareil, une approximation par simple remplissage est
   acceptable si l'écart reste invisible à la comparaison (la lueur derrière est déjà floue).
   Quatre segments séparés par des filets verticaux 1 × 30 `hairline`, chaque segment = marge
   horizontale 22 px, icône + 12 px + deux lignes (titre 15/600 `textPrimary`, sous-titre 12/500
   `textSecondary`, 1 px d'écart) :
   - `monitor` 20 × 18 à 70 % · « PC-Salon » / « En ligne »
   - `wifi` 20 × 15 à 70 % · « 4 ms » / « Wi-Fi excellent »
   - anneau batterie 26 × 26 (r = 11, trait 3, piste `ringTrackRest`, arc `accent`, se dessine de
     0 à 82 % en 1,6 s `appleOut` après 600 ms) · « 82 % » / « Environ 3 h »
   - vignette de jaquette 32 × 45, rayon 5, luminosité 0,75, liseré 1 px `rgba(255,255,255,0.1)`,
     marge gauche du segment 18 px · « Minecraft » / « Il y a 2 h »
8. **Indication** : « Appuyez sur (A) pour ouvrir l'accueil », même style qu'en 2.4.

## 4. Animation d'entrée (le moment signature)

À l'apparition de la veille (et à chaque changement d'état), chaque élément part de
`opacité 0, translation Y +18 px, flou 8 px` et arrive à `1, 0, 0` en 1000 ms `appleOut`
(`cubic-bezier(0.32, 0.72, 0, 1)` → `Easing.Bezier`, `bezierCurve: [0.32, 0.72, 0, 1, 1, 1]`),
avec ces délais :

| Élément | Délai | Durée |
|---|---|---|
| Jaquette (groupe entier) | 0 | 1200 |
| Surtitre | 150 | 1000 |
| Titre | 220 | 1000 |
| Méta | 290 | 1000 |
| Grand bloc | 400 | 1000 |
| Ligne d'état | 500 | 1000 |
| Heure + batterie (haut droit) | 600 | 1000 |
| Ligne de téléchargement (10) | 650 | 1000 |
| Indication du bas | 1000 | 1000 |
| *12 :* date | 100 | 1000 |
| *12 :* heure | 200 | 1200 |
| *12 :* capsule | 450 | 1100 |

`reference/png/*_entree.png` montre l'image à t = 0,45 s pour comparer le rythme.
Le flou d'entrée est le poste le plus coûteux : le rendre désactivable
(`IdleTheme.entryBlur`), opacité + translation seules gardant 90 % de l'effet.

**Sortie** (toute pression de touche ou de manette) : opacité → 0 et échelle → 1,02 en 320 ms
`appleOut`, puis signal `wakeRequested()`.

## 5. Formats de texte (français)

| Donnée | Format |
|---|---|
| Heure | `HH:mm` (24 h), chiffres tabulaires |
| Date (12) | jour de la semaine, jour, mois en toutes lettres, première lettre en majuscule : « Mardi 27 octobre » |
| Durée de session | « 1 h 24 min », « 24 min » sous 1 h |
| Débit | virgule décimale, 1 décimale : « 1,2 Go/s », « 850 Mo/s » |
| Temps restant (téléchargement) | « environ 6 min », « moins d'une minute », « environ 1 h 05 » |
| Pourcentage | entier + espace insécable + « % » : « 82 % » |
| Latence | entier + « ms » ; rafraîchie toutes les 2 s |
| Autonomie | « Environ 3 h », « Environ 45 min » ; en charge : « En charge » |
| Dernière session | « Il y a 12 min », « Il y a 2 h », « Hier », « Il y a 3 jours » |
| Qualité Wi-Fi | RSSI ≥ −55 dBm « Excellent », ≥ −67 « Bon », ≥ −75 « Moyen », sinon « Faible » ; en 12 : « Wi-Fi excellent » (minuscule) |
| État de l'hôte | « En jeu », « En ligne », « En veille », « Hors ligne » |

## 6. Correspondances CSS → QML recommandées

| Maquette (CSS) | QML |
|---|---|
| `filter: blur(Npx)` sur grande surface (backdrop, lueur) | Rendre la source dans un `ShaderEffectSource` à basse résolution (`textureSize` ≈ 1/8), puis `MultiEffect { blurEnabled: true }`. Flouter **une fois** dans une couche, et n'animer que la transformation de cette couche. |
| Vignettage + grain overlay + saturation | Un seul `ShaderEffect` de composition du backdrop (un passage) ; `.qsb` à précompiler avec `qsb`. |
| `box-shadow` de la jaquette | `BorderImage`/`Image` de `assets/cover_shadow_626x760.png`. |
| Coins arrondis qui rognent (carte, reflet glissant) | `layer.enabled` + `MultiEffect { maskEnabled: true; maskSource: <Rectangle arrondi en couche> }`. |
| Masque dégradé du reflet au sol | `MultiEffect` masque avec un `Rectangle` dégradé alpha, ou alpha calculé dans un petit shader. |
| Texte en dégradé (heure de 12) | Rectangle dégradé masqué par le `Text` mis en couche (`MultiEffect` mask). |
| `perspective rotateY rotateX` | `Matrix4x4` calculée (voir 2.2). |
| `font-variant-numeric: tabular-nums` | `font.features: { "tnum": 1 }` (Qt ≥ 6.6, Sora a `tnum`). Sinon, boîtes de largeur fixe par chiffre. |
| `letter-spacing` en em | `font.letterSpacing` en px (déjà converti dans `tokens.json`). |
| Anneaux de progression | `Shape` + `PathAngleArc` (`capStyle: ShapePath.RoundCap`), ou `Canvas` si `QtQuick.Shapes` indisponible. |
| Icônes SVG | `Image { source: "...svg"; sourceSize: ... }` + `MultiEffect` colorisation si une autre couleur que blanc est nécessaire. |
| `cubic-bezier(a,b,c,d)` | `easing.type: Easing.Bezier; easing.bezierCurve: [a, b, c, d, 1, 1]` |
| Mise à l'échelle | Un `Item` racine de 1280 × 720 avec `scale: Math.min(w/1280, h/720)`, centré, bandes noires si le ratio diffère. |
