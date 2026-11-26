"""Synthesize the five music loops with numpy: no samples, nothing borrowed.

    python tools/music.py            # -> assets/audio/music_*.ogg (needs ffmpeg)
    python tools/music.py service    # just this one

A bass, an electric piano, a plucked string and a small kit, playing
original loops: the title's slow groove, the prologue, prep, the dinner
rush and the critic's table. The other games' music is generated (see their
tools/music.py); these are stand-ins a generated score can replace, file
for file.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
RATE = 44100
RNG = np.random.default_rng(1971)


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def span(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    return np.fft.irfft(spectrum / (1.0 + (freqs / cutoff) ** 4), len(x))


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def bass(note: float, seconds: float) -> np.ndarray:
    x = span(seconds)
    f = hz(note)
    tone = np.sin(2 * np.pi * f * x) + 0.4 * np.sin(4 * np.pi * f * x) * np.exp(-x * 9) + 0.15 * np.sin(6 * np.pi * f * x) * np.exp(-x * 14)
    return tone * np.minimum(x / 0.006, 1.0) * np.exp(-x * 3.2) * 0.5


def keys(note: float, seconds: float) -> np.ndarray:
    """An electric piano: a soft bell over a sine, with a slow wobble."""
    x = span(seconds)
    f = hz(note)
    tine = np.sin(2 * np.pi * f * x + 1.6 * np.exp(-x * 7) * np.sin(2 * np.pi * f * 2 * x))
    return tine * (1 + 0.12 * np.sin(2 * np.pi * 4.6 * x)) * np.minimum(x / 0.004, 1.0) * np.exp(-x * 2.6) * 0.2


def pluck(note: float, seconds: float) -> np.ndarray:
    """A muted string: its harmonics die off top first."""
    x = span(seconds)
    f = hz(note)
    out = np.zeros(len(x))
    for k in range(1, 9):
        out += np.sin(2 * np.pi * f * k * x) / k * np.exp(-x * (5 + 3.5 * k))
    return out * np.minimum(x / 0.002, 1.0) * 0.3


def kick() -> np.ndarray:
    x = span(0.22)
    return np.sin(2 * np.pi * (48 * x + 60 * (1 - np.exp(-x * 30)) / 30)) * np.exp(-x * 16) * 0.75


def hat(seconds: float = 0.05, level: float = 0.12) -> np.ndarray:
    x = span(seconds)
    return highpass(RNG.standard_normal(len(x)), 7000) * np.exp(-x * 70) * level


def rim() -> np.ndarray:
    x = span(0.08)
    return (np.sin(2 * np.pi * 820 * x) * 0.5 + highpass(RNG.standard_normal(len(x)), 2000) * 0.3) * np.exp(-x * 60) * 0.35


def snare() -> np.ndarray:
    x = span(0.16)
    return (np.sin(2 * np.pi * 190 * x) * np.exp(-x * 30) * 0.4 + highpass(RNG.standard_normal(len(x)), 1500) * np.exp(-x * 24) * 0.28)


CHORDS = {"m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11], "7": [0, 4, 7, 10], "m": [0, 3, 7], "M": [0, 4, 7], "sus": [0, 5, 7]}


class Loop:
    """`bars` of four beats at `bpm`, with what falls past the end folded
    back onto the start, so it loops without a seam."""

    def __init__(self, bpm: float, bars: int) -> None:
        self.beat = 60.0 / bpm
        self.length = int(bars * 4 * self.beat * RATE)
        self.buf = np.zeros(self.length)

    def add(self, sound: np.ndarray, beat: float, gain: float = 1.0) -> None:
        at = int(beat * self.beat * RATE) % self.length
        while len(sound) > 0:
            n = min(len(sound), self.length - at)
            self.buf[at:at + n] += sound[:n] * gain
            sound = sound[n:]
            at = 0


def make(bpm: float, progression: list[tuple[int, str]], style: str) -> np.ndarray:
    loop = Loop(bpm, len(progression))
    b = loop.beat
    for bar, (root, quality) in enumerate(progression):
        notes = [root + step for step in CHORDS[quality]]
        at = bar * 4.0
        if style == "title":
            for beat, n in [(0, 0), (1.5, 0), (2.5, 2), (3.5, 0)]:
                loop.add(bass(notes[n] - 24, b * 1.2), at + beat)
            for beat in (1, 2.5):
                for n in notes:
                    loop.add(keys(n, b * 2.5), at + beat, 0.8)
            for i in range(8):
                loop.add(hat(), at + i * 0.5, 0.6 if i % 2 else 1.0)
            loop.add(kick(), at, 0.7)
            loop.add(rim(), at + 2, 0.8)
            loop.add(kick(), at + 2.5, 0.5)
            if bar % 2 == 1:
                for i, n in enumerate([notes[2], notes[1], notes[2] + 2 if quality != "m7" else notes[3]]):
                    loop.add(pluck(n + 12, b * 1.5), at + 2 + i * 0.5, 0.7)
        elif style == "intro":
            for i, n in enumerate([0, 1, 2, 1, len(notes) - 1, 2, 1, 2]):
                loop.add(keys(notes[n] + (12 if i == 4 else 0), b * 3), at + i * 0.5, 0.9)
            loop.add(bass(notes[0] - 24, b * 4), at, 0.8)
        elif style == "prep":
            for beat, n in [(0, 0), (0.75, 0), (1.5, 2), (2.5, 0), (3.25, 1), (3.5, 2)]:
                loop.add(bass(notes[n] - 24, b * 0.7), at + beat)
            for beat in (0.5, 1.75, 3):
                for n in notes[1:]:
                    loop.add(keys(n, b * 0.6), at + beat, 0.75)
            for i in range(16):
                loop.add(hat(0.03), at + i * 0.25, [1.0, 0.35, 0.6, 0.35][i % 4])
            loop.add(kick(), at, 0.7)
            loop.add(kick(), at + 2.5, 0.6)
            loop.add(rim(), at + 1)
            loop.add(rim(), at + 3)
        elif style == "service":
            for i in range(8):
                step = [0, 0, 2, 0, 0, 3 % len(notes), 2, 1][i]
                loop.add(bass(notes[step] - 24, b * 0.45), at + i * 0.5, 1.1)
            for i in range(16):
                loop.add(hat(0.03), at + i * 0.25, [1.0, 0.4, 0.7, 0.4][i % 4])
            for beat in range(4):
                loop.add(kick(), at + beat, 0.8)
            loop.add(snare(), at + 1)
            loop.add(snare(), at + 3)
            for beat in (0, 1.5, 3):
                for n in notes[:3]:
                    loop.add(pluck(n, b * 0.5), at + beat, 0.55)
            if bar % 4 == 3:
                for i in range(4):
                    loop.add(snare(), at + 3 + i * 0.25, 0.5 + i * 0.12)
        elif style == "critic":
            for i in range(8):
                loop.add(pluck(notes[[0, 2, 1, 2][i % 4]] + (12 if i == 7 else 0), b * 0.5), at + i * 0.5, 0.9)
            loop.add(bass(notes[0] - 24, b * 2), at, 1.0)
            loop.add(bass(notes[0] - 24, b * 1.5), at + 2.5, 0.8)
            for beat in range(4):
                loop.add(rim(), at + beat, 0.45 if beat % 2 else 0.7)
            if bar % 2 == 1:
                for n in notes:
                    loop.add(keys(n + 12, b * 3), at + 2, 0.6)
    out = loop.buf
    # A little room, folded round the loop the same way.
    tail = RNG.standard_normal(int(0.9 * RATE)) * np.exp(-np.arange(int(0.9 * RATE)) / (RATE * 0.18))
    wet = np.fft.irfft(np.fft.rfft(out) * np.fft.rfft(tail, len(out)), len(out))
    out = out + lowpass(wet, 3500) * 0.012
    return out / np.max(np.abs(out)) * 0.8


CUES = {
    "title": (92, [(57, "m7"), (53, "maj7"), (48, "maj7"), (55, "7")] * 2, "title"),
    "intro": (72, [(50, "m7"), (58, "maj7"), (53, "maj7"), (48, "M")] * 2, "intro"),
    "prep": (104, [(52, "m7"), (57, "7"), (52, "m7"), (59, "m7")] * 2, "prep"),
    "service": (136, [(52, "m"), (52, "m"), (48, "M"), (50, "M"), (52, "m"), (52, "m"), (55, "M"), (47, "M")], "service"),
    "critic": (116, [(57, "m"), (57, "m"), (53, "M"), (52, "M"), (57, "m"), (50, "m"), (53, "M"), (52, "7")], "critic"),
}


def save(name: str, sound: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "loop.wav"
        with wave.open(str(path), "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes((sound * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(path), "-c:a", "libvorbis", "-q:a", "3", str(OUT / f"music_{name}.ogg")], check=True)
    print(f"synthesized music_{name}.ogg {len(sound) / RATE:.1f}s")


def main() -> None:
    for name in sys.argv[1:] or CUES:
        bpm, progression, style = CUES[name]
        save(name, make(bpm, progression, style))


if __name__ == "__main__":
    main()
