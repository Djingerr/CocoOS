# Spécification — Refonte CocoOS

> Complète `CLAUDE_BRIEF.md`. Chaque section renvoie aux planches de `reference/` par leur
> identifiant (`<id>` = nom du fichier sans extension). Une valeur qui manque ici se lit dans
> `reference/dc-source/<id>.dc.html`.

## 1. Jetons : `tokens.json` → `Theme.qml`

Garder les noms existants de `Theme.qml` quand ils désignent la même chose (seule leur valeur
change), ajouter les autres en camelCase.

| `tokens.json` | `Theme.qml` | Note |
|---|---|---|
| `oled-black` | `background` | inchangé `#000000` |
| `ink` | `ink` | `#F2F0EC` → `#F5F5F7` |
| `ink-secondary` | `ink2` | → `rgba(245,245,247,0.6)` |
| `ink-tertiary` | `ink3` | → `rgba(245,245,247,0.5)` |
| `accent` | `accent` | inchangé ; peut suivre la jaquette (§5.9) |
| `accent-ink` | `inkOnAccent` | → `#1B0E04` |
| `danger` | `poor` + alias `danger` | `#FF453A` |
| `glass-pill`, `glass-group`, `glass-raised`, `glass-sheet`, `glass-dialog`, `glass-hud` | `glassPill`, `glassGroup`, … | toujours avec le flou `blur-*` correspondant et `hairline-strong` |
| `hairline`, `hairline-strong`, `focus-row`, `key-char`, `key-fn`, `toggle-off`, `segment-track`, `segment-active`, `accent-track`, `accent-soft`, `blue` | idem en camelCase | |
| `radius-*` | `radiusCoverS` 8, `radiusCover` 12, `radiusKey` 14, `radiusGroup` 20, `radiusSheet` 32, `radiusDialog` 36, `radiusPill` | |
| `shadow-*` | ombres **pré-rendues** en PNG (comme `shadows/`), régénérées par un script du harnais | pas de `DropShadow` animé |
| `blur-pill` 30, `blur-sheet` 40, `blur-backdrop` 100 | `blurPill`, `blurSheet`, `blurBackdrop` | `MultiEffect.blurMax` adapté ; flou fait une fois sur une image réduite |
| `dur-press` 110, `dur-focus` 210, `dur-exit` 260, `dur-enter` 560, `dur-scene` 900 | `durPress`, … | `pressDuration` (90) passe à 110 |
| `ease-main`, `ease-spring`, `ease-spring-strong`, `ease-exit` | `curveMain`, `curveSpring`, `curveSpringStrong`, `curveExit` | `Easing.BezierSpline` : `[x1, y1, x2, y2, 1, 1]` ; les y > 1 donnent le dépassement |
| styles de texte `display` 76 … `glyph` 11 | `textDisplay`, … (taille, graisse, interlettrage en px) | interlettrage : `-0.04em` → px à la taille utilisée |

Les ressorts physiques de `Spring.js` restent pour ce qui suit le doigt (focus du carrousel,
chiffres). Les courbes CocoOS servent aux entrées, sorties et panneaux.

`ok` / `fair` (vert, jaune) ne servent plus que dans les statistiques en jeu (« EXCELLENT ») :
partout ailleurs l'état « en ligne » est le point `accent` qui respire (`cocoLive` 2,4 s).

## 2. Sons

- Pack : `sounds/wav/*.wav` (48 kHz, 16 bits, stéréo) et `sounds/manifest.json` (déclencheur
  de chaque son). Tous en Mi majeur pentatonique, crêtes de −27 à −6 dBFS déjà réglées : ne pas
  renormaliser.
- `SoundEffect` préchargés au démarrage (après `BootSplash`, comme les relevés D-Bus) ; ambiances
  en `SoundEffect` à boucle infinie (raccord sans couture) avec fondu croisé 1,8 s / 0,9 s.
- Navigation : `play("nav_move")` alterne `nav_move_1/2/3` ; `nav_move_fast` (pas de 190 ms,
  flèche maintenue) limité à 11 par seconde.
