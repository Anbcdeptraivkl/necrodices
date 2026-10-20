"""Synthesise the chiptune SFX and music loops (16-bit mono 22050 Hz WAV).

Usage: python tools/audio/gen_audio.py        (overwrites every file it owns)

Outputs assets/audio/sfx/<name>.wav and assets/audio/music/{night,shop}_loop.wav.
Deterministic: every random source uses a fixed seed. Needs numpy.
SFX peak at -3 dBFS, music at -6 dBFS. Music loops are an exact number of bars, every
note decays to silence inside its own slot, so the first and last samples are exact zeros
and the loop (set at runtime by autoload/audio.gd) is seamless.
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 22050
ROOT = Path(__file__).resolve().parents[2]
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"
SFX_PEAK = 10 ** (-3 / 20)
MUSIC_PEAK = 10 ** (-6 / 20)


# ---------------------------------------------------------------- primitives

def n(sec: float) -> int:
    return int(round(sec * SR))


def midi_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def phase(freq) -> np.ndarray:
    """Cumulative phase in cycles for a per-sample frequency array."""
    return np.cumsum(np.asarray(freq, dtype=np.float64)) / SR


def sweep(f0: float, f1: float, length: int, curve: float = 1.0) -> np.ndarray:
    t = np.linspace(0.0, 1.0, length, endpoint=False) ** curve
    return f0 * (f1 / f0) ** t  # exponential glide sounds even across octaves


def square(ph: np.ndarray, duty: float = 0.5) -> np.ndarray:
    """Pulse wave with its DC offset removed (narrow pulses otherwise thump on gating)."""
    return np.where((ph % 1.0) < duty, 1.0, -1.0) - (2.0 * duty - 1.0)


def triangle(ph: np.ndarray) -> np.ndarray:
    return 4.0 * np.abs((ph % 1.0) - 0.5) - 1.0


def sine(ph: np.ndarray) -> np.ndarray:
    return np.sin(2 * np.pi * ph)


def noise(length: int, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, length)


def lowpass(x: np.ndarray, cutoff) -> np.ndarray:
    """One-pole low-pass; cutoff may be a per-sample array (Hz)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def env_exp(length: int, decay: float, attack: float = 0.002) -> np.ndarray:
    """Fast attack, exponential decay (decay = time constant in seconds)."""
    t = np.arange(length) / SR
    e = np.exp(-t / decay)
    a = n(attack)
    if a > 0:
        e[:a] *= np.linspace(0.0, 1.0, a, endpoint=False)
    return e


