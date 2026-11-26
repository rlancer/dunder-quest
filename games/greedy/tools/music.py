"""Generate the title, town, showdown and prologue music.

Uses the Dunder Quest music helpers (../../dunder-quest/tools/generate_music.py)
with this game's briefs: original comic-western music (twangy guitar,
whistling, harmonica, jaw harp, trumpet, hand percussion). The briefs ask for
a style and instruments only; they never name or describe any film's score.
Never prints the key.

    python tools/music.py                # every track that's missing
    python tools/music.py title showdown # just these
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
    "Original music for a small comic 2D pixel-art puzzle game set in a frontier town in the Old West. "
    "Do not imitate or quote any existing song, film score or game soundtrack; write a brand-new melody. "
    "Must loop seamlessly, about 60 to 90 seconds. "
)

TRACKS = {
    "title": COMMON + (
        "A big, swaggering, tongue-in-cheek western title theme: a twangy baritone electric guitar carries a "
        "bold tune over galloping acoustic guitar strumming, a clear human-style whistle played on a flute "
        "answers it, mariachi-flavoured trumpet stabs, a jaw harp boing, tubular bell, castanets and a "
        "cracking whip-like snare. Heroic and a bit silly at once. Minor key turning major, medium-fast gallop."
    ),
    "town": COMMON + (
        "Easygoing, light-footed thinking music for solving puzzles in a sleepy frontier town: a loping "
        "clip-clop woodblock rhythm, a lazy harmonica tune, soft nylon guitar picking, an upright bass walking "
        "two notes to the bar, a jaw harp now and then, a tack piano tinkling in the distance. Quiet, warm and "
        "unhurried, with plenty of space, so it can sit under reading. Major key, slow to medium tempo."
    ),
    "showdown": COMMON + (
        "Tense, slow-burning showdown music for a duel at high noon that is secretly a joke: a ticking "
        "pocket-watch pulse, a lonely twangy guitar figure, a distant trumpet, a tolling bell, a snare roll "
        "that keeps building, tremolo strings, then a galloping full-band burst with whip cracks. Dramatic, "
        "over the top, minor key, starts slow and grows."
    ),
    # Under the prologue's narration, so it stays out of the voice's way.
    "intro": COMMON + (
        "A warm, storytelling prologue underscore for an old-timer narrating a tall tale by a campfire: a "
        "slow fingerpicked acoustic guitar, a soft harmonica holding long notes, a gentle upright bass, brushed "
        "percussion like a horse walking, a hint of fiddle. Spacious and calm, no sudden loud hits, mostly in "
        "the low and middle register so a speaking voice sits clearly on top. Major key, slow tempo."
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
