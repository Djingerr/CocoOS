# Historique détaillé du projet (ex-§2 de CLAUDE.md)

> Déplacé hors de `CLAUDE.md` pour ne pas être rechargé à chaque tour de Claude Code.
> À lire quand on a besoin du *pourquoi* d'un choix passé ou du détail d'un commit.
> Contenu repris tel quel ; les renvois « §N » visent `CLAUDE.md`, sauf §5/§11 → skills
> (`cocoos-ui`, `cocoos-build`…), voir l'index en tête de `CLAUDE.md`.

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
    « Oublier ce PC » à appui maintenu (étape 7 des micro-interactions), qui oublie l'appairage Moonlight ET Companion.
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
  n'ont pas été écoutés. Reste : mesure des 60 fps sur la carte.
- ✅ **Fonctions « console » (2026-10-02)** — série de points validés avec Marco, un commit chacun :
  - **Étagère** (`Library.js`, testé par `tst_Library`) : les utilitaires d'Apollo / Sunshine
    (Desktop, Steam Big Picture, Virtual Display, Playnite…) sont écartés tant qu'il reste un jeu ;
    ordre = favoris (X épingle / désépingle, le dernier épinglé en tête), puis du plus récent au
    plus ancien (lancé d'ici, ou joué sur le PC d'après le Companion), puis par nom. Les index de
    l'étagère ne sont PAS ceux d'`AppModel` (`shelfModel`, rôle `appIndex`). Jeu sans jaquette :
    son nom sur un dégradé ; jaquette en fondu. Toast (`Toast.qml`) repris du prototype.
  - **Réveil du PC** (Wake-on-LAN, `ComputerModel.wakeComputer`, rien d'upstream modifié) : PC
    connu (MAC) mais hors ligne → réveil d'office 4 s après le démarrage ; A sur un jeu → étape
    « Réveil de … » en tête de l'écran de lancement, qui reprend seul quand le PC répond (en
    laissant 8 s au Companion pour se reconnecter) ; écran de recherche → A Réveiller / Réessayer.
    Abandon au bout de 90 s avec un message (Wake-on-LAN à activer dans le BIOS).
  - **Veille de l'écran** : remplacée le 2026-10-27 par l'écran de veille « Premium » (cf. plus bas).
  - **Bouton Home** (`InputStatus`) : à l'accueil, ouvre le menu Home (`ConsoleDialog` en mode
    `actions`) : reprendre / quitter le jeu en cours (quitter sans `QuitSegue`, pas de page
    upstream), mettre en veille, redémarrer, éteindre (ces deux derniers confirmés, A maintenu). En jeu,
    voir « Menu en jeu » plus bas. Au clavier : touche Origine.
  - **Menu en jeu** (`backend/streammenu`, 2026-10-02) : en jeu, Home ouvre par-dessus le flux
    un panneau (même dessin que `ConsoleDialog`, refait en QPainter par `streampainter` : le flux
    est affiché par SDL, Qt est suspendu) posé sur l'overlay de débogage de Moonlight. Fond :
    l'image du jeu floutée et figée (le jeu continue sur le PC), un voile en attendant. Reprendre,
    Statistiques du flux, Retour à l'accueil, Quitter le jeu, veille / redémarrer / éteindre
    (confirmés dans le menu) ; l'accueil fait la suite au retour (`InputStatus.takeStreamExit`).
    Menu ouvert, la manette (croix, stick gauche, A au relâché, B) le pilote, le PC la voit
    relâchée. **Statistiques** en haut à gauche, en Sora et en français (définition, i/s, codec,
    débit, latence réseau ± variance avec le point de qualité de l'accueil, pertes, temps de
    décodage / affichage / PC), réglage `ConsoleUi/streamStats`, aussi par Select + L1 + R1 + X.
    **Animations et sons** comme à l'accueil (mêmes durées et courbes que `ConsoleDialog` /
    `OptionsSheet`) : le panneau glisse (440 ms), le fond flouté apparaît en fondu (320 ms), le
    surlignage glisse (220 ms), les libellés changent de couleur (160 ms), la valeur « Affichées /
    Masquées » glisse comme une `SwapBox`, la confirmation remplace la liste en fondu enchaîné,
    les statistiques apparaissent en fondu. Un minuteur SDL redessine l'overlay toutes les 16 ms,
    seulement pendant une transition, hors du verrou et directement dans la surface SDL (à
    2560 × 1600 sur le laptop : ≈ 6 ms image posée, 9 à 14 ms en fondu). **Piège** : Moonlight ne
    compose un overlay qu'en affichant une image du flux, et le PC n'en envoie presque plus quand
    son écran ne bouge pas (bureau : 18 i/s en moyenne) ; le menu ramait. Sans image reçue depuis
    20 ms, le minuteur réveille donc le décodeur (`LiWakeWaitForVideoFrame`), qui réaffiche une
    copie de la dernière image (`StreamMenu::frameToRepeat`). Sons open / close /
    move / edge / select / tick joués par SDL (QtMultimedia ne tourne pas pendant un flux), au
    volume de `Theme.soundVolume`, coupés avec le réglage « Sons ». Croix ou stick tenus :
    la liste défile avec la répétition de l'accueil (`Theme.repeat*`), arrêtée au bout.
  - **Rideau CocoOS entre un jeu et l'accueil** (`StreamCurtain.qml`) : StreamSegue cache la
    fenêtre Qt pendant le flux et ne la réaffiche qu'après avoir fermé celle du flux : entre les
    deux, on voyait le bureau (noir sur la console). Désormais le rideau (noir) couvre l'accueil
    dès le début du flux ; quand on quitte par le menu en jeu, l'overlay fond au noir, puis
    `StreamMenu::finishLeave` réaffiche la fenêtre Qt et fait tourner Qt le temps qu'elle montre
    une image et que le logo y ait paru (≥ 320 ms) avant de fermer le flux : plus de trou. Dès que
    la fenêtre revient, le logo de l'animation de démarrage paraît sur le noir ; au retour sur
    l'accueil s'y ajoute « Fermeture de … » (le O respire jusqu'à la réponse du PC), puis le rideau
    se lève et l'accueil rentre (`entryAllowed`). Il garde la manette tant qu'il couvre. La
    toolbar Material (bande bleue en haut du rideau, ré-affichée par `StreamSegue` en se dépilant)
    est détachée de la fenêtre (`header = null`), plus seulement cachée.
    Les autres fins de flux (connexion perdue, Start + Select + L1 + R1, Ctrl+Alt+Maj+Q, fenêtre
    fermée) passent par le même chemin depuis le 2026-10-23 : `session.cpp` confie chaque
    `SDL_QUIT` à `StreamMenu::interceptQuit`, qui fait le fondu au noir et `finishLeave` (sortie
    vide pour l'accueil : le rideau se lève aussitôt), puis laisse passer le `SDL_QUIT` qu'il
    pousse. Connexion perdue : plus d'image du PC, le fondu ne paraît pas toujours, mais la
    fenêtre de l'accueil revient avant que celle du flux se ferme (plus de trou).
    **Au lancement** aussi (2026-10-23) : `StreamSegue` cachait la fenêtre Qt dès
    `connectionStarted`, avant que celle du flux n'existe (bureau visible). `ConsoleHome
    .keepHomeUnderStream`, branché avant lui, le débranche (Qt saute un gestionnaire débranché
    pendant l'émission) : la fenêtre reste, rideau et logo, sous celle du flux, **tout le
    flux** (au retour, le flux se ferme sur elle : aucun trou, vu par Marco). Journal :
    « [console-ui] Lancement : fenêtre de l'accueil gardée sous le flux ». Sous KDE, il reste
    ~0,2 s d'animation à l'ouverture : effets KWin « Échelle » (scale, toute fenêtre qui
    s'ouvre) et « Plein écran » (Moonlight crée sa fenêtre puis la passe en plein écran) ;
    rien de tel sous cage / gamescope. **Piège** : un `SDL_QUIT`
    resté dans la file après le flux est pris par `SdlGamepadKeyNavigation` pour « quitter
    l'application » (CocoOS se fermait après « Quitter » maintenu : le départ repartait une 2ᵉ
    fois) ; `interceptQuit` vide la file des `SDL_QUIT` quand il laisse passer le sien.
    ⚠️ Le menu a été vu dans un vrai flux par Marco, mais pas encore ses animations ni ses sons.
    Le flou sur l'Orange Pi est incertain (images AFBC du décodeur Rockchip) : si la copie échoue,
    le voile reste. Cadence des animations sur la carte à mesurer (objectif 60 i/s).
  - **Manettes** : les glyphes suivent la manette branchée (`Theme.buttonLayout`, réglage
    `ConsoleUi/buttonLayout` = auto par défaut) : lettres Xbox, lettres inversées Nintendo
    (Moonlight lit les boutons par position), ✕ ○ □ △ PlayStation. Batterie d'une manette sans
    fil dans la barre haute (silhouette + trois barres, orange à une barre).
  - **Qualité du réseau** : `SystemStatus.probeHost` chronomètre toutes les 3 s l'ouverture d'une
    connexion TCP vers le port HTTP Moonlight du PC (un aller-retour), seulement accueil à
    l'écran et PC en ligne ; latence = médiane des 8 dernières, gigue = écart moyen entre
    mesures. La pastille affiche « N ms » et son point passe au vert / jaune / rouge
    (`Format.networkQuality` : ≤ 20 ms et ≤ 5 ms de gigue, ≤ 50 et ≤ 15, au-delà).
    ⚠️ Jamais mesuré contre le vrai PC.
  - **Réglages de flux par jeu** (`ConsoleUi/gameProfiles`, JSON par nom) : en tête de l'onglet
    Flux, une ligne au nom du jeu sélectionné passe de « Réglages communs » à « Réglages à
    part » (copie des communs) ; les lignes suivantes règlent alors ce jeu. Au lancement, ses
    réglages remplacent les communs dans `StreamingPreferences` sans `save()`, et `endLaunch`
    remet les communs (la session ne réenregistre jamais les préférences).
  - **Options en onglets** (L1 / R1, lus dans SDL par `InputStatus` ; PageUp / PageDown au
    clavier) : **Flux** (résolution, fréquence, débit, codec, HDR, Oublier ce PC) et **Console**
    (luminosité par logind `SetBrightness`, volume par `wpctl`, mise en veille après, boutons,
    sons, langue, Wi-Fi). Une ligne peut être une action (`action: true`, A la déclenche, chevron ›).
  - **Wi-Fi et premier démarrage** : `WifiSetup` (NetworkManager par D-Bus) liste les réseaux
    et s'y connecte ; la liste est un `OptionsSheet` (titre « Wi-Fi », icône de signal), le mot
    de passe se tape sur `OnScreenKeyboard` (AZERTY, quatre couches, A / B / X / Y ; un vrai
    clavier marche aussi). Premier démarrage (`ConsoleUi/setupDone`) : « Bienvenue » (A), puis
    « Connexion à Internet » si la console n'est pas en ligne, puis le flux habituel (recherche
    du PC, liaisons). ⚠️ La connexion à un réseau n'a jamais été essayée en vrai (la lecture
    des réseaux, si : vérifiée contre le NetworkManager du laptop).
  - **Teinte ambiante** : `AmbientColor` tire de l'image de fond (miniature décodée hors du fil
    principal, cache) la teinte qui pèse le plus, pondérée par la saturation, rendue vive ; elle
    colore le bas du voile (fondu de 700 ms). Image grise : pas de teinte.
    Le bouton Jouer reste orange (la marque).
  - **Lancement depuis la vignette** : l'écran de lancement part de la place de la vignette
    active (`HomeScreen.activeThumbRect`, sa jaquette) et grandit jusqu'au plein écran (ressort
    « souple » étiré à 540 ms, comme le prototype des micro-interactions) pendant que
    l'illustration la remplace en fondu ; annulé (B, erreur), il y retourne (420 ms après 90,
    la jaquette revient). Reprise depuis le menu Home : le fondu d'origine.
  - **Logo du jeu** à la place du titre : média `logo` du Companion (PNG d'« Extra Metadata
    Loader », côté HostCompanion), mis en cache comme les fonds (`games()[i].logo`) ; le héros
    l'affiche une fois chargé (deux lignes de titre de haut au plus), le titre en texte sinon.
    ⚠️ Côté host, écrit mais pas compilé (pas de .NET sur le laptop).
  - **Démarrage** : animation « le O » (`BootSplash`, cf. `docs/boot-animation/`) : tracé du O,
    lettres sur ressorts, chargeur si le système tarde, vol du logo jusqu'à celui de la barre
    haute (relais au pixel près) pendant que l'accueil entre (spec §7 : textes en fondu 350 ms,
    vignettes en fondu + échelle 0,97 → 1 sur 500 ms, glyphes du héros à 300 ms). Sortie de
    veille (écran ou suspension logind) : l'accueil rentre, le O du logo de la barre respire.
    Thème Plymouth en noir pur dans `deploy/plymouth/` (notice, ligne de commande du noyau).
    ⚠️ Plymouth jamais installé ni vu en vrai (à faire sur l'Orange Pi, pas sur le laptop).
- ✅ **Langue FR / EN (2026-10-06)** : ligne « Langue » de l'onglet Console. Elle écrit le réglage
  de Moonlight (`StreamingPreferences.language`) et appelle son `retranslate()` : rien d'upstream
  modifié. Les textes console (sources en français, `qsTr` / `tr`) ont leur traduction anglaise dans
  `languages/qml_en.ts`, compilée en `qml_en.qm` et embarquée en `:/languages/qml_en.qm`, là où
  Moonlight la cherche (au démarrage, puis à chaque changement). Français : la traduction upstream
  `qml_fr` (textes Moonlight). « Auto » (jamais choisie) suit le système : anglais si `en_*`.
  En anglais : clavier à l'écran en QWERTY, nombres à la virgule → point (tailles, statistiques).
  Les messages d'erreur envoyés par le HostCompanion restent dans la langue du host.
  ⚠️ Vue dans le harnais et au démarrage (traduction chargée), pas encore à la manette.
- ✅ **Micro-interactions (2026-10-22 → 2026-10-23)** — cible : `docs/ui/micro-interactions/` (brief +
  prototype ; pour les durées et les courbes, le prototype fait foi). Huit étapes, un commit chacune,
  toutes faites et vérifiées dans le harnais :
  - **Ressorts physiques** (`Spring.js`) : `spring()` du prototype converti en courbe
    `Easing.BezierSpline` de 10 segments (le maximum que Qt garde), jouée par une simple
    `NumberAnimation` ; jetons `Theme.springSnappy` / `springBouncy` / `springGentle`
    (`{ curve, duration }`). Testé par `tst_Spring` contre les valeurs tirées du prototype
    (`reference-values.js`) et tel que Qt le joue : moins de 1 % d'écart.
  - **Étape 1, appui** (`Pressable.qml`) : A enfoncé, l'élément s'écrase (0,955 en 90 ms ;
    0,985 pour une ligne de panneau) ; relâché, il revient avec le ressort « rebond », et
    l'action part. **A agit désormais au relâché** sur l'étagère, dans `OptionsSheet`,
    `ConsoleDialog` et les `MessageScreen` (signal `activated`), et seulement après un appui fait
    au même endroit : le relâché d'un A qui a fermé un panneau ne lance rien. Bouton Jouer (qui
    reste enfoncé pendant le lancement), lignes d'action des options, choix des dialogs, entrée
    « A » de la légende des écrans de message.
  - **Étape 2, reflet** (`GameShelf`) : une bande claire (16 % de blanc, inclinée de 15°) balaie
    la vignette active une fois, 520 ms après chaque déplacement, comme le prototype (950 ms,
    `curveInOut`) ; remis à zéro dès qu'on bouge, jamais sans la manette (veille, lancement,
    panneaux) ni pendant l'entrée.
    La bande n'est créée (`Loader`) que sur la vignette active, le temps du balayage.
  - **Étape 3, interrupteurs** (`OptionsSheet`, composant `Switch`) : une ligne `toggle: true`
    (options [désactivé, activé] ; HDR et Sons, dont l'ordre est passé à [Coupés, Activés]) montre
    un interrupteur à la place de la valeur. A bascule (au relâché) ; → active, ← désactive, après
    90 ms d'étirement du pouce (la valeur est appliquée même si on referme avant) ; pousser vers
    l'état déjà là : butée de 3 px aller-retour (260 ms) et son `edge`. Pouce qui glisse au ressort
    « rebond » et s'étire pendant l'appui, orange qui se répand depuis le pouce éteint (320 ms),
    ligne qui s'écrase comme les lignes d'action. `Accessible.name` garde le libellé de la valeur.
  - **Étape 4, valeurs** (`OptionsSheet`, `RollingNumber.qml`) : une valeur numérique (toutes les
    options sont des nombres : images/s, luminosité, volume, veille…) roule chiffre par chiffre
    (ressort « vif », chiffres tabulaires, chiffres de tête effacés) ; les autres glissent toujours
    (`SwapBox`). En bout de liste, en plus du son `edge`, la valeur bute (5 px par poussée, 16 au
    plus, retour au ressort « rebond »). **Débit** : une ligne-interrupteur « Débit automatique »
    puis un **curseur** de 5 à 150 Mb/s (ligne plus haute, piste, crans à 10 / 20 / 40 / 80) ; à
    l'appui maintenu le pas accélère (1 → 2 → 5) et marque 260 ms d'arrêt sur chaque cran ;
    en automatique il montre, grisée, la valeur calculée par Moonlight, et le pousser repasse en
    débit fixe à partir d'elle. Le curseur signale sa valeur (Mb/s) à la place d'un index.
  - **Étape 5, onglets** (`ElasticIndicator.qml`) : un seul soulignement passe de Flux à Console ;
    son bord avant part au ressort « vif », l'arrière suit 40 ms plus tard (420 ms, `curveOut`),
    d'où l'étirement. Le libellé qui devient actif s'allume en 220 ms après 90 ms. Composant
    réutilisable (profils de flux du §12).
  - **Étape 6, refus et coche** : `Pressable.refuse()` secoue l'élément (440 ms : −9, 8, −5, 3,
    −1 px puis 0) avec le son `edge`. Là où c'est refusé aujourd'hui : le code Companion faux (les
    cases ; la ligne d'état d'un `MessageScreen` apparaît en dépliant, 340 ms), Jouer quand le PC
    est hors ligne et impossible à réveiller (en plus du toast), le réseau Wi-Fi déjà connecté
    (ligne `locked`, avec son surlignage). Une ligne `checked` d'`OptionsSheet` a une coche devant
    son libellé, tracée trait après trait (300 ms après 60 ms, orange) : le réseau connecté. Elle se
    trace quand le réseau connecté change (pas à chaque ouverture de la liste).
  - **Étape 7, appui maintenu** (`HoldFill.qml`) : confirmer une action destructive demande de
    maintenir A 900 ms : toutes les confirmations de `ConsoleHome` (`confirmDialog.holdToConfirm` :
    quitter le jeu, redémarrer, éteindre, désinstaller, annuler un téléchargement, « Fermer et
    jouer »), et « Oublier ce PC » (qui ne demande plus deux pressions). Remplissage orange de
    gauche à droite (affiché : progression^1,4), libellé repris en `inkOnAccent` sous lui, vidange
    en 280 ms si on lâche, rebond à 1,035, puis l'action. « Annuler » reste le choix par défaut ;
    la légende dit « Maintenir ». Le menu en jeu aussi, depuis le 2026-10-23, et **sans page de
    confirmation** (demande de Marco) : A, Entrée ou le clic tenus directement sur « Quitter … »,
    « Redémarrer », « Éteindre » de la liste (`streampainter` `drawHold`, `streammenu`
    `startHold` / `holdStep`), coche et libellé de fin, puis le départ (un `SDL_QUIT` ramène
    `holdStep`, fil du minuteur, sur le fil des événements ; le minuteur ne doit pas s'arrêter
    entre la coche et le départ, sinon le menu restait bloqué).
  - **Étape 8, île de notification** (`StatusBar`) : la pastille de l'hôte s'ouvre (340 × 72, taille
    au ressort « souple », rayon en 380 ms) pour un événement système, puis se referme seule après
    2,8 s ; B la referme. Événements : manette branchée / débranchée (`InputStatus.controllerCount`,
    ajouté), manette presque vide (une barre), batterie sous 20 % hors charge, PC perdu puis
    retrouvé, réseau « mauvais » pendant 10 s. Contenu (icône, titre, détail, valeur) en cascade
    (+110 ms, 45 ms d'écart, sans flou) ; une nouvelle notification remplace l'ancienne sans
    refermer (rebond à 1,025). Rien pendant l'entrée de l'accueil (le vol du logo), un panneau, un
    lancement, la veille ou le rideau ; un événement de ces moments-là est perdu. `Toast` reste
    pour l'étagère. Plus tard : « débit ajusté » du profil Auto (§12) par `homeScreen.notify()`.
  ⚠️ Vu dans le harnais (`HomeDemo` : `do=hold,release` ; reflet : `goto=7 at=2500 delay=4400` ;
  interrupteurs : `do=options,down,down,down,down,down,right at=2000` ; curseur :
  `do=options,down,down,down,right` ; onglets : `do=options,down,up,tab at=2000 delay=2550` ;
  refus : `view=ConsoleHomeDemo do=wifi,down,up,a at=2500 delay=2990`, `view=PagesDemo page=code-error` ;
  appui maintenu : `view=ConsoleHomeDemo do=home,down,down,a,down,hold at=4000 delay=5400` — après
  l'animation de démarrage, qui rend sinon le focus à l'accueil ; île : `do=pad`, `lost,back`,
  `lowbattery` à `at=2500` dans `HomeDemo`). Rien n'a été vu à la manette ni sur l'écran de la
  carte, aucun son n'a été écouté, et l'accueil au repos reste à 1,68 d'écart moyen du prototype
  Ambiant (inchangé par ce chantier).
  pas à la manette ni à 60 i/s sur l'Orange Pi (le reflet redessine le calque de la vignette
  active pendant 950 ms).
- ✅ **Étagère en portrait (2026-10-23, demande de Marco : « rendre l'OS beau »)** : les vignettes
  passent du 16:9 au portrait 3:4 (108 × 144, coins de 10), le format des jaquettes d'Apollo /
  Sunshine (600 × 800), désormais affichées entières au lieu d'être recadrées. Une dizaine de jeux
  tiennent sur la largeur. Le bloc héros remonte de 54 px (`heroBottom` 532, au-dessus de
  l'anneau de la vignette active depuis le carrousel), les écrans de message avec lui ; le toast suit l'étagère ; un
  jeu sans jaquette écrit son nom sur trois lignes. Tout découle des jetons de `Theme.qml`.
  L'accueil s'écarte donc des captures de référence du prototype Ambiant (étagère et héros) :
  `compare.py` n'a plus de sens que pour la barre haute et le fond. ⚠️ Pas vu avec les vraies
  jaquettes du PC (le harnais recadre ses images 16:10), ni à la manette.
- ✅ **Effets du prototype des micro-interactions (2026-10-23, demande de Marco)** : ombre portée sous
  la vignette active (0 18px 40px -12px) et sous l'île ouverte (0 14px 34px -8px), en **images
  pré-calculées** (`shadows/*.png`, `harness/make-shadows.py`, aucun flou à l'exécution ;
  `RectangularShadow` exigerait Qt 6.9) ; filet clair intérieur des vignettes (plus net sur
  l'active) ; la vignette active s'écrase depuis son centre tant que A est tenu (1,02 depuis le
  carrousel) ; halo de la poignée
  du curseur sur la ligne en focus, crans placés sous la poignée et qui pulsent quand on les franchit
  (×1,9, orange, 440 ms) ; pouce d'interrupteur plus clair sur la ligne en focus ; explication d'un
  refus dépliée sous la liste (réseau déjà connecté). Corrigé au passage : le soulignement des
  onglets sautait vers « Flux » à chaque valeur changée dans « Console » (onglets recréés), et les
  interrupteurs / chiffres / curseur s'animaient en changeant d'onglet. ⚠️ Pas vu à la manette ;
  ombres à juger sur l'écran de la carte (discrètes sur un fond sombre, comme dans le prototype).
- ✅ **Carrousel du prototype (2026-10-23, demande de Marco)** : l'étagère reprend le carrousel des
  micro-interactions, **anneau** compris (le brief l'écartait, Marco l'a demandé). Un seul anneau
  (trait clair de 2 px à 6 px de la vignette agrandie, halo de 5 px) glisse d'une vignette à
  l'autre au ressort « vif » ; la piste ne défile, au ressort « souple », que pour garder la
  vignette active à 80 px des bords (le prototype : 44 pour une marge de 36) : la sélection n'est
  plus calée à gauche. Avec la manette, la vignette active grandit à 1,08 depuis son centre
  (ressort « vif »), les autres passent à 48 % (220 ms) ; A tenu, elle redescend à 1,02. Sans la
  manette (options, panneau, héros), toutes reviennent et l'anneau s'efface en rétrécissant
  (160 ms, 0,94). En bout de liste, l'anneau bute. Le soulignement orange de la vignette active
  disparaît (la teinte ambiante ne colore plus que le voile). Le lancement en part et y revient
  (cf. plus haut). Corrigé au passage : l'illustration de l'écran de lancement se rechargeait à
  chaque taille pendant qu'il grandissait (image noire furtive). **Textes du jeu** : le swapText
  garde maintenant son flou (3 px, plein à l'invisible, nul une fois posé : il suit l'opacité),
  sur la méta, le titre, le sous-titre et le libellé du bouton Jouer (`SwapBox.blur`). Un calque
  MultiEffect par texte, posé une fois : pendant le glissement seul le mélange final change.
  Rendu GPU seulement (le rendu logiciel des tests n'a pas de calques). ⚠️ Pas vu à la manette ;
  `Theme.swapBlur` à 0 si la carte ne tient pas ses 60 i/s.
- ✅ **Sélecteur fixe, nets, Partie terminée (2026-10-23, demande de Marco)** : l'anneau de l'étagère
  ne bouge plus, il reste à la marge gauche et la piste défile dessous (ressort « vif ») ; en bout
  de liste, c'est la piste qui bute. `shelfScrollMargin` supprimé. La dernière vignette peut venir
  sous l'anneau : contentX dépasse la fin de la liste, la vue replace alors ses vignettes à l'estime
  et décale `originX` pendant qu'on écrit contentX → synchro impérative (`list.sync()`), plus de
  liaison (boucle de liaison sinon). Textes du héros (titre, « Reprendre la partie »…) flous /
  pixelisés au repos : le calque de flou du `SwapBox` restait actif ; il n'existe plus que pendant
  la transition (`opacity < 1`). « Partie terminée » débordait du bouton Quitter : sa largeur prend
  la plus grande de ses deux étiquettes (`HoldFill.doneWidth`). ⚠️ Pas vu à la manette.
- ✅ **Ctrl + Maj + Alt + Tab = bouton Home (2026-10-23, demande de Marco)** : à l'accueil, un
  `Shortcut` de `ConsoleHome` (« Tab » et « Backtab » : avec Maj, Qt reçoit Backtab) appelle
  `homeButton()` (menu Home, réveil de veille) ; en jeu, combo `KeyComboStreamMenu` de Moonlight
  (`keyboard.cpp`, `CONSOLE_UI` seulement) : ouvre / ferme le menu en jeu comme Home (manettes et
  touches relâchées côté PC). **Clavier et souris dans le menu en jeu** : menu ouvert, flèches,
  Entrée / Espace (A), Échap / Retour arrière (B) le pilotent (`keyboard.cpp`) et la souris est
  libérée (`SdlInputHandler::syncStreamMenuMouse`, `mouse.cpp`) : survoler une ligne la
  sélectionne, clic gauche la valide au relâché, clic droit ou à côté du panneau = B, molette =
  une ligne ; fermé, la souris repart au jeu. Rien n'atteint le PC menu ouvert. Ligne sous la
  souris : `StreamPainter::rowAt` (même calcul que le dessin, `choicesTop`), vérifié contre le
  dessin par `harness/streammenu-rows.cpp`. ⚠️ Pas encore essayé par Marco dans un vrai flux.
- ✅ **Souris partout (2026-10-23, demande de Marco)** : `HoverArea.qml` (MouseArea à survol, curseur
  en main, `pointed()` seulement quand le pointeur bouge vraiment : `Pointer.js` écarte les survols
  que Qt envoie quand le contenu glisse sous un pointeur immobile, sinon une liste qui défile au
  clavier rendait la sélection à la ligne sous la souris). Listes : survoler une ligne y amène la
  sélection (son `move`), un clic agit — options (lignes, curseur, choix du profil, « Oublier ce
  PC », chevrons ‹ › cliquables), dialogs et menu Home, clavier à l'écran (la touche cliquée
  s'écrase). Boutons : `Pressable.hovered` / `hoverScale` (grandit à 1,04 au ressort « vif ») —
  Jouer / Reprendre, Quitter la partie (contour éclairci), Options et Épingler (`TextButton` du
  héros, éclairés), Désinstaller (fiche), « B Annuler » du lancement ; onglets ; vignettes de
  l'étagère (1,04 et 80 % d'opacité, le survol ne sélectionne pas : la piste défilerait sous la
  souris) ; choix du profil (fond discret). La légende (`ControllerLegend.triggered`) fait ce que
  fait le bouton (A, B, X, Y) partout où elle est posée ; écrans de message : A → `activated`,
  Y → options ; cases du code Companion : clic pour choisir, molette pour le chiffre ; molette sur
  la description de la fiche ; île de notification : clic la referme, survolée elle reste.
  Testé par `tst_Hover`. ⚠️ Effets de survol pas vus à l'écran (le harnais ne bouge pas la souris).
- ✅ **Améliorations proposées puis validées (2026-10-23, demande de Marco)**, un commit chacune :
  - **« Réduire les animations »** (onglet Console, `ConsoleUi/reduceMotion`, `Theme.reducedMotion`) :
    les trois ressorts deviennent `Theme.reducedSpring` (curveOut, 200 ms), plus de flou des textes,
    d'ombres, de dérive du fond, de reflet, de bande de chargement, d'onde « en cours », de fondu
    d'entrée du flux. Plan B pour l'Orange Pi.
  - **Vibrations** (`StreamMenu::rumble`, `InputStatus.feedback`, `Sounds.played`) : butée, refus,
    appui maintenu au bout, lancement ; aussi dans le menu en jeu. Réglage « Vibrations »
    (`ConsoleUi/rumble`) dans l'onglet Console quand une manette est branchée.
  - **Point « en cours »** sur la vignette du jeu qui tourne sur le PC (`GameShelf.runningName`,
    `ConsoleHome.runningGame`), avec une onde. Harnais : `view=HomeDemo running=2`.
  - **Bande de chargement** sur les vignettes dont la jaquette charge.
  - **Le flux sort du noir** à sa première image (400 ms), pendant du fondu de sortie.
  - **Collections** Tous / Favoris / Récents (onglets à droite au-dessus de l'étagère, L1 / R1,
    Page préc. / suiv., clic ; `Library.collection(s)`), **saut** de dix vignettes (L2 / R2 lues par
    `InputStatus.triggerPressed`, Maj + ← / →), molette sur l'étagère.
  - **Menu en jeu** : « Capture d'écran » (aussi le bouton Partager / Capture, MISC1, plus envoyé au
    PC ; PNG pleine définition dans `Images/CocoOS`), « Volume » et « Luminosité » (← / →, via
    SystemStatus passé à `prepareStreamMenu`), **avis** en haut à droite pendant le jeu (réseau
    mauvais 10 s, manette presque vide, capture enregistrée ; `StreamPainter::Notice`). Harnais :
    `streammenu-shot … page=stats notice="Réseau instable" tone=bad`.
  - **Curseurs pour le volume et la luminosité, partout** : dans l'onglet Console (lignes `slider`
    comme le débit, crans à 25 / 50 / 75, luminosité 5 % au moins) et dans le menu en jeu (rail,
    remplissage orange, poignée dessinés par `StreamPainter` à droite de la ligne, la valeur à
    gauche ; ← / → de 5 % en 5 %, la poignée glisse en 160 ms ; à la souris, clic ou glisser par
    crans de 5 %, `StreamPainter::sliderAt`, vérifié par `streammenu-rows.cpp`). Harnais :
    `streammenu-shot … page=menu sliders=1`.
  - La dérive lente du fond existait déjà (zoom 1,03 → 1,09 en 30 s, arrêtée après 10 s sans
    action, pour la batterie) : rien d'ajouté. Couleur d'accent et « dernier jeu au démarrage » :
    écartés par Marco.
  ⚠️ Rien vu à la manette ni dans un vrai flux : vibrations, avis, capture, volume, collections.
- ✅ **Reprendre / Quitter la partie (2026-10-23, demande de Marco)** : les deux boutons du prototype
  des micro-interactions (« Reprendre la partie », « Quitter le stream »), dans le héros, quand le
  jeu sélectionné tourne sur le PC. Libellés « Reprendre la partie » / « Quitter la partie » (à
  l'accueil, le flux est déjà fermé : c'est le jeu qu'on quitte). Haut depuis l'étagère leur donne
  la manette (l'anneau de l'étagère s'efface) ; ← / → choisissent, bas ou B la rendent. Anneau de
  focus du prototype (2 px à 5 px du bouton, 140 ms, se resserre de 1,025). Reprendre : l'appui
  du bouton Jouer (« Reprise… »). Quitter : contour fin, s'écrase à 0,97, appui maintenu
  (`HoldFill` : remplissage orange, coche et « Partie terminée », tout le bouton rebondit) puis
  `quitRunningGame` ; lâché trop tôt, un toast « Maintenez A pour quitter la partie ». La coche
  reste 1,7 s puis le bouton se vide, si le jeu tourne encore. A sur l'étagère reprend toujours
  directement. Harnais : `view=HomeDemo running=0 do=hero,heroright,holdquit at=2500`.
  ⚠️ Pas vu à la manette ; le menu en jeu (QPainter) garde ses lignes.
- ✅ **Suite des effets du prototype (2026-10-23, demande de Marco)** : au changement de jeu, méta,
  titre et sous-titre du héros font le swapText du prototype (14 px, 380 ms à l'entrée, 220 ms à la
  sortie ; flou de 3 px ajouté ensuite, cf. « Carrousel du prototype ») ; au lancement, « Jouer » cède la place à « Lancement… » (« Reprise… ») et le
  bouton s'élargit ; un appui maintenu plein montre une coche tracée et un libellé de fin
  (« Extinction », « PC oublié »…) avant l'action, et se fait aussi à la souris (clic tenu) ; le
  curseur de débit se règle à la souris (clic, glisser, accroche aux crans, butée élastique). **Sons**
  nouveaux, synthétisés comme les autres (`make-sounds.py`) : `toggle-on` / `toggle-off`, `hold`
  (coupé si on lâche) puis `confirm`, `deny` (refus), `notify` (île), `detent` (cran du curseur),
  `segment` (profil). ⚠️ Aucun son n'a encore été écouté ; rien vu à la manette.
- ✅ **Profils de flux (2026-10-23, demande de Marco ; phase 1 du chantier §12)** : en tête de
  l'onglet Flux, un sélecteur (prototype « Sélecteur de profil » : pastille élastique, chiffres
  remplacés en cascade) — Compétitif, **Équilibré (par défaut)**, Qualité, Économie, Manuel
  (`StreamProfiles.js`, testé par `tst_StreamProfiles`). Un profil automatique choisit **au
  lancement** définition, images/s et débit d'après l'écran (définition, fréquence) et la qualité
  du réseau vers le PC (un palier de moins si moyenne, deux si mauvaise ; la note le dit) ; il ne
  touche ni au codec ni au HDR, et n'enregistre rien (`applyGameProfile` / `restoreCommonSettings`,
  comme les réglages par jeu). Sous un profil automatique, les lignes montrent ce qu'il choisira,
  grisées, sans « Débit automatique » ; en toucher une passe en Manuel à partir de ces valeurs.
  Manuel = les réglages d'avant, tels quels. Mémorisé dans `ConsoleUi/streamProfile` (communs) ou
  dans les réglages à part d'un jeu (Manuel pour ceux d'avant les profils). Le panneau d'options
  défile désormais (onglet Flux plus haut que l'écran, longues listes Wi-Fi), fondus aux bords.
  Définitions : celle de l'écran de la console si elle tient sous le plafond du profil (l'image le
  remplit), sinon les définitions courantes 16:9 (540p, 720p, 1080p, 1440p) — plus de tailles au
  format de l'écran (1728 × 1080…). Les cases du sélecteur prennent la largeur de leur libellé
  (« Competitive » entier en anglais).
  **Réglages avancés** (interrupteur sous le profil, `ConsoleUi/advancedSettings`, éteint par défaut) :
  éteint, l'onglet Flux se réduit à l'essentiel — le profil (avec une phrase qui le décrit au lieu
  de ses chiffres), l'interrupteur, « Oublier ce PC » ; allumé, les chiffres du profil, les
  réglages à part du jeu, définition, images/s, débit, codec, HDR. Les lignes restent toutes dans
  le modèle (`advanced`, `hidden` : repliées, hauteur nulle, sautées par la manette) : aucune ne
  prend plus la place d'une autre (ce qui faisait sauter les animations en passant de Manuel à
  Économie). Mouvement : à l'allumage, le dessous glisse faire la place (ressort « souple »), la
  description cède la place aux chiffres, puis les lignes apparaissent en cascade (90 ms, puis
  40 ms d'écart, en descendant de 12 px) ; à l'extinction, elles s'effacent du bas vers le haut
  et le dessous remonte 110 ms après (composant `Reveal` d'`OptionsSheet`). **Manuel** n'est proposé
  qu'avec les réglages avancés (`hiddenOptions` du sélecteur : la case se replie, la manette la
  saute) ; les éteindre sous Manuel ramène le profil à Équilibré (les réglages manuels restent
  enregistrés). Seule exception : un jeu aux réglages à part d'avant les profils garde Manuel.
  ⚠️ Libellés et paliers à valider par Marco à la manette (le doc le demande) ; le choix du palier
  n'est qu'une première version de la phase 4 (pas de sonde avant lancement ni de mémoire par
  réseau) ; anti-gigue (phase 3) et FSR (phase 5) restent à faire.
- ✅ **Barre haute : Réglages, Wi-Fi, batterie (2026-10-27, demande de Marco)** : un engrenage
  (`icons/settings.svg`) à droite de la batterie. Wi-Fi, batterie et engrenage se choisissent :
  haut depuis l'étagère (ou depuis les boutons du héros pendant une partie), ← / →, bas ou B
  rendent la manette ; au clavier pareil ; à la souris, survol et clic. Pastille éclairée et
  anneau de focus (`FocusRing.qml`, sorti de `HeroBlock`) ; l'icône choisie ou survolée ouvre
  sa **fiche** sous la barre (style de l'île, ombre étirée) : Wi-Fi (nom, sécurité, signal,
  latence vers le PC ; A « Changer de réseau » → la liste des réseaux), batterie (état,
  **autonomie restante** ou « pleine dans », consommation ou puissance de charge), Réglages
  (A → le panneau d'options sur l'onglet **Console**). Bande, IP, débit de la liaison, usure
  de la batterie et sous-titre des Réglages retirés à la demande de Marco (2026-10-27). Données : `SystemStatus.batteryDetails` (sysfs : `time_to_*_now`,
  sinon énergie / puissance ou charge / courant ; temps lissé d'un relevé à l'autre) et
  `SystemStatus.wifi` (NetworkManager). Vérifié sur le laptop (38 %, 13,4 W → 86 min), dans le harnais (`do=sys,sysleft`) et par
  `tst_ConsoleHome::test_9y_statusBarIcons`. ⚠️ Pas vu à la manette.
- ✅ **Écran de veille « Premium » (2026-10-27, branche `feat/idle-screen`, fusionnée dans
  `console-ui`)** — cible :
  `docs/design/idle/` (brief, spec, maquettes 09 à 12, références) ; suivi détaillé dans `next_steps.md`.
  Remplace `SleepScreen` (décision de Marco) : après `ConsoleUi/idleSeconds` (**5 min** par défaut, décision de Marco du 2026-10-28 ;
  Options › Console › Mise en veille après : 30 s, 1, 2, 5, 10, 30 min, jamais ; l'ancienne clé
  `sleepMinutes` est ignorée), `idle/IdleOverlay` monte au-dessus de l'accueil en fondu ;
  quatre écrans selon l'état : jeu en cours sur le PC (09), jeu + téléchargement (10), téléchargement
  (11), repos (12 : date, heure en dégradé, capsule PC / réseau / batterie / dernier jeu). Une touche ou
  un clic : sortie en 320 ms, l'accueil reprend la main tout de suite ; **A pendant une partie relance le
  flux** du jeu en cours (« Appuyez sur A pour reprendre »). Le glyphe suit la manette (✕ PlayStation,
  B Nintendo). En 4G / 5G (`network.kind` "4g" / "5g"), « 5G » remplace l'icône Wi-Fi (« 5G excellente »
  dans la capsule) ; la source réelle viendra du module 5G (ModemManager, TODO). Données réelles
  (`ConsoleHome`, `liveIdleStatus`) : PC, Wi-Fi et latence, batterie et autonomie, jeu qui tourne
  (jaquette Apollo, durée depuis son lancement d'ici), dernier jeu ; un élément sans donnée est masqué.
  TODO(HostCompanion) : téléchargements, jaquettes Playnite. `COCOOS_IDLE_MOCK=1`
  (+ `COCOOS_IDLE_STATE=game|gameDownload|download|rest`, `COCOOS_IDLE_NETWORK=4g|5g`) montre les
  données des maquettes sur la console.
  Parité avec les maquettes (phase 4) : écart moyen ≤ 3,4/255, tous les textes à ±2 px. **Format** : la
  grille 1280 × 720 des maquettes s'étire au format de l'écran (1280 × 800 en 16:10, plus large en 21:9),
  bloc central au milieu, heure et indication aux bords, fond et lueur sur tout l'écran ; les couches
  (heure en dégradé, jaquette, vignette) et les SVG sont rendus à la résolution de l'écran
  (`IdleTheme.textureScale`). Aperçu : `app/gui/console/idle/preview/IdlePreview.qml` (`grab.sh`,
  `parity.sh` ; `--network 5g`, `--pad playstation`, `--size 2560x1600`). Journal : « [console-ui] Veille après N s d'inactivité (état) ». ⚠️ Pas vu à la
  manette ni sur l'écran de la carte ; performance (flou d'entrée, `IdleTheme.entryBlur`) à mesurer sur
  l'Orange Pi (phase 6 du brief).
- 📋 **Chantier : optimisation du flux** (profils Manuel / Auto ✅ en phase 1, anti-gigue adaptatif,
  télémétrie, FSR 1.0) — décidé le 2026-10-01, cf §12 et `docs/stream/STREAM-OPTIMISATION.md`.
  Côté console uniquement (Apollo reste non modifié).
- **Tâche en cours** : la **validation E2E à la manette** contre le vrai host (Apollo +
  HostCompanion, jamais éprouvé en face), puis le mode kiosk (boot direct, §9 6c) et
  l'auto-accept du pairing côté host (installeur, §9 6b).
