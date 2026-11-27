"""Cut A Game About Nothing's trailer from Movie Maker captures of the bot.

A fast run of highlights on the beat of one original cue (a slapped bass,
finger snaps, a light funk band): Stu on stage at the Rimshot noticing that
the whole internet is people asking for things, while a request writes
itself out and a 200 comes back; the name as the band comes in; the 404 and
Lenny, who wanted the soup; then a card at a time ("Every errand is an HTTP
request.") between the moments that teach: a request slip made card by card
and a 201 Created, the broth counter answering a wrong Content-Type with
`{"error":"Next!"}`, a run of status lines a beat each, and then the cue
drops to nearly nothing for Stu's bit on DELETE and 204 No Content. The band
comes back for the post office's 412, the network's PATCH with a token, a
version and a body, Mr. Pratt's one laugh, and an end card with the URL and
one last joke. It doesn't play the game through. The voices are the game's
own clips (assets/voice/), laid in here rather than taken from the
captures, so a line can be trimmed to the sentence that lands.

Shots are laid out in the game's native 480x270 units but composed at
1920x1080 (`S` times that), so text is sharp: the game draws its text at
window resolution and is captured at 1920x1080 (`trailer/capture.sh`), and
the trailer's own cards are drawn at full size too. The pixel art stays on
whole-number nearest-neighbor scales. The mixing and encoding helpers come
from the Dunder Quest trailer (../../dunder-quest/tools/make_trailer.py).

The cue (`trailer/audio/cue_nothing.wav`, from tools/trailer_audio.py) was
measured at 120 BPM, its first note at 0.18 s. The trailer starts 0.32 s
before the cue does, so that note is on 0.5 s and every beat after it is on
a half second. In trailer time: the bass alone, with finger snaps, until a
drum fill at 7.6 s; the band in on 8.5; a breath from 22.6 and a slam on
24.0; the band's last hit on 38.5, then eight seconds of almost nothing
(a snap a second, and one lone hit on 40.0); the band back on 47.0; a bass
tag from 60.6; and the last hit on 63.0. Every cut lands on a beat. The
opening's solo bass comes back, quietly, as a tag under the end card.

Shots find their capture frames by name in the MARK logs
(`trailer/captures/<name>.log`), so a fresh capture needs no renumbering.
Needs ffmpeg on the PATH.

    bash trailer/capture.sh                 # -> trailer/captures/{open,e1..e5}/ + logs, at 1920x1080
    python tools/make_trailer.py            # -> trailer/out/nothing_trailer_{1080p,4k}.mp4 + nothing_thumbnail.png
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
SITE_THUMB = REPO / "site" / "static" / "img" / "nothing" / "trailer.png"
TITLES = ROOT / "assets" / "fonts" / "Righteous.ttf"
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
INK = (28, 20, 33)
PAPER = (247, 240, 219)
PAPER_DARK = (219, 209, 184)
PLUM = (61, 43, 77)
PLUM_DARK = (33, 23, 43)
MUSTARD = (232, 176, 59)
MUSTARD_LIGHT = (255, 217, 128)
TEAL = (33, 128, 128)
TEAL_LIGHT = (128, 219, 209)
BRICK = (181, 69, 46)
BRICK_LIGHT = (242, 128, 97)
GREEN_LIGHT = (128, 224, 148)
CREAM = (252, 245, 227)
GLASS = (18, 13, 26)
GLASS_TEXT = (224, 219, 242)
NIGHT = (13, 8, 18)
BLACK = (0, 0, 0)

# --- The cue -----------------------------------------------------------------

CUE = "cue_nothing"
BEAT = 0.5
## The trailer starts this long before the cue does, which puts the cue's
## beats (the first at 0.18 s) on the trailer's half seconds.
LEAD = 0.32
## Trailer times of the cue's landmarks.
BAND = 8.5       # the band comes in, after a fill
SLAM = 24.0      # the band slams back after a breath
STOP = 38.5      # the band's last hit before the eight seconds of nearly nothing
LONE = 40.0      # one lone hit in the nothing
BACK = 47.0      # the band again
TAG = 60.5       # the band's last downbeat; a bass tag follows
LAST_HIT = 63.0
## The cue's solo bass opening, in cue time: it comes back under the end card.
CUE_SOLO = (0.1, 6.5)
## How long the end card runs, with the tag and the last joke under it.
END_HOLD = 7.5


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
         anchor: str = "lt", outline=None, thick: float = 1, shadow=None, shadow_dy: float = 0,
         shadow_dx: float = 0) -> None:
    """`s` antialiased at full resolution; `xy`, `size`, `thick` and the
    shadow's offset are in native pixels. `anchor` is 'lt', 'mt' or 'rt'."""
    fnt = font(path, round(size * S))
    x, y = xy[0] * S, xy[1] * S
    pil_anchor = {"lt": "la", "mt": "ma", "rt": "ra"}[anchor]
    d = ImageDraw.Draw(img)
    stroke = round(thick * S) if outline is not None else 0
    if shadow is not None and (shadow_dy or shadow_dx):
        d.text((x + shadow_dx * S, y + shadow_dy * S), s, font=fnt, fill=shadow, anchor=pil_anchor,
               stroke_width=stroke, stroke_fill=shadow)
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


