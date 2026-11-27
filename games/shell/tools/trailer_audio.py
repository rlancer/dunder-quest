"""Generate the trailer's music cue and its sound effects.

Uses the Dunder Quest trailer's request helpers
(../../dunder-quest/tools/generate_trailer_audio.py) with this trailer's
briefs: an original, frantic, comic kitchen-rush cue (nervy overdriven
guitar, driving bass and drums, pots and pans, a tense string stab), with a
dead stop two thirds of the way through for the ticket machine. The briefs
ask for a style and instruments only and never name or describe any show's
music. Lands in `shell/trailer/audio/` as 48 kHz WAV, outside the game so
the web build stays small. Finds the key the way the game's other tools do
(tools/common.py) and never prints it.

    python tools/trailer_audio.py                    # everything
    python tools/trailer_audio.py cue_shell bell     # just these
    python tools/trailer_audio.py cue_shell:3        # three takes: cue_shell_1.wav ... to choose from

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
    "Original trailer music for a small comic 2D pixel-art puzzle game set in the cramped kitchen of a "
    "sandwich shop in a cold lakeside city, where the cooks pass the orders down the line. "
    "Do not imitate or quote any existing song, film score, game soundtrack or TV theme; write a brand-new "
    "piece. Exactly 120 BPM, 4/4, about 64 seconds, with a clean hard ending, not a fade. "
)

base.MUSIC = {
    "cue_shell": COMMON + (
        "A frantic, nervy, tongue-in-cheek dinner-rush cue played by a scrappy four-piece rock band with a "
        "kitchen in the room: overdriven jangly electric guitar, a driving picked bass, tight punchy drums, a "
        "tense staccato string stab, and kitchen percussion (a pan lid crash, a knife tapping a steel counter, "
        "a service bell ding). It starts on one big band hit with a service bell on the very first beat. "
        "From 0 to 8 seconds it is sparse and anxious: just the knife ticking eighth notes on the counter and "
        "a muted guitar riff. At exactly 8 seconds the whole band crashes in, driving and urgent, the guitar "
        "riff carrying it and the strings stabbing on the downbeats. Bigger from 24 seconds. At exactly 40 "
        "seconds the whole band stops dead: four seconds of near silence with only a ticking clock. "
        "At 44 seconds the knife and a building snare and rising strings bring it back, and at 48 seconds the "
        "full band slams in for the fastest, biggest rush, building to a triumphant peak. One final huge band "
        "hit with a service bell at exactly 58 seconds, then a short, soft solo guitar tag and one last bell."
    ),
}

base.SFX = {
    "bell": "A single one second restaurant service bell ding, bright and clean, ringing out. No voice, no music.",
    "printer": "A two second receipt ticket printer chattering out an order slip and tearing it off. "
               "No voice, no music.",
    "pan": "A single one second comic metal pan lid crash on a steel kitchen counter. No voice, no music.",
    "sting": "A single two second comic rock sting: one big overdriven guitar chord with a crash cymbal and a "
             "service bell, ending clean. No voice.",
}


def main() -> None:
    wanted = sys.argv[1:] or [*base.MUSIC, *base.SFX]
    # "cue_shell:3" asks for three takes of the same brief.
    jobs: list[str] = []
    for arg in wanted:
        name, _, takes = arg.partition(":")
        if takes:
            for k in range(1, int(takes) + 1):
                base.MUSIC[f"{name}_{k}"] = base.MUSIC[name]
                jobs.append(f"{name}_{k}")
        else:
            jobs.append(name)
    env = common.load_env()
    key = env.get("OPENROUTER_API_KEY", "")
    url = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(base.generate, url, key, name): name for name in jobs}
        for future in as_completed(futures):
            name = futures[future]
            try:
                base.to_wav(future.result(), OUT / f"{name}.wav")
                print(f"WROTE {name}.wav", flush=True)
            except Exception as exc:  # keep the others going
                print(f"FAIL {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
