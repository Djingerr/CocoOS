# Optimisation du flux — profils, anti-gigue, télémétrie

> Chantier **planifié, pas commencé** (décidé le 2026-10-01). À traiter quand les fronts
> prioritaires de `CLAUDE.md` §9 le permettent. Ce document est la source de vérité du
> chantier : en cas de doute, il gagne sur le résumé de `CLAUDE.md` §12.

---

## 1. Objectif

Offrir un flux **fluide et agréable pour un joueur lambda** sur un réseau qui varie (Wi-Fi
domestique, 4G/5G), tout en laissant aux experts un contrôle total. Deux familles de profils :

- **Manuel** : les paramètres choisis (résolution, fps, débit, codec) ne bougent jamais
  pendant le flux. C'est le comportement actuel de Moonlight.
- **Auto** : la console adapte ce qu'elle peut pour garder un flux fluide, **sans que
  l'utilisateur ne voie rien** (principe zéro friction, `CLAUDE.md` §1).

---

## 2. Décisions et contraintes (non négociables)

1. **Apollo reste non modifié (no-fork).** Conséquence : résolution, fps et débit sont
   négociés **une seule fois, au lancement de la session** (`STREAM_CONFIGURATION` passée à
   `LiStartConnection`). Ce chantier n'agit donc **que côté console**. Aucun message de
   protocole nouveau, aucune hypothèse sur un hôte patché.
2. **Pas de renégociation de session en cours de partie** (relancer le flux avec d'autres
   paramètres coupe l'image 1 à 3 s : contraire au zéro friction). En mode Auto, la v1
   **choisit bien au départ** et **absorbe la variance** ; elle ne change pas les paramètres
   d'encodage pendant le jeu.
3. **Préparer l'avenir sans le coder** : le contrôleur passe par une **interface de leviers
   abstraite** (§5). Le jour où l'hôte saura changer de débit à chaud, on ajoutera des leviers
   hôte sans réécrire le capteur ni le contrôleur.
4. **Règle de suivi d'upstream (`CLAUDE.md` §4) intacte** : tout le code neuf dans
   `app/gui/console/` (ou un sous-dossier, ex. `app/gui/console/stream/`). La télémétrie et
   l'upscale auront probablement besoin de **coutures dans des fichiers upstream**
   (`Session`, décodeur, renderer). **Toute nouvelle couture doit être proposée à Coco AVANT
   d'être faite**, avec son diff exact, sa taille et la raison pour laquelle aucune
   alternative additive n'existe. Viser une couture unique et minuscule (ex. émettre un signal
   de statistiques par frame).
5. **Build vanilla inchangé** : tout derrière `embedded` / `CONSOLE_UI`.
6. **Human-in-the-loop** : la mécanique se vérifie objectivement (tests, `netem`, timers GPU) ;
   le **réglage des seuils et le ressenti** se valident uniquement par Coco, manette en main.
   Ne jamais déclarer un réglage « bon » sur la seule foi des chiffres.
7. **Rejeté** : la génération de frames (type Lossless Scaling / LSFG). Elle ajoute au moins
   une frame de latence et des artefacts sur le HUD. Ne pas la proposer.

---

## 3. Chiffres de référence (HYPOTHÈSES À VALIDER)

Estimations raisonnées, **pas des mesures**. La phase 2 et la phase 5 produisent les vrais
chiffres sur l'Orange Pi 5B ; ils remplaceront ce tableau.

### Débit vidéo par palier (HEVC temps réel, sans B-frames, jeu en mouvement rapide)

| Palier | Minimum jouable | Confortable | Bits/pixel (confortable) |
|---|---|---|---|
| 360p60 | ~1,5 Mb/s | ~2–3 Mb/s | ~0,15 |
| 540p60 | ~3 Mb/s | ~4–6 Mb/s | ~0,14 |
| 720p60 | ~5 Mb/s | ~7–10 Mb/s | ~0,13 |
| 1080p60 | ~10 Mb/s | ~15–20 Mb/s | ~0,12 |

