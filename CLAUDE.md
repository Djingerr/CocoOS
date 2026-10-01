# CLAUDE.md — Console de streaming portable (projet DIY)

> Ce fichier donne le contexte complet du projet à Claude Code. Lis-le en entier
> avant toute modification. Le repo est un **fork de `moonlight-stream/moonlight-qt`**.

---

## 1. Le but final

Construire une **console de jeu portable, peu coûteuse à produire**, qui ne fait *pas*
tourner les jeux en local : elle **streame les jeux depuis un PC** (le PC fait le rendu,
la console n'est qu'un client d'affichage + manette). L'objectif est de permettre de jouer
à des jeux gourmands (AAA) sur un appareil léger à bonne autonomie, dès lors qu'on a une
bonne connexion.

Deux horizons :
- **Court terme** : un prototype fonctionnel à base de cartes off-the-shelf pour valider
  l'expérience et le logiciel.
- **Long terme** : un **produit grand public**, compact, pas cher à fabriquer, et à terme
  utilisable en mobilité via un **module 5G** (la difficulté finale, volontairement
  repoussée à la fin).

### Le principe directeur, non négociable : ZÉRO FRICTION

L'expérience doit être **aussi proche que possible d'une vraie console**, pour un novice
comme pour un expert. Conséquences concrètes pour tout ce qu'on code :
- **Aucun menu Linux, aucune fenêtre, aucun bureau visible.** Jamais.
- Au démarrage, la console **boote directement** sur l'interface de jeux et se **connecte
  automatiquement** au PC host.
- L'appairage (PIN) doit être **invisible** pour l'utilisateur (pré-appairage à la config,
  ou auto-acceptation du certificat).
- Tout doit donner le ressenti « j'allume, je joue ».

---

## 2. État actuel du projet

- Le streaming est **validé depuis ~1 an** : Moonlight + Sunshine + Tailscale, qui
  fonctionne bien, y compris **en 5G depuis un smartphone** (le chemin réseau/NAT est donc
  gérable — le concept est prouvé).
- Le repo est un **fork de moonlight-qt** (officiel), développé sous **Fedora KDE Plasma**,
  en **Qt 6**.
- Le fork **compile et se lance**, et le **décodage matériel fonctionne** (GPU Intel Iris Xe,
  pilote iHD/VAAPI, décodage H.264/HEVC/**AV1** confirmé).
- Une **interface console maison** (« Ambiant », voir §5) a été conçue et validée
  visuellement. Tout son code (QML + backends C++) vit dans `app/gui/console/`.
- ✅ **Intégration au build faite** (commit `64bb96a0` sur `console-ui`) : 3 coutures dans
  `app.pro`, `qml.qrc`, `main.cpp`, derrière `embedded`/`CONSOLE_UI`. Le binaire `embedded`
  démarre sur `ConsoleHome`, le binaire vanilla est inchangé.
- ✅ **UI branchée sur les vraies données Moonlight** (commits `e0f7600c` + `5df70d84`) :
  `ConsoleHome` lit `ComputerModel`/`AppModel`, sélectionne automatiquement le premier host
  online+paired, et le bouton Jouer crée une vraie session via `StreamSegue.qml`.
- ✅ **Appairage automatique côté console + refonte visuelle "pro"** : dès qu'un host en
  ligne non appairé est détecté, la console lance `pairComputer()` elle-même et affiche un
  **code de liaison** plein écran (façon appairage d'app TV ; aujourd'hui `pinScreen`, un
  `MessageScreen` de `ConsoleHome`) ; succès → accueil, échec → nouvelle tentative auto après
  5 s. Corrigé au passage le bug "Recherche…" permanent (modèles initialisés après liaison aux
  vues, cf §11) et masqué la toolbar Material de `main.qml` depuis `ConsoleHome` (zéro élément
  bureau). Le direct-launch (§9 6a) est câblé.
- ✅ **Chaîne complète validée en réel contre Apollo** (host « Djinger », juin 2026) :
  découverte → code de liaison saisi une fois → carrousel avec les vraies apps → stream.
  Deux correctifs en route (commits `25c02abb` + `c23148af`) :
  - `AppModel`/`ComputerModel` n'exposent **pas** de `count` en QML (cf §11) → le carrousel
    ne s'affichait jamais (« Chargement… » infini) ; tout passe par le `count` des
    `Instantiator` désormais.
  - au boot, le host passe online **avant** confirmation de son pairState → l'auto-pair
    exige maintenant un état online+non-appairé+connu **stable 2,5 s** (rôle
    `statusUnknown` + timer d'armement), sinon il enverrait un PIN parasite à un host
    déjà appairé.
- ✅ **Profil de stream console** : 1080p / 60 fps / `max(défaut, 30 Mbps)` (cible §7),
  appliqué **au premier démarrage seulement** (marqueur `ConsoleUi/streamProfileInitialized`
  dans la conf) ; ensuite l'écran Paramètres fait foi.
- ✅ **Illusion console complétée** (`ConsoleDialog.qml` + `ConsoleSettings.qml`, ce dernier
  remplacé depuis par le panneau d'options « Ambiant », cf plus bas) :
  - **Y/X interceptés** dans `ConsoleHome` → ouvrent NOS Paramètres (résolution/fréquence/
    débit appliqués immédiatement + « Oublier ce PC ») ; sans ça les événements remontaient
    à `main.qml` qui ouvrait la SettingsView Material. B est consommé à l'accueil.
  - **Conflit « un autre jeu tourne »** : dialog console (Annuler par défaut) puis
    `QuitSegue` upstream réutilisé pour quitter-puis-enchaîner (`nextSession`).
  - **Retour de stream** : `StreamSegue.onDeactivating` ré-affiche la toolbar upstream →
    `ConsoleHome` re-masque le chrome à chaque `StackView.onActivated` (+ refocus carrousel).
  - **Batterie/signal factices retirés** de la StatusBar (remplacés depuis par les vraies
    valeurs, `backend/systemstatus`).
- 🚧 **Couture console ↔ host — `CompanionClient` (2026-06-28)** : backend C++
  `app/gui/console/backend/companionclient.{h,cpp}`, compilé en build **`embedded` seulement**
  (singleton QML `CompanionClient` ; coutures isolées dans `app.pro` + `main.cpp`, build
  vanilla intact). Consomme la **Companion API** du repo HostCompanion
  (`../HostCompanion/docs/protocol.md`). **Tranches 1+2+3 codées ET compilées** (build
  `embedded` Fedora OK le 2026-07-03 — a nécessité `qt6-qtwebsockets-devel` + un fix MOC,
  cf §11 ; submodules déjà checkout) :
  - T1 : découverte mDNS `_hostcompanion._tcp` (calquée sur ComputerManager), `GET /v1/info`
    (pin **TOFU** du SHA-256 du cert), appairage par **code à 6 chiffres** (le HOST l'affiche,
    la console le SAISIT — décision 2026-06-28), token persisté en QSettings.
  - T2 : `GET /v1/library` (+ etag/If-None-Match, copie sur disque), images de fond 16:9
    (`GET /v1/media/{id}/bg`, cache disque), **WebSocket `/v1/events`**
    (reçoit LAUNCH_STATE / UPDATE_REQUIRED / UPDATE_PROGRESS / READY / LAUNCH_ERROR /
    GAME_STARTED / GAME_STOPPED / LIBRARY_UPDATED) avec reconnexion à backoff.
  - T3 : **`CompanionPairing.qml`** (saisie du code 6 chiffres, ←→/↑↓/A) + **`LaunchOverlay.qml`**
    (remplacé depuis par `LaunchScreen.qml`, cf « Refonte Ambiant » plus bas)
    (préparation/maj/erreur) ; `ConsoleHome.launchApp` **recâblé** : `POST /v1/launch` → dialog de
    maj éventuel → `READY` → ALORS `StreamSegue` (mapping app↔gameId par nom). **Repli direct**
    (`directLaunch`) si Companion absent/jeu inconnu. PIN Moonlight **auto-soumis** à Apollo une
    fois le Companion appairé (`submitMoonlightPin` → §6.4), écran de code Moonlight masqué dans
    ce cas. ✅ **Compile + démarre sans erreur QML** (smoke-test offscreen, 2026-07-03) :
    `ConsoleHome` charge, le singleton `CompanionClient` s'enregistre, la découverte mDNS
    `_hostcompanion._tcp` tourne (aucun warning QML issu de `app/gui/console/`). ⚠️ **Reste à
    valider À LA MANETTE contre un HostCompanion réellement en marche** (l'E2E n'a jamais tourné :
    le daemon n'était pas lancé côté PC) : focus manette des overlays, progression de maj,
    mapping app↔gameId, téléchargement des images de fond.
- ✅ **Refonte « Ambiant » (2026-09-30 → 2026-10-01)** — cible : `docs/ui/ambiant/` (brief +
  prototype HTML). Tous les écrans de la console sont refondus :
  - **Accueil** : jetons `Theme.qml` + polices embarquées, fond (`BackdropLayer`), barre haute
    (`StatusBar`), bloc héros, étagère (`GameShelf`), transitions de texte, entrée en cascade,
    assemblés dans `HomeScreen.qml` et branchés dans `ConsoleHome`. Le fond est l'**image 16:9
    du Companion** (média `bg`, cache disque dans `CompanionClient` ; bibliothèque gardée sur
    disque pour l'afficher dès le démarrage), à défaut la jaquette Apollo recadrée ; les
    vignettes gardent la jaquette (les fonds Playnite n'ont souvent pas le logo du jeu).
    L'accueil s'ouvre sur le **dernier jeu lancé** (`ConsoleUi/lastGame`).
  - **Options (Y)** : `OptionsSheet.qml`, panneau latéral qui lit et écrit `StreamingPreferences`
    (résolution, images par seconde, débit, codec, HDR), plus « Sons » (`ConsoleUi/sounds`) et
    « Oublier ce PC » à double confirmation, qui oublie l'appairage Moonlight ET Companion.
  - **Lancement** : `LaunchScreen.qml` (illustration plein écran, étapes, barre). Il vit dans la
    fenêtre, AU-DESSUS de la pile d'écrans : la page `StreamSegue` upstream fait son travail
    dessous, invisible, sans être modifiée. En direct, le flux démarre ~1,1 s après A (le temps
    que l'écran s'ouvre) ; via le Companion, il attend `READY`.
  - **Écrans de message** (absents du prototype, conçus dans son langage) : recherche du PC,
    chargement, liaison Moonlight (code à saisir sur le PC) et liaison Companion (code à saisir
    sur la console) sont des `MessageScreen` posés à la place du héros (`HomeScreen.stage`) ;
    la liaison Companion passe en priorité. Les dialogs (`ConsoleDialog`) sont un panneau
    latéral comme les options.
  - **Sons** : `Sounds.qml` (+ `SoundBank.qml`, QtMultimedia) joue les 9 sons du prototype,
    régénérables par `harness/make-sounds.py`.
  - **Batterie et Wi-Fi** : backend C++ `backend/systemstatus.{h,cpp}` (sysfs + NetworkManager
    par D-Bus), build `embedded` seulement. Éclair pendant la charge, orange sous 20 %.
  `GameCarousel`, `ConsoleSettings`, `LaunchOverlay`, `PairingOverlay` et `Spinner` sont
  supprimés. ✅ Vérifié dans le harnais (`docs/ui/ambiant/harness/`) : accueil et options à moins
  de 1,5 niveau d'écart moyen sur 255 avec les captures du prototype, ressort identique image par
  image, 28 tests QML dont le vrai `ConsoleHome` sur faux modules Moonlight (options, Sons,
  lancement direct, lancement Companion avec mise à jour, annulation, erreur, fond 16:9, saisie
  du code Companion, dernier jeu, oubli du PC). Build `embedded` OK, démarre sans erreur QML.
  ⚠️ **Rien de tout cela n'est encore validé à la manette contre le vrai host**, et les sons
  n'ont pas été écoutés. Restent : filtrage des apps qui ne sont pas des jeux, mesure des 60 fps
  sur la carte.
- **Tâche en cours** : la **validation E2E à la manette** contre le vrai host (Apollo +
  HostCompanion, jamais éprouvé en face), puis le mode kiosk (boot direct, §9 6c) et
  l'auto-accept du pairing côté host (installeur, §9 6b).

---

## 3. Architecture logicielle

L'insight central : **on n'écrit pas deux logiciels de zéro.** ~80 % existe déjà en open
source. Le vrai travail = **intégrer des briques existantes + ajouter une fine couche d'UX
et de packaging** pour supprimer la friction.

### Côté console (CE REPO)
- **Fork de moonlight-qt**, rebrandé, avec une **couche kiosk** : boot direct,
  auto-connexion, masquage de l'appairage, interface Big Picture maison.
- Principe : **« on n'écrit pas le streaming, on l'habille ».** Le décodage, le réseau,
  la manette sont déjà gérés par Moonlight. On retravaille surtout l'**UI** et le
  **comportement de démarrage**.
- OS cible : **Ubuntu Rockchip (Joshua Riek)** ou **Armbian** (kernel mainline,
  Mesa/Panfrost-Panthor pour le GPU, V4L2 pour le décodage), en mode kiosk.
- Compositeur : viser **gamescope** (celui de Valve/SteamOS : scaling, FSR, frame limiting,
  HDR) pour la version commerciale ; **cage** comme repli simple pour le proto.

### Côté PC host (logiciel séparé, à développer plus tard)
- Stack cible : **Apollo** (fork de Sunshine) + **Playnite** (agrège Steam/Epic/GOG/
  émulateurs avec jaquettes) + **PlayNiteWatcher** ou **Vibeshine** (export auto de la
  bibliothèque vers le host + box art) + **Tailscale** (accès distant, traversée du NAT).
- Le « logiciel host » à écrire = un **installeur/orchestrateur** qui pose et configure ces
  outils, tourne en arrière-plan, et gère l'**onboarding zéro-friction + l'auto-appairage**.
- (Setup actuel : le host « Djinger » tourne sous **Apollo** — l'appairage du fork a été
  validé contre Apollo en juin 2026. Sunshine reste compatible, même protocole.)

### Choix de lignée à garder en tête
- **Sunshine + moonlight-qt officiels** = plus stables, plus de plateformes.
- **Apollo + Artemis (Moonlight Noir)** = plus de fonctions de confort.
- Pour un handheld dédié, le compromis recommandé était **Apollo + un fork de moonlight-qt**.
  Ce repo part de moonlight-qt officiel ; rester compatible upstream est prioritaire (§4).

---

## 4. Stratégie de suivi d'upstream — LA convention de code n°1

On veut pouvoir **suivre les commits du repo officiel de moonlight** sans douleur. Donc :

- **Règle d'or : créer des fichiers neufs plutôt que réécrire les fichiers existants.**
  Un fichier neuf ne crée jamais de conflit de merge. Toute l'interface maison vit dans son
  propre dossier isolé : `app/gui/console/`.
- **Ne JAMAIS modifier un fichier upstream**, sauf les rares « coutures » strictement
  nécessaires, qu'on garde minuscules (voir §9).
- **Surtout, ne pas toucher `app/gui/main.qml`.**
- Git :
  - remote `upstream` = `https://github.com/moonlight-stream/moonlight-qt.git`
  - branche `master` = **miroir propre d'upstream** (on n'y code jamais)
  - branche `console-ui` = **tout le travail maison**
  - mise à jour : `git fetch upstream` → fast-forward `master` → `git rebase master` sur
    `console-ui` (historique linéaire, modifs rejouées proprement par-dessus l'officiel).
- Avant d'appliquer des changements : **toujours montrer les diffs.**

---

## 5. L'interface custom (direction artistique validée)

> **Source de vérité de l'UI d'accueil : l'écran « Ambiant »** —
> `docs/ui/ambiant/AMBIANT-BRIEF.md` et `docs/ui/ambiant/ambiant-prototype.html`
> (version n° 2 « Ambiant », touche `2`). En cas de doute, le prototype gagne.
> Accueil, options et lancement sont implémentés (cf §2). Les écrans d'attente,
> d'appairage et les dialogs, absents du prototype, en reprennent le langage :
> `MessageScreen` (même ancrage et même titre que le héros) et `ConsoleDialog` (même
> panneau que les options).

Sombre et immersif, **100 % navigable à la manette**, jamais d'élément "bureau". Choix
esthétiques arrêtés :
- **L'illustration du jeu sélectionné devient le décor** (plein écran, sous un voile de
  lisibilité), le titre prend toute la place en bas à gauche.
- **Étagère de vignettes 16:9** en bas : le jeu sélectionné est calé à gauche, agrandi et
  **souligné d'orange** ; tout le mouvement vient d'un seul ressort.
- **Accent orange chaud** (`#F2802A`) pour le bouton Jouer et le soulignement ; fond noir pur.
- **État de connexion au PC host affiché en permanence** en haut (pastille : point vert + nom
  du host), pour que l'utilisateur voie d'un coup d'œil que tout marche — sans jamais voir
  d'IP ni de réglage réseau.
- **Glyphes manette dans le bloc héros** (A Jouer · Y Options) ; ailleurs, une légende discrète
  en bas à gauche (`ControllerLegend`).
- **Aucune valeur en dur dans les composants** : tout passe par `Theme.qml`, en pixels d'un
  canevas de 800 de haut que `HomeScreen` met à l'échelle de l'écran.

Fichiers (dans `app/gui/console/`) :
- `ConsoleHome.qml` — l'écran d'accueil côté logique (hosts, appairage, lancement, overlays)
- `HomeScreen.qml` — l'écran d'accueil côté présentation : assemble fond, barre haute, héros,
  étagère et panneau d'options ; règle l'entrée en cascade, la dérive du fond, l'effacement au
  lancement. `stage` reçoit les écrans de message (`staged` efface héros et étagère et leur
  donne la manette)
- `OptionsSheet.qml` — panneau « Options du flux » (bouton Y), sans état propre
- `LaunchScreen.qml` — écran de lancement d'un jeu (remplace l'ancien `LaunchOverlay`)
- `Sounds.qml`, `SoundBank.qml`, `sounds/` — sons de l'interface (singleton `Sounds.play("move")`)
- `PadRepeat.qml` — répétition des flèches à l'appui prolongé (étagère, options)
- `Theme.qml` (+ `qmldir`) — singleton des jetons de design : couleurs, tailles, durées, ressort
- `fonts/` — Sora et JetBrains Mono embarquées (OFL), chargées par `Theme.qml`
- `BackdropLayer.qml` — fond en fondu croisé (deux calques) + voile + dérive lente
- `HeroBlock.qml` — méta, titre, sous-titre, boutons Jouer / Options
- `GameShelf.qml` — l'étagère de vignettes, son ressort, la répétition manette
- `SwapBox.qml`, `Appear.qml`, `ButtonGlyph.qml` — remplacement de texte en glissant,
  apparition en fondu-glissé, glyphe de bouton
- `Format.js` — mise en forme des données Companion (source, dernière session, temps de jeu)
- `StatusBar.qml` — barre haute : pastille de l'hôte + horloge / Wi-Fi / batterie (éclair en
  charge, orange sous `Theme.batteryLow`)
- `ControllerLegend.qml` — légende des boutons (glyphe + libellé), panneaux et écrans de message
- `MessageScreen.qml` — écran de message à la place du héros : titre, texte, code en grandes
  cases, ligne d'état, piste d'attente. Sert à la recherche du PC, au chargement et à la
  liaison Moonlight (code à saisir sur le PC), instanciés dans `ConsoleHome`
- `ConsoleDialog.qml` — confirmation dans un panneau latéral (Annuler par défaut ; A/B, flèches)
- `CompanionPairing.qml` — saisie du code d'appairage Companion à 6 chiffres (host→console),
  sur un `MessageScreen`
- `backend/companionclient.{h,cpp}` — pont C++ vers le HostCompanion (Companion API). Build
  `embedded` uniquement. Découverte mDNS, appairage 6 chiffres, bibliothèque (copie disque),
  images de fond 16:9 en cache disque (`games()[i].background`, URL `file://` : l'`Image` QML
  ne sait pas poser le Bearer), WebSocket events (cf §2). Nécessite `QT += websockets`.
- `backend/systemstatus.{h,cpp}` — batterie et charge (`/sys/class/power_supply`) et force du
  signal Wi-Fi (NetworkManager par D-Bus) pour la barre haute. Build `embedded` uniquement ;
  `QT += dbus`.

`ConsoleHome.qml` est **branché sur le vrai backend Moonlight** (imports
`ComputerModel`/`AppModel`/`ComputerManager`/`StreamingPreferences`/`CompanionClient`). Tout
le reste est de la présentation pure, sans dépendance Moonlight. Les deux se testent hors de
l'application dans le harnais `docs/ui/ambiant/harness/` (cf §11) : `HomeScreen` avec des jeux
de démo, et le vrai `ConsoleHome` sur de faux modules Moonlight (`stubs/`).

---

## 6. Matériel

### Carte de développement : **Orange Pi 5B** (RK3588S), 8 Go / 64 Go eMMC (~106 €)
Choisie pour : décodage matériel H.264/HEVC/**AV1**, GPU Mali-G610 (Panthor/Panfrost),
**Wi-Fi 6 + BT 5.0 intégrés**, alim **USB-C 5V** (idéal handheld), eMMC soudée (boot fiable).
C'est une carte de **dev** : elle sert à valider RK3588S + le logiciel. Le produit final
sera un **SoM RK3588S** ou une **carte porteuse custom** autour de ce SoC.

### BOM du prototype (~270–300 €)
- Refroidissement actif (dissipateur + ventilo) — **obligatoire**, le RK3588S throttle sinon.
- Écran : démarrer en **HDMI IPS 5,5–6"** (marche tout seul) ; viser **MIPI-DSI** ensuite
  (le DSI sur Orange Pi est le **risque n°1** : panneau supporté dans le device-tree requis).
  Une dalle **AMOLED 7" 165 Hz MIPI** est envisagée (nécessite sa driver board).
- Contrôles : **RP2040 (Pi Pico) + firmware GP2040-CE** → manette USB-HID ;
  **joysticks à effet Hall** (anti-drift), D-pad, ABXY, gâchettes.
- Alim : **power bank USB-C PD 5V/3A+** pour le proto ; batterie custom (2× 18650 + boost
  type IP5389 5V/5A) seulement en v2.
- Wi-Fi : intégré pour commencer ; comparer avec un **dongle Wi-Fi 6 USB3 MediaTek**
  (mt7921/mt7925) si la latence déçoit.

### 5G (le « boss de fin », plus tard)
Module **Quectel RM520N-GL** (M.2, 5G Sub-6, Rel.16, bandes globales = OK France).
À écarter : RM530N-GL (certifié T-Mobile only), RM502Q-AE (fin de vie). Nécessite carte
porteuse + antennes + slot SIM. Le mur n'est pas le débit mais **latence + gigue + NAT**
(Tailscale gère le NAT).

---

## 7. Contraintes & décisions structurantes

- **Licence GPLv3** : Moonlight/Sunshine/Apollo sont en GPLv3. Toute modif distribuée doit
  être **publiée sous GPL avec les sources**. Le modèle « logiciel propriétaire fermé » est
  **impossible** ; le business viable = **hardware + service**.
- **Abstraire décodage / affichage / entrées** (V4L2 / DRM / SDL) et ne pas coupler au
  matériel en dur : on changera de SoC (dev → produit) presque sans douleur.
- **Certification radio CE/FCC** obligatoire dès qu'un produit vendu embarque Wi-Fi/5G.
- **Le Wi-Fi compte plus que le CPU** pour l'expérience de streaming. Viser ~30–50 Mbps
  *stables* à faible gigue en 1080p60.
- **Latence** ~20–60 ms : excellente pour les AAA solo, dépendante du réseau pour le FPS
  compétitif. Rester honnête là-dessus dans le positionnement.

---

## 8. Roadmap

1. ✅ Valider le concept de streaming (fait, depuis 1 an).
2. ✅ Forker + compiler moonlight-qt, décodage matériel OK.
3. ✅ Concevoir l'UI Big Picture (4 fichiers QML autonomes).
4. ✅ Intégrer l'UI dans le build derrière le flag `embedded` (commit `64bb96a0`).
5. ✅ Brancher l'UI sur les vraies données Moonlight (commits `e0f7600c` + `5df70d84`).
5b. ✅ Refonte « Ambiant » (accueil avec fonds 16:9 du Companion, options Y, écran de
    lancement, écrans de recherche / liaison / dialogs, sons, batterie / Wi-Fi), cf §2 —
    vérifiée dans le harnais, **pas encore à la manette contre le vrai host**.
6. ⏳ **Mode kiosk + auto-appairage** (§9) — côté console : TERMINÉ (6a direct-launch,
   appairage auto avec code de liaison, options/dialogs console, chrome upstream
   masqué). Reste 6c (compositeur kiosk, lié au proto) et l'auto-accept côté host
   pour rendre le code invisible (lié à l'installeur, étape 8).
7. ⏳ Monter le proto hardware (Orange Pi 5B + écran + manette + power bank) —
   **carte commandée en juin 2026**. Premier objectif à réception : valider le décodage
   matériel 1080p60 (V4L2/FFmpeg sur RK3588S, kernel mainline + Panthor) — c'est LE
   risque technique restant du projet.
8. Installeur host 1-clic (Apollo/Sunshine + Playnite + Tailscale + Wake-on-LAN).
9. Version compacte v2 (SoM/carte custom, batterie, coque 3D).
10. Module 5G.

---

## 9. Tâche immédiate

La couche logicielle console est **fonctionnelle de bout en bout** (découverte →
appairage auto → accueil « Ambiant » → écran de lancement → stream → retour à l'accueil,
options au bouton Y).
Historique du découpage : 6a (direct-launch) ✅, 6b côté console (code de liaison,
aucun dialog upstream) ✅, 6c (kiosk) ⏳ hors repo.

> ⚠️ **Important** : historiquement ce « bout en bout » passait par **Apollo en DIRECT**
> (`ConsoleHome.launchApp` → `StreamSegue`), chemin proscrit par le repo host
> (`../HostCompanion/CLAUDE.md §4`). **La tranche 3 de `CompanionClient` a recâblé ce lancement**
> (cf §2) : quand le Companion est appairé+connecté, Play fait `POST /v1/launch` → `READY` →
> `StreamSegue` (et gère « maj AVANT stream »). Le lancement direct reste le **repli** si le
> Companion est absent (même fonction `launchApp`). ✅ T3 **compile et démarre** (2026-07-03)
> mais l'E2E n'a **jamais tourné contre un
> HostCompanion en marche** — tant que ce n'est pas vérifié à la manette, considérer le chemin
> Companion comme fonctionnel-mais-non-éprouvé.

Fronts ouverts, par priorité :

### A — Tests utilisateur de la couche console (en cours)
À valider à la manette par Marco, contre le vrai host : l'accueil « Ambiant » (navigation,
maintien des flèches, changement de jeu, fonds 16:9 du Companion, ouverture sur le dernier
jeu), le panneau d'options (réglages bien écrits et conservés, « Sons », « Oublier ce PC » qui
doit aussi faire réapparaître la liaison Companion), l'écran de lancement jusqu'au flux puis le
retour, le dialog « un jeu tourne déjà », les écrans de recherche et de liaison (saisie du code
Companion à la manette), les sons, les icônes batterie (charge, batterie faible) / Wi-Fi, B
inerte à l'accueil. Corriger ici ce qui coince.

### B — 6c : boot direct via compositeur kiosk (à l'arrivée de l'Orange Pi)
Hors de ce repo : configurer **cage** (proto) ou **gamescope** (cible commerciale) pour
lancer `moonlight` au boot, sans session KDE/GNOME, sans curseur souris. Testable dès
maintenant sur le laptop Fedora (`cage -- ./app/moonlight`) ; à documenter en §11.
À réception de la carte : valider d'abord le **décodage matériel** (cf roadmap 7).

### C — Suites de la refonte « Ambiant »
Filtrage des apps qui ne sont pas des jeux, mesure des 60 fps sur la carte. (Faits : batterie
et Wi-Fi, fonds 16:9 du Companion, dernier jeu, réglage Sons, écrans d'attente / appairage /
dialogs.) À valider contre le vrai HostCompanion : le téléchargement des fonds (`/v1/media/{id}/bg`
n'a jamais été appelé en réel).

### D — Auto-accept du pairing côté host (avec l'installeur, étape 8)
Pré-injecter l'identité/certificat de la console dans la conf d'Apollo (ou auto-accept),
pour que l'écran de code Moonlight (`pinScreen` de `ConsoleHome`) ne s'affiche jamais en
usage normal.

Contraintes (rappel §4) : tout le code console reste dans `app/gui/console/`. Aucun
fichier upstream touché. Build vanilla inchangé.

Vérification finale inchangée : sur un proto avec host paired, allumer la console doit
afficher l'accueil en moins de 5 s sans aucun élément Linux visible — et un jeu doit
pouvoir démarrer en une pression du bouton A.

---

## 10. Conventions de travail

- **Répondre en français.**
- **Toujours montrer les diffs** avant d'appliquer des changements.
- Garder les modifs **additives et isolées** ; préserver la compatibilité upstream (§4).
- En cas de doute sur un fichier upstream, demander plutôt que réécrire.

---

## 11. Notes de build durables

Pièges et conventions de build qui reviennent souvent — à garder sous la main.

### Comment compiler en mode `embedded` (UI maison)

```bash
qmake6 "CONFIG+=embedded" moonlight-qt.pro && make release -j$(nproc) && ./app/moonlight
```

L'app doit démarrer directement sur `ConsoleHome`. Un `qmake6` sans `embedded` doit
produire le Moonlight vanilla intact.

### Dépendance de build `embedded` : QtWebSockets

Le build `embedded` ajoute `QT += websockets` (WebSocket `/v1/events` du `CompanionClient`).
Sur Fedora, installer **`qt6-qtwebsockets-devel`** (`sudo dnf install -y qt6-qtwebsockets-devel`).
La lib runtime seule (`qt6-qtwebsockets`) ne suffit pas : sans le `-devel` il manque les
en-têtes, le symlink `libQt6WebSockets.so` et le module qmake `qt_lib_websockets.pri`, et
`qmake6` échoue (`Unknown module(s) in QT: websockets`). Le build vanilla n'en a pas besoin
(module dans le scope `embedded` uniquement).

### Piège MOC : les types d'arguments de slots/signaux doivent être COMPLETS (Qt6)

En Qt6, le MOC génère un `QMetaType` pour chaque type d'argument de signal/slot. Un type
seulement **forward-déclaré** (`class Foo;`) qui apparaît dans une signature — même en
`const QList<Foo>&` — fait échouer `moc_*.cpp` : `invalid use of incomplete type 'class Foo'`
(+ erreurs `has_ostream_operator<QDebug, Foo, void>`). Vécu au premier build de `CompanionClient`
sur `onSslErrors(QNetworkReply*, const QList<QSslError>&)` : il a fallu **`#include <QSslError>`**
dans le header au lieu du forward-declare. Règle : tout type figurant dans une signature d'un
`Q_OBJECT` doit être inclus complètement dans le header (seuls les pointeurs `Foo*` tolèrent le
forward-declare).

### Piège qmake `subdirs` (à connaître)

Si un précédent `qmake6` (sans `embedded`) a déjà généré les Makefiles des sous-projets,
relancer `qmake6 "CONFIG+=embedded" moonlight-qt.pro` au niveau racine **ne régénère pas**
les sous-Makefiles — le scope `embedded { ... }` reste inactif et `CONSOLE_UI` n'est pas
défini.

Symptômes : pas de `Project MESSAGE: Embedded build` au qmake, pas de `-DCONSOLE_UI` dans
la ligne `g++ -c ... main.cpp`, l'app démarre sur `PcView` malgré tout.

Deux contournements :
- `make distclean` avant le `qmake6` racine (propre mais recompile tout) ;
- ou régénérer directement le Makefile du sous-projet : `cd app && qmake6 "CONFIG+=embedded" app.pro`
  (rapide, recompile uniquement ce qui dépend du nouveau define).

### Piège ComputerModel/AppModel : initialiser AVANT d'assigner aux vues

`ComputerModel::initialize()` et `AppModel::initialize()` remplissent le modèle **sans
émettre de reset** (`beginResetModel`). Si une vue (ListView, Instantiator…) est liée au
modèle avant l'appel à `initialize()`, elle le considère **vide pour toujours** — symptôme :
« Recherche… » permanent alors que le host est en ligne. Le pattern correct (celui de
`PcView.qml` et de `ConsoleHome.qml`) :

```qml
var m = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
m.initialize(ComputerManager)   // d'abord initialiser…
computerModel = m               // …puis assigner la propriété liée aux vues
```

### Piège AppModel/ComputerModel : pas de propriété `count` en QML

Ces modèles C++ (QAbstractListModel) n'exposent **pas** de `count` : en QML,
`appModel.count` vaut `undefined`, donc `appModel.count > 0` est **toujours faux**
(symptôme : « Chargement de vos jeux… » infini alors que les données sont là).
Pour compter/observer les éléments, passer par un `Instantiator` lié au modèle et
utiliser **son** `count` (vraie propriété notifiée) — pattern des `hostScanner` /
`appViewer` de `ConsoleHome.qml`.

### Propriétés attachées : l'import compte

`StackView.onActivated` & co exigent `import QtQuick.Controls` dans le fichier qui les
utilise. Sans lui : « Non-existent attached object » au push, et la vue ne charge pas.

### Logs Qt invisibles sur Fedora (journald)

Quand stderr n'est pas un TTY, Qt envoie ses logs vers **journald** au lieu de la console
(`qml-qt6` n'affiche alors rien) → les lire avec `journalctl --user`. Le binaire
`moonlight` n'est pas concerné : il installe son propre handler (`qtLogToDiskHandler`)
qui écrit sur stdout. Attention : ce handler **supprime le niveau debug** (`console.log`
QML) — utiliser `console.info` pour qu'une trace QML apparaisse dans le log.

### rcc ne dépend que de `qml.qrc`, pas des `.qml`

Modifier un `.qml` ne suffit pas toujours à régénérer `qrc_qml.cpp` : faire
`touch qml.qrc` avant `make` pour forcer le réembarquement des ressources.

### Harnais « Ambiant » : voir et vérifier l'UI sans PC hôte

Tout est dans `docs/ui/ambiant/harness/` (hors de `app/`, rien n'entre dans le build) :

```bash
cd docs/ui/ambiant/harness
qml-qt6 -I stubs Harness.qml -- view=HomeDemo          # l'accueil, 10 jeux de démo, au clavier
qml-qt6 -I stubs Harness.qml -- view=ConsoleHomeDemo   # le vrai ConsoleHome sur faux modules
qml-qt6 Harness.qml -- view=PagesDemo page=code        # search|loading|pin|pin-error|code|code-busy|code-error|dialog
./shot.sh /tmp/a.png view=HomeDemo focus=6 drift=0 delay=2500   # capture (rendu GPU, sans fenêtre)
./compare.py /tmp/a.png ../ref/home-6-rdr2.png -o /tmp/diff.png # écart avec le prototype
./shot.sh /tmp/b.png view=HomeDemo do=options,down at=2500 delay=3700   # idem, après des actions
./ref-capture.py                                       # régénère ../ref/ et art/ depuis le prototype
./make-sounds.py                                       # régénère app/gui/console/sounds/*.wav
QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -import stubs -input tst_GameShelf.qml   # idem tst_Format, tst_ConsoleHome
```

- `shot.sh` lance un **mutter headless** le temps de la capture : `QT_QPA_PLATFORM=offscreen`
  ne sait rendre qu'en logiciel (petits tracés approximatifs, pas de `MultiEffect`).
- `ref-capture.py` pilote **Brave** par le protocole DevTools (module Python `websockets`) :
  son option `--screenshot` ne rend jamais la main. Le mode plein écran du prototype (touche
  `F`) donne un écran noir, la capture ne l'utilise pas.
- `tst_GameShelf::test_springMatchesPrototype` mesure le temps réel : il peut échouer au premier
  lancement « à froid » (écart 0,0828, vu 2 fois sur 23) ; relancer avant de chercher plus loin.

### Dépendances d'exécution de l'UI console

- **QtMultimedia** (module QML) pour les sons : `qt6-qtmultimedia` sur Fedora,
  `qml6-module-qtmultimedia` sur Debian/Ubuntu. Absent, l'interface marche sans son
  (`Sounds.qml` charge `SoundBank.qml` à part). Il faut un serveur de son (PipeWire/PulseAudio)
  pour que ces sons cohabitent avec l'audio du flux.
- **NetworkManager** pour l'icône Wi-Fi ; sans lui (ou sans Wi-Fi associé) l'icône est masquée.
- Une batterie système dans `/sys/class/power_supply` pour l'icône batterie ; sinon masquée
  (ce sera le cas du proto sur power bank). Relue toutes les 10 s (l'éclair de charge peut
  mettre ce temps à apparaître).
- Cache du Companion : `QStandardPaths::CacheLocation` + `/companion/` (sous Linux
  `~/.cache/Moonlight Game Streaming Project/Moonlight/companion/`) : `library.json` (dernière
  bibliothèque) et `bg-<sha1>` (images de fond). Il ne fait que grandir : à purger s'il pèse trop.

### Pièges QML rencontrés pendant la refonte

- Une propriété ne peut pas s'appeler `on<Majuscule>…` (prise pour un gestionnaire de signal) :
  le jeton `onAccent` du brief s'appelle `Theme.inkOnAccent`.
- `Rectangle.border.width` est **arrondi à l'entier** (1,5 → 2) sauf `border.pixelAligned: false`.
- `ListView.count` n'est mis à jour qu'à la mise en page suivante ; et il vaut 0 tant que le
  modèle charge : ne jamais y borner la sélection sans tester `count > 0`.
- Un composant en ligne (`component X: …`) voit les `id` du fichier tant qu'il y est instancié.
- Un `State` à `when:` joue sa transition **dès la création** de l'élément s'il est déjà vrai :
  les vignettes créées en défilant rejouaient leur entrée (cf. `Appear.animateInitially`).
- Relancer une animation depuis un `onXChanged` alors que sa cible (`to:`) est liée à la même
  propriété : l'ordre n'est pas garanti, l'animation peut partir avec l'ancienne cible. Poser
  `to` dans le gestionnaire (cf. `LaunchScreen.advanceBar`).
- `QT_QPA_PLATFORM=offscreen unshare -rn ./app/moonlight` : test de fumée sans réseau (aucun
  risque d'appairage ou de lancement sur le vrai PC) ; le bus D-Bus système y est injoignable.
  Rediriger la sortie vers un fichier (`> log 2>&1`) : à travers un pipe, rien n'apparaît.
- Dans `HomeScreen`, le focus suit des **liaisons** (`focus: !staged && !sheet.opened` sur
  l'étagère, `staged && !sheet.opened` sur `stage`) : il revient tout seul à la fermeture du
  panneau d'options ou d'un écran de message. Ne pas rappeler `shelf.forceActiveFocus()` en dur.

### Ignorer les artefacts de build sans toucher au `.gitignore` upstream

Le `.gitignore` upstream ne couvre pas les builds in-source de qmake (`Makefile*`,
`release/`, `*.o`, `*.a`, `.qmake.*`, `app/moonlight`, `config.log`…). Plutôt que de le
modifier (cf §4), on les ignore **localement à ce clone** via `.git/info/exclude` — fichier
non versionné, donc à **recréer après un `git clone`**. Contenu :

```
# qmake / make in-source build artifacts
Makefile
Makefile.Debug
Makefile.Release
release/
debug/
.qmake.cache
.qmake.stash

# Object files & static libs
*.o
*.a

# Build outputs / logs
config.log
app/moonlight
config.tests/*/EGL
```
