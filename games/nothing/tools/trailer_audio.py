"""Generate the trailer's music cue and its sound effects.

Uses the Dunder Quest trailer's request helpers
(../../dunder-quest/tools/generate_trailer_audio.py) with this trailer's
briefs: an original cue in the style of an early-1990s studio sitcom (a
slapped bass, finger snaps, a light funk band), which starts on the bass
alone, and drops to nearly nothing two thirds of the way through for Stu's
bit about 204 No Content. The briefs ask for a style and instruments only
and never name or describe any show's music; nothing here recreates a theme
tune. Lands in `nothing/trailer/audio/` as 48 kHz WAV, outside the game so
the web build stays small. Finds the key the way the game's other tools do
(tools/common.py) and never prints it.

    python tools/trailer_audio.py                     # everything
    python tools/trailer_audio.py cue_nothing whoosh  # just these
    python tools/trailer_audio.py cue_nothing:3       # three takes: cue_nothing_1.wav ... to choose from
    python tools/trailer_audio.py cue_nothing_el:2    # two takes from ElevenLabs Music, sections timed exactly

Every run writes new music: the cue the trailer was cut to is kept outside
the worktree (see trailer/README.md), not made again.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
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
    "Instrumental only. No vocals, no lyrics, no speech, no humming, no chanting, no choir, no laugh track, "
    "no audience. Original trailer music for a small comic 2D pixel-art puzzle game about four friends in "
    "New York in the early 1990s. Do not imitate or quote any existing song, television theme, score or game "
    "soundtrack; write a brand-new melody and a brand-new bass line. Exactly 120 BPM, 4/4, about 78 seconds, "
    "with a clean hard ending, not a fade. "
)

base.MUSIC = {
    "cue_nothing": COMMON + (
        "A cheeky, bouncy, light funk cue played by a small tight studio band: a slapped and popped electric "
        "bass carrying an original, playful, syncopated riff, finger snaps, a dry funk drum kit, a bright "
        "synth organ, short muted electric guitar chops and synth brass stabs. Wry and confident, like a joke "
        "about to land. Major key. It starts on the very first beat with the slap bass, no intro and no "
        "silence. From 0 to 8 seconds it is sparse: the slap bass alone, playing short phrases with gaps "
        "between them, and finger snaps on beats two and four. At exactly 8 seconds the whole band kicks in "
        "with a drum fill, the bass riff driving and the organ answering it. Bigger from 26 seconds, with "
        "brass stabs on the downbeats. At exactly 44 seconds the band stops dead on one hit: eleven seconds of "
        "almost nothing, only finger snaps on two and four and one lone bass pop. At 55 seconds a snare fill "
        "brings the full band back for the busiest, most joyful section, building to a peak. One final tight "
        "full-band hit with a bass pop at exactly 74 seconds, then a short solo slap-bass tag with one last "
        "finger snap."
    ),
}

base.SFX = {
    "whoosh": "A single 0.5 second fast airy whoosh swipe for a title card. No voice, no music.",
    "rimshot": "A single comedy-club drum sting, one and a half seconds: two quick snare hits then a "
               "cymbal crash, ba-dum-tss, dry and close. No voice, no laughter, no applause, no music.",
}


# The same cue from ElevenLabs Music (`music_v2_5`), as a composition plan:
# the sections and their lengths are asked for exactly, so the band's entry,
# the stop and the last hit land where the cut wants them. Ask for it as
# `cue_nothing_el` (or `cue_nothing_el:2`); it needs ELEVENLABS_API_KEY,
# like tools/music.py.
ELEVEN_URL = "https://api.elevenlabs.io/v1/music"
ELEVEN_STYLE = [
    "instrumental", "original light funk trailer cue", "early 1990s studio band", "120 BPM", "4/4", "major key",
    "slapped and popped electric bass carrying an original playful syncopated riff", "finger snaps",
    "dry tight funk drum kit", "bright synth organ", "muted electric guitar chops", "synth brass stabs",
    "cheeky, bouncy, wry and confident, like a joke about to land", "recorded dry and close",
]
ELEVEN_AVOID = [
    "vocals", "lyrics", "speech", "choir", "laugh track", "audience", "smooth jazz", "lounge", "ambient",
    "fade out", "any existing song or television theme",
]
ELEVEN_SECTIONS = [
    ("Bass alone", ["slap bass alone, short playful phrases with gaps", "finger snaps on two and four"],
     ["drums", "organ", "brass", "guitar"], 8000),
    ("Band in", ["a drum fill, then the whole band kicks in", "the bass riff driving, the organ answering it"],
     ["brass"], 18000),
    ("Bigger", ["full band, bigger", "brass stabs on the downbeats", "ends dead on one tight full-band hit"],
     [], 18000),
    ("Almost nothing", ["near silence", "only quiet finger snaps on two and four", "one lone bass pop"],
     ["drums", "organ", "brass", "guitar", "bass riff", "pad"], 11000),
    ("Band back", ["a snare fill brings the full band back", "busiest, most joyful section, building to a peak",
                   "ends on one final tight full-band hit with a bass pop"], [], 19000),
    ("Tag", ["a short solo slap-bass tag", "one last finger snap", "clean hard ending"],
     ["drums", "organ", "brass", "guitar"], 4000),
]


def eleven(name: str) -> bytes:
    key = os.environ.get("ELEVENLABS_API_KEY") or common.load_env().get("ELEVENLABS_API_KEY", "")
    if not key:
        raise RuntimeError("ELEVENLABS_API_KEY is missing from .env")
    # music_v2_5's plan is a list of chunks, each with its own styles.
    plan = {"chunks": [{"text": f"[{n}]", "duration_ms": ms, "positive_styles": ELEVEN_STYLE + pos,
                        "negative_styles": ELEVEN_AVOID + neg, "context_adherence": "high"}
                       for n, pos, neg, ms in ELEVEN_SECTIONS]}
    body = json.dumps({"composition_plan": plan, "model_id": "music_v2_5",
                       "respect_sections_durations": True}).encode("utf-8")
    request = urllib.request.Request(f"{ELEVEN_URL}?output_format=mp3_44100_192", data=body, method="POST",
                                     headers={"xi-api-key": key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            audio = response.read()
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:400]}") from None
    if len(audio) < 10000 or audio[:1] in (b"{", b"["):
        raise RuntimeError(f"not audio: {audio[:200]!r}")
    base.RAW.mkdir(parents=True, exist_ok=True)
    raw = base.RAW / f"{name}.mp3"
    raw.write_bytes(audio)
    return raw


def eleven_wav(raw: Path, dest: Path) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw), "-ac", "2", "-ar", "48000",
                    "-c:a", "pcm_s16le", str(dest)], check=True)


def main() -> None:
    wanted = sys.argv[1:] or [*base.MUSIC, *base.SFX]
    # "cue_nothing:3" asks for three takes of the same brief.
    jobs: list[str] = []
    for arg in wanted:
        name, _, takes = arg.partition(":")
        if name.startswith("cue_nothing_el"):
            jobs += [f"{name}_{k}" for k in range(1, int(takes) + 1)] if takes else [name]
        elif takes:
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
        futures = {pool.submit(eleven if name.startswith("cue_nothing_el") else base.generate,
                               *([name] if name.startswith("cue_nothing_el") else [url, key, name])): name
                   for name in jobs}
        for future in as_completed(futures):
            name = futures[future]
            try:
                if name.startswith("cue_nothing_el"):
                    eleven_wav(future.result(), OUT / f"{name}.wav")
                else:
                    base.to_wav(future.result(), OUT / f"{name}.wav")
                print(f"WROTE {name}.wav", flush=True)
            except Exception as exc:  # keep the others going
                print(f"FAIL {name}: {str(exc).replace(key, '[REDACTED]')}", flush=True)


if __name__ == "__main__":
    main()
