<div align="center">

# 🎮 CocoOS

**Une console de jeu portable qui ne fait pas tourner les jeux — elle les _streame_.**

_Vous allumez, vous jouez. Aucun menu, aucun bureau, aucune friction._

[![Basé sur Moonlight](https://img.shields.io/badge/bas%C3%A9%20sur-Moonlight-5b8def)](https://github.com/moonlight-stream/moonlight-qt)
[![Licence GPLv3](https://img.shields.io/badge/licence-GPLv3-blue)](LICENSE)
![Statut](https://img.shields.io/badge/statut-prototype-f2802a)
![Cible](https://img.shields.io/badge/cible-RK3588S%20/%20Orange%20Pi%205B-333)
![Qt](https://img.shields.io/badge/Qt-6-41cd52)

</div>

---

**CocoOS** transforme un petit SoC ARM en **console de streaming de jeux vidéo**. Les jeux — même
les AAA gourmands — tournent sur votre **PC** ; la console, elle, se contente de **décoder le flux,
l'afficher et transmettre la manette**. Résultat : jouer à des jeux lourds sur un appareil léger, à
bonne autonomie, dès qu'on a une bonne connexion.

C'est un **fork de [moonlight-qt](https://github.com/moonlight-stream/moonlight-qt)** : on ne
réécrit pas le streaming, **on l'habille**. Tout le moteur éprouvé de Moonlight (décodage matériel,
réseau, manette) est conservé intact ; CocoOS ajoute une **couche console** — interface « Big
Picture » maison, démarrage direct, appairage invisible.

## ✨ Le principe directeur : zéro friction

L'expérience doit être aussi proche que possible d'une **vraie console**, pour un novice comme pour
un expert :

- 🚫 **Aucun menu Linux, aucune fenêtre, aucun bureau.** Jamais.
- ⚡ Au démarrage, la console **boote directement** sur l'interface de jeux et **se connecte toute
  seule** au PC.
- 🤝 L'**appairage est invisible** (code affiché sur le PC ou auto-accepté) — pas d'IP ni de réglage
  réseau à voir.
- 🕹️ **100 % navigable à la manette.** « J'allume, je joue. »

## 🧩 Comment ça marche

```
  PC HOST  (le muscle)                                  CocoOS  (le client léger)
  ┌───────────────────────────┐                        ┌───────────────────────────┐
  │ Apollo / Sunshine         │   flux vidéo H.264 /   │ décodage matériel         │
  │ Playnite (bibliothèque)   │ ───── HEVC / AV1 ────► │ affichage plein écran     │
  │ vos jeux Steam/Epic/GOG   │                        │ manette (RP2040 + Hall)   │
  │ rendu 3D + encodage       │ ◄──── entrées manette  │ RK3588S, ~5 W             │
  └───────────────────────────┘                        └───────────────────────────┘
          Wi-Fi 6   ·   5G (à venir)   ·   Tailscale (traversée du NAT)
```

Le PC fait le rendu 3D et encode ; CocoOS décode et affiche. La latence typique (~20–60 ms sur bon
réseau) est excellente pour les AAA solo.

## 🖥️ L'interface console

Une interface **« Big Picture »** maison (façon Steam), sombre et immersive, pensée **manette
d'abord**. Elle vit dans son propre dossier isolé `app/gui/console/` pour ne jamais diverger du
moteur Moonlight :

- **Carrousel horizontal** de jaquettes 16:9 — la sélection centrée, agrandie et cerclée d'orange.
- **État du PC affiché en permanence** (point vert + nom de l'hôte) : on voit d'un coup d'œil que
  tout marche, sans jamais voir d'IP.
- **Appairage plein écran** façon app TV, **écran Paramètres** au bouton Y (résolution / débit /
  « oublier ce PC »), **légende manette contextuelle** en bas.
- **Couche « Companion »** optionnelle : orchestration du lancement côté PC (mise à jour de jeu,
  écran virtuel) via une petite API compagnon, pour que « Jouer » démarre le bon jeu du premier coup.

## 🧬 L'ADN Moonlight

CocoOS hérite de **tout** le moteur de [Moonlight](https://moonlight-stream.org) :

- Décodage vidéo **matériel** — H.264, HEVC et **AV1**
- **HDR**, YUV 4:4:4, son surround **7.1**
- **Manette** avec retour de force et capteurs de mouvement
- Faible latence, réseau robuste, traversée du NAT via Tailscale

Compatible avec les hôtes **[Sunshine](https://github.com/LizardByte/Sunshine)** et
**[Apollo](https://github.com/ClassicOldSong/Apollo)** (le setup de développement tourne sous
Apollo). Moonlight existe aussi sur [Android](https://github.com/moonlight-stream/moonlight-android)
et [iOS](https://github.com/moonlight-stream/moonlight-ios).

Pour suivre le développement du moteur amont, rejoignez le
**[Discord Moonlight](https://moonlight-stream.org/discord)** ; pour aider à le traduire, passez par
**[Weblate](https://hosted.weblate.org/projects/moonlight/moonlight-qt/)**.

## 🔩 Le matériel

Carte de développement : **Orange Pi 5B (RK3588S)** — décodage AV1, GPU Mali-G610 (Panthor/Panfrost),
Wi-Fi 6 + BT 5.0, alim USB-C.

| Élément    | Prototype                              | Cible produit                     |
|------------|----------------------------------------|-----------------------------------|
| SoC        | Orange Pi 5B (RK3588S)                  | SoM RK3588S / carte porteuse custom |
| Écran      | HDMI IPS 5,5–6"                         | MIPI-DSI (AMOLED 7" envisagé)     |
| Manette    | RP2040 + GP2040-CE, joysticks à effet Hall | intégrée                       |
| Alimentation | power bank USB-C PD                   | batterie 2× 18650 + boost         |
| Mobilité   | Wi-Fi                                   | module **5G** (Quectel RM520N-GL) |

## 🗺️ État du projet

- [x] Concept de streaming validé (Moonlight + Sunshine + Tailscale, y compris en 5G)
- [x] Fork moonlight-qt, compilation et décodage matériel OK
- [x] Interface « Big Picture » conçue et intégrée au build (flag `embedded`)
- [x] UI branchée sur les vraies données Moonlight (hôtes, jeux, sessions)
- [x] Appairage automatique + Paramètres console + illusion « zéro bureau »
- [x] Couche Companion console ↔ host (découverte, appairage, bibliothèque, lancement)
- [ ] Mode kiosk : boot direct via gamescope / cage
- [ ] Bring-up hardware Orange Pi — valider le décodage **1080p60 sur RK3588S** (mainline + Panthor)
- [ ] Installeur host 1-clic (Apollo + Playnite + Tailscale + Wake-on-LAN)
- [ ] Version compacte (SoM, batterie, coque 3D), puis module **5G**

> **Statut : prototype logiciel avancé.** La couche console (interface, appairage, lancement) est
> fonctionnelle sur PC de dev ; l'étape suivante est le passage sur carte ARM.

## 🛠️ Construire CocoOS

CocoOS se construit comme Moonlight, avec un flag `embedded` qui active la couche console.

**Prérequis (Fedora / RPM Fusion) :**

```bash
sudo dnf install openssl-devel SDL2-devel SDL2_ttf-devel ffmpeg-devel \
  libva-devel libvdpau-devel opus-devel pulseaudio-libs-devel alsa-lib-devel \
  libdrm-devel qt6-qtsvg-devel qt6-qtdeclarative-devel qt6-qtwebsockets-devel
```

> Debian/Ubuntu ainsi que les prérequis Windows/macOS : voir le
> [README amont de Moonlight](https://github.com/moonlight-stream/moonlight-qt#building).
> `qt6-qtwebsockets-devel` est requis **en plus** par la couche Companion (build `embedded`).

**Compiler en mode console :**

```bash
git submodule update --init --recursive
qmake6 "CONFIG+=embedded" moonlight-qt.pro
make release -j$(nproc)
./app/moonlight     # démarre directement sur l'accueil console
```

Un `qmake6 moonlight-qt.pro` **sans** `embedded` produit le Moonlight vanilla intact — pratique
pour comparer le comportement de référence.

## 🤝 Contribuer

CocoOS est un projet DIY ouvert. Pour proposer une amélioration :

1. **Forkez** le dépôt
2. **Écrivez** votre code
3. **Ouvrez** une Pull Request

Convention n°1 : la couche console vit dans son dossier isolé `app/gui/console/` pour ne jamais
diverger du moteur Moonlight amont. Merci de garder toute contribution console dans ce périmètre et
de ne pas modifier les fichiers upstream, afin qu'on puisse continuer à suivre les mises à jour de
Moonlight sans douleur.

## 🙏 Crédits & licence

CocoOS est un fork de **[moonlight-stream/moonlight-qt](https://github.com/moonlight-stream/moonlight-qt)**
et n'existe que grâce au travail des communautés **Moonlight**, **Sunshine** et **Apollo**. Un immense
merci à elles — CocoOS n'est que l'habillage « console » de leur streaming.

Distribué sous **[GPLv3](LICENSE)**, comme Moonlight : toute version distribuée de CocoOS l'est avec
ses sources.
