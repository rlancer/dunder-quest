"""Generate the Curb Your Oxidation trailer's music cue and its sound effects.

Uses the Dunder Quest trailer's request helpers (../../dunder-quest/tools/generate_trailer_audio.py)
with this trailer's briefs: a bouncy Italian library-music comedy cue (tuba,
mandolin, pizzicato), all original. The briefs ask for the style and the
instruments only; they never name or describe any TV theme, so nothing in
the cue can match one. Lands in `curb/trailer/audio/` as 48 kHz WAV, outside
the game so the web build stays small. Never prints the key.

    python tools/trailer_audio.py                  # everything
    python tools/trailer_audio.py cue_curb sting   # just these
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
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no whistling. "
    "Original trailer music for a small 2D pixel-art comedy game about a petty, opinionated man in "
    "Los Angeles. Do not imitate or quote any existing song, film score or TV theme; write a brand-new "
    "melody. Exactly 120 BPM, 4/4, about 64 seconds, with a clean hard ending, not a fade. "
)

base.MUSIC = {
    "cue_curb": COMMON + (
        "A bouncy, cheeky 1960s Italian library-music comedy piece: an oom-pah tuba bass line, a bright "
        "tremolo mandolin melody, pizzicato strings, a jaunty clarinet, a little glockenspiel and light "
        "brushed percussion. It starts on a big tuba-and-pizzicato hit on the very first beat, no intro. "
        "A smug, sunny main section; a bigger, busier section with the clarinet and muted trumpet from "
        "16 seconds; at 32 seconds it drops to an awkward, tiptoeing half-time breakdown with just "
        "pizzicato and a lone tuba; back to the full band at 40 seconds building to a silly peak at "
        "50 seconds; one final tuba-and-pizzicato button chord at 56 seconds, then a short, soft solo "
        "mandolin tag to the end."
    ),
}

base.SFX = {
    "sting": "A single two second comic tuba sting: a bouncy oom-pah tuba phrase of three notes with a "
             "pizzicato string pluck on the last note, ending on a clean button. No voice.",
    "scratch": "A single 0.6 second vinyl record scratch stop, comic. No voice, no music.",
    "door": "A single one second sound of a door being flung open hard and banging against the wall. "
            "No voice, no music.",
    "kitchen": "Twelve seconds of a quiet sunny kitchen in a Los Angeles house: a soft fridge hum, birds "
               "chirping outside an open window, a distant lawn sprinkler, a clock ticking. No voice, no music.",
    "swish": "A single 0.4 second quick soft camera whip-pan whoosh. No voice, no music.",
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
