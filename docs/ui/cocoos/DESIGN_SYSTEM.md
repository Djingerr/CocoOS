# Système de design CocoOS

> Copie du brand book publié (Design System « CocoOS »). Les valeurs exactes sont dans `tokens.json`.

CocoOS est l’interface d’une console portable de streaming de jeux (Orange Pi 5B, écran OLED 1280 × 800). Elle reprend la retenue d’Apple : fond noir pur, verres flous, une seule couleur d’accent, du mouvement doux et des sons discrets. Ces règles valent pour tous les écrans : accueil, fiche jeu, options, menu en jeu, réglages, configuration, écrans de veille.

## Principes

- **Le jeu est le héros.** L’art du jeu (jaquette, fond Playnite flouté avec `blur-backdrop`) donne la couleur de l’écran ; l’interface reste noire, blanche et `accent`.
- **Une seule chose à faire par écran.** Un bouton principal (`Bouton` principal), un focus visible, une barre d’aide en bas.
- **Tout se fait à la manette.** Chaque écran est utilisable avec la croix, A, B, Y, LB/RB et ≡ ; la barre d’aide le rappelle.
- **Rien ne s’entend ni ne bouge par-dessus le jeu** sans raison : seuls le volume, les captures et les alertes passent au-dessus du stream.

## Contenu et ton

- Français, vouvoiement : « Choisissez votre langue », « Appuyez pour commencer ».
- Casse de phrase partout ; capitales uniquement pour les libellés de section (`label`) : « PROFIL DE STREAM ».
- Verbes d’action à l’infinitif sur les boutons et dans les aides : « Jouer », « Réveiller le PC », « Effacer ».
- Unités à la française avec espace insécable : « 82 % », « 4 ms », « 18,4 Mb/s », « 1 h 24 min », heure en 24 h.
- Le séparateur des métadonnées est le point médian : « Mojang Studios · 2011 · Bac à sable ».
- Pas d’emoji, pas de point d’exclamation. Les messages d’erreur disent ce qui se passe et quoi faire : « PC-Salon ne répond pas. Vérifiez que le PC est allumé et relié au même réseau. »
- Le PC s’appelle par son nom (« PC-Salon »), jamais « l’hôte » ni « le serveur ».

## Couleur

- Fond : `oled-black` partout. Les dégradés viennent seulement de l’art du jeu flouté, assombri par un vignettage radial vers le noir.
- Texte : `ink` pour le principal, `ink-secondary` pour les métadonnées, `ink-tertiary` pour les libellés et aides (12 px minimum).
- `accent` (#F2802A) marque l’identité et l’état actif : le S et le O du logo, interrupteur actif, progression, point « en ligne », touche Valider. Jamais en aplat de fond d’écran ni pour du texte courant. Le texte sur `accent` est `accent-ink`.
- Verres : `glass-pill` (barre du haut), `glass-group` (listes), `glass-sheet` (feuilles), `glass-dialog` (dialogues, menus), `glass-hud` (au-dessus du jeu), toujours avec un `backdrop-filter: blur()` des jetons `blur-*` et `saturate(1.6)`, et un contour `hairline-strong`.
- `danger` signale un problème (hors ligne, batterie critique) et s’accompagne toujours d’un mot.
- L’accent peut être changé par l’utilisateur (orange, blanc, bleu `blue`, vert, rose) : tout ce qui est en `accent` suit.

## Typographie

- Une seule famille : Sora (Google Fonts), de 11 à 76 px. Titres en 600 avec un interlettrage négatif (`display`, `title-xl`, `title-l`, `title-m`), texte en 500.
- Le titre d’un jeu est en `display` sur la fiche et la veille, en `title-xl` sous le carrousel.
- Chiffres tabulaires pour l’heure, la latence, les pourcentages et les compteurs.

## Mise en page

- Cadre 1280 × 800. Logo texte à `margin-screen` (72 px) à gauche et 34 px du haut ; barre d’état à `margin-status` (56 px) à droite et 30 px du haut ; aides à 34 px du bas.
- Le contenu central reste dans une colonne de 560 à 640 px pour les listes de configuration ; les feuilles d’options font 492 px de large collées à droite avec 16 px de marge.
- Rayons : `radius-cover` pour les jaquettes, `radius-group` pour les listes, `radius-sheet` pour les feuilles et le clavier, `radius-dialog` pour les dialogues, `radius-pill` pour tout ce qui est pastille.
- Ombres : seulement `shadow-cover` (jaquettes), `shadow-glass` (verres flottants), `shadow-focus` (élément au focus).
- Grain : un bruit fractal à 7 % en `overlay` sur les écrans plein cadre pour casser les aplats de l’OLED.

## Mouvement

- Courbes : `ease-main` par défaut, `ease-spring` pour ce qui arrive (dialogues, bannières, focus), `ease-spring-strong` pour le relâchement d’un bouton, `ease-exit` pour ce qui part.
- Durées : `dur-press` (110 ms) pour l’appui, `dur-focus` (210 ms) pour déplacer le focus, `dur-enter` (560 ms) pour ouvrir, `dur-exit` (260 ms) pour fermer, `dur-scene` (900 ms) pour changer de scène. Une sortie est toujours plus courte que l’entrée.
- Appui : échelle 0,92 à 0,94 puis rebond ; focus : échelle 1,08 avec `shadow-focus`.
- Les textes changent par fondu flou (opacité, `blur(5px)`, 10 px de déplacement), jamais par coupe sèche.
- Une animation interrompue repart de sa position actuelle ; on n’attend jamais la fin d’une animation pour accepter une touche.
- Réglages › Accessibilité › Réduire les animations remplace déplacements et ressorts par des fondus de 200 ms.

## Son

- Chaque interaction a un son du pack CocoOS (59 sons, 6 ambiances), tous en Mi majeur pentatonique, énergie entre 500 Hz et 6 kHz pour le haut-parleur de la console.
- Ouvrir monte, fermer descend ; la navigation utilise trois variantes de `nav_move` en alternance.
- Pas de sons d’interface pendant le stream, sauf `volume_tick`, `capture` et les alertes. Réglages › Écran et son › Sons de l’interface coupe tout.

## Commandes et glyphes

- Disposition Xbox par défaut : A valider, B retour, X effacer, Y options ou espace, LB/RB onglets, LT majuscule, ≡ menu ou valider une saisie. Voir `GlypheManette` pour les équivalents PlayStation et Nintendo.
- Les glyphes sont dessinés en CSS (disque ou pastille au contour `ink-secondary`), jamais en image.

## Iconographie

- Icônes au trait, dessinées à la main en SVG inline : trait de 1,6 à 1,8 px, extrémités et angles arrondis, `ink` ou `ink-secondary`. Formes pleines seulement pour la batterie, la lune (veille) et le point d’état.
- Dans les Réglages, chaque rubrique a son icône blanche dans une tuile de couleur de 30 px (rayon 8 px).
- Il n’existe pas encore de jeu d’icônes complet : les icônes vivent dans les maquettes et seront extraites en fichiers lors du passage en QML.

## Logo

- Le logo est un mot-symbole en Sora 600 : « Coco » en `ink`, un O en anneau `accent` (épaisseur 8,8 px à 64 px), « S » en `accent`. Aucun fichier de logo n’existe encore : il est composé en texte.
- L’anneau O sert aussi d’indicateur de chargement et de mise à jour.

## Images

- Jaquettes 600 × 848 fournies par HostCompanion depuis Playnite ; fonds tirés de l’art Playnite, toujours floutés. Sans image, un squelette `glass-group` avec balayage.
- Pas de photos de personnes ni d’illustrations décoratives.
