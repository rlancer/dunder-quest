"""Cut The Good, the Bad and the Greedy's trailer from Movie Maker captures of the bot.

A fast run of highlights on the beat of one original cue (twangy guitar, a
whistle, trumpet, jaw harp): the band in the desert while the old-timer says
who they are, the title as the band gallops in, the town where everybody is
a Hobson, Dot Starr riding in, then a card at a time ("A wanted poster is a
pattern.") between the moments that teach: a poster written chip by chip
with the line-up lighting up, the draw and the CAUGHT banner, a run of
banners a beat each, Big Backtrack in the cue's dead stop and his count
doubling through the build, greedy against lazy, Dot caught by her own
`.*`, and an end card with the URL and one last joke. It doesn't play the
game through. The voices are the game's own clips (assets/voice/), laid in
here rather than taken from the captures, so a line can be trimmed to the
sentence that lands.

Shots are laid out in the game's native 480x270 units but composed at
1920x1080 (`S` times that), so text is sharp: the game draws its text at
window resolution and is captured at 1920x1080 (`trailer/capture.sh`), and
the trailer's own cards are drawn at full size too. The pixel art stays on
whole-number nearest-neighbor scales. The mixing and encoding helpers come
from the Dunder Quest trailer (../../dunder-quest/tools/make_trailer.py).

The cue (`trailer/audio/cue_greedy.wav`, from tools/trailer_audio.py) was
measured at 120 BPM. In cue time: four seconds of nothing, a sparse whistle
from 4.07 s, the band in on 8.07, a dead stop from 40.3 to 44.0, a quiet
build to 48.07, the full band again, and the last hit on 61.57. The trailer
plays the sparse four seconds twice (the old-timer needs eight), so trailer
time is cue time less 0.07 s from the band's entry on: the band comes in at
8 s, beats every half second from there, bars of four. Every cut lands on
one. The sparse bars come back, twice over, as a tag under the end card.

Shots find their capture frames by name in the MARK logs
(`trailer/captures/<name>.log`), so a fresh capture needs no renumbering.
Needs ffmpeg on the PATH.

    bash trailer/capture.sh                 # -> trailer/captures/{open,j1..j5}/ + logs, at 1920x1080
    python tools/make_trailer.py            # -> trailer/out/greedy_trailer_{1080p,4k}.mp4 + greedy_thumbnail.png
    python tools/make_trailer.py --stills   # one frame per shot, for checking the cut
    python tools/make_trailer.py --at 3 12.5   # frames at those trailer times
    python tools/make_trailer.py --thumb    # just the thumbnail (also copied to the site)
    python tools/make_trailer.py --audio-only   # remix over the video already rendered
"""

from __future__ import annotations

import hashlib
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
SITE_THUMB = REPO / "site" / "static" / "img" / "greedy" / "trailer.png"
RYE = ROOT / "assets" / "fonts" / "Rye.ttf"
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

# The game's palette (core/palette.gd), as 8-bit RGB.
INK = (41, 23, 15)
PAPER = (237, 217, 166)
PAPER_DARK = (201, 179, 125)
WOOD = (92, 56, 33)
WOOD_DARK = (56, 33, 20)
GOLD = (232, 161, 59)
GOLD_LIGHT = (255, 214, 115)
RED = (163, 38, 28)
RED_LIGHT = (230, 87, 61)
CREAM = (255, 237, 194)
NIGHT = (23, 15, 13)
BLACK = (0, 0, 0)

# --- The cue -----------------------------------------------------------------

CUE = "cue_greedy"
BEAT = 0.5
## Cue time of the sparse opening's first beat, and of the band's entry.
CUE_SPARSE = 4.07
CUE_BAND = 8.07
## Trailer time the band comes in: the sparse four seconds, twice.
BAND = 8.0
## Where the cue's last hit has rung out, in cue time.
CUE_END = 62.6
## Trailer times of the cue's landmarks.
STOP = 40.5      # the band is gone (its last chord dies at 40.25)
BUILD = 44.0     # a quiet build starts
BACK = 48.0      # the full band again
LAST_HIT = 61.5
## How long the end card runs, with the tag and the last joke under it.
END_HOLD = 7.0


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

def flash_fx(at: float, frames: int = 4, peak: float = 0.8, color=(255, 240, 200)):
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


