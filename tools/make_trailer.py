"""Cut the Dunder Quest trailer from a Movie Maker capture of the trail bot.

Every frame is composed at the game's native 480x270, gameplay and motion
graphics alike, then scaled by whole numbers with nearest-neighbor so no
pixel ever smears. It opens cold: coconut clops in the dark, the squire
walks into a beam of light, and the giant foot stomps down on the march's
first hit. From there the edit is cut to `trailer/audio/cue_march.wav`
(120 BPM, first beat 0.17 s into the cue, measured from its onsets).
Needs ffmpeg on the PATH.

    godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_capture.tscn
    python tools/make_trailer.py            # -> trailer/out/dunder_quest_trailer_{1080p,4k}.mp4
    python tools/make_trailer.py --stills   # one PNG per shot, for checking the cut
"""

from __future__ import annotations

import functools
import json
import math
import random
import subprocess
import sys
import wave
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = ROOT / "trailer" / "captures" / "run"
AUDIO = ROOT / "trailer" / "audio"
OUT = ROOT / "trailer" / "out"
PIXEL = ROOT / "assets" / "fonts" / "PixelifySans.ttf"
MONO = ROOT / "assets" / "fonts" / "VT323.ttf"
ART = ROOT / "assets" / "backgrounds"

W, H = 480, 270
FPS = 60
RATE = 48000
## The cold open runs this long before the march starts.
INTRO = 6.0
CUE = "cue_march"
BEAT = 60.0 / 120.0
FIRST_BEAT = INTRO + 0.17
## The march's opening brass hit, where the foot lands.
SLAM = INTRO + 0.8
SPRITES = ROOT / "assets" / "sprites"
## Clip-clops getting closer in the dark: (time, gain).
CLOPS = [(0.5, 0.18), (1.15, 0.22), (1.75, 0.28), (2.3, 0.34), (2.8, 0.42), (3.25, 0.5),
         (3.65, 0.58), (4.0, 0.66), (4.32, 0.74), (4.6, 0.8)]

GOLD = (242, 181, 68)
TITLE_GOLD = (255, 214, 117)
PARCHMENT = (244, 228, 196)
ASH = (176, 169, 208)
EMBER = (255, 138, 61)
NIGHT = (21, 18, 42)
LINE = (74, 79, 134)
OUTLINE = (41, 15, 31)
SHADOW = (128, 36, 31)
MINT = (126, 224, 160)


def beat(k: float) -> float:
    return FIRST_BEAT + k * BEAT


def bar(n: float) -> float:
    return beat(n * 4)


# --- Drawing helpers ---------------------------------------------------------

@functools.lru_cache(maxsize=None)
def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def text_mask(s: str, fnt: ImageFont.FreeTypeFont) -> Image.Image:
    """A hard-edged 1-bit mask of `s`, so pixel fonts stay on the grid."""
    left, top, right, bottom = fnt.getbbox(s)
    mask = Image.new("L", (max(1, right) + 2, max(1, bottom) + 2), 0)
    ImageDraw.Draw(mask).text((0, 0), s, font=fnt, fill=255)
    return mask.point(lambda v: 255 if v > 110 else 0)


