<div align="center">

# CocoOS

A handheld game console that streams games from your PC instead of running them.

[![Based on Moonlight](https://img.shields.io/badge/based%20on-Moonlight-5b8def)](https://github.com/moonlight-stream/moonlight-qt)
[![License: GPLv3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)
![Status: prototype](https://img.shields.io/badge/status-prototype-f2802a)
![Target: RK3588S](https://img.shields.io/badge/target-RK3588S-333)
![Qt 6](https://img.shields.io/badge/Qt-6-41cd52)

</div>

## Overview

CocoOS turns a small ARM board into a dedicated game streaming console. Your PC renders and
encodes the game; the handheld decodes the video, shows it, and sends back controller input.
The goal is simple: play demanding PC games on a light, cheap, long-lasting device, at home
over Wi-Fi and eventually on the go over 5G.

The software is a fork of [moonlight-qt](https://github.com/moonlight-stream/moonlight-qt).
Moonlight already does the hard part (hardware decoding, low-latency networking, controller
support) and does it well, so CocoOS does not rewrite any of it. It adds a console layer on
top: a controller-first interface, direct boot into that interface, and pairing the user
never has to think about.

## Design principles

**Turn it on, play.** The device should feel like a console, not like a Linux computer
running a streaming app. No desktop, no windows, no IP addresses, no settings to get through
before the first game. It boots straight into the game library, finds the PC on its own, and
pairing happens once with a short code, the way a TV app does it.

**Dress the stream, don't rewrite it.** Moonlight's streaming engine is kept intact. Every
line of console code lives in its own directory (`app/gui/console/`), and the upstream files
are only touched at a handful of small, documented integration points. This keeps the fork
easy to rebase on new Moonlight releases.

**Two builds from one tree.** The console layer is compiled only with `CONFIG+=embedded`.
Without it, the tree builds an unmodified Moonlight, which stays useful as a reference.

**Honest about latency.** Streaming adds roughly 20 to 60 ms on a good network. That is
excellent for single-player games and depends heavily on the network for competitive ones.
The project does not pretend otherwise.

**Open by necessity and by choice.** Moonlight, Sunshine and Apollo are GPLv3, and so is
CocoOS. Any distributed build ships with its source. If this ever becomes a product, the
value lies in the hardware and the experience, not in closed software.

## How it works

```
  Host PC                                     CocoOS handheld
  Apollo or Sunshine (stream server)          hardware video decoding
  Playnite (game library)        -- video --> fullscreen display
  Steam, Epic, GOG, emulators    <-- input -- controller (RP2040, Hall-effect sticks)
  game rendering + encoding                   RK3588S SoC, about 5 W

             Wi-Fi 6  ·  5G (planned)  ·  Tailscale for remote access
```

A companion service on the host (developed in a separate repository, HostCompanion) handles
what Moonlight alone cannot: exporting the game library with artwork, launching the right
game, and applying game updates before the stream starts.

## The console interface

The home screen, called *Ambiant*, is designed to be driven entirely with a controller:

- The artwork of the selected game fills the screen, with its title in large type.
- A shelf of 16:9 thumbnails runs along the bottom; the selected game is underlined in orange.
- A status bar shows the connected host, the time, Wi-Fi strength and battery level.
- Stream options (resolution, frame rate, bitrate, codec, HDR) open in a side panel.
- Launching a game shows a full-screen launch screen while the host prepares it.
- Waiting, pairing and confirmation screens all follow the same visual language.

Design reference and a test harness that renders the interface without a host PC are in
[`docs/ui/ambiant/`](docs/ui/ambiant/).

## Hardware

Development board: Orange Pi 5B (RK3588S), chosen for AV1 hardware decoding, its Mali-G610
GPU, built-in Wi-Fi 6 and USB-C power.

| Component   | Prototype                                   | Product target                    |
|-------------|---------------------------------------------|-----------------------------------|
| SoC         | Orange Pi 5B (RK3588S)                      | RK3588S SoM on a custom carrier   |
| Display     | 5.5–6" HDMI IPS                             | MIPI-DSI panel (7" AMOLED considered) |
| Controls    | RP2040 with GP2040-CE, Hall-effect sticks   | integrated                        |
| Power       | USB-C PD power bank                         | 2× 18650 cells with boost converter |
| Connectivity| Wi-Fi                                       | 5G module (Quectel RM520N-GL)     |

## Status

CocoOS is an advanced software prototype. The console layer works end to end on a
development PC: host discovery, automatic pairing, the Ambiant home screen, launching through
the companion service, streaming, and returning to the home screen. The next milestone is
running it on the ARM board.

- [x] Streaming concept validated (Moonlight, Sunshine and Tailscale, including over 5G)
- [x] Fork builds, hardware decoding works (H.264, HEVC, AV1)
- [x] Console interface integrated behind the `embedded` build flag
- [x] Interface wired to real Moonlight data (hosts, apps, sessions)
- [x] Automatic pairing and console-style options and dialogs
- [x] Companion client: discovery, pairing, library, launch orchestration
- [x] Ambiant redesign of every screen
- [ ] Hands-on validation with a controller against a real host
- [ ] Kiosk mode: direct boot through gamescope or cage
- [ ] Board bring-up: 1080p60 hardware decoding on RK3588S (mainline kernel, Panthor)
- [ ] Stream profiles, adaptive jitter buffering and upscaling ([plan](docs/stream/STREAM-OPTIMISATION.md))
- [ ] One-click host installer (Apollo, Playnite, Tailscale, Wake-on-LAN)
- [ ] Compact hardware revision, then 5G

## Building

CocoOS builds like Moonlight, plus the `embedded` flag for the console layer.

Dependencies on Fedora (with RPM Fusion):

```bash
sudo dnf install openssl-devel SDL2-devel SDL2_ttf-devel ffmpeg-devel \
  libva-devel libvdpau-devel opus-devel pulseaudio-libs-devel alsa-lib-devel \
  libdrm-devel qt6-qtsvg-devel qt6-qtdeclarative-devel qt6-qtwebsockets-devel
```

`qt6-qtwebsockets-devel` is only needed by the console build. For other platforms, see the
[upstream build instructions](https://github.com/moonlight-stream/moonlight-qt#building).

Build and run the console version:

```bash
git submodule update --init --recursive
qmake6 "CONFIG+=embedded" moonlight-qt.pro
make release -j$(nproc)
./app/moonlight
```

Running `qmake6 moonlight-qt.pro` without the flag produces stock Moonlight.

## Repository layout

| Path | Contents |
|------|----------|
| `app/gui/console/` | The console layer: QML screens and C++ backends (companion client, system status) |
| `docs/ui/ambiant/` | Interface design brief, HTML prototype, test harness |
| `docs/stream/` | Stream optimisation plan |
| `CLAUDE.md` | Full project context and working rules (in French) |
| everything else | Moonlight upstream, kept as close to the original as possible |

## How this project is built

CocoOS is developed with heavy use of AI. Most of the code is written with
[Claude Code](https://claude.com/claude-code), working from the project context in
[`CLAUDE.md`](CLAUDE.md). The direction, architecture decisions, design, hardware choices and
every test on real hardware are done by a human, and changes are reviewed before they are
merged. AI makes it possible for one person to move a project of this size forward; it does
not replace testing with a controller in hand.

## Contributing

Issues and pull requests are welcome. One rule matters more than any other: keep console
code inside `app/gui/console/` and avoid modifying upstream Moonlight files, so the fork can
keep following Moonlight releases.

## Credits and license

CocoOS exists thanks to the work of the [Moonlight](https://moonlight-stream.org),
[Sunshine](https://github.com/LizardByte/Sunshine) and
[Apollo](https://github.com/ClassicOldSong/Apollo) projects. The streaming engine is theirs;
CocoOS is the console built around it. Questions about the engine itself belong on the
[Moonlight Discord](https://moonlight-stream.org/discord).

Licensed under the [GNU GPL v3](LICENSE), like Moonlight.
