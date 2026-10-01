# CocoOS : écran d'accueil « Ambiant » (brief d'implémentation)

Source de vérité visuelle et de mouvement : `ambiant-prototype.html` (version n° 2 « Ambiant », touche `2`).
Ce document en extrait les valeurs exactes. En cas de doute entre ce texte et le prototype, le prototype gagne : ouvre-le, lis le code de l'objet `VB` (et `Launch`, `Sheet`, `Spring`, `swap`, `Layers`), et compare.

## 0. Règles du projet (non négociables)

- Toute la couche console reste dans `app/gui/console/`. Au plus 3 retouches minimales hors de ce dossier (les « coutures » déjà existantes). Ne touche pas au moteur Moonlight.
- Zéro friction : jamais de bureau, jamais de menu système, 100 % navigable à la manette.
- Aucune valeur en dur dans les composants : tout passe par `Theme.qml` (tokens synchronisés avec Figma).
- Cible matérielle : RK3588S (Mali-G610). 60 fps tenus. Pas de flou temps réel plein écran.
- Le prototype est du HTML : ce qui est propre au web (variables CSS, `clip-path`, `mix-blend-mode`) doit être traduit, pas copié.

## 1. Canevas et tokens

Écran de référence : **1280 × 800** (16:10). Tout est spécifié en pixels de ce canevas. Prévoir une échelle (`Theme.scale = height / 800`), car l'écran final (MIPI-DSI) n'a pas forcément cette résolution.

| Token | Valeur |
| --- | --- |
| `accent` | `#F2802A` |
| `onAccent` | `#160B03` |
| `ink` | `#F2F0EC` |
| `ink2` | `#A19D97` |
| `ok` (hôte connecté) | `#69D08E` |
| fond | noir pur `#000000` (OLED) |
| `easeOut` | `Easing.OutCubic` (`cubic-bezier(0.33, 1, 0.68, 1)`) |
| `easeQuint` | `Easing.OutQuint` (`cubic-bezier(0.22, 1, 0.36, 1)`) |
| `easeExpo` | `Easing.OutExpo` |

Polices (à **embarquer** dans les ressources Qt et charger avec `QFontDatabase.addApplicationFont` : la console est hors ligne) :
- **Sora** 400 / 500 / 600 : interface et titres.
- **JetBrains Mono** 400 / 500 : données techniques (latence, spécifications du flux).
Les deux sont sous licence OFL.

## 2. Structure de l'écran (de l'arrière vers l'avant)

1. **Fond** : deux calques `Image` plein écran en fondu croisé.
2. **Voile de lisibilité** (scrim).
3. **Barre haute**, **bloc héros** (bas gauche), **étagère de vignettes**, **soulignement**.
4. Par-dessus : **écran de lancement**, **panneau d'options** (Y), **message**, **veille**.

Correspondance avec l'existant : `ConsoleHome` (racine), `GameCarousel` (étagère), `StatusBar` (barre haute), `ControllerLegend` (les glyphes A / Y intégrés au héros remplacent la légende du bas dans cette version). Ajouter `BackdropLayer.qml`, `HeroBlock.qml`, `LaunchOverlay.qml`, `OptionsSheet.qml` si utile.

## 3. Valeurs exactes

