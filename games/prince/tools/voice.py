"""Read the prologue aloud with ElevenLabs.

Asks the game for every line the prologue speaks (tools/intro_lines.tscn,
which calls Intro.lines()), then makes each clip that's missing from
assets/voice/: the story in the narrator's voice, the Princess's and the
Vizier's lines in theirs, and the Git word for each beat by the narrator.
A clip is named for its words, so editing a line in ui/intro.gd and running
this again makes just that clip; --prune drops clips no line uses any more.

The key is ELEVENLABS_API_KEY in .env (found as tools/common.py finds the
OpenRouter key) and is never printed. Voices are ElevenLabs' stock ones;
ELEVENLABS_VOICE_NARRATOR, _PRINCESS and _VIZIER in .env swap any of them.

    python tools/voice.py              # every clip that's missing
    python tools/voice.py --redo       # every clip, again
    python tools/voice.py --prune      # and delete clips nothing reads
    godot --headless --path . --import # then let Godot import them

Needs ffmpeg and Godot (GODOT, else `godot` on the PATH).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

from common import load_env  # noqa: E402

OUT = ROOT / "assets" / "voice"
RAW = HERE / "generated" / "voice"
API = "https://api.elevenlabs.io/v1/text-to-speech/{voice}?output_format=mp3_44100_128"
MODEL = "eleven_multilingual_v2"

# Stock ElevenLabs voices, and how each one should sound.
VOICES = {
    # George: a warm, mature British storyteller.
    "narrator": ("JBFqnCBsd6RMkjVDRZzb", {"stability": 0.55, "similarity_boost": 0.75, "style": 0.25}),
    # Lily: a young, warm British woman, brave behind bars.
    "princess": ("pFZP5JQG7iQjIQuC4Bku", {"stability": 0.5, "similarity_boost": 0.75, "style": 0.35}),
    # Callum: husky and sly, a villain enjoying himself.
    "vizier": ("N2lVS1w4EtoT3dr4eOWO", {"stability": 0.35, "similarity_boost": 0.75, "style": 0.6}),
}


def godot() -> str:
    found = os.environ.get("GODOT") or shutil.which("godot")
    if not found:
        raise SystemExit("Godot not found: set GODOT or put godot on the PATH")
    # On Windows the console build prints to the terminal; the GUI one doesn't.
    console = Path(found).resolve().with_name("godot.console.exe")
    scoop = Path.home() / "scoop" / "apps" / "godot" / "current" / "godot.console.exe"
    for candidate in (console, scoop):
        if os.name == "nt" and candidate.exists():
            return str(candidate)
    return found


def lines() -> list[dict]:
    result = subprocess.run([godot(), "--headless", "--path", str(ROOT), "res://tools/intro_lines.tscn"],
                            capture_output=True, text=True, encoding="utf-8", timeout=120)
    for line in result.stdout.splitlines():
        if line.startswith("INTRO_LINES "):
            return json.loads(line.removeprefix("INTRO_LINES "))
    raise SystemExit("The game didn't list its lines:\n" + result.stdout[-2000:] + result.stderr[-2000:])


def speak(key: str, line: dict, env: dict[str, str]) -> Path:
    voice, settings = VOICES[line["voice"]]
    voice = env.get(f"ELEVENLABS_VOICE_{line['voice'].upper()}", voice)
    body = json.dumps({"text": line["text"], "model_id": env.get("ELEVENLABS_MODEL", MODEL),
                       "voice_settings": settings}).encode("utf-8")
    request = urllib.request.Request(API.format(voice=voice), data=body, method="POST", headers={
        "xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            audio = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace").replace(key, "[REDACTED]")
        raise RuntimeError(f"HTTP {exc.code}: {detail[:400]}") from None
    RAW.mkdir(parents=True, exist_ok=True)
    raw = RAW / f"{line['key']}.mp3"
    raw.write_bytes(audio)
    return raw


def to_ogg(source: Path, dest: Path) -> None:
    """Mono Ogg, loudness-matched, with the silence trimmed off both ends."""
    trim = "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05"
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-af",
               f"{trim},areverse,{trim},areverse,loudnorm=I=-16:TP=-1.5:LRA=11",
               "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", str(dest)]
    subprocess.run(command, check=True)


def main() -> None:
    redo = "--redo" in sys.argv
    env = load_env()
    key = env.get("ELEVENLABS_API_KEY", "") or os.environ.get("ELEVENLABS_API_KEY", "")
    wanted = lines()
    todo = [line for line in wanted if redo or not (OUT / f"{line['key']}.ogg").exists()]
    if todo and not key:
        raise SystemExit("ELEVENLABS_API_KEY is missing from .env")
    OUT.mkdir(parents=True, exist_ok=True)
    failed = 0
    for line in todo:
        try:
            to_ogg(speak(key, line, env), OUT / f"{line['key']}.ogg")
            print(f"SPOKE {line['key']} ({line['voice']}): {line['text']}", flush=True)
        except Exception as exc:  # keep the other lines going
            failed += 1
            print(f"VOICE fail {line['key']}: {str(exc).replace(key, '[REDACTED]') if key else exc}", flush=True)
    if "--prune" in sys.argv:
        keep = {f"{line['key']}.ogg" for line in wanted}
        for clip in OUT.glob("intro_*.ogg"):
            if clip.name not in keep:
                clip.unlink()
                Path(str(clip) + ".import").unlink(missing_ok=True)
                print(f"PRUNED {clip.name}")
    print(f"{len(wanted) - failed} of {len(wanted)} lines have a voice")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
