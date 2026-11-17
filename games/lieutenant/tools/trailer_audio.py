"""Generate the Just One More JOIN trailer's music cue and its sound effects.

Uses the Dunder Quest trailer's request helpers
(../../dunder-quest/tools/generate_trailer_audio.py) with this trailer's
briefs: an original 1970s television-mystery cue for a small jazz band and
strings (walking bass, brushes, vibraphone, electric piano, a wry bassoon,
muted trumpet), with a dead stop for the moment the Lieutenant turns round at
the door. The briefs ask for a style and instruments only and never describe
any existing show's music. Lands in `lieutenant/trailer/audio/` as 48 kHz
WAV, outside the game so the web build stays small. Finds the key the way
the other games' tools do (tools/common.py) and never prints it.

    python tools/trailer_audio.py                    # everything
    python tools/trailer_audio.py cue_join sting     # just these
    python tools/trailer_audio.py --takes 3          # cue_join_1..3.wav, to pick from

The trailer plays `cue_join.wav`; copy the take you like over it and measure
its beats before cutting to it (see trailer/README.md).
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
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no whistling. "
    "Original trailer music for a small 2D pixel-art detective comedy set in Los Angeles in 1974: a rumpled, "
    "polite homicide lieutenant in a raincoat who always has one more question. "
    "Do not imitate or quote any existing song, film score, game soundtrack or TV theme; write a brand-new "
    "melody. Exactly 120 BPM, 4/4, straight eighths with a light swing feel, about 64 seconds, with a clean "
    "hard ending, not a fade. "
)

base.MUSIC = {
    "cue_join": COMMON + (
        "A sly, witty 1970s television-mystery cue for a small jazz band with strings: walking upright bass, "
        "brushed drums with a tight hi-hat, vibraphone, electric piano, a wry solo bassoon melody answered by "
        "muted trumpet, pizzicato strings and a wah-wah guitar scratch. It starts on a big brass-and-vibraphone "
        "stab on the very first beat, no intro. A sneaking, tiptoeing first section led by the bassoon; bigger "
        "and busier from 16 seconds with the full band and strings; at exactly 32 seconds the whole band stops "
        "dead on a single stab, then two seconds of complete silence, then one cheeky solo pizzicato-bass "
        "phrase; the full band slams back in at 36 seconds, swinging hard and building to a triumphant brass "
        "peak at 50 seconds; one final huge brass-and-drums hit at 56 seconds, then a soft solo vibraphone "
        "tag to the end."
    ),
}

base.SFX = {
    "sting": "A single two second jazzy musical flourish: a bright brass chord with a vibraphone run "
             "and a cymbal choke, ending clean. No voice.",
    "hit": "A single one second deep timpani and upright-bass hit with a short tail. No voice, no music.",
    "bell": "A single 1.5 second old rotary telephone bell ringing once. No voice, no music.",
    "teletype": "A two second burst of a 1970s teletype printer chattering, then a carriage return. No voice, "
                "no music.",
}


def main() -> None:
    args = sys.argv[1:]
    takes = 0
    if "--takes" in args:
        at = args.index("--takes")
        takes = int(args[at + 1])
        del args[at:at + 2]
        for k in range(1, takes + 1):
            base.MUSIC[f"cue_join_{k}"] = base.MUSIC["cue_join"]
    names = args or ([f"cue_join_{k}" for k in range(1, takes + 1)] if takes else [*base.MUSIC, *base.SFX])
    url, key = common.api()
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
