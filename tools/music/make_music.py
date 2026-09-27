"""Compose the three Living Memories music beds (original, CC0).

Usage: python tools/music/make_music.py

Writes apps/mobile/assets/music/{warm,wander,light}.wav — 30 s, mono,
32 kHz, 16-bit PCM. Everything is synthesised here from sine partials and a
plucked-string model, so there is no third-party audio and no licence to
track beyond the CC0 dedication in LICENSE.md. Deterministic (seeded).
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 32000
SECONDS = 30
OUT = Path(__file__).resolve().parents[2] / "apps" / "mobile" / "assets" / "music"

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def freq(name: str, octave: int) -> float:
    midi = 12 * (octave + 1) + NOTE[name]
    return 440.0 * 2 ** ((midi - 69) / 12)


def chord(root: str, minor: bool, octave: int) -> list[float]:
    r = 12 * (octave + 1) + NOTE[root]
    third = 3 if minor else 4
    return [440.0 * 2 ** ((m - 69) / 12) for m in (r, r + third, r + 7, r + 12)]


def piano(f: float, dur: float, vel: float) -> list[float]:
    n = int(dur * RATE)
    out = []
    partials = [(1, 1.0), (2, 0.42), (3, 0.18), (4, 0.08), (5, 0.04)]
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.008)
        env = attack * math.exp(-t * (1.6 + f / 900))
        s = 0.0
        for k, a in partials:
            s += a * math.sin(2 * math.pi * f * k * t) * math.exp(-t * k * 0.6)
        out.append(s * env * vel)
    return out


def bell(f: float, dur: float, vel: float) -> list[float]:
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.004) * math.exp(-t * 2.2)
        s = math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-t * 3) \
            + 0.2 * math.sin(2 * math.pi * f * 5.4 * t) * math.exp(-t * 6)
        out.append(s * env * vel)
    return out


def pluck(f: float, dur: float, vel: float, rng: random.Random) -> list[float]:
    """Karplus-Strong plucked string."""
    period = max(2, int(RATE / f))
    buf = [rng.uniform(-1, 1) for _ in range(period)]
    n = int(dur * RATE)
    out = []
    for i in range(n):
        v = buf[i % period]
        nxt = buf[(i + 1) % period]
        buf[i % period] = 0.996 * 0.5 * (v + nxt)
        out.append(v * vel)
    return out


def pad(freqs: list[float], dur: float, vel: float) -> list[float]:
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.9, (dur - t) / 0.9)
        s = sum(math.sin(2 * math.pi * f * t + 0.3 * math.sin(2 * math.pi * 0.2 * t)) for f in freqs)
        out.append(s / len(freqs) * env * vel)
    return out


def mix(buf: list[float], sound: list[float], at: float) -> None:
    start = int(at * RATE)
    for i, v in enumerate(sound):
        j = start + i
        if j >= len(buf):
            break
        buf[j] += v


def reverb(buf: list[float]) -> list[float]:
    """A few feedback delays: enough room to soften the synthesis."""
    out = buf[:]
    for delay_ms, gain in ((53, 0.28), (79, 0.22), (113, 0.17), (167, 0.12)):
        d = int(RATE * delay_ms / 1000)
        for i in range(d, len(out)):
            out[i] += out[i - d] * gain
    return out


def write(name: str, buf: list[float]) -> None:
    buf = reverb(buf)
    peak = max(abs(v) for v in buf) or 1.0
    scale = 0.8 / peak
    n = len(buf)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for i, v in enumerate(buf):
            fade = min(1.0, i / (RATE * 0.5), (n - i) / (RATE * 2.0))
            frames += struct.pack("<h", int(max(-1, min(1, v * scale * fade)) * 32767))
        w.writeframes(bytes(frames))
    print(f"wrote {name}.wav")


def warm() -> list[float]:
    """Wedding: slow piano arpeggios over a soft pad, F major, 72 bpm."""
    buf = [0.0] * (RATE * SECONDS)
    beat = 60 / 72
    prog = [("F", False), ("D", True), ("A#", False), ("C", False)]
    t = 0.0
    bar = 0
    while t < SECONDS:
        root, minor = prog[bar % 4]
        mix(buf, pad(chord(root, minor, 3)[:3], beat * 4 + 0.8, 0.10), t)
        notes = chord(root, minor, 4)
        for k, idx in enumerate((0, 1, 2, 3, 2, 1, 2, 3)):
            mix(buf, piano(notes[idx], 2.4, 0.22 if k % 4 == 0 else 0.15), t + k * beat / 2)
        if bar % 2 == 1:
            mix(buf, piano(freq(root, 5) * (1.5 if minor else 1.25), 3.0, 0.12), t + beat * 2)
        t += beat * 4
        bar += 1
    return buf


def wander() -> list[float]:
    """Travel: plucked guitar pattern with a light shaker, D major, 96 bpm."""
    rng = random.Random(7)
    buf = [0.0] * (RATE * SECONDS)
    beat = 60 / 96
    prog = [("D", False), ("A", False), ("B", True), ("G", False)]
    t = 0.0
    bar = 0
    while t < SECONDS:
        root, minor = prog[bar % 4]
        notes = chord(root, minor, 3)
        mix(buf, pluck(notes[0] / 2, beat * 4, 0.35, rng), t)
        pattern = (1, 2, 3, 2, 1, 3, 2, 3)
        for k, idx in enumerate(pattern):
            mix(buf, pluck(notes[idx], 1.6, 0.22, rng), t + k * beat / 2)
        for k in range(8):
            shaker = [rng.uniform(-1, 1) * math.exp(-i / (RATE * 0.03)) * (0.05 if k % 2 else 0.08)
                      for i in range(int(RATE * 0.12))]
            mix(buf, shaker, t + k * beat / 2 + beat / 4)
        if bar >= 4:
            mix(buf, bell(freq(root, 5), 1.5, 0.05), t + beat * 3)
        t += beat * 4
        bar += 1
    return buf


def light() -> list[float]:
    """Family, baby, birthday: music-box bells over a pad, C major, 88 bpm."""
    buf = [0.0] * (RATE * SECONDS)
    beat = 60 / 88
    prog = [("C", False), ("G", False), ("A", True), ("F", False)]
    melody = [0, 2, 1, 3, 2, 1, 0, 1]
    t = 0.0
    bar = 0
    while t < SECONDS:
        root, minor = prog[bar % 4]
        mix(buf, pad(chord(root, minor, 3)[:3], beat * 4 + 0.8, 0.09), t)
        notes = chord(root, minor, 5)
        for k, idx in enumerate(melody):
            mix(buf, bell(notes[(idx + bar) % 4], 1.8, 0.16), t + k * beat / 2)
        mix(buf, piano(chord(root, minor, 2)[0], 3.0, 0.18), t)
        t += beat * 4
        bar += 1
    return buf


if __name__ == "__main__":
    write("warm", warm())
    write("wander", wander())
    write("light", light())
