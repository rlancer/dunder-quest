"""Cut the Flatmates.js trailer from a Movie Maker capture of the bot.

Played straight as a flat-share sitcom: the inner voices do the talking,
the camera sits in someone's head and stares at the other one, and the
best jokes land in the awkward silences. Everything is composed at the
game's native 480x270 and scaled by whole numbers with nearest-neighbor,
like the Dunder Quest trailer, whose drawing, mixing and encoding helpers
(../../dunder-quest/tools/make_trailer.py) this reuses.

It opens cold on room tone: Clive's and then Jazz's inner voice over a
close-up of each, until the kettle clicks off and the cue starts. After
that every cut lands on a bar or a beat of `trailer/audio/cue_flat.wav`
(123.45 BPM, first beat 0.148 s in, both measured from its onsets).

Shots find their capture frames by name in the run's MARK log
(`trailer/captures/run.log`), so a fresh capture needs no renumbering.
Needs ffmpeg on the PATH.

    godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_run.tscn > trailer/captures/run.log
    python tools/make_trailer.py            # -> trailer/out/flatmates_trailer_{1080p,4k}.mp4
    python tools/make_trailer.py --stills   # one frame per shot, for checking the cut
"""

from __future__ import annotations

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
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import make_trailer as dq  # noqa: E402
from make_trailer import draw_text, flash, font, panel, text_size  # noqa: E402

CAPTURE = ROOT / "trailer" / "captures" / "run"
LOG = ROOT / "trailer" / "captures" / "run.log"
AUDIO = ROOT / "trailer" / "audio"
OUT = ROOT / "trailer" / "out"
PIXEL = ROOT / "assets" / "fonts" / "PixelifySans.ttf"
MONO = ROOT / "assets" / "fonts" / "VT323.ttf"
TITLE_ART = ROOT / "assets" / "backgrounds" / "title.png"
GAME_SFX = ROOT / "assets" / "audio"

W, H = dq.W, dq.H
FPS = dq.FPS
RATE = dq.RATE
## The cold open runs this long before the cue comes in.
INTRO = 6.5
CUE = "cue_flat"
BEAT = 60.0 / 123.45
## The cue's soft first two bars are skipped: it comes in on bar 2, where
## the full band starts, right on the title. Bars count from the cue's start.
CUE_SKIP = 0.148 + 8 * BEAT
FIRST_BEAT = INTRO + 0.148 - CUE_SKIP

# The game's palette (core/palette.gd), as 8-bit RGB.
INK = (20, 18, 26)
PAPER = (245, 235, 214)
STEEL = (158, 168, 184)
JS = (247, 222, 31)
CLIVE = (117, 168, 250)
JAZZ = (250, 107, 97)
RED = (224, 77, 71)
GREEN = (117, 214, 128)
AMBER = (255, 178, 76)
CODE = (219, 230, 255)
CODE_BG = (26, 28, 41)
CODE_LINE = (66, 71, 102)
SYN_KEYWORD = (199, 143, 255)
SYN_STRING = (158, 230, 133)
SYN_NUMBER = (255, 168, 102)
SYN_COMMENT = (128, 138, 168)
SYN_CALL = (128, 199, 255)
TINT = {"clive": CLIVE, "jazz": JAZZ}


def beat(k: float) -> float:
    return FIRST_BEAT + k * BEAT


def bar(n: float) -> float:
    return beat(n * 4)


# --- The capture's MARK log ---------------------------------------------------

@lru_cache(maxsize=None)
def marks() -> list[tuple[int, str]]:
    out = []
    for line in LOG.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"MARK (\d+) (.*?)(?: clive=[-\d.]+,[-\d.]+ jazz=[-\d.]+,[-\d.]+)?$", line)
        if m:
            out.append((int(m.group(1)), m.group(2)))
    return out


def mark(text: str, stage: int | None = None, nth: int = 0) -> int:
    """The frame of the `nth` MARK starting with `text`, inside `stage` if given."""
    lo, hi = 0, 1 << 30
    if stage is not None:
        lo = mark(f"stage {stage}")
        nxt = [f for f, s in marks() if s == f"stage {stage + 1}"]
        hi = nxt[0] if nxt else hi
    found = [f for f, s in marks() if s.startswith(text) and lo <= f < hi]
    if len(found) <= nth:
        sys.exit(f"no MARK '{text}' #{nth} in stage {stage}")
    return found[nth]


