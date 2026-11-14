"""Paint the cast, the tiles and the door, pixel by pixel.

Everything here is drawn from scratch for this game: nothing is traced or
copied from any other game's sprites.

    python tools/paint.py            # -> assets/sprites/*.png
    python tools/paint.py --preview  # also tools/preview/sheet.png, scaled up
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

from PIL import Image

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

T = 16
TILES = ["stone", "floor", "spikes", "plank", "gate", "holes", "plate_up", "plate_down",
         "lever_off", "lever_on", "torch_dark", "torch_a", "torch_b", "scroll", "bar", "gate_tip"]


def stone(c: Canvas, seed: int, top: bool) -> None:
    rng = random.Random(seed)
    c.rect(0, 0, T, T, STONE)
    for row, y in enumerate((0, 8)):
        c.rect(0, y + 7, T, 1, STONE_DEEP)
        offset = 0 if row == 0 else 8
        for x in (offset + 3, offset + 11):
            c.rect(x % T, y, 1, 7, STONE_DEEP)
        c.rect(0, y, T, 1, STONE_LIGHT)
    for _ in range(14):
        c.px(rng.randrange(T), rng.randrange(T), rng.choice((STONE_DARK, STONE_DARK, STONE_LIGHT)))
    if top:
        c.rect(0, 0, T, 1, TRIM_LIGHT)
        c.rect(0, 1, T, 2, TRIM)
        c.rect(0, 3, T, 1, STONE_DEEP)
        for x in range(1, T, 4):
            c.rect(x, 1, 2, 1, TEAL)


def paint_tiles() -> Image.Image:
    c = Canvas(T * len(TILES), T)
    for index, name in enumerate(TILES):
        c.at(index * T, 0)
        if name == "stone":
            stone(c, 3, False)
        elif name == "floor":
            stone(c, 5, True)
        elif name == "spikes":
            for x in (0, 4, 8, 12):
                c.line(x + 1, 15, x + 2, 4, STEEL)
                c.line(x + 2, 15, x + 2, 3, WHITE)
                c.line(x + 3, 15, x + 2, 5, STEEL_DARK)
                c.px(x + 2, 3, WHITE)
            c.rect(0, 15, T, 1, INK)
        elif name == "plank":
            c.rect(0, 0, T, 5, WOOD)
            c.rect(0, 0, T, 1, WOOD_LIGHT)
            c.rect(0, 4, T, 1, WOOD_DARK)
            c.rect(7, 0, 1, 5, WOOD_DARK)
            c.rect(15, 0, 1, 5, WOOD_DARK)
            for x in (2, 11):
                c.px(x, 2, STEEL)
        elif name == "gate":
            for x in (2, 7, 12):
                c.rect(x, 0, 2, T, STEEL_DARK)
                c.rect(x, 0, 1, T, STEEL)
            for y in (3, 11):
                c.rect(0, y, T, 2, STEEL_DARK)
                c.rect(0, y, T, 1, STEEL)
        elif name == "gate_tip":
            for x in (2, 7, 12):
                c.rect(x, 0, 2, 4, STEEL_DARK)
                c.rect(x, 0, 1, 4, STEEL)
                c.px(x, 4, STEEL)
                c.px(x + 1, 4, STEEL_DARK)
                c.px(x, 5, STEEL_DARK)
        elif name == "holes":
            stone(c, 7, True)
            for x in (1, 5, 9, 13):
                c.rect(x, 1, 2, 2, INK)
        elif name in ("plate_up", "plate_down"):
            h = 3 if name == "plate_up" else 1
            c.rect(2, T - h, 12, h, TRIM)
            c.rect(2, T - h, 12, 1, TRIM_LIGHT)
            c.rect(1, T - 1, 14, 1, STONE_DEEP if name == "plate_up" else TRIM)
        elif name in ("lever_off", "lever_on"):
            c.rect(4, 12, 8, 4, STEEL_DARK)
            c.rect(4, 12, 8, 1, STEEL)
            c.rect(7, 10, 2, 3, STONE_DEEP)
            tip = 3 if name == "lever_off" else 12
            c.line(7, 11, tip, 3, WOOD_LIGHT, 2)
            c.rect(tip - 1 if name == "lever_off" else tip, 2, 3, 3, CRIMSON if name == "lever_off" else rgb("5fcf6a"))
        elif name.startswith("torch"):
            c.rect(7, 8, 2, 7, WOOD_DARK)
            c.rect(5, 7, 6, 2, TRIM)
            c.rect(5, 7, 6, 1, TRIM_LIGHT)
            c.rect(6, 9, 4, 1, STEEL_DARK)
            if name == "torch_dark":
                c.rect(6, 5, 4, 2, STONE_DEEP)
            else:
                lean = 0 if name == "torch_a" else 1
                c.rect(5, 3, 6, 4, FLAME_RED)
                c.rect(6, 2, 4, 5, FLAME)
                c.rect(6 + lean, 0, 2, 3, FLAME)
                c.rect(7, 3, 2, 4, FLAME_HOT)
                c.px(5 + 5 * lean, 1, FLAME_RED)
        elif name == "scroll":
            c.rect(3, 4, 10, 9, PARCHMENT)
            c.rect(2, 3, 12, 2, PARCHMENT_DARK)
            c.rect(2, 12, 12, 2, PARCHMENT_DARK)
            for y in (6, 8, 10):
                c.rect(5, y, 6, 1, WOOD_DARK)
            c.px(2, 3, WOOD)
            c.px(13, 3, WOOD)
        elif name == "bar":
            c.rect(0, 5, T, 5, WOOD)
            c.rect(0, 5, T, 1, WOOD_LIGHT)
            c.rect(0, 9, T, 1, WOOD_DARK)
            for x in (3, 12):
                c.rect(x, 6, 2, 3, STEEL_DARK)
    return c.image


def paint_door() -> Image.Image:
    """Three frames, 24x32: shut, open, barred."""
    w, h = 24, 32
    c = Canvas(w * 3, h)
    for frame in range(3):
        c.at(frame * w, 0)
        # The arch.
        c.rect(1, 4, 22, 28, TRIM)
        c.rect(3, 1, 18, 4, TRIM)
        c.rect(5, 0, 14, 2, TRIM)
        c.rect(1, 4, 1, 28, TRIM_LIGHT)
        c.rect(5, 0, 14, 1, TRIM_LIGHT)
        inside = rgb("0d0a14") if frame == 1 else WOOD
        c.rect(4, 6, 16, 26, inside)
        c.rect(6, 3, 12, 4, inside)
        c.rect(8, 2, 8, 2, inside)
        if frame == 1:
            # Moonlight through the open door.
            for y in range(8, 32):
                c.rect(8, y, 8, 1, rgb("28335c"))
            c.rect(10, 10, 4, 22, rgb("5a6fa8"))
            c.rect(11, 12, 2, 20, rgb("a9bde8"))
        else:
            c.rect(11, 2, 2, 30, WOOD_DARK)
            for y in (9, 17, 25):
                c.rect(4, y, 16, 1, WOOD_DARK)
                for x in (6, 16):
                    c.rect(x, y - 3, 2, 2, GOLD)
            c.rect(9, 18, 2, 3, GOLD)
            c.rect(13, 18, 2, 3, GOLD)
        if frame == 2:
            for y in (11, 21):
                c.rect(0, y, 24, 4, WOOD_LIGHT)
                c.rect(0, y, 24, 1, PARCHMENT_DARK)
                c.rect(0, y + 3, 24, 1, WOOD_DARK)
                for x in (2, 20):
                    c.rect(x, y + 1, 2, 2, STEEL)
    return c.image


# --- the Prince --------------------------------------------------------------

PW, PH = 24, 32
PRINCE_FRAMES = ["idle", "run1", "run2", "run3", "run4", "run5", "run6", "jump", "fall", "dead", "dagger"]


def prince_body(c: Canvas, bob: int, legs: tuple[tuple[int, int], tuple[int, int]], arms: tuple[int, int],
                dagger: bool = False) -> None:
    """Facing right. `legs` are (knee dx, foot dx) for the back and front leg,
    `arms` the back and front hand dx."""
    hip_x, hip_y = 11, 20 + bob
    # Back leg, then front leg: baggy white trousers and a red slipper.
    for index, (knee, foot) in enumerate(legs):
        shade = WHITE_SHADE if index == 0 else WHITE
        c.line(hip_x, hip_y, hip_x + knee, hip_y + 5, shade, 3)
        c.line(hip_x + knee, hip_y + 5, hip_x + foot, 29, shade, 3)
        c.rect(hip_x + foot, 30, 4, 2, CRIMSON_DARK if index == 0 else CRIMSON)
    # Back arm.
    c.line(10, 12 + bob, 10 + arms[0], 18 + bob, SKIN_DARK, 2)
    # Tunic and sash.
    c.rect(8, 10 + bob, 7, 9, BLUE)
    c.rect(8, 10 + bob, 2, 9, BLUE_DARK)
    c.rect(11, 10 + bob, 3, 6, WHITE)
    c.rect(8, 18 + bob, 7, 3, CRIMSON)
    c.rect(8, 20 + bob, 7, 1, CRIMSON_DARK)
    c.rect(7, 19 + bob, 2, 5, CRIMSON)
    # Head: dark hair, a white headband with a tail.
    c.rect(9, 3 + bob, 6, 6, SKIN)
    c.rect(8, 2 + bob, 7, 3, HAIR)
    c.rect(8, 4 + bob, 2, 5, HAIR)
    c.rect(8, 4 + bob, 7, 1, WHITE)
    c.rect(5, 5 + bob, 3, 1, WHITE)
    c.px(5, 6 + bob, WHITE_SHADE)
    c.px(13, 6 + bob, INK)
    c.rect(13, 8 + bob, 2, 1, SKIN_DARK)
    # Front arm.
    if dagger:
        c.line(13, 12 + bob, 17, 8 + bob, SKIN, 2)
        c.rect(18, 2 + bob, 1, 6, GOLD)
        c.rect(17, 6 + bob, 3, 1, TRIM)
        c.px(18, 1 + bob, FLAME_HOT)
    else:
        c.line(13, 12 + bob, 13 + arms[1], 18 + bob, SKIN, 2)
        # The Dagger of HEAD at his hip.
        c.rect(14, 19 + bob, 1, 4, GOLD)


def paint_prince() -> Image.Image:
    c = Canvas(PW * len(PRINCE_FRAMES), PH)
    run = [
        (((-3, -6), (3, 5)), (3, -3), 0),
        (((-2, -4), (3, 3)), (2, -2), -1),
        (((0, -1), (1, 0)), (0, 0), 0),
        (((3, 5), (-3, -6)), (-3, 3), 0),
        (((3, 3), (-2, -4)), (-2, 2), -1),
        (((1, 0), (0, -1)), (0, 0), 0),
    ]
    for index, name in enumerate(PRINCE_FRAMES):
        c.at(index * PW, 0)
        if name == "idle":
            prince_body(c, 0, ((-1, -2), (1, 0)), (-1, 1))
        elif name.startswith("run"):
            legs, arms, bob = run[int(name[3]) - 1]
            prince_body(c, bob, legs, arms)
        elif name == "jump":
            prince_body(c, -2, ((-3, -5), (4, 2)), (-3, 4))
        elif name == "fall":
            prince_body(c, -1, ((-2, -1), (2, 3)), (-4, 4))
        elif name == "dagger":
            prince_body(c, 0, ((-2, -3), (2, 1)), (-1, 0), dagger=True)
        elif name == "dead":
            # Flat on his back.
            c.rect(3, 27, 5, 4, SKIN)
            c.rect(2, 26, 3, 5, HAIR)
            c.rect(4, 26, 4, 1, WHITE)
            c.rect(8, 27, 7, 4, BLUE)
            c.rect(10, 27, 3, 2, WHITE)
            c.rect(14, 27, 2, 4, CRIMSON)
            c.rect(16, 28, 6, 3, WHITE)
            c.rect(21, 27, 2, 4, CRIMSON)
            c.px(6, 28, INK)
        c.outline(0, 0, PW, PH, INK)
    return c.image


# --- the Vizier and the Princess ---------------------------------------------

VW, VH = 24, 40


def paint_vizier() -> Image.Image:
    """Two frames: standing, and arms up as he commits."""
    c = Canvas(VW * 2, VH)
    for frame in range(2):
        c.at(frame * VW, 0)
        # The robe, widening to the floor.
        for y in range(14, 40):
            half = 4 + (y - 14) // 5
            c.rect(12 - half, y, half * 2, 1, ROBE)
            c.px(12 - half, y, ROBE_LIGHT)
        c.rect(11, 14, 2, 26, VIOLET)
        c.rect(8, 22, 8, 2, GOLD)
        # Shoulders and sleeves.
        c.rect(6, 13, 12, 3, ROBE_LIGHT)
        if frame == 0:
            c.line(6, 15, 5, 24, ROBE, 3)
            c.line(17, 15, 18, 24, ROBE, 3)
            c.rect(5, 25, 2, 2, PALE)
            c.rect(18, 25, 2, 2, PALE)
        else:
            c.line(6, 14, 2, 6, ROBE, 3)
            c.line(17, 14, 20, 6, ROBE, 3)
            c.rect(2, 4, 2, 2, PALE)
            c.rect(21, 4, 2, 2, PALE)
            c.px(1, 2, VIOLET)
            c.px(22, 2, VIOLET)
            c.px(3, 1, GOLD)
            c.px(20, 1, GOLD)
        # A long pale face, a pointed black beard, a tall dark turban.
        c.rect(9, 7, 6, 6, PALE)
        c.rect(10, 11, 4, 4, BLACK)
        c.rect(11, 15, 2, 2, BLACK)
        c.px(10, 9, INK)
        c.px(13, 9, INK)
        c.rect(9, 8, 2, 1, BLACK)
        c.rect(13, 8, 2, 1, BLACK)
        c.rect(8, 2, 8, 5, ROBE_LIGHT)
        c.rect(9, 0, 6, 3, ROBE_LIGHT)
        c.rect(8, 6, 8, 1, VIOLET)
        c.rect(11, 3, 2, 2, CRIMSON)
        c.outline(0, 0, VW, VH, INK)
    return c.image


def paint_princess() -> Image.Image:
    c = Canvas(24, 36)
    # A sea-green gown.
    for y in range(15, 36):
        half = 3 + (y - 15) // 4
        c.rect(12 - half, y, half * 2, 1, SEA)
        c.px(12 - half, y, SEA_DARK)
    c.rect(8, 22, 8, 1, GOLD)
    c.rect(9, 12, 6, 4, SEA)
    c.line(9, 13, 7, 21, SKIN, 2)
    c.line(14, 13, 16, 21, SKIN, 2)
    # Long dark hair, a small gold circlet, a rose veil.
    c.rect(8, 4, 8, 10, HAIR)
    c.rect(9, 5, 6, 6, SKIN)
    c.px(10, 7, INK)
    c.px(13, 7, INK)
    c.rect(11, 9, 2, 1, ROSE)
    c.rect(8, 3, 8, 1, GOLD)
    c.px(12, 2, GOLD)
    c.rect(6, 5, 2, 12, ROSE)
    c.outline(0, 0, 24, 36, INK)
    return c.image


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
