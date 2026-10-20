"""Generate the per-area music tracks and store them as looping Ogg Vorbis.

Reuses the request helpers in generate_assets.py. Never prints the key.

    python tools/generate_music.py             # generate every track
    python tools/generate_music.py cinder      # just one
"""

from __future__ import annotations

import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_assets import (  # noqa: E402
    ENV_PATH,
    audio_from_json,
    audio_from_sse,
    load_env,
    request_bytes,
)

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "tools" / "generated" / "music"
OUT = ROOT / "assets" / "audio"
MODEL = "google/lyria-3-pro-preview"

COMMON = (
    "Instrumental only. No vocals, no lyrics, no speech, no humming. "
    "Original music for a small 2D pixel platformer; must loop seamlessly, about 60 to 90 seconds. "
    "Do not imitate any existing game soundtrack. "
)

TRACKS = {
    "cinder": COMMON + (
        "Tense but adventurous volcanic stage music: driving low hand drums and taiko, plucked "
        "low strings, a smoky clay flute melody, crackling ember textures, minor key, steady fast tempo."
    ),
    "calm": COMMON + (
        "Gentle overworld and title music at dusk: warm kalimba arpeggios, soft felt piano, a soaring "
        "clay ocarina melody, light shaker, hopeful and cozy, relaxed tempo."
    ),
}


def generate(base: str, key: str, name: str) -> Path:
    body = {
        "model": MODEL,
        "messages": [{"role": "user", "content": TRACKS[name]}],
        "modalities": ["text", "audio"],
        "audio": {"format": "mp3"},
        "stream": True,
    }
    raw, content_type = request_bytes(f"{base}/chat/completions", key, body, timeout=400)
    if "application/json" in content_type or raw[:1] in (b"{", b"["):
        audio = audio_from_json(json.loads(raw.decode("utf-8", "replace")))
    else:
        audio = audio_from_sse(raw)
    if len(audio) < 10000:
        raise RuntimeError(f"{name} response was {len(audio)} bytes, type {content_type}")
    RAW.mkdir(parents=True, exist_ok=True)
    path = RAW / f"{name}.mp3"
    path.write_bytes(audio)
    return path


def to_ogg(source: Path, dest: Path) -> None:
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-ac", "2", "-ar", "44100",
               "-c:a", "libvorbis", "-q:a", "4", str(dest)]
    subprocess.run(command, check=True)
    print(f"INSTALLED {dest.name} {dest.stat().st_size // 1024} KiB", flush=True)


def main() -> None:
    names = sys.argv[1:] or list(TRACKS)
    env = load_env(ENV_PATH)
    key = env.get("OPENROUTER_API_KEY", "")
    base = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(generate, base, key, name): name for name in names}
        for future in as_completed(futures):
            name = futures[future]
            try:
                to_ogg(future.result(), OUT / f"music_{name}.ogg")
            except Exception as exc:  # keep the other track going
                print(f"MUSIC fail {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
