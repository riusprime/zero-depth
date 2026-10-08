#!/usr/bin/env python3
"""Renders the game's synthesised sound effects and biome ambience (PLAN v0.3.0 L27, workstream AU).

Every sound is original: built here from oscillators, FM, filtered noise, pitch sweeps, bitcrush and short echo
tails, in the style the owner asked for (robotic, synthy, slightly echoey). Nothing is sampled or downloaded.

    python3 scripts/audio/generate_sfx.py            # writes assets/audio/{sfx,ambience}/*.wav + manifest.json
    python3 scripts/audio/generate_sfx.py --check    # renders in memory, exits 1 if a file differs from disk

Output: mono, 44.1 kHz, 16-bit PCM WAV. SFX peak at -1 dBFS, ambience at -6 dBFS. Ambience files are seamless
loops: every partial and LFO completes whole cycles over the loop, noise is shaped in the frequency domain (circular)
and echoes wrap around, so the last sample runs into the first. The render is deterministic: each sound's noise
comes from a seed derived from its id (crc32), so the same version of this script always writes the same bytes.

Needs numpy (pip install numpy). Bump GENERATOR_VERSION whenever a recipe changes the output.
"""

import argparse
import hashlib
import json
import os
import struct
import sys
import wave
import zlib

import numpy as np

GENERATOR_VERSION = 2
RATE = 44100
SFX_PEAK = 10 ** (-1.0 / 20.0)
AMB_PEAK = 10 ** (-6.0 / 20.0)
AMB_SECONDS = 10.0
LICENCE = "Original work generated for this project by scripts/audio/generate_sfx.py (no third-party audio)"

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_SFX = os.path.join(ROOT, "assets", "audio", "sfx")
OUT_AMB = os.path.join(ROOT, "assets", "audio", "ambience")
MANIFEST = os.path.join(ROOT, "assets", "audio", "manifest.json")

# --- building blocks ---------------------------------------------------------------------------------------------


def rng_for(sound_id):
    return np.random.RandomState(zlib.crc32(sound_id.encode("utf-8")) & 0x7FFFFFFF)


def n_of(seconds):
    return int(round(seconds * RATE))


def times(seconds):
    return np.arange(n_of(seconds)) / RATE


def curve(a, b, n, shape="exp"):
    """A sweep from a to b over n samples: exponential (pitch) or linear."""
    x = np.linspace(0.0, 1.0, n, endpoint=False)
    if shape == "exp" and a > 0 and b > 0:
        return a * (b / a) ** x
    return a + (b - a) * x


def phase(freq):
    """Accumulated phase (radians) for a per-sample frequency array."""
    return 2.0 * np.pi * np.cumsum(freq) / RATE


def osc(freq, wave_kind="sine", n=None):
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    ph = phase(freq)
    if wave_kind == "sine":
        return np.sin(ph)
    frac = (ph / (2.0 * np.pi)) % 1.0
    if wave_kind == "saw":
        return 2.0 * frac - 1.0
    if wave_kind == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if wave_kind == "tri":
        return 4.0 * np.abs(frac - 0.5) - 1.0
    raise ValueError(wave_kind)


def fm(carrier, ratio, index, n):
    """Two-operator FM: a sine carrier whose phase a sine modulator (carrier x ratio) pushes by index (array ok)."""
    if np.isscalar(carrier):
        carrier = np.full(n, float(carrier))
    mod = np.sin(phase(carrier * ratio))
    return np.sin(phase(carrier) + index * mod)


def env(n, attack=0.005, decay=0.2, curve_pow=1.0):
    """Linear attack, exponential-ish decay to silence by the end."""
    a = max(1, n_of(attack))
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a, endpoint=False)
    rest = n - a
    if rest > 0:
        k = np.arange(rest) / RATE
        tail = np.exp(-k / max(decay, 1e-4))
        fade = np.linspace(1.0, 0.0, rest) ** curve_pow  # reaches exactly 0 at the end
        e[a:] = tail * fade
    return e