### Fond (`BackdropLayer`)
- Deux `Image` (`fillMode: Image.PreserveAspectCrop`, `asynchronous: true`, `sourceSize` = résolution de l'écran, jamais l'image d'origine).
- Changement de jeu : attendre **140 ms** après le dernier déplacement (anti-rebond), puis fondu croisé **560 ms** `easeOut` (le nouveau calque passe devant). L'ancien est vidé **700 ms** après.
- Dérive lente : `scale` 1.03 → 1.09 (+ translation −1 % / −0.6 %), **30 s**, aller-retour, `InOutSine`. Voir la question ouverte n° 3 (batterie).
- Voile : trois `Rectangle` à dégradé superposés :
  - horizontal, de gauche à droite : `rgba(0,0,0,.84)` à 0 %, `.58` à 30 %, `.10` à 58 %, `0` à 72 % ;
  - vertical, de bas en haut : `.92` à 0 %, `.50` à 22 %, `0` à 44 % ;
  - vertical, de haut en bas : `.50` à 0 %, `0` à 16 %.
- Grain : facultatif, désactivé par défaut (le prototype utilise un mélange « overlay » que QML n'a pas).

### Barre haute (x 72, y 26, hauteur 40, marges 72 de chaque côté)
- Pastille hôte : padding 8 / 14 / 8 / 12, rayon 999, fond `rgba(0,0,0,.42)`, filet intérieur 1 px `rgba(255,255,255,.12)`, texte Sora 14 px 500. Point de 7 px : orange et **clignotant** (1.1 s) pendant « connexion… », vert `ok` fixe une fois connecté. Latence en mono 12 px, `ink2`.
- À droite : horloge Sora 17 px 500, icône Wi-Fi, icône batterie (pas de pourcentage dans cette version).

### Bloc héros (ancré en **bas** : bord bas à y = 586, x = 72, largeur 660)
De haut en bas, ces éléments s'empilent (le titre peut passer sur 2 lignes : le bloc grandit **vers le haut**) :
- Méta : Sora 14 px 500, `rgba(255,255,255,.78)`. Contenu : source, séparateur vertical 1 × 12 `rgba(255,255,255,.36)`, dernière session. Espacement 12.
- Titre : Sora **64 px, 600**, interligne 1.04, `letterSpacing` ≈ −1.8 px (−0.028 em). Marge haute 12. Sa hauteur s'anime (**460 ms**, `easeQuint`) quand le nombre de lignes change.
- Sous-titre : Sora 15 px, `rgba(255,255,255,.76)`, marge haute 10. Contenu : « 412 h de jeu ». S'il y a une mise à jour côté PC : puce carrée orange de 6 px + le texte de la mise à jour.
- Actions (marge haute 26) : bouton « Jouer » : hauteur 52, padding 0 / 26 / 0 / 10, rayon 26, fond `accent`, texte `onAccent` Sora 17 px 600, glyphe de bouton (A) dans un rond de 32 px `onAccent` avec la lettre en orange. À côté, à 26 px : glyphe (Y) + « Options », Sora 16 px 500, `rgba(255,255,255,.86)`.

### Étagère (`GameCarousel`)
- Vignette : **176 × 99** (16:9), rayon 8, ombre `0 10px 30px rgba(0,0,0,.55)`. Écart 14. Pour l'index `i` et la position animée `pos` : `d = i − pos`, `f = max(0, 1 − |d|)`.
- `x = 72 + d × 190 + 31.68 × clamp(d, 0, 1)` (le décalage de 31.68 = 176 × 0.18 fait de la place à la vignette active).
- `y = 736 − 99 − 8 × f` ; `transformOrigin: BottomLeft` ; `scale = 1 + 0.18 × f`.
- `opacity = (d < 0 ? clamp(1 + 1.6 × d, 0, 1) : 1) × (0.5 + 0.5 × f)`.
- Ne pas rendre ce qui est hors écran (`visible: false` au-delà de ±60 px).
- **Soulignement** orange : x 72, y 750, hauteur 3, rayon 2, largeur = 176 × 1.18 ≈ 207.7.

### Le ressort qui anime tout
```qml
property real pos: currentIndex
Behavior on pos {
    SpringAnimation { spring: 2.2; damping: 0.30; mass: 1; epsilon: 0.0005 }
}
```
`epsilon` doit être petit : `pos` est un index, avec la valeur par défaut l'animation s'arrête visiblement trop tôt.
**Attention** : j'ai reproduit dans le prototype l'algorithme de `SpringAnimation` de mémoire. Vérifie le ressenti dans le vrai QML, côte à côte avec le prototype (touche `T` du prototype pour régler), et ajuste `spring` / `damping` jusqu'à obtenir le même mouvement.

### Changement de jeu (textes)
Chaque champ sort et entre en glissant (sens = direction du déplacement, distance 70 % de la hauteur du champ), l'ancien à 80 % de la durée en `easeOut`, le nouveau en `easeQuint` :
- méta : **300 ms**, sans délai ; titre : **460 ms**, délai 40 ms ; sous-titre : **300 ms**, délai 90 ms.

### Entrée de l'écran (une seule fois)
Chaque bloc apparaît de 0 → 1 en **460 ms** linéaire avec un glissement vertical de 18 px → 0 en **720 ms** `easeQuint`. Ordre (délai = rang × 60 ms) : barre haute 0, héros 1, vignettes 2 à 7 (au plus 6 échelonnées), soulignement 3. Le fond entre avec un zoom 1.06 → 1 (**1100 ms**, `easeOut`) et un fondu de 900 ms.

### Entrées manette
Répétition à l'appui prolongé : premier délai **360 ms**, puis intervalle **120 ms** qui diminue de 10 ms par répétition jusqu'à 55 ms. Aux extrémités de la liste : petit rebond de `pos` de ±0.12, retour après 90 ms, et un son « butée ».

### Lancement d'un jeu (touche A)
1. Le bouton s'enfonce (`scale` 0.95, 120 ms). Son de sélection.
2. **120 ms** plus tard, l'écran de lancement s'ouvre : image du jeu en fondu (**560 ms**, délai 180) avec un zoom 1.12 → 1 (**1200 ms**, `easeQuint`). En parallèle, le fond zoome à 1.12, le voile disparaît (700 ms), la barre haute s'efface, le héros glisse de 28 px vers la gauche en s'effaçant (260 ms), l'étagère descend de 26 px en s'effaçant.
3. Un voile noir monte à 64 % (**420 ms**, délai 420). À **640 ms** apparaît le bloc de progression (largeur 420, centré, y ≈ 568) : ligne d'étape en mono 13 px, piste de 2 px, barre orange qui avance par paliers (`InOutCubic`, **680 ms** par étape). Le texte d'étape change en 340 ms.
   Étapes : « Réveil de {hôte} » → (si mise à jour) « Mise à jour de {taille} sur le PC » → « Lancement de {jeu} » → « Ouverture du flux {résolution}{fps} {codec} ».
4. Fin : le voile retombe à 0 (700 ms), pastille « En direct » (point rouge, spécifications, latence) en haut à gauche, qui s'efface après 3.4 s. Indication « B : Revenir à l'accueil » en bas, discrète.
5. **B** en cours de jeu : fondu inverse (560 ms) puis retour à l'accueil.
Cette séquence est **la seule animation « signature »** de l'interface : ne pas en ajouter d'autres de cette ampleur.

### Options du flux (touche Y)
- Panneau de droite, largeur 472, fond `rgba(18,18,20,.95)`, glisse en **440 ms** `easeQuint` ; le reste s'assombrit à 62 % (320 ms).
- Lignes de 60 px : résolution, images par seconde, débit, codec, HDR, « Oublier ce PC ». Le surlignage (fond `rgba(255,255,255,.10)`, rayon 14) se déplace en **220 ms** `easeOut`. Gauche/droite (ou A) change la valeur, l'ancienne sort et la nouvelle entre horizontalement en **260 ms**.
- « Oublier ce PC » demande une seconde confirmation (le texte devient « Confirmer : oublier {hôte} ? » en orange).
- Ces réglages doivent lire et écrire les vraies préférences de Moonlight (pas un état séparé).

### Sons (facultatif dans un premier temps)
Petits sons courts : tick de déplacement (~880 Hz, 40 ms), butée, sélection, retour, ouverture / fermeture du panneau, prêt. À charger avec `QSoundEffect` (fichiers `.wav` courts), volume très bas.

## 4. Traduction web → QML (pièges)

- Pas de `clip-path` en QML : pour l'ouverture « depuis la carte » (utilisée dans les autres versions), passer par un `Item` avec `clip: true` animé. Dans Ambiant, le lancement est un fondu, donc inutile.
- Un seul `Behavior` sur `pos` ; toutes les vignettes se calculent à partir de lui (pas d'animation par vignette).
- Éviter `layer.enabled` sur les éléments plein écran, et tout `MultiEffect` / flou temps réel.
- Les images du fond : pré-réduites à la résolution de l'écran, `cache: true`, une seule `Image` par calque.
- Animer uniquement `x`, `y`, `scale`, `opacity` (jamais `width` / `height` d'éléments dans un `Row` ou un `Column`).
- L'animation continue de dérive du fond empêche le GPU de se mettre au repos.

## 5. Données nécessaires (à brancher sur la couche Companion)

Par jeu : titre, source (Steam, GOG, Epic…), dernière session, temps de jeu, **image de fond 16:9** (« hero »), vignette 16:9, indicateur de mise à jour en attente (+ taille).
Si l'image 16:9 manque : utiliser la jaquette, recadrée et assombrie, plutôt que de laisser le fond vide.

## 6. Décisions déjà prises dans le prototype (à confirmer ou changer)

1. L'accueil ne montre **que des jeux** (Desktop, Steam Big Picture et Virtual Display en sont retirés, cohérent avec « jamais de bureau »).
2. Les jaquettes du prototype sont des illustrations de remplacement.
3. Dérive lente du fond activée.
4. Les écrans **d'appairage, d'erreur réseau, de bibliothèque vide et de chargement des images** ne sont pas conçus : garder l'existant en attendant, ou demander une proposition dans le même langage visuel.

## 7. Modifications demandées par rapport au prototype

> À compléter par Coco avant de lancer Claude Code.

-
-
-

## 8. Critères d'acceptation

- Capture de l'écran d'accueil comparée à la version Ambiant du prototype, jeu par jeu : mêmes positions à ±2 px.
- Déplacement d'un jeu à l'autre : même mouvement que le prototype (à vérifier en superposant deux vidéos ou en comparant des images clés).
- 60 fps constants pendant un défilement rapide (appui prolongé) sur la carte cible, sinon réduire la dérive et les effets avant tout autre chose.
- Aucun fichier modifié hors de `app/gui/console/` en dehors des coutures autorisées.
