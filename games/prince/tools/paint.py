"""Paint the cast, the tiles and the door, pixel by pixel.

Everything here is drawn from scratch for this game: nothing is traced or
copied from any other game's sprites.

    python tools/paint.py            # -> assets/sprites/*.png
    python tools/paint.py --preview  # also tools/preview/sheet.png, scaled up
"""

from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"

CLEAR = (0, 0, 0, 0)


def rgb(text: str) -> tuple[int, int, int, int]:
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), 255)


INK = rgb("14101c")
STONE = rgb("3d4568")
STONE_DARK = rgb("2b3150")
STONE_DEEP = rgb("20253f")
STONE_LIGHT = rgb("58648f")
TRIM = rgb("c79a3e")
TRIM_LIGHT = rgb("ecc867")
TEAL = rgb("1f8f96")
STEEL = rgb("b9c2d6")
STEEL_DARK = rgb("6d7790")
WOOD = rgb("8a5a34")
WOOD_DARK = rgb("5c3a22")
WOOD_LIGHT = rgb("b07a48")
FLAME = rgb("ffb238")
FLAME_HOT = rgb("fff0a8")
FLAME_RED = rgb("e2552c")
PARCHMENT = rgb("eadfb8")
PARCHMENT_DARK = rgb("b9a878")
SKIN = rgb("d99a6c")
SKIN_DARK = rgb("b0744c")
HAIR = rgb("2a1c1a")
WHITE = rgb("f2eee2")
WHITE_SHADE = rgb("c4c2c9")
CRIMSON = rgb("d2333d")
CRIMSON_DARK = rgb("8f1f2c")
BLUE = rgb("2f5fae")
BLUE_DARK = rgb("1f3f7a")
BLACK = rgb("1b1522")
ROBE = rgb("2a2038")
ROBE_LIGHT = rgb("413257")
VIOLET = rgb("8f5cc7")
GOLD = rgb("e9b949")
PALE = rgb("d9c3ae")
ROSE = rgb("e07a9a")
SEA = rgb("2aa7a1")
SEA_DARK = rgb("1b7773")


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.image = Image.new("RGBA", (width, height), CLEAR)
        self.ox = 0
        self.oy = 0

    def at(self, ox: int, oy: int) -> "Canvas":
        self.ox, self.oy = ox, oy
        return self

    def px(self, x: int, y: int, color: tuple[int, int, int, int]) -> None:
        x += self.ox
        y += self.oy
        if 0 <= x < self.image.width and 0 <= y < self.image.height:
            self.image.putpixel((x, y), color)

    def rect(self, x: int, y: int, w: int, h: int, color: tuple[int, int, int, int]) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, color)

    def line(self, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int, int], thick: int = 1) -> None:
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            self.rect(x, y, thick, thick, color)

    def outline(self, x: int, y: int, w: int, h: int, color: tuple[int, int, int, int]) -> None:
        """An ink line round every painted pixel in the cell."""
        src = self.image.copy()
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if src.getpixel((xx + self.ox, yy + self.oy))[3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = xx + dx, yy + dy
                    if x <= nx < x + w and y <= ny < y + h and src.getpixel((nx + self.ox, ny + self.oy))[3]:
                        self.px(xx, yy, color)
                        break


# --- tiles -------------------------------------------------------------------
#
# Everything here is painted at twice the room's pixel density, like the
# Prince: a 16-pixel tile is 32x32 texels. On the sheet each tile sits in a
# 34-texel cell with its edge texels repeated round it, so the game's sharp
# filtering never blends one tile into its neighbour on the sheet.

T = 16
TT = 32
CELL = 34
TILES = ["stone", "floor", "spikes", "plank", "gate", "holes", "plate_up", "plate_down",
         "lever_off", "lever_on", "torch_dark", "torch_a", "torch_b", "scroll", "bar", "gate_tip"]

STEEL_LIGHT = rgb("e4e9f4")
TRIM_DARK = rgb("8c6a28")
WOOD_DEEP = rgb("3e2716")
GREEN = rgb("5fcf6a")
GREEN_DARK = rgb("2f8a3e")


def mix(a: tuple, b: tuple, t: float) -> tuple[int, int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def bricks(c: Canvas, seed: int) -> None:
    """Two courses of bevelled palace stone, mortar between, a little worn."""
    rng = random.Random(seed)
    c.rect(0, 0, TT, TT, STONE)
    for course, (y, joints) in enumerate(((0, (6, 22)), (16, (14, 30)))):
        # Each block a slightly different stone.
        edges = sorted(joints)
        spans = [(edges[i] + 1, (edges[(i + 1) % len(edges)] - edges[i] - 1) % TT) for i in range(len(edges))]
        for x0, width in spans:
            tone = mix(STONE, rng.choice((STONE_DARK, STONE_LIGHT, STONE)), rng.uniform(0.0, 0.25))
            for i in range(width):
                c.rect((x0 + i) % TT, y, 1, 15, tone)
            for i in range(width):
                xx = (x0 + i) % TT
                c.px(xx, y, mix(tone, STONE_LIGHT, 0.7))
                c.px(xx, y + 1, mix(tone, STONE_LIGHT, 0.25))
                c.px(xx, y + 14, STONE_DARK)
            c.rect(x0 % TT, y + 1, 1, 13, mix(tone, STONE_LIGHT, 0.4))
            c.rect((x0 + width - 1) % TT, y + 1, 1, 14, STONE_DARK)
        c.rect(0, y + 15, TT, 1, STONE_DEEP)
        for j in joints:
            c.rect(j % TT, y, 1, 15, STONE_DEEP)
    for _ in range(26):
        x, y = rng.randrange(TT), rng.randrange(TT)
        if c.image.getpixel((x + c.ox, y + c.oy))[:3] != STONE_DEEP[:3]:
            c.px(x, y, rng.choice((STONE_DARK, STONE_DARK, STONE_LIGHT, STONE_DEEP)))
    # A hairline crack or two.
    for _ in range(rng.randrange(1, 3)):
        x, y = rng.randrange(2, TT - 4), rng.randrange(3, TT - 4)
        for _ in range(rng.randrange(2, 5)):
            c.px(x, y, STONE_DEEP)
            x += rng.choice((-1, 0, 1))
            y += 1


def trim(c: Canvas) -> None:
    """The gilded edge along the top of a floor, inlaid with teal."""
    c.rect(0, 0, TT, 1, TRIM_LIGHT)
    c.rect(0, 1, TT, 5, TRIM)
    c.rect(0, 1, TT, 1, mix(TRIM, TRIM_LIGHT, 0.5))
    c.rect(0, 5, TT, 1, TRIM_DARK)
    c.rect(0, 6, TT, 1, STONE_DEEP)
    c.rect(0, 7, TT, 1, STONE_DARK)
    for x in range(4, TT, 8):
        c.px(x, 2, TEAL)
        c.rect(x - 1, 3, 3, 1, TEAL)
        c.px(x, 4, SEA_DARK)
        c.px(x, 3, SEA)
        for dx in (-4, 4):
            c.px(x + dx, 3, TRIM_LIGHT)


def figure(size: tuple[int, int], draw: Callable[[Figure], None], rim: bool = False) -> Image.Image:
    """Small curved things (flames, knobs, spikes), drawn big and averaged down."""
    f = Figure(size=size)
    draw(f)
    return finish(f.image, settle=False, rim=rim)


def paint_tile(name: str) -> Image.Image:
    c = Canvas(TT, TT)
    if name == "stone":
        bricks(c, 3)
    elif name == "floor":
        bricks(c, 5)
        trim(c)
    elif name == "holes":
        bricks(c, 7)
        trim(c)
        for x in (2, 10, 18, 26):
            c.rect(x, 2, 4, 3, INK)
            c.rect(x, 1, 4, 1, TRIM_DARK)
            c.rect(x + 1, 5, 2, 1, TRIM_LIGHT)
    elif name == "spikes":
        def spikes(f: Figure) -> None:
            for x, tip in ((4, 7), (12, 5), (20, 8), (28, 6)):
                f.shape((STEEL, STEEL_DARK, STEEL_LIGHT), lambda d, x=x, tip=tip: f.poly(d, [(x - 2.6, 29), (x, tip), (x + 2.6, 29)]), rim=1.4)
        c.image.alpha_composite(figure((TT, TT), spikes, rim=True))
        for x, tip in ((4, 7), (12, 5), (20, 8), (28, 6)):
            c.px(x, tip + 1, STEEL_LIGHT)
            c.px(x, tip + 2, WHITE)
        c.rect(0, 28, TT, 3, STEEL_DARK)
        c.rect(0, 28, TT, 1, STEEL)
        c.rect(0, 31, TT, 1, INK)
        for x in range(2, TT, 8):
            c.px(x, 29, STEEL_LIGHT)
    elif name == "plank":
        rng = random.Random(11)
        c.rect(0, 0, TT, 10, WOOD)
        c.rect(0, 0, TT, 1, WOOD_LIGHT)
        c.rect(0, 1, TT, 1, mix(WOOD, WOOD_LIGHT, 0.5))
        c.rect(0, 8, TT, 1, WOOD_DARK)
        c.rect(0, 9, TT, 1, WOOD_DEEP)
        for _ in range(7):
            x, y = rng.randrange(TT), rng.randrange(2, 8)
            c.rect(x, y, rng.randrange(3, 8), 1, rng.choice((WOOD_DARK, WOOD_LIGHT)))
        for x in (15, 31):
            c.rect(x, 0, 1, 10, WOOD_DEEP)
            c.rect((x + 1) % TT, 0, 1, 9, WOOD_LIGHT)
        for x in (4, 11, 20, 27):
            c.px(x, 4, STEEL_LIGHT)
            c.px(x + 1, 4, STEEL)
            c.px(x, 5, STEEL_DARK)
            c.px(x + 1, 5, WOOD_DEEP)
    elif name in ("gate", "gate_tip"):
        h = TT if name == "gate" else 10
        for x in (4, 14, 24):
            for i, col in enumerate((STEEL, STEEL_LIGHT, STEEL, STEEL_DARK)):
                c.rect(x + i, 0, 1, h, col)
            if name == "gate_tip":
                # The points along the bottom of the portcullis.
                for i, (dx, w) in enumerate(((0, 4), (0, 4), (1, 2), (1, 2), (1, 1))):
                    for k in range(w):
                        c.px(x + dx + k, h + i, (STEEL, STEEL_LIGHT, STEEL, STEEL_DARK)[min(3, dx + k)])
                c.px(x + 1, h + 5, STEEL_DARK)
        if name == "gate":
            for y in (6, 22):
                for i, col in enumerate((STEEL_LIGHT, STEEL, STEEL, STEEL_DARK)):
                    c.rect(0, y + i, TT, 1, col)
                for x in (4, 14, 24):
                    c.rect(x + 1, y + 1, 2, 2, GOLD)
                    c.px(x + 1, y + 1, FLAME_HOT)
    elif name in ("plate_up", "plate_down"):
        h = 6 if name == "plate_up" else 2
        c.rect(2, TT - 2, 28, 2, STONE_DEEP if name == "plate_up" else TRIM_DARK)
        c.rect(4, TT - h - 1, 24, h, TRIM)
        c.rect(4, TT - h - 1, 24, 1, TRIM_LIGHT)
        c.rect(4, TT - h - 1, 1, h, TRIM_LIGHT)
        c.rect(27, TT - h - 1, 1, h, TRIM_DARK)
        if name == "plate_up":
            c.rect(5, TT - 3, 22, 1, TRIM_DARK)
            for x in (10, 16, 22):
                c.px(x, TT - 5, TEAL)
                c.px(x, TT - 4, SEA_DARK)
    elif name in ("lever_off", "lever_on"):
        on = name == "lever_on"
        tip = (25.0, 7.0) if on else (7.0, 7.0)

        def lever(f: Figure) -> None:
            f.shape((WOOD_LIGHT, WOOD, rgb("d39a62")), lambda d: f.capsule(d, (16, 22), tip, 1.6, 1.3), rim=0.8)
            f.shape((GREEN, GREEN_DARK, rgb("a6f0ad")) if on else (CRIMSON, CRIMSON_DARK, rgb("ef6060")),
                    lambda d: f.circle(d, tip, 3.4), rim=1.2)
        c.rect(8, 23, 16, 9, STEEL_DARK)
        c.rect(8, 23, 16, 1, STEEL_LIGHT)
        c.rect(8, 24, 1, 8, STEEL)
        c.rect(23, 24, 1, 8, INK)
        c.rect(14, 21, 4, 4, STONE_DEEP)
        for x in (10, 21):
            c.px(x, 26, STEEL_LIGHT)
            c.px(x, 29, STEEL_LIGHT)
        c.image.alpha_composite(figure((TT, TT), lever, rim=True))
        c.rect(15, 21, 2, 2, GOLD)
    elif name.startswith("torch"):
        c.rect(14, 16, 4, 14, WOOD_DARK)
        c.rect(14, 16, 1, 14, WOOD)
        c.rect(17, 16, 1, 14, WOOD_DEEP)
        c.rect(12, 30, 8, 2, STEEL_DARK)
        c.rect(12, 30, 8, 1, STEEL)
        c.rect(10, 13, 12, 4, TRIM)
        c.rect(10, 13, 12, 1, TRIM_LIGHT)
        c.rect(10, 16, 12, 1, TRIM_DARK)
        c.rect(12, 17, 8, 2, STEEL_DARK)
        if name == "torch_dark":
            c.rect(12, 10, 8, 3, STONE_DEEP)
            c.rect(13, 9, 6, 1, INK)
            c.px(15, 11, FLAME_RED)
            for x, y in ((16, 6), (15, 4), (16, 2)):
                c.px(x, y, STONE_LIGHT)
        else:
            lean = -1.6 if name == "torch_a" else 1.6

            def flame(f: Figure) -> None:
                for tone, r, top in ((FLAME_RED, 5.6, 0.0), (FLAME, 4.4, 2.5), (FLAME_HOT, 2.8, 5.5), (WHITE, 1.4, 8.5)):
                    f.shape((tone, tone, tone), lambda d, r=r, top=top: (f.circle(d, (16, 9.5), r),
                            f.poly(d, [(16 - r, 9.5), (16 + lean * (1 - top / 10), top), (16 + r, 9.5)])), rim=0)
            c.image.alpha_composite(figure((TT, TT), flame))
            c.px(16 + (5 if lean > 0 else -6), 3, FLAME)
            c.px(16 + (6 if lean > 0 else -5), 1, FLAME_RED)
    elif name == "scroll":
        c.rect(7, 8, 18, 17, PARCHMENT)
        c.rect(22, 8, 3, 17, PARCHMENT_DARK)
        c.rect(7, 8, 1, 17, rgb("f6eed2"))
        for y, w in ((11, 12), (14, 14), (17, 10), (20, 13)):
            c.rect(9, y, w, 1, WOOD_DARK)
        c.rect(19, 21, 3, 3, CRIMSON)
        c.px(19, 21, rgb("ef6060"))
        for y in (5, 24):
            c.rect(5, y, 22, 4, PARCHMENT)
            c.rect(5, y, 22, 1, rgb("f6eed2"))
            c.rect(5, y + 3, 22, 1, PARCHMENT_DARK)
            c.rect(3, y, 2, 4, WOOD)
            c.rect(27, y, 2, 4, WOOD)
            c.px(3, y, WOOD_LIGHT)
            c.px(27, y, WOOD_LIGHT)
            c.rect(3, y + 3, 2, 1, WOOD_DARK)
            c.rect(27, y + 3, 2, 1, WOOD_DARK)
    elif name == "bar":
        c.rect(0, 10, TT, 10, WOOD)
        c.rect(0, 10, TT, 1, WOOD_LIGHT)
        c.rect(0, 11, TT, 1, mix(WOOD, WOOD_LIGHT, 0.5))
        c.rect(0, 18, TT, 1, WOOD_DARK)
        c.rect(0, 19, TT, 1, WOOD_DEEP)
        rng = random.Random(13)
        for _ in range(5):
            c.rect(rng.randrange(TT), rng.randrange(12, 17), rng.randrange(3, 7), 1, WOOD_DARK)
        for x in (5, 23):
            c.rect(x, 9, 4, 12, STEEL_DARK)
            c.rect(x, 9, 4, 1, STEEL_LIGHT)
            c.rect(x, 10, 1, 11, STEEL)
            c.px(x + 2, 14, STEEL_LIGHT)
    return c.image


def paint_tiles() -> Image.Image:
    sheet = Image.new("RGBA", (CELL * len(TILES), CELL), CLEAR)
    for index, name in enumerate(TILES):
        tile = paint_tile(name)
        x = index * CELL
        # The tile, with its edge texels repeated one texel out all round.
        for dx, dy in ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)):
            sheet.alpha_composite(tile, (x + 1 + dx, 1 + dy))
        sheet.paste(tile, (x + 1, 1))
    return sheet