- 120 fps : ×1,5 à ×1,7 (pas ×2). AV1 : environ −20 à −30 %. Jeux lents : −30 à −50 %.
- **Règle bpp** : sous ~0,10 bit/pixel, descendre d'un palier de résolution plutôt que garder
  la résolution avec un débit trop bas (l'image est meilleure, upscalée).
- **Débit réseau stable nécessaire ≈ 1,6 à 2 × le débit vidéo** (FEC ~20 %, overhead ~5 %,
  marge pour keyframes et variations radio). Confortable (720p60 → upscale) : ~15 Mb/s stables.
- Consommation data : ~6,7 Go/h à 15 Mb/s (à afficher dans le profil Économie).
- En mobile, **la gigue est le vrai ennemi, pas le débit**.

### Upscale FSR 1.0 sur Mali-G610 (sortie à la résolution du panneau)

| Sortie | EASU + RCAS (estimé) |
|---|---|
| 720p | ~1–2 ms |
| 1080p | ~2–4 ms |

- Facteur utile : 1,3× à 2× par axe. **Au-delà de 2×, l'image est pâteuse** : 360p n'est
  qu'un plancher de secours, pas un mode de jeu.
- Le vrai risque n'est pas le coût GPU mais **rater la fenêtre de vsync** (une frame perdue).
- Bilan latence souvent positif : moins de résolution = moins de bits par frame à transmettre,
  encodage et décodage plus rapides.

---

## 4. Profils

Un profil est une **politique** : il fixe les paramètres de lancement et la façon dont les
leviers client réagissent à la variance.

| | Compétitif | Équilibré (Auto, défaut) | Chill / Qualité | Économie | Manuel |
|---|---|---|---|---|---|
| Priorité | latence | compromis | fluidité, image | data, batterie | utilisateur |
| Buffer anti-gigue | 0–1 frame | adaptatif 1–2 | adaptatif jusqu'à 3–4 | adaptatif | fixe (actuel) |
| Frame en retard | jetée | jetée au-delà d'un seuil | affichée | affichée | comportement actuel |
| Choix au démarrage | plafond utilisateur, fps jamais réduits | palier selon réseau | palier selon réseau | plafond bas | paramètres figés |
| Upscale | bilinéaire ou EASU sans RCAS | FSR | FSR + RCAS piloté | FSR | au choix |

- Le profil **Manuel** = les réglages actuels de `OptionsSheet` / `StreamingPreferences`,
  inchangés. Ne pas casser la logique « profil console appliqué au premier démarrage
  seulement » (`ConsoleUi/streamProfileInitialized`, `CLAUDE.md` §2).
- Les profils Auto respectent un **plafond utilisateur** (ex. « jamais au-dessus de
  1080p/120/40 Mb/s »).
- Les fps sont plafonnés à la fréquence du panneau (165 fps sur un écran 120 Hz = débit perdu).
- Noms et libellés dans l'UI : langage console, aucun jargon (pas de « jitter buffer » à
  l'écran). Valider les libellés avec Coco.

---

## 5. Architecture cible (côté console)

```
           ┌──────────────────────┐   métriques    ┌───────────────────┐
 Session ─▶│ StreamHealthMonitor  │──────────────▶│ StreamController  │
 (couture) │  (capteur)           │               │ (politique =      │
           └──────────────────────┘               │  profil actif)    │
                                                   └────────┬──────────┘
                                                            │ ILever
                           ┌────────────────────────────────┼─────────────────────┐
                           ▼                                ▼                     ▼
                StartupLever (lancement)          ClientLevers (direct)    HostLevers
                résolution/fps/débit initiaux     buffer anti-gigue,       (FUTUR, non codé :
                via StreamingPreferences          frame en retard,         exige un hôte qui
                                                  upscale + RCAS           sait changer à chaud)
```

- **`StreamHealthMonitor`** : agrège sur fenêtres glissantes (1 s et 10 s), en **percentiles**
  (P50/P95) et EWMA, jamais en moyennes seules :
  - frames reçues / perdues réseau / en retard / jetées, temps de décodage, temps de rendu ;
  - RTT et variance (`LiGetEstimatedRttInfo`), événements `CONN_STATUS_POOR/OKAY` ;
  - **gigue d'arrivée des frames** (P95 de l'écart à l'intervalle nominal) ;
  - **gradient de délai** : écart entre intervalles d'envoi (timestamps RTP) et intervalles
    d'arrivée, filtré (principe du trendline filter de Google Congestion Control / WebRTC).
    Il détecte une file d'attente qui se remplit (bufferbloat 4G/5G) **avant** les pertes.
- **`StreamController`** : applique la politique du profil ; asymétrie **descendre vite,
  remonter lentement**, hystérésis, temps minimal entre deux changements.
- **`ILever`** : interface commune (appliquer une consigne, état courant, bornes). Le jour où
  l'hôte saura changer de débit à chaud, on branche `HostLevers` ici.
- Exposition QML : un **overlay de diagnostic** caché (combinaison de boutons à définir avec
  Coco), jamais visible en usage normal. Log CSV optionnel pour l'analyse.

---

## 6. Upscale FSR 1.0 — place dans la chaîne

```
décodage V4L2 (NV12, DMA-BUF) → texture EGL (zéro copie) → YUV→RGB
  → EASU (résolution du flux → résolution du panneau) → RCAS
  → composition de l'UI QML (native, nette) → DRM/KMS
```

- Sortie **toujours** à la résolution du panneau ; seule l'entrée change. Flux déjà natif :
  sauter EASU, RCAS léger seulement.
- **RCAS piloté par le débit** : sur vidéo compressée, l'affûtage renforce les macroblocs.
  Affûtage normal à débit confortable, réduit ou coupé à bas débit.
- Le HUD du jeu est upscalé avec l'image ; l'UI console ne l'est pas.
- **Où l'implémenter : décision à prendre en phase 0.** Options : dans le renderer de Moonlight
  (couture upstream) ou au niveau du compositeur (gamescope sait faire FSR, `CLAUDE.md` §3).
  Comparer coût, contrôle (RCAS piloté ?) et nombre de coutures.
- Rester en zéro copie : une copie CPU coûterait bien plus que FSR.

---

## 7. Phases (chacune se termine par un gate validé par Coco)

### Phase 0 — Audit (aucun code applicatif)
Livrable : `docs/stream/AUDIT.md`.
- Cartographier où les paramètres sont fixés (`StreamingPreferences`, `Session`,
  `STREAM_CONFIGURATION`) et comment `OptionsSheet` les écrit.
- Inventorier les statistiques déjà calculées (stats vidéo du décodeur, overlay de
  performances upstream, RTT, statut de connexion) et **l'accès aux timestamps RTP** par frame.
- Identifier le chemin de rendu réel sur RK3588S (GLES/EGL, DRM direct ?) et le point
  d'insertion possible de FSR ; comparer avec l'option gamescope.
- Lister ce qui existe déjà en réglages client (frame pacing, file de frames…) et réutilisable.
- **Lister les coutures nécessaires** (fichier, lignes, diff estimé) et proposer la plus petite.
- **Gate** : Coco valide la liste des coutures et le choix d'emplacement de FSR.

### Phase 1 — Modèle de profils
- Modèle + persistance (`ConsoleUi/streamProfile`, plafonds utilisateur), entrée dans
  `OptionsSheet` dans le langage « Ambiant ». Manuel = comportement actuel.
- **Gate** : tests unitaires/QML dans le harnais (`docs/ui/ambiant/harness/`), build vanilla
  intact, revue visuelle de Coco.

### Phase 2 — Télémétrie (`StreamHealthMonitor`)
- Capteur complet (§5), overlay de diagnostic caché, log CSV.
- Scripts `netem` reproductibles dans `docs/stream/netem/` (scénarios : Wi-Fi propre, Wi-Fi
  chargé, 4G moyenne, 4G dégradée, bufferbloat, coupure brève). Rappel : `netem` façonne la
  sortie d'une interface ; pour dégrader le **trafic entrant** de la console, passer par une
  interface `ifb`, ou appliquer `netem` sur le PC hôte / un routeur intermédiaire.
- **Gate** : les logs sous chaque scénario sont cohérents (le gradient de délai monte avant
  les pertes en scénario bufferbloat).

### Phase 3 — Anti-gigue adaptatif + politique de frame en retard
- Buffer de frames dont la taille suit la gigue P95 mesurée, borné par le profil ; politique
  « jeter / afficher au prochain vsync » selon le profil ; en cas de trou, **figer la
  dernière bonne image** plutôt qu'afficher une image corrompue.
- **Gate** : sous `netem`, moins de saccades (frames en retard / répétées) que la baseline de
  phase 2, **sans latence ajoutée sur réseau propre** en profil Compétitif. Puis ressenti
  validé par Coco à la manette.

### Phase 4 — Choix intelligent au démarrage
- Mémoire du dernier palier stable par réseau (SSID Wi-Fi ; cellulaire plus tard), court
  probe (RTT, gigue) avant le lancement, choix du palier dans les plafonds du profil.
  S'intègre au flux de lancement existant (`LaunchScreen`) sans écran supplémentaire.
- **Gate** : scénarios `netem` → palier attendu ; pas de délai de lancement perceptible
  ajouté (à mesurer).

### Phase 5 — FSR 1.0 + RCAS piloté
- Selon la décision de phase 0. Timers GPU (`GL_TIME_ELAPSED`) dans le log.
- **Gate** : temps GPU dans le budget, **aucune vsync ratée** à 60 et 120 Hz, validation
  visuelle de Coco (360p/540p/720p → panneau).

---

## 8. Hors périmètre (en attente d'une décision explicite de Coco)

- **Leviers hôte** (débit/résolution/fps en direct, intra-refresh, packet pacing, plafond
  VBV, FEC adaptative) : exigent un Apollo modifié. **Ne rien coder** tant que la règle
  no-fork tient.
- **Signaux radio du modem** (RSRP/RSRQ/SINR via ModemManager) pour anticiper les
  dégradations : côté console, mais seulement une fois le module 5G choisi et monté.
- **Super-résolution sur NPU** (RKNN) : piste R&D, à évaluer contre FSR (latence, conso,
  qualité à débit égal) seulement si FSR déçoit.
- **Multipath Wi-Fi + 4G** (duplication des paquets d'inputs) : plus tard.

### Critère de réouverture du no-fork
Si les tests réels en 4G/5G montrent que le choix au démarrage + l'anti-gigue ne suffisent
pas (saccades ou dérive de latence plusieurs fois par session), la question d'un patch Apollo
minimal (version pinnée + patch queue, upstream-first, compatibilité dans les deux sens) sera
rouverte, **chiffres de la télémétrie à l'appui**. Ce n'est pas à Claude Code de la trancher.
