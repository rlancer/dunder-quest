"""Give the cast their voices with ElevenLabs.

Asks the game for every line it speaks (tools/lines.tscn: the prologue, each
case's cold open and talk, the questions for Records and their hints, the
lesson cards, and what Doris and the Lieutenant say over every printout the
pages can bring back), then makes each clip that's missing from
assets/voice/. A clip is named for who says it
and what they say, so editing a line and running this again makes just that
clip; --prune drops clips no line uses any more.

It goes through OpenRouter's speech endpoint, with the same key in .env as
the art and the music (tools/common.py finds it); the key is never printed.
The model is ElevenLabs' v4, the expressive one: a line's `say` may carry
stage directions in square brackets ("[thinking aloud]"), which it acts and
does not read, and spells SQL the way it's said ("select star", "percent
four K"). A line's mood (data/cases.json) becomes a direction too. The
voices are ElevenLabs' stock ones, cast as types, never to sound like any
actor: the detective is rumpled and polite, not anybody's impression. Doris
is on the telephone, so her clips go through a telephone's band.

    python tools/voice.py              # every clip that's missing
    python tools/voice.py --redo       # every clip, again
    python tools/voice.py lt_0123abcdef # just these, again
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
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

from common import api  # noqa: E402

OUT = ROOT / "assets" / "voice"
RAW = HERE / "generated" / "voice"
MODEL = os.environ.get("VOICE_MODEL", "elevenlabs/eleven-v4")
# Every clip's loudness, in LUFS.
LOUDNESS = -16.0

# Stock ElevenLabs voices, by OpenRouter's names for them.
VOICES = {
    # An older announcer: the cold opens, the prologue and the lesson cards.
    "narrator": "bill",
    # Lieutenant Colonna: warm, down to earth, polite, a man who rambles.
    "lt": "chris",
    # Doris in Records: brisk, confident, no time to waste.
    "doris": "sarah",
    # The suspects, every one of them well off and sure of it.
    # Voss, the developer: easy, confident, pleased with himself.
    "voss": "roger",
    # Ms. Bannister, the tennis champion: bright and sharp.
    "bannister": "jessica",
    # Brandt, the astrologer: husky, theatrical.
    "brandt": "callum",
    # Dr. Sloane, the psychiatrist: measured and professional.
    "sloane": "matilda",
    # Mrs. Harrow, the hotelier: a grand old voice.
    "harrow": "lily",
}
# Voices heard down a telephone line.
PHONE = {"doris"}


def godot() -> str:
    found = os.environ.get("GODOT") or shutil.which("godot")
    scoop = Path.home() / "scoop" / "apps" / "godot" / "current" / "godot.console.exe"
    if os.name == "nt":
        # The console build prints to the terminal; the GUI one doesn't.
        for candidate in ([Path(found).resolve().with_name("godot.console.exe")] if found else []) + [scoop]:
            if candidate.exists():
                return str(candidate)
    if not found:
        raise SystemExit("Godot not found: set GODOT or put godot on the PATH")
    return found


def lines() -> list[dict]:
    result = subprocess.run([godot(), "--headless", "--path", str(ROOT), "res://tools/lines.tscn"],
                            capture_output=True, text=True, encoding="utf-8", timeout=180)
    for line in result.stdout.splitlines():
        if line.startswith("LINES "):
            return json.loads(line.removeprefix("LINES "))
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
        with urllib.request.urlopen(request, timeout=180) as response:
            audio = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace").replace(key, "[REDACTED]")
        raise RuntimeError(f"HTTP {exc.code}: {detail[:400]}") from None
    if len(audio) < 2000 or audio[:1] in (b"{", b"["):
        raise RuntimeError(f"not audio: {audio[:200]!r}")
    RAW.mkdir(parents=True, exist_ok=True)
    raw.write_bytes(audio)
    return raw


def to_ogg(source: Path, dest: Path, phone: bool = False) -> None:
    """Mono Ogg with the silence trimmed off both ends, every clip as loud as
    the next. The level is measured and then set, since a one-pass loudnorm
    leaves a two-second clip several decibels short. `phone` narrows it to a
    telephone's band first. 24 kHz at Vorbis quality 0 is plenty for speech,
    and keeps this game's many lines inside the web build's size cap."""
    trim = "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05"
    trimmed = f"{trim},areverse,{trim},areverse"
    if phone:
        trimmed += ",highpass=f=350,lowpass=f=3200,acompressor=threshold=0.2:ratio=3"
    heard = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(source), "-af", f"{trimmed},ebur128=framelog=quiet",
                            "-f", "null", "-"], capture_output=True, text=True, check=True).stderr
    gain = LOUDNESS - float(re.findall(r"I:\s+(-?[\d.]+) LUFS", heard)[-1])
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-af",
               f"{trimmed},volume={gain:.2f}dB,alimiter=limit=0.84:level=false",
               "-ac", "1", "-ar", "24000", "-c:a", "libvorbis", "-q:a", "0", str(dest)]
    subprocess.run(command, check=True)


def main() -> None:
    redo = "--redo" in sys.argv
    picked = {a for a in sys.argv[1:] if not a.startswith("--")}
    wanted = lines()
    todo = [line for line in wanted if redo or line["key"] in picked or not (OUT / f"{line['key']}.ogg").exists()]
    url, key = api() if todo else ("", "")
    OUT.mkdir(parents=True, exist_ok=True)

    def one(line: dict) -> bool:
        try:
            to_ogg(speak(url, key, line, redo or line["key"] in picked), OUT / f"{line['key']}.ogg",
                   line["voice"] in PHONE)
            print(f"SPOKE {line['key']} ({line['voice']}): {line['text']}", flush=True)
            return True
        except Exception as exc:  # keep the other lines going
            print(f"VOICE fail {line['key']}: {str(exc).replace(key, '[REDACTED]')}", flush=True)
            return False

    with ThreadPoolExecutor(max_workers=int(os.environ.get("VOICE_WORKERS", "4"))) as pool:
        failed = sum(0 if ok else 1 for ok in pool.map(one, todo))
    if "--prune" in sys.argv:
        keep = {f"{line['key']}.ogg" for line in wanted}
        for clip in OUT.glob("*.ogg"):
            if clip.name not in keep:
                clip.unlink()
                Path(str(clip) + ".import").unlink(missing_ok=True)
                (RAW / f"{clip.stem}.mp3").unlink(missing_ok=True)
                print(f"PRUNED {clip.name}")
    print(f"{len(wanted) - failed} of {len(wanted)} lines have a voice")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