def one_pole_lp(x, cutoff):
    """One-pole low-pass; cutoff may be an array (a filter sweep)."""
    cut = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1.0 - np.exp(-2.0 * np.pi * cut / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def one_pole_hp(x, cutoff):
    return x - one_pole_lp(x, cutoff)


def bandpass(x, centre, q=4.0):
    """State-variable band-pass; centre may sweep (array)."""
    c = np.broadcast_to(np.asarray(centre, dtype=float), x.shape)
    f = 2.0 * np.sin(np.pi * np.minimum(c, RATE / 6.0) / RATE)
    damp = 1.0 / q
    low = band = 0.0
    y = np.empty_like(x)
    for i in range(len(x)):
        high = x[i] - low - damp * band
        band += f[i] * high
        low += f[i] * band
        y[i] = band
    return y


def bitcrush(x, bits=8, hold=1):
    """Fewer amplitude steps and a sample-and-hold (lower effective rate): the robotic grit."""
    steps = 2 ** (bits - 1)
    y = np.round(x * steps) / steps
    if hold > 1:
        idx = (np.arange(len(y)) // hold) * hold
        y = y[idx]
    return y


def echo(x, delay_ms=110.0, feedback=0.35, mix=0.35, damp=3500.0, tail=0.4):
    """A short feedback delay with a darkening repeat, the 'slightly echoey' tail. Adds `tail` seconds."""
    d = max(1, n_of(delay_ms / 1000.0))
    out = np.concatenate([x, np.zeros(n_of(tail))])
    wet = np.zeros_like(out)
    buf = out.copy()
    gain = 1.0
    for k in range(1, 12):
        gain *= feedback
        if gain < 0.01 or d * k >= len(out):
            break
        shifted = np.zeros_like(out)
        shifted[d * k :] = buf[: len(out) - d * k]
        wet += gain * shifted
    wet = one_pole_lp(wet, damp)
    y = out + mix * wet / max(feedback, 1e-3)
    return fade_tail(y, 0.03)


def fade_tail(x, seconds):
    n = min(len(x), n_of(seconds))
    if n > 0:
        x = x.copy()
        x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def noise(r, n):
    return r.uniform(-1.0, 1.0, n)


def pad_to(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[: max(n, len(x))]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, seconds, total=None):
    """x delayed by `seconds` (silence before)."""
    y = np.concatenate([np.zeros(n_of(seconds)), x])
    return pad_to(y, total) if total else y


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


# --- the sounds --------------------------------------------------------------------------------------------------


def whoosh(r, seconds, f0, f1, q=3.0, decay=0.12):
    n = n_of(seconds)
    return bandpass(noise(r, n), curve(f0, f1, n), q) * env(n, 0.012, decay)


def metal_ping(seconds, freq, ratio=1.41, index=2.5, decay=0.08):
    n = n_of(seconds)
    idx = index * env(n, 0.001, decay * 0.6)
    return fm(freq, ratio, idx, n) * env(n, 0.001, decay)


# v0.3.5 F17 (owner: "sounds from sword are too overwhelming"): every blade swing is one layer (the whoosh; the
# metal ping and the spin's chord and thud are gone), shorter (the whoosh and its echo tail roughly halved), with a
# single quiet repeat. The -8 dB is in the cues (data/audio/cues/blade_*.tres, enemy_hit.tres), because every file
# here is peak-normalised.
def blade_slash(r, f0, f1):
    w = whoosh(r, 0.15, f0, f1, 2.5, 0.045)
    return echo(w, 55, 0.2, 0.15, 3500, 0.06)


def s_blade_slash_1(r):
    return blade_slash(r, 5200, 1400)


def s_blade_slash_2(r):
    return blade_slash(r, 1500, 5600)


def s_blade_slash_3(r):
    w = whoosh(r, 0.18, 4200, 900, 2.0, 0.055)
    return echo(w, 60, 0.2, 0.15, 3200, 0.07)


def s_blade_thrust(r):
    n = n_of(0.12)
    burst = one_pole_hp(noise(r, n), curve(800, 6000, n)) * env(n, 0.003, 0.035)
    return echo(burst, 50, 0.2, 0.15, 4000, 0.06)


def s_blade_spin(r):
    n = n_of(0.32)
    t = np.arange(n) / RATE
    centre = 1800 + 1300 * np.sin(2 * np.pi * 9.0 * t)
    w = bandpass(noise(r, n), centre, 3.0) * env(n, 0.02, 0.12) * (0.7 + 0.3 * np.sin(2 * np.pi * 14.0 * t))
    return echo(w, 70, 0.2, 0.15, 3000, 0.08)


def s_bolt_fire(r):
    n = n_of(0.16)
    zap = osc(curve(1500, 260, n), "square", n) * env(n, 0.002, 0.05)
    zap = bitcrush(one_pole_lp(zap, 5000), 6, 3)
    click = noise(r, n_of(0.01)) * 0.5
    return echo(mix(zap * 0.7, click), 90, 0.32, 0.3, 3000, 0.22)


def s_enemy_fire(r):
    n = n_of(0.2)
    zap = osc(curve(700, 140, n), "saw", n) * env(n, 0.002, 0.07)
    zap = bitcrush(one_pole_lp(zap, 3000), 5, 4)
    return echo(zap * 0.8, 100, 0.3, 0.3, 2500, 0.22)


def s_bolt_hit(r):
    n = n_of(0.12)
    thump = osc(curve(900, 180, n), "sine") * env(n, 0.001, 0.035)
    crack = one_pole_hp(noise(r, n_of(0.03)), 2500) * env(n_of(0.03), 0.001, 0.01)
    return echo(bitcrush(mix(thump, crack * 0.6), 7, 2), 55, 0.25, 0.2, 4000, 0.1)


def s_hit_taken(r):
    n = n_of(0.3)
    body = osc(curve(190, 55, n), "saw", n) * env(n, 0.002, 0.1)
    crunch = bandpass(noise(r, n), curve(2500, 600, n), 1.5) * env(n, 0.001, 0.06)
    x = soft_clip(mix(body * 0.8, crunch * 0.9), 2.5)
    return echo(bitcrush(x, 5, 3), 85, 0.3, 0.3, 2500, 0.25)


def s_enemy_hit(r):
    tick = metal_ping(0.1, 620, 2.71, 3.0, 0.025)
    n = n_of(0.04)
    grit = one_pole_hp(noise(r, n), 1500) * env(n, 0.001, 0.012)
    return echo(mix(tick * 0.8, grit * 0.5), 50, 0.25, 0.18, 4000, 0.1)


def s_guard_block(r):
    bell = metal_ping(0.35, 1180, 3.5, 5.0, 0.12)
    n = n_of(0.05)
    clank = bandpass(noise(r, n), 3000, 2.0) * env(n, 0.001, 0.015)
    return echo(mix(bell * 0.7, clank), 75, 0.35, 0.3, 4500, 0.3)


def death(r, f0, f1, seconds, crush, ring=0.0, chirp=False):
    n = n_of(seconds)
    body = osc(curve(f0, f1, n), "saw", n) * env(n, 0.003, seconds * 0.3)
    burst = bandpass(noise(r, n), curve(3000, 400, n), 1.2) * env(n, 0.001, seconds * 0.15)
    parts = [body * 0.6, burst * 0.7]
    if ring:
        parts.append(metal_ping(seconds, ring, 1.73, 4.0, seconds * 0.25) * 0.35)
    if chirp:
        for k in range(4):
            c = osc(curve(3200 - 500 * k, 1200 - 200 * k, n_of(0.05)), "square") * env(n_of(0.05), 0.001, 0.02)
            parts.append(at(c * 0.25, 0.04 + 0.06 * k))
    x = bitcrush(soft_clip(mix(*parts), 1.8), crush, 3)
    return echo(x, 110, 0.35, 0.3, 2500, 0.35)


def s_enemy_death_charger(r):
    return death(r, 420, 60, 0.45, 5)


def s_enemy_death_warden(r):
    return death(r, 260, 40, 0.6, 6, ring=330)


def s_enemy_death_needle(r):
    return death(r, 900, 200, 0.35, 5, chirp=True)


def s_enemy_death_hatchling(r):
    n = n_of(0.18)
    squelch = bandpass(noise(r, n), curve(1800, 500, n), 6.0) * env(n, 0.002, 0.05)
    pip = osc(curve(1400, 500, n), "tri") * env(n, 0.001, 0.04) * 0.5
    return echo(bitcrush(mix(squelch, pip), 6, 2), 70, 0.25, 0.22, 3000, 0.15)


def s_enemy_windup(r):
    n = n_of(0.3)
    t = np.arange(n) / RATE
    tone = osc(curve(300, 720, n), "square", n) * (0.6 + 0.4 * np.sin(2 * np.pi * 24 * t))
    tone = one_pole_lp(tone, 2200) * env(n, 0.04, 0.2)
    return echo(bitcrush(tone, 6, 2) * 0.7, 95, 0.3, 0.3, 2500, 0.2)


# v0.3.5 AI: the Arc Caster and the Bomb Drone.
def s_enemy_death_arc_caster(r):
    return death(r, 1200, 140, 0.45, 5, ring=880, chirp=True)


def s_enemy_death_bomb_drone(r):
    n = n_of(0.5)
    whine = osc(curve(1600, 180, n), "saw", n) * env(n, 0.002, 0.3) * 0.4
    pop = bandpass(noise(r, n), curve(2400, 300, n), 1.0) * env(n, 0.001, 0.12)
    x = bitcrush(soft_clip(mix(whine, pop), 1.6), 5, 3)
    return echo(x, 100, 0.3, 0.28, 2400, 0.3)


def s_enemy_death_lens_drone(r):
    """v0.4.0 BO: a Lens Drone popping: a falling glassy chirp and a crackle."""
    n = n_of(0.45)
    chirp = osc(curve(2200, 260, n), "sine") * env(n, 0.002, 0.25) * 0.5
    crackle = bandpass(noise(r, n), 3200, 3.0) * env(n, 0.001, 0.08)
    x = bitcrush(mix(chirp, crackle), 6, 2)
    return echo(x, 90, 0.3, 0.28, 3000, 0.3)


def s_arc_bolt(r):
    n = n_of(0.22)
    zap = osc(curve(2600, 500, n), "square", n) * env(n, 0.001, 0.08)
    crackle = bandpass(noise(r, n), 3800, 2.0) * env(n, 0.001, 0.06)
    x = bitcrush(mix(zap * 0.5, crackle * 0.6), 6, 2)
    return echo(x, 80, 0.25, 0.25, 4000, 0.15)


def s_rune_erupt(r):
    n = n_of(0.45)
    thump = osc(curve(160, 45, n), "sine", n) * env(n, 0.002, 0.2)
    shimmer = fm(curve(900, 1400, n), 2.01, 3.0, n) * env(n, 0.005, 0.25) * 0.35
    burst = bandpass(noise(r, n), curve(2500, 600, n), 1.5) * env(n, 0.001, 0.1) * 0.5
    return echo(soft_clip(mix(thump, shimmer, burst), 1.5), 120, 0.3, 0.3, 2500, 0.3)


def s_bomb_lob(r):
    n = n_of(0.3)
    whistle = osc(curve(700, 1500, n), "tri", n) * env(n, 0.02, 0.22) * 0.5
    thunk = osc(curve(220, 90, n_of(0.06)), "square") * env(n_of(0.06), 0.001, 0.03)
    return echo(bitcrush(mix(whistle, thunk), 7, 2), 90, 0.25, 0.22, 3000, 0.15)


def s_bomb_blast(r):
    n = n_of(0.7)
    boom = osc(curve(120, 30, n), "sine", n) * env(n, 0.002, 0.35)
    debris = one_pole_lp(noise(r, n), 1800) * env(n, 0.001, 0.25)
    x = bitcrush(soft_clip(mix(boom, debris * 0.8), 2.2), 6, 3)
    return echo(x, 140, 0.35, 0.3, 1800, 0.4)


# v0.4.0 EN: the horde kinds.
def s_enemy_death_swarmer(r):
    n = n_of(0.14)
    crunch = bandpass(noise(r, n), curve(4200, 1200, n), 5.0) * env(n, 0.001, 0.03)
    pip = osc(curve(2200, 900, n), "square", n) * env(n, 0.001, 0.03) * 0.3
    return echo(bitcrush(mix(crunch, pip), 6, 2), 60, 0.2, 0.18, 3500, 0.1)


def s_enemy_death_splitter(r):
    n = n_of(0.4)
    tear = bandpass(noise(r, n), curve(600, 2400, n), 3.0) * env(n, 0.004, 0.14)
    halves = mix(osc(curve(300, 120, n), "saw", n), osc(curve(360, 150, n), "saw", n)) * env(n, 0.002, 0.12) * 0.35
    return echo(bitcrush(soft_clip(mix(tear, halves), 1.4), 6, 2), 90, 0.3, 0.25, 2800, 0.25)


def s_enemy_death_shield_bearer(r):
    return death(r, 220, 35, 0.6, 6, ring=410)


def s_enemy_death_mender(r):
    n = n_of(0.5)
    fall = fm(curve(1400, 350, n), 1.5, 2.0, n) * env(n, 0.003, 0.2) * 0.6
    sparkle = bandpass(noise(r, n), 5200, 3.0) * env(n, 0.002, 0.12) * 0.4
    return echo(mix(fall, sparkle), 110, 0.35, 0.3, 4000, 0.3)


def s_enemy_death_mine_layer(r):
    return death(r, 520, 70, 0.5, 5, ring=600)


def s_enemy_death_sniper(r):
    return death(r, 1500, 220, 0.4, 5, chirp=True)


def s_sniper_shot(r):
    n = n_of(0.5)
    crack = one_pole_hp(noise(r, n), 1500) * env(n, 0.0005, 0.03)
    boom = osc(curve(240, 60, n), "sine", n) * env(n, 0.001, 0.12) * 0.8
    whine = osc(curve(3800, 1800, n), "tri", n) * env(n, 0.001, 0.08) * 0.25
    return echo(soft_clip(mix(crack, boom, whine), 1.8), 150, 0.35, 0.3, 3000, 0.35)


def s_mine_arm(r):
    x = mix(*[at(osc(1760.0, "square", n_of(0.05)) * env(n_of(0.05), 0.001, 0.02), k * 0.09) for k in range(3)])
    return echo(bitcrush(x * 0.6, 7, 2), 70, 0.25, 0.2, 4000, 0.1)


def s_mine_blast(r):
    n = n_of(0.6)
    boom = osc(curve(150, 35, n), "sine", n) * env(n, 0.002, 0.25)
    grit = one_pole_lp(noise(r, n), 2600) * env(n, 0.001, 0.16)
    x = bitcrush(soft_clip(mix(boom, grit * 0.7), 2.0), 6, 3)
    return echo(x, 120, 0.3, 0.28, 2000, 0.35)


def s_shield_bash(r):
    n = n_of(0.35)
    clang = metal_ping(0.35, 240.0, 1.37, 3.0, 0.1) * 0.6
    thud = osc(curve(130, 55, n), "sine", n) * env(n, 0.002, 0.07)
    scrape = bandpass(noise(r, n), 1600, 2.0) * env(n, 0.002, 0.05) * 0.4
    return echo(mix(clang, thud, scrape), 80, 0.25, 0.22, 3000, 0.2)


def s_mender_heal(r):
    x = notes((659.25, 987.77), 0.06, 0.12, "tri", 0.03, 6000) * 0.4
    n = len(x)
    shimmer = fm(np.full(n, 1318.5), 2.0, 1.2, n) * env(n, 0.02, 0.1) * 0.25
    return echo(mix(x, shimmer), 100, 0.3, 0.3, 5000, 0.2)


def s_player_death(r):
    n = n_of(1.1)
    fall = osc(curve(520, 40, n), "saw", n)
    crushed = np.concatenate(
        [bitcrush(seg, b, h) for seg, b, h in zip(np.array_split(fall, 5), (8, 7, 6, 5, 4), (1, 2, 3, 5, 8))]
    )
    body = one_pole_lp(crushed, curve(6000, 600, n)) * env(n, 0.005, 0.5)
    hit = s_hit_taken(r)[: n_of(0.25)]
    return echo(mix(hit, body * 0.7), 160, 0.45, 0.4, 2000, 0.8)


def s_dash(r):
    w = whoosh(r, 0.2, 600, 3200, 1.8, 0.06)
    n = n_of(0.12)
    thump = osc(curve(140, 60, n), "sine") * env(n, 0.002, 0.04) * 0.5
    return echo(mix(w, thump), 70, 0.25, 0.22, 3500, 0.15)


def s_blink_out(r):
    n = n_of(0.24)
    idx = curve(1.0, 6.0, n, "lin")
    sweep = fm(curve(400, 2400, n), 1.5, idx, n) * env(n, 0.01, 0.12)
    shimmer = one_pole_hp(noise(r, n), 5000) * env(n, 0.02, 0.06) * 0.25
    return echo(mix(sweep * 0.6, shimmer), 90, 0.4, 0.35, 5000, 0.3)


def s_blink_in(r):
    n = n_of(0.22)
    sweep = fm(curve(2400, 500, n), 1.5, curve(6.0, 1.0, n, "lin"), n) * env(n, 0.002, 0.08)
    click = noise(r, n_of(0.008)) * 0.6
    return echo(mix(click, sweep * 0.6), 90, 0.4, 0.35, 5000, 0.3)


def notes(freqs, step, length, wave_kind="square", decay=0.05, lp=4000):
    parts = []
    for k, f in enumerate(freqs):
        n = n_of(length)
        tone = one_pole_lp(osc(f, wave_kind, n), lp) * env(n, 0.002, decay)
        parts.append(at(tone, k * step))
    return mix(*parts)


def s_item_pickup(r):
    arp = notes((523.25, 659.25, 783.99, 1046.5), 0.055, 0.12, "square", 0.04)
    return echo(bitcrush(arp, 7, 1) * 0.6, 110, 0.4, 0.35, 4000, 0.35)


def s_altar_open(r):
    n = n_of(0.8)
    pad = sum(osc(f, "sine", n) * (0.5 if f < 600 else 0.3) for f in (293.66, 440.0, 587.33, 880.0))
    pad = pad * env(n, 0.25, 0.35)
    shimmer = bandpass(noise(r, n), curve(3000, 7000, n), 8.0) * env(n, 0.2, 0.3) * 0.4
    return echo(mix(pad * 0.4, shimmer), 140, 0.45, 0.4, 4000, 0.5)


def s_chest_open(r):
    clicks = mix(*[at(bandpass(noise(r, n_of(0.02)), 2500, 3.0) * env(n_of(0.02), 0.001, 0.006), k * 0.07) for k in range(3)])
    n = n_of(0.45)
    chime = fm(curve(500, 1500, n), 2.0, curve(3.0, 0.5, n, "lin"), n) * env(n, 0.03, 0.18) * 0.5
    return echo(mix(clicks, at(chime, 0.2)), 120, 0.4, 0.35, 4000, 0.4)


def s_chest_refuse(r):
    buzz = notes((220.0, 164.81), 0.11, 0.1, "square", 0.08, 1200)
    return echo(bitcrush(buzz, 5, 4) * 0.7, 80, 0.25, 0.2, 2000, 0.15)


def s_shop_open(r):
    # v0.5.0 SH: the terminal wakes: a rising two-note chirp over a soft relay click.
    click = bandpass(noise(r, n_of(0.025)), 1800, 3.0) * env(n_of(0.025), 0.001, 0.008)
    chirp = notes((392.0, 587.33), 0.07, 0.16, "tri", 0.06, 5000) * 0.5
    return echo(mix(click * 0.6, at(chirp, 0.03)), 90, 0.3, 0.3, 5000, 0.25)


def s_shop_buy(r):
    # v0.5.0 SH: a register: a short coin rattle, then a bright two-tone ka-ching.
    rattle = mix(*[at(bandpass(noise(r, n_of(0.018)), 5200, 5.0) * env(n_of(0.018), 0.001, 0.006), k * 0.035) for k in range(3)])
    ding = mix(metal_ping(0.4, 1318.5, 1.5, 1.8, 0.12) * 0.45, at(metal_ping(0.35, 1975.5, 1.5, 1.4, 0.1) * 0.35, 0.07))
    return echo(mix(rattle * 0.5, at(ding, 0.09)), 100, 0.35, 0.3, 6000, 0.3)


def s_shop_sell(r):
    # v0.5.0 SH: salvage: a falling clink and a low thunk as the part drops into the hopper.
    clink = mix(metal_ping(0.25, 1567.98, 1.41, 1.6, 0.07) * 0.35, at(metal_ping(0.25, 1174.66, 1.41, 1.6, 0.07) * 0.35, 0.06))
    n = n_of(0.18)
    thunk = one_pole_lp(osc(curve(160, 70, n), "sine", n), 900) * env(n, 0.002, 0.07) * 0.7
    return echo(mix(clink, at(thunk, 0.12)), 90, 0.3, 0.25, 4000, 0.25)


def s_shard_collect(r):
    n = n_of(0.06)
    blip = osc(curve(1800, 2600, n), "sine") * env(n, 0.001, 0.02)
    return echo(blip * 0.6, 45, 0.3, 0.25, 6000, 0.08)


def s_combo_unlock(r):
    arp = notes((392.0, 523.25, 659.25, 783.99, 1046.5), 0.07, 0.16, "square", 0.05, 5000) * 0.5
    n = n_of(0.7)
    bell = sum(metal_ping(0.7, f, 3.5, 2.0, 0.25) for f in (1046.5, 1318.5, 1568.0)) * 0.2
    return echo(mix(bitcrush(arp, 7, 1), at(bell, 0.35)), 130, 0.45, 0.4, 4500, 0.6)


def s_heat_threshold(r):
    tones = notes((660.0, 990.0), 0.08, 0.12, "square", 0.05, 3000)
    return echo(bitcrush(tones, 6, 2) * 0.6, 90, 0.3, 0.3, 3000, 0.2)


def s_heat_overheat(r):
    n = n_of(0.7)
    t = np.arange(n) / RATE
    warble = osc(700 + 250 * np.sign(np.sin(2 * np.pi * 7.5 * t)), "square", n) * env(n, 0.005, 0.35)
    sizzle = one_pole_hp(noise(r, n), 4000) * env(n, 0.02, 0.25) * 0.4
    return echo(bitcrush(mix(one_pole_lp(warble, 2500) * 0.5, sizzle), 5, 3), 120, 0.35, 0.3, 2500, 0.3)


def s_heat_vent(r):
    n = n_of(0.5)
    hiss = one_pole_hp(noise(r, n), curve(6000, 1500, n)) * env(n, 0.005, 0.18)
    whomp = osc(curve(120, 45, n_of(0.3)), "sine") * env(n_of(0.3), 0.003, 0.09)
    return echo(mix(hiss * 0.7, whomp * 0.8), 110, 0.35, 0.3, 3000, 0.3)


def s_boss_telegraph(r):
    """The generic warning: a two-tone alarm every boss windup plays, so an off-screen attack is heard."""
    parts = []
    for k, f in enumerate((880.0, 660.0, 880.0)):
        n = n_of(0.13)
        parts.append(at(one_pole_lp(osc(f, "square", n), 3500) * env(n, 0.004, 0.08), k * 0.15))
    x = bitcrush(mix(*parts), 6, 2) * 0.6
    return echo(x, 150, 0.4, 0.35, 3000, 0.45)


def s_boss_telegraph_gatekeeper(r):
    n = n_of(0.8)
    rumble = one_pole_lp(noise(r, n), 220) * 4.0
    grind = osc(55.0 + 6.0 * np.sin(2 * np.pi * 3.0 * np.arange(n) / RATE), "saw", n)
    x = soft_clip(mix(rumble, one_pole_lp(grind, 600) * 0.6), 1.5) * env(n, 0.25, 0.3)
    return echo(x, 140, 0.35, 0.3, 1500, 0.35)


def s_boss_telegraph_brood_mother(r):
    n = n_of(0.75)
    t = np.arange(n) / RATE
    chitter = bandpass(noise(r, n), 2400, 5.0) * (np.sin(2 * np.pi * 38 * t) > 0.2)
    ring = osc(curve(300, 520, n), "sine") * osc(97.0, "square", n)
    x = mix(chitter * 0.8, ring * 0.3) * env(n, 0.08, 0.35)
    return echo(bitcrush(x, 6, 2), 120, 0.35, 0.3, 3000, 0.35)


def s_boss_telegraph_siege_engine(r):
    n = n_of(0.8)
    whine = fm(curve(220, 1100, n), 0.5, 1.5, n) * env(n, 0.3, 0.35)
    hum = osc(110.0, "saw", n) * env(n, 0.3, 0.35) * 0.4
    x = one_pole_lp(mix(whine * 0.6, hum), 3500)
    return echo(bitcrush(x, 7, 2), 130, 0.35, 0.3, 3000, 0.35)


def s_boss_telegraph_warlord(r):
    """v0.4.0 BO: the Warlord's warning: armour plates clanking twice, then a low horn."""
    clank1 = metal_ping(0.35, 520, 1.62, 3.0, 0.07)
    clank2 = metal_ping(0.35, 470, 1.62, 3.0, 0.07)
    n = n_of(0.8)
    horn = one_pole_lp(osc(curve(98, 110, n), "saw", n), 900) * env(n, 0.2, 0.35) * 0.6
    x = mix(clank1 * 0.6, at(clank2 * 0.6, 0.14), at(horn, 0.18))
    return echo(bitcrush(x, 7, 2), 140, 0.35, 0.3, 2200, 0.35)


def s_boss_telegraph_hive_lens(r):
    """v0.4.0 BO: the Hive Lens focusing: a rising glassy hum with a beating partial."""
    n = n_of(0.8)
    t = np.arange(n) / RATE
    hum = osc(curve(330, 990, n), "sine") * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t))
    glass = fm(curve(1320, 1980, n), 2.01, 1.2, n) * 0.25
    x = mix(hum * 0.7, glass) * env(n, 0.3, 0.3)
    return echo(bitcrush(x, 7, 2), 120, 0.4, 0.35, 4000, 0.4)