def fade_in_fx(at: float, length: float = 0.5):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) / length
        return Image.blend(Image.new("RGB", img.size, BLACK), img, max(k, 0.0)) if k < 1 else img
    return fx


def status_fx(line: str, at: float, color=GREEN_LIGHT):
    """A status line, big, on the counter's dark glass, across the top of
    the desk: for a shot too short to read the response in."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        if t < at:
            return img
        out = img.copy()
        size = 40
        wide = width(line, MONO, size) + 28
        box = ((W - wide) / 2, 12, (W + wide) / 2, 60)
        rect(out, (box[0] + 3, box[1] + 3, box[2] + 3, box[3] + 3), fill=BLACK)
        rect(out, box, fill=GLASS, border=MUSTARD, thick=2)
        text(out, (W / 2, 16), line, MONO, size, color, anchor="mt")
        return out
    return fx


# --- Cards ----------------------------------------------------------------------

def card(lines: list[str], size: float = 26, place: str = "club", dark: float = 0.8):
    """A card over one of the game's backdrops with the lights down: lines
    in the titles' rounded capitals, centered, the last in mustard. A line
    that starts with ` is a line of HTTP, on its paper."""
    def draw(_t: float) -> Image.Image:
        img = backdrop(place, dark).copy()
        fitted = []
        for s in lines:
            code = s.startswith("`")
            s = s.lstrip("`")
            path = MONO if code else TITLES
            px = size * (1.2 if code else 1.0)
            while width(s, path, px) > W - 40:
                px -= 1
            fitted.append((s, code, path, px))
        step = size * 1.45
        y = (H - step * len(lines)) / 2
        for k, (s, code, path, px) in enumerate(fitted):
            if code:
                w = width(s, path, px) + 16
                rect(img, ((W - w) / 2, y - 2, (W + w) / 2, y + px + 1), fill=PAPER, border=PAPER_DARK)
                text(img, (W / 2, y - 1), s, path, px, BRICK, anchor="mt")
            else:
                color = MUSTARD if k == len(lines) - 1 else CREAM
                text(img, (W / 2, y), s, path, px, color, anchor="mt", shadow=BLACK, shadow_dy=2)
            y += step
        return img
    return draw


def name_block(img: Image.Image, top: float, big: float = 64) -> None:
    """The game's name, centered, as its title screen letters it: cream over
    mustard with a brick drop shadow."""
    text(img, (W / 2, top), "A GAME ABOUT", TITLES, big * 0.42, CREAM, anchor="mt", shadow=BLACK, shadow_dy=2)
    text(img, (W / 2, top + big * 0.46), "NOTHING", TITLES, big, MUSTARD, anchor="mt", shadow=BRICK,
         shadow_dy=3, shadow_dx=3)


