# Matériel (ex-§6 de CLAUDE.md)

> Déplacé hors de `CLAUDE.md` (inutile pour le code au quotidien). Contenu repris tel quel.

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
