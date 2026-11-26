"""Synthesize the sound effects with numpy: no samples, nothing borrowed.

    python tools/sfx.py            # -> assets/audio/*.wav (mono, 44.1 kHz, 16-bit)
    python tools/sfx.py shot toot  # just these

The plucked notes are Karplus-Strong strings, which is about as close as a
dozen lines of arithmetic gets to a twangy guitar.
"""

from __future__ import annotations

import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
RATE = 44100
RNG = np.random.default_rng(1874)


def t(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def env(n: int, attack: float, release: float) -> np.ndarray:
    """A linear attack and a curved release, in seconds."""
    out = np.ones(n)
    a = max(1, min(n, int(RATE * attack)))
    out[:a] = np.linspace(0.0, 1.0, a)
    r = max(1, min(n, int(RATE * release)))
    out[-r:] *= np.linspace(1.0, 0.0, r) ** 2
    return out


def tone(freq: float | np.ndarray, seconds: float, shape: str = "sine") -> np.ndarray:
    x = t(seconds)
    phase = 2 * np.pi * np.cumsum(np.broadcast_to(freq, x.shape)) / RATE
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "saw":
        return (phase / np.pi) % 2.0 - 1.0
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


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


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


def pluck(freq: float, seconds: float, bright: float = 0.5) -> np.ndarray:
    """A Karplus-Strong string: a burst of noise going round a short loop."""
    period = max(2, int(RATE / freq))
    buf = RNG.uniform(-1.0, 1.0, period)
    n = int(RATE * seconds)
    out = np.empty(n)
    for i in range(n):
        j = i % period
        out[i] = buf[j]
        buf[j] = (bright * buf[j] + (1.0 - bright) * buf[(j + 1) % period]) * 0.996
    return out * env(n, 0.001, seconds * 0.5)


def chip() -> np.ndarray:
    """A wooden tile put down on a desk."""
    x = lowpass(noise(0.05), 2200) * 2.0 + tone(sweep(420, 260, 0.05), 0.05) * 0.5
    return x * env(len(x), 0.001, 0.045) * 0.5


def erase() -> np.ndarray:
    x = highpass(lowpass(noise(0.09), sweep(3000, 900, 0.09)), 400)
    return x * env(len(x), 0.01, 0.07) * 0.5


def draw() -> np.ndarray:
    """A hammer cocked: two small iron clicks."""
    def click(freq: float) -> np.ndarray:
        c = (tone(freq, 0.04, "square") * 0.3 + highpass(noise(0.04), 2500) * 0.8) * env(int(RATE * 0.04), 0.0005, 0.035)
        return c
    return mix((click(1900), 0.0), (click(1300), 0.085)) * 0.5


def shot() -> np.ndarray:
    """A pistol shot and the whine of it going off a rock."""
    bang = lowpass(noise(0.18), sweep(6000, 500, 0.18)) * env(int(RATE * 0.18), 0.0005, 0.17) * 1.3
    boom = tone(sweep(160, 50, 0.16), 0.16) * env(int(RATE * 0.16), 0.001, 0.15) * 0.8
    n = 0.42
    whine = tone(sweep(2300, 700, n), n) * (1 + 0.25 * np.sin(2 * np.pi * 28 * t(n))) * env(int(RATE * n), 0.02, 0.38) * 0.22
    return mix((bang + np.pad(boom, (0, len(bang) - len(boom))), 0.0), (whine, 0.05)) * 0.6


def tip() -> np.ndarray:
    """A hat tipped: a soft two-note whistle."""
    a = tone(1320, 0.07) * env(int(RATE * 0.07), 0.01, 0.05)
    b = tone(1760, 0.1) * env(int(RATE * 0.1), 0.01, 0.08)
    return mix((a, 0.0), (b, 0.07)) * 0.16


def miss() -> np.ndarray:
    x = tone(sweep(200, 90, 0.16), 0.16, "tri") + lowpass(noise(0.16), 500) * 1.2
    return x * env(len(x), 0.002, 0.14) * 0.5


def buzz() -> np.ndarray:
    a = tone(140, 0.11, "square") * env(int(RATE * 0.11), 0.003, 0.05)
    return mix((a, 0.0), (a * 0.9, 0.14)) * 0.3


def win() -> np.ndarray:
    """Four plucked notes up a major chord, and the last one rings."""
    notes = [(196.0, 0.0, 0.5), (246.9, 0.11, 0.5), (293.7, 0.22, 0.5), (392.0, 0.34, 1.1)]
    return mix(*[(pluck(freq, seconds, 0.55) * 0.5, start) for freq, start, seconds in notes])


def page() -> np.ndarray:
    """A notice pinned up: paper, then a tack."""
    flap = highpass(lowpass(noise(0.16), sweep(1200, 5000, 0.16)), 600) * env(int(RATE * 0.16), 0.03, 0.1) * 0.6
    return mix((flap, 0.0), (chip() * 0.9, 0.15))


def sting() -> np.ndarray:
    """Trouble walks in: two low strings a tritone apart, shaken."""
    n = 1.4
    x = pluck(82.4, n, 0.6) + pluck(116.5, n, 0.6) * 0.8
    return x * (1 + 0.25 * np.sin(2 * np.pi * 6.5 * t(n))) * 0.55


def toot() -> np.ndarray:
    """The beans, speaking: a low raspberry that wobbles up and gives out."""
    n = 0.5
    wobble = 1 + 0.08 * np.sin(2 * np.pi * 9 * t(n)) + 0.04 * RNG.standard_normal(int(RATE * n)).cumsum() / 40.0
    freq = np.linspace(82, 128, int(RATE * n)) * wobble
    rasp = tone(freq, n, "saw") * (0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 47 * t(n))))
    x = lowpass(rasp + noise(n) * 0.25, 900) * 2.2
    squeak = tone(sweep(300, 520, 0.09), 0.09, "saw") * env(int(RATE * 0.09), 0.01, 0.06) * 0.25
    return mix((x * env(len(x), 0.02, 0.1), 0.0), (lowpass(squeak, 1500), n - 0.03)) * 0.6