def s_boss_telegraph_foundry(r):
    """v0.4.0 BO: the Foundry stoking up: a roaring furnace swell over a slow bellows pump."""
    n = n_of(0.85)
    t = np.arange(n) / RATE
    roar = one_pole_lp(noise(r, n), curve(300, 1800, n)) * (0.6 + 0.4 * np.sin(2 * np.pi * 4 * t))
    pump = osc(curve(60, 75, n), "square", n) * 0.25
    x = soft_clip(mix(roar * 1.2, one_pole_lp(pump, 500)), 1.6) * env(n, 0.3, 0.3)
    return echo(x, 150, 0.35, 0.3, 1800, 0.35)


def s_boss_floor_burst(r):
    """v0.4.0 BO: a flood's lanes bursting up (spears through the floor, molten metal): a crack and a hiss."""
    n = n_of(0.7)
    crack = bandpass(noise(r, n), curve(3000, 600, n), 1.5) * env(n, 0.001, 0.06)
    thud = osc(curve(140, 50, n), "sine") * env(n, 0.002, 0.12)
    hiss = one_pole_hp(noise(r, n), 3500) * env(n, 0.04, 0.35) * 0.35
    x = soft_clip(mix(crack, thud, hiss), 1.5)
    return echo(bitcrush(x, 7, 2), 120, 0.35, 0.3, 2500, 0.4)


