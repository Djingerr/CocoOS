# CocoOS — Animation de démarrage (« le O »)

Spécification d'implémentation pour Claude Code. Dépôt `Djingerr/CocoOS`, branche `console-ui`.

**Source de vérité comportementale : `docs/boot-animation/prototype.html`.** Ouvre-le et lis son JavaScript : toutes les valeurs de ce document en viennent. En cas d'ambiguïté entre ce document et le prototype, reproduis le prototype. Le prototype est un rendu Canvas 2D ; il ne faut pas porter le Canvas mais reproduire le comportement en QML natif.

---

## 1. Contexte et contraintes

- Fork de moonlight-qt, Qt 6, QML, build qmake6. Cible : Orange Pi 5B (RK3588S, GPU Mali-G610 via Panfrost/Panthor, OpenGL ES), kiosk plein écran, dalle OLED.
- Fond noir pur `#000000` en permanence (OLED : pixels éteints).
- Accent unique : orange `#F2802A`. Texte : blanc `#FFFFFF`.
- Police du logotype : **Sora Bold (700)**. Logotype : « Coco » en blanc, « OS » en orange.
- Aucune dépendance nouvelle sans validation (en particulier QtMultimedia, voir §9).
- Avant d'écrire du code, explore le dépôt : structure de `app/gui/`, fichiers `.qrc` existants, `main.qml`, `ConsoleHome`, `StatusBar`. Adapte les chemins proposés ici aux conventions réelles du dépôt.

## 2. Police Sora

1. Fichiers attendus dans le dépôt : `app/fonts/Sora-Bold.ttf` et `app/fonts/OFL.txt` (licence SIL Open Font License, obligatoire à redistribuer avec la police). Si le dossier `fonts` existe déjà ailleurs, utilise-le.
2. Utiliser une instance **statique** Bold, pas la police variable (le support des axes variables dépend de la version de Qt).
3. Déclarer la police dans le `.qrc` existant et la charger avec `FontLoader { source: "qrc:/fonts/Sora-Bold.ttf" }`. Toutes les occurrences du logotype utilisent `font.family: soraLoader.font.family` et `font.weight: Font.Bold`.
4. **Ne démarre pas l'animation tant que `FontLoader.status !== FontLoader.Ready`**, sinon les métriques (positions des lettres, rayons du O) seront calculées sur une police de repli.
5. Le logo de la `StatusBar` doit lui aussi utiliser Sora Bold, sinon le passage de relais en fin d'animation sautera (§7).

## 3. Architecture

```
app/gui/boot/
  BootSplash.qml        composant racine, piloté par un temps t (ms)
  BootTimeline.js       fonctions pures : easings, ressorts, état à l'instant t (port direct du prototype)
  ConicMask.frag        masque angulaire du O (tracé + chargeur)
  EllipseMask.frag      masque elliptique pour les lettres qui sortent de derrière le O
  *.frag.qsb            shaders compilés (voir §8)
docs/boot-animation/
  BOOT_ANIMATION.md     ce document
  prototype.html        référence
```

**Pilotage par le temps.** Le prototype est entièrement une fonction de `t` (ms depuis le début). Reproduis ce modèle : une propriété `t` avancée par un `FrameAnimation` (Qt ≥ 6.4 ; sinon `NumberAnimation` en boucle sur un compteur), et toutes les propriétés visuelles calculées à partir de `t` via `BootTimeline.js`. C'est le moyen le plus fiable de reproduire le prototype à l'identique, et cela rend la vitesse (`×0,25` pour le debug) et le saut (§6) triviaux.

**Conséquence : le thread GUI doit rester libre pendant le boot.** Tout chargement lourd (bibliothèque, découverte réseau, `ConsoleHome`) doit être asynchrone : `Loader { asynchronous: true }`, travail réseau déjà asynchrone dans moonlight, aucune I/O bloquante sur le thread GUI pendant la séquence. Si des saccades sont mesurées sur la cible malgré cela, basculer les propriétés de transform (`x`, `scale`, `opacity`) sur des `Animator` (thread de rendu) avec des `Easing.BezierSpline` multi-segments qui approximent les ressorts.

**Repère.** Toutes les valeurs spatiales du prototype sont en pixels d'une référence 1280×720. Facteur d'échelle : `k = height / 720`. Le logo est centré sur `(width/2, height/2)`.

### API de `BootSplash.qml`

