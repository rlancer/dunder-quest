"""Generate the trailer's music cue and its sound effects.

Uses the Dunder Quest trailer's request helpers
(../../dunder-quest/tools/generate_trailer_audio.py) with this trailer's
briefs: an original comic spaghetti-western cue (twangy guitar, a whistle,
trumpet, jaw harp, a galloping band), with a dead stop two thirds of the way
through for Big Backtrack. The briefs ask for a style and instruments only
and never name or describe any film's music. Lands in
`greedy/trailer/audio/` as 48 kHz WAV, outside the game so the web build
stays small. Finds the key the way the game's other tools do
(tools/common.py) and never prints it.

    python tools/trailer_audio.py                    # everything
    python tools/trailer_audio.py cue_greedy whip    # just these
    python tools/trailer_audio.py cue_greedy:3       # three takes: cue_greedy_1.wav ... to choose from

Every run writes new music: the cue the trailer was cut to is kept outside
the worktree (see trailer/README.md), not made again.
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
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no chanting, no choir. "
    "Original trailer music for a small comic 2D pixel-art puzzle game set in a frontier town in the Old West, "
    "where a sheriff catches outlaws with wanted posters instead of a gun. "
    "Do not imitate or quote any existing song, film score, game soundtrack or TV theme; write a brand-new "
    "melody. Exactly 120 BPM, 4/4, about 64 seconds, with a clean hard ending, not a fade. "
)

base.MUSIC = {
    "cue_greedy": COMMON + (
        "A swaggering, tongue-in-cheek western showdown cue played by a small scrappy band: a twangy baritone "
        "electric guitar, galloping acoustic guitar strumming, a clear whistled tune played on a flute, "
        "mariachi-flavoured trumpet, a jaw harp boing, castanets, tubular bell, a cracking snare and whip "
        "cracks. It starts on one big twangy guitar-and-trumpet hit on the very first beat, no intro. "
        "From 0 to 8 seconds it is sparse and lonesome: the whistle over a clip-clop woodblock, with the jaw "
        "harp answering. At exactly 8 seconds the whole band gallops in, bold and a bit silly, the twangy "
        "guitar carrying the tune and the trumpet stabbing on the downbeats. Bigger from 24 seconds with the "
        "trumpet taking the melody. At exactly 40 seconds the whole band stops dead: two seconds of silence "
        "with a single jaw harp boing in it. At 42 seconds a snare roll and a rising trumpet bring the full "
        "band back for the fastest, biggest gallop, whip cracks on the off-beats, building to a triumphant "
        "peak. One final huge guitar-trumpet-and-bell hit at exactly 56 seconds, then a short, soft solo "
        "whistle tag with one last jaw harp boing."
    ),
}

base.SFX = {
    "whip": "A single 0.5 second bullwhip crack, sharp and dry, with a short tail. No voice, no music.",
    "ricochet": "A single one second cartoon bullet ricochet: a pistol shot and a whining pee-yow bounce. "
                "No voice, no music.",
    "sting": "A single two second comic western sting: a big twangy electric guitar chord with a trumpet stab "
             "and a tubular bell, ending clean. No voice.",
    "boom": "A single one second deep cinematic boom with a short tail. No voice, no music.",
}


def main() -> None:
    wanted = sys.argv[1:] or [*base.MUSIC, *base.SFX]
    # "cue_greedy:3" asks for three takes of the same brief.
    jobs: list[tuple[str, str]] = []
    for arg in wanted:
        name, _, takes = arg.partition(":")
        if takes:
            for k in range(1, int(takes) + 1):
                base.MUSIC[f"{name}_{k}"] = base.MUSIC[name]
                jobs.append((f"{name}_{k}", f"{name}_{k}"))
        else:
            jobs.append((name, name))
    env = common.load_env()
    key = env.get("OPENROUTER_API_KEY", "")
    url = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(base.generate, url, key, name): out for name, out in jobs}
        for future in as_completed(futures):
            name = futures[future]
            try:
                base.to_wav(future.result(), OUT / f"{name}.wav")
                print(f"WROTE {name}.wav", flush=True)
            except Exception as exc:  # keep the others going
                print(f"FAIL {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
