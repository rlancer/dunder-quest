"""Cut Yes, Shell!'s trailer from Movie Maker captures of the bot.

A fast run of highlights on the beat of one original cue (nervy guitar,
driving bass and drums, pots and pans): Uncle Awk's kitchen, where the
orders were shouted, the name as the band crashes in, Ash Bourne home with
a system, then a card at a time ("Every station is a command. The pass is a
pipe.") between the moments that teach: a line written chip by chip with
the pass printing as it goes, the fire and the ORDER UP, the shell's own
error word for word, a line that sends too much and Shell saying so, the
pipe, the ticket machine in the cue's dead stop, the critic's question, and
the five-command line on the band's return, then an end card with the URL.
It doesn't play the game through. The voices are the game's own clips
(assets/voice/), laid in here rather than taken from the captures, so a
line can be trimmed to the sentence that lands.

Shots are laid out in the game's native 480x270 units but composed at
1920x1080 (`S` times that), so text is sharp: the game draws its text at
window resolution and is captured at 1920x1080 (`trailer/capture.sh`), and
the trailer's own cards are drawn at full size too. The pixel art stays on
whole-number nearest-neighbor scales. The mixing and encoding helpers come
from the Dunder Quest trailer (../../dunder-quest/tools/make_trailer.py).

The cue (`trailer/audio/cue_shell.wav`, from tools/trailer_audio.py) was
measured at 120 BPM, beats on 0.49 s + k/2 in cue time. In cue time: a
sparse, ticking opening from 2.0 s, the band in on 9.99, a dead stop from
42.5 to 50.3 (its last chord gone by 43), a quiet build to 54.49, the full
band again, and the last hit on 59.49, then a soft tag to 63.3. The trailer
plays the sparse bars one and a half times (the cold open needs twelve
seconds), so from the band's entry trailer time is cue time plus 2.01 s:
the band comes in at 12 s, beats every half second from there, bars of
four. Every cut lands on one.

Shots find their capture frames by name in the MARK logs
(`trailer/captures/<name>.log`), so a fresh capture needs no renumbering.
Needs ffmpeg on the PATH.

    bash trailer/capture.sh                 # -> trailer/captures/{open,s1..s5}/ + logs, at 1920x1080
    python tools/make_trailer.py            # -> trailer/out/shell_trailer_{1080p,4k}.mp4 + shell_thumbnail.png
    python tools/make_trailer.py --stills   # one frame per shot, for checking the cut
    python tools/make_trailer.py --at 3 12.5   # frames at those trailer times
    python tools/make_trailer.py --thumb    # just the thumbnail (also copied to the site)
    python tools/make_trailer.py --audio-only   # remix over the video already rendered
"""

from __future__ import annotations

import hashlib
import json
import math
import re
import subprocess
import sys
import wave
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Callable

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import make_trailer as dq  # noqa: E402
from make_trailer import flash, font  # noqa: E402

CAPTURES = ROOT / "trailer" / "captures"
AUDIO = ROOT / "trailer" / "audio"
OUT = ROOT / "trailer" / "out"
SITE_THUMB = REPO / "site" / "static" / "img" / "shell" / "trailer.png"
TITLES = ROOT / "assets" / "fonts" / "BebasNeue.ttf"
MONO = ROOT / "assets" / "fonts" / "VT323.ttf"
PIXEL = ROOT / "assets" / "fonts" / "PixelifySans.ttf"
GAME_AUDIO = ROOT / "assets" / "audio"
VOICE = ROOT / "assets" / "voice"

## Layout units are the game's native pixels; frames are S times that.
W, H = dq.W, dq.H
S = 4
CW, CH = W * S, H * S
FPS = dq.FPS
RATE = dq.RATE


def rgb(r: float, g: float, b: float) -> tuple[int, int, int]:
    return (round(r * 255), round(g * 255), round(b * 255))