# --- the door ----------------------------------------------------------------

DW, DH = 48, 64


def paint_door() -> Image.Image:
    """Three frames, 48x64 texels (24x32 in the room): shut, open, barred.
    A pointed palace arch in gilt and teal."""
    sheet = Image.new("RGBA", (DW * 3, DH), CLEAR)

    def arch(d: ImageDraw.ImageDraw, f: Figure, x0: float, x1: float, spring: float, r: float) -> None:
        # Two arcs meeting in a point, over straight jambs.
        mid = (x0 + x1) / 2
        a, _ = f.mask()
        b, _ = f.mask()
        f.circle(ImageDraw.Draw(a), (x0 + r, spring), r)
        f.circle(ImageDraw.Draw(b), (x1 - r, spring), r)
        lens = ImageChops.multiply(a, b)
        d.bitmap((0, 0), lens, fill=255)
        f.poly(d, [(x0, spring), (x1, spring), (x1, DH + 1), (x0, DH + 1)])
        del mid

    for frame in range(3):
        f = Figure(size=(DW, DH))
        outer = f.shape(TONE_GOLD, lambda d: arch(d, f, 1, 47, 26, 24), rim=1.4)
        f.shape((TEAL, SEA_DARK, SEA), lambda d: arch(d, f, 5, 43, 28, 20), rim=0.8)
        inner, di = f.mask()
        arch(di, f, 8, 40, 30, 18)
        if frame == 1:
            # Open: the night outside, a crescent moon, light spilling in.
            f.image.paste(rgb("0d0a14"), (0, 0), inner)
            for y in range(DH):
                band = Image.new("L", f.size, 0)
                ImageDraw.Draw(band).rectangle((0, y * SS, f.size[0], (y + 1) * SS), fill=255)
                f.image.paste(mix(rgb("1a2148"), rgb("3a4d86"), y / DH), (0, 0), ImageChops.multiply(band, inner))
            beam, db = f.mask()
            f.poly(db, [(18, 30), (30, 30), (36, DH), (12, DH)])
            f.image.paste(rgb("5a6fa8"), (0, 0), ImageChops.multiply(beam, inner))
            core, dc = f.mask()
            f.poly(dc, [(22, 34), (26, 34), (29, DH), (19, DH)])
            f.image.paste(rgb("a9bde8"), (0, 0), ImageChops.multiply(core, inner))
            moon, dm = f.mask()
            f.circle(dm, (30, 22), 3.2)
            bite, dbt = f.mask()
            f.circle(dbt, (31.6, 21), 2.8)
            f.image.paste(PARCHMENT, (0, 0), ImageChops.subtract(moon, bite))
        else:
            f.paint(inner, (WOOD, WOOD_DARK, WOOD_LIGHT), rim=1.0)
        f.shape((CRIMSON, CRIMSON_DARK, rgb("ef6060")), lambda d: f.circle(d, (24, 6.5), 1.8), rim=0.6)
        door = finish(f.image, settle=False, rim=True)
        c = Canvas(DW, DH)
        c.image = door
        if frame != 1:
            # Planks, iron bands studded in gold, two ring pulls.
            for x in (14, 19, 29, 34):
                for y in range(14, DH):
                    if door.getpixel((x, y))[:3] == WOOD[:3] or door.getpixel((x, y))[:3] == WOOD_LIGHT[:3]:
                        c.px(x, y, WOOD_DARK)
            c.rect(23, 13, 2, DH - 13, WOOD_DEEP)
            for y in (38, 50, 60):
                c.rect(8, y, 32, 2, STEEL_DARK)
                c.rect(8, y, 32, 1, STEEL)
                for x in (11, 17, 30, 36):
                    c.px(x, y, FLAME_HOT)
                    c.px(x, y + 1, GOLD)
            for cx in (20, 27):
                for dx, dy in ((0, -2), (1, -1), (1, 0), (1, 1), (0, 2), (-1, 1), (-1, 0), (-1, -1)):
                    c.px(cx + dx, 45 + dy, GOLD if dy <= 0 else TRIM)
        if frame == 1:
            for x, y in ((14, 24), (20, 18), (34, 30), (17, 33), (25, 15)):
                c.px(x, y, PARCHMENT)
        if frame == 2:
            # Barred, with the Vizier's violet seal.
            for y in (30, 48):
                c.rect(0, y, DW, 8, WOOD_LIGHT)
                c.rect(0, y, DW, 1, PARCHMENT_DARK)
                c.rect(0, y + 6, DW, 1, WOOD_DARK)
                c.rect(0, y + 7, DW, 1, WOOD_DEEP)
                for x in (4, 40):
                    c.rect(x, y - 1, 4, 10, STEEL_DARK)
                    c.rect(x, y - 1, 4, 1, STEEL_LIGHT)
                    c.px(x + 2, y + 3, STEEL_LIGHT)
            c.rect(21, 31, 6, 6, VIOLET)
            c.rect(22, 30, 4, 8, VIOLET)
            c.rect(22, 31, 2, 2, rgb("b58ae0"))
            c.rect(25, 35, 2, 2, rgb("6a3f9a"))
        sheet.alpha_composite(c.image, (frame * DW, 0))
    return sheet