def s_boss_slam(r):
    n = n_of(0.7)
    boom = osc(curve(120, 32, n), "sine") * env(n, 0.002, 0.2)
    crunch = one_pole_lp(noise(r, n), curve(4000, 300, n)) * env(n, 0.001, 0.09)
    x = soft_clip(mix(boom * 1.2, crunch * 0.8), 2.0)
    return echo(bitcrush(x, 7, 2), 180, 0.4, 0.35, 1500, 0.6)


def s_boss_laser(r):
    n = n_of(0.9)
    t = np.arange(n) / RATE
    buzz = fm(220.0, 1.01, 3.0 + 2.0 * np.sin(2 * np.pi * 11 * t), n)
    sizzle = one_pole_hp(noise(r, n), 5000) * 0.25
    x = mix(buzz * 0.6, sizzle) * env(n, 0.02, 0.6)
    return echo(bitcrush(x, 6, 2), 100, 0.35, 0.3, 3500, 0.35)


def s_boss_mortar(r):
    n = n_of(0.18)
    thoomp = osc(curve(200, 60, n), "sine") * env(n, 0.002, 0.05)
    m = n_of(0.45)
    whistle = osc(curve(2400, 700, m), "sine") * env(m, 0.05, 0.3) * 0.3
    return echo(mix(thoomp, at(whistle, 0.1)), 140, 0.35, 0.3, 3000, 0.35)


