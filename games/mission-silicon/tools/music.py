"""Generate the music and the stings.

Uses the Dunder Quest music helpers (../../dunder-quest/tools/generate_music.py
and make_loops.py) with this game's briefs: original glitchy electronic music,
bitcrushed synths and a drum machine. The briefs ask for the style and the
instruments only; they never name or describe any TV theme. Reads the key from
the repo's .env and never prints it.

    python tools/music.py                # every track and sting that's missing
    python tools/music.py live merge     # just these
    python tools/music.py --install      # redo the loop, cut and encode only

The music is looped like the other games' (make_loops.py's crossfade), then
encoded mono at a lower Vorbis quality than theirs to keep the phone build
small; the bitcrushed sound hides it. Each sting is cut from the start of its
generated track to a few seconds with a short fade.
"""

from __future__ import annotations

import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import generate_music as base  # noqa: E402
import make_loops  # noqa: E402

OUT = ROOT / "assets" / "audio"
base.RAW = HERE / "generated" / "music"
QUALITY = "1"
# Long tracks are cut to this before looping, so no loop runs much past a minute.
MAX_SECONDS = 80

COMMON = (
    "Instrumental only. No vocals, no lyrics, no speech, no vocal samples, no humming. "
    "Original music for a small 2D pixel-art comedy game about a scrappy tech startup. Do not imitate "
    "or quote any existing song, film score or TV theme; write a brand-new melody. "
)
LOOP = "Must loop seamlessly, about 60 to 90 seconds. "

TRACKS = {
    "title": COMMON + LOOP + (
        "Glitchy, confident electronic music: a punchy drum machine beat with crisp claps, a bouncy "
        "bitcrushed synth bass, a catchy bright arpeggiated lead made of crunchy lo-fi synth bleeps, "
        "stuttering glitch edits and little digital chirps. Smart, cocky and a bit nerdy, like a "
        "startup that thinks it will change the world. Major key, medium-quick tempo."
    ),
    "plan": COMMON + LOOP + (
        "Sparse, thoughtful glitchy electronic underscore for reading code late at night: a soft "
        "ticking drum machine, a warm muted bitcrushed synth pad, a gentle plucky arpeggio, occasional "
        "glitch blips and stutters, lots of space. Quiet enough to read over, curious, slightly "
        "nervous. Minor key leaning hopeful, relaxed tempo."
    ),
    "live": COMMON + LOOP + (
        "Driving, tense glitchy electronic music for a website buckling under a flood of traffic: a fast "
        "four-on-the-floor drum machine, a pulsing distorted bitcrushed synth bass, urgent stabbing "
        "synth chords, rising glitch stutters and alarm-like bleeps, building pressure. Exciting and a "
        "little panicky. Minor key, fast tempo."
    ),
}

STINGS = {
    "sting_title": (2.6, COMMON + (
        "A very short title-card sting, about 5 seconds: it starts instantly on a punchy drum machine hit "
        "and a bright bitcrushed synth chord stab, a quick stuttering glitch flourish, and ends on a "
        "clean confident final hit. Major key.")),
    "sting_merge": (2.2, COMMON + (
        "A very short triumphant sting, about 4 seconds: it starts instantly with a rising bitcrushed "
        "synth arpeggio and a drum machine fill, landing on a big bright major chord with a glitchy "
        "sparkle. Upbeat.")),
    "sting_fail": (3.0, COMMON + (
        "A very short comic failure sting, about 5 seconds: it starts instantly with a glitchy synth "
        "chord that stutters, bitcrushes harder and pitches down like a computer powering off, a "
        "falling drum machine fill, then a dead stop. Minor key, funny.")),
    "sting_postmortem": (2.6, COMMON + (
        "A very short deadpan sting, about 5 seconds: it starts instantly with two dry drum machine "
        "hits and a small, flat bitcrushed synth figure that ends on an unresolved, awkward chord, "
        "like an awkward pause in a meeting.")),
}


def encode(samples: np.ndarray, dest: Path) -> None:
    mono = samples.mean(axis=1).astype(np.float32)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ac", "1", "-ar", str(make_loops.RATE),
         "-i", "-", "-c:a", "libvorbis", "-q:a", QUALITY, str(dest)],
        input=mono.tobytes(), check=True,
    )
    print(f"INSTALLED {dest.name} {dest.stat().st_size // 1024} KiB", flush=True)


def install_music(name: str) -> None:
    # make_loops works in place on an ogg; loop a full-quality copy, then encode it small.
    work = base.RAW / f"{name}.loop.ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(base.RAW / f"{name}.mp3"), "-t", str(MAX_SECONDS),
                    "-ac", "2", "-ar", str(make_loops.RATE), "-c:a", "libvorbis", "-q:a", "6", str(work)], check=True)
    make_loops.make_loop(work)
    encode(make_loops.decode(work), OUT / f"music_{name}.ogg")


def install_sting(name: str) -> None:
    seconds = STINGS[name][0]
    samples = make_loops.decode(base.RAW / f"{name}.mp3")
    # Start at the first sound, not the silence some tracks open with.
    loud = np.where(np.abs(samples).max(axis=1) > 0.02)[0]
    start = int(loud[0]) if len(loud) else 0
    clip = samples[start:start + int(seconds * make_loops.RATE)].copy()
    fade = int(0.5 * make_loops.RATE)
    clip[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)[:, None]
    encode(clip, OUT / f"{name}.ogg")


def install(name: str) -> None:
    if name in STINGS:
        install_sting(name)
    else:
        install_music(name)


def target(name: str) -> Path:
    return OUT / (f"{name}.ogg" if name in STINGS else f"music_{name}.ogg")


def main() -> None:
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = names or [n for n in list(TRACKS) + list(STINGS) if not target(n).exists()]
    OUT.mkdir(parents=True, exist_ok=True)
    base.RAW.mkdir(parents=True, exist_ok=True)
    if "--install" in sys.argv:
        for name in names:
            install(name)
        return
    base.TRACKS = {**TRACKS, **{n: brief for n, (_s, brief) in STINGS.items()}}
    env = base.load_env(base.ENV_PATH)
    key = env.get("OPENROUTER_API_KEY", "")
    url = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(base.generate, url, key, name): name for name in names}
        for future in as_completed(futures):
            name = futures[future]
            try:
                future.result()
                install(name)
            except Exception as exc:  # keep the other tracks going
                print(f"MUSIC fail {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