# --- the Prince --------------------------------------------------------------
#
# He is painted at twice the room's pixel density: a 64x64 frame that the game
# draws into 32x32 room pixels, so he is the same size as before but each of
# his pixels is half as big as a stone's. He is a jointed figure (hip, knees,
# ankles, shoulders, elbows) posed by angle and drawn in shapes four times
# larger, then averaged down, so his limbs taper and his edges are smooth. Each
# part is lit from the upper front in three tones. No black outline: a thin
# dark rim, only where he meets the background. The run is ten frames, paced
# by distance so his feet don't slide. See GAME.md, "How the Prince reads".

PF = 64
SS = 4
PRINCE_FRAMES = (["idle_a", "idle_b"] + [f"run{i}" for i in range(1, 11)]
                 + ["jump", "apex", "fall", "land", "dead", "dagger"])

# Base, shade, light. The far arm and leg use the darker set.
TONE_WHITE = (WHITE, WHITE_SHADE, rgb("ffffff"))
TONE_WHITE_FAR = (WHITE_SHADE, rgb("9896a8"), rgb("dcdae2"))
TONE_CUFF = (WHITE_SHADE, rgb("9896a8"), WHITE)
TONE_BLUE = (BLUE, BLUE_DARK, rgb("4b80d0"))
TONE_CRIMSON = (CRIMSON, CRIMSON_DARK, rgb("ef6060"))
TONE_CRIMSON_FAR = (CRIMSON_DARK, rgb("5e1420"), CRIMSON)
TONE_SKIN = (SKIN, SKIN_DARK, rgb("f0b98c"))
TONE_SKIN_FAR = (SKIN_DARK, rgb("8a5638"), rgb("c88a5e"))
TONE_HAIR = (HAIR, rgb("170e10"), rgb("4a3430"))
TONE_GOLD = (GOLD, TRIM, FLAME_HOT)
TONE_GEM = (TEAL, SEA_DARK, SEA)
TONE_BLADE = (FLAME_HOT, FLAME, FLAME_HOT)
LIGHT = (0.6, -0.8)