# --- JavaScript, colored like the game's editor --------------------------------

KEYWORDS = {"const", "let", "for", "of", "await", "async", "function", "return", "if", "else", "new"}


def tokens(line: str) -> list[tuple[str, tuple]]:
    out: list[tuple[str, tuple]] = []
    i = 0
    while i < len(line):
        ch = line[i]
        if line.startswith("//", i):
            out.append((line[i:], SYN_COMMENT))
            break
        if ch in "\"'`":
            j = line.find(ch, i + 1)
            j = len(line) if j < 0 else j + 1
            out.append((line[i:j], SYN_STRING))
            i = j
            continue
        if ch.isdigit():
            j = i
            while j < len(line) and line[j].isdigit():
                j += 1
            out.append((line[i:j], SYN_NUMBER))
            i = j
            continue
        if ch.isalpha() or ch in "_$":
            j = i
            while j < len(line) and (line[j].isalnum() or line[j] in "_$"):
                j += 1
            word = line[i:j]
            if word in KEYWORDS:
                color = SYN_KEYWORD
            elif j < len(line) and line[j] == "(":
                color = SYN_CALL
            else:
                color = CODE
            out.append((word, color))
            i = j
            continue
        out.append((ch, STEEL if ch in ".;,()" else CODE))
        i += 1
    return out


def draw_js(img: Image.Image, xy: tuple[int, int], line: str, fnt, shown: int | None = None) -> int:
    x, y = xy
    visible = line if shown is None else line[:max(0, shown)]
    for word, color in tokens(visible):
        draw_text(img, (x, y), word, fnt, color)
        x += int(fnt.getlength(word))
    return x


# --- Overlays -----------------------------------------------------------------

def wrap(s: str, fnt, width: int) -> list[str]:
    lines, line = [], ""
    for word in s.split():
        trial = f"{line} {word}".strip()
        if line and fnt.getlength(trial) > width:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line]


def voice(who: str, line: str, at: float, until: float, y: int = 30, cps: float = 34, width: int = 300,
          rows: int = 0):
    """The inner voice, as the game draws it: a dark box edged in his color
    that types `Clive, thinking: ...` out a letter at a time. `rows` pads it
    taller, to cover the game's own thought box underneath."""
    tint = TINT[who]
    text_color = tuple(int(a * 0.45 + b * 0.55) for a, b in zip(tint, PAPER))
    fnt = font(PIXEL, 13)
    kicker = f"{who.capitalize()}, thinking:"
    lines = wrap(line, fnt, width - 16)
    line_h = 14

    def fx(img: Image.Image, t: float) -> Image.Image:
        if not at <= t < until:
            return img
        x0 = (W - width) // 2
        box = (x0, y, x0 + width, y + 22 + line_h * max(rows, len(lines)))
        panel(img, box, fill=(15, 13, 20), border=tint, alpha=0.88)
        draw_text(img, (x0 + 8, y + 4), kicker, font(PIXEL, 11), tint)
        left = int((t - at) * cps)
        for k, s in enumerate(lines):
            if left <= 0:
                break
            draw_text(img, (x0 + 8, y + 18 + k * line_h), s[:left], fnt, text_color)
            left -= len(s) + 1
        return img
    return fx


