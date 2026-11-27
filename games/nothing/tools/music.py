"""Generate the title, prologue and episode music with ElevenLabs Music.

Original music in the style of an early-1990s studio sitcom: slapped and
popped bass up front, a little synth, finger snaps, a tight funk kit, and
the stops and hits that land a joke. The briefs ask for a style and
instruments only; they never name or describe any show's music or any
existing song, and none of them recreates a theme tune.

It calls ElevenLabs' own music API (POST /v1/music) with its newest model,
`music_v2_5`, instrumental only, in loop mode. Loop mode mostly ends a
track at full volume, but not always (some end in a short tail), so the
seams are still smoothed with make_loops.py afterwards. OpenRouter
carries ElevenLabs' voices but not its music, so this needs
ELEVENLABS_API_KEY in .env. In a cloud session for this repo the
environment holds it as a network secret, and
`ELEVENLABS_API_KEY=proxy-injected` is enough. The key is never printed.

    python tools/music.py                    # every track that's missing
    python tools/music.py title diner        # just these, again
    python ../dunder-quest/tools/make_loops.py assets/audio/music_*.ogg   # then smooth the seams
    godot --headless --path . --import       # and import them

The smaller ElevenLabs plans run two requests at a time, so it makes two at
once.
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

from common import load_env  # noqa: E402

OUT = ROOT / "assets" / "audio"
RAW = HERE / "generated" / "music"
URL = "https://api.elevenlabs.io/v1/music"
MODEL = os.environ.get("MUSIC_MODEL", "music_v2_5")

COMMON = (
    "Instrumental only, no vocals. Original music for a comic pixel-art game about four friends in New York "
    "in the early 1990s. Clean, punchy, live-sounding studio band, recorded dry and close. Do not imitate or "
    "quote any existing song, television theme or soundtrack: a brand-new melody and a brand-new bass line. "
)

# Each: the brief, and its length in seconds.
TRACKS = {
    "title": (COMMON + (
        "A cocky, bouncy title theme at 112 BPM in E major. A slapped and popped electric bass plays a "
        "syncopated, conversational riff full of ghost notes and octave pops, like someone telling a joke "
        "with great timing. Finger snaps on 2 and 4, a tight dry funk kit with a crisp snare, a bright synth "
        "organ answering the bass, muted clean guitar chops. Sudden full-band stops where only the bass "
        "keeps talking, then the band slams back in. Wry, confident and funny."), 60),
    "apartment": (COMMON + (
        "Light, sly hanging-out music for a friend's apartment, 96 BPM in G major. A slapped bass plays short "
        "chatty phrases with gaps between them, like someone thinking out loud. Finger snaps, soft synth "
        "marimba, a brushed snare, a little synth bass blip at the end of phrases. Sparse and airy so "
        "dialogue sits on top. Amused, never sleepy."), 70),
    "diner": (COMMON + (
        "Upbeat, cheeky breakfast-rush music for a busy corner diner, 116 BPM in F major. A punchy slapped and "
        "popped bass riff with attitude, a tight funk kit with a snappy snare, finger snaps, a bright synth "
        "organ answering the bass, short stabby synth brass hits like a raised eyebrow, muted guitar chops. "
        "Busy, gossipy and comic, with full-band stops where the bass gets the last word. Not smooth jazz, "
        "not lounge, not relaxed: it should make you want to order fast."), 60),
    "garage": (COMMON + (
        "Comic, impatient music for queuing at a strict food counter with a line round the block, 104 BPM in "
        "D minor. A tense slapped bass ostinato that shuffles forward then stops dead, a ticking hi-hat, "
        "a muted synth trumpet with a deadpan little motif, pizzicato synth plucks, a single snare crack on "
        "each stop. Nervous, silly, never scary."), 65),
    "restaurant": (COMMON + (
        "Restless, impatient waiting music for the packed lobby of a restaurant on a Saturday night, 112 BPM in "
        "A minor. A pushy walking slap bass that keeps checking its watch, a woodblock ticking like a clock, a "
        "tight snare with a cross-stick groove, staccato vibraphone stabs, a clavinet arguing with the bass. "
        "Exasperated and comic, with sudden stops where everyone glares at the door. Not smooth jazz, not lounge."), 65),
    "network": (COMMON + (
        "Buttoned-up boardroom music for pitching a show to a man who never laughs, 108 BPM in C minor. A "
        "tight, nervous slapped bass figure, a stiff electronic drum groove, a cold synth string pad slowly "
        "swelling, a synth brass hit at the end of each phrase like a joke that didn't land. Comic pressure "
        "that builds without getting loud."), 70),
    # Under the prologue's narration, so it stays out of the voice's way.
    # Under the prologue's narration: it sits lower to leave room for the voice, but it still moves.
    "intro": (COMMON + (
        "A sly, bouncy storytelling underscore for a narrator introducing a group of friends in the city, 100 BPM "
        "in B-flat major. A slapped bass plays short playful riffs with gaps for the voice, a clean electric piano "
        "comping in short chords, finger snaps, a crisp shaker, a light funk kit. Mostly low and middle register "
        "so a speaking voice sits on top, but with a wink and a groove you can nod to. Not smooth jazz, not "
        "lounge, not ambient."), 70),
}


def key() -> str:
    found = os.environ.get("ELEVENLABS_API_KEY") or load_env().get("ELEVENLABS_API_KEY", "")
    if not found:
        raise SystemExit("ELEVENLABS_API_KEY is missing from .env")
    return found


def target(name: str) -> Path:
    return OUT / f"music_{name}.ogg"


def generate(api_key: str, name: str, mode: str = "loop") -> Path:
    brief, seconds = TRACKS[name]
    body = json.dumps({"prompt": brief, "model_id": MODEL, "music_length_ms": seconds * 1000,
                       "force_instrumental": True, "generation_mode": mode}).encode("utf-8")
    request = urllib.request.Request(f"{URL}?output_format=mp3_44100_192", data=body, method="POST", headers={
        "xi-api-key": api_key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            audio = response.read()
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:400]}") from None
    if len(audio) < 10000 or audio[:1] in (b"{", b"["):
        raise RuntimeError(f"not audio: {audio[:200]!r}")
    RAW.mkdir(parents=True, exist_ok=True)
    path = RAW / f"{name}.mp3"
    path.write_bytes(audio)
    return path


def to_ogg(source: Path, dest: Path) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-ac", "2", "-ar", "44100",
                    "-c:a", "libvorbis", "-q:a", "4", str(dest)], check=True)
    print(f"INSTALLED {dest.name} {dest.stat().st_size // 1024} KiB", flush=True)


def main() -> None:
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = names or [n for n in TRACKS if not target(n).exists()]
    api_key = key()
    OUT.mkdir(parents=True, exist_ok=True)
    failed = 0
    # ElevenLabs runs two requests at a time on the smaller plans.
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(generate, api_key, name): name for name in names}
        for future in as_completed(futures):
            name = futures[future]
            try:
                to_ogg(future.result(), target(name))
            except Exception as exc:  # keep the other tracks going
                failed += 1
                print(f"MUSIC fail {name}: {str(exc).replace(api_key, '[REDACTED]')}", flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