def band_under(img: Image.Image, top: float, bottom: float) -> None:
    """The plum band the game's own title cards sit on, mustard-ruled."""
    shade = Image.new("RGB", (CW, round((bottom - top) * S)), PLUM_DARK)
    y = round(top * S)
    img.paste(Image.blend(img.crop((0, y, CW, y + shade.height)), shade, 0.9), (0, y))
    rect(img, (0, top, W, top + 2), fill=MUSTARD)
    rect(img, (0, bottom - 2, W, bottom), fill=MUSTARD)


def title_card(_t: float) -> Image.Image:
    img = backdrop("title", 0.25).copy()
    band_under(img, 66, 204)
    name_block(img, 84, 76)
    return img


def end_card(at: float):
    def draw(t: float) -> Image.Image:
        img = backdrop("title", 0.45).copy()
        band_under(img, 14, 256)
        local = t - at
        name_block(img, 24, 60)
        if local >= 0.75:
            text(img, (W / 2, 126), "Learn HTTP and REST APIs.", MONO, 30, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
        if local >= 1.5:
            text(img, (W / 2, 166), "Play free in your browser", PIXEL, 11, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
            text(img, (W / 2, 178), "dunderquest.com/nothing", MONO, 36, MUSTARD_LIGHT, anchor="mt", shadow=BLACK, shadow_dy=2)
        if local >= 2.25:
            text(img, (W / 2, 226), "a __dunder_quest__ game", MONO, 18, PAPER, anchor="mt", shadow=BLACK, shadow_dy=1)
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


## The status lines in the run, a beat each: capture, scene, the line.
RUN = (("e1", "1a", "200 OK"), ("e2", "2b", "201 Created"), ("e4", "4a", "304 Not Modified"),
       ("e4", "4b", "202 Accepted"))
## Where the run starts: it ends on the band's last hit.
RUN_AT = STOP - len(RUN) * BEAT
## When Stu's bit on DELETE starts, in the nothing, and the part of his set
## that's used: from "And what does it send back?" to the end.
BIT_AT = STOP + 0.2
BIT_CUT = (2.05, 11.64)
## How long into that the words "204 No Content" start: the slip goes then.
BIT_204 = 1.35


def edit() -> list[Shot]:
    shots: list[Shot] = []

    def add(start: float, end: float, **kw) -> Shot:
        shot = Shot(start, end, **kw)
        shots.append(shot)
        return shot

    # The bass alone: Stu at the Rimshot, and a request writing itself out.
    page = mark("open", "page 3")
    add(0.0, BAND, cap="open", src=page, speed=0.97, label="stu notices", fx=[fade_in_fx(0.0, 0.5)])
    # The band comes in on the name.
    add(BAND, 10.5, draw=title_card, label="title", fx=[flash_fx(BAND, 5, 0.8)])
    # It always answers with a number.
    add(10.5, 17.0, cap="open", src=mark("open", "page 4"), label="404")
    add(17.0, 20.5, cap="open", src=mark("open", "page 5"), label="the soup")
    add(20.5, 22.5, draw=card(["Every counter in New York", "is a web server."], 26, "street"), label="card counter")
    add(22.5, SLAM, draw=card(["Every errand", "is an HTTP request."], 30, "street"), label="card errand")
    # A slip, a card at a time, and a 201.
    add(SLAM, 29.5, cap="e1", src=mark("e1", "brief 1c") + 2, audio=1.0, label="post an order",
        fx=[flash_fx(SLAM, 4, 0.5)])
    # The broth counter, and its one word.
    add(29.5, 33.0, cap="e2", src=said("e2", "Know what you want") + round(4.6 * FPS), label="one word")
    add(33.0, 34.0, cap="e2", src=said("e2", "Next!") + 4, label="next")
    add(34.0, RUN_AT, cap="e2", src=mark("e2", "send 2b 0") - 30, audio=1.0, label="415 next")
    # A run of status lines, a beat each, up to the band's last hit.
    for k, (cap, scene, line) in enumerate(RUN):
        at = RUN_AT + k * BEAT
        add(at, at + BEAT, cap=cap, src=mark(cap, f"won {scene}") + 24, label=line,
            fx=[status_fx(line, at, MUSTARD_LIGHT if line.startswith("3") else GREEN_LIGHT), flash_fx(at, 3, 0.4)])
    # The band stops. DELETE, and what it sends back: nothing.
    send = mark("e3", "send 3c")
    gone = BIT_AT + BIT_204
    add(STOP, 42.0, cap="e3", src=send - round((gone - STOP) * FPS), audio=1.0, label="delete")
    add(42.0, BACK, cap="e3", src=mark("e3", "card delete") + 150, label="stu's set")
    # The band's back: the post office, and a version that's out of date.
    add(BACK, 49.0, cap="e4", src=said("e4", "Every parcel has a version") + 2, label="vernon",
        fx=[flash_fx(BACK, 4, 0.6)])
    add(49.0, 50.5, cap="e4", src=mark("e4", "send 4c 0") - 12, audio=1.0, label="412")
    # The network.
    add(50.5, 53.0, cap="e5", src=said("e5", "Our pilots are behind") + round(2.25 * FPS), label="pratt")
    start = mark("e5", "write 5d") - 6
    stop = mark("e5", "won 5d") + 50
    add(53.0, 56.0, cap="e5", src=start, speed=(stop - start) / (3.0 * FPS), label="the patch")
    add(56.0, 57.5, cap="e5", src=said("e5", "Ha.") + 2, label="ha")
    add(57.5, TAG, cap="e5", src=said("e5", "Six episodes!") + 2, label="six episodes")
    add(TAG, LAST_HIT, draw=card(["Real HTTP. Every request is checked", "against a real HTTP server."], 22, "club"),
        label="card real")
    add(LAST_HIT, LAST_HIT + END_HOLD, draw=end_card(LAST_HIT), label="end card", fx=[flash_fx(LAST_HIT, 5, 0.7)])
    return shots


def chapters() -> list[tuple[float, str]]:
    """YouTube chapters (each at least 10 s long), for the video description."""
    return [(0.0, "People asking for things"), (SLAM, "Every errand is a request"),
            (STOP, "204 No Content"), (50.5, "The network")]


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
    return [
        Line(0.7, "stu", "You ever notice the whole internet is just people asking for things? Give me the menu. "
             "Give me the weather."),
        Line(10.65, "stu", "And it always answers with a number. 200, it's OK. 404, there's nothing there."),
        Line(17.05, "lenny", "[exasperated] A number? I don't want a number! I want the soup!"),
        Line(SLAM + 0.2, "stu", "Lenny wants a toast at table 4. Put the order in, as JSON."),
        Line(29.8, "dana", "Know what you want. Say it in JSON. Step up, don't chat. Get one thing wrong and he says "
             "one word.", cut=(5.0, 7.68)),
        Line(33.1, "kasimir", "[barking, stern] Next!"),
        Line(35.55, "kasimir", "[barking, stern] Next!", gain=0.9),
        Line(BIT_AT, "stu", "DELETE gets rid of a thing. And what does it send back? 204 No Content. It worked, and "
             "there's nothing to say about it. My favourite status. It's a show about nothing.", cut=BIT_CUT,
             tight=0.22),
        Line(BACK + 0.1, "vernon", "Every parcel has a version, Lerner. Ask if it's changed, I'll tell you. Change it "
             "without saying which version you saw, and I won't.", cut=(0.0, 2.1)),
        Line(50.6, "pratt", "Our pilots are behind a login. Show me who you are, or don't come in.", cut=(2.25, 4.7)),
        Line(56.0, "pratt", "[a single, dry, surprised laugh] Ha."),
        Line(57.6, "lenny", "[ecstatic] Six episodes! Of nothing! We're geniuses!"),
        Line(LAST_HIT + 2.6, "lenny", "And anything starting with a 4?"),
        Line(LAST_HIT + 4.8, "stu", "Means it's your fault."),
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


## How far into whoosh.wav its swipe peaks: it's laid in to peak on the cut.
WHOOSH = 0.7


def cues() -> list[tuple[Path, float, float]]:
    """(sound, trailer time, gain): effects laid in by hand. The trailer's
    own are in trailer/audio/, the game's in assets/audio/."""
    out = [
        (AUDIO / "whoosh.wav", 20.5 - WHOOSH, 0.5),
        (AUDIO / "whoosh.wav", 22.5 - WHOOSH, 0.5),
        (AUDIO / "whoosh.wav", TAG - WHOOSH, 0.5),
        (GAME_AUDIO / "sting.wav", LAST_HIT + 0.05, 0.5),
        (AUDIO / "rimshot.wav", LAST_HIT + 6.2, 0.7),
    ]
    for k in range(len(RUN)):
        out.append((GAME_AUDIO / "card.wav", RUN_AT + k * BEAT, 0.6))
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

    def at(seconds: float) -> int:
        return int(seconds * RATE)

    # The cue, as written, from LEAD on; and its solo bass opening again,
    # quietly, as a tag under the end card.
    score = load_audio(AUDIO / f"{CUE}.wav")
    music = np.zeros((n, 2), np.float32)
    dq.place(music, score, LEAD, 1.0)
    tag = soft_edges(score[at(CUE_SOLO[0]):at(CUE_SOLO[1])], 0.3)
    dq.place(music, tag, LAST_HIT + 1.0 + LEAD - CUE_SOLO[0], 0.75)
    # The captures' own sound: cards going on the slip, the send, the verdict.
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
    """A 1920x1080 YouTube thumbnail: Stu and Mr. Pratt either side of the
    name, over the street, with the response the game is named for."""
    img = backdrop("title", 0.35).copy()
    sprites = ROOT / "assets" / "sprites"
    stu = Image.open(sprites / "stu.png").convert("RGBA").resize((96 * 2 * S, 96 * 2 * S), Image.NEAREST)
    pratt = Image.open(sprites / "pratt.png").convert("RGBA").resize((96 * 2 * S, 96 * 2 * S), Image.NEAREST)
    img.paste(stu, (-20 * S, 78 * S), stu)
    img.paste(pratt, (308 * S, 78 * S), pratt)
    rect(img, (0, 0, W, 76), fill=PLUM_DARK)
    rect(img, (0, 76, W, 78), fill=MUSTARD)
    text(img, (W / 2, 3), "A GAME ABOUT", TITLES, 20, CREAM, anchor="mt", shadow=BLACK, shadow_dy=1)
    text(img, (W / 2, 22), "NOTHING", TITLES, 48, MUSTARD, anchor="mt", shadow=BRICK, shadow_dy=2, shadow_dx=2)
    text(img, (W / 2, 90), "LEARN", TITLES, 26, CREAM, outline=INK, thick=2, anchor="mt")
    text(img, (W / 2, 116), "HTTP", TITLES, 64, MUSTARD_LIGHT, outline=INK, thick=2, shadow=BLACK, shadow_dy=3, anchor="mt")
    # The response it's named for.
    line = "HTTP/1.1 204 No Content"
    pw = width(line, MONO, 30)
    box = ((W - pw) / 2 - 14, 200, (W + pw) / 2 + 14, 258)
    rect(img, (box[0] + 3, box[1] + 3, box[2] + 3, box[3] + 3), fill=BLACK)
    rect(img, box, fill=GLASS, border=TEAL, thick=2)
    text(img, (W / 2, 203), "RESPONSE", PIXEL, 11, TEAL_LIGHT, anchor="mt")
    text(img, (W / 2, 220), line, MONO, 30, GREEN_LIGHT, anchor="mt")
    img.save(path, optimize=True)
    print(f"WROTE {path.relative_to(ROOT.parent)}")
    SITE_THUMB.parent.mkdir(parents=True, exist_ok=True)
    img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(SITE_THUMB, optimize=True)
    print(f"WROTE {SITE_THUMB.relative_to(REPO)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if "--thumb" in sys.argv:
        thumbnail(OUT / "nothing_thumbnail.png")
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
    encode(native, OUT / "mix.wav", 1, OUT / "nothing_trailer_1080p.mp4", 12)
    if "--no-4k" not in sys.argv:
        encode(native, OUT / "mix.wav", 2, OUT / "nothing_trailer_4k.mp4", 16)
    thumbnail(OUT / "nothing_thumbnail.png")


if __name__ == "__main__":
    main()
