"""Generate the title and scene music, the end-of-scene sting and a few SFX.

Uses the Dunder Quest music helpers (../../dunder-quest/tools/generate_music.py)
with this game's briefs: bouncy Italian-library-style comedy music (tuba,
mandolin, pizzicato), all original. The briefs ask for the style and the
instruments only; they never name or describe any TV theme. Reads the key
from the repo's .env and never prints it.

    python tools/music.py                # every track and SFX that's missing
    python tools/music.py title sting    # just these
    python ../dunder-quest/tools/make_loops.py assets/audio/music_*.ogg   # then loop the music

The sting is cut from the start of its generated track to a few seconds with
a short fade (`--sting-only` redoes just that cut).
"""

from __future__ import annotations

import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import generate_music as base  # noqa: E402
from generate_assets import request_bytes  # noqa: E402
from generate_trailer_audio import raw_audio  # noqa: E402

OUT = ROOT / "assets" / "audio"
base.RAW = HERE / "generated" / "music"
SFX_MODEL = "bytedance-seed/seed-audio-1-0"
STING_SECONDS = 5.5

COMMON = (
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no whistling. "
    "Original music for a small 2D pixel-art comedy game. Do not imitate or quote any existing song, "
    "film score or TV theme; write a brand-new melody. "
)
LOOP = "Must loop seamlessly, about 60 to 90 seconds. "

TRACKS = {
    "title": COMMON + LOOP + (
        "A bouncy, cheeky 1960s Italian library-music comedy tune: an oom-pah tuba bass line, a bright "
        "mandolin melody, pizzicato strings, a little glockenspiel and a jaunty clarinet, light brushed "
        "percussion. Silly, sunny and a bit smug, like a man who is sure he is right. Major key, "
        "medium-quick bouncy tempo."
    ),
    "scene": COMMON + LOOP + (
        "Light, sparse awkward-comedy underscore for small talk at a Los Angeles party: soft pizzicato "
        "strings tiptoeing, a plucked mandolin, a gentle tuba on the off-beats, a muted trumpet answering "
        "now and then, lots of space. Quiet enough to talk over. Major key, relaxed bouncy tempo."
    ),
    "tension": COMMON + LOOP + (
        "Tiptoeing comic-suspense underscore for a petty social standoff: staccato pizzicato strings, a "
        "low sneaking bassoon and tuba, a nervous clarinet trill, a woodblock tick, mock-serious and "
        "silly. Minor key, slow creeping tempo."
    ),
    "sting": COMMON + (
        "A very short comic end-of-scene sting, about 8 seconds: it starts instantly on a big bouncy tuba "
        "and pizzicato hit, a quick cheeky mandolin and clarinet flourish, oom-pah tuba, and ends with a "
        "clean final button chord. Major key, bouncy."
    ),
}

SFX = {
    "scratch": "A single one second vinyl record scratch, the needle dragged sharply across a record, then "
               "silence. No voice, no music.",
}


def generate_sfx(url: str, key: str, name: str) -> Path:
    body = {"model": SFX_MODEL, "input": SFX[name], "response_format": "mp3"}
    raw, content_type = request_bytes(f"{url}/audio/speech", key, body, timeout=200)
    audio = raw_audio(raw, content_type)
    if len(audio) < 2000:
        raise RuntimeError(f"{name} response was {len(audio)} bytes, type {content_type}")
    base.RAW.mkdir(parents=True, exist_ok=True)
    path = base.RAW / f"sfx_{name}.mp3"
    path.write_bytes(audio)
    return path


def to_wav(source: Path, dest: Path, seconds: float | None = None) -> None:
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-ac", "1", "-ar", "44100"]
    if seconds:
        command += ["-t", str(seconds), "-af", f"afade=t=out:st={seconds - 0.8}:d=0.8"]
    command += [str(dest)]
    subprocess.run(command, check=True)
    print(f"INSTALLED {dest.name}", flush=True)


def install(name: str, path: Path) -> None:
    if name == "sting":
        to_wav(path, OUT / "sting.wav", STING_SECONDS)
    elif name in SFX:
        to_wav(path, OUT / f"{name}.wav")
    else:
        base.to_ogg(path, OUT / f"music_{name}.ogg")


def target(name: str) -> Path:
    if name == "sting" or name in SFX:
        return OUT / f"{name}.wav"
    return OUT / f"music_{name}.ogg"


def main() -> None:
    if "--sting-only" in sys.argv:
        install("sting", base.RAW / "sting.mp3")
        return
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = names or [n for n in list(TRACKS) + list(SFX) if not target(n).exists()]
    base.TRACKS = TRACKS
    env = base.load_env(base.ENV_PATH)
    key = env.get("OPENROUTER_API_KEY", "")
    url = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {}
        for name in names:
            job = generate_sfx if name in SFX else base.generate
            futures[pool.submit(job, url, key, name)] = name
        for future in as_completed(futures):
            name = futures[future]
            try:
                install(name, future.result())
            except Exception as exc:  # keep the other tracks going
                print(f"MUSIC fail {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