def s_boss_stagger(r):
    n = n_of(0.6)
    t = np.arange(n) / RATE
    down = osc(curve(900, 90, n) * (1 + 0.06 * np.sin(2 * np.pi * 9 * t)), "saw", n) * env(n, 0.005, 0.3)
    clank = metal_ping(0.4, 420, 1.73, 4.0, 0.12) * 0.5
    x = mix(one_pole_lp(down, 2500) * 0.6, clank)
    return echo(bitcrush(x, 6, 3), 130, 0.4, 0.35, 2500, 0.4)


def s_boss_phase(r):
    n = n_of(0.9)
    swell = one_pole_lp(noise(r, n), curve(200, 5000, n)) * np.linspace(0, 1, n) ** 2
    roar = osc(curve(70, 110, n), "saw", n) * np.linspace(0, 1, n) ** 1.5
    x = soft_clip(mix(swell * 0.8, roar * 0.6), 2.5)
    x = fade_tail(x, 0.05)
    return echo(bitcrush(x, 6, 2), 170, 0.4, 0.35, 2000, 0.5)


def s_boss_death(r):
    n = n_of(1.6)
    boom = osc(curve(140, 25, n), "sine") * env(n, 0.003, 0.5)
    rubble = one_pole_lp(noise(r, n), curve(5000, 200, n)) * env(n, 0.002, 0.4)
    fall = osc(curve(700, 50, n), "saw", n) * env(n, 0.05, 0.6) * 0.3
    pops = mix(*[at(s_bolt_hit(r) * 0.4, 0.15 + 0.17 * k) for k in range(5)])
    x = soft_clip(mix(boom * 1.2, rubble * 0.8, fall, pops), 2.0)
    return echo(bitcrush(x, 7, 2), 220, 0.45, 0.4, 1500, 1.0)


