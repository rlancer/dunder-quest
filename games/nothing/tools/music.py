"""Generate the title, prologue and episode music.

Uses the Dunder Quest music helpers (../../dunder-quest/tools/generate_music.py)
with this game's briefs: original music in the style of an early-1990s
studio sitcom (slap bass, a little synth, finger snaps, a light funk drum
groove). The briefs ask for a style and instruments only; they never name or
describe any show's music or any existing song, and none of them recreates a
theme tune. Never prints the key.

    python tools/music.py                    # every track that's missing
    python tools/music.py title diner        # just these
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
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no chanting, no choir, no laugh track. "
    "Original music for a small comic 2D pixel-art puzzle game about four friends in New York in the early "
    "1990s. Do not imitate or quote any existing song, television theme, score or game soundtrack; write a "
    "brand-new melody and a brand-new bass line. Must loop seamlessly, about 60 to 90 seconds. "
)

TRACKS = {
    "title": COMMON + (
        "A bouncy, cheeky title theme: a funky slapped and popped electric bass carrying an original, playful, "
        "syncopated riff, finger snaps, a light dry funk drum groove, a bright synth organ, short muted "
        "electric guitar chops. Wry and confident, like a joke about to land. Major key, medium-fast tempo."
    ),
    "apartment": COMMON + (
        "Light, chatty thinking music for hanging around a friend's apartment: a gentle slapped bass playing "
        "short little phrases with gaps between them, finger snaps, soft synth marimba, a brushed snare, the "
        "odd synth bass blip. Sparse and airy so it can sit under reading. Major key, medium tempo."
    ),
    "restaurant": COMMON + (
        "Restless waiting music for standing in the lobby of a crowded restaurant: a nervous walking slap bass "
        "line, a ticking woodblock like a clock, a muted vibraphone, a soft tom groove, a lounge electric piano "
        "noodling politely. Impatient, a little exasperated, comic. Minor key, medium tempo."
    ),
    "diner": COMMON + (
        "Easygoing, chatty music for a long breakfast in a corner diner: a warm round slapped bass groove, "
        "a clean electric piano, finger snaps, a shaker, a soft synth brass stab now and then. Relaxed and "
        "gossipy, plenty of space. Major key, medium-slow tempo."
    ),
    "garage": COMMON + (
        "Comic suspense music for being lost in a parking garage: a low slapped bass ostinato that keeps "
        "climbing and falling, a synth pad, a hollow echoing rimshot, a tense pizzicato synth, a little "
        "detective-style muted synth trumpet. Mysterious and silly, never scary. Minor key, medium tempo."
    ),
    "network": COMMON + (
        "Tense, buttoned-up music for a big meeting in a television network's boardroom: a tight, nervous "
        "slapped bass figure, a stiff electronic drum groove, a cold synth string pad slowly swelling, a "
        "synth brass hit at the end of each phrase. Comic pressure that builds without getting loud. Minor "
        "key, medium tempo."
    ),
    # Under the prologue's narration, so it stays out of the voice's way.
    "intro": COMMON + (
        "A warm storytelling underscore for a narrator introducing a group of friends in the city: a soft "
        "slapped bass playing a few quiet notes at a time, a mellow electric piano, finger snaps, a gentle "
        "shaker. Spacious and calm, no sudden loud hits, mostly low and middle register so a speaking voice "
        "sits clearly on top. Major key, slow to medium tempo."
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
