# Référence détaillée — CocoOS (anciennes sections AGENTS.md)

> Instructions **communes à tous les assistants IA** (Claude Code, Codex / ChatGPT, Cursor, Copilot,
> Gemini CLI, Aider, OpenCode… avec n'importe quel modèle, DeepSeek compris) et aux humains.
> Référence à charger par section, jamais intégralement au démarrage.
> Le repo est un **fork de `moonlight-stream/moonlight-qt`** (branche de travail `console-ui`).
> Les anciens renvois « CLAUDE.md §N » / « AGENTS.md §N » désignent maintenant ce fichier.
> Les états historiques ci-dessous ne remplacent pas la roadmap ni `HANDOFF.md`.

## 0. Démarrage (une fois par clone ou worktree)

```bash
scripts/dev/setup.sh    # hooks du worktree et exclusions locales ; réseau seulement sur option explicite
scripts/dev/status.sh   # où en est-on : branche, fichiers modifiés, dernière étape, dernier build
```

## Index : où trouver quoi

**Skills** = procédures et références au format ouvert Agent Skills : `.agents/skills/<nom>/SKILL.md`.
Si ton outil ne les charge pas tout seul, **lis le SKILL.md concerné** quand la tâche y correspond.

| Besoin | Où |
|---|---|
| Prochaine tâche, état fin du chantier en cours | `next_steps.md` (dernière section) |
| Enchaîner une tâche de bout en bout (choisir → coder → vérifier → committer) | skill `next` |
| Vérifier : build + tests + fumée, verdict PASS/FAIL | skill `verify` |
| Relire un diff d'UI | skill `qml-review` |
| Comprendre le code upstream de moonlight-qt avant une couture | skill `upstream-explore` |
| UI : direction artistique, carte des fichiers, pièges QML (ex-§5) | skill `cocoos-ui` |
| Build, pièges MOC/qmake/rcc, dépendances, logs (ex-§11) | skill `cocoos-build` |
| Voir / capturer / tester l'UI sans PC hôte | skill `ambiant-harness` |
| Traduction anglaise | skill `cocoos-i18n` |
| Animation de démarrage | skill `boot-animation` |
| Mettre à jour depuis moonlight-qt officiel | skill `upstream-sync` |
| Historique, *pourquoi* d'un choix, commits (ex-§2) | `docs/ai/HISTORY.md` (recherche ciblée, pas de lecture intégrale) |
| Matériel, BOM, 5G (ex-§6) | `docs/ai/HARDWARE.md` |
| Optimisation du flux | `docs/stream/STREAM-OPTIMISATION.md` (§12) |
| Travailler en parallèle, à distance, avec quel outil | `docs/ai/WORKFLOW.md` |
| OpenCode V2, modèles, flotte tmux, revue, coûts et SSH | `docs/ai/OPENCODE.md` |
| Vérification rapide et limites Qt/matériel | `docs/ai/QUALITY.md` ; `docs/ai/QT-SKILLS.md` |

## Outillage (sorties filtrées, économes en tokens — à préférer aux commandes brutes)

```bash
scripts/dev/build.sh [embedded|vanilla] [--clean]   # build : erreurs/warnings utiles + BUILD OK|FAILED
scripts/dev/test.sh [NomDuTest]                     # tests QML du harnais, résumé seulement
scripts/dev/smoke.sh [secondes]                     # lancement hors réseau, erreurs seulement
scripts/dev/i18n.sh [--release]                     # lupdate + chaînes non traduites (+ lrelease)
scripts/dev/upstream-policy.sh <fichier>            # own | seam | upstream | forbidden | guard | new
```
- **Garde-fou commun** : le hook git `.githooks/pre-commit` refuse tout commit touchant un fichier upstream
  hors des coutures de `.agents/seams.txt` (et tout commit sur `master`). **Avant de modifier un fichier hors
  de `app/gui/console/`, lancer `scripts/dev/upstream-policy.sh <fichier>`** : `upstream`/`forbidden` = ne
  pas y toucher ; `seam` = modif additive minimale, sous `#ifdef CONSOLE_UI`, diff montré à Coco ; `guard` =
  décision de Coco. Ne jamais contourner avec `--no-verify`.
- Ne pas relire un fichier inchangé ; modifier par petites retouches plutôt que réécrire un fichier entier.
- Garder le contexte propre : explorations larges (upstream, logs) dans un sous-agent si l'outil en a.

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

## 2. État actuel du projet (résumé — détail : `docs/ai/HISTORY.md`)

- Streaming validé depuis ~1 an (Moonlight + Sunshine/Apollo + Tailscale, y compris en 5G sur smartphone).
- Fork Qt 6 sous Fedora KDE ; décodage matériel OK (Iris Xe, VAAPI, H.264/HEVC/AV1).
- UI console « Ambiant » intégrée derrière `embedded`/`CONSOLE_UI`, branchée sur les vraies données
  Moonlight ; chaîne découverte → appairage auto → accueil → lancement → stream → retour validée contre Apollo.
- Client HostCompanion (`CompanionClient`) : lancement via `POST /v1/launch` câblé, **jamais éprouvé E2E**
  contre un HostCompanion en marche (repli : lancement direct Apollo).
- Menu en jeu, sons, veille (`idle/`, remplace `SleepScreen`), animation de démarrage « le O » : faits,
  vérifiés au harnais, **pas encore à la manette ni sur l'Orange Pi**.
- Optimisation du flux : phase 1 (profils) faite, suite planifiée (§12).
- **Tâche en cours** : validation E2E à la manette contre le vrai host (Apollo + HostCompanion), puis
  kiosk (§9 6c) et auto-accept du pairing côté host.

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

### Côté PC host (projet séparé, déjà implémenté)
**HostCompanion** orchestre Apollo et Playnite sans les forker. Ses choix de stack,
intégrations et validations ont pour source `HostCompanion/AGENTS.md` et ses skills,
pas ce dépôt. Le protocole canonique est `HostCompanion/docs/protocol.md` :
`POST /v1/launch` → `READY` avant le stream lorsque le Companion est connecté.
Ne pas supposer le dépôt frère accessible depuis un worktree : demander son
chemin en lecture seule si nécessaire. La compatibilité moonlight-qt reste prioritaire.


---

## 4. Stratégie de suivi d'upstream — LA convention de code n°1

On veut pouvoir **suivre les commits du repo officiel de moonlight** sans douleur. Donc :

- **Règle d'or : créer des fichiers neufs plutôt que réécrire les fichiers existants.**
  Un fichier neuf ne crée jamais de conflit de merge. Toute l'interface maison vit dans son
  propre dossier isolé : `app/gui/console/`.
- **Ne JAMAIS modifier un fichier upstream**, sauf les rares « coutures » strictement
  nécessaires, qu'on garde minuscules (voir §9), toujours sous `#ifdef CONSOLE_UI` ou dans le
  scope `embedded`. Liste : `app.pro`, `qml.qrc`, `main.cpp` (enregistrement des singletons,
  rôle PipeWire des sons), `streaming/input/gamepad.cpp` (Home ouvre le menu en jeu, boutons
  et stick routés vers lui, combinaison des statistiques, Partager = capture d'écran), `streaming/input/keyboard.cpp` +
  `input.{h,cpp}` (Ctrl+Alt+Maj+Tab ouvre le menu en jeu, touches routées vers lui),
  `streaming/input/mouse.cpp` (souris libérée et routée vers le menu en jeu),
  `streaming/session.cpp` (chaque `SDL_QUIT` passe d'abord par le rideau, `interceptQuit`), `streaming/video/overlaymanager.{h,cpp}`
  (`setOverlaySurface` : une image toute faite sur l'overlay de débogage, dont le texte
  d'origine est ignoré ; un verrou empêche le moteur de rendu de disparaître pendant qu'on le
  notifie depuis le minuteur d'animation), `streaming/video/ffmpeg.cpp` (chiffres du flux chaque seconde, image
  décodée pour le flou, réaffichage de la dernière image quand le menu change sur un écran
  immobile, copie lâchée à l'arrêt du décodeur). Ces coutures n'ajoutent que des lignes (sauf celle de Home, déjà là).
- **Surtout, ne pas toucher `app/gui/main.qml`.**
- Git :
  - remote `upstream` = `https://github.com/moonlight-stream/moonlight-qt.git`
  - branche `master` = **miroir propre d'upstream** (on n'y code jamais)
  - branche `console-ui` = **tout le travail maison**
  - mise à jour : `git fetch upstream` → fast-forward `master` → `git rebase master` sur
    `console-ui` (historique linéaire, modifs rejouées proprement par-dessus l'officiel).
- Avant d'appliquer des changements : **toujours montrer les diffs.**


---

## 5. L'interface custom → skill `cocoos-ui`

Source de vérité de l'accueil : l'écran « Ambiant » (`docs/ui/ambiant/AMBIANT-BRIEF.md` +
`ambiant-prototype.html` ; le prototype gagne en cas de doute). Sombre, 100 % manette, aucun élément
« bureau », accent `#F2802A`, police Sora seule, **aucune valeur en dur hors `Theme.qml`**.
Carte complète des fichiers de `app/gui/console/` et pièges QML : skill `cocoos-ui`.

---

## 6. Matériel → `docs/ai/HARDWARE.md`

Proto : Orange Pi 5B (RK3588S), manette RP2040 + GP2040-CE, écran HDMI puis MIPI-DSI, 5G plus tard.

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
7b. 📋 Optimisation du flux côté console (profils, télémétrie, anti-gigue adaptatif, choix
    du palier au démarrage, FSR 1.0) — planifié, cf §12. Les phases 0 à 4 sont faisables sur
    le laptop Fedora ; la phase 5 (FSR) et les mesures se font sur l'Orange Pi.
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
> (`../HostCompanion/AGENTS.md §4`). **La tranche 3 de `CompanionClient` a recâblé ce lancement**
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
Mesure des 60 fps sur la carte. (Faits : filtrage des apps qui ne sont pas des jeux, batterie
et Wi-Fi, fonds 16:9 du Companion, dernier jeu, réglage Sons, écrans d'attente / appairage /
dialogs.) À valider contre le vrai HostCompanion : le téléchargement des fonds (`/v1/media/{id}/bg`
n'a jamais été appelé en réel).

### D — Auto-accept du pairing côté host (avec l'installeur, étape 8)
Pré-injecter l'identité/certificat de la console dans la conf d'Apollo (ou auto-accept),
pour que l'écran de code Moonlight (`pinScreen` de `ConsoleHome`) ne s'affiche jamais en
usage normal.

### E — Optimisation du flux (quand A à D le permettent)
Chantier complet décrit dans `docs/stream/STREAM-OPTIMISATION.md` (résumé en §12). Commencer
par la **phase 0 (audit, sans code)** et s'arrêter à son gate : aucune couture upstream sans
l'accord de Coco.

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
- Avant de déclarer une tâche finie : skill `verify` (build + tests verts), et pour de l'UI une capture du
  harnais regardée (skill `ambiant-harness`). Sinon dire précisément ce qui n'est pas vérifié.
- Tenir `next_steps.md` à jour à la fin de chaque tâche (fait / reste / décisions de Marco).

---

## 11. Notes de build durables → skills

Tout est dans le skill `cocoos-build` (build, QtWebSockets, pièges MOC / qmake `subdirs` / modèles /
`count` / imports / journald / rcc, dépendances d'exécution, `.git/info/exclude`), `ambiant-harness`
(harnais), `cocoos-i18n` (traduction) et `boot-animation`. Commande de base :

```bash
qmake6 "CONFIG+=embedded" moonlight-qt.pro && make release -j$(nproc) && ./app/moonlight
```

---

## 12. Chantier : optimisation du flux (planifié)

Source unique : **`docs/stream/STREAM-OPTIMISATION.md`**, à lire avant ce chantier.
Apollo non modifié ; pas de renégociation en cours de partie ni de génération de
frames. Toute couture ou extension de périmètre exige l'accord de Coco avant
édition. Les gates, profils, leviers et mesures restent dans ce document ; les
tests offscreen ne prouvent ni performances du streaming ni ressenti à la manette.