# The game's palette (core/palette.gd).
INK = rgb(0.1, 0.11, 0.13)
PAPER = rgb(0.95, 0.94, 0.9)
PAPER_DARK = rgb(0.83, 0.82, 0.77)
STEEL = rgb(0.25, 0.29, 0.34)
STEEL_DARK = rgb(0.11, 0.13, 0.16)
STEEL_LIGHT = rgb(0.5, 0.56, 0.62)
LAMP = rgb(0.96, 0.62, 0.18)
LAMP_LIGHT = rgb(1.0, 0.82, 0.42)
RED = rgb(0.76, 0.17, 0.13)
RED_LIGHT = rgb(0.97, 0.42, 0.33)
GREEN_LIGHT = rgb(0.47, 0.87, 0.57)
CREAM = rgb(0.97, 0.95, 0.88)
TERM = rgb(0.04, 0.06, 0.07)
TERM_TEXT = rgb(0.82, 0.93, 0.84)
NIGHT = rgb(0.03, 0.04, 0.06)
BLACK = (0, 0, 0)

# --- The cue -----------------------------------------------------------------

CUE = "cue_shell"
BEAT = 0.5
## Cue time of the sparse opening, and of the band's entry.
CUE_SPARSE = 1.99
CUE_BAND = 9.99
## Trailer time the band comes in: the sparse bars, one and a half times.
BAND = 12.0
## Where the cue's tag has rung out, in cue time.
CUE_END = 63.3
## Trailer times of the cue's landmarks.
STOP = 44.5      # the band is gone (its last chord dies by 45)
BUILD = 52.5     # a quiet build starts
BACK = 56.5      # the full band again
LAST_HIT = 61.5
## How long the end card runs, with the tag and the last word under it.
END_HOLD = 9.0


def bar(n: float) -> float:
    """Trailer time of bar `n` (two seconds each), counted from the start."""
    return n * 4 * BEAT


# --- The capture's MARK logs ---------------------------------------------------

@lru_cache(maxsize=None)
def marks(cap: str) -> list[tuple[int, str]]:
    log = CAPTURES / f"{cap}.log"
    if not log.exists():
        sys.exit(f"no {log.name}: run bash trailer/capture.sh")
    out = []
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"MARK (\d+) (.*)$", line)
        if m:
            out.append((int(m.group(1)), m.group(2)))
    return out


def mark(cap: str, text: str, nth: int = 0) -> int:
    """The frame of the `nth` MARK in `cap`'s log that starts with `text`."""
    found = [f for f, s in marks(cap) if s.startswith(text)]
    if len(found) <= nth:
        sys.exit(f"no MARK '{text}' #{nth} in {cap}.log")
    return found[nth]


def said(cap: str, start: str) -> int:
    """The frame a line of talk starting with `start` came up."""
    for f, s in marks(cap):
        if s.startswith("say ") and s.split("| ", 1)[-1].startswith(start):
            return f
    sys.exit(f"no line '{start}' in {cap}.log")


# --- Sharp drawing, in native units --------------------------------------------

def width(s: str, path: Path, size: float) -> float:
    return font(path, round(size * S)).getlength(s) / S


def text(img: Image.Image, xy: tuple[float, float], s: str, path: Path, size: float, color,
         anchor: str = "lt", outline=None, thick: float = 1, shadow=None, shadow_dy: float = 0) -> None:
    """`s` antialiased at full resolution; `xy`, `size`, `thick` and
    `shadow_dy` are in native pixels. `anchor` is 'lt', 'mt' or 'rt'."""
    fnt = font(path, round(size * S))
    x, y = xy[0] * S, xy[1] * S
    pil_anchor = {"lt": "la", "mt": "ma", "rt": "ra"}[anchor]
    d = ImageDraw.Draw(img)
    stroke = round(thick * S) if outline is not None else 0
    if shadow is not None and shadow_dy:
        d.text((x, y + shadow_dy * S), s, font=fnt, fill=shadow, anchor=pil_anchor, stroke_width=stroke, stroke_fill=shadow)
    d.text((x, y), s, font=fnt, fill=color, anchor=pil_anchor, stroke_width=stroke, stroke_fill=outline)


def rect(img: Image.Image, box: tuple[float, float, float, float], fill=None, border=None, thick: float = 1) -> None:
    x0, y0, x1, y1 = (round(v * S) for v in box)
    d = ImageDraw.Draw(img)
    if fill is not None:
        d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=fill)
    if border is not None:
        d.rectangle((x0, y0, x1 - 1, y1 - 1), outline=border, width=round(thick * S))


@lru_cache(maxsize=None)
def backdrop(name: str, dark: float) -> Image.Image:
    """One of the game's backdrops, at full size, dimmed towards night."""
    art = Image.open(ROOT / "assets" / "backgrounds" / f"{name}.png").convert("RGB").resize((CW, CH), Image.NEAREST)
    return Image.blend(art, Image.new("RGB", (CW, CH), NIGHT), dark)