def env_adsr(length: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    e = np.full(length, s)
    na, nd, nr = n(a), n(d), n(r)
    na = min(na, length)
    e[:na] = np.linspace(0.0, 1.0, na, endpoint=False)
    nd = min(nd, max(0, length - na))
    e[na:na + nd] = np.linspace(1.0, s, nd, endpoint=False)
    nr = min(nr, length)
    if nr > 0:
        e[length - nr:] *= np.linspace(1.0, 0.0, nr)
    return e


def pad(x: np.ndarray, length: int) -> np.ndarray:
    out = np.zeros(length)
    out[:min(length, len(x))] = x[:length]
    return out


def mix_at(buf: np.ndarray, x: np.ndarray, start: int, gain: float = 1.0) -> None:
    end = min(len(buf), start + len(x))
    if end > start:
        buf[start:end] += gain * x[:end - start]


def xylo(freq: float, length: int, decay: float = 0.08) -> np.ndarray:
    """Bone-xylophone: sine fundamental + inharmonic 3.93x partial that dies fast."""
    ph = phase(np.full(length, freq))
    body = sine(ph) * env_exp(length, decay, 0.001)
    over = 0.35 * sine(ph * 3.93) * env_exp(length, decay * 0.25, 0.001)
    return body + over


def finish(x: np.ndarray, peak: float, fade_in: float = 0.002, fade_out: float = 0.012) -> np.ndarray:
    fi, fo = n(fade_in), n(fade_out)
    x = x.copy()
    if fi:
        x[:fi] *= np.linspace(0.0, 1.0, fi)
    if fo:
        x[-fo:] *= np.linspace(1.0, 0.0, fo)
    m = np.max(np.abs(x))
    if m > 0:
        x *= peak / m
    return x


def write_wav(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------- SFX

def sfx_roll(rng):
    L = n(0.26)
    out = np.zeros(L)
    times = np.sort(rng.uniform(0.0, 0.2, 7))
    for i, t in enumerate(times):
        k = n(0.03)
        click = lowpass(noise(k, rng), 3500) * env_exp(k, 0.006, 0.0005)
        tone = square(phase(np.full(k, rng.uniform(900, 1600))), 0.3) * env_exp(k, 0.008, 0.0005)
        mix_at(out, click + 0.25 * tone, n(t), 1.0 - 0.08 * i)
    return out


def sfx_select(rng):
    L = n(0.07)
    f = sweep(660, 990, L)
    return 0.6 * triangle(phase(f)) * env_adsr(L, 0.003, 0.03, 0.5, 0.03) + \
        0.15 * square(phase(f)) * env_exp(L, 0.02)


def sfx_deselect(rng):
    L = n(0.07)
    f = sweep(880, 520, L)
    return 0.6 * triangle(phase(f)) * env_adsr(L, 0.003, 0.03, 0.5, 0.03) + \
        0.15 * square(phase(f)) * env_exp(L, 0.02)


def bone_clack(rng, length: int) -> np.ndarray:
    k = n(0.025)
    clack = lowpass(noise(k, rng), 4000) * env_exp(k, 0.005, 0.0003)
    knock = sine(phase(np.full(k, 1850))) * env_exp(k, 0.012, 0.0003)
    return pad(clack + 0.7 * knock, length)


def sfx_bind(rng):
    L = n(0.3)
    out = bone_clack(rng, L)
    mix_at(out, xylo(midi_hz(76), n(0.12), 0.05), n(0.03), 0.7)   # E5
    mix_at(out, xylo(midi_hz(81), n(0.2), 0.07), n(0.09), 0.8)    # A5
    rise = n(0.16)
    mix_at(out, 0.18 * square(phase(sweep(440, 880, rise)), 0.25) * env_adsr(rise, 0.01, 0.05, 0.6, 0.06), n(0.06))
    return out


def sfx_unbind(rng):
    L = n(0.28)
    out = 0.6 * bone_clack(rng, L)
    mix_at(out, xylo(midi_hz(81), n(0.1), 0.05), n(0.02), 0.6)
    mix_at(out, xylo(midi_hz(76), n(0.18), 0.07), n(0.08), 0.7)
    fall = n(0.15)
    mix_at(out, 0.15 * square(phase(sweep(660, 330, fall)), 0.25) * env_adsr(fall, 0.01, 0.05, 0.5, 0.06), n(0.05))
    return out


def sfx_summon(rng):
    L = n(0.5)
    w = n(0.36)
    cutoff = sweep(300, 4500, w, 1.6)
    whoosh = lowpass(noise(w, rng), cutoff) * env_adsr(w, 0.15, 0.1, 0.8, 0.1)
    ghost = 0.25 * triangle(phase(sweep(220, 520, w) * (1 + 0.02 * np.sin(2 * np.pi * 9 * np.arange(w) / SR))))
    ghost *= env_adsr(w, 0.12, 0.1, 0.7, 0.12)
    out = pad(whoosh * 1.4 + ghost, L)
    p = n(0.12)
    pop = sine(phase(sweep(260, 900, p, 0.5))) * env_exp(p, 0.03, 0.001)
    mix_at(out, pop, n(0.33), 0.9)
    return out


def sfx_tick(rng):
    L = n(0.08)
    return xylo(midi_hz(72), L, 0.03)  # C5; the game pitch-shifts up to C6


def sfx_clone(rng):
    L = n(0.1)
    pop = sine(phase(sweep(320, 1100, L, 0.4))) * env_exp(L, 0.025, 0.001)
    k = n(0.012)
    out = pop + pad(0.3 * lowpass(noise(k, rng), 5000) * env_exp(k, 0.004, 0.0003), L)
    return out


def sfx_slam(rng):
    L = n(0.55)
    thump = sine(phase(sweep(140, 38, L, 0.5))) * env_exp(L, 0.16, 0.001)
    sub = 0.35 * square(phase(sweep(90, 40, L, 0.5)), 0.5) * env_exp(L, 0.08, 0.001)
    k = n(0.2)
    crash = pad(lowpass(noise(k, rng), sweep(3000, 400, k)) * env_exp(k, 0.05, 0.001), L)
    return thump + lowpass(sub, 900) + 0.9 * crash


def sfx_hit(rng):
    L = n(0.16)
    k = n(0.07)
    out = pad(lowpass(noise(k, rng), 3000) * env_exp(k, 0.02, 0.0005), L)
    out += 0.45 * square(phase(sweep(260, 110, L)), 0.5) * env_exp(L, 0.05, 0.001)
    return out


def note_seq(notes, voice, total: float) -> np.ndarray:
    """notes: (start_s, dur_s, midi, gain)."""
    out = np.zeros(n(total))
    for start, dur, m, g in notes:
        mix_at(out, voice(midi_hz(m), n(dur)), n(start), g)
    return out


def chip_voice(f: float, L: int) -> np.ndarray:
    ph = phase(np.full(L, f))
    return (0.55 * square(ph, 0.25) + 0.45 * triangle(ph)) * env_adsr(L, 0.004, 0.06, 0.6, 0.04)


def sfx_win(rng):
    notes = [(0.00, 0.10, 69, 0.8), (0.09, 0.10, 72, 0.8), (0.18, 0.10, 76, 0.8),
             (0.27, 0.12, 81, 0.9), (0.40, 0.55, 81, 0.7), (0.40, 0.55, 85, 0.6), (0.40, 0.55, 88, 0.6)]
    out = note_seq(notes, chip_voice, 1.0)
    for t in (0.0, 0.09, 0.18, 0.27):
        mix_at(out, 0.5 * xylo(midi_hz(93), n(0.08), 0.03), n(t))
    return out


def sfx_lose(rng):
    L = n(1.05)
    out = note_seq([(0.00, 0.18, 76, 0.8), (0.18, 0.18, 75, 0.8), (0.36, 0.18, 74, 0.8)], chip_voice, 1.05)
    k = n(0.5)
    vib = midi_hz(69) * sweep(1.0, 0.94, k) * (1 + 0.03 * np.sin(2 * np.pi * 6 * np.arange(k) / SR))
    ph = phase(vib)
    tail = (0.5 * square(ph, 0.5) + 0.5 * triangle(ph)) * env_adsr(k, 0.01, 0.1, 0.7, 0.2)
    mix_at(out, tail, n(0.54), 0.8)
    return out


def sfx_coin(rng):
    L = n(0.32)
    a, b = n(0.06), n(0.26)
    out = pad(square(phase(np.full(a, midi_hz(83))), 0.5) * env_adsr(a, 0.002, 0.02, 0.8, 0.005), L)
    mix_at(out, square(phase(np.full(b, midi_hz(88))), 0.5) * env_exp(b, 0.08, 0.002), a)
    return lowpass(out, 6000)


def sfx_buy(rng):
    notes = [(0.0, 0.07, 84, 0.8), (0.06, 0.07, 88, 0.8), (0.12, 0.2, 91, 0.9)]
    out = note_seq(notes, lambda f, L: square(phase(np.full(L, f)), 0.5) * env_exp(L, 0.06, 0.002), 0.36)
    return lowpass(out, 6000)


def sfx_sell(rng):
    out = note_seq([(0.0, 0.07, 88, 0.8), (0.07, 0.2, 83, 0.8)],
                   lambda f, L: square(phase(np.full(L, f)), 0.5) * env_exp(L, 0.06, 0.002), 0.3)
    k = n(0.06)
    mix_at(out, lowpass(noise(k, rng), 5000) * env_exp(k, 0.015, 0.001), 0, 0.35)
    return lowpass(out, 6000)


def sfx_click(rng):
    L = n(0.035)
    return square(phase(np.full(L, 1050)), 0.5) * env_exp(L, 0.008, 0.0005) * 0.7 + \
        triangle(phase(np.full(L, 525))) * env_exp(L, 0.01, 0.0005) * 0.5


def sfx_error(rng):
    L = n(0.28)
    out = np.zeros(L)
    for t, f in ((0.0, 165.0), (0.14, 155.0)):
        k = n(0.11)
        ph = phase(np.full(k, f))
        mix_at(out, (0.5 * square(ph, 0.5) + 0.5 * triangle(ph)) * env_adsr(k, 0.003, 0.02, 0.8, 0.02), n(t))
    return lowpass(out, 1500)


def sfx_reroll_shop(rng):
    L = n(0.34)
    out = np.zeros(L)
    for i, m in enumerate((69, 72, 76, 79, 81)):
        mix_at(out, xylo(midi_hz(m), n(0.1), 0.04), n(0.045 * i), 0.7)
    for t in rng.uniform(0.0, 0.22, 5):
        k = n(0.02)
        mix_at(out, lowpass(noise(k, rng), 3000) * env_exp(k, 0.004, 0.0003), n(t), 0.5)
    return out


def metal_hit(f: float, L: int) -> np.ndarray:
    out = np.zeros(L)
    for ratio, g, d in ((1.0, 1.0, 0.07), (2.76, 0.6, 0.05), (5.40, 0.4, 0.03), (8.93, 0.25, 0.02)):
        out += g * sine(phase(np.full(L, f * ratio))) * env_exp(L, d, 0.0005)
    return out


def sfx_shackle(rng):
    L = n(0.42)
    out = np.zeros(L)
    for t, f, g in ((0.0, 620, 1.0), (0.09, 700, 0.7), (0.16, 560, 0.55), (0.24, 660, 0.4)):
        mix_at(out, metal_hit(f, n(0.16)), n(t), g)
        k = n(0.015)
        mix_at(out, lowpass(noise(k, rng), 6000) * env_exp(k, 0.003, 0.0002), n(t), 0.4 * g)
    return out


def sfx_page(rng):
    L = n(0.22)
    x = noise(L, rng)
    band = lowpass(x, sweep(2500, 6000, L)) - lowpass(x, 700)
    return band * env_adsr(L, 0.07, 0.05, 0.7, 0.1) * 2.0


SFX = {
    "roll": sfx_roll, "select": sfx_select, "deselect": sfx_deselect, "bind": sfx_bind,
    "unbind": sfx_unbind, "summon": sfx_summon, "tick": sfx_tick, "clone": sfx_clone,
    "slam": sfx_slam, "hit": sfx_hit, "win": sfx_win, "lose": sfx_lose, "coin": sfx_coin,
    "buy": sfx_buy, "sell": sfx_sell, "click": sfx_click, "error": sfx_error,
    "reroll_shop": sfx_reroll_shop, "shackle": sfx_shackle, "page": sfx_page,
}


# ---------------------------------------------------------------- music

def gated(voice, f: float, slot: int, gate: float = 0.9) -> np.ndarray:
    """Render a voice inside its slot; a 6 ms release ends it before the slot ends."""
    L = max(1, int(slot * gate))
    x = voice(f, L)
    r = min(L, n(0.006))
    x[-r:] *= np.linspace(1.0, 0.0, r)
    return x


def lead_voice(f: float, L: int) -> np.ndarray:
    t = np.arange(L) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) / 0.1, 0, 1)
    ph = phase(f * vib)
    return (0.7 * square(ph, 0.25) + 0.3 * triangle(ph)) * env_adsr(L, 0.005, 0.08, 0.55, 0.03)


