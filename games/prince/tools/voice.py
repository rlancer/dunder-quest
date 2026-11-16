"""Read the prologue aloud with ElevenLabs.

Asks the game for every line the prologue speaks (tools/intro_lines.tscn,
which calls Intro.lines()), then makes each clip that's missing from
assets/voice/: the story in the narrator's voice, the Princess's and the
Vizier's lines in theirs, and the Git word for each beat by the narrator.
A clip is named for its words, so editing a line in ui/intro.gd and running
this again makes just that clip; --prune drops clips no line uses any more.

It goes through OpenRouter's speech endpoint, with the same key in .env as
the art and the music (tools/common.py finds it); the key is never printed.
Voices are ElevenLabs' stock ones.

    python tools/voice.py              # every clip that's missing
    python tools/voice.py --redo       # every clip, again
    python tools/voice.py --prune      # and delete clips nothing reads
    godot --headless --path . --import # then let Godot import them

Needs ffmpeg and Godot (GODOT, else `godot` on the PATH).
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

from common import api  # noqa: E402

OUT = ROOT / "assets" / "voice"
RAW = HERE / "generated" / "voice"
# Made for steady narration, so sixteen separate clips sound like one reading.
MODEL = "elevenlabs/eleven-multilingual-v2"
# Every clip's loudness, in LUFS.
LOUDNESS = -16.0

# Stock ElevenLabs voices, by OpenRouter's names for them.
VOICES = {
    # A warm, mature British storyteller.
    "narrator": "george",
    # A young, warm British woman, brave behind bars.
    "princess": "lily",
    # Husky and sly, a villain enjoying himself.
    "vizier": "callum",
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


def speak(url: str, key: str, line: dict, redo: bool) -> Path:
    """The line as ElevenLabs read it. A reading already in tools/generated/
    is used again unless `redo`, so re-levelling the clips costs nothing."""
    raw = RAW / f"{line['key']}.mp3"
    if raw.exists() and not redo:
        return raw
    body = json.dumps({"model": MODEL, "input": line["text"], "voice": VOICES[line["voice"]],
                       "response_format": "mp3"}).encode("utf-8")
    request = urllib.request.Request(f"{url}/audio/speech", data=body, method="POST", headers={
        "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            audio = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace").replace(key, "[REDACTED]")
        raise RuntimeError(f"HTTP {exc.code}: {detail[:400]}") from None
    if len(audio) < 2000 or audio[:1] in (b"{", b"["):
        raise RuntimeError(f"not audio: {audio[:200]!r}")
    RAW.mkdir(parents=True, exist_ok=True)
    raw.write_bytes(audio)
    return raw


def to_ogg(source: Path, dest: Path) -> None:
    """Mono Ogg with the silence trimmed off both ends, every clip as loud as
    the next. The level is measured and then set, since a one-pass loudnorm
    leaves a two-second clip several decibels short."""
    trim = "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05"
    trimmed = f"{trim},areverse,{trim},areverse"
    heard = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(source), "-af", f"{trimmed},ebur128=framelog=quiet",
                            "-f", "null", "-"], capture_output=True, text=True, check=True).stderr
    gain = LOUDNESS - float(re.findall(r"I:\s+(-?[\d.]+) LUFS", heard)[-1])
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-af",
               f"{trimmed},volume={gain:.2f}dB,alimiter=limit=0.84:level=false",
               "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", str(dest)]
    subprocess.run(command, check=True)


def main() -> None:
    redo = "--redo" in sys.argv
    wanted = lines()
    todo = [line for line in wanted if redo or not (OUT / f"{line['key']}.ogg").exists()]
    url, key = api() if todo else ("", "")
    OUT.mkdir(parents=True, exist_ok=True)
    failed = 0
    for line in todo:
        try:
            to_ogg(speak(url, key, line, redo), OUT / f"{line['key']}.ogg")
            print(f"SPOKE {line['key']} ({line['voice']}): {line['text']}", flush=True)
        except Exception as exc:  # keep the other lines going
            failed += 1
            print(f"VOICE fail {line['key']}: {str(exc).replace(key, '[REDACTED]')}", flush=True)
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
