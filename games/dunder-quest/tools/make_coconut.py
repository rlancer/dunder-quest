"""Synthesize the coconut clop: two hollow shell halves knocked together.

A clop is a burst of noise rung through a few short resonances (the shells'
hollow tones), with a fast attack and a quick decay. Deterministic, so the
file only changes when this script does.

    python tools/make_coconut.py
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "coconut.wav"
RATE = 44100
LENGTH = 0.11
# (frequency in Hz, decay per second, weight): the hollow body and a click on top.
MODES = [(520.0, 38.0, 1.0), (910.0, 52.0, 0.55), (1630.0, 90.0, 0.3), (3100.0, 160.0, 0.18)]


def clop() -> list[float]:
    rng = random.Random(7)
    count = int(RATE * LENGTH)
    out = []
    for i in range(count):
        t = i / RATE
        tone = sum(w * math.exp(-d * t) * math.sin(2.0 * math.pi * f * t) for f, d, w in MODES)
        click = rng.uniform(-1.0, 1.0) * math.exp(-t * 400.0) * 0.6
        attack = min(1.0, t / 0.0015)
        out.append((tone + click) * attack)
    peak = max(abs(v) for v in out)
    return [v / peak * 0.45 for v in out]


def main() -> None:
    samples = clop()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in samples))
    print(f"wrote {OUT.relative_to(ROOT)} ({len(samples)} samples)")


if __name__ == "__main__":
    main()