THIGH, SHIN, TORSO, UPPER_ARM, FOREARM = 15.0, 14.0, 17.0, 9.5, 8.5
SOLE = 1.6

Point = tuple[float, float]


def _dir(angle: float) -> Point:
    """A unit vector `angle` degrees from straight down, positive forward."""
    a = math.radians(angle)
    return (math.sin(a), math.cos(a))


def _add(p: Point, d: Point, k: float = 1.0) -> Point:
    return (p[0] + d[0] * k, p[1] + d[1] * k)


class Figure:
    """A frame drawn in texel coordinates, at SS times the size, optionally
    turned about a pivot (for lying down)."""

    def __init__(self, rot: float = 0.0, pivot: Point = (32.0, 40.0), size: tuple[int, int] = (PF, PF)) -> None:
        self.size = (size[0] * SS, size[1] * SS)
        self.image = Image.new("RGBA", self.size, CLEAR)
        self.rot = math.radians(rot)
        self.pivot = pivot

    def tx(self, p: Point) -> Point:
        x, y = p[0] - self.pivot[0], p[1] - self.pivot[1]
        c, s = math.cos(self.rot), math.sin(self.rot)
        return ((self.pivot[0] + x * c + y * s) * SS, (self.pivot[1] - x * s + y * c) * SS)

    def mask(self) -> tuple[Image.Image, ImageDraw.ImageDraw]:
        m = Image.new("L", self.size, 0)
        return m, ImageDraw.Draw(m)

    def circle(self, d: ImageDraw.ImageDraw, c: Point, r: float) -> None:
        x, y = self.tx(c)
        r *= SS
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)

    def capsule(self, d: ImageDraw.ImageDraw, a: Point, b: Point, ra: float, rb: float) -> None:
        steps = max(2, int(math.dist(a, b) * 4))
        for i in range(steps + 1):
            t = i / steps
            self.circle(d, (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), ra + (rb - ra) * t)

    def poly(self, d: ImageDraw.ImageDraw, points: list[Point]) -> None:
        d.polygon([self.tx(p) for p in points], fill=255)

    def paint(self, m: Image.Image, tone: tuple, clip: Image.Image | None = None, rim: float = 1.1) -> None:
        """Fill the mask in three tones: shade on the side away from the light,
        a thin highlight on the side facing it."""
        if clip is not None:
            m = ImageChops.multiply(m, clip)
        base, shade, light = tone
        sx, sy = round(LIGHT[0] * rim * SS), round(LIGHT[1] * rim * SS)
        hx, hy = round(LIGHT[0] * 0.7 * SS), round(LIGHT[1] * 0.7 * SS)
        inner = ImageChops.multiply(m, ImageChops.offset(m, sx, sy))
        edge = ImageChops.subtract(m, ImageChops.offset(m, -hx, -hy))
        self.image.paste(shade, (0, 0), m)
        self.image.paste(base, (0, 0), inner)
        self.image.paste(light, (0, 0), ImageChops.multiply(edge, inner))

    def shape(self, tone: tuple, draw: Callable, clip: Image.Image | None = None, rim: float = 1.1) -> Image.Image:
        m, d = self.mask()
        draw(d)
        self.paint(m, tone, clip, rim)
        return m


