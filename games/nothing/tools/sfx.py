"""Synthesize the sound effects with numpy: no samples, nothing borrowed.

    python tools/sfx.py                # -> assets/audio/*.wav (mono, 44.1 kHz, 16-bit)
    python tools/sfx.py sting card     # just these

A sitcom's worth: cue cards slapped down and pulled off, the tape rolling,
applause, a door flung open by somebody who never knocks, and a slapped
bass between the scenes (an original riff, made here a note at a time).
"""

from __future__ import annotations

import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
RATE = 44100
RNG = np.random.default_rng(1971)


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


def bell(freq: float, seconds: float) -> np.ndarray:
    """A struck bell: a note and the partials that sit oddly over it."""
    n = int(RATE * seconds)
    x = tone(freq, seconds) + 0.5 * tone(freq * 2.76, seconds) + 0.25 * tone(freq * 5.4, seconds) + 0.12 * tone(freq * 8.9, seconds)
    return x * np.exp(-t(seconds) * 5.0 / seconds) * env(n, 0.001, 0.02)


def card() -> np.ndarray:
    """A cue card slapped down on a script."""
    x = lowpass(noise(0.05), 2200) * 2.0 + tone(sweep(420, 240, 0.05), 0.05) * 0.4
    return x * env(len(x), 0.001, 0.045) * 0.5


def erase() -> np.ndarray:
    """A cue card pulled back off."""
    x = highpass(lowpass(noise(0.09), sweep(3000, 900, 0.09)), 400)
    return x * env(len(x), 0.01, 0.07) * 0.5


def tick() -> np.ndarray:
    """A pencil tapped on the page."""
    x = highpass(noise(0.02), 2500) + tone(1800, 0.02) * 0.3
    return x * env(len(x), 0.0005, 0.018) * 0.35


def buzz() -> np.ndarray:
    a = tone(140, 0.11, "square") * env(int(RATE * 0.11), 0.003, 0.05)
    return mix((a, 0.0), (a * 0.9, 0.14)) * 0.3


def thumb(freq: float, seconds: float) -> np.ndarray:
    """A slapped bass note: the thumb's thwack, then the string."""
    string = pluck(freq, seconds, 0.72)
    hit = lowpass(noise(0.012), 900) * env(int(RATE * 0.012), 0.0005, 0.01) * 1.6
    thump = tone(freq * 2, 0.04) * env(int(RATE * 0.04), 0.0005, 0.035) * 0.5
    return mix((string, 0.0), (hit, 0.0), (thump, 0.0))


def pop(freq: float, seconds: float) -> np.ndarray:
    """A popped bass note: a finger snaps the string back on the frets."""
    string = pluck(freq, seconds, 0.85)
    snap = highpass(noise(0.008), 2500) * env(int(RATE * 0.008), 0.0003, 0.007) * 1.2
    return mix((string, 0.0), (snap, 0.0))


def riff(notes: list[tuple[str, float, float, float]]) -> np.ndarray:
    parts = []
    for kind, freq, start, seconds in notes:
        parts.append(((thumb if kind == "t" else pop)(freq, seconds) * (0.8 if kind == "t" else 0.6), start))
    return mix(*parts)


def sting() -> np.ndarray:
    """Between scenes: four slapped and popped notes, an original little figure."""
    e2, g2, a2, e3, b2, d3 = 82.4, 98.0, 110.0, 164.8, 123.5, 146.8
    return riff([("t", e2, 0.0, 0.3), ("p", e3, 0.11, 0.2), ("t", g2, 0.22, 0.25), ("t", a2, 0.36, 0.2),
                 ("p", d3, 0.47, 0.18), ("t", b2, 0.58, 0.18), ("t", e2, 0.72, 0.6)]) * 0.9


def air() -> np.ndarray:
    """A line goes out on air: one popped note."""
    return pop(196.0, 0.25) * 0.45


def miss() -> np.ndarray:
    """A line out of place: a bass note bent down."""
    x = tone(sweep(130, 70, 0.22), 0.22, "tri") + lowpass(noise(0.22), 400) * 0.6
    return x * env(len(x), 0.002, 0.2) * 0.5


def roll() -> np.ndarray:
    """Roll tape: the deck's latch, then the motor running up."""
    clunk = lowpass(noise(0.06), 700) * env(int(RATE * 0.06), 0.001, 0.05) * 1.4
    motor = tone(sweep(40, 120, 0.5), 0.5, "saw") * 0.12 + highpass(lowpass(noise(0.5), 1500), 300) * 0.1
    motor = motor * env(len(motor), 0.15, 0.2)
    return mix((clunk, 0.0), (motor, 0.05))


def claps(seconds: float, density: float) -> np.ndarray:
    """A room clapping: hundreds of little bursts of noise, all at once."""
    n = int(RATE * seconds)
    out = np.zeros(n)
    count = int(seconds * density)
    for _ in range(count):
        at = int(RNG.uniform(0, n - 2000))
        length = int(RNG.uniform(250, 700))
        burst = RNG.uniform(-1, 1, length) * np.exp(-np.arange(length) / (length / 4))
        out[at:at + length] += burst * RNG.uniform(0.3, 1.0)
    out = highpass(lowpass(out, 3500), 500)
    return out * env(n, seconds * 0.15, seconds * 0.5)


def applause() -> np.ndarray:
    """The studio audience, pleased."""
    return claps(1.8, 900) * 0.25


def page() -> np.ndarray:
    """A sheet turned over: paper, then the card set down."""
    flap = highpass(lowpass(noise(0.16), sweep(1200, 5000, 0.16)), 600) * env(int(RATE * 0.16), 0.03, 0.1) * 0.6
    return mix((flap, 0.0), (card() * 0.9, 0.15))


def door() -> np.ndarray:
    """A door flung open by somebody who has never knocked."""
    latch = highpass(noise(0.03), 1500) * env(int(RATE * 0.03), 0.001, 0.025) * 0.8
    swoosh = highpass(lowpass(noise(0.25), sweep(600, 3000, 0.25)), 300) * env(int(RATE * 0.25), 0.05, 0.1) * 0.5
    bang = (lowpass(noise(0.3), 400) * 1.5 + tone(sweep(90, 50, 0.3), 0.3) * 0.6) * env(int(RATE * 0.3), 0.001, 0.28)
    return mix((latch, 0.0), (swoosh, 0.03), (bang, 0.24)) * 0.7


def win() -> np.ndarray:
    """That's a wrap: the riff, and the room applauding."""
    return mix((sting(), 0.0), (claps(2.4, 1100) * 0.25, 0.5))


SOUNDS = {
    "card": card, "erase": erase, "tick": tick, "buzz": buzz, "sting": sting, "air": air, "miss": miss,
    "roll": roll, "applause": applause, "page": page, "door": door, "win": win,
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
