"""Generate the title and stage music as looping Ogg Vorbis.

Uses the Dunder Quest music helpers (../../tools/generate_music.py) with
this game's briefs: scruffy British indie and awkward-sitcom cues, all
original. Reads the key from the repo's .env and never prints it.

    python tools/music.py            # every track that's missing
    python tools/music.py flat       # just one
    python ../tools/make_loops.py assets/audio/music_*.ogg   # then loop them
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parent / "tools"))

import generate_music as base  # noqa: E402

OUT = ROOT / "assets" / "audio"
base.RAW = HERE / "generated" / "music"

COMMON = (
    "Instrumental only. No vocals, no lyrics, no speech, no humming. "
    "Original music for a small 2D pixel-art comedy game; must loop seamlessly, about 60 to 90 seconds. "
    "Do not imitate any existing song, band or TV theme. "
)

TRACKS = {
    "title": COMMON + (
        "A scruffy, wry British indie title theme: a jangly clean electric guitar riff, a slightly out-of-tune "
        "upright piano, brushed drums and a walking bass, mid-2000s London, melancholy but funny, like two "
        "flatmates who can't stand each other but can't move out. Major key with a sad turn, moderate tempo."
    ),
    "flat": COMMON + (
        "Lazy Saturday-in-the-flat music: a noodling acoustic guitar, a cheap Casio keyboard melody, a shaker "
        "and a sleepy bass, a kettle-and-toast mood, slightly awkward and endearing. Major key, relaxed tempo."
    ),
    "office": COMMON + (
        "Drab open-plan office music: a stiff muzak electric piano, a ticking hi-hat like a desk clock, a "
        "bored bass line and a hopeful little glockenspiel phrase that keeps getting cut short, like a "
        "Monday that never ends. Major key, plodding tempo."
    ),
    "cellar": COMMON + (
        "A grubby pub-cellar band rehearsal: a fuzzy distorted guitar riff, loose garage-rock drums, a bass "
        "that's slightly ahead of the beat, enthusiastic and a bit rubbish, like a band that changes its name "
        "every week. Minor key, driving tempo."
    ),
    "farm": COMMON + (
        "A soggy countryside weekend away: a wonky accordion and fiddle folk tune over a plodding tuba and "
        "wellies-in-mud percussion, rain-soaked and comic, like a stag do that is going badly. Major key, "
        "bouncy tempo."
    ),
    "station": COMMON + (
        "A busy commuter railway station at rush hour: a nervous ticking synth arpeggio, a train-rhythm "
        "snare shuffle, a chiming two-note announcement motif (no voice), anxious and comic, like running "
        "for a train you'll definitely miss. Minor key, fast tempo."
    ),
    "church": COMMON + (
        "A small English church wedding, slightly wrong: a stately church organ processional that keeps "
        "being joined by a cheeky electric guitar, gentle timpani, a triumphant but awkward ending that "
        "loops back. Major key, stately tempo."
    ),
}


def main() -> None:
    names = sys.argv[1:] or [n for n in TRACKS if not (OUT / f"music_{n}.ogg").exists()]
    base.TRACKS = TRACKS
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
                base.to_ogg(future.result(), OUT / f"music_{name}.ogg")
            except Exception as exc:  # keep the other tracks going
                print(f"MUSIC fail {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
