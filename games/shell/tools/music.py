"""Generate the title, prologue, prep, service and critic music.

Uses the Dunder Quest music helpers (../../dunder-quest/tools/generate_music.py)
with this game's briefs: original music for a city kitchen (a small rhythm
section, electric piano, clean guitar, brushes and hand percussion). The
briefs ask for a style and instruments only; they never name or describe
any show's soundtrack or any existing song. Never prints the key.

    python tools/music.py                # every track that's missing
    python tools/music.py title service  # just these
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
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no chanting, no choir. "
    "Original music for a small comic 2D pixel-art puzzle game set in the kitchen of a neighbourhood sandwich "
    "shop in a big northern city. Do not imitate or quote any existing song, television score or game "
    "soundtrack; write a brand-new melody. Must loop seamlessly, about 60 to 90 seconds. "
)

TRACKS = {
    "title": COMMON + (
        "A warm, confident title theme with a night-in-the-city feel: a clean, jangly electric guitar riff over "
        "a steady mid-tempo drum groove, a round electric bass, a Hammond organ pad, a tambourine on the "
        "backbeat. Hopeful and a little scrappy, like a small place about to get its act together. Major key, "
        "medium tempo."
    ),
    "prep": COMMON + (
        "Light, tidy thinking music for the quiet hours before a restaurant opens: a soft electric piano "
        "playing gentle chords, a walking upright bass, brushed drums, a muted guitar picking a small "
        "figure, now and then the clink of a spoon on a pan as percussion. Calm, neat and unhurried, with "
        "plenty of space, so it can sit under reading. Major key, slow to medium tempo."
    ),
    "service": COMMON + (
        "Focused, driving music for a busy dinner service that is under control: a tight funk drum groove with "
        "sixteenth-note hi-hats, a busy but quiet bass line, clipped rhythm guitar, short electric piano "
        "stabs, congas. Propulsive but not loud or frantic, staying in the middle register so it can sit "
        "under reading and thinking. Minor key, medium-fast tempo."
    ),
    "critic": COMMON + (
        "Tense, tiptoeing music for an important guest sitting down in the dining room: pizzicato strings "
        "ticking like a clock, a soft brushed snare, a nervous upright bass, a single muted trumpet with a "
        "sly tune, a triangle. Comic suspense that slowly winds tighter without ever getting loud. Minor "
        "key, medium tempo."
    ),
    # Under the prologue's narration, so it stays out of the voice's way.
    "intro": COMMON + (
        "A warm storytelling underscore for a narrator setting the scene in a city at dusk: a mellow electric "
        "piano, a slow brushed drum pattern, a soft upright bass, a distant muted trumpet holding long notes. "
        "Spacious and calm, no sudden loud hits, mostly in the low and middle register so a speaking voice "
        "sits clearly on top. Major key, slow tempo."
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
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(base.generate, url, key, name): name for name in names}
        for future in as_completed(futures):
            name = futures[future]
            try:
                base.to_ogg(future.result(), target(name))
            except Exception as exc:  # keep the other tracks going
                print(f"MUSIC fail {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
