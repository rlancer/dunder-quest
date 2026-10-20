"""Turn generated music into seamless loops.

Generated tracks fade in and fade out, which leaves a dip to near silence every
time the loop wraps. This trims to the full-volume body, then folds the last
CROSSFADE seconds over the first ones so the end flows straight into the start.

    python tools/make_loops.py assets/audio/music_amber.ogg [...]
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100
CROSSFADE = 2.0
WINDOW = 0.25


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def encode(samples: np.ndarray, path: Path) -> None:
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-i", "-",
         "-c:a", "libvorbis", "-q:a", "4", str(path)],
        input=samples.astype(np.float32).tobytes(), check=True,
    )


def loudness(samples: np.ndarray) -> np.ndarray:
    """RMS in dB for each WINDOW-second block."""
    block = int(RATE * WINDOW)
    count = len(samples) // block
    blocks = samples[: count * block].reshape(count, block, 2)
    rms = np.sqrt(np.mean(blocks ** 2, axis=(1, 2)) + 1e-12)
    return 20.0 * np.log10(rms)


def make_loop(path: Path) -> None:
    samples = decode(path)
    db = loudness(samples)
    body = np.median(db)
    loud = np.where(db > body - 6.0)[0]
    start = int(loud[0] * WINDOW * RATE)
    end = int((loud[-1] + 1) * WINDOW * RATE)
    fade = int(CROSSFADE * RATE)
    if end - start < fade * 4:
        print(f"SKIP {path.name}: body too short")
        return
    segment = samples[start:end]
    head = segment[:fade]
    loop = segment[fade:].copy()
    # Equal-power crossfade: the tail fades out while the head fades in.
    t = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
    loop[-fade:] = loop[-fade:] * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    encode(loop, path)
    print(f"LOOPED {path.name}: {len(samples) / RATE:.1f}s -> {len(loop) / RATE:.1f}s "
          f"(trimmed {start / RATE:.1f}s head, {(len(samples) - end) / RATE:.1f}s tail)")


def main() -> None:
    for name in sys.argv[1:]:
        make_loop(Path(name))


if __name__ == "__main__":
    main()
