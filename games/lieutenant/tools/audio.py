"""Synthesize the game's sound: effects and three music loops.

Everything is made here from sine waves and noise, with numpy, so it needs
no key and no network: an upright bass, a vibraphone, an electric piano and
brushes, playing an original minor blues. Music is written to OGG with
ffmpeg; effects are WAV.

    python tools/audio.py            # everything
    python tools/audio.py sfx        # just the effects
    python tools/audio.py music      # just the music

The other games' music is generated (see their tools/music.py). These loops
are stand-ins a generated score can replace, file for file.
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
SR = 44100


def hz(note: float) -> float:
    """MIDI note number to frequency."""
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def t(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def env(n: int, attack: float, decay: float) -> np.ndarray:
    x = np.arange(n) / SR
    return np.minimum(x / max(attack, 1e-4), 1.0) * np.exp(-x / decay)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spectrum / (1.0 + (freqs / cutoff) ** 4), len(x))


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spectrum * (1.0 - 1.0 / (1.0 + (freqs / cutoff) ** 4)), len(x))


def reverb(x: np.ndarray, seconds: float = 1.1, wet: float = 0.18, seed: int = 3) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    tail = rng.standard_normal(n) * np.exp(-np.arange(n) / (seconds * SR / 5.0))
    tail = lowpass(tail, 3800.0)
    tail /= np.sqrt(np.sum(tail ** 2))
    size = len(x) + n
    out = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(tail, size), size)[: len(x)]
    return x * (1.0 - wet * 0.3) + out * wet


def normalize(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    return x * (peak / max(1e-9, float(np.max(np.abs(x)))))


def write_wav(path: Path, x: np.ndarray) -> None:
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


def write_ogg(path: Path, x: np.ndarray) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "loop.wav"
        write_wav(wav, x)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3", str(path)], check=True)


# --- Instruments ------------------------------------------------------------

def bass(note: float, seconds: float) -> np.ndarray:
    """A plucked upright bass: a thump, then a round tone that dies away."""
    x = t(seconds)
    f = hz(note) * (1.0 + 0.012 * np.exp(-x * 30))
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(phase) + 0.42 * np.sin(2 * phase) * np.exp(-x * 5) + 0.16 * np.sin(3 * phase) * np.exp(-x * 9)
    thump = np.random.default_rng(int(note)).standard_normal(len(x)) * np.exp(-x * 190) * 0.3
    return (tone * env(len(x), 0.004, 0.55) + lowpass(thump, 900)) * 0.9


def vibes(note: float, seconds: float, velocity: float = 1.0) -> np.ndarray:
    """A vibraphone bar: a pure tone, a bright ring that fades fast, the motor's slow wobble."""
    x = t(seconds)
    f = hz(note)
    tone = np.sin(2 * np.pi * f * x) + 0.3 * np.sin(2 * np.pi * f * 4 * x) * np.exp(-x * 7) + 0.1 * np.sin(2 * np.pi * f * 10 * x) * np.exp(-x * 20)
    wobble = 1.0 + 0.22 * np.sin(2 * np.pi * 5.2 * x)
    return tone * wobble * env(len(x), 0.002, 1.1) * 0.5 * velocity


def keys(note: float, seconds: float, velocity: float = 1.0) -> np.ndarray:
    """An electric piano: a sine bent by another, the bend dying off (FM)."""
    x = t(seconds)
    f = hz(note)
    index = 1.6 * np.exp(-x * 6) + 0.25
    tone = np.sin(2 * np.pi * f * x + index * np.sin(2 * np.pi * f * x))
    tine = 0.12 * np.sin(2 * np.pi * f * 7 * x) * np.exp(-x * 30)
    return (tone + tine) * env(len(x), 0.004, 0.9) * 0.3 * velocity


def brush(seconds: float, seed: int, bright: float = 5200.0) -> np.ndarray:
    x = t(seconds)
    noise = np.random.default_rng(seed).standard_normal(len(x))
    return highpass(lowpass(noise, bright), 1800.0) * env(len(x), 0.02, seconds / 3.0) * 0.4


def ride(seconds: float, seed: int) -> np.ndarray:
    x = t(seconds)
    noise = np.random.default_rng(seed).standard_normal(len(x))
    ping = sum(np.sin(2 * np.pi * f * x) for f in (5210.0, 6730.0, 8115.0, 9340.0)) * 0.05
    return (highpass(noise, 6000.0) * 0.16 + ping) * env(len(x), 0.001, 0.16)


def kick(seconds: float = 0.3) -> np.ndarray:
    x = t(seconds)
    f = 52.0 + 60.0 * np.exp(-x * 40)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 14) * 0.5


class Track:
    def __init__(self, seconds: float) -> None:
        self.buffer = np.zeros(int(seconds * SR) + SR * 3)
        self.length = int(seconds * SR)

    def add(self, when: float, sound: np.ndarray, gain: float = 1.0) -> None:
        start = int(when * SR)
        if start >= len(self.buffer):
            return
        end = min(len(self.buffer), start + len(sound))
        self.buffer[start:end] += sound[: end - start] * gain

    def loop(self) -> np.ndarray:
        """Folds whatever rings on past the end back onto the start, so the
        loop has no seam."""
        out = self.buffer[: self.length].copy()
        tail = self.buffer[self.length:]
        out[: len(tail)] += tail[: len(out)]
        return out