@dataclass
class Pose:
    lean: float = 2.0
    legs: tuple = ((-4, 6), (6, 8))          # (thigh, knee bend), far leg then near
    arms: tuple = ((-6, 14), (6, 20))        # (upper arm, elbow bend), far arm then near
    flow: float = 0.0                        # how far the tails stream back
    lift: float = 0.0
    breath: float = 0.0
    nod: float = 0.0
    dagger: bool = False
    rot: float = 0.0


def _legs(hip: Point, pose: Pose) -> list[tuple]:
    out = []
    for thigh, knee in pose.legs:
        k = _add(hip, _dir(thigh), THIGH)
        shin = thigh - knee
        out.append((k, _add(k, _dir(shin), SHIN), shin))
    return out


def draw_prince(pose: Pose) -> Image.Image:
    # Stand him so his lowest slipper touches the frame's bottom row.
    probe = _legs((0.0, 0.0), pose)
    hip = (32.0, PF - SOLE - max(a[1] for _, a, _ in probe) - pose.lift)
    f = Figure(pose.rot)
    legs = _legs(hip, pose)
    up = (math.sin(math.radians(pose.lean)), -math.cos(math.radians(pose.lean)))
    fwd = (-up[1], up[0])

    def at(p: Point, ahead: float, rise: float) -> Point:
        return _add(_add(p, fwd, ahead), up, rise)

    shoulder = at(hip, 0.0, TORSO + pose.breath)
    head = at(shoulder, 0.9 + pose.nod, 6.6)
    waist = at(hip, 0.0, 2.5)

    def ribbon(d: ImageDraw.ImageDraw, root: Point, length: float, r0: float, r1: float, droop: float, wave: float) -> None:
        # A ribbon trailing behind him, streaming back as he runs.
        angle = -(droop + 70.0 * pose.flow)
        p = root
        for i in range(4):
            q = _add(p, _dir(angle + wave * math.sin(i * 1.7 + pose.flow * 3.0)), length / 4)
            f.capsule(d, p, q, r0 + (r1 - r0) * i / 4, r0 + (r1 - r0) * (i + 1) / 4)
            p = q

    # Behind him: the tails of his sash and his headband.
    f.shape(TONE_CRIMSON_FAR, lambda d: ribbon(d, at(waist, -3.0, 1.0), 10.0, 1.5, 0.8, 18.0, 10.0))
    f.shape(TONE_WHITE_FAR, lambda d: ribbon(d, at(head, -4.0, 1.2), 7.5, 1.0, 0.6, 35.0, 14.0))

    def arm(d: ImageDraw.ImageDraw, root: Point, upper: float, elbow: float, sleeve: bool) -> Point:
        e = _add(root, _dir(upper), UPPER_ARM)
        h = _add(e, _dir(upper + elbow), FOREARM)
        if sleeve:
            f.capsule(d, root, e, 2.7, 2.1)
        else:
            f.capsule(d, e, h, 1.5, 1.3)
            f.circle(d, h, 1.7)
        return h

    def leg(far: bool, k: Point, a: Point, shin: float) -> None:
        # Baggy trousers gathered at the ankle.
        f.shape(TONE_WHITE_FAR if far else TONE_WHITE,
                lambda d: (f.capsule(d, hip, k, 3.8, 3.1), f.capsule(d, k, _add(a, _dir(shin), -1.0), 3.1, 3.5)))
        f.shape(TONE_WHITE_FAR if far else TONE_CUFF, lambda d: f.capsule(d, _add(a, _dir(shin), -0.6), a, 2.0, 1.7))
        # A red slipper with a curled toe: flat on the floor, else square to the shin.
        if a[1] > PF - SOLE - 1.2 - pose.lift:
            fd = (1.0, 0.0)
        else:
            s = math.radians(shin)
            fd = (math.cos(s), -math.sin(s))
        n = (-fd[1], fd[0])
        shape = [(-1.6, -0.7), (2.0, -0.9), (4.0, -0.8), (5.6, -2.2), (5.4, 0.2), (3.2, 1.5), (-1.2, SOLE), (-2.2, 0.5)]
        pts = [(a[0] + fd[0] * u + n[0] * v, a[1] + fd[1] * u + n[1] * v) for u, v in shape]
        f.shape(TONE_CRIMSON_FAR if far else TONE_CRIMSON, lambda d: f.poly(d, pts), rim=0.8)

    far_shoulder = at(shoulder, -0.8, -1.4)
    near_shoulder = at(shoulder, 0.2, -1.6)
    (fu, fe), (nu, ne) = pose.arms

    # The far arm and leg.
    f.shape(TONE_SKIN_FAR, lambda d: arm(d, far_shoulder, fu, fe, False))
    f.shape(TONE_WHITE_FAR, lambda d: arm(d, far_shoulder, fu, fe, True))
    leg(True, *legs[0])

    # Torso: a white shirt under a blue vest, trimmed in gold.
    chest = at(shoulder, 0.0, -2.0)
    torso_pts = [at(hip, 3.4, 0), at(chest, 4.3, 0), at(shoulder, 2.8, 0.8),
                 at(shoulder, -3.0, 0.8), at(chest, -3.8, 0), at(hip, -3.4, 0)]
    torso = f.shape(TONE_WHITE, lambda d: (f.poly(d, torso_pts), f.circle(d, at(shoulder, 0, -0.6), 3.3)))
    vest_pts = [at(shoulder, -4.4, 2.0), at(shoulder, 1.0, 2.0), at(chest, 1.5, 0), at(waist, 1.2, 0), at(waist, -4.4, 0)]
    f.shape(TONE_BLUE, lambda d: f.poly(d, vest_pts), clip=torso)
    f.shape(TONE_GOLD, lambda d: (f.capsule(d, at(shoulder, 1.0, 1.0), at(chest, 1.5, 0), 0.5, 0.5),
                                  f.capsule(d, at(chest, 1.5, 0), at(waist, 1.2, 0), 0.5, 0.5)), clip=torso, rim=0.4)

    # Hips and the near leg.
    f.shape(TONE_WHITE, lambda d: f.circle(d, hip, 3.9))
    leg(False, *legs[1])

    # The sash, and the Dagger of HEAD at his hip.
    f.shape(TONE_CRIMSON, lambda d: f.poly(d, [at(hip, 3.9, 0.4), at(hip, 4.0, 3.6), at(hip, -3.9, 3.6), at(hip, -4.0, 0.4)]), rim=0.8)
    if not pose.dagger:
        grip = at(hip, 2.4, 2.2)
        f.shape(TONE_GOLD, lambda d: f.capsule(d, grip, at(grip, 2.0, 2.6), 0.7, 0.6), rim=0.5)
        f.shape(TONE_GEM, lambda d: f.circle(d, at(grip, 2.2, 3.0), 0.9), rim=0.4)

    # Head: a face in profile, dark hair, a white headband.
    f.shape(TONE_SKIN, lambda d: (f.circle(d, head, 4.3), f.circle(d, at(head, 1.8, -2.4), 2.4), f.circle(d, at(head, 4.2, -0.6), 0.9)))
    face, fd_ = f.mask()
    f.circle(fd_, at(head, 2.4, -1.4), 4.1)
    hair, hd = f.mask()
    f.circle(hd, at(head, -0.7, 0.8), 4.7)
    f.capsule(hd, at(head, -3.0, 0), at(head, -3.6 - 1.2 * pose.flow, -3.8), 1.8, 1.3)
    f.paint(ImageChops.subtract(hair, face), TONE_HAIR)
    band, bd = f.mask()
    f.poly(bd, [at(head, -6, 1.0), at(head, 6, 1.6), at(head, 6, 3.0), at(head, -6, 2.4)])
    disc, dd = f.mask()
    f.circle(dd, head, 4.75)
    f.paint(band, TONE_WHITE, clip=disc, rim=0.6)
    f.shape(TONE_SKIN_FAR, lambda d: f.circle(d, at(head, -0.4, -0.4), 1.0), rim=0.5)
    f.shape((INK, INK, INK), lambda d: f.circle(d, at(head, 2.7, -0.4), 0.5))
    f.shape((SKIN_DARK, SKIN_DARK, SKIN_DARK), lambda d: f.capsule(d, at(head, 2.9, -2.3), at(head, 3.7, -2.2), 0.35, 0.35))

    # The near arm, last, and the dagger raised in it, glowing.
    tip = None
    if pose.dagger:
        hand = arm(ImageDraw.Draw(Image.new("L", (1, 1))), near_shoulder, nu, ne, False)
        point, side = _dir(nu + ne), _dir(90 + nu + ne)
        tip = _add(hand, point, 9.0)
        f.shape(TONE_BLADE, lambda d: f.capsule(d, _add(hand, point, 1.5), tip, 1.0, 0.3), rim=0.4)
        guard = _add(hand, point, 1.6)
        f.shape(TONE_GOLD, lambda d: f.capsule(d, _add(guard, side, -2.0), _add(guard, side, 2.0), 0.6, 0.6), rim=0.4)
    f.shape(TONE_SKIN, lambda d: arm(d, near_shoulder, nu, ne, False))
    f.shape(TONE_WHITE, lambda d: arm(d, near_shoulder, nu, ne, True))
    return f.image