def caption(s: str, at: float, until: float, y: int = 226, color=PAPER, size: int = 16, x: int = W // 2):
    """A plain sitcom caption that cuts in and out, centered on `x`."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        if at <= t < until:
            draw_text(img, (x, y), s, font(PIXEL, size), color, outline=INK, thick=2, anchor="mt")
        return img
    return fx


def code_chip(line: str, at: float, until: float, y: int = 226, border=JS):
    """One line of JavaScript in an editor-colored panel that wipes open."""
    fnt = font(MONO, 18)

    def fx(img: Image.Image, t: float) -> Image.Image:
        if not at <= t < until:
            return img
        tw = int(fnt.getlength(line))
        pw, ph = tw + 18, 22
        x0 = (W - pw) // 2
        grow = min(1.0, (t - at) * 10, (until - t) * 12)
        width = int(pw * grow)
        if width < 4:
            return img
        panel(img, (x0, y, x0 + width, y + ph), fill=CODE_BG, border=border)
        if width == pw:
            draw_js(img, (x0 + 9, y + 2), line, fnt)
        return img
    return fx


def stage_slam(name: str, number: int, at: float, until: float):
    """The stop's name dropping in under a little line-map number."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        local = t - at
        if not 0 <= local < until - at:
            return img
        drop = max(0, 6 - int(local * FPS) * 2)
        draw_text(img, (W // 2, 46 - drop), f"STOP {number} OF 6", font(MONO, 16), JS, outline=INK, thick=1, anchor="mt")
        draw_text(img, (W // 2, 60 - drop), name, font(PIXEL, 26), PAPER, outline=INK, thick=2,
                  shadow=(0, 0, 0), shadow_dy=2, anchor="mt")
        return img
    return fx


def slam_lines(lines: list[tuple[str, int, tuple]], at: float, gap: float, y: int = 0):
    def fx(img: Image.Image, t: float) -> Image.Image:
        total = sum(int(size * 1.15) for _, size, _ in lines)
        top = (H - total) // 2 + y
        for k, (s, size, color) in enumerate(lines):
            local = t - (at + k * gap)
            if local >= 0:
                drop = max(0, 6 - int(local * FPS) * 2)
                draw_text(img, (W // 2, top - drop), s, font(PIXEL, size), color, outline=INK, thick=2,
                          shadow=(0, 0, 0), shadow_dy=3, anchor="mt")
            top += int(size * 1.15)
        return img
    return fx


def flash_fx(at: float, frames: int = 4, peak: float = 0.8):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) * FPS
        return flash(img, peak * (1 - k / frames)) if 0 <= k < frames else img
    return fx


def shake_fx(at: float, amount: float = 3.0, length: float = 0.25):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = t - at
        return dq.shaken(img, amount * (1 - k / length), t) if 0 <= k < length else img
    return fx


def handheld(img: Image.Image, t: float) -> Image.Image:
    """The POV camera: a slow whole-pixel drift, as if someone's holding it
    at eye level and trying not to stare."""
    dx = int(round(math.sin(t * 1.9) * 1.6 + math.sin(t * 4.3) * 0.6))
    dy = int(round(math.cos(t * 1.4) * 1.2))
    out = Image.new("RGB", img.size, INK)
    out.paste(img, (dx, dy))
    return out


def freeze_tint(img: Image.Image, t: float) -> Image.Image:
    """The sitcom freeze frame: drained and warm, a still from a bad day."""
    gray = img.convert("L").convert("RGB")
    return Image.blend(Image.blend(img, gray, 0.6), Image.new("RGB", img.size, (120, 96, 60)), 0.18)


def tape_rewind(at: float):
    """VHS rewind: tracking bands rolling up a washed-out picture, the REW
    label, and where we're rewinding to."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        local = t - at
        img = Image.blend(img, img.convert("L").convert("RGB"), 0.4)
        draw = ImageDraw.Draw(img)
        for k in range(3):
            y = int(H - (local * 340 + k * 97) % (H + 20))
            for row in range(max(0, y), min(H, y + 6)):
                shift = int(math.sin(row * 1.7 + t * 40) * 6)
                img.paste(img.crop((0, row, W, row + 1)), (shift, row))
            draw.rectangle((0, y + 2, W, y + 3), fill=(220, 220, 230))
        panel(img, (6, 12, 84, 40), fill=INK, border=PAPER)
        draw.polygon([(22, 20), (12, 26), (22, 32)], fill=PAPER)
        draw.polygon([(32, 20), (22, 26), (32, 32)], fill=PAPER)
        draw_text(img, (38, 16), "REW", font(MONO, 22), PAPER, outline=INK)
        draw_text(img, (W // 2, 120), "EARLIER THAT SATURDAY", font(PIXEL, 22), PAPER,
                  outline=INK, thick=2, anchor="mt")
        return img
    return fx


def pov_frame(who: str):
    """Peep-show corners: a soft dark vignette, stepped on whole pixels,
    and whose eyes these are."""
    @lru_cache(maxsize=1)
    def shade() -> Image.Image:
        mask = Image.new("L", (W, H), 0)
        px = mask.load()
        for y in range(H):
            for x in range(W):
                d = math.hypot((x - W / 2) / (W / 2), (y - H / 2) / (H / 2))
                px[x, y] = min(200, max(0, int((d - 0.78) * 420)) // 40 * 40)
        return mask

    def fx(img: Image.Image, t: float) -> Image.Image:
        img.paste(INK, (0, 0), shade())
        draw_text(img, (W - 10, H - 20), f"{who.upper()}'S POV", font(MONO, 16), TINT[who], anchor="rt")
        return img
    return fx


# --- Cards ----------------------------------------------------------------------

def black(_t: float) -> Image.Image:
    return Image.new("RGB", (W, H), (10, 9, 14))


@lru_cache(maxsize=None)
def title_art() -> Image.Image:
    return Image.open(TITLE_ART).convert("RGB")


def wordmark(img: Image.Image, y: int, size: int = 48) -> None:
    f = font(PIXEL, size)
    left, js = "flatmates", ".js"
    total = int(f.getlength(left + js))
    x = (W - total) // 2
    draw_text(img, (x, y), left, f, PAPER, outline=INK, thick=3, shadow=(0, 0, 0), shadow_dy=3)
    draw_text(img, (x + int(f.getlength(left)), y), js, f, JS, outline=INK, thick=3, shadow=(0, 0, 0), shadow_dy=3)


def title_card(at: float):
    def draw(t: float) -> Image.Image:
        img = dq.dim(title_art().copy(), 0.35)
        local = t - at
        if local >= 0:
            drop = max(0, 8 - int(local * FPS) * 2)
            wordmark(img, 60 - drop)
        if local >= BEAT:
            draw_text(img, (W // 2, 124), "Two flatmates. Two points of view.", font(MONO, 22), PAPER,
                      outline=INK, thick=1, anchor="mt")
        if local >= BEAT * 2:
            draw_text(img, (W // 2, 146), "One of them runs your JavaScript.", font(MONO, 22), JS,
                      outline=INK, thick=1, anchor="mt")
        return img
    return draw


def end_card(at: float):
    def draw(t: float) -> Image.Image:
        img = dq.dim(title_art().copy(), 0.5)
        local = t - at
        drop = max(0, 8 - int(max(0.0, local) * FPS) * 2)
        wordmark(img, 34 - drop)
        if local >= BEAT * 2:
            draw_text(img, (W // 2, 92), "Learn JavaScript. Mostly by accident.", font(MONO, 20), PAPER,
                      outline=INK, thick=1, anchor="mt")
        if local >= BEAT * 4:
            f = font(PIXEL, 13)
            msg = "Play free in your browser"
            tw = text_size(msg, f)[0]
            panel(img, ((W - tw) // 2 - 12, 120, (W + tw) // 2 + 12, 142), fill=CODE_BG, border=JS)
            draw_text(img, (W // 2, 124), msg, f, PAPER, anchor="mt")
        if local >= BEAT * 6:
            draw_text(img, (W // 2, 150), "dunderquest.com/flatmates", font(PIXEL, 22), JS,
                      outline=INK, thick=2, anchor="mt")
        if local >= BEAT * 8:
            draw_text(img, (W // 2, 180), "a __dunder_quest__ game", font(MONO, 18), AMBER,
                      outline=INK, thick=1, anchor="mt")
        return img
    return draw


# --- Gameplay source ------------------------------------------------------------

@lru_cache(maxsize=256)
def capture(frame: int) -> Image.Image:
    path = CAPTURE / f"f{frame:08d}.png"
    if not path.exists():
        return Image.new("RGB", (W, H), INK)
    return Image.open(path).convert("RGB")


@dataclass
class Shot:
    """`start`..`end` in trailer seconds. `src` is the capture frame shown at
    `start`; `draw` paints a card instead. `fx` paint on top, in order."""
    start: float
    end: float
    src: int | None = None
    speed: float = 1.0
    zoom: int = 1
    focus: tuple[int, int] = (240, 150)
    draw: Callable[[float], Image.Image] | None = None
    fx: list[Callable[[Image.Image, float], Image.Image]] = field(default_factory=list)
    audio: float = 1.0
    label: str = ""

    def frame_at(self, t: float) -> int:
        return int(self.src + round((t - self.start) * FPS * self.speed))


def edit() -> list[Shot]:
    shots: list[Shot] = []

    def add(start: float, end: float, **kw) -> Shot:
        shot = Shot(start, end, **kw)
        shots.append(shot)
        return shot

    s1 = mark("stage 1")
    # Cold open, in the middle of things: Jazz strums once too often, the
    # speakers come down, freeze frame, and we rewind to the morning.
    # One framing throughout, so the eye stays on the two of them.
    # Wide first, so the stage, the amps and the speaker stack all read; the
    # freeze is the one punch-in.
    add(0.0, FREEZE_AT, src=TOO_LOUD - int(FREEZE_AT * FPS), label="too loud",
        fx=[caption("BAND PRACTICE", 0.2, FREEZE_AT, y=166, color=AMBER, size=26, x=360),
            caption("Saturday, 7pm", 0.5, FREEZE_AT, y=196, color=PAPER, size=16, x=360)])
    add(FREEZE_AT, REWIND_AT, src=TOO_LOUD, speed=0.0, zoom=2, focus=FREEZE_FOCUS, audio=0.0, label="freeze",
        fx=[shake_fx(FREEZE_AT, 4, 0.3), freeze_tint, flash_fx(FREEZE_AT, 3, 0.7),
            caption("TOO LOUD!", FREEZE_AT, FREEZE_AT + 1.1, y=22, color=AMBER, size=39),
            caption("The landlord pulled the plug.", FREEZE_AT + 0.25, FREEZE_AT + 1.1, y=68, color=PAPER, size=16),
            voice("clive", "Yep. That's me. You're probably wondering how we got here.", FREEZE_AT + 1.1, REWIND_AT, y=24, cps=40, width=400)])
    add(REWIND_AT, INTRO, src=TOO_LOUD, speed=-REWIND_FRAMES / ((INTRO - REWIND_AT) * FPS), zoom=2,
        focus=FREEZE_FOCUS, audio=0.0, label="rewind", fx=[tape_rewind(REWIND_AT)])

    # The title, on the full band's first hit.
    add(bar(2), bar(3), draw=title_card(bar(2)), label="title", fx=[flash_fx(bar(2), 5, 0.9)])

    # Tell, show: who they are, how you script, what he does with it.
    add(bar(3), bar(3.5), src=s1 + 150, label="this is clive",
        fx=[caption("Clive. Can't jump.", bar(3), bar(3.5), color=CLIVE, size=22, y=220)])
    jazz_jump = mark("pov jazz", 1, 0)
    add(bar(3.5), bar(4), src=jazz_jump + 20, label="this is jazz",
        fx=[caption("Jazz. Can't do much else.", bar(3.5), bar(4), color=JAZZ, size=22, y=220)])
    # The editor, then Run on bar 5, and he does it: one shot.
    run = mark("run jazz.js", 1, 1)
    add(bar(4), bar(6), src=run - int(4 * BEAT * FPS) + 8, label="editor",
        fx=[caption("Write his to-do list in real JavaScript.", bar(4) + BEAT / 2, bar(5) - BEAT / 4, y=6, color=JS),
            flash_fx(bar(5) - 8 / FPS, 3, 0.4)])
    add(bar(6), bar(7), src=mark("run jazz.js", 1, 1) + 40, zoom=2, focus=POV_JAZZ, label="pov jazz",
        fx=[handheld, pov_frame("clive"),
            voice("clive", "I can't change Jazz. But I can change his to-do list.", bar(6), bar(7), y=24)])
    add(bar(7), bar(8), draw=lambda t: dq.dim(title_art().copy(), 0.7), label="hook",
        fx=[slam_lines([("YOU WRITE THE SCRIPT.", 30, PAPER), ("HE LIVES IT.", 30, JS)], bar(7), BEAT * 2),
            shake_fx(bar(7), 2), shake_fx(bar(7) + BEAT * 2, 3)])

    # Chorus: the six stops, a bar each, then a bar of quick cuts.
    stops = [
        (1, "Flat 5B", mark("run jazz.js", 1, 3) + 20, "jazz.jump();"),
        (2, "Croydon Credit", mark("run lift.js", 2, 1) + 20, "lift.goTo(2);"),
        (3, "Band Practice", mark("run jazz.js", 3, 1) + 30, "for (let i = 0; i < 4; i++)"),
        (4, "The Stag Do", mark("run jazz.js", 4, 1) + 30, 'bell.addEventListener("ring", go);'),
        (5, "East Croydon", mark("run jazz.js", 5, 1) + 40, "setTimeout(press, 2500);"),
        (6, "The Wedding", mark("editor on jazz.js", 6, 1) + 10, "await clive.reach(altar);"),
    ]
    for k, (n, name, src, code) in enumerate(stops):
        at = bar(8 + k)
        add(at, bar(9 + k), src=src, label=name,
            fx=[flash_fx(at, 3, 0.5), stage_slam(name, n, at, at + BEAT * 2.5),
                code_chip(code, at + BEAT, bar(9 + k) - BEAT / 4)])
    quick = [(mark("pov jazz", 1, 1) + 20, 1, (240, 150)), (mark("card true", 3, 1) - 30, 2, (240, 170)),
             (mark("pov jazz", 4) + 80, 1, (240, 150)), (mark("pov jazz", 5) + 60, 2, (240, 170)),
             (mark("cleared true", 2) - 60, 1, (240, 150)), (mark("pov clive", 4, 1) + 40, 2, (240, 170)),
             (mark("cleared true", 3) - 50, 1, (240, 150)), (mark("cleared true", 5) - 40, 2, (240, 170))]
    for k, (src, zoom, focus) in enumerate(quick):
        add(beat(56 + k), beat(57 + k), src=src, zoom=zoom, focus=focus, label=f"quick {k}",
            fx=[flash_fx(beat(56 + k), 2, 0.3)])

    # Breakdown: the music drops out to a lonely piano, so the awkward bits go here.
    early = mark("run jazz.js", 5, 0)
    add(bar(16), bar(18), src=early + 120, label="too early",
        fx=[code_chip("setTimeout(press, 500);", bar(16) + BEAT / 2, bar(18), y=226, border=RED),
            voice("clive", "Half a second. The barrier was ready. I wasn't. Story of my life.", bar(16) + BEAT * 2, bar(18), y=28, width=330, rows=3)])
    add(bar(18), bar(19), src=mark("card true", 2) + 60, speed=0.0, label="lesson card",
        fx=[caption("Every stop teaches one idea.", bar(18) + BEAT, bar(19), y=6, color=JS)])
    stare = mark("run jazz.js", 6, 1) + 95
    add(bar(19), bar(21.5), src=stare, zoom=3, focus=POV_STARE, speed=0.0, audio=0.0, label="the stare",
        fx=[handheld, pov_frame("clive"),
            voice("clive", "Say something. Anything.", bar(19) + BEAT, bar(20), y=24),
            voice("clive", "...Do you like semicolons?", bar(20) + BEAT * 2, bar(21.5), y=24)])
    add(bar(21.5), bar(22), draw=black, label="beat",
        fx=[caption("Six stops. One very small flat.", bar(21.5), bar(22), y=128, color=PAPER)])

    # Finale: the band's back, and so are the stops, every cut on a bar.
    finale = [(mark("editor on jazz.js", 4, 1) + 20, 'bell.addEventListener("ring", ...)', "bell"),
              (mark("run tannoy.js", 5, 1) + 10, None, "mind the gap"),
              (mark("run jazz.js", 6, 1) + 40, None, "here comes the bride"),
              (mark("run car.js", 6, 1) - 40, None, "the car")]
    for k, (src, code, label) in enumerate(finale):
        at = bar(22 + k)
        add(at, bar(23 + k), src=src, label=label,
            fx=[flash_fx(at, 4 if k == 0 else 3, 0.9 if k == 0 else 0.5)]
            + ([code_chip(code, at + BEAT / 2, bar(23 + k) - BEAT / 4)] if code else []))
    ends = [mark("cleared true", n) - 90 for n in (1, 2, 3, 4, 5, 6)] + [mark("run car.js", 6, 0) + 20, mark("cleared true", 6) - 30]
    for k, src in enumerate(ends):
        add(beat(104 + k), beat(105 + k), src=src, zoom=1 + k % 2, focus=(240, 170), label=f"finale {k}",
            fx=[flash_fx(beat(104 + k), 2, 0.3)])

    # The end card, and the last word over the piano tag.
    add(bar(28), LENGTH, draw=end_card(bar(28)), label="end card",
        fx=[flash_fx(bar(28), 8, 1.0), flash_fx(bar(30), 4, 0.4),
            voice("jazz", "Did we just learn JavaScript?", bar(30) + BEAT, bar(31) + BEAT, y=210, width=250),
            voice("clive", "Don't tell anyone.", bar(31) + BEAT, LENGTH, y=210, width=250)])
    return shots


## Screen spots (native pixels) for the punch-ins, read off the stills.
CLOSE_CLIVE = (74, 196)
CLOSE_JAZZ = (153, 196)
POV_JAZZ = (240, 196)
POV_STARE = (112, 190)
## Flat 5B before the first thought: both of them in shot, nothing on screen.
QUIET = 165
## Band Practice: the fifth strum brings the speakers down and the landlord's
## "TOO LOUD!" is up. The cold open freezes here, on Clive and Jazz.
TOO_LOUD = 5918
FREEZE_FOCUS = (176, 175)
FREEZE_AT = 2.3
REWIND_AT = 5.3
## The rewind runs the speakers back down to after Jazz's script started.
REWIND_FRAMES = 128

## The cue's piano tag rings out to here.
LENGTH = INTRO + 63.5 - CUE_SKIP

CUES = [
    # The garage band under the live shot, cut dead by the scratch.
    ("garage", 0.0, 0.55, FREEZE_AT),
    ("scratch", FREEZE_AT - 0.05, 0.8),
    ("rewind", REWIND_AT, 0.7),
    ("sting", bar(2), 0.6),
    ("impact", bar(2), 0.6),
    ("swish", bar(3.5) - 0.1, 0.4),
    ("typing", bar(4) + 0.1, 0.4),
    ("impact", bar(7), 0.6), ("impact", bar(7) + BEAT * 2, 0.7),
    ("swish", bar(8) - 0.15, 0.6),
    ("scratch", bar(16) + 0.9, 0.5),
    ("room_tone", bar(19), 0.6), ("room_tone", bar(19) + 3.9, 0.6),
    ("impact", bar(22), 0.9),
    ("impact", bar(28), 0.9),
]


# --- Rendering and sound --------------------------------------------------------

def render_frame(shots: list[Shot], t: float) -> Image.Image:
    shot = next((s for s in shots if s.start <= t < s.end), shots[-1])
    if shot.draw is not None:
        img = shot.draw(t)
    else:
        img = dq.zoomed(capture(shot.frame_at(t)), shot.zoom, shot.focus).copy()
    for fx in shot.fx:
        img = fx(img, t)
    return img


def write_video(shots: list[Shot], length: float, path: Path) -> None:
    command = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "ffv1", "-pix_fmt", "bgr0", str(path)]
    proc = subprocess.Popen(command, stdin=subprocess.PIPE)
    total = int(round(length * FPS))
    for n in range(total):
        proc.stdin.write(render_frame(shots, n / FPS).tobytes())
        if n % 600 == 0:
            print(f"frame {n}/{total}", flush=True)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed while writing the native video")


def sfx_path(name: str) -> Path:
    """This trailer's own effects first, then the Dunder Quest trailer's."""
    own = AUDIO / f"{name}.wav"
    return own if own.exists() else dq.AUDIO / f"{name}.wav"


def mix_audio(shots: list[Shot], length: float, path: Path) -> None:
    n = int(length * RATE)
    music = np.zeros((n, 2), np.float32)
    dq.place(music, dq.load_wav(AUDIO / f"{CUE}.wav")[int(CUE_SKIP * RATE):], INTRO, 1.0)
    game = np.zeros((n, 2), np.float32)
    source = dq.load_wav(CAPTURE / "f.wav")
    fade = int(0.01 * RATE)
    for shot in shots:
        if shot.src is None or shot.audio <= 0 or shot.speed != 1.0:
            continue
        a = int(shot.src / FPS * RATE)
        clip = source[a:a + int((shot.end - shot.start) * RATE)].copy()
        if len(clip) > 2 * fade:
            ramp = np.linspace(0, 1, fade)[:, None]
            clip[:fade] *= ramp
            clip[-fade:] *= ramp[::-1]
        dq.place(game, clip, shot.start, shot.audio)
    sfx = np.zeros((n, 2), np.float32)
    for name, at, gain, *cut in CUES:
        clip = dq.load_wav(sfx_path(name))
        if cut:
            # Cut dead, as if someone pulled the plug.
            clip = clip[:int(cut[0] * RATE)].copy()
            clip[-240:] *= np.linspace(1, 0, 240)[:, None]
        dq.place(sfx, clip, at, gain)
    hits = np.abs(game * 2.5 + sfx).max(axis=1)
    env = np.convolve(hits, np.ones(2400) / 2400, mode="same")
    duck = 1.0 - np.clip(env * 2.0, 0.0, 0.35)
    game = 0.6 * np.tanh(game * 2.5 / 0.6)
    mix = music * 0.62 * duck[:, None] + game + sfx * 0.8
    tail = int(1.0 * RATE)
    mix[-tail:] *= np.linspace(1, 0, tail)[:, None]
    peak = np.abs(mix).max()
    if peak > 0.98:
        mix *= 0.98 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())


def thumbnail(path: Path) -> None:
    """A 1920x1080 YouTube thumbnail: the two of them on their sofas, close
    up, under the name, with the line that moves Jazz."""
    img = dq.zoomed(capture(QUIET), 3, (113, 186)).copy()
    ImageDraw.Draw(img).rectangle((0, 0, W, 84), fill=INK)
    wordmark(img, 4, 48)
    draw_text(img, (W // 2, 60), "LEARN JAVASCRIPT. BLAME YOUR FLATMATE.", font(PIXEL, 16), PAPER,
              outline=INK, thick=1, anchor="mt")
    f = font(MONO, 36)
    line = "jazz.walk(7);"
    tw = int(f.getlength(line))
    panel(img, ((W - tw) // 2 - 12, 96, (W + tw) // 2 + 12, 136), fill=CODE_BG, border=JS)
    draw_js(img, ((W - tw) // 2, 98), line, f)
    img.resize((W * 4, H * 4), Image.NEAREST).save(path)
    print(f"WROTE {path.relative_to(ROOT.parent)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    shots = edit()
    if "--thumb" in sys.argv:
        thumbnail(OUT / "youtube_thumbnail.png")
        return
    if "--stills" in sys.argv:
        sheet = Image.new("RGB", (W * 4, H * ((len(shots) + 3) // 4)), "black")
        for k, shot in enumerate(shots):
            mid = min(shot.end - 1 / FPS, shot.start + (shot.end - shot.start) * 0.7)
            sheet.paste(render_frame(shots, mid), ((k % 4) * W, (k // 4) * H))
        sheet.save(OUT / "stills.png")
        print(f"WROTE {(OUT / 'stills.png').relative_to(ROOT.parent)}")
        return
    if "--at" in sys.argv:
        times = [float(a) for a in sys.argv[sys.argv.index("--at") + 1:]]
        sheet = Image.new("RGB", (W * 2, H * ((len(times) + 1) // 2)), "black")
        for k, t in enumerate(times):
            sheet.paste(render_frame(shots, t), ((k % 2) * W, (k // 2) * H))
        sheet.save(OUT / "at.png")
        print(f"WROTE {(OUT / 'at.png').relative_to(ROOT.parent)}")
        return
    native = OUT / "native.mkv"
    if "--audio-only" not in sys.argv or not native.exists():
        write_video(shots, LENGTH, native)
    mix_audio(shots, LENGTH, OUT / "mix_raw.wav")
    dq.normalize(OUT / "mix_raw.wav", OUT / "mix.wav")
    dq.encode(native, OUT / "mix.wav", 4, OUT / "flatmates_trailer_1080p.mp4", 12)
    if "--no-4k" not in sys.argv:
        dq.encode(native, OUT / "mix.wav", 8, OUT / "flatmates_trailer_4k.mp4", 16)
    thumbnail(OUT / "youtube_thumbnail.png")


if __name__ == "__main__":
    main()