def s_boss_door_seal(r):
    n = n_of(0.35)
    clunk = osc(curve(110, 50, n), "square", n) * env(n, 0.002, 0.07)
    clunk = one_pole_lp(clunk, 900)
    m = n_of(0.45)
    hiss = one_pole_hp(noise(r, m), 3000) * env(m, 0.02, 0.15) * 0.4
    return echo(mix(clunk * 0.9, at(hiss, 0.12)), 160, 0.4, 0.35, 2000, 0.45)


def s_portal_open(r):
    n = n_of(1.2)
    chord = sum(fm(f * curve(0.5, 1.0, n), 2.0, 1.2, n) for f in (220.0, 330.0, 440.0, 660.0)) * 0.2
    chord *= np.linspace(0, 1, n) ** 1.2
    chord = fade_tail(chord, 0.15)
    shimmer = bandpass(noise(r, n), curve(2000, 8000, n), 10.0) * np.linspace(0, 1, n) * 0.5
    return echo(mix(chord, shimmer), 180, 0.45, 0.4, 4000, 0.8)


def s_floor_enter(r):
    w = whoosh(r, 0.6, 5000, 400, 1.5, 0.25)
    n = n_of(0.8)
    drone = osc(55.0, "saw", n) * env(n, 0.05, 0.35)
    hit = osc(curve(90, 40, n_of(0.4)), "sine") * env(n_of(0.4), 0.003, 0.12)
    return echo(mix(w * 0.6, at(one_pole_lp(drone, 700) * 0.5, 0.35), at(hit, 0.35)), 200, 0.45, 0.4, 2500, 0.7)


def s_ui_move(r):
    n = n_of(0.035)
    tick = osc(1500.0, "square", n) * env(n, 0.001, 0.008)
    return echo(one_pole_lp(tick, 5000) * 0.4, 40, 0.25, 0.2, 5000, 0.05)


def s_ui_confirm(r):
    x = notes((880.0, 1318.5), 0.05, 0.08, "square", 0.03, 5000) * 0.5
    return echo(x, 70, 0.3, 0.25, 5000, 0.12)


def s_ui_back(r):
    x = notes((1046.5, 698.46), 0.05, 0.07, "square", 0.03, 4000) * 0.5
    return echo(x, 70, 0.3, 0.25, 4000, 0.1)


def s_low_hp_heartbeat(r):
    def beat(f, level):
        n = n_of(0.16)
        return osc(curve(f, f * 0.6, n), "sine") * env(n, 0.003, 0.05) * level

    x = mix(beat(70, 1.0), at(beat(60, 0.7), 0.17))
    return echo(one_pole_lp(x, 400), 120, 0.2, 0.15, 800, 0.1)



# --- v0.3.5 K: the build skills and the cold Vent click ---------------------------------------------------------
def s_skill_lunge_cleave(r):
    """The Lunge Cleave: a rising rush over the 0.2 s lunge, then one heavy, wide slash with a low ring."""
    rush = whoosh(r, 0.24, 300, 2400, 2.2, 0.1)
    n = n_of(0.3)
    slash = bandpass(noise(r, n), curve(5200, 900, n), 2.5) * env(n, 0.003, 0.09)
    ring = metal_ping(0.45, 330.0, 1.41, 2.0, 0.14) * 0.35
    thump = osc(curve(110, 50, n_of(0.18)), "sine") * env(n_of(0.18), 0.002, 0.05) * 0.6
    return echo(mix(rush * 0.7, at(mix(slash, ring, thump), 0.2)), 90, 0.25, 0.2, 3000, 0.2)


def s_skill_scatter_blast(r):
    """The Scatter Blast: a short, dry, crunchy boom with a spray of pellet ticks."""
    n = n_of(0.32)
    boom = one_pole_lp(noise(r, n), curve(6000, 500, n)) * env(n, 0.001, 0.07)
    body = osc(curve(160, 55, n), "sine") * env(n, 0.002, 0.08) * 0.8
    ticks = mix(*[at(one_pole_hp(noise(r, n_of(0.01)), 3000) * env(n_of(0.01), 0.0005, 0.003), 0.02 + k * 0.011) for k in range(7)])
    return echo(mix(bitcrush(boom, 7, 2), body, ticks * 0.4), 60, 0.2, 0.15, 2500, 0.12)