def finish(big: Image.Image, settle: bool = True, rim: bool = True) -> Image.Image:
    """Average a big drawing down to texels, settle it on the bottom row, and
    rim it in a dark line where it meets the background."""
    small = big.convert("RGBa").reduce(SS).convert("RGBA")
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 112 else 0)
    small.putalpha(alpha)
    w, h = small.size
    bbox = alpha.getbbox()
    if settle and bbox and bbox[3] < h:
        moved = Image.new("RGBA", small.size, CLEAR)
        moved.paste(small, (0, h - bbox[3]))
        small = moved
    if not rim:
        return small
    src = small.copy()
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] == 255:
                continue
            solid = [src.getpixel((nx, ny)) for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                     if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] == 255]
            if solid:
                # The rim takes a little of the colour it borders, so it reads as shadow, not ink.
                mix = [sum(p[i] for p in solid) // len(solid) for i in range(3)]
                small.putpixel((x, y), tuple(INK[i] + (mix[i] - INK[i]) // 5 for i in range(3)) + (220,))
    return small


def run_leg(p: float) -> tuple[float, float]:
    """(thigh, knee bend) of one leg at phase p of the stride, 0 = heel strike."""
    keys = [(0.00, 30, 12), (0.10, 18, 32), (0.22, -2, 24), (0.35, -28, 18), (0.45, -40, 34),
            (0.55, -32, 82), (0.68, -4, 118), (0.80, 32, 98), (0.90, 46, 46)]
    p %= 1.0
    n = len(keys)
    for i in range(n):
        t0 = keys[i][0]
        t1 = keys[(i + 1) % n][0] + (1.0 if i == n - 1 else 0.0)
        if t0 <= p < t1:
            u = (p - t0) / (t1 - t0)
            out = []
            for j in (1, 2):
                # Catmull-Rom through the neighbouring keys, so the cycle has no corners.
                a, b, c, d = (keys[(i + k) % n][j] for k in (-1, 0, 1, 2))
                out.append(0.5 * (2 * b + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (3 * b - a - 3 * c + d) * u ** 3))
            return out[0], out[1]
    return keys[0][1], keys[0][2]


def prince_pose(name: str) -> Pose:
    if name == "idle_a":
        return Pose()
    if name == "idle_b":
        return Pose(breath=0.7, arms=((-5, 16), (7, 22)), nod=-0.2)
    if name.startswith("run"):
        p = (int(name[3:]) - 1) / 10.0
        near, far = run_leg(p), run_leg(p + 0.5)

        def swing(thigh: float) -> tuple[float, float]:
            # Each arm swings against the leg on its side, the elbow bent.
            return (-0.9 * thigh, 78 - 0.45 * thigh)

        lift = 2.0 * max(0.0, math.cos(4 * math.pi * (p - 0.45))) ** 2
        return Pose(lean=11, legs=(far, near), arms=(swing(far[0]), swing(near[0])), flow=1.0, lift=lift, nod=0.6)
    if name == "jump":
        return Pose(lean=5, legs=((-26, 48), (62, 92)), arms=((-40, 30), (115, 25)), flow=0.7, nod=0.4)
    if name == "apex":
        return Pose(lean=7, legs=((22, 92), (52, 104)), arms=((70, 40), (100, 30)), flow=0.5, nod=0.5)
    if name == "fall":
        return Pose(lean=-3, legs=((-10, 26), (20, 36)), arms=((-140, 20), (140, 28)), flow=0.3)
    if name == "land":
        return Pose(lean=24, legs=((28, 96), (56, 104)), arms=((18, 34), (38, 30)), flow=0.4, nod=0.6)
    if name == "dagger":
        return Pose(lean=-3, legs=((-15, 6), (15, 10)), arms=((-22, 22), (112, 6)), flow=0.25, dagger=True)
    if name == "dead":
        # On his back, one knee up, an arm flung past his head.
        return Pose(lean=0, legs=((8, 22), (30, 58)), arms=((-12, 20), (172, 14)), rot=90.0)
    raise ValueError(name)


def paint_prince() -> Image.Image:
    sheet = Image.new("RGBA", (PF * len(PRINCE_FRAMES), PF), CLEAR)
    for index, name in enumerate(PRINCE_FRAMES):
        sheet.alpha_composite(finish(draw_prince(prince_pose(name))), (index * PF, 0))
    return sheet


# --- the Vizier and the Princess ---------------------------------------------
#
# Painted the Prince's way (jointed shapes drawn big, averaged down, lit in
# three tones, rimmed), at the same density: two texels to a room pixel.

VW, VH = 48, 80
TONE_ROBE = (ROBE, rgb("1a1426"), ROBE_LIGHT)
TONE_MANTLE = (ROBE_LIGHT, ROBE, rgb("5c4878"))
TONE_VIOLET = (VIOLET, rgb("6a3f9a"), rgb("b58ae0"))
TONE_PALE = (PALE, rgb("b39a86"), rgb("efdccb"))
TONE_BEARD = (BLACK, INK, rgb("3a3046"))
TONE_SEA = (SEA, SEA_DARK, rgb("62d4cb"))
TONE_ROSE = (ROSE, rgb("b4567a"), rgb("f3a6bf"))


def sparkle(c: Canvas, x: int, y: int, color: tuple, big: bool) -> None:
    c.px(x, y, FLAME_HOT)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        c.px(x + dx, y + dy, color)
    if big:
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            c.px(x + dx, y + dy, color)


def paint_vizier() -> Image.Image:
    """Two frames, 48x80 texels (24x40 in the room): standing, and arms up
    as he commits."""
    sheet = Image.new("RGBA", (VW * 2, VH), CLEAR)
    for frame in range(2):
        f = Figure(size=(VW, VH))
        # A high violet collar behind his head.
        f.shape(TONE_VIOLET, lambda d: f.poly(d, [(15, 20), (33, 20), (35, 31), (13, 31)]))
        # The far sleeve, then the robe, widening to the floor.
        if frame == 0:
            sleeves = (((14, 31), (10, 55)), ((34, 31), (38, 55)))
        else:
            sleeves = (((14, 30), (5, 13)), ((34, 30), (43, 13)))
        robe = f.shape(TONE_ROBE, lambda d: f.poly(d, [(16, 28), (32, 28), (37, 56), (41, 79), (7, 79), (11, 56)]))
        for x0, x1 in ((19, 14), (29, 34), (22, 19.5), (26, 28.5)):
            f.shape(((26, 20, 38, 255),) * 3, lambda d, x0=x0, x1=x1: f.capsule(d, (x0, 38), (x1, 79), 0.4, 0.6), clip=robe)
        f.shape(TONE_VIOLET, lambda d: f.poly(d, [(22, 30), (26, 30), (29.5, 79), (18.5, 79)]), clip=robe)
        f.shape(TONE_GOLD, lambda d: (f.capsule(d, (22, 30), (18.5, 79), 0.5, 0.5), f.capsule(d, (26, 30), (29.5, 79), 0.5, 0.5)),
                clip=robe, rim=0.4)
        f.shape(TONE_GOLD, lambda d: f.poly(d, [(0, 75), (48, 75), (48, 78), (0, 78)]), clip=robe, rim=0.5)
        f.shape(TONE_GOLD, lambda d: f.poly(d, [(8, 44), (40, 44), (40, 47.5), (8, 47.5)]), clip=robe, rim=0.6)
        f.shape((CRIMSON, CRIMSON_DARK, rgb("ef6060")), lambda d: f.circle(d, (24, 45.8), 1.7), rim=0.5)
        # The mantle over his shoulders.
        f.shape(TONE_MANTLE, lambda d: (f.circle(d, (16, 31), 5.0), f.circle(d, (32, 31), 5.0),
                                        f.poly(d, [(16, 26), (32, 26), (32, 36), (16, 36)])))
        for root, end in sleeves:
            reach = (end[0] - root[0], end[1] - root[1])
            f.shape(TONE_PALE, lambda d, end=end, reach=reach: (f.circle(d, _add(end, reach, 0.3), 2.1),
                                                               f.capsule(d, end, _add(end, reach, 0.3), 1.2, 1.2)))
            sleeve = f.shape(TONE_ROBE if frame == 0 else TONE_MANTLE, lambda d, root=root, end=end: f.capsule(d, root, end, 3.4, 4.8))
            # A gold hem round the mouth of the sleeve.
            hem, hd = f.mask()
            f.circle(hd, end, 4.8)
            inside, ind = f.mask()
            f.circle(ind, _add(end, reach, -0.07), 4.8)
            f.paint(ImageChops.subtract(hem, inside), TONE_GOLD, clip=sleeve, rim=0.4)
        # A long pale face, a pointed black beard, a scowl.
        f.shape(TONE_PALE, lambda d: (f.circle(d, (24, 15), 4.6), f.circle(d, (24, 19), 4.0)))
        f.shape(TONE_BEARD, lambda d: (f.poly(d, [(19.5, 19.5), (28.5, 19.5), (28, 25), (25, 34), (23, 34), (20, 25)]),
                                       f.capsule(d, (20, 20.5), (28, 20.5), 1.0, 1.0)))
        f.shape((rgb("6e4a4a"),) * 3, lambda d: f.capsule(d, (22.5, 22.5), (25.5, 22.5), 0.45, 0.45))
        f.shape((INK,) * 3, lambda d: (f.circle(d, (21.6, 16.4), 0.6), f.circle(d, (26.4, 16.4), 0.6)))
        f.shape(TONE_BEARD, lambda d: (f.capsule(d, (19.6, 14.0), (22.8, 15.2), 0.5, 0.5), f.capsule(d, (28.4, 14.0), (25.2, 15.2), 0.5, 0.5)))
        f.shape((rgb("b39a86"),) * 3, lambda d: f.capsule(d, (24.2, 16.5), (24.6, 19.2), 0.5, 0.6))
        # A tall turban wound in violet, a ruby, a white plume.
        turban = f.shape(TONE_MANTLE, lambda d: (f.circle(d, (24, 9), 7.0), f.circle(d, (18, 10.5), 4.4),
                                                 f.circle(d, (30, 10.5), 4.4), f.circle(d, (24, 4.5), 5.2)))
        for a, b in (((16, 13), (31, 6)), ((17, 9), (29, 2.5)), ((19, 14), (33, 10))):
            f.shape(TONE_VIOLET, lambda d, a=a, b=b: f.capsule(d, a, b, 0.6, 0.6), clip=turban, rim=0.4)
        f.shape(TONE_VIOLET, lambda d: f.poly(d, [(14, 12.5), (34, 12.5), (34, 14.5), (14, 14.5)]), clip=turban, rim=0.4)
        f.shape(TONE_WHITE, lambda d: (f.capsule(d, (25, 8), (27.5, 3), 1.1, 0.8), f.capsule(d, (27.5, 3), (30, 0.6), 0.8, 0.4)), rim=0.4)
        f.shape(TONE_GOLD, lambda d: f.circle(d, (24, 9.5), 2.4), rim=0.5)
        f.shape((CRIMSON, CRIMSON_DARK, rgb("ef6060")), lambda d: f.circle(d, (24, 9.5), 1.5), rim=0.4)
        c = Canvas(VW, VH)
        c.image = finish(f.image, settle=True, rim=True)
        if frame == 1:
            for x, y, color, big in ((3, 3, VIOLET, True), (10, 4, GOLD, False), (45, 3, VIOLET, True), (38, 4, GOLD, False),
                                     (1, 13, GOLD, False), (46, 14, VIOLET, False)):
                sparkle(c, x, y, color, big)
        sheet.alpha_composite(c.image, (frame * VW, 0))
    return sheet


def paint_princess() -> Image.Image:
    """48x72 texels: the Princess, keeper of the palace ledger."""
    f = Figure(size=(48, 72))
    # A rose veil and her long dark hair, behind her.
    f.shape(TONE_ROSE, lambda d: f.poly(d, [(16, 7), (32, 7), (39, 50), (34, 52), (14, 52), (9, 50)]))
    f.shape(TONE_HAIR, lambda d: f.poly(d, [(16, 10), (32, 10), (35.5, 40), (31, 43), (28, 24), (20, 24), (17, 43), (12.5, 40)]))
    # A sea-green gown, belted high in gold.
    gown = f.shape(TONE_SEA, lambda d: f.poly(d, [(18, 27), (30, 27), (32, 37), (35, 52), (40, 71), (8, 71), (13, 52), (16, 37)]))
    for x0, x1 in ((20, 15), (28, 33), (24, 24)):
        f.shape((SEA_DARK,) * 3, lambda d, x0=x0, x1=x1: f.capsule(d, (x0, 42), (x1, 71), 0.4, 0.7), clip=gown)
    f.shape(TONE_GOLD, lambda d: f.poly(d, [(0, 66), (48, 66), (48, 69), (0, 69)]), clip=gown, rim=0.5)
    f.shape(TONE_GOLD, lambda d: f.poly(d, [(0, 34), (48, 34), (48, 36.5), (0, 36.5)]), clip=gown, rim=0.5)
    f.shape(TONE_SKIN, lambda d: (f.capsule(d, (24, 21), (24, 27), 1.9, 1.9), f.poly(d, [(20.5, 27), (27.5, 27), (24, 31)])))
    # Sleeves, and her hands folded in front.
    for shoulder, elbow in (((17.5, 28.5), (14.5, 43)), ((30.5, 28.5), (33.5, 43))):
        f.shape(TONE_SKIN, lambda d, elbow=elbow: f.capsule(d, elbow, (24, 49.5), 1.4, 1.3))
        f.shape(TONE_SEA, lambda d, shoulder=shoulder, elbow=elbow: f.capsule(d, shoulder, elbow, 2.6, 2.2))
    f.shape(TONE_SKIN, lambda d: f.circle(d, (24, 49.8), 2.1))
    # Face, fringe, a gold circlet with a teal stone.
    f.shape(TONE_SKIN, lambda d: (f.circle(d, (24, 15.5), 4.8), f.circle(d, (24, 18.5), 3.9)))
    hair, hd = f.mask()
    f.circle(hd, (24, 13), 5.5)
    face, fd = f.mask()
    f.circle(fd, (24, 17.6), 4.7)
    f.paint(ImageChops.subtract(hair, face), TONE_HAIR)
    f.shape((INK,) * 3, lambda d: (f.circle(d, (21.9, 16.3), 0.6), f.circle(d, (26.1, 16.3), 0.6)))
    f.shape((HAIR,) * 3, lambda d: (f.capsule(d, (20.6, 14.6), (22.8, 14.4), 0.35, 0.35), f.capsule(d, (25.2, 14.4), (27.4, 14.6), 0.35, 0.35)))
    f.shape((rgb("c25a72"),) * 3, lambda d: f.capsule(d, (23.0, 20.2), (25.0, 20.2), 0.5, 0.5))
    f.shape((rgb("e8957a"),) * 3, lambda d: (f.circle(d, (20.8, 18.6), 0.7), f.circle(d, (27.2, 18.6), 0.7)))
    f.shape(TONE_GOLD, lambda d: f.capsule(d, (19, 10.8), (29, 10.8), 0.6, 0.6), rim=0.4)
    f.shape(TONE_GEM, lambda d: f.circle(d, (24, 10.4), 1.2), rim=0.4)
    return finish(f.image, settle=True, rim=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {"tiles": paint_tiles(), "door": paint_door(), "prince": paint_prince(),
              "vizier": paint_vizier(), "princess": paint_princess()}
    for name, image in sheets.items():
        image.save(OUT / f"{name}.png")
        print("painted", name, image.size)
    if "--preview" in sys.argv:
        preview = ROOT / "tools" / "preview"
        preview.mkdir(parents=True, exist_ok=True)
        width = max(i.width for i in sheets.values())
        sheet = Image.new("RGBA", (width, sum(i.height + 4 for i in sheets.values())), rgb("2a3050"))
        y = 0
        for image in sheets.values():
            sheet.alpha_composite(image, (0, y))
            y += image.height + 4
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.Resampling.NEAREST).save(preview / "sheet.png")


if __name__ == "__main__":
    main()
