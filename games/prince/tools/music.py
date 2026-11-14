"""Generate the title, room and boss music.

Uses the Dunder Quest music helpers (../../dunder-quest/tools/generate_music.py)
with this game's briefs: original adventure music on Persian instruments
(oud, santur, ney, daf and tombak). The briefs ask for a style and
instruments only; they never name or describe any game's soundtrack. Never
prints the key.

    python tools/music.py                # every track that's missing
    python tools/music.py title boss     # just these
    python ../dunder-quest/tools/make_loops.py assets/audio/music_*.ogg   # then loop the music
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))
sys.path.insert(0, str(HERE))

import generate_music as base  # noqa: E402
from common import api  # noqa: E402

OUT = ROOT / "assets" / "audio"
base.RAW = HERE / "generated" / "music"

COMMON = (
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no chanting. "
    "Original music for a small 2D pixel-art adventure game set in an old Persian palace at night. "
    "Do not imitate or quote any existing song, film score or game soundtrack; write a brand-new melody. "
    "Must loop seamlessly, about 60 to 90 seconds. "
)

TRACKS = {
    "title": COMMON + (
        "A sweeping, mysterious adventure theme: a plucked oud carries the melody over a shimmering santur "
        "(hammered dulcimer), a breathy ney flute answers, daf frame drum and tombak keep a steady rolling "
        "6/8 pulse, low strings swell underneath. Heroic but wistful, like sand running through an "
        "hourglass. Minor mode with a raised second, medium tempo."
    ),
    "room": COMMON + (
        "Quiet, tense exploration underscore for creeping through a palace at night: a sparse plucked oud "
        "ostinato, soft tombak finger rolls, a distant ney phrase now and then, a low drone, lots of space "
        "and silence between phrases. Quiet enough to think over. Minor mode, slow to medium tempo."
    ),
    "boss": COMMON + (
        "Urgent, driving confrontation music: fast daf and tombak drumming, a low string ostinato, tremolo "
        "oud, sharp santur runs, brass stabs, a ticking clock-like pulse underneath. Dangerous and "
        "relentless, a villain's hourglass running out. Minor mode, fast tempo."
    ),
}


def target(name: str) -> Path:
    return OUT / f"music_{name}.ogg"


def main() -> None:
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = names or [n for n in TRACKS if not target(n).exists()]
    base.TRACKS = TRACKS
    url, key = api()
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = {pool.submit(base.generate, url, key, name): name for name in names}
        for future in as_completed(futures):
            name = futures[future]
            try:
                base.to_ogg(future.result(), target(name))
            except Exception as exc:  # keep the other tracks going
                print(f"MUSIC fail {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
