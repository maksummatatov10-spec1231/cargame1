#!/usr/bin/env python3
"""Generates the sound effects used by Neon Breaker.

The whole project ships without binary assets, so the SFX are synthesised
here with the standard library only (no numpy / scipy needed).

Usage:
    python3 tools/generate_sfx.py

Output: ../assets/audio/*.wav (mono, 44.1 kHz, 16-bit PCM)
Godot imports them as AudioStreamWAV automatically.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


# --------------------------------------------------------------------------- #
# Oscillators
# --------------------------------------------------------------------------- #
def osc_sine(t: float, freq: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def osc_square(t: float, freq: float) -> float:
    return 1.0 if math.sin(2.0 * math.pi * freq * t) >= 0.0 else -1.0


def osc_saw(t: float, freq: float) -> float:
    return 2.0 * ((t * freq) % 1.0) - 1.0


def osc_triangle(t: float, freq: float) -> float:
    x = (t * freq) % 1.0
    return 4.0 * abs(x - 0.5) - 1.0


# --------------------------------------------------------------------------- #
# Envelope helpers
# --------------------------------------------------------------------------- #
def env_ar(t: float, duration: float, attack: float, curve: float = 3.0) -> float:
    """Attack / exponential-release envelope in the [0, 1] range."""
    if t < 0.0 or t > duration:
        return 0.0
    if t < attack and attack > 0.0:
        return t / attack
    rel = (t - attack) / max(duration - attack, 1e-6)
    return max(0.0, (1.0 - rel) ** curve)


def env_percussive(t: float, duration: float, curve: float = 5.0) -> float:
    """Very fast attack, exponential decay."""
    if t < 0.0 or t > duration:
        return 0.0
    return max(0.0, (1.0 - t / duration) ** curve)


# --------------------------------------------------------------------------- #
# Renderers
# --------------------------------------------------------------------------- #
def render_blip(
    freq_start: float,
    freq_end: float,
    duration: float,
    osc=osc_square,
    curve: float = 5.0,
    volume: float = 0.7,
    attack: float = 0.001,
    noise: float = 0.0,
    seed: int = 1,
) -> list[float]:
    rng = random.Random(seed)
    count = int(SAMPLE_RATE * duration)
    out: list[float] = []
    phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        k = i / max(count - 1, 1)
        freq = freq_start + (freq_end - freq_start) * k
        phase += freq / SAMPLE_RATE
        sample = osc(phase, 1.0)
        if noise > 0.0:
            sample = sample * (1.0 - noise) + rng.uniform(-1.0, 1.0) * noise
        sample *= env_ar(t, duration, attack, curve)
        out.append(sample * volume)
    return out


def render_arpeggio(
    freqs: list[float],
    step: float,
    volume: float = 0.6,
    osc=osc_triangle,
    overlap: float = 1.6,
) -> list[float]:
    duration = step * (len(freqs) - 1) + step * 0.9
    count = int(SAMPLE_RATE * duration)
    out = [0.0] * count
    for index, freq in enumerate(freqs):
        start = int(index * step * SAMPLE_RATE)
        note_len = step * overlap
        note_count = int(SAMPLE_RATE * note_len)
        for i in range(note_count):
            pos = start + i
            if pos >= count:
                break
            t = i / SAMPLE_RATE
            out[pos] += osc(t, freq) * env_percussive(t, note_len, 3.0) * volume
    return out


def render_noise_burst(duration: float, volume: float = 0.5, seed: int = 7, tone: float = 0.0) -> list[float]:
    rng = random.Random(seed)
    count = int(SAMPLE_RATE * duration)
    out = []
    for i in range(count):
        t = i / SAMPLE_RATE
        sample = rng.uniform(-1.0, 1.0)
        if tone > 0.0:
            sample = sample * 0.5 + osc_square(t * tone, 1.0) * 0.5
        out.append(sample * env_percussive(t, duration, 4.0) * volume)
    return out


# --------------------------------------------------------------------------- #
# Mixing / writing
# --------------------------------------------------------------------------- #
def mix(*layers: list[float]) -> list[float]:
    length = max(len(layer) for layer in layers)
    out = [0.0] * length
    for layer in layers:
        for i, value in enumerate(layer):
            out[i] += value
    return out


def write_wav(name: str, samples: list[float], peak: float = 0.85) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    highest = max((abs(s) for s in samples), default=1.0) or 1.0
    scale = peak / highest
    frames = bytearray()
    for value in samples:
        clipped = max(-1.0, min(1.0, value * scale))
        frames += struct.pack("<h", int(clipped * 32767))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(frames))
    print(f"wrote {os.path.relpath(path)} ({len(samples) / SAMPLE_RATE:.3f}s)")


def main() -> None:
    # Paddle hit: bright, short, rising.
    write_wav("paddle.wav", mix(
        render_blip(520, 760, 0.09, osc_square, curve=6.0, volume=0.6),
        render_noise_burst(0.05, volume=0.18, seed=11),
    ))

    # Wall bounce: soft low click.
    write_wav("wall.wav", render_blip(300, 240, 0.07, osc_triangle, curve=7.0, volume=0.5))

    # Brick destroyed: crunchy zap.
    write_wav("brick.wav", mix(
        render_blip(880, 1180, 0.09, osc_square, curve=6.5, volume=0.45, noise=0.25, seed=23),
        render_noise_burst(0.06, volume=0.25, seed=5),
    ))

    # Brick damaged but alive: duller thud.
    write_wav("brick_hit.wav", render_blip(420, 380, 0.06, osc_triangle, curve=8.0, volume=0.35))

    # Power-up: happy arpeggio.
    write_wav("powerup.wav", render_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.055, volume=0.5))

    # Lost life: descending saw.
    write_wav("life_lost.wav", render_blip(440, 110, 0.45, osc_saw, curve=2.0, volume=0.5))

    # Level cleared: fanfare.
    write_wav("level_up.wav", render_arpeggio([392.0, 523.25, 659.25, 784.0, 1046.5, 1318.5], 0.07, volume=0.45))

    # UI click.
    write_wav("click.wav", render_blip(1200, 900, 0.035, osc_square, curve=8.0, volume=0.35))

    # Game over: sad descending arpeggio.
    write_wav("game_over.wav", render_arpeggio([523.25, 466.16, 392.0, 311.13, 261.63], 0.16, volume=0.45, osc=osc_saw))


if __name__ == "__main__":
    main()
