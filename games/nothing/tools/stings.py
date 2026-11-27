"""Generate the slap-bass stings between scenes with ElevenLabs Music.

The 1990s studio sitcom's scene change is a format, not a tune: a few
seconds of solo slapped and popped bass, a little synthetic, with mouth pops
and clicks where the drums would be, a different improvised-sounding lick
every time. These are original licks in that style. The briefs never name or
describe any show's music, and none of them recreates a theme or its riff.

Each sting is its own short generation (ElevenLabs' `music_v2_5`), trimmed
of silence, with a few milliseconds of fade so it never clicks, and saved as
assets/audio/sting_<n>.ogg. The game plays one at random wherever it plays
"sting" (core/sfx.gd), and falls back to the synthesized sting.wav from
tools/sfx.py when there are none. Same key as tools/music.py.

    python tools/stings.py          # every sting that's missing
    python tools/stings.py 2 5      # just these, again
    godot --headless --path . --import
"""

from __future__ import annotations

import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import music  # noqa: E402

OUT = music.OUT
RAW = music.RAW
# The longest a sting may run, in seconds, after trimming, and the shortest
# that counts as a lick rather than a single hit.
LONGEST = 4.5
SHORTEST = 0.9
# Below this, in dB, is silence.
QUIET = -45.0
RATE = 44100

COMMON = (
    "A short solo bass sting between scenes of a 1990s studio sitcom, about four seconds. One slapped and "
    "popped electric bass with a bright, slightly synthetic, sampled keyboard-bass edge, played dry and close. "
    "No drums and no other instruments: the only percussion is quick mouth pops, lip smacks and tongue clicks "
    "in the gaps. An original, improvised-sounding funky lick of eight to twelve notes lasting about two "
    "seconds, never a single hit, and never any existing riff or theme. Starts on the first note and ends on "
    "a punchy final note with nothing after it, no fade. "
)

STINGS = {
    1: COMMON + "Cocky and bouncy, 120 BPM, in E: stuttering muted slaps, a quick slide up, an octave pop, and a "
         "slapped low root to finish.",
    2: COMMON + "Smug and strutting, 108 BPM, in A: a lazy hammer-on lick that ends on a sly bend.",
    3: COMMON + "Nervous and fidgety, 128 BPM, in D: stuttering muted slaps, a fast pull-off, a high pop.",
    4: COMMON + "Deadpan and wry, 104 BPM, in G: a walking slapped figure of eight notes, a lip pop, then a "
         "quick little pull-off flourish like a raised eyebrow.",
    5: COMMON + "Busy and bouncy, 124 BPM, in F: a syncopated octave figure that tumbles down to the low root.",
    6: COMMON + "Triumphant, 116 BPM, in C: a rising slapped run that lands on a big double-stop pop.",
}


def target(n: int) -> Path:
    return OUT / f"sting_{n}.ogg"


def generate(api_key: str, n: int) -> Path:
    music.TRACKS[f"sting_{n}"] = (STINGS[n], 4)
    return music.generate(api_key, f"sting_{n}", mode="track")


def to_ogg(source: Path, dest: Path) -> None:
    """The lick alone: from its first note to the first real silence after the
    first second (a generation sometimes plays it again after a gap), at most
    LONGEST seconds, with a few milliseconds of fade so it never clicks."""
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(source), "-f", "f32le", "-ac", "2",
                          "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    audio = np.frombuffer(raw, np.float32).reshape(-1, 2)
    step = RATE // 100
    level = [20 * np.log10(np.sqrt(np.mean(audio[i:i + step] ** 2)) + 1e-9) for i in range(0, len(audio), step)]
    loud = [k for k, db in enumerate(level) if db > QUIET]
    if not loud:
        raise RuntimeError("silent")
    start, end, quiet = loud[0], loud[-1] + 1, 0
    for k in range(start + 100, len(level)):
        quiet = quiet + 1 if level[k] <= QUIET else 0
        if quiet >= 30:  # 0.3 s of silence: the lick is over
            end = k - quiet + 1
            break
    end = min(end, start + int(LONGEST * 100))
    seconds = (end - start) / 100
    if seconds < SHORTEST:
        raise RuntimeError(f"only {seconds:.1f}s: a hit, not a lick; run it again")
    chain = f"atrim={start / 100}:{end / 100},afade=t=in:d=0.005,areverse,afade=t=in:d=0.03,areverse"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-af", chain, "-ac", "2",
                    "-ar", str(RATE), "-c:a", "libvorbis", "-q:a", "5", str(dest)], check=True)
    print(f"INSTALLED {dest.name} {seconds:.1f}s", flush=True)


def main() -> None:
    picked = [int(a) for a in sys.argv[1:] if a.isdigit()]
    todo = picked or [n for n in STINGS if not target(n).exists()]
    api_key = music.key()
    failed = 0
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(generate, api_key, n): n for n in todo}
        for future in as_completed(futures):
            n = futures[future]
            try:
                to_ogg(future.result(), target(n))
            except Exception as exc:  # keep the others going
                failed += 1
                print(f"STING fail {n}: {str(exc).replace(api_key, '[REDACTED]')}", flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
