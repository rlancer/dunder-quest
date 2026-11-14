"""Synthesize the sound effects with numpy: no samples, nothing borrowed.

    python tools/sfx.py            # -> assets/audio/*.wav (mono, 44.1 kHz, 16-bit)
    python tools/sfx.py rewind     # just these
"""

from __future__ import annotations

import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
RATE = 44100
RNG = np.random.default_rng(7)


def t(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def env(n: int, attack: float, release: float) -> np.ndarray:
    """A linear attack and an exponential-ish release, in seconds."""
    out = np.ones(n)
    a = max(1, int(RATE * attack))
    out[:a] = np.linspace(0.0, 1.0, a)
    r = max(1, min(n, int(RATE * release)))
    out[-r:] *= np.linspace(1.0, 0.0, r) ** 2
    return out


def tone(freq: float | np.ndarray, seconds: float, shape: str = "sine") -> np.ndarray:
    x = t(seconds)
    phase = 2 * np.pi * np.cumsum(np.broadcast_to(freq, x.shape)) / RATE
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    return np.sin(phase)


def noise(seconds: float) -> np.ndarray:
    return RNG.uniform(-1.0, 1.0, int(RATE * seconds))


def lowpass(x: np.ndarray, cutoff: float | np.ndarray) -> np.ndarray:
    """One-pole lowpass; `cutoff` in Hz may sweep."""
    alpha = np.broadcast_to(1.0 - np.exp(-2 * np.pi * np.asarray(cutoff, dtype=float) / RATE), x.shape)
    out = np.empty_like(x)
    y = 0.0
    for i in range(len(x)):
        y += alpha[i] * (x[i] - y)
        out[i] = y
    return out


def mix(*parts: tuple[np.ndarray, float]) -> np.ndarray:
    """Layers (sound, start in seconds)."""
    length = max(int(RATE * start) + len(sound) for sound, start in parts)
    out = np.zeros(length)
    for sound, start in parts:
        at = int(RATE * start)
        out[at:at + len(sound)] += sound
    return out


def sweep(a: float, b: float, seconds: float) -> np.ndarray:
    return np.geomspace(a, b, int(RATE * seconds))


def jump() -> np.ndarray:
    x = tone(sweep(260, 520, 0.13), 0.13, "tri")
    return x * env(len(x), 0.005, 0.1) * 0.5


def land() -> np.ndarray:
    x = lowpass(noise(0.1), 500) * 2.0 + tone(sweep(120, 60, 0.1), 0.1) * 0.8
    return x * env(len(x), 0.002, 0.09) * 0.6


def torch() -> np.ndarray:
    x = lowpass(noise(0.45), sweep(400, 2600, 0.45)) * 1.6
    return x * env(len(x), 0.08, 0.3) * 0.6


def lever() -> np.ndarray:
    def clank(freq: float) -> np.ndarray:
        c = (tone(freq, 0.09, "square") * 0.4 + lowpass(noise(0.09), 3000)) * env(int(RATE * 0.09), 0.001, 0.08)
        return c
    return mix((clank(420), 0.0), (clank(300), 0.11)) * 0.55


def gate() -> np.ndarray:
    x = lowpass(noise(0.7), 240) * 3.0 * (1 + 0.5 * np.sin(2 * np.pi * 23 * t(0.7)))
    return mix((x * env(len(x), 0.05, 0.35) * 0.55, 0.0), (land() * 1.2, 0.6))


def commit() -> np.ndarray:
    """The seal: two bright bell notes, a fifth apart."""
    def bell(freq: float, seconds: float) -> np.ndarray:
        b = tone(freq, seconds) + 0.4 * tone(freq * 2.01, seconds) + 0.2 * tone(freq * 3.02, seconds)
        return b * env(len(b), 0.002, seconds * 0.95)
    return mix((bell(880, 0.35), 0.0), (bell(1318.5, 0.6), 0.1)) * 0.3


def rewind() -> np.ndarray:
    """The sands run backward: a swelling hiss sucked up through a falling whistle."""
    n = 0.75
    hiss = lowpass(noise(n), sweep(600, 6000, n)) * np.linspace(0.05, 1.0, int(RATE * n)) ** 2 * 1.4
    whistle = tone(sweep(1500, 300, n), n) * np.linspace(0.0, 1.0, int(RATE * n)) * 0.25
    flutter = 1 + 0.4 * np.sin(2 * np.pi * 18 * t(n))
    x = (hiss + whistle) * flutter
    x[-int(RATE * 0.03):] *= np.linspace(1.0, 0.0, int(RATE * 0.03))
    return x * 0.55


def death() -> np.ndarray:
    shing = lowpass(noise(0.25), 7000) * env(int(RATE * 0.25), 0.001, 0.24) * 0.5
    ring = tone(2400, 0.25) * env(int(RATE * 0.25), 0.001, 0.24) * 0.15
    thud = (tone(sweep(110, 45, 0.35), 0.35) + lowpass(noise(0.35), 300) * 2.0) * env(int(RATE * 0.35), 0.002, 0.3) * 0.7
    return mix((shing + ring, 0.0), (thud, 0.06))


def error() -> np.ndarray:
    a = tone(150, 0.11, "square") * env(int(RATE * 0.11), 0.003, 0.05)
    return mix((a, 0.0), (a * 0.9, 0.14)) * 0.3


def conflict() -> np.ndarray:
    """Two timelines at once: a semitone clash."""
    n = 0.6
    x = tone(440, n, "tri") + tone(466.2, n, "tri") + 0.5 * tone(220, n, "square")
    return x * env(len(x), 0.005, 0.5) * (1 + 0.3 * np.sin(2 * np.pi * 11 * t(n))) * 0.28


def draw() -> np.ndarray:
    """The dagger leaving its sheath."""
    x = lowpass(noise(0.22), sweep(1800, 9000, 0.22)) + tone(sweep(900, 2600, 0.22), 0.22) * 0.12
    return x * env(len(x), 0.01, 0.12) * 0.4


def clear() -> np.ndarray:
    notes = [(587.3, 0.0), (740.0, 0.12), (880.0, 0.24), (1174.7, 0.38)]
    parts = []
    for freq, start in notes:
        seconds = 0.9 if start > 0.3 else 0.3
        n = tone(freq, seconds, "tri") + 0.3 * tone(freq * 2, seconds)
        parts.append((n * env(len(n), 0.004, seconds * 0.9) * 0.3, start))
    return mix(*parts)


def vizier() -> np.ndarray:
    n = 1.1
    x = tone(73.4, n, "square") * 0.5 + tone(77.8, n, "tri") + lowpass(noise(n), 400)
    return x * env(len(x), 0.4, 0.5) * 0.35


SOUNDS = {
    "jump": jump, "land": land, "torch": torch, "lever": lever, "gate": gate, "commit": commit, "rewind": rewind,
    "death": death, "error": error, "conflict": conflict, "draw": draw, "clear": clear, "vizier": vizier,
}


def save(name: str, sound: np.ndarray) -> None:
    peak = float(np.max(np.abs(sound))) or 1.0
    if peak > 0.95:
        sound = sound * (0.95 / peak)
    data = (sound * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    print(f"synthesized {name}.wav {len(sound) / RATE:.2f}s")


def main() -> None:
    for name in sys.argv[1:] or SOUNDS:
        save(name, SOUNDS[name]())


if __name__ == "__main__":
    main()