def bass_voice(f: float, L: int) -> np.ndarray:
    return triangle(phase(np.full(L, f))) * env_adsr(L, 0.004, 0.1, 0.7, 0.03)


def stab_voice(f: float, L: int) -> np.ndarray:
    return square(phase(np.full(L, f)), 0.125) * env_exp(L, 0.06, 0.003)


def kick(L: int) -> np.ndarray:
    return sine(phase(sweep(130, 45, L, 0.5))) * env_exp(L, 0.05, 0.001)


def hat(L: int, rng) -> np.ndarray:
    x = noise(L, rng)
    return (x - lowpass(x, 5000)) * env_exp(L, 0.012, 0.0005)


def music_box(f: float, L: int) -> np.ndarray:
    ph = phase(np.full(L, f))
    tone = sine(ph) * env_exp(L, 0.45, 0.002)
    tone += 0.25 * sine(ph * 2.0) * env_exp(L, 0.2, 0.002)
    tone += 0.12 * sine(ph * 5.4) * env_exp(L, 0.05, 0.001)  # tine shimmer
    return tone


# Chords as MIDI notes (bass root, then stab/arp tones).
CH = {
    "Am": (45, [57, 60, 64]), "Dm": (50, [57, 62, 65]), "E": (40, [56, 59, 64]),
    "F": (41, [57, 60, 65]), "C": (48, [55, 60, 64]), "G": (43, [55, 59, 62]),
    "Gm": (43, [55, 58, 62]), "Bb": (46, [53, 58, 62]), "A": (45, [57, 61, 64]),
}

