"""Generate the trailer's music cue and its motion-graphics sound effects.

Lands in `trailer/audio/`, outside the game so the web build stays small.
Reuses the request helpers in generate_assets.py. Never prints the key.

    python tools/generate_trailer_audio.py              # everything
    python tools/generate_trailer_audio.py cue_a typing # just these
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
RAW = ROOT / "tools" / "generated" / "trailer"
OUT = ROOT / "trailer" / "audio"
MUSIC_MODEL = "google/lyria-3-pro-preview"
SFX_MODEL = "bytedance-seed/seed-audio-1-0"

COMMON = (
    "Instrumental only. No vocals, no lyrics, no speech, no humming. "
    "Original trailer music for a comic-epic 2D pixel-art platformer: a squire's quest for the Holy Grail, "
    "in the spirit of a pompous British comedy brass band. Do not imitate any existing soundtrack or march. "
    "Exactly 125 BPM, 4/4, "
    "about 64 seconds, with a clean hard ending, not a fade. "
)

MUSIC = {
    "cue_march": COMMON + (
        "A grand, jaunty, slightly ridiculous brass-band march: oom-pah tuba, snare rolls, crashing cymbals, "
        "a proud cornet melody and silly trombone slides. It starts on a huge brass-and-cymbal hit on the very "
        "first beat, no intro. Builds through the first 15 seconds, drops into a bouncy full-band main section, "
        "turns mock-serious and dramatic at 30 seconds with timpani and low brass, peaks triumphantly at 49 "
        "seconds, slams to a stop on one final hit at 57 seconds, then a short, soft solo glockenspiel tag."
    ),
    "cue_a": COMMON + (
        "Structure: 0-4s punchy hand-drum groove under a clay ocarina hook; 4-6s sudden near-silence "
        "with one soft kalimba note; 6-12s build with taiko and plucked strings; 12s big drop, full "
        "driving percussion, bold ocarina melody; 28-40s tense minor-key duel section with low brass "
        "stabs on every downbeat; 40-48s fastest, most energetic section; 48-54s soaring triumphant "
        "peak; 54-56s one huge final hit then silence; 56-64s warm gentle kalimba outro under a logo."
    ),
    "cue_b": COMMON + (
        "Chiptune-meets-orchestra hybrid: square-wave arpeggios layered with taiko, warm strings and a "
        "clay flute lead. Starts already moving, builds through the first 12 seconds, drops into a "
        "bouncy energetic main section, turns tense and dramatic at 28 seconds, peaks triumphantly at "
        "48 seconds, slams to a stop at 56 seconds, then a short soft music-box tag to the end."
    ),
}

SFX = {
    "typing": "A two second sound effect of fast retro mechanical keyboard typing, crisp clicks. No voice, no music.",
    "cursor_blip": "A single 0.1 second soft 8-bit blip, like a terminal cursor appearing. No voice, no music.",
    "whoosh": "A single 0.6 second fast airy whoosh swipe for a title card. No voice, no music.",
    "impact": "A single 1 second deep cinematic trailer impact hit with a short boom tail. No voice, no music.",
    "riser": "A three second rising tension riser that ends abruptly at its peak. No voice, no music.",
    "correct": "A single 0.5 second bright magical correct-answer chime with a sparkle. No voice, no music.",
    "wrong": "A single 0.5 second low buzzy retro wrong-answer thud. No voice, no music.",
}


def raw_audio(raw: bytes, content_type: str) -> bytes:
    if "application/json" in content_type or raw[:1] in (b"{", b"["):
        return audio_from_json(json.loads(raw.decode("utf-8", "replace")))
    if "event-stream" in content_type or raw.startswith(b"data:"):
        return audio_from_sse(raw)
    return raw


def generate(base: str, key: str, name: str) -> Path:
    if name in MUSIC:
        body = {
            "model": MUSIC_MODEL,
            "messages": [{"role": "user", "content": MUSIC[name]}],
            "modalities": ["text", "audio"],
            "audio": {"format": "mp3"},
            "stream": True,
        }
        raw, content_type = request_bytes(f"{base}/chat/completions", key, body, timeout=400)
    else:
        body = {"model": SFX_MODEL, "input": SFX[name], "response_format": "mp3"}
        raw, content_type = request_bytes(f"{base}/audio/speech", key, body, timeout=180)
    audio = raw_audio(raw, content_type)
    if len(audio) < 2000:
        raise RuntimeError(f"{name} response was {len(audio)} bytes, type {content_type}")
    RAW.mkdir(parents=True, exist_ok=True)
    path = RAW / f"{name}.mp3"
    path.write_bytes(audio)
    return path


def to_wav(source: Path, dest: Path) -> None:
    # 48 kHz stereo, the rate the trailer is mixed and delivered at.
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-ac", "2", "-ar", "48000",
               "-c:a", "pcm_s16le", str(dest)]
    subprocess.run(command, check=True)
    print(f"INSTALLED {dest.name} {dest.stat().st_size // 1024} KiB", flush=True)


def main() -> None:
    names = sys.argv[1:] or [*MUSIC, *SFX]
    env = load_env(ENV_PATH)
    key = env.get("OPENROUTER_API_KEY", "")
    base = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(generate, base, key, name): name for name in names}
        for future in as_completed(futures):
            name = futures[future]
            try:
                to_wav(future.result(), OUT / f"{name}.wav")
            except Exception as exc:  # keep the others going
                print(f"FAIL {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
