"""Synthesize the sound effects with numpy: no samples, nothing borrowed.

    python tools/sfx.py            # -> assets/audio/*.wav (mono, 44.1 kHz, 16-bit)
    python tools/sfx.py fire printer  # just these

A kitchen's worth: tickets slapped down and pulled off, the bell on the
pass, plates landing, and the ticket machine that will not stop.
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


def chip() -> np.ndarray:
    """A ticket slapped down on steel."""
    x = lowpass(noise(0.05), 2600) * 2.0 + tone(sweep(520, 300, 0.05), 0.05) * 0.4
    return x * env(len(x), 0.001, 0.045) * 0.5


def erase() -> np.ndarray:
    """A ticket pulled off the rail."""
    x = highpass(lowpass(noise(0.09), sweep(3000, 900, 0.09)), 400)
    return x * env(len(x), 0.01, 0.07) * 0.5


def fire() -> np.ndarray:
    """The bell on the pass, hit once."""
    return bell(2093.0, 0.9) * 0.3


def plate() -> np.ndarray:
    """A plate set down under the lamps."""
    x = tone(1480, 0.09) * 0.5 + tone(2350, 0.09) * 0.3 + highpass(noise(0.09), 3000) * 0.25
    return x * env(len(x), 0.001, 0.08) * 0.35


def miss() -> np.ndarray:
    """A plate sent back: it lands heavier."""
    x = tone(sweep(200, 90, 0.16), 0.16, "tri") + lowpass(noise(0.16), 500) * 1.2
    return x * env(len(x), 0.002, 0.14) * 0.5


def buzz() -> np.ndarray:
    a = tone(140, 0.11, "square") * env(int(RATE * 0.11), 0.003, 0.05)
    return mix((a, 0.0), (a * 0.9, 0.14)) * 0.3


def win() -> np.ndarray:
    """Order up: the bell twice, and a chord plucked up under it."""
    notes = [(196.0, 0.0, 0.5), (246.9, 0.1, 0.5), (293.7, 0.2, 0.5), (392.0, 0.3, 1.0)]
    parts = [(pluck(freq, seconds, 0.55) * 0.4, start) for freq, start, seconds in notes]
    return mix(*parts, (bell(2093.0, 0.5) * 0.2, 0.0), (bell(2637.0, 0.9) * 0.2, 0.16))


def page() -> np.ndarray:
    """A sheet taped up: paper, then a thumb along the tape."""
    flap = highpass(lowpass(noise(0.16), sweep(1200, 5000, 0.16)), 600) * env(int(RATE * 0.16), 0.03, 0.1) * 0.6
    return mix((flap, 0.0), (chip() * 0.9, 0.15))


def sting() -> np.ndarray:
    """The door opens on somebody who matters: two low strings, shaken."""
    n = 1.4
    x = pluck(82.4, n, 0.6) + pluck(116.5, n, 0.6) * 0.8
    return x * (1 + 0.25 * np.sin(2 * np.pi * 6.5 * t(n))) * 0.55


def printer() -> np.ndarray:
    """The ticket machine: a chatter of little hammers, then the tear."""
    n = 0.9
    gate = (np.sin(2 * np.pi * 31 * t(n)) > 0.2).astype(float)
    chatter = highpass(lowpass(noise(n), 3800), 900) * gate * env(int(RATE * n), 0.01, 0.05) * 0.55
    hum = tone(118, n, "saw") * 0.06 * env(int(RATE * n), 0.01, 0.05)
    tear = highpass(lowpass(noise(0.14), sweep(2000, 7000, 0.14)), 1200) * env(int(RATE * 0.14), 0.01, 0.1) * 0.7
    return mix((chatter + hum, 0.0), (tear, n + 0.03))


SOUNDS = {
    "chip": chip, "erase": erase, "fire": fire, "plate": plate, "miss": miss, "buzz": buzz, "win": win,
    "page": page, "sting": sting, "printer": printer,
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