# --- Overlays -----------------------------------------------------------------

def flash_fx(at: float, frames: int = 4, peak: float = 0.8, color=(255, 244, 220)):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) * FPS
        return flash(img, peak * (1 - k / frames), color) if 0 <= k < frames else img
    return fx


def shake_fx(at: float, amount: float = 3.0, length: float = 0.3):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = t - at
        if not 0 <= k < length:
            return img
        a = amount * (1 - k / length)
        if a < 0.5:
            return img
        dx = int(round(math.sin(t * 91.0) * a * S))
        dy = int(round(math.cos(t * 77.0) * a * S))
        out = Image.new("RGB", img.size, BLACK)
        out.paste(img, (dx, dy))
        return out
    return fx


def fade_in_fx(at: float, length: float = 0.5):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) / length
        return Image.blend(Image.new("RGB", img.size, BLACK), img, max(k, 0.0)) if k < 1 else img
    return fx


# --- Cards ----------------------------------------------------------------------

def card(lines: list[str], size: float = 34, place: str = "pass", dark: float = 0.8):
    """A card over one of the game's backdrops, dimmed: tall capitals,
    centered, the last line in the lamp's orange. A line that starts with
    ` is a line of shell, on a terminal strip."""
    def draw(_t: float) -> Image.Image:
        img = backdrop(place, dark).copy()
        fitted = []
        for s in lines:
            code = s.startswith("`")
            s = s.lstrip("`")
            path = MONO if code else TITLES
            px = size * (0.9 if code else 1.0)
            while width(s, path, px) > W - 48:
                px -= 1
            fitted.append((s, code, path, px))
        step = size * 1.25
        y = (H - step * len(lines)) / 2 + 2
        for k, (s, code, path, px) in enumerate(fitted):
            if code:
                w = width("$ " + s, path, px) + 20
                rect(img, ((W - w) / 2, y - 3, (W + w) / 2, y + px + 2), fill=TERM, border=STEEL)
                x = (W - w) / 2 + 10
                text(img, (x, y - 1), "$", path, px, GREEN_LIGHT)
                text(img, (x + width("$ ", path, px), y - 1), s, path, px, TERM_TEXT)
            else:
                color = LAMP if k == len(lines) - 1 else CREAM
                text(img, (W / 2, y), s, path, px, color, anchor="mt", shadow=BLACK, shadow_dy=2)
            y += step
        return img
    return draw