```qml
property string mode: "cold"         // "cold" (démarrage à froid) | "wake" (sortie de veille)
property bool systemReady: false     // lié à l'état réel de l'app (§5)
property string stepText: ""         // étape en cours, affichée seulement si showStepText
property bool showStepText: false
property Item statusBarLogo          // le logo de la StatusBar, cible de la sortie (§7)
signal exitStarted()                 // émis à E + 250 ms : ConsoleHome lance son entrée
signal finished()                    // fin de la sortie : masquer le splash, afficher le vrai logo
signal soundCue(string name)         // "close" | "open" (§9)
function skip()                      // bouton A pendant l'animation (§6)
```

## 4. Timeline du démarrage à froid

### Constantes (ms, réf. 1280×720)

| Nom | Valeur | Rôle |
|---|---|---|
| `drawStart` | 250 | noir pur avant (première frame stable) |
| `drawDur` | 750 | révélation conique du O |
| `pause` | 150 | O seul, complet |
| `anticip` | 80 | élan : compression de 2 % |
| `oResp`, `oZeta` | 620, 0.90 | ressort du O |
| `lResp`, `lZeta` | 520, 0.78 | ressort des lettres |
| `firstDelay`, `stagger`, `sDelay` | 20, 45, 40 | départs des lettres |
| `settle` | 600 | stabilisation |
| `holdLogo` | 400 | logo au repos avant sortie |
| `loaderDelay` | 400 | attente avant d'afficher le chargeur |
| `loaderMin` | 600 | durée minimale d'affichage du chargeur |
| `closeDur`, `breath` | 520, 380 | fermeture du O, pulsation de confirmation |
| `spinCycle`, `spinRot` | 1333, 1568 | chargeur façon Material |
| `exitDur` | 750 | vol vers la StatusBar |

Instants dérivés : `drawEnd = 1000`, `anticStart = 1150`, `release = 1230`, `revealEnd = 1985`, `normalE = 2385` (début de sortie si le système est déjà prêt), `loaderShowAt = 2785`.

Logotype : taille `104·k` px. Couleurs : `ORANGE = #F2802A`, `BRIGHT = #FFB076`.

### Easings

| Nom | Bézier | Équivalent QML |
|---|---|---|
| `E_OUT` | (0.33, 1, 0.68, 1) | `Easing.OutCubic` |
| `E_INOUT` | (0.65, 0, 0.35, 1) | `Easing.InOutCubic` |
| `E_EMPH` | (0.2, 0, 0, 1) | `Easing.BezierSpline` `[0.2,0, 0,1, 1,1]` |
| `E_DRAW` | (0.7, 0, 0.2, 1) | `Easing.BezierSpline` `[0.7,0, 0.2,1, 1,1]` |
| `E_STD` | (0.4, 0, 0.2, 1) | `Easing.BezierSpline` `[0.4,0, 0.2,1, 1,1]` |

`BootTimeline.js` doit contenir un évaluateur de Bézier cubique (bissection, comme `cubicBezier()` du prototype) pour calculer ces courbes à un `t` arbitraire.

### Ressort amorti

Départ au repos, vitesse initiale nulle, paramétré comme SwiftUI (réponse en ms, amortissement ζ) :

```js
function spring(t, resp, zeta) {
  if (t <= 0) return 0;
  const w = 2 * Math.PI / resp, wd = w * Math.sqrt(1 - zeta * zeta);
  return 1 - Math.exp(-zeta * w * t) * (Math.cos(wd * t) + (zeta * w / wd) * Math.sin(wd * t));
}
```

### Géométrie (à calculer une fois la police chargée)

Avec `TextMetrics`/`FontMetrics` sur Sora Bold `104·k` :

- `wC = advance("Coco")`, `wOS = advance("OS")`, `w = wC + wOS`, `x0 = width/2 − w/2`.
- Ligne de base : `base = height/2 + (ascent − descent)/2` où ascent/descent sont ceux du rectangle serré de « CocoOS ».
- Origine de chaque lettre de « Coco » (avec crénage) : `x0 + advance(prefix jusqu'à i inclus) − advance(lettre i)`.
- O : origine `xO = x0 + wC`. S : `xS = x0 + wC + (advance("OS") − advance("S"))`.
- Centre du O : depuis `tightBoundingRect("O")` ; rayons extérieurs `rxo`, `ryo` = demi-largeur et demi-hauteur de ce rectangle.