def text_size(s: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
    left, top, right, bottom = fnt.getbbox(s)
    return right, bottom


def draw_text(img: Image.Image, xy: tuple[int, int], s: str, fnt: ImageFont.FreeTypeFont,
              color: tuple, outline: tuple | None = None, thick: int = 1,
              shadow: tuple | None = None, shadow_dy: int = 0, anchor: str = "lt") -> tuple[int, int]:
    """Pastes `s` with an optional pixel outline and drop shadow. `anchor` is
    'lt', 'mt' or 'rt' horizontally against x, top against y."""
    mask = text_mask(s, fnt)
    width = text_size(s, fnt)[0]
    x, y = xy
    if anchor[0] == "m":
        x -= width // 2
    elif anchor[0] == "r":
        x -= width
    if outline is not None:
        grown = mask
        for _ in range(thick):
            grown = grown.filter(ImageFilter.MaxFilter(3))
        if shadow is not None and shadow_dy:
            img.paste(shadow, (x - 1, y - 1 + shadow_dy), mask=_pad(grown))
        img.paste(outline, (x - 1, y - 1), mask=_pad(grown))
    elif shadow is not None and shadow_dy:
        img.paste(shadow, (x, y + shadow_dy), mask=mask)
    img.paste(color, (x, y), mask=mask)
    return x, width


def _pad(mask: Image.Image) -> Image.Image:
    padded = Image.new("L", (mask.width + 2, mask.height + 2), 0)
    padded.paste(mask, (1, 1))
    return padded.filter(ImageFilter.MaxFilter(3))


def panel(img: Image.Image, box: tuple[int, int, int, int], fill=NIGHT, border=LINE, alpha: float = 1.0) -> None:
    x0, y0, x1, y1 = box
    if alpha < 1.0:
        region = img.crop(box)
        solid = Image.new("RGB", region.size, fill)
        img.paste(Image.blend(region, solid, alpha), box[:2])
    else:
        ImageDraw.Draw(img).rectangle((x0, y0, x1 - 1, y1 - 1), fill=fill)
    ImageDraw.Draw(img).rectangle((x0, y0, x1 - 1, y1 - 1), outline=border)


def flash(img: Image.Image, amount: float, color=(255, 246, 228)) -> Image.Image:
    if amount <= 0:
        return img
    return Image.blend(img, Image.new("RGB", img.size, color), min(1.0, amount))


def dim(img: Image.Image, amount: float) -> Image.Image:
    return Image.blend(img, Image.new("RGB", img.size, NIGHT), amount)


# --- Python syntax colors, for code typed onto cards ------------------------

KEYWORDS = {"def", "return", "for", "in", "if", "else", "import", "and", "or", "not", "True", "False", "while"}
BUILTINS = {"print", "range", "len", "list"}


def tokens(line: str) -> list[tuple[str, tuple]]:
    out: list[tuple[str, tuple]] = []
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "#":
            out.append((line[i:], ASH))
            break
        if ch in "\"'":
            j = line.find(ch, i + 1)
            j = len(line) if j < 0 else j + 1
            out.append((line[i:j], GOLD))
            i = j
            continue
        if ch.isdigit():
            j = i
            while j < len(line) and line[j].isdigit():
                j += 1
            out.append((line[i:j], MINT))
            i = j
            continue
        if ch.isalpha() or ch == "_":
            j = i
            while j < len(line) and (line[j].isalnum() or line[j] == "_"):
                j += 1
            word = line[i:j]
            color = EMBER if word in KEYWORDS else (GOLD if word in BUILTINS else PARCHMENT)
            out.append((word, color))
            i = j
            continue
        out.append((ch, ASH if ch in ">." else PARCHMENT))
        i += 1
    return out


def draw_code(img: Image.Image, xy: tuple[int, int], lines: list[str], shown: int, fnt: ImageFont.FreeTypeFont,
              cursor: bool, line_h: int) -> None:
    """Types `lines` out to `shown` characters, colored, with a block cursor."""
    x0, y = xy
    left = shown
    cx, cy = x0, y
    for line in lines:
        x = x0
        visible = line[:max(0, left)]
        for word, color in tokens(visible):
            draw_text(img, (x, y), word, fnt, color)
            x += int(fnt.getlength(word))
        cx, cy = x, y
        left -= len(line)
        if left <= 0:
            break
        y += line_h
    if cursor:
        ImageDraw.Draw(img).rectangle((cx + 1, cy + 3, cx + 7, cy + line_h - 3), fill=EMBER)


# --- Ambient layers ----------------------------------------------------------

_rng = random.Random(7)
SPARKS = [(_rng.uniform(0, W), _rng.uniform(0, H), _rng.uniform(6, 22), _rng.uniform(0, 6.28), _rng.choice([1, 1, 2]))
          for _ in range(70)]


def embers(img: Image.Image, t: float, strength: float = 1.0) -> None:
    """Rising ember pixels with a flicker; deterministic in `t`."""
    draw = ImageDraw.Draw(img)
    for x0, y0, speed, phase, size in SPARKS:
        y = (y0 - t * speed) % (H + 10) - 5
        x = x0 + math.sin(t * 1.3 + phase) * 6
        glow = 0.5 + 0.5 * math.sin(t * 7 + phase * 3)
        if glow * strength < 0.25:
            continue
        color = EMBER if glow > 0.6 else GOLD
        draw.rectangle((int(x), int(y), int(x) + size - 1, int(y) + size - 1), fill=color)


@functools.lru_cache(maxsize=None)
def layer(name: str) -> Image.Image:
    return Image.open(ART / f"{name}.png").convert("RGBA")


def parallax(t: float, theme: str = "wood", darkness: float = 0.72) -> Image.Image:
    """The stage's three background layers drifting at their own speeds."""
    img = Image.new("RGB", (W, H), NIGHT)
    for depth, speed in (("far", 4), ("mid", 9), ("near", 18)):
        art = layer(f"{theme}_{depth}")
        art = art.resize((art.width * 2, art.height * 2), Image.NEAREST)
        offset = int(t * speed) % art.width
        for x in (-offset, art.width - offset):
            img.paste(art, (x, H - art.height), art)
    return dim(img, darkness)


# --- Gameplay source ---------------------------------------------------------

@functools.lru_cache(maxsize=256)
def capture(frame: int) -> Image.Image:
    path = CAPTURE / f"f{frame:08d}.png"
    if not path.exists():
        return Image.new("RGB", (W, H), NIGHT)
    return Image.open(path).convert("RGB")


def zoomed(img: Image.Image, zoom: int, focus: tuple[int, int]) -> Image.Image:
    """Whole-number punch-in around `focus` (native pixels)."""
    if zoom == 1:
        return img
    cw, ch = W // zoom, H // zoom
    x = min(max(focus[0] - cw // 2, 0), W - cw)
    y = min(max(focus[1] - ch // 2, 0), H - ch)
    return img.crop((x, y, x + cw, y + ch)).resize((W, H), Image.NEAREST)


def shaken(img: Image.Image, amount: float, t: float) -> Image.Image:
    if amount < 0.5:
        return img
    dx = int(round(math.sin(t * 91.0) * amount))
    dy = int(round(math.cos(t * 77.0) * amount))
    out = Image.new("RGB", img.size, NIGHT)
    out.paste(img, (dx, dy))
    return out


# --- The edit ----------------------------------------------------------------

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


def slam_title(lines: list[tuple[str, int, tuple]], at: float, gap: float, y: int = 0):
    """Lines of big text that drop in one per `gap` seconds, centered."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        total = sum(size * 1.1 for _, size, _ in lines)
        top = (H - int(total)) // 2 + y
        for k, (s, size, color) in enumerate(lines):
            local = t - (at + k * gap)
            if local >= 0:
                drop = max(0, 6 - int(local * FPS) * 2)
                f = font(PIXEL, size)
                draw_text(img, (W // 2, top - drop), s, f, color, outline=OUTLINE, thick=2,
                          shadow=SHADOW, shadow_dy=3, anchor="mt")
            top += int(size * 1.1)
        return img
    return fx


def chip(s: str, at: float, until: float, y: int = 240, color=GOLD, size: int = 13, mono: bool = False):
    """A label panel that wipes open from the left and wipes away."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        if not at <= t < until:
            return img
        f = font(MONO if mono else PIXEL, size)
        tw, th = text_size(s, f)
        pw, ph = tw + 16, th + 9
        x0 = (W - pw) // 2
        grow = min(1.0, (t - at) * 10)
        shrink = min(1.0, (until - t) * 12)
        width = int(pw * min(grow, shrink))
        if width < 4:
            return img
        panel(img, (x0, y, x0 + width, y + ph), fill=NIGHT, border=color)
        if width == pw:
            draw_text(img, (x0 + 8, y + 3), s, f, color)
        return img
    return fx


def code_box(lines: list[str], at: float, cps: float, box: tuple[int, int, int, int], until: float = 1e9,
             size: int = 16, line_h: int = 15, alpha: float = 0.92):
    """A terminal panel that types `lines` out at `cps` characters a second."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        if not at <= t < until:
            return img
        panel(img, box, alpha=alpha)
        shown = int((t - at) * cps)
        blink = int(t / (BEAT / 2)) % 2 == 0
        draw_code(img, (box[0] + 8, box[1] + 4), lines, shown, font(MONO, size), blink, line_h)
        return img
    return fx


def flash_fx(at: float, frames: int = 4, peak: float = 0.9):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) * FPS
        if 0 <= k < frames:
            return flash(img, peak * (1 - k / frames))
        return img
    return fx


def shake_fx(at: float, amount: float = 3.0, length: float = 0.25):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = t - at
        if 0 <= k < length:
            return shaken(img, amount * (1 - k / length), t)
        return img
    return fx


def letterbox(img: Image.Image, t: float) -> Image.Image:
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, W, 17), fill=(0, 0, 0))
    draw.rectangle((0, H - 18, W, H), fill=(0, 0, 0))
    return img


def black(_t: float) -> Image.Image:
    return Image.new("RGB", (W, H), (8, 6, 16))


def terminal_card(lines: list[str], at: float, cps: float, size: int = 32, theme: str | None = None):
    """A dark card with code typing out large, centered on its longest line."""
    f = font(MONO, size)
    width = max(int(f.getlength(line)) for line in lines)
    line_h = int(size * 0.95)

    def draw(t: float) -> Image.Image:
        img = parallax(t, theme, 0.82) if theme else Image.new("RGB", (W, H), (8, 6, 16))
        embers(img, t, 0.6)
        x = (W - width) // 2
        y = (H - line_h * len(lines)) // 2
        shown = int(max(0.0, t - at) * cps)
        draw_code(img, (x, y), lines, shown, f, int(t / (BEAT / 2)) % 2 == 0, line_h)
        return img
    return draw


def end_card(t: float) -> Image.Image:
    art = Image.open(ART / "title_art.png").convert("RGB")
    # A slow push in on the left side, done as whole-pixel crops.
    img = art
    k = min(1.0, max(0.0, (t - bar(28)) / 1.0))
    img = dim(img, 0.55 - 0.25 * k)
    embers(img, t, 1.0)
    local = t - bar(28)
    if local >= 0.0:
        drop = max(0, 8 - int(local * FPS) * 2)
        draw_text(img, (W // 2, 70 - drop), "__dunder_quest__", font(PIXEL, 39), TITLE_GOLD,
                  outline=OUTLINE, thick=3, shadow=SHADOW, shadow_dy=3, anchor="mt")
    if local >= BEAT * 2:
        draw_text(img, (W // 2, 118), "A squire's quest for the Grail", font(PIXEL, 13), (245, 230, 255),
                  outline=OUTLINE, thick=1, anchor="mt")
    if local >= BEAT * 4:
        f = font(PIXEL, 13)
        msg = "Play free in your browser"
        tw = text_size(msg, f)[0]
        panel(img, ((W - tw) // 2 - 12, 150, (W + tw) // 2 + 12, 172), fill=NIGHT, border=GOLD)
        draw_text(img, (W // 2, 154), msg, f, PARCHMENT, anchor="mt")
    if local >= BEAT * 6:
        draw_text(img, (W // 2, 182), "dunderquest.com", font(PIXEL, 26), GOLD,
                  outline=OUTLINE, thick=2, anchor="mt")
    if local >= BEAT * 8:
        draw_text(img, (W // 2, 218), "Learn Python  ·  Windows  ·  macOS  ·  Linux  ·  Web", font(MONO, 16), ASH,
                  outline=OUTLINE, thick=1, anchor="mt")
    return img


@functools.lru_cache(maxsize=None)
def sprite(name: str, scale: int) -> Image.Image:
    art = Image.open(SPRITES / f"{name}.png").convert("RGBA")
    return art.resize((art.width * scale, art.height * scale), Image.NEAREST)


def cold_open(t: float) -> Image.Image:
    """Clops in the dark, a beam of light, the squire walks in and stops, and
    the giant foot comes down beside him on the march's first hit."""
    img = Image.new("RGB", (W, H), (8, 6, 16))
    floor = 206
    # The beam fades up as the clops get closer.
    beam = min(1.0, max(0.0, (t - 1.0) / 2.0))
    if beam > 0.0:
        light = Image.new("L", (W, H), 0)
        ImageDraw.Draw(light).polygon([(W // 2 - 26, 0), (W // 2 + 26, 0), (W // 2 + 70, floor), (W // 2 - 70, floor)],
                                      fill=int(70 * beam))
        ImageDraw.Draw(light).ellipse((W // 2 - 74, floor - 6, W // 2 + 74, floor + 6), fill=int(110 * beam))
        img.paste(Image.new("RGB", (W, H), (255, 236, 170)), (0, 0), light)
        embers(img, t, 0.25 * beam)
    # The squire walks in from the left, bobbing on every clop, and stops in the light.
    squire = sprite("squire", 3)
    walk = min(1.0, max(0.0, (t - 0.4) / 4.3))
    x = int(-squire.width + (W // 2 - squire.width // 2 + squire.width) * (1 - (1 - walk) ** 2))
    bob = 3 if walk < 1.0 and any(0 <= t - c < 0.12 for c, _ in CLOPS) else 0
    # A flinch the moment the foot lands.
    if 0 <= t - SLAM < 0.25:
        bob = 6
    img.paste(squire, (x, floor - squire.height - bob), squire)
    # The foot: drops in a fifth of a second, stands one beat, then lifts away.
    foot = sprite("giant_foot", 2)
    fx = W // 2 + 30
    if t >= SLAM - 0.2:
        if t < SLAM:
            y = floor - foot.height - int((SLAM - t) / 0.2 * (floor + 10))
        elif t < SLAM + BEAT:
            y = floor - foot.height
        else:
            y = floor - foot.height - int((t - SLAM - BEAT) * 900)
        img.paste(foot, (fx, y), foot)
    # The title stamps in with the foot.
    if t >= SLAM:
        drop = max(0, 8 - int((t - SLAM) * FPS) * 2)
        draw_text(img, (W // 2, 34 - drop), "__dunder_quest__", font(PIXEL, 39), TITLE_GOLD,
                  outline=OUTLINE, thick=3, shadow=SHADOW, shadow_dy=3, anchor="mt")
    if t >= SLAM + BEAT:
        draw_text(img, (W // 2, 82), "A squire's quest for the Grail", font(PIXEL, 13), (245, 230, 255),
                  outline=OUTLINE, thick=1, anchor="mt")
    return img


def stage_slam(name: str, at: float):
    """A stage name that drops in big over the play, then clears on the next beat."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        local = t - at
        if not 0 <= local < BEAT * 3:
            return img
        drop = max(0, 6 - int(local * FPS) * 2)
        draw_text(img, (W // 2, 92 - drop), name, font(PIXEL, 26), TITLE_GOLD,
                  outline=OUTLINE, thick=2, shadow=SHADOW, shadow_dy=2, anchor="mt")
        return img
    return fx


# Capture frames for each moment, read off the run's MARK log and contact sheets.
BRIDGE = 9552        # Bridge of Peril: span(5) bumped at 9618, planks out by 9658
LIFT = 5377          # Cave of the Bunny: the lift rides up on range()
GATE = 7145          # Ministry of Walks: the heat dial bumped, the gate swings
STAIR = 11987        # Castle Aargh: the comprehension stair builds
PLANKS = 500         # Shrubbery Wood: the slice lays the planks
SCROLL_A = 352       # "Counting Backwards" lore card, fully open
SCROLL_B = 11834     # "Words In, Words Out" lore card
ARENA = 5637         # Tom the Enchanter seals the arena


def edit() -> list[Shot]:
    shots: list[Shot] = []

    def add(start: float, end: float, **kw) -> Shot:
        shot = Shot(start, end, **kw)
        shots.append(shot)
        return shot

    # Intro: the cold open, then straight into play and the prompt.
    add(0.0, bar(1), draw=cold_open, label="cold open",
        fx=[flash_fx(SLAM, 6, 1.0), shake_fx(SLAM, 5, 0.4)])
    add(bar(1), bar(2), src=64, label="amber run")
    add(bar(2), bar(3), draw=terminal_card([">>> import adventure"], bar(2) + BEAT, 22), label="import")
    add(bar(3), bar(4), src=2295, label="cinder run", fx=[flash_fx(bar(3))])

    # Build: one stage per bar, each named as it lands.
    for n, (src, name) in enumerate([(4417, "Cave of the Bunny"), (7060, "Ministry of Walks"), (9267, "Bridge of Peril")]):
        add(bar(4 + n), bar(5 + n), src=src, label=name,
            fx=[flash_fx(bar(4 + n), 3, 0.6), stage_slam(name, bar(4 + n))])
    add(bar(7), bar(8), draw=lambda t: parallax(t, "cave", 0.78), label="hook card",
        fx=[lambda img, t: (embers(img, t), img)[1],
            slam_title([("YOUR CODE", 39, PARCHMENT), ("BUILDS THE WORLD", 39, TITLE_GOLD)], bar(7), BEAT * 2),
            shake_fx(bar(7), 2), shake_fx(bar(7) + BEAT * 2, 3)])

    # Main: the gadgets, each one a line of Python made solid.
    add(bar(8), bar(10), src=BRIDGE, label="bridge",
        fx=[flash_fx(bar(8)), chip("bridge = span(5)", bar(8) + BEAT, bar(10) - BEAT / 2, mono=True, size=16),
            shake_fx(bar(8) + (9618 - BRIDGE) / FPS, 2)])
    add(bar(10), bar(11), src=LIFT, label="lift",
        fx=[chip("for i in range(4): lift.rise()", bar(10) + BEAT / 2, bar(11) - BEAT / 4, mono=True, size=16)])
    add(bar(11), bar(12), src=GATE, label="gate",
        fx=[chip("if heat > 1 and heat != 3: gate.open()", bar(11) + BEAT / 2, bar(12) - BEAT / 4, mono=True, size=16)])
    add(bar(12), bar(13), src=STAIR, label="stair",
        fx=[chip("steps = [n * 2 for n in range(1, 5)]", bar(12) + BEAT / 2, bar(13) - BEAT / 4, mono=True, size=16)])
    add(bar(13), bar(14), src=PLANKS, label="planks",
        fx=[chip("bridge = planks[1:11]", bar(13) + BEAT / 2, bar(14) - BEAT / 4, mono=True, size=16)])
    # Two bars of quick cuts on every beat, punching in on every other one.
    quick = [(230, 1, (240, 150)), (2333, 2, (220, 190)), (4477, 1, (240, 150)), (7420, 2, (230, 185)),
             (9372, 1, (240, 150)), (11562, 2, (230, 170)), (11702, 1, (240, 150)), (6850, 2, (230, 190))]
    for k, (src, zoom, focus) in enumerate(quick):
        add(beat(56 + k), beat(57 + k), src=src, zoom=zoom, focus=focus, label=f"quick {k}",
            fx=[flash_fx(beat(56 + k), 2, 0.35)])

    # Breakdown: the scrolls that teach, then the guardian who tests.
    add(bar(16), bar(17), src=SCROLL_A, speed=0.0, label="scroll A",
        fx=[chip("Read the lore scrolls", bar(16) + BEAT, bar(17))])
    add(bar(17), bar(18), src=SCROLL_B, speed=0.0, label="scroll B",
        fx=[chip("Learn real Python", bar(17) + BEAT / 2, bar(18))])
    add(bar(18), bar(19), src=ARENA, label="arena")
    add(bar(19), bar(20), draw=terminal_card([">>> duel(bridgekeeper)"], bar(19) + BEAT / 2, 20, theme="cave"),
        label="duel prompt")

    # Finale: a duel a bar, each a different lesson, every one landing on a beat.
    duels = [(1000, "lists"), (3371, "dictionaries"), (5760, "loops & range"), (7980, "booleans"),
             (10138, "functions"), (12517, "comprehensions")]
    for k, (src, topic) in enumerate(duels):
        add(bar(20 + k), bar(21 + k), src=src, label=f"duel {topic}",
            fx=[flash_fx(bar(20 + k), 4 if k == 0 else 3, 0.9 if k == 0 else 0.5),
                chip(topic, bar(20 + k) + BEAT / 2, bar(21 + k) - BEAT / 4, color=MINT)])
    add(bar(26), bar(27), src=13758, label="banish", fx=[flash_fx(bar(26), 3, 0.5)])
    add(bar(27), bar(28), src=13823, label="waygate")

    # The slam, then the title.
    add(bar(28), LENGTH, draw=end_card, label="end card", fx=[flash_fx(bar(28), 8, 1.0)])
    return shots


## The march plays out to its own finish under the end card.
LENGTH = INTRO + 66.0

CUES = [
    *[("coconut", at, gain) for at, gain in CLOPS],
    *[("coconut", at + 0.19, gain * 0.3) for at, gain in CLOPS],
    *[("coconut", at + 0.38, gain * 0.12) for at, gain in CLOPS],
    ("whoosh", SLAM - 0.35, 0.6),
    ("impact", SLAM, 1.0),
    ("typing", bar(2) + BEAT, 0.7),
    ("cursor_blip", bar(2), 0.6),
    ("whoosh", bar(4) - 0.1, 0.5), ("whoosh", bar(5) - 0.1, 0.5), ("whoosh", bar(6) - 0.1, 0.5),
    ("impact", bar(7), 0.7), ("impact", bar(7) + BEAT * 2, 0.8),
    ("impact", bar(8), 0.6),
    ("whoosh", bar(16) - 0.1, 0.4),
    ("typing", bar(19) + BEAT / 2, 0.7),
    ("riser", bar(20) - 3.5, 0.6),
    ("impact", bar(20), 1.0),
    ("wrong", bar(25) + (12559 - 12517) / FPS, 0.6),
    ("impact", bar(28), 1.0),
]


def thumbnail(path: Path) -> None:
    """A 1920x1080 YouTube thumbnail: a duel mid-answer under a big headline."""
    img = capture(5809).copy()
    ImageDraw.Draw(img).rectangle((0, 0, W, 92), fill=NIGHT)
    img.paste(dim(img.crop((0, 92, W, H)), 0.25), (0, 92))
    draw_text(img, (W // 2, 8), "__dunder_quest__", font(PIXEL, 39), TITLE_GOLD,
              outline=OUTLINE, thick=3, shadow=SHADOW, shadow_dy=3, anchor="mt")
    draw_text(img, (W // 2, 56), "LEARN PYTHON BY PLAYING", font(PIXEL, 26), PARCHMENT,
              outline=OUTLINE, thick=2, anchor="mt")
    f = font(MONO, 32)
    line = "print(list(range(4)))"
    tw = int(f.getlength(line))
    panel(img, ((W - tw) // 2 - 10, 98, (W + tw) // 2 + 10, 132), border=GOLD)
    draw_code(img, ((W - tw) // 2, 98), [line], len(line), f, False, 32)
    img.resize((W * 4, H * 4), Image.NEAREST).save(path)
    print(f"WROTE {path.relative_to(ROOT)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    shots = edit()
    if "--thumb" in sys.argv:
        thumbnail(OUT / "youtube_thumbnail.png")
        return
    if "--stills" in sys.argv:
        sheet = Image.new("RGB", (W * 4, H * ((len(shots) + 3) // 4)), "black")
        for k, shot in enumerate(shots):
            mid = min(shot.end - 1 / FPS, shot.start + (shot.end - shot.start) * 0.6)
            sheet.paste(render_frame(shots, mid), ((k % 4) * W, (k // 4) * H))
        sheet.save(OUT / "stills.png")
        print(f"WROTE {(OUT / 'stills.png').relative_to(ROOT)}")
        return
    if "--at" in sys.argv:
        times = [float(a) for a in sys.argv[sys.argv.index("--at") + 1:]]
        sheet = Image.new("RGB", (W * 2, H * ((len(times) + 1) // 2)), "black")
        for k, t in enumerate(times):
            sheet.paste(render_frame(shots, t), ((k % 2) * W, (k // 2) * H))
        sheet.save(OUT / "at.png")
        print(f"WROTE {(OUT / 'at.png').relative_to(ROOT)}")
        return
    native = OUT / "native.mkv"
    mixed = OUT / "mix.wav"
    if "--audio-only" not in sys.argv or not native.exists():
        run_ffmpeg_video(shots, LENGTH, native)
    mix_audio(shots, CUES, LENGTH, OUT / "mix_raw.wav")
    normalize(OUT / "mix_raw.wav", mixed)
    encode(native, mixed, 4, OUT / "dunder_quest_trailer_1080p.mp4", 12)
    if "--no-4k" not in sys.argv:
        encode(native, mixed, 8, OUT / "dunder_quest_trailer_4k.mp4", 16)


# --- Rendering ---------------------------------------------------------------

def render_frame(shots: list[Shot], t: float) -> Image.Image:
    shot = next((s for s in shots if s.start <= t < s.end), shots[-1])
    if shot.draw is not None:
        img = shot.draw(t)
    else:
        img = zoomed(capture(shot.frame_at(t)), shot.zoom, shot.focus)
    for fx in shot.fx:
        img = fx(img, t)
    return img


def run_ffmpeg_video(shots: list[Shot], length: float, path: Path) -> None:
    command = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "ffv1", "-pix_fmt", "bgr0", str(path)]
    proc = subprocess.Popen(command, stdin=subprocess.PIPE)
    total = int(round(length * FPS))
    for n in range(total):
        img = render_frame(shots, n / FPS)
        proc.stdin.write(img.tobytes())
        if n % 300 == 0:
            print(f"frame {n}/{total}", flush=True)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed while writing the native video")


# --- Audio -------------------------------------------------------------------

def load_wav(path: Path) -> np.ndarray:
    """Any wav as float32 stereo at RATE, resampled by ffmpeg when needed."""
    with wave.open(str(path)) as w:
        ok = w.getframerate() == RATE and w.getnchannels() == 2 and w.getsampwidth() == 2
        if ok:
            data = np.frombuffer(w.readframes(w.getnframes()), np.int16)
            return data.reshape(-1, 2).astype(np.float32) / 32768.0
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "s16le", "-ac", "2",
                          "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).reshape(-1, 2).astype(np.float32) / 32768.0


def place(mix: np.ndarray, clip: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = int(at * RATE)
    if start >= len(mix):
        return
    end = min(len(mix), start + len(clip))
    mix[start:end] += clip[:end - start] * gain


def mix_audio(shots: list[Shot], cues: list[tuple[str, float, float]], length: float, path: Path) -> None:
    n = int(length * RATE)
    music = np.zeros((n, 2), np.float32)
    place(music, load_wav(AUDIO / f"{CUE}.wav"), INTRO, 1.0)
    game = np.zeros((n, 2), np.float32)
    source = load_wav(CAPTURE / "f.wav")
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
        place(game, clip, shot.start, shot.audio)
    sfx = np.zeros((n, 2), np.float32)
    for name, at, gain in cues:
        # The coconut lives with the game's sounds; the rest are trailer-only.
        source = ROOT / "assets" / "audio" / "coconut.wav" if name == "coconut" else AUDIO / f"{name}.wav"
        place(sfx, load_wav(source), at, gain)
    # Duck the music a little under the effects so hits read through.
    hits = np.abs(game * 2.8 + sfx).max(axis=1)
    env = np.convolve(hits, np.ones(2400) / 2400, mode="same")
    duck = 1.0 - np.clip(env * 2.0, 0.0, 0.35)
    # The capture's effects sit ~20 dB under the cue; lift them, soft-limited.
    game = 0.6 * np.tanh(game * 2.8 / 0.6)
    mix = music * 0.62 * duck[:, None] + game + sfx * 0.8
    # The tail fades out under the end card.
    tail = int(1.2 * RATE)
    mix[-tail:] *= np.linspace(1, 0, tail)[:, None]
    peak = np.abs(mix).max()
    if peak > 0.98:
        mix *= 0.98 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())


def normalize(source: Path, dest: Path) -> None:
    """Two-pass loudnorm to -14 LUFS, -1 dBTP: measure, then apply linearly."""
    target = "I=-14:TP=-1:LRA=11"
    probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(source), "-af",
                            f"loudnorm={target}:print_format=json", "-f", "null", "-"],
                           capture_output=True, text=True, check=True).stderr
    stats = json.loads(probe[probe.rindex("{"):probe.rindex("}") + 1])
    measured = (f"measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
                f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:"
                f"offset={stats['target_offset']}:linear=true")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-af",
                    f"loudnorm={target}:{measured}", "-ar", str(RATE), "-c:a", "pcm_s16le", str(dest)],
                   check=True)


def encode(native: Path, audio: Path, scale: int, out: Path, crf: int) -> None:
    """Whole-number nearest-neighbor upscale."""
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(native), "-i", str(audio),
               "-vf", f"scale={W * scale}:{H * scale}:flags=neighbor",
               "-c:v", "libx264", "-preset", "slow", "-crf", str(crf), "-pix_fmt", "yuv420p",
               "-tune", "animation", "-c:a", "aac", "-b:a", "320k", "-ar", str(RATE),
               "-movflags", "+faststart", str(out)]
    subprocess.run(command, check=True)
    print(f"WROTE {out.relative_to(ROOT)}", flush=True)


if __name__ == "__main__":
    main()