def s_vent_cold(r):
    """Vent pressed under Hot: a small, dull, cold click (nothing vented)."""
    n = n_of(0.07)
    click = bandpass(noise(r, n), 1800, 6.0) * env(n, 0.0005, 0.012)
    tone = osc(420.0, "sine", n) * env(n, 0.001, 0.02) * 0.4
    return mix(click, tone)


SFX = [
    ("blade_slash_1", s_blade_slash_1),
    ("blade_slash_2", s_blade_slash_2),
    ("blade_slash_3", s_blade_slash_3),
    ("blade_thrust", s_blade_thrust),
    ("blade_spin", s_blade_spin),
    ("bolt_fire", s_bolt_fire),
    ("bolt_hit", s_bolt_hit),
    ("enemy_fire", s_enemy_fire),
    ("hit_taken", s_hit_taken),
    ("enemy_hit", s_enemy_hit),
    ("guard_block", s_guard_block),
    ("enemy_death_charger", s_enemy_death_charger),
    ("enemy_death_warden", s_enemy_death_warden),
    ("enemy_death_needle", s_enemy_death_needle),
    ("enemy_death_hatchling", s_enemy_death_hatchling),
    ("enemy_windup", s_enemy_windup),
    ("enemy_death_arc_caster", s_enemy_death_arc_caster),
    ("enemy_death_bomb_drone", s_enemy_death_bomb_drone),
    ("enemy_death_lens_drone", s_enemy_death_lens_drone),
    ("arc_bolt", s_arc_bolt),
    ("rune_erupt", s_rune_erupt),
    ("bomb_lob", s_bomb_lob),
    ("bomb_blast", s_bomb_blast),
    ("enemy_death_swarmer", s_enemy_death_swarmer),
    ("enemy_death_splitter", s_enemy_death_splitter),
    ("enemy_death_shield_bearer", s_enemy_death_shield_bearer),
    ("enemy_death_mender", s_enemy_death_mender),
    ("enemy_death_mine_layer", s_enemy_death_mine_layer),
    ("enemy_death_sniper", s_enemy_death_sniper),
    ("sniper_shot", s_sniper_shot),
    ("mine_arm", s_mine_arm),
    ("mine_blast", s_mine_blast),
    ("shield_bash", s_shield_bash),
    ("mender_heal", s_mender_heal),
    ("player_death", s_player_death),
    ("dash", s_dash),
    ("blink_out", s_blink_out),
    ("blink_in", s_blink_in),
    ("item_pickup", s_item_pickup),
    ("altar_open", s_altar_open),
    ("chest_open", s_chest_open),
    ("chest_refuse", s_chest_refuse),
    ("shard_collect", s_shard_collect),
    ("shop_open", s_shop_open),
    ("shop_buy", s_shop_buy),
    ("shop_sell", s_shop_sell),
    ("combo_unlock", s_combo_unlock),
    ("heat_threshold", s_heat_threshold),
    ("heat_overheat", s_heat_overheat),
    ("heat_vent", s_heat_vent),
    ("boss_telegraph", s_boss_telegraph),
    ("boss_telegraph_gatekeeper", s_boss_telegraph_gatekeeper),
    ("boss_telegraph_brood_mother", s_boss_telegraph_brood_mother),
    ("boss_telegraph_siege_engine", s_boss_telegraph_siege_engine),
    ("boss_telegraph_warlord", s_boss_telegraph_warlord),
    ("boss_telegraph_hive_lens", s_boss_telegraph_hive_lens),
    ("boss_telegraph_foundry", s_boss_telegraph_foundry),
    ("boss_floor_burst", s_boss_floor_burst),
    ("boss_slam", s_boss_slam),
    ("boss_laser", s_boss_laser),
    ("boss_mortar", s_boss_mortar),
    ("boss_stagger", s_boss_stagger),
    ("boss_phase", s_boss_phase),
    ("boss_death", s_boss_death),
    ("boss_door_seal", s_boss_door_seal),
    ("portal_open", s_portal_open),
    ("floor_enter", s_floor_enter),
    ("ui_move", s_ui_move),
    ("ui_confirm", s_ui_confirm),
    ("ui_back", s_ui_back),
    ("low_hp_heartbeat", s_low_hp_heartbeat),
    ("skill_lunge_cleave", s_skill_lunge_cleave),
    ("skill_scatter_blast", s_skill_scatter_blast),
    ("vent_cold", s_vent_cold),
]

# --- ambience (seamless loops) -----------------------------------------------------------------------------------


def loop_noise(r, n, lo, hi, tilt=0.0):
    """Noise band-limited to [lo, hi] Hz in the frequency domain: circular, so it loops without a seam."""
    spec = np.fft.rfft(r.normal(0.0, 1.0, n))
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    shape = ((f >= lo) & (f <= hi)).astype(float)
    edge = np.exp(-(((f - lo) / (lo * 0.5 + 1)) ** 2)) * (f < lo) + np.exp(-(((f - hi) / (hi * 0.3 + 1)) ** 2)) * (f > hi)
    shape = np.maximum(shape, edge)
    if tilt:
        shape *= np.where(f > 1, (np.maximum(f, 1.0) / max(lo, 1.0)) ** (-tilt), 0.0)
    y = np.fft.irfft(spec * shape, n)
    return y / (np.max(np.abs(y)) + 1e-9)


def loop_sine(n, cycles, phase0=0.0):
    """A sine with a whole number of cycles over the loop (frequency = cycles / loop length)."""
    return np.sin(2.0 * np.pi * cycles * np.arange(n) / n + phase0)


def cyc(freq):
    """The whole-cycle count nearest to freq Hz over the loop."""
    return max(1, int(round(freq * AMB_SECONDS)))


def loop_echo(x, delay_s, feedback, taps=5):
    """Wrap-around echo: rolls the loop on itself, so the tail of the end lands at the start."""
    y = x.copy()
    g = 1.0
    for k in range(1, taps + 1):
        g *= feedback
        y += g * np.roll(x, n_of(delay_s) * k)
    return y