Utilise **un `Text` par lettre** (C, o, c, o, O, S) positionné par son origine, y compris au repos : ainsi aucune position ne change au passage du déploiement au repos.

### Phases

**0 → 250 : noir.**

**250 → 1000 : tracé du O.** Le vrai glyphe O (pas un trait) est révélé par un masque conique (§8, `ConicMask`), centré sur le O, à l'échelle `oScale = 1.25`, positionné au **centre de l'écran**.
- `p = (t − 250)/750`, fraction révélée `len = E_DRAW(p)`.
- Angle de départ `a0 = −π/2 − 0.6·(1 − E_OUT(p))` (repère écran, sens horaire, 0 = droite).
- Bord d'attaque adouci sur `0.035` tour, départ net.
- Couleur du O : `BRIGHT`, puis mélange vers `ORANGE` de 1000 à 1400 ms (`E_OUT`).

**1000 → 1150 : pause.** O seul, complet.

**1150 → 1230 : élan.** Échelle du O `oScale · (1 − 0.02·E_INOUT((t−1150)/80))`.

**À partir de 1230 : déploiement.**
- O : `sp = spring(t − 1230, 620, 0.9)` ; échelle `lerp(oScale·0.98, 1, sp)` ; x du centre `lerp(width/2, centreFinalDuO, sp)`.
- Lettres, avec `delay` : C = 20, o = 65, c = 110, o = 155, S = 40 (le C part en premier car il va le plus loin ; elles ne se croisent jamais).
  - `sp = spring(t − (1230 + delay), 520, 0.78)` (léger dépassement voulu).
  - Départ : centrées derrière le **centre courant** du O, soit `xCentreO(t) − advance(lettre)/2`. Arrivée : leur origine finale. `x = lerp(départ, arrivée, sp)`.
  - Luminance : `lerp(0.55, 1, clamp(sp, 0, 1))` appliquée à la couleur (blanc pour Coco, orange pour S).
  - Masque : les lettres sont invisibles à l'intérieur de l'ellipse centrée sur le O courant, rayons `(rxo, ryo)·échelleO·0.97` (§8, `EllipseMask`). Le O est dessiné par-dessus les lettres.
- **Flou de mouvement : désactivé par défaut**, à n'activer qu'après validation sur la dalle. S'il est activé : deux copies fantômes de chaque lettre en mouvement, à `x − dx·0.5` (opacité `k`) et `x − dx·1.0` (opacité `k/2`), où `dx` est le déplacement sur 16 ms et `k = min(0.12, (|dx| − 1.5)·0.012)` si `|dx| > 1.5`, sinon 0.

**1985 : repos.** Positions finales arrondies au pixel physique. Désactiver les `layer`/shaders devenus inutiles.

**`E` : sortie** (`E = normalE` si le système est prêt, sinon voir §5). Sur `exitDur = 750` ms avec `e = E_EMPH(progress)` :
- Trajectoire courbe (Bézier quadratique) du centre du logo de `P0` (centre écran) vers `P2` (centre du logo de la StatusBar), point de contrôle `C = (lerp(P0.x, P2.x, 0.25), lerp(P0.y, P2.y, 0.8))`.
- Échelle de 1 vers `hauteurLogoStatusBar / hauteurLogoSplash`.
- `exitStarted()` à `E + 250`. `finished()` à `E + 750` : masquer le splash et rendre visible le logo réel de la StatusBar dans la même frame.

## 5. Boot lent : le O de OS devient le chargeur

`systemReady` est lié à l'état réel : `ConsoleHome` chargé **et** liste des jeux/hôte disponible (identifie les signaux existants dans le code de moonlight et de la console UI). `stepText` reflète l'étape réelle (démarrage des services, recherche de l'hôte, connexion à l'hôte, chargement de la bibliothèque).

Soit `r` l'instant (en `t`) où `systemReady` passe à vrai.

- Si `r ≤ loaderShowAt` : pas de chargeur ; la sortie commence à `E = max(normalE, r)`.
- Sinon le chargeur apparaît à `loaderShowAt`, et :
  - `ca = max(r, loaderShowAt + loaderMin)` (anti-clignotement : visible au moins 600 ms) ;
  - fermeture de `ca` à `ca + closeDur`, pulsation jusqu'à `ca + closeDur + breath` ;
  - `E = ca + closeDur + breath`.

