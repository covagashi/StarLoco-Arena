#!/usr/bin/env python3
"""S39: the spells' own sounds, synthesised (no library has elemental magic;
Kenney's CC0 packs cover the interface and the impacts). One sound per S37
effect shape and element (spells.json "fx": {"s": shape, "e": element}):
an element gives the texture —
  fire     crackle: band-passed noise with sparks
  water    bubbles: short rising sine chirps over a soft splash
  air      gust: noise through a sweeping band
  earth    thud: a low decaying sine and a gritty rumble
  neutral  shimmer: a few bright partials with a vibrato
— and a shape gives its envelope, length and pitch movement (a bolt flies
and lands, an area booms, a curse sinks, a heal rises, a teleport zips...).
Writes assets/audio/spells/<shape>_<element>.ogg (Vorbis, through ffmpeg).
Deterministic (seeded). Run from godot/: python3 tools/audio/spell_sfx.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
OUT = "assets/audio/spells"
SHAPES = ["aura", "bolt", "area", "curse", "hit", "summon", "heal", "tp", "trap"]
ELEMENTS = ["neutral", "fire", "water", "air", "earth"]
# shape → (seconds, pitch from, pitch to, attack share, gain)
SHAPE = {
    "bolt": (0.45, 0.8, 1.35, 0.08, 0.9), "hit": (0.22, 1.0, 0.8, 0.02, 1.0),
    "area": (0.9, 1.0, 0.7, 0.05, 1.0), "aura": (0.8, 0.85, 1.1, 0.45, 0.6),
    "curse": (0.7, 1.15, 0.6, 0.15, 0.8), "heal": (0.8, 0.9, 1.5, 0.3, 0.7),
    "summon": (0.75, 0.6, 1.3, 0.5, 0.8), "tp": (0.32, 1.6, 0.7, 0.1, 0.7),
    "trap": (0.3, 1.2, 1.0, 0.01, 0.8),
}


def lowpass(x, cutoff):
    """A one-pole low-pass, cutoff in Hz (array or scalar)."""
    c = np.broadcast_to(np.asarray(cutoff, float), x.shape)
    a = 1 - np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a[i] * (x[i] - s)
        y[i] = s
    return y


def band(x, lo, hi):
    return lowpass(x, hi) - lowpass(x, lo)


def resonant(x, centre, q=4.0):
    """A state-variable band-pass (Chamberlin), centre in Hz (array or
    scalar): a narrow, singing band where the one-pole pair is a wide one."""
    c = np.broadcast_to(np.asarray(centre, float), x.shape)
    f = 2 * np.sin(np.pi * np.minimum(c, SR / 6) / SR)
    damp = 1.0 / q
    low = bandp = 0.0
    y = np.empty_like(x)
    for i in range(len(x)):
        high = x[i] - low - damp * bandp
        bandp += f[i] * high
        low += f[i] * bandp
        y[i] = bandp
    return y


def env(n, attack, curve=3.0):
    """A rise over `attack` (share of n) then a decay to 0."""
    t = np.linspace(0, 1, n)
    a = max(attack, 1e-3)
    up = np.clip(t / a, 0, 1)
    down = np.clip((1 - t) / (1 - a), 0, 1) ** curve
    return np.where(t < a, up, down)


def sweep(n, p0, p1):
    return p0 * (p1 / p0) ** np.linspace(0, 1, n)


def element(e, n, pitch, rng):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    if e == "fire":
        crackle = resonant(noise, 1400 * pitch, 1.5) * .7
        sparks = np.zeros(n)
        for i in rng.integers(0, n, size=max(4, n // 900)):
            k = min(n - i, 180)
            sparks[i:i + k] += rng.uniform(.4, 1) * np.exp(-np.arange(k) / 25) * rng.choice([-1, 1])
        roar = lowpass(noise, 300 * pitch) * 2.5
        return crackle * .8 + band(sparks, 1500, 6000) * 1.4 + roar
    if e == "water":
        out = lowpass(noise, 900 * pitch) * .9
        for _ in range(max(5, n // 2500)):
            i = rng.integers(0, max(1, n - 2400))
            k = int(rng.uniform(.03, .07) * SR)
            k = min(k, n - i)
            f = sweep(k, rng.uniform(300, 700) * pitch, rng.uniform(900, 1600) * pitch)
            ph = 2 * np.pi * np.cumsum(f) / SR
            out[i:i + k] += np.sin(ph) * np.exp(-np.arange(k) / (k / 3)) * .6
        return out
    if e == "air":
        f = sweep(n, 300 * pitch, 2400 * pitch) * (1 + .15 * np.sin(2 * np.pi * 3 * t))
        return resonant(noise, f, 6.0) * 1.2
    if e == "earth":
        f = sweep(n, 95 * pitch, 48 * pitch)
        thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / .18) * 1.6
        grit = resonant(noise, 180 * pitch, 2.0) * .8 + lowpass(noise, 350) * .9
        return thud + grit
    # neutral: a shimmer of partials with a vibrato
    vib = 1 + .012 * np.sin(2 * np.pi * 6 * t)
    out = np.zeros(n)
    for k, amp in ((1, 1), (1.5, .55), (2, .4), (3, .2)):
        out += np.sin(2 * np.pi * np.cumsum(np.full(n, 660 * pitch * k) * vib) / SR) * amp
    return out * .45 + band(noise, 2000, 7000) * .25


def shape_sound(s, e, seed):
    rng = np.random.default_rng(seed)
    dur, p0, p1, att, gain = SHAPE[s]
    n = int(dur * SR)
    pitch = sweep(n, p0, p1).mean()
    body = element(e, n, pitch, rng)
    # the pitch movement, as a moving filter over the body
    top = {"earth": 900, "water": 3000, "fire": 4500, "air": 6000, "neutral": 7000}[e]
    move = lowpass(body, sweep(n, top * .5 * p0, top * p1))
    x = (body * .35 + move * .9) * env(n, att)
    if s == "bolt":      # flies, then lands with a small knock
        k = int(.08 * SR)
        knock = lowpass(rng.standard_normal(k), 700) * np.exp(-np.arange(k) / 300) * 2.2
        x[n - k:] += knock
    elif s == "area":    # a low boom under it
        b = np.sin(2 * np.pi * np.cumsum(sweep(n, 70, 38)) / SR) * np.exp(-np.arange(n) / SR / .3)
        x += b * 1.2
    elif s == "heal":    # a rising arpeggio of chimes
        for j, f in enumerate((880, 1109, 1319, 1760)):
            i = int(j * n / 6)
            k = n - i
            x[i:] += np.sin(2 * np.pi * f * np.arange(k) / SR) * np.exp(-np.arange(k) / SR / .18) * .35
    elif s == "summon":  # a pop at the top
        k = int(.06 * SR)
        x[n - k:] += np.sin(2 * np.pi * 420 * np.arange(k) / SR) * np.exp(-np.arange(k) / 250) * .9
    elif s == "trap":    # a snap at the start
        k = int(.03 * SR)
        x[:k] += band(rng.standard_normal(k), 1500, 8000) * 3
    x = np.tanh(x * 1.4) * gain     # soft limit
    fade = min(len(x), int(.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x / max(1e-6, np.abs(x).max()) * .85 * gain


def write_ogg(path, x):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.remove(tmp)


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for i, s in enumerate(SHAPES):
        for j, e in enumerate(ELEMENTS):
            p = f"{OUT}/{s}_{e}.ogg"
            write_ogg(p, shape_sound(s, e, 1000 + i * 10 + j))
            total += os.path.getsize(p)
    print(f"{len(SHAPES) * len(ELEMENTS)} spell sounds in {OUT}, {total // 1024} KB")


if __name__ == "__main__":
    main()
