#!/usr/bin/env python3
"""Génère les sons de l'interface (app/gui/console/sounds/*.wav).

Ce sont ceux du prototype, qui les synthétise à la volée (objet `Sound` de
ambiant-prototype.html) : on refait ici le même calcul que ses oscillateurs
WebAudio, une fois pour toutes, pour QSoundEffect. Version « Ambiant » : le son de
déplacement est une sinusoïde à 880 Hz.

    ./make-sounds.py

Les niveaux du prototype sont très bas (0,018 à 0,06 de la pleine échelle). Ils
sont multipliés par BOOST dans les fichiers pour ne pas perdre en précision, et
Theme.soundVolume (1 / BOOST par défaut) les ramène au niveau d'origine.
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
BOOST = 8
OUT = Path(__file__).resolve().parents[4] / "app" / "gui" / "console" / "sounds"

# nom -> liste de notes (fréquence, durée, options), comme Sound.play() du prototype.
# Options : gain, type ('sine' | 'triangle'), to (glissement de fréquence), at (départ différé).
SOUNDS = {
    "move":   [(880, 0.04, dict(gain=0.032))],
    "edge":   [(160, 0.09, dict(gain=0.06))],
    "select": [(660, 0.12, dict(gain=0.045)), (990, 0.18, dict(gain=0.04, at=0.07))],
    "back":   [(740, 0.10, dict(gain=0.04)), (494, 0.16, dict(gain=0.035, at=0.06))],
    "open":   [(520, 0.14, dict(gain=0.03, to=800))],
    "close":  [(760, 0.12, dict(gain=0.03, to=480))],
    "tick":   [(1800, 0.025, dict(gain=0.018, type="triangle"))],
    "launch": [(200, 1.8, dict(gain=0.018, to=620))],
    "ready":  [(880, 0.10, dict(gain=0.035)), (1320, 0.20, dict(gain=0.03, at=0.08))],
}
ATTACK = 0.006      # montée du gain
FLOOR = 0.0001      # gain de départ et d'arrivée (les rampes WebAudio sont exponentielles)
TAIL = 0.03         # l'oscillateur est coupé 30 ms après la fin de la note


def exp_ramp(v0, v1, x):
    """Valeur d'une rampe exponentielle WebAudio de v0 à v1, x allant de 0 à 1."""
    return v0 * (v1 / v0) ** x


def tone(buf, freq, dur, gain=0.04, type="sine", to=None, at=0.0):
    phase = 0.0
    start = round(at * RATE)
    for n in range(round((dur + TAIL) * RATE)):
        t = n / RATE
        f = exp_ramp(freq, to, min(t / dur, 1)) if to else freq
        phase += 2 * math.pi * f / RATE
        if t < ATTACK:
            g = exp_ramp(FLOOR, gain, t / ATTACK)
        elif t < dur:
            g = exp_ramp(gain, FLOOR, (t - ATTACK) / (dur - ATTACK))
        else:
            g = FLOOR
        s = math.sin(phase)
        if type == "triangle":
            s = 2 / math.pi * math.asin(s)
        buf[start + n] += g * s


for name, notes in SOUNDS.items():
    length = max(round((o.get("at", 0) + d + TAIL) * RATE) for _, d, o in notes)
    buf = [0.0] * length
    for freq, dur, opts in notes:
        tone(buf, freq, dur, **opts)
    peak = max(abs(s) for s in buf) * BOOST
    assert 0.05 < peak < 1, f"{name} : niveau {peak:.3f} hors plage"
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", round(s * BOOST * 32767)) for s in buf))
    print(f"{name:7s} {length / RATE * 1000:5.0f} ms  crête {peak:.3f}")