NIGHT_PHRASE_A = (["Am", "Dm", "E", "Am", "F", "Dm", "E", "Am"], [
    [(76, 1), (72, 1), (69, 1)], [(74, 1.5), (72, 0.5), (69, 1)], [(71, 1), (68, 1), (64, 1)],
    [(69, 2), (None, 1)], [(72, 1), (77, 1), (76, 1)], [(74, 1), (77, 1), (74, 1)],
    [(71, 1), (74, 0.5), (72, 0.5), (71, 1)], [(69, 2), (None, 1)],
])
NIGHT_PHRASE_B = (["C", "G", "Am", "E", "F", "C", "Dm", "E"], [
    [(79, 1), (76, 1), (72, 1)], [(79, 1.5), (77, 0.5), (74, 1)], [(76, 1), (72, 1), (69, 1)],
    [(68, 1), (71, 1), (76, 1)], [(77, 1), (76, 0.5), (74, 0.5), (72, 1)], [(76, 2), (72, 1)],
    [(74, 1), (72, 0.5), (71, 0.5), (69, 1)], [(68, 1), (71, 1), (64, 1)],
])


def night_loop() -> np.ndarray:
    """A-minor waltz, 3/4 at 135 bpm: 24 bars = exactly 32.0 s (9800 samples per beat)."""
    rng = np.random.default_rng(1031)
    beat = 9800
    bar = 3 * beat
    phrases = [NIGHT_PHRASE_A, NIGHT_PHRASE_B, NIGHT_PHRASE_A]
    total = bar * 8 * len(phrases)
    out = np.zeros(total)
    b = 0
    for pi, (chords, melody) in enumerate(phrases):
        for chord, mel in zip(chords, melody):
            s = b * bar
            root, tones = CH[chord]
            mix_at(out, gated(bass_voice, midi_hz(root), beat), s, 0.55)
            mix_at(out, gated(bass_voice, midi_hz(root + 7), beat, 0.6), s + beat, 0.35)
            mix_at(out, gated(bass_voice, midi_hz(root + 12), beat, 0.6), s + 2 * beat, 0.35)
            for k in (1, 2):
                for m in tones:
                    mix_at(out, gated(stab_voice, midi_hz(m), beat // 2), s + k * beat, 0.07)
            mix_at(out, kick(n(0.09)), s, 0.5)
            for k in (1, 2):
                mix_at(out, hat(n(0.04), rng), s + k * beat, 0.18)
            t = 0.0
            for m, d in mel:
                slot = int(d * beat)
                if m is not None:
                    gain = 0.32 if pi < 2 else 0.3
                    mix_at(out, gated(lead_voice, midi_hz(m), slot, 0.88), s + int(t * beat), gain)
                    if pi == 2:  # last phrase: a soft octave-up echo voice
                        mix_at(out, gated(lead_voice, midi_hz(m + 12), slot, 0.6), s + int(t * beat), 0.08)
                t += d
            b += 1
    return out


SHOP_CHORDS = ["Dm", "Gm", "C", "F", "Bb", "Gm", "A", "Dm", "Dm", "Bb", "A", "Dm"]
SHOP_MELODY = [
    [(74, 2), (77, 1)], [(79, 2), (74, 1)], [(76, 3)], [(77, 1), (76, 1), (74, 1)],
    [(74, 2), (70, 1)], [(79, 1), (77, 1), (74, 1)], [(73, 2), (76, 1)], [(74, 3)],
    [(81, 2), (77, 1)], [(74, 2), (77, 1)], [(76, 1), (73, 1), (69, 1)], [(74, 2), (None, 1)],
]


def shop_loop() -> np.ndarray:
    """D-minor music box, 3/4 at 90 bpm: 12 bars = exactly 24.0 s (14700 samples per beat)."""
    beat = 14700
    bar = 3 * beat
    eighth = beat // 2
    total = bar * len(SHOP_CHORDS)
    out = np.zeros(total)
    for b, chord in enumerate(SHOP_CHORDS):
        s = b * bar
        root, tones = CH[chord]
        mix_at(out, gated(bass_voice, midi_hz(root), bar, 0.95) * env_exp(int(bar * 0.95), 1.2, 0.01), s, 0.3)
        arp = [tones[0], tones[1], tones[2], tones[1] + 12, tones[2], tones[1]]
        for i, m in enumerate(arp):
            mix_at(out, gated(music_box, midi_hz(m + 12), eighth, 0.98), s + i * eighth, 0.16)
        t = 0
        for m, d in SHOP_MELODY[b]:
            slot = int(d * beat)
            if m is not None:
                mix_at(out, gated(music_box, midi_hz(m + 12), slot, 0.97), s + int(t * beat), 0.42)
            t += d
    return out


def main() -> None:
    total_bytes = 0
    for i, (name, fn) in enumerate(SFX.items()):
        rng = np.random.default_rng(7000 + i)
        x = finish(fn(rng), SFX_PEAK)
        p = SFX_DIR / f"{name}.wav"
        write_wav(p, x)
        total_bytes += p.stat().st_size
    for name, fn in (("night_loop", night_loop), ("shop_loop", shop_loop)):
        x = fn()
        x *= MUSIC_PEAK / np.max(np.abs(x))
        assert x[0] == 0.0 and x[-1] == 0.0, f"{name}: loop ends must be silent zeros"
        p = MUSIC_DIR / f"{name}.wav"
        write_wav(p, x)
        total_bytes += p.stat().st_size
        print(f"{name}: {len(x) / SR:.3f} s, {len(x)} frames")
    print(f"{len(SFX)} sfx + 2 loops written, {total_bytes / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