def label_fx(word: str, pattern: str, at: float):
    """A wooden sign over the desk's brief: a word in Rye and the pattern it's about."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        if t < at:
            return img
        out = img.copy()
        box = (96, 17, 384, 65)
        rect(out, box, fill=WOOD_DARK, border=GOLD, thick=2)
        ww = width(word, RYE, 28)
        pw = width(pattern, MONO, 30) + 14
        x = (W - (ww + 14 + pw)) / 2
        text(out, (x, 25), word, RYE, 28, GOLD_LIGHT, shadow=BLACK, shadow_dy=2)
        rect(out, (x + ww + 14, 27, x + ww + 14 + pw, 57), fill=PAPER)
        text(out, (x + ww + 21, 27), pattern, MONO, 30, RED)
        return out
    return fx


# --- Cards ----------------------------------------------------------------------

def card(lines: list[str], size: float = 26, place: str = "desert", dark: float = 0.78):
    """A card over one of the game's backdrops at dusk: Rye lines, centered,
    the last in gold. A line that starts with ` is a pattern, on its paper."""
    def draw(_t: float) -> Image.Image:
        img = backdrop(place, dark).copy()
        fitted = []
        for s in lines:
            code = s.startswith("`")
            s = s.lstrip("`")
            path = MONO if code else RYE
            px = size * (1.25 if code else 1.0)
            while width(s, path, px) > W - 48:
                px -= 1
            fitted.append((s, code, path, px))
        step = size * 1.5
        y = (H - step * len(lines)) / 2 + 2
        for k, (s, code, path, px) in enumerate(fitted):
            if code:
                w = width(s, path, px) + 16
                rect(img, ((W - w) / 2, y - 2, (W + w) / 2, y + px + 1), fill=PAPER, border=PAPER_DARK)
                text(img, (W / 2, y - 1), s, path, px, RED, anchor="mt")
            else:
                color = GOLD_LIGHT if k == len(lines) - 1 else CREAM
                text(img, (W / 2, y), s, path, px, color, anchor="mt", shadow=BLACK, shadow_dy=2)
            y += step
        return img
    return draw


