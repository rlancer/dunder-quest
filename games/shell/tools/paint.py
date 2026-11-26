"""Paint the Standard Inn and the people in it.

Everything is drawn here from shapes, with Pillow, so it needs no key and no
network: six rooms (480x270) and five faces (96x96). Each is drawn four
times larger, averaged down and then cut to a short palette, which is what
makes it read as pixel art rather than as a small drawing. Everyone is an
invented archetype; nobody is drawn to look like a real person.

    python tools/paint.py            # -> assets/backgrounds/*.png, assets/sprites/*.png
    python tools/paint.py pass chef  # just these
    python tools/paint.py --preview  # also tools/preview/sheet.png

The other games' rooms and casts are generated (see their tools/scenery.py).
These are stand-ins a generated set can replace, file for file.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ROOMS_OUT = ROOT / "assets" / "backgrounds"
CAST_OUT = ROOT / "assets" / "sprites"
FONT = ROOT / "assets" / "fonts" / "BebasNeue.ttf"
S = 4
W, H = 480, 270


def rgb(text: str) -> tuple[int, int, int]:
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16))


def mix(a: tuple, b: tuple, k: float) -> tuple[int, int, int]:
    return tuple(int(round(a[i] + (b[i] - a[i]) * k)) for i in range(3))


def shade(c: tuple, k: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(c[i] * k))) for i in range(3))


STEEL = rgb("8a97a6")
STEEL_DARK = rgb("4a5462")
STEEL_LIGHT = rgb("c4ced8")
TILE = rgb("d8dcd6")
NIGHT = rgb("0d1220")
AMBER = rgb("f5a030")
GREEN = rgb("23804f")
BRICK = rgb("6e3b30")
PAPER = rgb("f2f0e6")
RED = rgb("c22c22")
BLUE = rgb("274a8f")


class Paint:
    """A canvas in room pixels, drawn four times larger."""

    def __init__(self, w: int, h: int, fill: tuple | None = None) -> None:
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w * S, h * S), (*fill, 255) if fill else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x: float, y: float, w: float, h: float, c: tuple) -> None:
        self.d.rectangle([x * S, y * S, (x + w) * S - 1, (y + h) * S - 1], fill=c)

    def oval(self, x: float, y: float, w: float, h: float, c: tuple) -> None:
        self.d.ellipse([x * S, y * S, (x + w) * S - 1, (y + h) * S - 1], fill=c)

    def poly(self, points: list, c: tuple) -> None:
        self.d.polygon([(x * S, y * S) for x, y in points], fill=c)

    def line(self, points: list, c: tuple, width: float = 1.0) -> None:
        self.d.line([(x * S, y * S) for x, y in points], fill=c, width=max(1, int(width * S)), joint="curve")

    def fade(self, x: float, y: float, w: float, h: float, top: tuple, bottom: tuple) -> None:
        for i in range(int(h * S)):
            c = mix(top, bottom, i / max(1, h * S - 1))
            self.d.line([(x * S, y * S + i), ((x + w) * S - 1, y * S + i)], fill=c)

    def glow(self, x: float, y: float, r: float, c: tuple, strength: float = 0.6) -> None:
        """A soft pool of light, added on top."""
        layer = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=(*c, int(255 * strength)))
        layer = layer.filter(ImageFilter.GaussianBlur(r * S * 0.45))
        self.im.alpha_composite(layer)
        self.d = ImageDraw.Draw(self.im)

    def cone(self, x: float, y: float, spread: float, drop: float, c: tuple, strength: float = 0.35) -> None:
        layer = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon([(x * S - 3 * S, y * S), (x * S + 3 * S, y * S), ((x + spread) * S, (y + drop) * S), ((x - spread) * S, (y + drop) * S)],
                                      fill=(*c, int(255 * strength)))
        layer = layer.filter(ImageFilter.GaussianBlur(3 * S))
        self.im.alpha_composite(layer)
        self.d = ImageDraw.Draw(self.im)

    def text(self, x: float, y: float, words: str, size: float, c: tuple) -> None:
        self.d.text((x * S, y * S), words, font=ImageFont.truetype(str(FONT), int(size * S)), fill=c)

    def done(self, colors: int) -> Image.Image:
        small = self.im.resize((self.w, self.h), Image.Resampling.BOX)
        alpha = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
        flat = small.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
        flat.putalpha(alpha)
        return flat


# --- Rooms -------------------------------------------------------------------

def tiles(p: Paint, x: float, y: float, w: float, h: float, base: tuple, size: float = 8.0) -> None:
    p.rect(x, y, w, h, base)
    grout = shade(base, 0.86)
    row = 0
    yy = y
    while yy < y + h:
        p.rect(x, yy, w, 0.6, grout)
        xx = x + (size / 2 if row % 2 else 0)
        while xx < x + w:
            p.rect(xx, yy, 0.6, min(size / 2, y + h - yy), grout)
            xx += size
        yy += size / 2
        row += 1


def counter(p: Paint, x: float, y: float, w: float, h: float) -> None:
    p.rect(x, y, w, h, STEEL_DARK)
    p.rect(x, y, w, 4, STEEL_LIGHT)
    p.rect(x, y + 4, w, 2, STEEL)
    p.fade(x, y + 6, w, h - 6, shade(STEEL, 0.8), shade(STEEL_DARK, 0.7))
    xx = x + 30
    while xx < x + w - 10:
        p.rect(xx, y + 10, 0.8, h - 14, shade(STEEL_DARK, 0.6))
        p.rect(xx - 8, y + 14, 5, 1.2, STEEL_LIGHT)
        xx += 62


def tub(p: Paint, x: float, y: float, w: float, h: float, c: tuple, rng: random.Random) -> None:
    """A container with a strip of green tape for a label."""
    p.rect(x, y, w, h, c)
    p.rect(x, y, w, 1.5, shade(c, 1.25))
    p.rect(x + w - 1.5, y, 1.5, h, shade(c, 0.75))
    p.rect(x + 2, y + h * 0.4, w - 5, 3, GREEN)
    p.rect(x + 3, y + h * 0.4 + 1, rng.uniform(2, w - 8), 0.8, shade(GREEN, 0.45))


def hood(p: Paint, x: float, y: float, w: float) -> None:
    p.poly([(x, y + 26), (x + 14, y), (x + w - 14, y), (x + w, y + 26)], STEEL)
    p.poly([(x, y + 26), (x + 14, y), (x + 20, y), (x + 8, y + 26)], STEEL_LIGHT)
    p.rect(x, y + 26, w, 6, STEEL_DARK)
    p.rect(x, y + 26, w, 1.2, STEEL_LIGHT)


def kitchen() -> Paint:
    rng = random.Random(7)
    p = Paint(W, H)
    tiles(p, 0, 0, W, 150, TILE)
    p.fade(0, 0, W, 40, shade(TILE, 0.72), TILE)
    hood(p, 150, 0, 230)
    # A shelf of labelled tubs, and pans hanging under it.
    p.rect(14, 62, 126, 3, STEEL_DARK)
    x = 18.0
    for c in [rgb("e8e2d0"), rgb("c9d6dd"), rgb("e3c9a0"), rgb("d7dfc4"), rgb("e8e2d0"), rgb("c9d6dd")]:
        tub(p, x, 44, 17, 18, c, rng)
        x += 20
    for i, r in enumerate([11, 9, 12]):
        cx = 400 + i * 26
        p.rect(cx - 0.6, 36, 1.2, 14, STEEL_DARK)
        p.oval(cx - r, 48, r * 2, r * 2, shade(STEEL_DARK, 0.7))
        p.oval(cx - r + 2, 50, r * 2 - 4, r * 2 - 4, shade(STEEL_DARK, 0.95))
    p.rect(388, 34, 86, 2.5, STEEL_DARK)
    # The range: burners, a flat-top, a pot.
    p.rect(150, 118, 230, 34, shade(STEEL_DARK, 0.75))
    p.rect(150, 116, 230, 3, STEEL_LIGHT)
    for i in range(4):
        p.oval(166 + i * 30, 110, 22, 7, rgb("1a1c20"))
        p.oval(170 + i * 30, 111.5, 14, 4, rgb("2b6fd6") if i != 2 else rgb("1a1c20"))
    p.rect(292, 108, 80, 8, rgb("2a2d33"))
    p.rect(292, 108, 80, 1.5, rgb("5a606a"))
    p.rect(194, 88, 26, 22, STEEL)
    p.rect(194, 88, 26, 3, STEEL_LIGHT)
    p.rect(188, 93, 6, 2.5, STEEL_DARK)
    p.rect(220, 93, 6, 2.5, STEEL_DARK)
    for i in range(3):
        p.line([(200 + i * 7, 84), (198 + i * 7, 76), (202 + i * 7, 68)], (235, 238, 240), 1.0)
    for i in range(5):
        p.oval(160 + i * 9, 136, 5, 5, shade(STEEL, 0.6))
    # The floor and the counters in front.
    p.fade(0, 150, W, 120, rgb("5b3a2e"), rgb("2c1c18"))
    for i in range(12):
        p.line([(240 + (i - 6) * 26, 150), (240 + (i - 6) * 70, 270)], rgb("3a241d"), 0.8)
    for y in [166, 190, 226]:
        p.rect(0, y, W, 0.8, rgb("3a241d"))
    counter(p, 0, 138, 140, 70)
    counter(p, 390, 138, 90, 70)
    # A cutting board, a knife, a stack of plates, squeeze bottles.
    p.rect(24, 132, 52, 6, rgb("d2a468"))
    p.rect(24, 132, 52, 1.5, rgb("e8c088"))
    p.poly([(46, 131), (74, 129), (74, 131.5)], STEEL_LIGHT)
    p.rect(36, 129.5, 11, 2.5, rgb("22252b"))
    for i in range(5):
        p.oval(92, 131 - i * 2.4, 34, 6, shade(PAPER, 1.0 - i * 0.02))
    for i, c in enumerate([RED, rgb("e8c23a"), PAPER]):
        p.rect(404 + i * 13, 120, 8, 18, c)
        p.poly([(406 + i * 13, 120), (408 + i * 13, 112), (410 + i * 13, 120)], c)
    tub(p, 446, 122, 24, 16, rgb("c9d6dd"), rng)
    p.glow(265, 60, 150, rgb("fff0cc"), 0.16)
    return p


def pass_room() -> Paint:
    rng = random.Random(11)
    p = Paint(W, H)
    # Beyond the pass: the kitchen, out of focus.
    tiles(p, 0, 0, W, 130, shade(TILE, 0.78))
    hood(p, 120, 0, 240)
    p.rect(120, 96, 240, 34, shade(STEEL_DARK, 0.7))
    for i in range(4):
        p.oval(140 + i * 54, 90, 30, 8, rgb("15171b"))
    p.glow(194, 86, 16, rgb("4a8cff"), 0.5)
    p.glow(302, 86, 16, rgb("4a8cff"), 0.5)
    p.im = p.im.filter(ImageFilter.GaussianBlur(1.3 * S))
    p.d = ImageDraw.Draw(p.im)
    # The shelf over the pass: heat lamps and the ticket rail.
    p.rect(0, 22, W, 9, STEEL_DARK)
    p.rect(0, 22, W, 2, STEEL_LIGHT)
    p.rect(0, 31, W, 2.5, shade(STEEL_DARK, 0.6))
    for i in range(5):
        cx = 48 + i * 96
        p.rect(cx - 0.8, 33, 1.6, 12, shade(STEEL_DARK, 0.6))
        p.poly([(cx - 13, 56), (cx - 7, 45), (cx + 7, 45), (cx + 13, 56)], shade(AMBER, 0.55))
        p.rect(cx - 12, 55, 24, 2, AMBER)
        p.cone(cx, 57, 44, 84, rgb("ffb648"), 0.32)
    p.rect(0, 34, W, 2, rgb("d9dde2"))
    x = 14.0
    while x < W - 20:
        if rng.random() < 0.8:
            h = rng.uniform(26, 46)
            w = 17
            p.rect(x, 36, w, h, PAPER)
            p.rect(x + w - 1.5, 36, 1.5, h, shade(PAPER, 0.85))
            yy = 40.0
            while yy < 36 + h - 4:
                p.rect(x + 2, yy, rng.uniform(6, w - 5), 0.9, rgb("6b6f76"))
                yy += 3.2
            if rng.random() < 0.3:
                p.rect(x + 2, 38, 8, 1.6, RED)
        x += rng.choice([19, 21, 34])
    # The pass itself: a steel shelf, plates waiting, the bell.
    p.rect(0, 140, W, 7, STEEL_LIGHT)
    p.rect(0, 147, W, 3, STEEL)
    p.fade(0, 150, W, 120, shade(STEEL_DARK, 0.85), shade(STEEL_DARK, 0.45))
    for cx, food in [(90, rgb("9a5a2c")), (200, rgb("c88a3a")), (318, rgb("9a5a2c"))]:
        p.oval(cx - 30, 130, 60, 13, shade(PAPER, 0.8))
        p.oval(cx - 28, 129, 56, 11, PAPER)
        p.oval(cx - 16, 124, 32, 10, food)
        p.oval(cx - 15, 121, 30, 7, rgb("e2b56e"))
        p.rect(cx - 9, 123, 18, 2, rgb("5e8c3a"))
    p.oval(408, 128, 26, 13, rgb("b8891f"))
    p.oval(410, 121, 22, 16, rgb("e6b93a"))
    p.oval(414, 122, 7, 4, rgb("fff0b0"))
    p.rect(419.5, 117, 3, 5, rgb("8a6410"))
    p.rect(0, 150, W, 1, shade(STEEL_DARK, 0.5))
    return p


def walkin() -> Paint:
    rng = random.Random(3)
    p = Paint(W, H)
    p.fade(0, 0, W, 200, rgb("b9cdd8"), rgb("8ea6b6"))
    for x in range(0, W, 48):
        p.rect(x, 0, 1, 200, rgb("7e96a6"))
        p.rect(x + 1, 0, 1, 200, rgb("d2e0e8"))
    p.fade(0, 196, W, 74, rgb("5d6e7a"), rgb("38444e"))
    for i in range(10):
        p.line([(240 + (i - 5) * 30, 196), (240 + (i - 5) * 80, 270)], rgb("46535d"), 0.8)
    # Wire shelves, three high, with everything labelled.
    for shelf, y in enumerate([54, 104, 154]):
        x = 16.0
        while x < W - 30:
            kind = rng.random()
            if kind < 0.55:
                w, h = rng.choice([(22, 22), (26, 18), (18, 26)])
                tub(p, x, y - h, w, h, rng.choice([rgb("e8eef0"), rgb("d5e2ea"), rgb("f0e8d6"), rgb("dfe9d8")]), rng)
            elif kind < 0.8:
                w, h = 34, 24
                p.rect(x, y - h, w, h, rgb("b08a5a"))
                p.rect(x, y - h, w, 2, rgb("c9a777"))
                p.rect(x + w / 2 - 1, y - h, 2, h, rgb("8f6e44"))
                p.rect(x + 4, y - h + 8, 12, 3, GREEN)
            else:
                w = 20
                for i in range(3):
                    p.oval(x + i * 2, y - 12 - i * 9, 16, 12, rng.choice([rgb("c5462c"), rgb("d8a23a"), rgb("6c9a3c")]))
            x += w + rng.uniform(4, 12)
        p.rect(8, y, W - 16, 2.5, rgb("e6edf1"))
        p.rect(8, y + 2.5, W - 16, 1.2, rgb("6f8494"))
        for xx in range(10, W - 8, 6):
            p.rect(xx, y + 3.7, 0.8, 2.5, rgb("9fb2bf"))
    for x in [8, 162, 316, 468]:
        p.rect(x, 20, 3, 178, rgb("dfe7ec"))
        p.rect(x + 3, 20, 1.2, 178, rgb("6f8494"))
    p.rect(200, 0, 80, 5, rgb("f4fbff"))
    p.glow(240, 6, 150, rgb("dff2ff"), 0.3)
    return p


def skyline(p: Paint, base: float, rng: random.Random, color: tuple, lit: tuple, tall: float, x0: float = 0, x1: float = W) -> None:
    x = x0
    while x < x1:
        w = rng.uniform(16, 38)
        h = rng.uniform(tall * 0.35, tall)
        p.rect(x, base - h, w, h, color)
        if rng.random() < 0.3:
            p.rect(x + w / 2 - 1, base - h - 8, 2, 8, color)
        wy = base - h + 4
        while wy < base - 4:
            wx = x + 3
            while wx < x + w - 3:
                if rng.random() < 0.42:
                    p.rect(wx, wy, 2, 2.5, lit)
                wx += 5
            wy += 6
        x += w + rng.uniform(0, 4)


def tracks(p: Paint, y: float, color: tuple) -> None:
    """The elevated line: a deck on riveted legs."""
    p.rect(0, y, W, 8, color)
    p.rect(0, y, W, 1.5, shade(color, 1.5))
    for x in range(0, W, 12):
        p.rect(x, y + 8, 1.5, 5, color)
    p.rect(0, y + 13, W, 2.5, color)
    for x in range(40, W, 130):
        p.rect(x, y + 15, 7, H, color)
        p.line([(x + 3, y + 15), (x + 34, y + 52)], color, 2.0)
        p.line([(x + 3, y + 15), (x - 28, y + 52)], color, 2.0)


def train(p: Paint, x: float, y: float, cars: int) -> None:
    for i in range(cars):
        cx = x + i * 66
        p.rect(cx, y, 62, 17, rgb("9aa4b0"))
        p.rect(cx, y, 62, 3, rgb("c9d1da"))
        p.rect(cx, y + 12, 62, 2, rgb("b83a2e"))
        for k in range(5):
            p.rect(cx + 5 + k * 11, y + 4.5, 8, 6, rgb("ffd98a"))


def city() -> Paint:
    rng = random.Random(5)
    p = Paint(W, H)
    p.fade(0, 0, W, 150, rgb("1c2550"), rgb("e27a4a"))
    p.oval(330, 110, 44, 44, rgb("ffc86a"))
    p.glow(352, 132, 70, rgb("ffb060"), 0.35)
    skyline(p, 150, rng, rgb("3c3a66"), rgb("f2b062"), 96)
    skyline(p, 150, random.Random(9), rgb("201f3c"), rgb("ffd98a"), 62)
    # The lake, with the sun laid across it.
    p.fade(0, 150, W, 120, rgb("3b3f7a"), rgb("121632"))
    for i in range(26):
        y = 154 + i * 4.4
        w = rng.uniform(10, 46) * (1 + i * 0.06)
        p.rect(352 - w / 2 + rng.uniform(-6, 6), y, w, 1.2, rgb("f6a45c") if i % 3 else rgb("ffd9a0"))
    tracks(p, 118, rgb("11131f"))
    train(p, 60, 101, 3)
    return p


def title() -> Paint:
    rng = random.Random(2)
    p = Paint(W, H)
    p.fade(0, 0, W, H, rgb("0a0f22"), rgb("1b2244"))
    for _ in range(70):
        p.rect(rng.uniform(0, W), rng.uniform(0, 110), 1, 1, rgb("9aa6d8"))
    skyline(p, 230, random.Random(8), rgb("131831"), rgb("8a7448"), 62, 236, W)
    tracks(p, 12, rgb("070912"))
    # The Standard Inn: brick, a striped awning, a lit window, the sign.
    p.rect(0, 40, 236, 190, BRICK)
    yy = 40.0
    row = 0
    while yy < 230:
        p.rect(0, yy, 236, 0.7, shade(BRICK, 0.72))
        xx = 6.0 if row % 2 else 0.0
        while xx < 236:
            p.rect(xx, yy, 0.7, 5, shade(BRICK, 0.72))
            xx += 12
        yy += 5
        row += 1
    p.rect(236, 40, 4, 190, shade(BRICK, 0.55))
    p.rect(0, 40, 240, 5, shade(BRICK, 0.6))
    p.rect(20, 56, 196, 34, rgb("12141c"))
    p.rect(20, 56, 196, 34, rgb("12141c"))
    p.rect(22, 58, 192, 30, rgb("1c1f2a"))
    p.text(31, 60, "THE STANDARD INN", 26, rgb("ffb648"))
    p.glow(118, 73, 78, rgb("ff9a30"), 0.22)
    for i in range(14):
        p.poly([(14 + i * 15, 100), (29 + i * 15, 100), (25 + i * 15, 120), (10 + i * 15, 120)], RED if i % 2 else PAPER)
    p.rect(10, 120, 212, 3, shade(RED, 0.6))
    p.rect(28, 128, 118, 76, rgb("ffcf7a"))
    p.fade(28, 128, 118, 76, rgb("ffe2a0"), rgb("f09c3c"))
    p.rect(28, 128, 118, 3, rgb("3a2a22"))
    p.rect(86, 128, 3, 76, rgb("3a2a22"))
    # Inside: the pass, and somebody at it.
    p.rect(34, 176, 46, 3, rgb("7a4a22"))
    p.oval(48, 150, 14, 15, rgb("5a3420"))
    p.rect(44, 164, 22, 14, rgb("f4efe2"))
    p.oval(104, 153, 13, 14, rgb("5a3420"))
    p.rect(100, 166, 21, 12, rgb("2f4f96"))
    p.rect(92, 180, 50, 3, rgb("7a4a22"))
    p.rect(160, 130, 50, 96, rgb("3a2a22"))
    p.rect(164, 134, 42, 60, rgb("f0a850"))
    p.rect(200, 180, 3, 8, rgb("d8b060"))
    p.rect(172, 142, 26, 13, PAPER)
    p.text(175, 143.5, "OPEN", 9, RED)
    p.glow(88, 170, 90, rgb("ffb050"), 0.22)
    # The pavement, wet under the lamps.
    p.fade(0, 230, W, 40, rgb("272a3a"), rgb("10121c"))
    p.rect(0, 230, W, 2, rgb("4a4e62"))
    for i in range(18):
        p.rect(rng.uniform(20, 220), 236 + i * 1.8, rng.uniform(8, 40), 0.9, rgb("d98a3a"))
    p.rect(452, 150, 3, 82, rgb("0c0e18"))
    p.rect(440, 148, 27, 3, rgb("0c0e18"))
    p.oval(436, 150, 12, 6, rgb("ffe0a0"))
    p.cone(442, 154, 30, 78, rgb("ffd080"), 0.16)
    return p


def dining() -> Paint:
    rng = random.Random(4)
    p = Paint(W, H)
    p.fade(0, 0, W, 170, rgb("3a1f24"), rgb("5a2e2c"))
    p.rect(0, 112, W, 58, rgb("2c1a1c"))
    p.rect(0, 110, W, 3, rgb("7a4a34"))
    for x in range(0, W, 30):
        p.rect(x, 113, 1, 57, rgb("241416"))
    # A window on the night, and the train going by.
    p.rect(40, 24, 150, 74, rgb("7a4a34"))
    p.fade(44, 28, 142, 66, rgb("101634"), rgb("2a3566"))
    skyline(p, 94, random.Random(12), rgb("0b0f22"), rgb("f2b062"), 44, 44, 186)
    p.rect(113, 28, 3, 66, rgb("7a4a34"))
    p.rect(44, 60, 142, 2.5, rgb("7a4a34"))
    for cx in [250, 330, 410]:
        p.rect(cx - 16, 30, 32, 40, rgb("1c1012"))
        p.rect(cx - 13, 33, 26, 34, rng.choice([rgb("8a5a3a"), rgb("5a6a7a"), rgb("7a6a4a")]))
        p.oval(cx - 7, 42, 14, 14, rgb("d8c9a8"))
    p.fade(0, 170, W, 100, rgb("4a2a22"), rgb("1e1210"))
    for i in range(12):
        p.line([(240 + (i - 6) * 28, 170), (240 + (i - 6) * 76, 270)], rgb("382018"), 0.8)
    # Tables under lamps; table one in front, set for one.
    for cx, y, k in [(70, 150, 0.7), (410, 150, 0.7), (240, 176, 1.0)]:
        p.line([(cx, 0), (cx, 58 if k < 1 else 70)], rgb("14090a"), 1.0)
        top = 58 if k < 1 else 70
        p.poly([(cx - 12 * k, top + 12 * k), (cx - 5 * k, top), (cx + 5 * k, top), (cx + 12 * k, top + 12 * k)], rgb("b8891f"))
        p.cone(cx, top + 12 * k, 60 * k, y - top, rgb("ffcf80"), 0.22)
        w = 110 * k
        p.oval(cx - w / 2, y - 9 * k, w, 22 * k, PAPER)
        p.poly([(cx - w / 2, y + 2 * k), (cx + w / 2, y + 2 * k), (cx + w / 2 - 8 * k, y + 60 * k), (cx - w / 2 + 8 * k, y + 60 * k)], shade(PAPER, 0.86))
        p.oval(cx - w / 2, y - 9 * k, w, 20 * k, PAPER)
        p.oval(cx - 16 * k, y - 4 * k, 32 * k, 9 * k, shade(PAPER, 0.88))
        p.rect(cx + 24 * k, y - 12 * k, 3 * k, 12 * k, rgb("f0e6c8"))
        p.oval(cx + 23 * k, y - 17 * k, 5 * k, 7 * k, rgb("ffb648"))
        p.glow(cx + 25.5 * k, y - 14 * k, 10 * k, rgb("ffb648"), 0.5)
    p.rect(206, 164, 1.2, 12, STEEL_LIGHT)
    p.rect(274, 164, 1.2, 12, STEEL_LIGHT)
    p.poly([(214, 152), (230, 152), (226, 166), (218, 166)], rgb("f4f0e6"))
    return p


ROOMS = {"kitchen": kitchen, "pass": pass_room, "walkin": walkin, "city": city, "title": title, "dining": dining}


# --- Faces -------------------------------------------------------------------

def face(spec: dict) -> Paint:
    """A head and shoulders, 96x96, lit from the upper left."""
    p = Paint(96, 96)
    skin = rgb(spec["skin"])
    dark = shade(skin, 0.78)
    wide = spec.get("wide", 1.0)
    # Shoulders and what they're wearing.
    top = rgb(spec["top"])
    sw = 34 * wide
    p.poly([(48 - sw - 6, 96), (48 - sw, 76), (48 - 12, 68), (48 + 12, 68), (48 + sw, 76), (48 + sw + 6, 96)], top)
    p.poly([(48 + 12, 68), (48 + sw, 76), (48 + sw + 6, 96), (48 + sw - 8, 96)], shade(top, 0.8))
    if "apron" in spec:
        apron = rgb(spec["apron"])
        p.poly([(48 - 15, 96), (48 - 13, 76), (48 + 13, 76), (48 + 15, 96)], apron)
        p.line([(48 - 13, 76), (48 - 9, 66)], apron, 2.0)
        p.line([(48 + 13, 76), (48 + 9, 66)], apron, 2.0)
        p.rect(48 + 5, 76, 9, 20, shade(apron, 0.82))
    if spec.get("collar"):
        c = rgb(spec["collar"])
        p.poly([(48 - 12, 70), (48, 80), (48 - 4, 84), (48 - 16, 74)], c)
        p.poly([(48 + 12, 70), (48, 80), (48 + 4, 84), (48 + 16, 74)], shade(c, 0.85))
    if spec.get("scarf"):
        c = rgb(spec["scarf"])
        p.oval(48 - 17, 64, 34, 14, c)
        p.poly([(48 - 4, 72), (48 + 8, 72), (48 + 12, 94), (48 - 2, 94)], shade(c, 0.85))
    if spec.get("chain"):
        p.line([(48 - 10, 70), (48, 80), (48 + 10, 70)], rgb("e6b93a"), 1.2)
    if spec.get("phones"):
        p.line([(48 - 15, 70), (48 - 17, 78), (48 + 17, 78), (48 + 15, 70)], rgb("22252b"), 3.0)
        p.oval(48 - 21, 70, 9, 12, rgb("3a3f48"))
        p.oval(48 + 12, 70, 9, 12, rgb("3a3f48"))
    # Neck and head.
    p.rect(48 - 8, 56, 16, 16, dark)
    hw = 21 * wide
    hy = spec.get("head_y", 20)
    p.oval(48 - hw, hy, hw * 2, 46, skin)
    p.oval(48 + hw - 9, hy + 8, 9, 30, dark)
    p.oval(48 - hw - 3, hy + 20, 6, 10, skin)
    p.oval(48 + hw - 3, hy + 20, 6, 10, dark)
    # Hair, hat, whatever's on top.
    hair = rgb(spec["hair"])
    style = spec["style"]
    if style == "messy":
        p.oval(48 - hw - 1, hy - 5, hw * 2 + 2, 24, hair)
        for i in range(7):
            x = 48 - hw + i * (hw * 2 / 6)
            p.poly([(x - 4, hy + 6), (x + 1, hy - 9 + (i % 2) * 3), (x + 5, hy + 7)], hair)
        p.rect(48 - hw - 1, hy + 8, 4, 12, hair)
        p.rect(48 + hw - 3, hy + 8, 4, 12, shade(hair, 0.8))
    elif style == "wrap":
        wrap = rgb(spec["wrap"])
        p.oval(48 - hw - 2, hy - 7, hw * 2 + 4, 26, wrap)
        p.rect(48 - hw - 1, hy + 8, hw * 2 + 2, 6, shade(wrap, 0.82))
        p.poly([(48 + hw - 2, hy + 6), (48 + hw + 10, hy + 2), (48 + hw + 7, hy + 14), (48 + hw - 2, hy + 12)], wrap)
        p.rect(48 - hw, hy + 14, 4, 12, hair)
        p.rect(48 + hw - 4, hy + 14, 4, 12, hair)
    elif style == "bald":
        p.oval(48 - hw - 3, hy + 10, 9, 20, hair)
        p.oval(48 + hw - 6, hy + 10, 9, 20, hair)
        p.oval(48 - 9, hy + 3, 12, 5, shade(skin, 1.12))
    elif style == "beanie":
        cap = rgb(spec["wrap"])
        p.oval(48 - hw - 1, hy - 9, hw * 2 + 2, 28, cap)
        p.rect(48 - hw - 2, hy + 7, hw * 2 + 4, 8, shade(cap, 0.8))
        for i in range(8):
            p.rect(48 - hw + i * (hw * 2 / 8), hy + 7, 1, 8, shade(cap, 0.65))
    elif style == "bob":
        p.oval(48 - hw - 4, hy - 6, hw * 2 + 8, 30, hair)
        p.rect(48 - hw - 4, hy + 8, 9, 32, hair)
        p.rect(48 + hw - 5, hy + 8, 9, 32, shade(hair, 0.85))
        p.poly([(48 - hw, hy + 4), (48 + hw - 4, hy + 2), (48 + 6, hy + 14), (48 - hw, hy + 15)], shade(hair, 1.08))
    # Brows, eyes, nose, mouth.
    ey = hy + 22
    brow = shade(hair, 0.7) if style != "bald" else rgb("6a6a6a")
    tilt = spec.get("brow", 0)
    for side in (-1, 1):
        ex = 48 + side * 9 * wide
        lift = spec.get("raise", 0) if side == 1 else 0
        p.line([(ex - 5, ey - 6 + side * tilt - lift), (ex + 5, ey - 6 - side * tilt - lift)], brow, 1.6)
        p.oval(ex - 3.5, ey - 2.5, 7, 5.5 * spec.get("eyes", 1.0), (250, 248, 240))
        p.oval(ex - 1.6, ey - 1.6, 3.4, 3.6, rgb("20140f"))
        if spec.get("tired"):
            p.line([(ex - 4, ey + 4.5), (ex + 4, ey + 4.5)], dark, 1.0)
    if spec.get("glasses"):
        g = rgb(spec["glasses"])
        for side in (-1, 1):
            ex = 48 + side * 9 * wide
            p.line([(ex - 6, ey - 4), (ex + 6, ey - 4), (ex + 6, ey + 5), (ex - 6, ey + 5), (ex - 6, ey - 4)], g, 1.2)
        p.line([(48 - 3, ey), (48 + 3, ey)], g, 1.2)
    p.line([(48 + 1, ey + 2), (48 + 3, ey + 10), (48 - 1, ey + 11)], dark, 1.3)
    my = hy + 37
    mouth = spec["mouth"]
    lip = rgb(spec.get("lip", "7a3a34"))
    if mouth == "flat":
        p.line([(48 - 6, my), (48 + 6, my)], lip, 1.6)
    elif mouth == "smile":
        p.line([(48 - 7, my - 1), (48 - 3, my + 1.5), (48 + 3, my + 1.5), (48 + 7, my - 1)], lip, 1.6)
    elif mouth == "shout":
        p.oval(48 - 7, my - 3, 14, 10, rgb("4a1c1c"))
        p.rect(48 - 5, my - 2.5, 10, 2.2, (250, 248, 240))
    elif mouth == "purse":
        p.oval(48 - 4, my - 2, 8, 4.5, lip)
    if spec.get("tache"):
        t = rgb(spec["tache"])
        p.poly([(48 - 12, my - 2), (48 - 3, my - 7), (48, my - 5), (48 + 3, my - 7), (48 + 12, my - 2), (48 + 3, my - 3), (48, my - 2), (48 - 3, my - 3)], t)
    if spec.get("stubble"):
        for i in range(26):
            a = math.pi * (0.1 + 0.8 * i / 25)
            p.rect(48 + math.cos(a) * hw * 0.78, hy + 30 + math.sin(a) * 12, 1, 1, shade(skin, 0.6))
    return p


CAST = {
    "chef": {"skin": "e0b08c", "top": "f2efe6", "apron": "274a8f", "hair": "3a2a22", "style": "messy", "mouth": "flat", "tired": True, "stubble": True, "brow": 1},
    "shell": {"skin": "a9744f", "top": "f2efe6", "collar": "f2efe6", "hair": "1c1512", "style": "wrap", "wrap": "23804f", "mouth": "smile", "lip": "7a2f2c"},
    "awk": {"skin": "d79a78", "top": "7a1f26", "collar": "f2efe6", "chain": True, "hair": "9a9a98", "style": "bald", "mouth": "shout", "tache": "8a8a88",
            "wide": 1.16, "brow": -2, "eyes": 1.2},
    "dev": {"skin": "c48a62", "top": "2a2d33", "apron": "3d4450", "phones": True, "hair": "1c1512", "style": "beanie", "wrap": "c9772a", "mouth": "flat", "eyes": 0.7},
    "root": {"skin": "ecc9ae", "top": "1c1c24", "scarf": "8a1f3a", "hair": "d8d8dc", "style": "bob", "mouth": "purse", "lip": "b0202c", "glasses": "1c1c24",
             "raise": 3, "wide": 0.94},
}


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ROOMS_OUT.mkdir(parents=True, exist_ok=True)
    CAST_OUT.mkdir(parents=True, exist_ok=True)
    made: list[Image.Image] = []
    for name, room in ROOMS.items():
        if args and name not in args:
            continue
        image = room().done(56)
        image.save(ROOMS_OUT / f"{name}.png")
        made.append(image)
        print("room", name)
    for name, spec in CAST.items():
        if args and name not in args:
            continue
        image = face(spec).done(20)
        image.save(CAST_OUT / f"{name}.png")
        made.append(image)
        print("face", name)
    if "--preview" in sys.argv and made:
        sheet = Image.new("RGBA", (W * 3, H * 2 + 96 * 2), (20, 24, 30, 255))
        for i, image in enumerate(im for im in made if im.size == (W, H)):
            sheet.alpha_composite(image, (W * (i % 3), H * (i // 3)))
        for i, image in enumerate(im for im in made if im.size != (W, H)):
            sheet.alpha_composite(image.resize((192, 192), Image.Resampling.NEAREST), (200 * i, H * 2))
        out = ROOT / "tools" / "preview"
        out.mkdir(exist_ok=True)
        sheet.save(out / "sheet.png")


if __name__ == "__main__":
    main()