def name_block(img: Image.Image, top: float) -> None:
    """The game's name, centered, as the title screen sets it."""
    text(img, (W / 2, top), "THE STANDARD INN PRESENTS", TITLES, 16, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
    text(img, (W / 2, top + 18), "YES, SHELL!", TITLES, 84, LAMP, anchor="mt", shadow=BLACK, shadow_dy=3)


def title_card(_t: float) -> Image.Image:
    img = backdrop("title", 0.55).copy()
    name_block(img, 70)
    return img


def end_card(at: float):
    def draw(t: float) -> Image.Image:
        img = backdrop("title", 0.66).copy()
        local = t - at
        name_block(img, 14)
        if local >= 0.8:
            text(img, (W / 2, 124), "Learn the shell.", MONO, 30, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
            text(img, (W / 2, 150), "Five shifts. Every line voiced. Real bash.", MONO, 18, PAPER, anchor="mt",
                 shadow=BLACK, shadow_dy=1)
        if local >= 1.6:
            text(img, (W / 2, 184), "Play free in your browser", PIXEL, 11, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
            text(img, (W / 2, 197), "dunderquest.com/shell", MONO, 34, LAMP_LIGHT, anchor="mt", shadow=BLACK, shadow_dy=2)
        if local >= 2.4:
            text(img, (W / 2, 242), "a __dunder_quest__ game", MONO, 18, PAPER, anchor="mt", shadow=BLACK, shadow_dy=1)
        return img
    return draw


# --- Gameplay source ------------------------------------------------------------

@lru_cache(maxsize=48)
def capture(cap: str, frame: int) -> Image.Image:
    path = CAPTURES / cap / f"f{frame:08d}.png"
    if not path.exists():
        return Image.new("RGB", (CW, CH), NIGHT)
    img = Image.open(path).convert("RGB")
    return img if img.size == (CW, CH) else img.resize((CW, CH), Image.NEAREST)


@dataclass
class Shot:
    """`start`..`end` in trailer seconds. `src` is the frame of capture `cap`
    shown at `start`; `draw` paints a card instead. `fx` paint on top, in
    order. `audio` is how loud the capture's own sound (its effects) goes
    in, 0 for none; the voices are laid in separately (`voices()`)."""
    start: float
    end: float
    cap: str = ""
    src: int | None = None
    speed: float = 1.0
    draw: Callable[[float], Image.Image] | None = None
    fx: list[Callable[[Image.Image, float], Image.Image]] = field(default_factory=list)
    audio: float = 0.0
    label: str = ""

    def frame_at(self, t: float) -> int:
        return int(self.src + round((t - self.start) * FPS * self.speed))


## The banners at the end of the pipe, a beat each: capture, ticket.
RUN = (("s4", "4d"), ("s5", "5b"))


def edit() -> list[Shot]:
    shots: list[Shot] = []

    def add(start: float, end: float, **kw) -> Shot:
        shot = Shot(start, end, **kw)
        shots.append(shot)
        return shot

    # The sparse bars: Uncle Awk's kitchen, where the orders were shouted.
    add(0.0, bar(2.75), cap="open", src=mark("open", "page 1") + 4, label="awk's kitchen", fx=[fade_in_fx(0.0, 0.6)])
    add(bar(2.75), BAND, cap="open", src=mark("open", "page 2"), label="table six")
    # The band crashes in on the name.
    add(BAND, bar(7), draw=title_card, label="title", fx=[flash_fx(BAND, 5, 0.85), shake_fx(BAND, 3, 0.3)])
    # Ash Bourne comes home, with a system.
    add(bar(7), bar(8.75), cap="open", src=mark("open", "page 3") + 30, label="ash comes home")
    add(bar(8.75), bar(11.5), cap="open", src=mark("open", "page 4"), label="the system")
    add(bar(11.5), bar(12.5), draw=card(["Every station is a command.", "The pass is a pipe."]), label="card stations")
    # A line, a chip at a time, the pass printing as it goes; the fire and the order-up.
    add(bar(12.5), bar(14.5), cap="s2", src=mark("s2", "write 2a 2") + 4, audio=1.0, label="grep beef")
    add(bar(14.5), bar(15.5), draw=card(["Real shell.", "Real errors."], 40), label="card errors")
    # The words the wrong way round: bash's own error, and Shell on it.
    add(bar(15.5), bar(18.5), cap="s2", src=mark("s2", "write 2a 0") + 4, audio=1.0, label="no such file")
    # Too much food.
    add(bar(18.5), bar(20), cap="s2", src=mark("s2", "fire 2a 1") - 20, audio=1.0, label="too much",
        fx=[flash_fx(bar(18.5), 3, 0.4)])
    # The pipe, then a couple of banners on the beat, up to the stop.
    write = mark("s3", "write 3b")
    sent = mark("s3", "sent 3b")
    length = bar(21.75) - bar(20)
    add(bar(20), bar(21.75), cap="s3", src=write + 10, speed=(sent + 40 - write - 10) / (length * FPS), label="the pipe")
    for k, (cap, ticket) in enumerate(RUN):
        at = bar(21.75) + k * BEAT
        add(at, at + BEAT, cap=cap, src=mark(cap, f"sent {ticket}") + 30, label=f"sent {ticket}",
            fx=[flash_fx(at, 3, 0.45)])
    # The cue stops dead. The ticket machine doesn't.
    add(STOP, bar(24.25), cap="s5", src=said("s5", "The machine!") - 2, label="the machine",
        fx=[shake_fx(STOP + 0.1, 2.5, 0.6)])
    add(bar(24.25), BUILD, cap="s5", src=said("s5", "Twelve tickets") - 2, label="twelve tickets")
    # The critic's question, through the build.
    add(BUILD, bar(27.25), cap="s5", src=said("s5", "One question, Chef") - 2, label="one question")
    # Her ticket, held on the empty line until the first chip.
    brief = mark("s5", "brief 5d") + 4
    add(bar(27.25), BACK, cap="s5", src=brief, speed=(mark("s5", "write 5d") + 4 - brief) / ((BACK - bar(27.25)) * FPS),
        label="the critic's ticket")
    # The five-command line on the band's return.
    write = mark("s5", "write 5d")
    sent = mark("s5", "sent 5d")
    length = LAST_HIT - BACK
    add(BACK, LAST_HIT, cap="s5", src=write + 4, speed=(sent + 70 - write - 4) / (length * FPS), label="five commands",
        fx=[shake_fx(BACK, 3, 0.35)])
    add(LAST_HIT, LAST_HIT + END_HOLD, draw=end_card(LAST_HIT), label="end card", fx=[flash_fx(LAST_HIT, 5, 0.7)])
    return shots


def chapters() -> list[tuple[float, str]]:
    """YouTube chapters (each at least 10 s long), for the video description."""
    return [(0.0, "The Standard Inn"), (bar(11.5), "Build the line"),
            (bar(20), "The pass is a pipe"), (BUILD, "The critic's question")]


# --- The voices -------------------------------------------------------------------

def voice_key(who: str, words: str) -> str:
    """The clip's name, as core/voice.gd makes it."""
    return f"{who}_{hashlib.md5((who + '|' + words).encode()).hexdigest()[:10]}"


@lru_cache(maxsize=None)
def spoken_lines() -> dict[tuple[str, str], str]:
    """(who, text) -> the words as read aloud, for every line in data/shifts.json."""
    data = json.loads((ROOT / "data" / "shifts.json").read_text(encoding="utf-8"))
    out: dict[tuple[str, str], str] = {}

    def walk(node) -> None:
        if isinstance(node, dict):
            if "text" in node and "who" in node:
                out[(node["who"], node["text"])] = node.get("say", node["text"].replace('"', "").strip())
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)
    walk(data["shifts"])
    return out


@dataclass
class Line:
    """A voice clip laid into the trailer at `at`: `words` are the line as
    written (looked up in data/shifts.json for its `say`, or read as they
    are for the prologue); `cut` is the part of it used, in seconds;
    `tight` closes its pauses up to that many seconds."""
    at: float
    who: str
    words: str
    cut: tuple[float, float] | None = None
    tight: float = 0.0
    gain: float = 1.0

    def spoken(self) -> str:
        return spoken_lines().get((self.who, self.words), self.words.replace('"', "").strip())


## The narrator on the Chef's homecoming: its first words and its last are used.
ASH = "Then Ash Bourne came home, out of the finest kitchen in the country, with a roll of green tape, a marker, and a system."


def voices() -> list[Line]:
    return [
        Line(0.4, "narrator", "It was Uncle Awk's kitchen. Orders were shouted. Tickets were lost. Nothing had been "
             "written down since 1987.", cut=(0.0, 4.95), tight=0.25),
        Line(bar(2.75) + 0.2, "awk", "Two beef! No, three! Who's got table six? WHO HAS TABLE SIX?", tight=0.2),
        Line(bar(7) + 0.1, "narrator", ASH, cut=(0.0, 1.85)),
        Line(bar(7) + 2.1, "narrator", ASH, cut=(6.7, 7.53)),
        Line(bar(8.75) + 0.1, "chef", "Every station does one thing. It does it well. Then it passes it down the line.",
             tight=0.2),
        Line(bar(15.5) + 0.3, "shell", "The word first, then the file. Swap them round and it goes looking for a file "
             "called beef.", tight=0.15),
        Line(bar(19.5) + 0.25, "chef", "Yes, Shell."),
        Line(STOP + 0.15, "awk", "The machine! The to-go machine! It won't stop printing!"),
        Line(bar(24.25) + 0.15, "shell", "Twelve tickets and climbing. Don't read them, Chef. Build a line.", tight=0.15),
        Line(BUILD + 0.6, "root", "One question, Chef, and I'll have the answer on one line.", tight=0.15),
        Line(LAST_HIT + 0.9, "root", "Fries. Five stations, not one raised voice, and the answer is fries.", tight=0.2),
        Line(LAST_HIT + 7.0, "awk", "...Yes, Shell."),
    ]


def load_audio(path: Path) -> np.ndarray:
    """Any sound file as float32 stereo at RATE."""
    if path.suffix == ".wav":
        return dq.load_wav(path)
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "s16le", "-ac", "2",
                          "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).reshape(-1, 2).astype(np.float32) / 32768.0


def tightened(clip: np.ndarray, keep: float) -> np.ndarray:
    """`clip` with every pause longer than `keep` seconds closed up to it."""
    hop = RATE // 100
    level = np.array([np.sqrt((clip[i:i + hop] ** 2).mean()) for i in range(0, len(clip) - hop, hop)])
    quiet = level < 0.012
    parts = []
    last = 0
    i = 0
    while i < len(quiet):
        if not quiet[i]:
            i += 1
            continue
        j = i
        while j < len(quiet) and quiet[j]:
            j += 1
        if (j - i) / 100 > keep + 0.1 and i > 0 and j < len(quiet):
            cut_from = int((i / 100 + keep / 2) * RATE)
            cut_to = int((j / 100 - keep / 2) * RATE)
            parts.append(clip[last:cut_from])
            last = cut_to
        i = j
    parts.append(clip[last:])
    return np.concatenate(parts)


@lru_cache(maxsize=None)
def _voice_clip(who: str, spoken: str, cut: tuple[float, float] | None, tight: float) -> np.ndarray:
    path = VOICE / f"{voice_key(who, spoken)}.ogg"
    if not path.exists():
        sys.exit(f"no voice clip for {who}: {spoken[:40]}")
    clip = load_audio(path)
    if cut is not None:
        clip = clip[int(cut[0] * RATE):int(cut[1] * RATE)].copy()
    if tight > 0:
        clip = tightened(clip, tight)
    soft = int(0.03 * RATE)
    clip = clip.copy()
    clip[:soft] *= np.linspace(0, 1, soft)[:, None]
    clip[-soft:] *= np.linspace(1, 0, soft)[:, None]
    return clip


def voice_clip(line: Line) -> np.ndarray:
    return _voice_clip(line.who, line.spoken(), line.cut, line.tight)


def cues() -> list[tuple[Path, float, float]]:
    """(sound, trailer time, gain): effects laid in by hand. The trailer's
    own are in trailer/audio/, the game's in assets/audio/."""
    out = [
        (AUDIO / "pan.wav", BAND - 0.03, 0.6),
        (AUDIO / "printer.wav", bar(2.75), 0.35),
        (GAME_AUDIO / "sting.wav", bar(7), 0.5),
        (AUDIO / "bell.wav", bar(11.5), 0.45),
        (AUDIO / "bell.wav", bar(14.5), 0.45),
        (AUDIO / "printer.wav", STOP + 0.05, 0.6),
        (AUDIO / "printer.wav", STOP + 2.6, 0.45),
        (AUDIO / "pan.wav", BACK - 0.03, 0.45),
        (AUDIO / "sting.wav", LAST_HIT, 0.5),
        (AUDIO / "bell.wav", LAST_HIT + 6.6, 0.4),
    ]
    for k in range(len(RUN)):
        out.append((GAME_AUDIO / "win.wav", bar(21.75) + k * BEAT, 0.5))
    return out


# --- Rendering and sound --------------------------------------------------------

def render_frame(shots: list[Shot], t: float) -> Image.Image:
    shot = next((s for s in shots if s.start <= t < s.end), shots[-1])
    if shot.draw is not None:
        img = shot.draw(t)
    else:
        img = capture(shot.cap, shot.frame_at(t)).copy()
    for fx in shot.fx:
        img = fx(img, t)
    return img


def write_video(shots: list[Shot], total_s: float, path: Path) -> None:
    command = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{CW}x{CH}", "-r", str(FPS), "-i", "-", "-c:v", "ffv1", "-pix_fmt", "bgr0", str(path)]
    proc = subprocess.Popen(command, stdin=subprocess.PIPE)
    total = int(round(total_s * FPS))
    for n in range(total):
        proc.stdin.write(render_frame(shots, n / FPS).tobytes())
        if n % 600 == 0:
            print(f"frame {n}/{total}", flush=True)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed while writing the native video")


def soft_edges(clip: np.ndarray, seconds: float) -> np.ndarray:
    clip = clip.copy()
    n = min(int(seconds * RATE), len(clip) // 2)
    ramp = np.linspace(0, 1, n)[:, None]
    clip[:n] *= ramp
    clip[-n:] *= ramp[::-1]
    return clip


def mix_audio(shots: list[Shot], total_s: float, path: Path) -> None:
    n = int(total_s * RATE)
    # The cue: the first half of its sparse bars, then all of it from the
    # top of the sparse bars, so the band lands on BAND.
    score = load_audio(AUDIO / f"{CUE}.wav")

    def at(seconds: float) -> int:
        return int(seconds * RATE)
    lead = BAND - (CUE_BAND - CUE_SPARSE)  # 4 s: where the full pass of the sparse bars starts
    music = np.zeros((n, 2), np.float32)
    dq.place(music, soft_edges(score[at(CUE_SPARSE):at(CUE_SPARSE + lead)], 0.02), 0.0, 1.0)
    body = score[at(CUE_SPARSE):at(CUE_END)].copy()
    tail = at(0.4)
    body[-tail:] *= np.linspace(1, 0, tail)[:, None]
    body[:at(0.02)] *= np.linspace(0, 1, at(0.02))[:, None]
    dq.place(music, body, lead, 1.0)
    # The captures' own sound: chips, the fire, the plates, the order-up.
    game = np.zeros((n, 2), np.float32)
    for shot in shots:
        if shot.src is None or shot.audio <= 0 or shot.speed != 1.0:
            continue
        source = load_capture_audio(shot.cap)
        a = int(shot.src / FPS * RATE)
        clip = source[a:a + int((shot.end - shot.start) * RATE)]
        if len(clip) > RATE // 10:
            dq.place(game, soft_edges(clip, 0.01), shot.start, shot.audio * 0.7)
    sfx = np.zeros((n, 2), np.float32)
    for source, when, gain in cues():
        dq.place(sfx, load_audio(source), when, gain)
    talk = np.zeros((n, 2), np.float32)
    for line in voices():
        dq.place(talk, voice_clip(line), line.at, line.gain)
    # The music drops under a voice, and a little under the effects.
    window = np.ones(4800) / 4800
    spoken = np.convolve(np.abs(talk).max(axis=1), window, mode="same")
    hits = np.convolve(np.abs(game * 2.5 + sfx).max(axis=1), window, mode="same")
    duck = (1.0 - np.clip(spoken * 14.0, 0.0, 0.6)) * (1.0 - np.clip(hits * 2.0, 0.0, 0.3))
    game = 0.6 * np.tanh(game * 2.5 / 0.6)
    mix = music * 0.75 * duck[:, None] + game + sfx * 0.8 + talk * 1.25
    end = int(1.2 * RATE)
    mix[-end:] *= np.linspace(1, 0, end)[:, None]
    peak = np.abs(mix).max()
    if peak > 0.98:
        mix *= 0.98 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())


@lru_cache(maxsize=None)
def load_capture_audio(cap: str) -> np.ndarray:
    return dq.load_wav(CAPTURES / cap / "f.wav")


def encode(native: Path, audio: Path, scale: int, out: Path, crf: int) -> None:
    """Whole-number nearest-neighbor upscale of the 1920x1080 master to H.264
    + AAC, YouTube/Steam friendly."""
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(native), "-i", str(audio),
               "-vf", f"scale={CW * scale}:{CH * scale}:flags=neighbor",
               "-c:v", "libx264", "-preset", "slow", "-crf", str(crf), "-pix_fmt", "yuv420p",
               "-tune", "animation", "-r", str(FPS), "-c:a", "aac", "-b:a", "320k", "-ar", str(RATE),
               "-shortest", "-movflags", "+faststart", str(out)]
    subprocess.run(command, check=True)
    print(f"WROTE {out.relative_to(ROOT.parent)}", flush=True)


## The line the thumbnail shows: the one the last ticket is sent with.
THUMB_LINE = "cut -d, -f2 flood.csv | sort | uniq -c | sort -rn | head -n 1"


def thumbnail(path: Path) -> None:
    """A 1920x1080 YouTube thumbnail: the Chef and Shell either side of the
    name, over the kitchen, with the five-command line that answers the
    critic and what it prints."""
    img = backdrop("pass", 0.5).copy()
    sprites = ROOT / "assets" / "sprites"
    chef = Image.open(sprites / "chef.png").convert("RGBA").resize((96 * 2 * S, 96 * 2 * S), Image.NEAREST)
    shell = Image.open(sprites / "shell.png").convert("RGBA").resize((96 * 2 * S, 96 * 2 * S), Image.NEAREST)
    shell = shell.transpose(Image.FLIP_LEFT_RIGHT)
    img.paste(shell, (-20 * S, 52 * S), shell)
    img.paste(chef, (308 * S, 52 * S), chef)
    rect(img, (0, 0, W, 62), fill=STEEL_DARK)
    rect(img, (0, 62, W, 64), fill=LAMP)
    text(img, (W / 2, 1), "YES, SHELL!", TITLES, 62, LAMP, anchor="mt", shadow=BLACK, shadow_dy=2)
    text(img, (W / 2, 76), "LEARN", TITLES, 40, CREAM, outline=INK, thick=2, anchor="mt")
    text(img, (W / 2, 110), "THE SHELL", TITLES, 72, LAMP_LIGHT, outline=INK, thick=2, shadow=BLACK, shadow_dy=3,
         anchor="mt")
    # The line, and what reaches the pass.
    size = 20
    while width("$ " + THUMB_LINE, MONO, size) > W - 24:
        size -= 1
    lw = width("$ " + THUMB_LINE, MONO, size)
    box = ((W - lw) / 2 - 8, 196, (W + lw) / 2 + 8, 258)
    rect(img, (box[0] + 3, box[1] + 3, box[2] + 3, box[3] + 3), fill=BLACK)
    rect(img, box, fill=TERM, border=STEEL_LIGHT, thick=1.5)
    text(img, (box[0] + 8, 203), "$", MONO, size, GREEN_LIGHT)
    text(img, (box[0] + 8 + width("$ ", MONO, size), 203), THUMB_LINE, MONO, size, TERM_TEXT)
    text(img, (box[0] + 8, 228), "      5 fries", MONO, 26, LAMP_LIGHT)
    img.save(path, optimize=True)
    print(f"WROTE {path.relative_to(ROOT.parent)}")
    SITE_THUMB.parent.mkdir(parents=True, exist_ok=True)
    img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(SITE_THUMB, optimize=True)
    print(f"WROTE {SITE_THUMB.relative_to(REPO)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if "--thumb" in sys.argv:
        thumbnail(OUT / "shell_thumbnail.png")
        return
    shots = edit()
    total = shots[-1].end
    print(f"length {total:.2f}s")
    for at, name in chapters():
        print(f"CHAPTER {int(at) // 60}:{int(at) % 60:02d} {name}")
    if "--stills" in sys.argv:
        sheet = Image.new("RGB", (W * 4, H * ((len(shots) + 3) // 4)), "black")
        for k, shot in enumerate(shots):
            mid = min(shot.end - 1 / FPS, shot.start + (shot.end - shot.start) * 0.7)
            img = render_frame(shots, mid)
            text(img, (2, 2), f"{k} {shot.label} {shot.start:.1f}", MONO, 16, (255, 0, 255))
            sheet.paste(img.resize((W, H), Image.LANCZOS), ((k % 4) * W, (k // 4) * H))
        sheet.save(OUT / "stills.png")
        print(f"WROTE {(OUT / 'stills.png').relative_to(ROOT.parent)}")
        for shot in shots:
            print(f"{shot.start:6.2f}-{shot.end:6.2f} {shot.label} {shot.cap} src={shot.src} x{shot.speed:.2f}")
        for line in voices():
            print(f"VOICE {line.at:6.2f}-{line.at + len(voice_clip(line)) / RATE:6.2f} {line.who}: {line.words[:50]}")
        return
    if "--at" in sys.argv:
        times = [float(a) for a in sys.argv[sys.argv.index("--at") + 1:]]
        tw, th = (CW, CH) if len(times) == 1 else (CW // 2, CH // 2)
        sheet = Image.new("RGB", (tw * 2 if len(times) > 1 else tw, th * ((len(times) + 1) // 2)), "black")
        for k, t in enumerate(times):
            sheet.paste(render_frame(shots, t).resize((tw, th), Image.LANCZOS), ((k % 2) * tw, (k // 2) * th))
        sheet.save(OUT / "at.png")
        print(f"WROTE {(OUT / 'at.png').relative_to(ROOT.parent)}")
        return
    native = OUT / "native.mkv"
    if "--audio-only" not in sys.argv or not native.exists():
        write_video(shots, total, native)
    mix_audio(shots, total, OUT / "mix_raw.wav")
    dq.normalize(OUT / "mix_raw.wav", OUT / "mix.wav")
    encode(native, OUT / "mix.wav", 1, OUT / "shell_trailer_1080p.mp4", 12)
    if "--no-4k" not in sys.argv:
        encode(native, OUT / "mix.wav", 2, OUT / "shell_trailer_4k.mp4", 16)
    thumbnail(OUT / "shell_thumbnail.png")


if __name__ == "__main__":
    main()