def name_block(img: Image.Image, top: float) -> None:
    """The game's name, centered, in its gold slab letters."""
    text(img, (W / 2, top), "The Good, the Bad", RYE, 30, CREAM, anchor="mt", shadow=BLACK, shadow_dy=2)
    text(img, (W / 2, top + 36), "and the", RYE, 16, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
    text(img, (W / 2, top + 52), "GREEDY", RYE, 68, GOLD, anchor="mt", shadow=BLACK, shadow_dy=3)


def title_card(_t: float) -> Image.Image:
    img = backdrop("title", 0.5).copy()
    name_block(img, 62)
    return img


def end_card(at: float):
    def draw(t: float) -> Image.Image:
        img = backdrop("title", 0.62).copy()
        local = t - at
        name_block(img, 18)
        if local >= 0.9:
            text(img, (W / 2, 150), "Learn regex.", MONO, 30, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
        if local >= 1.7:
            text(img, (W / 2, 186), "Play free in your browser", PIXEL, 11, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
            text(img, (W / 2, 198), "dunderquest.com/greedy", MONO, 34, GOLD_LIGHT, anchor="mt", shadow=BLACK, shadow_dy=2)
        if local >= 2.5:
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


## The banners in the run of catches, a beat each: capture, poster.
RUN = (("j2", "2a"), ("j2", "2d"), ("j3", "3a"), ("j3", "3d"), ("j4", "4d"))
## Capture seconds of Big Backtrack's card the count runs over, shown in four.
COUNT_FROM, COUNT_SPAN = 0.6, 8.8


def edit() -> list[Shot]:
    shots: list[Shot] = []

    def add(start: float, end: float, **kw) -> Shot:
        shot = Shot(start, end, **kw)
        shots.append(shot)
        return shot

    # The sparse bars: the band, standing in the desert.
    add(0.0, BAND, cap="open", src=mark("open", "page 0"), label="the band", fx=[fade_in_fx(0.0, 0.6)])
    # The band gallops in on the name.
    add(BAND, bar(5), draw=title_card, label="title", fx=[flash_fx(BAND, 5, 0.8)])
    # A town called Hobson.
    add(bar(5), bar(7.5), cap="j1", src=said("j1", "Everybody in this town") - 2, label="hobson")
    # Dot Starr rides in, and takes everything on the line.
    add(bar(7.5), bar(8.5), cap="open", src=mark("open", "page 3") + 8, label="dot rides in",
        fx=[flash_fx(bar(7.5), 4, 0.6, RED_LIGHT)])
    add(bar(8.5), bar(11), cap="open", src=mark("open", "page 4"), label="dot takes it")
    add(bar(11), bar(12), draw=card(["Nobody shoots anybody.", "The law is a wanted poster."], 24), label="card law")
    add(bar(12), bar(13), draw=card(["A wanted poster", "is a pattern."], 32), label="card pattern")
    # H.nk, a chip at a time, the draw, and the banner.
    add(bar(13), bar(15.5), cap="j1", src=mark("j1", "write 1b") - 20, audio=1.0, label="write H.nk")
    # The Mayor would like a word about the church organists.
    add(bar(15.5), bar(18), cap="j1", src=mark("j1", "write 1c") - 20, audio=0.8, label="the organists")
    add(bar(18), bar(19), draw=card(["`H[ao]nk", "That's a regular expression."], 24), label="card regex")
    # A run of catches, a beat each.
    for k, (cap, poster) in enumerate(RUN):
        at = bar(19) + k * BEAT
        add(at, at + BEAT, cap=cap, src=mark(cap, f"caught {poster}") + 30, label=f"caught {poster}",
            fx=[flash_fx(at, 3, 0.45)])
    # The cue stops dead. Big Backtrack doesn't.
    add(bar(19) + len(RUN) * BEAT, bar(23), cap="j5", src=said("j5", "Backtrack try every way") - 2, label="backtrack")
    # His count, doubling through the build and into the band's return.
    count = mark("j5", "card catastrophic")
    add(bar(23), bar(25), cap="j5", src=count + round(COUNT_FROM * FPS), speed=COUNT_SPAN / 4.0, label="the count",
        fx=[shake_fx(BACK, 3, 0.4), shake_fx(bar(25) - 0.5, 4, 0.5)])
    # Greedy, and lazy.
    add(bar(25), bar(26.5), cap="j4", src=said("j4", "I don't take a little") + round(5.5 * FPS), label="dot greedy",
        fx=[flash_fx(bar(25), 4, 0.6)])
    add(bar(26.5), bar(27.5), cap="j4", src=mark("j4", "draw 4a") - 6, audio=0.9, label="greedy",
        fx=[label_fx("GREEDY", '".*"', bar(26.5))])
    add(bar(27.5), bar(28.5), cap="j4", src=mark("j4", "draw 4b") - 6, audio=0.9, label="lazy",
        fx=[label_fx("LAZY", '".*?"', bar(27.5))])
    # Dot Starr, caught by her own dot and star, objecting.
    write = mark("j5", "write 5c")
    caught = mark("j5", "caught 5c")
    length = bar(29.75) - bar(28.5)
    add(bar(28.5), bar(29.75), cap="j5", src=write + 20, speed=(caught + 45 - write - 20) / (length * FPS), label="catch dot")
    add(bar(29.75), LAST_HIT, draw=card(["Five jobs. Every line voiced.", "Real regex."], 24, "saloon"), label="card five")
    add(LAST_HIT, LAST_HIT + END_HOLD, draw=end_card(LAST_HIT), label="end card", fx=[flash_fx(LAST_HIT, 5, 0.7)])
    return shots


def chapters() -> list[tuple[float, str]]:
    """YouTube chapters (each at least 10 s long), for the video description."""
    return [(0.0, "The band, and a town called Hobson"), (bar(7.5), "Dot Starr rides in"),
            (bar(13), "A wanted poster is a pattern"), (bar(19) + len(RUN) * BEAT, "Big Backtrack"),
            (bar(25), "The greedy and the lazy")]


# --- The voices -------------------------------------------------------------------

def voice_key(who: str, words: str) -> str:
    """The clip's name, as core/voice.gd makes it."""
    return f"{who}_{hashlib.md5((who + '|' + words).encode()).hexdigest()[:10]}"


@dataclass
class Line:
    """A voice clip laid into the trailer at `at`: `cut` is the part of it
    used, in seconds; `tight` closes its pauses up to that many seconds."""
    at: float
    who: str
    words: str
    cut: tuple[float, float] | None = None
    tight: float = 0.0
    gain: float = 1.0


def voices() -> list[Line]:
    hobson = bar(5) + 2 / FPS
    stationery = hobson + (said("j1", "It keeps the stationery") - said("j1", "Everybody in this town")) / FPS
    return [
        Line(0.25, "narrator", "The West, eighteen seventy-something. That's the band. They go wherever the story goes, "
             "and nobody is sure who's paying them.", tight=0.14),
        Line(hobson, "sheriff", "Everybody in this town is named Hobson?"),
        Line(stationery, "mayor", "It keeps the stationery simple."),
        Line(bar(7.5) + 0.1, "narrator", "Then Dot Starr rode in. Dot, as in anything at all. Star, as in as much of it "
             "as she pleases.", cut=(0.0, 2.0)),
        Line(bar(8.5) + 0.15, "dot", "I'll take the bank. And the feed store. And everything else on the line."),
        Line(bar(15.5) + 0.05, "mayor", "Sheriff! You've arrested Hunk and Hink. They're the church organists! It's only "
             "Hank and Honk we want.", cut=(0.0, 4.33)),
        Line(STOP + 0.15, "backtrack", "Backtrack try every way. Then Backtrack go back. Try every other way.", tight=0.2),
        Line(bar(25) + 0.05, "dot", "I don't take a little. I take everything on the line, right up to the last place I "
             "can stop. They call it greedy. I call it thorough.", cut=(5.8, 9.0)),
        Line(bar(28.5) + 0.1, "dot", "You can't hold me, Sheriff. I match everything!"),
        Line(LAST_HIT + 2.0, "sheriff", "That's the lot of them."),
        Line(LAST_HIT + 3.75, "kid", "For the record, that one was the horse."),
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


def voice_clip(line: Line) -> np.ndarray:
    path = VOICE / f"{voice_key(line.who, line.words)}.ogg"
    if not path.exists():
        sys.exit(f"no voice clip for {line.who}: {line.words[:40]}")
    clip = load_audio(path)
    if line.cut is not None:
        clip = clip[int(line.cut[0] * RATE):int(line.cut[1] * RATE)].copy()
    if line.tight > 0:
        clip = tightened(clip, line.tight)
    soft = int(0.03 * RATE)
    clip = clip.copy()
    clip[:soft] *= np.linspace(0, 1, soft)[:, None]
    clip[-soft:] *= np.linspace(1, 0, soft)[:, None]
    return clip


def cues() -> list[tuple[Path, float, float]]:
    """(sound, trailer time, gain): effects laid in by hand. The trailer's
    own are in trailer/audio/, the game's in assets/audio/."""
    out = [
        (AUDIO / "whip.wav", BAND - 0.06, 0.7),
        (GAME_AUDIO / "sting.wav", bar(7.5), 0.6),
        (AUDIO / "whip.wav", bar(11) - 0.06, 0.5),
        (AUDIO / "whip.wav", bar(12) - 0.06, 0.5),
        (AUDIO / "whip.wav", bar(18) - 0.06, 0.5),
        (GAME_AUDIO / "thud.wav", STOP, 0.9),
        (AUDIO / "boom.wav", bar(25) - 0.05, 0.6),
        (AUDIO / "ricochet.wav", bar(29.75) - 0.25, 0.5),
        # Two cracks to count the last hit in.
        (AUDIO / "whip.wav", LAST_HIT - 1.06, 0.45),
        (AUDIO / "whip.wav", LAST_HIT - 0.56, 0.55),
        (AUDIO / "sting.wav", LAST_HIT, 0.5),
        (GAME_AUDIO / "toot.wav", LAST_HIT + 3.2, 0.9),
    ]
    for k in range(len(RUN)):
        out.append((GAME_AUDIO / "shot.wav", bar(19) + k * BEAT, 0.55))
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
    # The cue: its sparse bars twice, the rest as written, and the sparse
    # bars again, quietly, as a tag under the end card.
    score = load_audio(AUDIO / f"{CUE}.wav")
    def at(seconds: float) -> int:
        return int(seconds * RATE)
    lead = BAND - (CUE_BAND - CUE_SPARSE)  # 4 s: where the second pass of the sparse bars starts
    sparse_end = at(CUE_BAND - 0.07)
    music = np.zeros((n, 2), np.float32)
    dq.place(music, soft_edges(score[at(CUE_SPARSE):sparse_end], 0.02), 0.0, 1.0)
    dq.place(music, soft_edges(score[at(CUE_SPARSE - 0.07):sparse_end], 0.02), lead - 0.07, 1.0)
    body = score[sparse_end:at(CUE_END)].copy()
    tail = at(0.4)
    body[-tail:] *= np.linspace(1, 0, tail)[:, None]
    dq.place(music, body, BAND - 0.07, 1.0)
    tag = score[at(CUE_SPARSE):sparse_end].copy()
    tag[:at(0.3)] *= np.linspace(0, 1, at(0.3))[:, None]
    for k in range(2):
        dq.place(music, tag, LAST_HIT + 0.9 + k * len(tag) / RATE, 0.8)
    # The captures' own sound: chips, the draw, the verdicts.
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
    duck = (1.0 - np.clip(spoken * 14.0, 0.0, 0.62)) * (1.0 - np.clip(hits * 2.0, 0.0, 0.3))
    game = 0.6 * np.tanh(game * 2.5 / 0.6)
    mix = music * 0.7 * duck[:, None] + game + sfx * 0.8 + talk * 1.25
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


def thumbnail(path: Path) -> None:
    """A 1920x1080 YouTube thumbnail: the Sheriff and Dot Starr either side
    of the name, over the town, with the poster that catches her."""
    img = backdrop("title", 0.45).copy()
    sprites = ROOT / "assets" / "sprites"
    sheriff = Image.open(sprites / "sheriff.png").convert("RGBA").resize((96 * 2 * S, 96 * 2 * S), Image.NEAREST)
    dot = Image.open(sprites / "dot.png").convert("RGBA").resize((96 * 2 * S, 96 * 2 * S), Image.NEAREST)
    img.paste(sheriff, (-22 * S, 82 * S), sheriff)
    img.paste(dot, (310 * S, 82 * S), dot)
    rect(img, (0, 0, W, 64), fill=WOOD_DARK)
    rect(img, (0, 64, W, 66), fill=GOLD)
    text(img, (W / 2, 3), "The Good, the Bad and the", RYE, 20, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
    text(img, (W / 2, 22), "GREEDY", RYE, 40, GOLD, anchor="mt", shadow=BLACK, shadow_dy=2)
    text(img, (W / 2, 84), "LEARN", RYE, 30, CREAM, outline=INK, thick=2, anchor="mt")
    text(img, (W / 2, 114), "REGEX", RYE, 62, GOLD_LIGHT, outline=INK, thick=2, shadow=BLACK, shadow_dy=3, anchor="mt")
    # The poster that catches her.
    pattern = "^D.* Starr$"
    pw = width(pattern, MONO, 34)
    box = ((W - pw) / 2 - 16, 196, (W + pw) / 2 + 16, 256)
    rect(img, (box[0] + 3, box[1] + 3, box[2] + 3, box[3] + 3), fill=BLACK)
    rect(img, box, fill=PAPER, border=PAPER_DARK, thick=2)
    text(img, (W / 2, 199), "WANTED", RYE, 16, RED, anchor="mt")
    text(img, (W / 2, 219), pattern, MONO, 34, INK, anchor="mt")
    img.save(path, optimize=True)
    print(f"WROTE {path.relative_to(ROOT.parent)}")
    SITE_THUMB.parent.mkdir(parents=True, exist_ok=True)
    img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(SITE_THUMB, optimize=True)
    print(f"WROTE {SITE_THUMB.relative_to(REPO)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if "--thumb" in sys.argv:
        thumbnail(OUT / "greedy_thumbnail.png")
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
            print(f"{shot.start:6.2f}-{shot.end:6.2f} {shot.label} {shot.cap} src={shot.src}")
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
    encode(native, OUT / "mix.wav", 1, OUT / "greedy_trailer_1080p.mp4", 12)
    if "--no-4k" not in sys.argv:
        encode(native, OUT / "mix.wav", 2, OUT / "greedy_trailer_4k.mp4", 16)
    thumbnail(OUT / "greedy_thumbnail.png")


if __name__ == "__main__":
    main()