### Rendu du chargeur (port direct de `spinner()` et `loaderState()` du prototype)

```js
function spinner(tau) {                 // résultat en tours
  const D = 1333, tt = tau + D / 2;
  const c = Math.floor(tt / D), u = (tt - c * D) / D;
  const head = E_STD(clamp01(u / 0.5)) * 0.75;
  const tail = E_STD(clamp01((u - 0.5) / 0.5)) * 0.75;
  const base = c * 0.75 + tau / 1568;
  return { tail: base + tail, head: base + head + 0.03 };
}
// tau = t - loaderShowAt ; ca = Infinity tant que non prêt
const sp = spinner(tau);
let tail = lerp(sp.head - 1, sp.tail, E_OUT(clamp01(tau / 450)));   // part du O complet
let head = sp.head;
if (isFinite(ca)) head = lerp(head, tail + 1, E_EMPH(clamp01((t - ca) / 520)));  // se referme
const len = Math.min(1, head - tail);
const startAngle = -Math.PI / 2 + 2 * Math.PI * (tail - 0.78);
const vis = E_OUT(clamp01(tau / 400)) * (isFinite(ca) ? 1 - E_OUT(clamp01((t - ca) / 520)) : 1);
const bb = isFinite(ca) ? clamp01((t - ca - 520) / 380) : 0;
const bump = (bb > 0 && bb < 1) ? Math.sin(Math.PI * E_OUT(bb)) : 0;
```

- **Piste** : un second `Text` « O » orange à opacité `0.18`, sous l'arc, tant que `len < 1`.
- **Arc** : le glyphe O passé dans `ConicMask` avec `startAngle`, `len`, adoucissement aux deux bouts `min(0.025, len/3)`.
- « Coco » et « S » : luminance `lerp(1, 0.82, vis)`.
- Pulsation de confirmation : échelle du O `1 + 0.045·bump`, couleur `mix(ORANGE, BRIGHT, 0.8·bump)`.
- Étape en texte (si `showStepText`) : apparaît à `loaderShowAt + 1500`, centrée à `bottomLogo + 62·k`, JetBrains Mono (ou la mono du design system) `13·k` px, `#6E6E6E`, fondu de 300 ms et légère montée de 4 px à chaque changement, opacité multipliée par `vis`.

## 6. Interruption (bouton A)

`skip()` : multiplie la vitesse de `t` par 4 jusqu'à la fin de la sortie, puis revient à 1. Ne court-circuite **pas** l'attente du système : si le chargeur est actif, seule la partie animée est accélérée.

## 7. Variante sortie de veille (`mode: "wake"`)

Durée ≈ 1 s. Le logo est déjà à sa place dans la StatusBar.
- 0 → 80 ms : noir.
- `u = t − 80` : logo de la StatusBar en fondu `E_OUT(u/250)`, luminance `0.55 → 1`.
- Respiration du O : échelle `1 + 0.14·sin(π·E_INOUT((u − 150)/500))`.
- L'entrée de `ConsoleHome` démarre à `u = 0`.

Entrée de `ConsoleHome` (commune aux deux variantes) : texte de la StatusBar en fondu 350 ms (`E_OUT`) ; cartes du carrousel en fondu + échelle `0.97 → 1`, `E_EMPH` sur 500 ms, décalage de 45 ms par carte ; légende manette en fondu à partir de 300 ms.

## 8. Shaders (Qt 6 `ShaderEffect`)

Le glyphe passe dans le shader via `layer.enabled: true` + `layer.effect`. **Pour éviter le flou à l'agrandissement**, rendre le `Text` du O à sa taille maximale (`104·k·1.25`) et le réduire avec `scale`, jamais l'inverse.

### `ConicMask.frag`

```glsl
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 center;        // centre du O, coordonnées normalisées de la source
    vec2 itemSize;      // taille de l'item en px (angle non déformé)
    float startAngle;   // radians, 0 = droite, sens horaire (y vers le bas)
    float len;          // fraction de tour révélée [0..1]
    float featherHead;  // fraction de tour
    float featherTail;  // 0 = départ net (tracé), > 0 pour le chargeur
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec2 d = (qt_TexCoord0 - center) * itemSize;
    float u = fract((atan(d.y, d.x) - startAngle) / 6.28318530718);
    float m = 1.0;
    if (len < 0.999) {
        float head = 1.0 - smoothstep(len - featherHead, len, u);
        float tail = featherTail > 0.0 ? smoothstep(0.0, featherTail, u) : 1.0;
        m = head * tail;
    }
    fragColor = c * m * qt_Opacity;
}
```