# --- The tune ---------------------------------------------------------------

# A twelve-bar blues in D minor: (root, chord tones above it).
M7 = (0, 3, 7, 10)
DOM = (0, 4, 7, 10)
HALF_DIM = (0, 3, 6, 10)
BLUES = [(38, M7), (43, M7), (38, M7), (38, M7), (43, M7), (43, M7), (38, M7), (38, M7), (40, HALF_DIM), (45, DOM), (38, M7), (45, DOM)]

# Two choruses of melody: (bar, beat, note, beats long). Beats run 0..4.
HEAD = [
    (0, 0.0, 69, 1.5), (0, 1.67, 72, 0.5), (0, 2.0, 74, 2.0),
    (1, 1.0, 72, 0.67), (1, 1.67, 70, 0.5), (1, 2.0, 67, 2.0),
    (2, 0.0, 69, 1.5), (2, 1.67, 72, 0.5), (2, 2.0, 74, 1.0), (2, 3.0, 77, 1.0),
    (3, 0.0, 76, 0.67), (3, 0.67, 74, 2.5),
    (4, 0.0, 70, 1.5), (4, 1.67, 74, 0.5), (4, 2.0, 77, 2.0),
    (5, 1.0, 74, 0.67), (5, 1.67, 72, 0.5), (5, 2.0, 70, 2.0),
    (6, 0.0, 69, 1.0), (6, 1.0, 65, 0.67), (6, 1.67, 67, 0.5), (6, 2.0, 69, 2.0),
    (7, 2.0, 62, 0.67), (7, 2.67, 65, 0.5), (7, 3.0, 67, 1.0),
    (8, 0.0, 70, 1.0), (8, 1.0, 67, 0.67), (8, 1.67, 64, 0.5), (8, 2.0, 67, 2.0),
    (9, 0.0, 69, 1.0), (9, 1.0, 73, 1.0), (9, 2.0, 76, 1.0), (9, 3.0, 73, 1.0),
    (10, 0.0, 74, 3.0),
    (11, 1.67, 69, 0.5), (11, 2.0, 68, 0.67), (11, 2.67, 67, 0.5), (11, 3.0, 65, 1.0),
]


def walk(root: int, tones: tuple, next_root: int, bar: int) -> list[int]:
    """Four quarter notes: the root, two chord tones, a step into the next bar."""
    up = bar % 2 == 0
    second = root + (tones[1] if up else tones[2])
    third = root + (tones[2] if up else tones[1])
    approach = next_root + (1 if next_root < third else -1)
    return [root, second, third, approach]


def blues(bpm: float, choruses: int, swing: bool = True, drums: bool = True, head_gain: float = 1.0, comp_gain: float = 1.0) -> np.ndarray:
    beat = 60.0 / bpm
    bars = 12 * choruses
    track = Track(bars * 4 * beat)
    for bar in range(bars):
        root, tones = BLUES[bar % 12]
        next_root = BLUES[(bar + 1) % 12][0]
        start = bar * 4 * beat
        for i, note in enumerate(walk(root, tones, next_root, bar)):
            track.add(start + i * beat, bass(note, beat * 1.6), 0.8)
        # The electric piano answers on the "and" of two, and sometimes four.
        for when in ((1.67, 2.6) if bar % 4 != 3 else (0.0, 2.67)):
            for tone in tones[1:]:
                track.add(start + when * beat, keys(root + 12 + tone, beat * 2.0, 0.7), 0.5 * comp_gain)
        if drums:
            for i in range(4):
                track.add(start + i * beat, ride(0.5, bar * 8 + i), 0.5)
                if swing and i in (1, 3):
                    track.add(start + (i + 0.67) * beat, ride(0.4, bar * 8 + i + 4), 0.3)
                if i in (1, 3):
                    track.add(start + i * beat, brush(0.35, bar * 4 + i), 0.5)
            track.add(start, kick(), 0.4)
        if bar // 12 == choruses - 1 or choruses == 1 or bar // 12 == 0:
            for (b, when, note, length) in HEAD:
                if b == bar % 12:
                    octave = 12 if bar // 12 == 1 else 0
                    track.add(start + when * beat, vibes(note + octave, max(length * beat * 1.5, 0.6)), 0.55 * head_gain)
    return normalize(reverb(track.loop(), 1.2, 0.2), 0.8)


