"""Generate the Flatmates.js trailer's music cue and its sound effects.

Uses the Dunder Quest trailer's request helpers (../../dunder-quest/tools/generate_trailer_audio.py)
with this trailer's briefs: scruffy, wry British indie, all original. Lands
in `flatmates/trailer/audio/` as 48 kHz WAV, outside the game so the web
build stays small. Never prints the key.

    python tools/trailer_audio.py                 # everything
    python tools/trailer_audio.py cue_flat kettle # just these
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import generate_trailer_audio as base  # noqa: E402

OUT = ROOT / "trailer" / "audio"
base.RAW = HERE / "generated" / "trailer"

COMMON = (
    "Instrumental only. No vocals, no lyrics, no speech, no humming. "
    "Original trailer music for a small 2D pixel-art comedy game about two mismatched flatmates in a "
    "Croydon flat. Do not imitate any existing song, band or TV theme. "
    "Exactly 120 BPM, 4/4, about 60 seconds, with a clean hard ending, not a fade. "
)

base.MUSIC = {
    "cue_flat": COMMON + (
        "Scruffy, wry mid-2000s British indie: a jangly clean electric guitar riff, a slightly out-of-tune "
        "upright piano, a bouncy bass and tight dry drums, melancholy but funny. It starts on a strummed "
        "guitar chord with the full band on the very first beat, no intro. A bright, cocky main section, "
        "a bigger chorus with a fuzzy guitar from 16 seconds, a deflated half-time breakdown at 32 seconds "
        "with just piano and bass, back to the full band at 40 seconds building to a peak at 50 seconds, "
        "one final strummed chord at 56 seconds, then a short, lonely solo piano tag."
    ),
}

base.SFX = {
    "room_tone": "Four seconds of quiet flat room tone: a fridge humming, a distant road, a clock ticking. No voice, no music.",
    "kettle": "A three second electric kettle coming to the boil and clicking off. No voice, no music.",
    "sting": "A single 1.5 second strummed jangly clean electric guitar chord, bright, then ringing out. No voice.",
    "scratch": "A single 0.6 second record scratch stop, comic. No voice, no music.",
    "swish": "A single 0.4 second quick soft camera whip-pan whoosh. No voice, no music.",
    "garage": "Three seconds of an amateur garage band rehearsing in a small room: a loud, slightly out-of-tune distorted electric guitar strumming the same chord over and over, a bashing drum kit, getting louder, ending in amp feedback. No vocals.",
    "rewind": "A 1.2 second VHS tape rewinding fast, a whirring squeal that rises in pitch, ending in a clunk. No voice, no music.",
}


def main() -> None:
    names = sys.argv[1:] or [*base.MUSIC, *base.SFX]
    env = base.load_env(base.ENV_PATH)
    key = env.get("OPENROUTER_API_KEY", "")
    url = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(base.generate, url, key, name): name for name in names}
        for future in as_completed(futures):
            name = futures[future]
            try:
                base.to_wav(future.result(), OUT / f"{name}.wav")
            except Exception as exc:  # keep the others going
                print(f"FAIL {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