Centre du O dans l'item : `(tight.x + tight.width/2, baselineOffset + tight.y + tight.height/2)` avec `tight = TextMetrics.tightBoundingRect`, puis normaliser par la taille de l'item.

### `EllipseMask.frag`

```glsl
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;       // px
    vec2 ellipseCenter;  // px, repère de l'item
    vec2 ellipseRadii;   // px
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec2 q = (qt_TexCoord0 * itemSize - ellipseCenter) / ellipseRadii;
    float aa = 1.0 / min(ellipseRadii.x, ellipseRadii.y);
    float m = smoothstep(1.0 - aa, 1.0, length(q));
    fragColor = c * m * qt_Opacity;
}
```

Appliquer `EllipseMask` à un conteneur des lettres (sans le O) uniquement entre `release` et `revealEnd`, puis désactiver le `layer`.

### Compilation

Le build est en qmake : compiler les shaders avec `qsb` et ajouter les `.qsb` au `.qrc`. Ajouter un script `tools/build-shaders.sh` qui régénère les `.qsb` :

```sh
qsb --glsl "100 es,120,150,300 es" -o ConicMask.frag.qsb ConicMask.frag
qsb --glsl "100 es,120,150,300 es" -o EllipseMask.frag.qsb EllipseMask.frag
```

Les versions GLSL ES sont nécessaires pour la cible Mali. Le vertex shader par défaut de `ShaderEffect` suffit.

## 9. Son

Ne pas ajouter QtMultimedia si ce n'est pas déjà une dépendance. Émettre `soundCue(name)` aux instants suivants ; le branchement audio (SDL ou autre) se fera plus tard :
- `"close"` à `drawEnd` (1000 ms) ;
- `"open"` à `release` (1230 ms) ;
- `"close"` à `ca + 0.8·closeDur` si le chargeur a été affiché ;
- `"open"` à `u = 150` ms en variante veille.

## 10. Outils de debug (variables d'environnement)

- `COCOOS_BOOT_SPEED` : multiplicateur de vitesse (ex. `0.25`).
- `COCOOS_BOOT_FAKE_DELAY_MS` : retarde artificiellement `systemReady` (ex. `4000`) pour tester le chargeur.
- `COCOOS_BOOT_MODE` : `cold` ou `wake`.
- `COCOOS_BOOT_LOOP=1` : rejoue la séquence en boucle (sans entrer dans l'UI).

## 11. Critères d'acceptation

1. À `COCOOS_BOOT_SPEED=0.25`, chaque phase correspond visuellement au prototype en Sora (comparer côte à côte).
2. Points de contrôle (boot rapide) : 500 ms O tracé à environ 15 % ; 600 ms environ à moitié ; 1000 ms O complet, plus clair ; 1200 ms O légèrement comprimé ; 1400 ms « C » et « o » sortis ; 1985 ms logo au repos, net ; 2385 ms début de la sortie ; 3135 ms logo dans la StatusBar.
3. Avec `COCOOS_BOOT_FAKE_DELAY_MS=300` : aucun chargeur n'apparaît. Avec `4000` : le chargeur tourne, se referme, pulse, puis sortie.
4. Le chargeur, une fois visible, reste au moins 600 ms.
5. Aucune lettre visible à l'intérieur ou au bord du O pendant le déploiement.
6. Aucun saut au passage de relais avec le logo de la StatusBar (≤ 1 px).
7. 60 i/s tenus sur l'Orange Pi 5B : vérifier avec `QSG_RENDER_TIMING=1`, aucune frame au-delà de 16,6 ms pendant la séquence.
8. Bouton A : accélération fluide, jamais de coupure.

## 12. Ordre de travail suggéré

1. Police Sora + `FontLoader` + logo StatusBar en Sora.
2. `BootTimeline.js` (fonctions pures, testables) et un `BootSplash.qml` minimal piloté par `t`, sans shaders, pour valider positions et ressorts.
3. Shaders `ConicMask` et `EllipseMask`, script `qsb`.
4. Chargeur et logique `systemReady`.
5. Sortie vers la StatusBar, entrée de `ConsoleHome`, variante veille.
6. Variables de debug, puis validation sur la cible.

Fais un commit par étape.
