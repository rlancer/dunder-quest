"""Generate the Prince of Versions trailer's music cue and its sound effects.

Uses the Dunder Quest trailer's request helpers
(../../dunder-quest/tools/generate_trailer_audio.py) with this trailer's
briefs: an original adventure cue on the game's own Persian instruments (oud,
santur, ney, daf), with a dead stop for the death and a reversed swell for
the rewind. The briefs ask for a style and instruments only and never
describe any existing game's music. Lands in `prince/trailer/audio/` as
48 kHz WAV, outside the game so the web build stays small. Finds the key the
way the game's other tools do (tools/common.py) and never prints it.

    python tools/trailer_audio.py                  # everything
    python tools/trailer_audio.py cue_prince rewind  # just these
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import common  # noqa: E402
import generate_trailer_audio as base  # noqa: E402

OUT = ROOT / "trailer" / "audio"
base.RAW = HERE / "generated" / "trailer"

COMMON = (
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no chanting. "
    "Original trailer music for a small 2D pixel-art adventure game about a nimble young prince running "
    "through a moonlit desert palace full of traps, with a magic dagger that turns back time. "
    "Do not imitate or quote any existing song, film score, game soundtrack or TV theme; write a brand-new "
    "melody. Exactly 120 BPM, 4/4, about 64 seconds, with a clean hard ending, not a fade. "
)

base.MUSIC = {
    "cue_prince": COMMON + (
        "A driving, heroic adventure cue on Persian instruments with a small orchestra: a fast plucked oud "
        "riff, shimmering santur runs, a breathy ney flute melody, daf and tombak frame drums, low strings "
        "and taiko-like hits. It starts on a big drum-and-strings hit on the very first beat, no intro. "
        "A mysterious, rhythmic first section; bigger and faster from 16 seconds with the full strings; "
        "at exactly 32 seconds the whole band stops dead, two seconds of silence, then a long reversed "
        "cymbal and string swell rising back in; full band again from 36 seconds, building to a triumphant "
        "peak with the ney soaring at 50 seconds; one final huge drum-and-oud hit at 56 seconds, then a "
        "soft solo santur tag to the end."
    ),
}

base.SFX = {
    "rewind": "A single 1.2 second magical time-rewind sound: shimmering sand pouring backwards, a reversed "
              "chime and a rising whoosh. No voice, no music.",
    "sting": "A single two second triumphant sting: a huge frame-drum hit with a bright plucked oud chord "
             "and a cymbal swell, ending clean. No voice.",
    "slash": "A single 0.4 second quick metallic dagger swish and ring. No voice, no music.",
    "boom": "A single one second deep cinematic boom with a short tail. No voice, no music.",
}


def main() -> None:
    names = sys.argv[1:] or [*base.MUSIC, *base.SFX]
    env = common.load_env()
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
                print(f"WROTE {name}.wav", flush=True)
            except Exception as exc:  # keep the others going
                print(f"FAIL {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