def cold(seconds: float = 28.0) -> np.ndarray:
    """Under the cold open: a low hum, a slow pulse, and a few notes from a
    piano somebody isn't sitting at."""
    track = Track(seconds)
    x = t(seconds)
    drone = sum(np.sin(2 * np.pi * hz(n) * (1 + d) * x) for n, d in ((26, 0.0), (26, 0.004), (33, 0.0), (38, -0.003))) * 0.09
    drone *= 0.75 + 0.25 * np.sin(2 * np.pi * x / (seconds / 4.0))
    track.add(0, drone)
    beat = seconds / 16.0
    for i in range(16):
        track.add(i * beat, kick(0.4), 0.5)
        if i % 4 == 2:
            track.add(i * beat + 0.28, kick(0.3), 0.3)
    notes = [(1.0, 74), (2.5, 73), (5.0, 69), (6.5, 70), (9.0, 77), (10.5, 76), (13.0, 74), (14.2, 68)]
    for when, note in notes:
        track.add(when * beat, vibes(note, 3.0, 0.8), 0.5)
        track.add(when * beat, keys(note - 12, 2.5, 0.5), 0.5)
    return normalize(reverb(track.loop(), 2.0, 0.34), 0.7)


# --- Effects ----------------------------------------------------------------

def sfx() -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    # A pencil tick, for picking a chip.
    x = t(0.06)
    out["bump"] = normalize(highpass(np.random.default_rng(1).standard_normal(len(x)), 1500) * np.exp(-x * 120) + np.sin(2 * np.pi * 880 * x) * np.exp(-x * 90) * 0.5, 0.5)
    # A page turning.
    x = t(0.32)
    sweep = lowpass(np.random.default_rng(2).standard_normal(len(x)), 5200) * np.sin(np.pi * x / 0.32) ** 2
    out["page"] = normalize(highpass(sweep, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * x)), 0.5)
    # A telephone dial running back: a train of clicks.
    track = Track(0.8)
    for i in range(9):
        c = t(0.03)
        click = highpass(np.random.default_rng(10 + i).standard_normal(len(c)), 2200) * np.exp(-c * 260)
        track.add(0.04 + i * 0.074, click, 0.7)
    whirr = lowpass(np.random.default_rng(3).standard_normal(int(0.8 * SR)), 500) * 0.12
    out["dial"] = normalize(track.buffer[: int(0.8 * SR)] + whirr * np.hanning(len(whirr)), 0.6)
    # A line printer: quick hammered rows.
    track = Track(0.6)
    for i in range(22):
        c = t(0.02)
        tap = np.random.default_rng(40 + i).standard_normal(len(c)) * np.exp(-c * 300)
        track.add(0.01 + i * 0.026, lowpass(tap, 3200), 0.6 + 0.3 * (i % 3 == 0))
    out["teletype"] = normalize(track.buffer[: int(0.6 * SR)], 0.55)
    # A desk bell: that's the one.
    x = t(0.9)
    out["ding"] = normalize(sum(np.sin(2 * np.pi * f * x) * np.exp(-x * d) * a for f, d, a in ((1568, 4, 1.0), (3136, 7, 0.4), (4700, 12, 0.2), (2349, 5, 0.3))), 0.6)
    # The machine doesn't like it.
    x = t(0.34)
    out["buzz"] = normalize(lowpass(np.sign(np.sin(2 * np.pi * 110 * x)) + 0.6 * np.sign(np.sin(2 * np.pi * 116.5 * x)), 1400) * np.minimum(1, (0.34 - x) * 30) * np.minimum(1, x * 200), 0.45)
    # He stops at the door: two notes on the bass, going up.
    track = Track(1.0)
    track.add(0.0, bass(45, 0.5))
    track.add(0.22, bass(50, 0.9))
    track.add(0.22, vibes(74, 0.9), 0.5)
    out["turn"] = normalize(reverb(track.buffer[: int(1.2 * SR)], 0.8, 0.2), 0.7)
    # The sting on a freeze frame: a low hit, a chord that hangs, a cymbal.
    track = Track(2.6)
    track.add(0.0, kick(0.5), 1.0)
    track.add(0.0, bass(38, 2.0), 0.9)
    for note in (62, 65, 69, 72, 76):
        track.add(0.02, keys(note, 2.4, 1.0), 0.8)
        track.add(0.16, vibes(note + 12, 2.2), 0.4)
    c = t(1.6)
    track.add(0.0, highpass(np.random.default_rng(9).standard_normal(len(c)), 5000) * np.exp(-c * 3.0) * 0.2)
    out["sting"] = normalize(reverb(track.buffer[: int(2.9 * SR)], 1.6, 0.3), 0.8)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    what = [a for a in sys.argv[1:] if not a.startswith("-")] or ["sfx", "music"]
    if "sfx" in what:
        for name, sound in sfx().items():
            write_wav(OUT / f"{name}.wav", sound)
            print(f"{name}.wav {len(sound) / SR:.2f}s")
    if "music" in what:
        loops = {
            # The case: a medium swing, the tune twice with a chorus of just the rhythm between.
            "music_case": blues(108, 3),
            # The title and the case files: the same blues, slow, no drums.
            "music_title": blues(72, 1, swing=False, drums=False, comp_gain=1.2),
            "music_cold": cold(),
        }
        for name, sound in loops.items():
            write_ogg(OUT / f"{name}.ogg", sound)
            print(f"{name}.ogg {len(sound) / SR:.1f}s {(OUT / f'{name}.ogg').stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