def scratch() -> np.ndarray:
    """The band stops dead: a needle dragged off a record."""
    n = 0.5
    pitch = tone(sweep(1400, 90, n), n, "saw") * 0.35
    hiss = highpass(lowpass(noise(n), sweep(7000, 600, n)), 300)
    x = (pitch + hiss) * (0.6 + 0.4 * np.sin(2 * np.pi * sweep(60, 8, n) * t(n)))
    return x * env(len(x), 0.003, 0.2) * 0.5


def thud() -> np.ndarray:
    """Big Backtrack sets a foot down."""
    x = tone(sweep(90, 38, 0.4), 0.4) * 1.2 + lowpass(noise(0.4), 220) * 2.5
    return x * env(len(x), 0.003, 0.36) * 0.75


def crash() -> np.ndarray:
    """A brawl going through a wall: boards, then glass, then a pan lid."""
    parts = []
    for start in (0.0, 0.07, 0.16, 0.3):
        crack = lowpass(noise(0.2), sweep(4000, 300, 0.2)) * env(int(RATE * 0.2), 0.001, 0.18) * 1.2
        parts.append((crack, start))
    glass = highpass(noise(0.5), 4000) * env(int(RATE * 0.5), 0.002, 0.45) * 0.35
    lid = (tone(523, 0.7) + 0.6 * tone(1187, 0.7) + 0.4 * tone(1873, 0.7)) * env(int(RATE * 0.7), 0.001, 0.65) * 0.14
    parts += [(glass, 0.22), (lid, 0.48), (thud() * 0.7, 0.02)]
    return mix(*parts) * 0.6


SOUNDS = {
    "chip": chip, "erase": erase, "draw": draw, "shot": shot, "tip": tip, "miss": miss, "buzz": buzz, "win": win,
    "page": page, "sting": sting, "toot": toot, "scratch": scratch, "thud": thud, "crash": crash,
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