- Pas de son d'interface pendant le stream, sauf : `ingame_menu_*`, `focus_tick`, `slider_*`,
  `volume_*`, `capture`, alertes (`battery_*`, `controller_*`, `network_*`).
- Réglages › Écran et son : « Sons de l'interface » coupe tout ; « Ambiances des écrans de veille »
  coupe seulement `amb_*`.

Alias des noms actuels (dans `Sounds.qml`, pour ne casser aucun appel existant) :

| Ancien | Nouveau | | Ancien | Nouveau |
|---|---|---|---|---|
| `move` | `nav_move` (rotation) | | `toggle-on` / `toggle-off` | `toggle_on` / `toggle_off` |
| `edge` | `nav_edge` | | `hold` | `hold_fill` (arrêté par `stop`) |
| `select` | `select` | | `confirm` | `hold_done` |
| `back` | `back` | | `deny` | `deny` |
| `open` | `sheet_open` | | `notify` | `notification` |
| `close` | `sheet_close` | | `detent` | `slider_tick` |
| `tick` | `focus_tick` | | `segment` | `tab_switch` |
| `launch` | `launch_start` | | `boot-close` | *(aucun : `boot` couvre toute l'animation)* |
| `ready` | `launch_ready` | | `boot-open` | `boot` |

Les appels qui ont un son plus juste dans le nouveau pack (fiche : `fiche_open`/`fiche_close` au
lieu de `open`/`close` ; catégories : `category_next`/`category_prev`) sont à changer à l'appel.

## 3. Vibrations

`motion/haptics.json` : 14 motifs, chacun relié à un son. Deux moteurs (`L` lourd basse fréquence,
`H` léger haute fréquence), impulsions `{start, duration, from, to}` en ms et amplitude 0..1.
Lecture par `SDL_GameControllerRumble` (pas de 10 ms ; une rampe `from → to` se découpe en paliers).
Niveaux : Off 0, Légères 0,6, Fortes 1,0 (Réglages › Bluetooth et manettes). Déclenchement : le
signal `Sounds.played(name)` existant, via une table nom de son → motif. La manette intégrée
(GP2040-CE) n'a peut-être pas de moteurs : à vérifier en phase 0, sans bloquer le reste.

## 4. Commandes

| Touche | Accueil | Fiche | Feuilles, listes | Clavier | Pendant le jeu |
|---|---|---|---|---|---|
| Croix / stick | parcourir (maintenu : rapide) | défiler | focus | touche suivante | menu ouvert : focus |
| A | Jouer | Jouer | valider / modifier | taper (maintenu : accents) | menu : valider |
| B | — (consommé) | revenir | fermer / retour | annuler | menu : reprendre |
| X | — | Favori / Retirer | — | effacer | — |
| Y | Options | Options | — | espace | — |
| LB / RB | catégorie | — | onglet ou menu ↔ contenu (Réglages) | curseur | — |
| LT / RT | saut alphabétique (> 30 jeux) | — | — | LT : majuscule | — |
| ↓ / ↑ | ↓ ouvre la fiche | ↑ en haut : referme | | | |
| ≡ | — | — | valide une saisie | valider | — |
| Home (Xbox, PS) | — | — | — | — | ouvre / ferme le centre de contrôle (déjà câblé) |
| Partager | — | — | — | — | capture (déjà câblé) |
| Power court | veille | veille | veille | veille | veille (stream en pause côté PC) |
| Power long (≈ 1,2 s) | menu d'alimentation | idem | idem | idem | idem |
| Volume +/− (dessus) | HUD volume en haut | idem | idem | idem | HUD dans l'overlay |

Glyphes : disposition Xbox par défaut ; Réglages › Bluetooth et manettes › « Glyphes à l'écran »
(Xbox, PlayStation, Nintendo), et détection automatique de la famille de manette (`InputStatus`
la connaît déjà). `ButtonGlyph.qml` dessine les glyphes en QML (disque ou pastille au contour
`ink2`), jamais en image.

## 5. Écrans

Pour chaque écran : **Réf.** planches, **Composant**, **Données**, puis ce qui demande de
l'attention. Les sons et vibrations à l'instant près sont dans `motion/cues.json`.

### 5.1 Accueil — carrousel 3D
**Réf.** `AccueilCarrousel`, `MotionNavigation`, `MotionCategories`, `MotionJaquettes`,
`EtatFavorisVide`, `CasLimites`. **Composant** `HomeScreen` + nouveaux `CoverFlow.qml`,
`CategoryTabs.qml`. **Données** `CompanionClient.games()` (jaquette 600 × 848, fond, éditeur,
année, genre, PEGI, favori, dernière session), sinon `AppModel` en repli.

- Géométrie (source `AccueilCarrousel.dc.html`, `renderVals`) : sol à y = 436, centre x = 640.
  Emplacements par distance `k` au centre : `[largeur, hauteur, décalage x, luminosité]` =
  `[240,340,0,1]`, `[190,269,250,.6]`, `[160,227,430,.38]`, `[140,198,580,.2]`. Rotation
  `rotateY = −signe(o) × (38 + (k−1) × 6)°`, perspective 900 px (`Matrix4x4`, pas `Rotation`).
  Reflet au sol : copie retournée, masque 24 % → 0 sur 18 % de hauteur. Fondus noirs 160 px sur
  les bords.
- Jaquette au centre : liseré 1 px blanc 12 %, ombre `shadow-cover`, reflet qui balaie toutes les
  10 s (`cocoSheen`). Latérales : titre en 12 px sur un dégradé bas.
- Déplacement : chaque jaquette glisse vers l'emplacement suivant (ressort `springSnappy`), le fond
  change en fondu croisé (`backdropFade`), le titre et la méta changent en fondu flou
  (`SwapBox` avec `blur`). Maintenu : pas de 190 ms, jaquettes floutées en mouvement. Butée :
  rebond de 34 px puis retour (`nav_edge`).
- Catégories Tout / Favoris / Récents / Apps : pastille blanche qui glisse (`ElasticIndicator`), le
  carrousel sort par le côté opposé et le nouveau entre en éventail (`MotionCategories`).
- Bloc sous le carrousel : titre `title-xl` 48 px centré, méta « Éditeur · Année · Genre » + PEGI,
  boutons « A Jouer » (blanc) et « Y Options » (verre). Aide en bas : « ◀ ▶ Parcourir », « ↓ Plus
  d'infos » (flèche qui oscille de 3 px).
- Chargement des jaquettes : squelettes en verre avec balayage, chaque jaquette apparaît en fondu
  dès qu'elle arrive, le fond en dernier (`MotionJaquettes`), puis `library_ready`.
- Cas limites (`CasLimites`) : titre sur 2 lignes équilibrées, puis 48 → 36 px, puis points de
  suspension ; jaquette composée si absente (dégradé tiré du fond du jeu, sinon une des 6 teintes
  de secours choisie par hachage du nom, éditeur en libellé, titre Sora 600) ; un champ absent
  disparaît avec son séparateur ; au-delà de 30 jeux, RT / LT sautent à la lettre suivante /
  précédente avec la lettre dans un carré de verre au centre (`tab_switch`, vibration `category`).
- « Aucun favori » : quatre emplacements en pointillés en perspective, étoile dans un disque de
  verre, « RB Voir les jeux récents ».

### 5.2 Fiche jeu — éditoriale
**Réf.** `FicheEditoriale`, `MotionFiche`, `MotionFavori`. **Composant** `GamePage`.
**Données** jeu Companion : éditeur, développeur, date de sortie, genres, PEGI, modes (solo,
multijoueur, manette), temps de jeu, note critique, taille installée, plateformes, dernière session,
description. Phase 0 : lister les champs absents de l'API Companion (ne pas les inventer, masquer).

- ↓ depuis l'accueil : la jaquette centrale quitte le carrousel et va à gauche en s'inclinant,
  les autres s'effacent, le texte arrive de droite en cascade (`MotionFiche`). ↑ (en haut) ou B :
  l'inverse, plus court.
- Boutons : « A Jouer », « X Favori », « Y Options ». Favori : l'étoile se remplit en `accent`,
  anneau qui s'élargit, bannière « Ajouté aux favoris » ; X à nouveau : « Retiré des favoris ».
  Les favoris sont aussi écrits dans Playnite (via Companion), comme aujourd'hui.
- Description longue : défilement par lignes entières (comportement actuel de `GamePage`).

### 5.3 Options (Y) — feuille groupée
**Réf.** `OptionsFeuille`, `MotionOptions`. **Composant** `OptionsSheet`.

- Feuille 492 px, collée à droite avec 16 px de marge, `glass-sheet` + flou 40, `radius-sheet`.
  L'accueil recule légèrement et s'assombrit derrière.
- En-tête : nom du jeu, « Options », « PC-Salon · connecté · 4 ms ». Onglets LB/RB « Stream » et
  « Console ».
- Stream : profil (Compétitif, Équilibré, Qualité, Éco, Manuel) en contrôle segmenté, résolution,
  images/s, débit, priorité, note « Réseau faible : le profil descend automatiquement de deux
  crans. », section « Avancé ». Branché sur `StreamProfiles.js` et `StreamingPreferences`.
- Console : mise en veille, sons, réduire les animations, langue, et « Tous les réglages ».
- Aide : « A Modifier », « B Fermer ». Nombres qui roulent (`RollingNumber`).

### 5.4 Réglages
**Réf.** `ReglagesWifi`, `ReglagesManettes`, `ReglagesEcranSon`, `ReglagesGeneral`.
**Composant** nouveau `settings/SettingsScreen.qml` + une page par rubrique.

- Plein écran : menu à gauche (carte « Console de Coco · CocoOS 1.2 · 82 % · 41 Go libres », puis
  les rubriques, chacune avec son icône blanche dans une tuile de couleur 30 px rayon 8), contenu
  à droite en listes groupées. LB/RB passent du menu au contenu.
- Wi-Fi (`WifiSetup`, `SystemStatus`) : réseau connecté avec signal, lien, latence vers le PC ;
  autres réseaux ; secours 5G ; bande préférée. Bluetooth et manettes (`InputStatus`) : connectées,
  connues, associer, glyphes, vibrations, test des boutons. Écran et son : luminosité automatique,
  couleurs, chaleur le soir, sons de l'interface, ambiances, sortie audio. Général : mise à jour,
  stockage, à propos, licences, réinitialiser (appui maintenu `HoldFill`).
- Rubriques sans maquette (Notifications, Batterie, Accessibilité, Confidentialité, PC et streaming,
  Bibliothèque) : même gabarit, contenu limité aux réglages qui existent déjà dans la conf ; sinon
  rubrique masquée. À lister dans « Questions pour Coco ».

### 5.5 Clavier et recherche
**Réf.** `ClavierWifi`, `Recherche`, `MotionClavier`. **Composant** `OnScreenKeyboard`, nouveau
`SearchScreen.qml`.

- Clavier en verre `radius-sheet`, AZERTY par défaut (selon la langue), QWERTY via la touche globe.
  X efface, Y espace, LT majuscule, LB/RB déplacent le curseur, A maintenu ouvre les accents
  (bulle au-dessus de la touche), ≡ valide, B annule. Mot de passe : caractères masqués, le dernier
  visible 1 s ; R3 affiche / masque.
- Recherche : champ « titres, éditeurs et genres », recherches récentes, suggestions, résultats en
  jaquettes ; état « aucun résultat » (dans les propriétés de la planche).

### 5.6 Lancer, quitter, erreurs, PC
**Réf.** `MotionLancement`, `MotionQuitter`, `MotionEchec`, `MotionReveilPC`, `ChoixPC`,
`EtatHorsLigne`. **Composant** `LaunchScreen`, `StreamCurtain`, `ConsoleHome`, nouveau
`HostPicker.qml`.

- Lancement : A s'écrase (110 ms), la jaquette grandit vers le centre, statuts en fondu flou
  (« Réveil de PC-Salon… » → « Lancement de Minecraft… » → « Connexion au flux vidéo… »), boucle
  `connecting_loop`, puis l'image du jeu prend l'écran ; bannière « Connecté à PC-Salon » (sans
  son). Le premier statut n'apparaît que si le PC dormait. Minutage : `MotionLancement.dc.html`.
- Quitter (menu en jeu) : alerte de confirmation, puis l'image se réduit en jaquette qui reprend sa
  place dans le carrousel (`quit_confirm`).
- PC injoignable : après l'échec, carte « PC-Salon ne répond pas » avec « Réessayer » et « Réveiller
  le PC » ; le réveil passe par Wake-on-LAN (`MotionReveilPC` : pastille du PC qui s'étire, roue,
  coche, « PC-Salon est en ligne »).
- Choix du PC : liste des PC (connecté, en veille avec « Réveiller », introuvable), « Ajouter un
  PC ». A Basculer, B Fermer. Données `ComputerModel` + Companion.
- PC hors ligne : carrousel grisé, « PC-Salon est hors ligne », « Votre bibliothèque reste
  consultable. Réveillez le PC pour jouer. », « A Réveiller le PC », « Y Choisir un autre PC ».

### 5.7 Par-dessus le jeu (overlay QPainter)
**Réf.** `JeuControle`, `MotionMenuJeu`, `StatsOverlay`, `MotionHud`, `MotionCapture`,
`MotionAlertes`, `MotionReseau`. **Composant** `backend/streammenu` + `streampainter`.

- Centre de contrôle : image du jeu floutée et assombrie (flou déjà disponible dans `streammenu`),
  tuiles : Reprendre, luminosité, volume (curseurs verticaux), Capture, Statistiques, Accueil,
  Quitter le jeu, Veille, Alimentation. Entrée en ressort, sortie plus courte ; minutage dans
  `MotionMenuJeu.dc.html`.
- Statistiques : version détaillée (latence totale et détail, image, débit, images perdues,
  batterie) et compacte (une ligne en haut).
- HUD volume : capsule horizontale en haut de l'écran (les boutons sont sur le dessus de la console),
  220 px, fine (10 px) puis épaisse (48 px) pendant les appuis, remplissage de gauche à droite,
  icône du haut-parleur à gauche, étirement élastique en butée, position réglable (gauche, centre,
  droite). Même rendu sur l'accueil (QML) et dans l'overlay.
- Capture : flash, l'image se réduit en vignette qui glisse en bas à gauche, bannière « Capture
  enregistrée ».
- Alertes : batterie 5 % (bannière en haut), manette déconnectée (jeu en pause, carte centrale qui
  se transforme en « Manette reconnectée »), réseau (pastille qui change : Wi-Fi perdu → 4G, qualité
  ajustée, Wi-Fi retrouvé).

### 5.8 Système
**Réf.** `Demarrage`, `MotionVeille`, `MotionReveil`, `MotionExtinction`, `MenuAlimentation`,
`MotionAlimentation`, `Veille*`, `MotionMiseAJour`, `MotionRecharge`, `MotionSalon`, `LedConsole`.

- Démarrage (`BootSplash`, `BootTimeline.js`) : animation du O inchangée jusqu'à 3,2 s ; nouvelle
  sortie : « Coco » et « S » s'effacent, le O glisse au centre, se déplie en jaquette du jeu
  sélectionné, les autres jaquettes s'ouvrent en éventail, le fond flou monte, puis titre, boutons,
  barre du haut et aide (minutage dans la note de la planche et `Demarrage.dc.html`).
- Veille (power court) : l'interface recule et s'efface, un point lumineux reste un instant au
  centre puis s'éteint (`sleep`). Réveil : pas de point ; le fond revient, les jaquettes se
  remettent en place en cascade (45 ms d'écart) et le texte monte (`wake`). Minutage :
  `MotionVeille.dc.html`.
- Sortie de l'écran de veille (une touche) : les jaquettes reviennent en éventail, le texte monte
  (`idle_exit`).
- Extinction : l'accueil se replie, le logo apparaît, l'anneau O se vide, un point puis le noir.
- Menu d'alimentation (power long) : « Mise en veille », « Redémarrer », « Éteindre » en grandes
  tuiles, batterie et autonomie en tête, « Le stream en cours sera fermé proprement avant l'arrêt. »
  ; ◀ ▶ choisit, A confirme, B annule ; « Redémarrage… » puis l'animation d'extinction.
  `SystemStatus.power()`.
- Écran de veille (5 min sans action) : 4 états (jeu en cours, jeu + téléchargement, téléchargement
  seul, repos), 1280 × 800, ambiances `amb_veille` / `amb_repos`. Reprendre le travail de la branche
  `feat/idle-screen` (modèle `IdleStatus`, composants) en mettant les écrans à ces références.
- Mise à jour : le O sert de barre de progression, redémarrage, « CocoOS 1.2 est installé ».
  Mécanisme de mise à jour à définir : interface + backend factice.
- Recharge console éteinte, mode salon, LED : dépendent du matériel. Interface déclenchable depuis
  le harnais ; la LED est une spécification pour le firmware (`LedConsole`).

### 5.9 Première configuration
**Réf.** `SetupBonjour`, `SetupLangue`, `SetupWifi`, `SetupPC`, `MotionAppairage`,
`SetupBibliotheque`, `MotionSetupFin`. **Composant** nouveau `setup/`.

- Parcours : Bonjour (« Appuyez pour commencer » dans plusieurs langues) → Langue (région, clavier,
  format d'heure) → Wi-Fi ou 5G (mot de passe au clavier ; 5G proposée si une SIM est détectée) →
  Choix du PC (PC trouvés sur le réseau, « Ajouter avec une adresse IP », « Installer Apollo et
  HostCompanion » avec code QR) → code PIN (écran `MotionAppairage`, logique `CompanionPairing` et
  liaison Moonlight existantes) → Bibliothèque (progression des jaquettes « 132 / 214 », préférences :
  accent, sons, jeux non installés, mise en veille) → « Tout est prêt » → accueil.
- En-tête « PREMIÈRE CONFIGURATION · n SUR 3 ». Marqueur `ConsoleUi/setupDone`. Les écrans
  d'attente actuels (recherche, liaison) restent pour les cas hors configuration.

### 5.10 Finitions
**Réf.** `MotionCourbes`, `MotionInterruption`, `MotionReduite`, `MotionAccent`, `Vibrations`.

- Interruption : en plein déplacement, un nouvel appui repart de la position courante ; une feuille
  qui se ferme et qu'on rouvre repart de là où elle en est.
- Réduire les animations : déplacements et ressorts remplacés par des fondus de 200 ms ; le
  carrousel change de jaquette sans rotation.
- Accent du jeu : `AmbientColor` sur la jaquette, couleur ramenée dans une plage lisible (luminance
  et saturation bornées comme dans `MotionAccent.dc.html`), transition 600 ms. Option dans
  Réglages ; désactivée : `#F2802A` ou l'accent choisi.

## 6. Navigation

`reference/png/CarteNavigation.png` est la carte. En bref :

- Allumage → Démarrage → (1re fois) Configuration → Accueil ; (déjà configuré) → Accueil.
- Accueil ↔ Fiche (↓ / ↑), Accueil → Options (Y) → Tous les réglages → Réglages ; Recherche.
- Accueil → (A) Lancement → Stream ; (PC hors ligne) → PC injoignable → Réveil du PC → relance.
- Stream → (Home) Menu en jeu → Statistiques / Quitter → Accueil (jaquette qui revient).
- Partout : power court → Veille → retour à l'écran quitté ; power long → Menu d'alimentation →
  Extinction ou redémarrage ; 5 min sans action → Écran de veille → une touche → Accueil (éventail) ;
  câble branché → Recharge (console éteinte) ; TV branchée → Mode salon. Par-dessus le jeu :
  volume, capture, alertes.

## 7. Questions à poser à Coco (ne pas trancher seul)

- Appui long sur power : par logind (`HandlePowerKey=ignore` + inhibiteur) ou par le firmware
  GP2040-CE ? Nouvelle couture nécessaire ?
- Luminosité et volume pendant le stream : déjà par logind et `wpctl` ; HUD par l'overlay suffit-il ?
- Champs de la fiche absents de l'API Companion (note critique, modes de jeu, taille installée).
- Mécanisme de mise à jour de CocoOS (paquet, image A/B, autre).
- Recharge console éteinte : quel programme s'affiche avant le démarrage complet ?
- Mode salon et LED : matériel encore ouvert.
- Moteurs de vibration sur la manette intégrée.