def drone(n, base, partials, wobble_cycles, wobble_depth):
    out = np.zeros(n)
    for mult, level in partials:
        c = cyc(base * mult)
        lfo = 1.0 + wobble_depth * loop_sine(n, wobble_cycles + int(mult), mult)
        out += level * loop_sine(n, c, mult * 0.7) * lfo
    return out


def a_ruins(r):
    n = n_of(AMB_SECONDS)
    low = drone(n, 55.0, [(1, 1.0), (1.5, 0.5), (2, 0.35), (3, 0.15)], 1, 0.25)
    wind = loop_noise(r, n, 120, 900, 0.5) * (0.55 + 0.45 * loop_sine(n, 2))
    air = loop_noise(r, n, 2500, 6000) * 0.08 * (0.5 + 0.5 * loop_sine(n, 3, 1.0))
    bell = loop_sine(n, cyc(440.0)) * np.maximum(0.0, loop_sine(n, 1, -1.2)) ** 6 * 0.15
    return loop_echo(low * 0.5 + wind * 0.45 + air + bell, 0.37, 0.4)


def a_night_rocks(r):
    n = n_of(AMB_SECONDS)
    cold = drone(n, 73.4, [(1, 0.8), (2, 0.5), (3, 0.3), (4.5, 0.15)], 2, 0.3)
    breath = loop_noise(r, n, 400, 2500, 0.3) * (0.5 + 0.5 * loop_sine(n, 1, 0.5)) * 0.4
    glints = sum(
        loop_sine(n, cyc(f)) * np.maximum(0.0, loop_sine(n, k + 1, k * 1.7)) ** 10 * 0.08
        for k, f in enumerate((1174.7, 1568.0, 1760.0))
    )
    return loop_echo(cold * 0.45 + breath + glints, 0.45, 0.45)


def a_red_canyon(r):
    n = n_of(AMB_SECONDS)
    warm = drone(n, 49.0, [(1, 1.0), (1.01, 0.6), (2, 0.4), (2.5, 0.2), (4, 0.1)], 1, 0.2)
    dust = loop_noise(r, n, 80, 600, 0.8) * (0.6 + 0.4 * loop_sine(n, 1, 2.0)) * 0.55
    hum = loop_sine(n, cyc(196.0)) * (0.5 + 0.5 * loop_sine(n, 3)) * 0.08
    return loop_echo(warm * 0.5 + dust + hum, 0.52, 0.35)


AMBIENCE = [("ruins", a_ruins), ("night_rocks", a_night_rocks), ("red_canyon", a_red_canyon)]

# --- output ------------------------------------------------------------------------------------------------------


def normalise(x, peak):
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x)
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def master_sfx(x):
    """The SFX master: DC blocked (25 Hz high-pass), the crush images tamed (9 kHz low-pass), peak-normalised,
    then a 1.5 ms fade-in and a 5 ms fade-out so no file starts or ends on a click."""
    x = one_pole_lp(one_pole_hp(np.asarray(x, dtype=float), 25.0), 9000.0)
    m = np.max(np.abs(x))
    x = x * (SFX_PEAK / m) if m > 0 else x
    a = n_of(0.0015)
    x[:a] *= np.linspace(0.0, 1.0, a)
    return fade_tail(x, 0.005)


def to_pcm16(x):
    return np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")


def wav_bytes(pcm, loop=False):
    """A RIFF/WAVE file; loops carry a 'smpl' chunk with a forward loop over the whole file."""
    import io

    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    data = bytearray(buf.getvalue())
    if loop:
        frames = len(pcm)
        smpl = struct.pack(
            "<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0
        ) + struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
        data += b"smpl" + struct.pack("<I", len(smpl)) + smpl
        struct.pack_into("<I", data, 4, len(data) - 8)
    return bytes(data)


def render_all():
    out = []
    for sid, fn in SFX:
        x = master_sfx(fn(rng_for(sid)))
        pcm = to_pcm16(x)
        out.append(("sfx", sid, os.path.join(OUT_SFX, sid + ".wav"), pcm, wav_bytes(pcm)))
    for bid, fn in AMBIENCE:
        x = normalise(fn(rng_for("ambience_" + bid)), AMB_PEAK)
        pcm = to_pcm16(x)
        out.append(("ambience", bid, os.path.join(OUT_AMB, bid + ".wav"), pcm, wav_bytes(pcm, loop=True)))
    return out


def manifest_for(rendered):
    sounds = []
    for kind, sid, path, pcm, data in rendered:
        x = pcm.astype(float) / 32767.0
        sounds.append(
            {
                "id": sid,
                "kind": kind,
                "path": os.path.relpath(path, ROOT).replace(os.sep, "/"),
                "sha256": hashlib.sha256(data).hexdigest(),
                "seconds": round(len(pcm) / RATE, 4),
                "peak_dbfs": round(20 * np.log10(np.max(np.abs(x)) + 1e-12), 2),
                "rms_dbfs": round(20 * np.log10(np.sqrt(np.mean(x * x)) + 1e-12), 2),
                "loop": kind == "ambience",
            }
        )
    return {
        "generator": "scripts/audio/generate_sfx.py",
        "generator_version": GENERATOR_VERSION,
        "format": "wav mono 44100 Hz 16-bit",
        "licence": LICENCE,
        "sounds": sounds,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="render in memory and compare with the files on disk")
    args = ap.parse_args()
    rendered = render_all()
    manifest = json.dumps(manifest_for(rendered), indent=2) + "\n"
    if args.check:
        diffs = 0
        for _kind, sid, path, _pcm, data in rendered:
            same = os.path.exists(path) and open(path, "rb").read() == data
            diffs += 0 if same else 1
            print(("  same  " if same else "  DIFF  ") + os.path.relpath(path, ROOT))
        same = os.path.exists(MANIFEST) and open(MANIFEST, encoding="utf-8").read() == manifest
        diffs += 0 if same else 1
        print(("  same  " if same else "  DIFF  ") + "assets/audio/manifest.json")
        print("%d difference(s)" % diffs)
        return 1 if diffs else 0
    os.makedirs(OUT_SFX, exist_ok=True)
    os.makedirs(OUT_AMB, exist_ok=True)
    total = 0
    for kind, sid, path, pcm, data in rendered:
        with open(path, "wb") as f:
            f.write(data)
        total += len(data)
        print("%-9s %-28s %6.3f s  %7d bytes" % (kind, sid, len(pcm) / RATE, len(data)))
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        f.write(manifest)
    print("%d files, %d bytes, generator v%d" % (len(rendered), total, GENERATOR_VERSION))
    return 0


if __name__ == "__main__":
    sys.exit(main())
