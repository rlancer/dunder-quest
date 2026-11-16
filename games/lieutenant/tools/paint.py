"""Paint the cast: the Lieutenant, his dog and tonight's five suspects.

Everything is drawn from shapes, at two texels to a room pixel (a frame is
64x128 texels, shown 32x64), the way Prince of Versions paints its cast:
each part is a tapered shape drawn four times larger and averaged down, lit
from the upper front in three tones, with a thin dark rim instead of an ink
outline. Everyone is an archetype with an invented name; nobody is drawn to
look like a real person.

A sheet is: idle, talk, two poses of their own, then (the Lieutenant only)
a six-frame walk.

    python tools/paint.py            # -> assets/sprites/*.png
    python tools/paint.py --preview  # also tools/preview/cast.png, scaled up
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"

CLEAR = (0, 0, 0, 0)
SS = 4
FW, FH = 64, 128
LIGHT = (0.6, -0.8)
Point = tuple[float, float]


def rgb(text: str) -> tuple[int, int, int, int]:
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), 255)


def scale(c: tuple, k: float) -> tuple[int, int, int, int]:
    return (min(255, int(c[0] * k)), min(255, int(c[1] * k)), min(255, int(c[2] * k)), 255)


def tone(text: str, shade: float = 0.74, light: float = 1.14) -> tuple:
    base = rgb(text)
    return (base, scale(base, shade), scale(base, light))


INK = rgb("17120f")
WHITE = rgb("f1ece0")
MOUTH = rgb("6e2a2c")

SKIN_LIGHT = tone("e9bd98")
SKIN_TAN = tone("d6a078")
SKIN_OLIVE = tone("c9966c")
SKIN_PALE = tone("f0cdb0")


def _dir(angle: float) -> Point:
    """A unit vector `angle` degrees from straight down, positive forward."""
    a = math.radians(angle)
    return (math.sin(a), math.cos(a))


def _add(p: Point, d: Point, k: float = 1.0) -> Point:
    return (p[0] + d[0] * k, p[1] + d[1] * k)


class Figure:
    """A frame drawn in texel coordinates, at SS times the size."""

    def __init__(self, size: tuple[int, int] = (FW, FH)) -> None:
        self.size = (size[0] * SS, size[1] * SS)
        self.image = Image.new("RGBA", self.size, CLEAR)

    def tx(self, p: Point) -> Point:
        return (p[0] * SS, p[1] * SS)

    def mask(self) -> tuple[Image.Image, ImageDraw.ImageDraw]:
        m = Image.new("L", self.size, 0)
        return m, ImageDraw.Draw(m)

    def circle(self, d: ImageDraw.ImageDraw, c: Point, r: float) -> None:
        x, y = self.tx(c)
        r *= SS
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)

    def oval(self, d: ImageDraw.ImageDraw, c: Point, rx: float, ry: float) -> None:
        x, y = self.tx(c)
        d.ellipse((x - rx * SS, y - ry * SS, x + rx * SS, y + ry * SS), fill=255)

    def capsule(self, d: ImageDraw.ImageDraw, a: Point, b: Point, ra: float, rb: float) -> None:
        steps = max(2, int(math.dist(a, b) * 4))
        for i in range(steps + 1):
            t = i / steps
            self.circle(d, (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), ra + (rb - ra) * t)

    def poly(self, d: ImageDraw.ImageDraw, points: list[Point]) -> None:
        d.polygon([self.tx(p) for p in points], fill=255)

    def paint(self, m: Image.Image, tones: tuple, rim: float = 1.2) -> None:
        """Fill the mask in three tones: shade on the side away from the
        light, a thin highlight on the side facing it."""
        base, shade, light = tones
        sx, sy = round(LIGHT[0] * rim * SS), round(LIGHT[1] * rim * SS)
        hx, hy = round(LIGHT[0] * 0.8 * SS), round(LIGHT[1] * 0.8 * SS)
        inner = ImageChops.multiply(m, ImageChops.offset(m, sx, sy))
        edge = ImageChops.subtract(m, ImageChops.offset(m, -hx, -hy))
        self.image.paste(shade, (0, 0), m)
        self.image.paste(base, (0, 0), inner)
        self.image.paste(light, (0, 0), ImageChops.multiply(edge, inner))

    def shape(self, tones: tuple, draw, rim: float = 1.2) -> None:
        m, d = self.mask()
        draw(d)
        self.paint(m, tones, rim)

    def flat(self, color: tuple, draw) -> None:
        m, d = self.mask()
        draw(d)
        self.image.paste(color, (0, 0), m)


def finish(big: Image.Image, rim: bool = True) -> Image.Image:
    """Average a big drawing down to texels and rim it in a dark line where
    it meets the background."""
    small = big.convert("RGBa").reduce(SS).convert("RGBA")
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 112 else 0)
    small.putalpha(alpha)
    if not rim:
        return small
    w, h = small.size
    src = small.load()
    out = small.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 255:
                continue
            solid = [src[nx, ny] for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                     if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] == 255]
            if solid:
                # The rim takes a little of the colour it borders, so it reads as shadow, not ink.
                mix = [sum(p[i] for p in solid) // len(solid) for i in range(3)]
                dst[x, y] = tuple(INK[i] + (mix[i] - INK[i]) // 5 for i in range(3)) + (225,)
    return out


# --- People -----------------------------------------------------------------

THIGH, SHIN = 23.0, 23.0
UPPER_ARM, FOREARM = 15.0, 14.0

CAST: dict[str, dict] = {
    # The Lieutenant: a rumpled raincoat over a brown suit, a loose tie, dark
    # hair that hasn't seen a comb, and a cigar he never gets round to lighting.
    "lt": dict(skin=SKIN_TAN, hair=tone("3a2c26"), style="tousled", coat=tone("c7b189"), coat_len=23,
               top=tone("8a6f52"), shirt=tone("e6e0d0"), tie=tone("5f6b3a"), legs=tone("6f5a44"),
               shoes=tone("4a3324"), brows=True, cigar=True, slouch=2.0, walk=True),
    # The developer: black tie, silver hair with a side parting, a clipped moustache.
    "voss": dict(skin=SKIN_LIGHT, hair=tone("c9c9d1"), style="parted", coat=tone("23222a"), coat_len=4,
                 top=tone("23222a"), shirt=tone("f1ece0"), bow=tone("17151b"), legs=tone("23222a"),
                 shoes=tone("15131a"), tache=rgb("b4b4bd"), height=3),
    # The champion: a white club sweater with navy and red at the neck, a short blonde bob.
    "bannister": dict(skin=SKIN_TAN, hair=tone("e3c172"), style="bob", coat=tone("f0ede4", 0.82, 1.04), coat_len=0,
                      top=tone("f0ede4", 0.82, 1.04), trim=(rgb("28376b"), rgb("b83a35")), legs=tone("ecebe6", 0.82, 1.03),
                      shoes=tone("f7f5ef", 0.8, 1.02), skirt=14, lips=rgb("b5524b"), slim=True),
    # The astrologer: a purple robe to the floor, a gold medallion, long dark hair and a pointed beard.
    "brandt": dict(skin=SKIN_OLIVE, hair=tone("2a2230"), style="long", coat=tone("5d3a8c"), coat_len=46,
                   top=tone("5d3a8c"), gold=tone("e2b23c"), legs=tone("3a2458"), shoes=tone("c9a23c"),
                   beard=rgb("2a2230"), brows=True, wide=True),
    # The psychiatrist: a teal suit, a dark bob with a streak of grey, glasses.
    "sloane": dict(skin=SKIN_PALE, hair=tone("3b3038"), style="streak", coat=tone("2f7f80"), coat_len=6,
                   top=tone("2f7f80"), shirt=tone("efe6d2"), legs=tone("2f7f80"), shoes=tone("3a2a2a"),
                   skirt=22, glasses=True, lips=rgb("a8433f"), slim=True),
    # The hotelier: a plum evening gown, a rope of pearls, silver hair piled high.
    "harrow": dict(skin=SKIN_PALE, hair=tone("d7d6de"), style="updo", coat=tone("7b2f52"), coat_len=46,
                   top=tone("7b2f52"), pearls=True, legs=tone("5c2140"), shoes=tone("2a1a22"),
                   lips=rgb("9e2f45"), wide=True),
}

# (near arm, far arm) as (upper arm angle, elbow bend), and a mood for the face.
POSES = {
    "idle": dict(near=(5, 10), far=(-4, 8)),
    "talk": dict(near=(34, 96), far=(-4, 10), mouth="open"),
    "think": dict(near=(52, 158), far=(-4, 10), mouth="flat", brow="knit"),
    "point": dict(near=(64, 104), far=(-4, 10), mouth="open", finger=True),
    "smug": dict(folded=True, mouth="smirk", brow="arch"),
    "sweat": dict(near=(30, 142), far=(-10, 6), mouth="frown", brow="worry", drops=True, sag=1.5),
}


def leg_pose(phase: float) -> tuple[float, float]:
    """(thigh angle, knee bend) at `phase` of a stride, 0 = this leg forward."""
    swing = math.cos(phase * math.tau)
    lift = max(0.0, math.sin(phase * math.tau))
    return (20.0 * swing, 6.0 + 30.0 * lift)


def draw_person(spec: dict, pose_name: str, walk: float | None = None) -> Image.Image:
    f = Figure()
    pose = POSES[pose_name]
    skin = spec["skin"]
    slim = 1.0 if spec.get("slim") else 0.0
    wide = 1.0 if spec.get("wide") else 0.0
    sag = pose.get("sag", 0.0) + spec.get("slouch", 0.0)
    grow = spec.get("height", 0)
    bob = 0.0
    legs = [(-2.0, 3.0), (3.0, 4.0)]     # far, near
    arms = [pose.get("far", (-4, 8)), pose.get("near", (5, 10))]
    if walk is not None:
        legs = [leg_pose(walk + 0.5), leg_pose(walk)]
        swing = math.cos(walk * math.tau)
        arms = [(16.0 * swing, 18.0), (-16.0 * swing + 4, 22.0)]
        bob = -1.2 * abs(math.sin(walk * math.tau))
    hip: Point = (31.0, 78.0 + bob)
    shoulder: Point = (31.0 + sag * 0.6, 45.0 - grow + sag + bob)
    neck: Point = (shoulder[0] + 1.0, shoulder[1] - 3.0)
    head: Point = (neck[0] + 1.5 + sag * 0.5, neck[1] - 11.0)
    half = 10.5 - slim * 1.5 + wide * 1.5
    gown = spec.get("coat_len", 0) >= 40
    skirt = spec.get("skirt", 0)

    def limb(d, root: Point, a1: float, a2: float, l1: float, l2: float, r0: float, r1: float, r2: float) -> tuple[Point, Point]:
        mid = _add(root, _dir(a1), l1)
        end = _add(mid, _dir(a2), l2)
        f.capsule(d, root, mid, r0, r1)
        f.capsule(d, mid, end, r1, r2)
        return mid, end

    def leg(index: int) -> None:
        thigh, bend = legs[index]
        root = (hip[0] + (-2.5 if index == 0 else 2.5), hip[1])
        tones = spec["legs"] if index == 1 else (spec["legs"][1], scale(spec["legs"][1], 0.82), spec["legs"][0])
        if skirt and not gown:
            tones = skin if index == 1 else (skin[1], scale(skin[1], 0.85), skin[0])
        knee = _add(root, _dir(thigh), THIGH)
        ankle = _add(knee, _dir(thigh - bend), SHIN)
        r = 4.6 - slim * 0.7
        f.shape(tones, lambda d: (f.capsule(d, root, knee, r, r - 0.8), f.capsule(d, knee, ankle, r - 0.8, r - 1.6)))
        toe = (ankle[0] + 5.0, ankle[1] + 1.6)
        f.shape(spec["shoes"], lambda d: f.capsule(d, (ankle[0] - 1.0, ankle[1] + 1.4), toe, 2.6, 2.0), rim=0.8)

    def arm(index: int) -> Point:
        upper, bend = arms[index]
        root = (shoulder[0] + (-half + 2.5 if index == 0 else half - 3.5), shoulder[1] + 3.0)
        sleeve = spec["coat"] if index == 1 else (spec["coat"][1], scale(spec["coat"][1], 0.82), spec["coat"][0])
        elbow = _add(root, _dir(upper), UPPER_ARM)
        wrist = _add(elbow, _dir(upper + bend), FOREARM)
        r = 4.3 - slim * 0.6 + wide * 0.6
        f.shape(sleeve, lambda d: (f.capsule(d, root, elbow, r, r - 0.6), f.capsule(d, elbow, wrist, r - 0.6, r - 1.2 + wide * 1.2)))
        hand = _add(wrist, _dir(upper + bend), 2.6)
        f.shape(skin, lambda d: f.circle(d, hand, 3.0), rim=0.8)
        return hand

    # Back to front: far arm, legs, body, head, near arm.
    folded = pose.get("folded", False)
    if not folded:
        arm(0)
    if not gown:
        leg(0)
        leg(1)
    else:
        # Just the toes show under a gown.
        f.shape(spec["shoes"], lambda d: f.capsule(d, (hip[0] + 2, 125.4), (hip[0] + 9, 125.8), 2.2, 1.8), rim=0.8)

    hem = hip[1] + spec.get("coat_len", 0)
    flare = 3.0 if spec.get("coat_len", 0) >= 20 else 0.0
    sway = 0.0 if walk is None else 2.0 * math.sin(walk * math.tau)

    def torso(d) -> None:
        top_y = shoulder[1]
        f.poly(d, [(shoulder[0] - half, top_y + 3), (shoulder[0] - half + 3, top_y - 1), (shoulder[0] + half - 3, top_y - 1),
                   (shoulder[0] + half, top_y + 3), (hip[0] + half - 1.5 + wide, hip[1] + 2), (hip[0] + half - 1 + flare + wide + sway * 0.5, hem),
                   (hip[0] - half + 1 - flare - wide + sway * 0.5, hem), (hip[0] - half + 1.5 - wide, hip[1] + 2)])
        f.circle(d, (shoulder[0] - half + 3.5, top_y + 2.5), 3.5)
        f.circle(d, (shoulder[0] + half - 3.5, top_y + 2.5), 3.5)

    if skirt and not gown:
        f.shape(spec["legs"], lambda d: f.poly(d, [(hip[0] - half + 1.5, hip[1] - 2), (hip[0] + half - 1.5, hip[1] - 2),
                                                 (hip[0] + half + 0.5, hip[1] + skirt), (hip[0] - half - 0.5, hip[1] + skirt)]))
    f.shape(spec["coat"], torso)

    # What shows at the chest.
    cx = shoulder[0] + 2.0
    top_y = shoulder[1]
    if "shirt" in spec:
        f.shape(spec["shirt"], lambda d: f.poly(d, [(cx - 3.5, top_y - 1), (cx + 4.5, top_y - 1), (cx + 1.5, top_y + 15), (cx - 0.5, top_y + 15)]), rim=0.6)
    if "tie" in spec:
        f.shape(spec["tie"], lambda d: f.poly(d, [(cx - 0.6, top_y + 1), (cx + 2.2, top_y + 1.5), (cx + 2.6, top_y + 13), (cx + 0.8, top_y + 15), (cx - 0.8, top_y + 13)]), rim=0.5)
    if "bow" in spec:
        f.flat(spec["bow"][0], lambda d: (f.poly(d, [(cx - 3, top_y - 0.5), (cx + 0.5, top_y + 1.5), (cx - 3, top_y + 3.5)]),
                                          f.poly(d, [(cx + 4, top_y - 0.5), (cx + 0.5, top_y + 1.5), (cx + 4, top_y + 3.5)])))
        for i in range(3):
            f.flat(rgb("2a2830"), lambda d, i=i: f.circle(d, (cx + 0.6, top_y + 6 + i * 3.4), 0.7))
    if "trim" in spec:
        navy, red = spec["trim"]
        f.flat(navy, lambda d: f.poly(d, [(cx - 5, top_y - 1), (cx + 6, top_y - 1), (cx + 1, top_y + 9), (cx, top_y + 9)]))
        f.flat(red, lambda d: f.poly(d, [(cx - 3.4, top_y - 1), (cx + 4.4, top_y - 1), (cx + 1, top_y + 6.4), (cx, top_y + 6.4)]))
        f.shape(skin, lambda d: f.poly(d, [(cx - 2, top_y - 1), (cx + 3, top_y - 1), (cx + 0.6, top_y + 4), (cx + 0.2, top_y + 4)]), rim=0.5)
    if "gold" in spec:
        f.flat(spec["gold"][1], lambda d: (f.capsule(d, (cx - 4, top_y), (cx + 0.5, top_y + 10), 0.6, 0.6), f.capsule(d, (cx + 5, top_y), (cx + 0.5, top_y + 10), 0.6, 0.6)))
        f.shape(spec["gold"], lambda d: f.circle(d, (cx + 0.5, top_y + 12), 3.2), rim=0.7)
        f.flat(spec["gold"][0], lambda d: f.poly(d, [(hip[0] - half - 2, hem - 5), (hip[0] + half + 2 + sway, hem - 5), (hip[0] + half + 2 + sway, hem - 3), (hip[0] - half - 2, hem - 3)]))
    if spec.get("pearls"):
        for i in range(7):
            t = i / 6.0
            f.flat(WHITE, lambda d, t=t: f.circle(d, (cx - 4 + 9 * t, top_y + 1.5 + 6.5 * math.sin(t * math.pi)), 1.1))
    if spec.get("coat_len", 0) >= 20 and not gown:
        # A raincoat: a turned-up collar, lapels, and a belt hanging open.
        dark = spec["coat"][1]
        f.shape(spec["coat"], lambda d: (f.poly(d, [(cx - 7.5, top_y + 1), (cx - 5, top_y - 4.5), (cx - 2.5, top_y - 1), (cx - 3.5, top_y + 4)]),
                                         f.poly(d, [(cx + 8, top_y + 1), (cx + 5.5, top_y - 4), (cx + 3.5, top_y - 1), (cx + 4.5, top_y + 4)])), rim=0.7)
        f.flat(dark, lambda d: f.poly(d, [(cx - 6, top_y - 1), (cx - 3.5, top_y - 1), (cx - 0.4, top_y + 15), (cx - 1.6, top_y + 16)]))
        f.flat(dark, lambda d: f.poly(d, [(cx + 7, top_y - 1), (cx + 4.5, top_y - 1), (cx + 1.4, top_y + 15), (cx + 2.6, top_y + 16)]))
        f.flat(dark, lambda d: f.capsule(d, (cx + 0.6, top_y + 16), (cx + 0.8 + sway * 0.4, hem - 1), 0.5, 0.5))
        f.flat(dark, lambda d: f.capsule(d, (hip[0] - half + 2, hip[1] - 4), (hip[0] - half + 1 - sway, hip[1] + 10), 1.0, 0.9))
    if spec.get("coat_len", 0) in (4, 6):
        dark = scale(spec["coat"][0], 0.6)
        f.flat(dark, lambda d: f.capsule(d, (cx + 1, top_y + 15), (cx + 1.2, hem - 1), 0.45, 0.45))

    # Neck and head.
    f.shape(skin, lambda d: f.capsule(d, (neck[0] + 0.5, neck[1] + 3), (head[0] - 0.5, head[1] + 6), 3.2, 3.2), rim=0.7)
    style = spec["style"]
    hair = spec["hair"]
    hx, hy = head
    if style in ("long", "bob", "streak"):
        length = {"long": 17.0, "bob": 9.0, "streak": 8.5}[style]
        f.shape(hair, lambda d: (f.oval(d, (hx - 2.5, hy - 1), 10.2, 10.6), f.poly(d, [(hx - 12.4, hy - 1), (hx - 3, hy - 1), (hx - 2, hy + length), (hx - 11, hy + length)])))
    if style == "updo":
        f.shape(hair, lambda d: (f.oval(d, (hx - 2.5, hy - 9.5), 7.5, 6.5), f.oval(d, (hx - 3, hy - 1), 9.8, 9.8)))
    f.shape(skin, lambda d: (f.oval(d, (hx, hy), 8.6, 9.6), f.oval(d, (hx + 1.5, hy + 4.5), 6.4, 5.6)), rim=1.0)
    # Nose and ear.
    f.shape(skin, lambda d: f.poly(d, [(hx + 7.6, hy - 0.5), (hx + 10.6, hy + 2.6), (hx + 7.6, hy + 3.6)]), rim=0.5)
    f.flat(skin[1], lambda d: f.oval(d, (hx - 5.6, hy + 1.0), 1.8, 2.6))

    def hair_top(d) -> None:
        if style == "tousled":
            f.poly(d, [(hx - 9.5, hy + 2), (hx - 10.5, hy - 5), (hx - 6, hy - 11.5), (hx + 1, hy - 12.5), (hx + 7, hy - 10.5), (hx + 9.6, hy - 6),
                       (hx + 6.5, hy - 5.5), (hx + 4, hy - 7), (hx + 1, hy - 5.5), (hx - 3, hy - 6.5), (hx - 6.5, hy - 3)])
            for dx, dy in ((-9, -9), (-3, -13.4), (4, -13), (9, -9.5), (-11, -3)):
                f.circle(d, (hx + dx, hy + dy), 2.2)
        elif style == "parted":
            f.poly(d, [(hx - 9.2, hy + 1), (hx - 9.8, hy - 5), (hx - 5, hy - 10.6), (hx + 2, hy - 11.4), (hx + 8, hy - 8.5), (hx + 9, hy - 5),
                       (hx + 4, hy - 7.4), (hx - 4, hy - 6), (hx - 7, hy - 2)])
        elif style == "bob":
            f.poly(d, [(hx - 10, hy), (hx - 9.6, hy - 6), (hx - 4, hy - 11.2), (hx + 3, hy - 11.4), (hx + 8.4, hy - 8), (hx + 9.2, hy - 3.5),
                       (hx + 5, hy - 5.6), (hx - 2, hy - 5), (hx - 6.4, hy - 1)])
        elif style in ("streak", "long"):
            f.poly(d, [(hx - 10, hy), (hx - 9.6, hy - 6), (hx - 4, hy - 11), (hx + 3, hy - 11.2), (hx + 8.4, hy - 8), (hx + 8.8, hy - 4.5),
                       (hx + 3, hy - 7.4), (hx - 3, hy - 5.4), (hx - 6.6, hy - 1)])
        elif style == "updo":
            f.poly(d, [(hx - 9.6, hy), (hx - 9.4, hy - 6), (hx - 4, hy - 10.6), (hx + 3, hy - 10.8), (hx + 8, hy - 7.6), (hx + 8.4, hy - 4.6),
                       (hx + 2, hy - 6.6), (hx - 4, hy - 5), (hx - 6.6, hy - 1)])

    f.shape(hair, hair_top, rim=1.0)
    if style == "streak":
        f.flat(rgb("c9c6cf"), lambda d: f.poly(d, [(hx + 2, hy - 10.8), (hx + 4.6, hy - 10.2), (hx + 1.6, hy - 6.6), (hx - 0.4, hy - 6.2)]))
    if "beard" in spec:
        f.flat(spec["beard"], lambda d: f.poly(d, [(hx - 2, hy + 6), (hx + 7.4, hy + 5.4), (hx + 5.6, hy + 9.6), (hx + 4, hy + 15), (hx + 1.6, hy + 10.4)]))
    if not folded:
        hand = arm(1)
    else:
        # Arms folded: two sleeves across the chest, a hand tucked at each end.
        y0 = shoulder[1] + 13.0
        for side in (-1, 1):
            root = (shoulder[0] + side * (half - 3.0), shoulder[1] + 3.0)
            f.shape(spec["coat"], lambda d, root=root, side=side: f.capsule(d, root, (root[0] + side * 0.8, y0 + 1), 4.2, 3.8))
        f.shape(spec["coat"], lambda d: f.capsule(d, (shoulder[0] - half + 3.5, y0 + 2.4), (shoulder[0] + half - 3.0, y0 - 0.6), 3.7, 3.5))
        f.shape((spec["coat"][1], scale(spec["coat"][1], 0.85), spec["coat"][0]), lambda d: f.capsule(d, (shoulder[0] + half - 3.5, y0 + 3.4), (shoulder[0] - half + 5.0, y0 + 3.0), 3.3, 3.3), rim=0.9)
        f.shape(skin, lambda d: f.circle(d, (shoulder[0] - half + 4.0, y0 + 3.0), 2.7), rim=0.7)
        hand = (0.0, 0.0)
    if pose.get("finger"):
        f.shape(skin, lambda d: f.capsule(d, hand, (hand[0] + 1.0, hand[1] - 6.5), 1.3, 1.1), rim=0.5)
    if spec.get("cigar") and pose_name in ("idle", "talk") and walk is None:
        tip = (hand[0] + 5.5, hand[1] - 2.0)
        f.flat(rgb("6a4a2e"), lambda d: f.capsule(d, (hand[0] + 0.5, hand[1] - 0.6), tip, 1.1, 1.0))
        f.flat(rgb("e9712a"), lambda d: f.circle(d, tip, 1.1))

    out = finish(f.image)
    px = out.load()

    def dot(x: float, y: float, color: tuple) -> None:
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < FW and 0 <= yi < FH:
            px[xi, yi] = color

    def bar(x0: float, x1: float, y: float, color: tuple) -> None:
        for x in range(int(round(x0)), int(round(x1)) + 1):
            dot(x, y, color)

    # The face, a texel at a time, so it stays crisp.
    ex, ey = hx + 2.0, hy - 0.5
    eye = rgb("241a18")
    brow_color = spec["hair"][1] if spec["style"] not in ("parted", "updo") else rgb("8d8c96")
    mood_brow = pose.get("brow", "")
    for cx_eye in (ex, ex + 4.4):
        dot(cx_eye, ey, eye)
        dot(cx_eye, ey + 1, eye)
    lift = {"": 0, "knit": 1, "arch": -1, "worry": -1}[mood_brow]
    heavy = 1 if spec.get("brows") else 0
    for row in range(1 + heavy):
        bar(ex - 1, ex + 1, ey - 3 + lift - row + (1 if mood_brow == "worry" else 0), brow_color)
        bar(ex + 3.4, ex + 5.4, ey - 3 - row + (lift if mood_brow != "worry" else 0), brow_color)
    if spec.get("glasses"):
        frame = rgb("3a2f33")
        for gx in (ex - 0.5, ex + 4.2):
            bar(gx - 1.5, gx + 1.5, ey - 2, frame)
            bar(gx - 1.5, gx + 1.5, ey + 2.4, frame)
            dot(gx - 2, ey, frame)
            dot(gx - 2, ey + 1, frame)
            dot(gx + 2, ey, frame)
            dot(gx + 2, ey + 1, frame)
        bar(ex - 7.5, ex - 3, ey - 1, frame)
    my = hy + 6.0
    mouth = pose.get("mouth", "")
    lips = spec.get("lips", MOUTH)
    if "tache" in spec:
        bar(ex - 0.5, ex + 5, my - 1, spec["tache"])
    if mouth == "open":
        bar(ex + 0.5, ex + 4, my, MOUTH)
        bar(ex + 1, ex + 3.5, my + 1, MOUTH)
        bar(ex + 1.5, ex + 3, my + 1, rgb("c46a66"))
    elif mouth == "smirk":
        bar(ex + 0.5, ex + 3.5, my, lips)
        dot(ex + 4.5, my - 1, lips)
    elif mouth == "frown":
        bar(ex + 1, ex + 4, my, lips)
        dot(ex, my + 1, lips)
        dot(ex + 5, my + 1, lips)
    else:
        bar(ex + 0.5, ex + 4, my, lips)
    if pose.get("drops"):
        drop = rgb("9fd3ea")
        for dx, dy in ((-9.5, -6), (-11, -1), (10.5, -8)):
            dot(hx + dx, hy + dy, drop)
            dot(hx + dx, hy + dy + 1, drop)
            dot(hx + dx, hy + dy + 2, WHITE)
    return out


def sheet(name: str) -> Image.Image:
    spec = CAST[name]
    own = ("think", "point") if name == "lt" else ("smug", "sweat")
    frames = [draw_person(spec, "idle"), draw_person(spec, "talk"), draw_person(spec, own[0]), draw_person(spec, own[1])]
    if spec.get("walk"):
        frames += [draw_person(spec, "idle", walk=i / 6.0) for i in range(6)]
    out = Image.new("RGBA", (FW * len(frames), FH), CLEAR)
    for i, frame in enumerate(frames):
        out.paste(frame, (i * FW, 0))
    return out


# --- Null -------------------------------------------------------------------

DW, DH = 80, 48


def draw_dog(sitting: bool, phase: float = 0.0) -> Image.Image:
    """A basset hound: long, low, mostly ears."""
    f = Figure((DW, DH))
    coat = tone("b9783e")
    white = tone("efe7d6", 0.8, 1.04)
    dark = tone("4a2f22")
    ground = 46.0
    if sitting:
        f.shape(coat, lambda d: (f.oval(d, (30, ground - 9), 12, 9), f.capsule(d, (34, ground - 12), (48, ground - 20), 9, 7)))
        f.shape(white, lambda d: (f.capsule(d, (47, ground - 16), (47, ground - 2), 3.4, 3.0), f.capsule(d, (47, ground - 1.5), (52, ground - 1.5), 2.6, 2.4)), rim=0.8)
        f.shape(coat, lambda d: f.capsule(d, (27, ground - 3), (37, ground - 2), 3.6, 3.0), rim=0.8)
        f.shape(white, lambda d: f.capsule(d, (18, ground - 6), (10, ground - 12), 2.0, 1.2), rim=0.6)
        head = (54.0, ground - 27.0)
    else:
        lift = 1.0 * abs(math.sin(phase * math.tau))
        swing = 5.0 * math.cos(phase * math.tau)
        for x, s, t in ((26, -swing, True), (50, swing, True), (30, swing, False), (54, -swing, False)):
            tones = (white[1], scale(white[1], 0.85), white[0]) if t else white
            f.shape(tones, lambda d, x=x, s=s: (f.capsule(d, (x, ground - 12), (x + s, ground - 2.5), 3.2, 2.6),
                                                f.capsule(d, (x + s, ground - 1.6), (x + s + 4, ground - 1.6), 2.4, 2.2)), rim=0.8)
        f.shape(coat, lambda d: f.capsule(d, (25, ground - 15 - lift), (52, ground - 16 - lift), 8.5, 8.0))
        f.shape(white, lambda d: f.capsule(d, (30, ground - 11 - lift), (50, ground - 11.5 - lift), 4.0, 4.0), rim=0.6)
        f.shape(white, lambda d: f.capsule(d, (17, ground - 19 - lift), (9, ground - 27 - lift + swing * 0.3), 2.0, 1.1), rim=0.6)
        head = (60.0, ground - 22.0 - lift)
    f.shape(coat, lambda d: (f.oval(d, head, 8.0, 7.0), f.capsule(d, (head[0] + 4, head[1] + 2.5), (head[0] + 13, head[1] + 4.5), 5.0, 4.2)))
    f.shape(white, lambda d: f.capsule(d, (head[0] + 7, head[1] + 5.5), (head[0] + 13.5, head[1] + 6.2), 3.2, 3.0), rim=0.6)
    f.flat(dark[0], lambda d: f.circle(d, (head[0] + 17.2, head[1] + 3.6), 2.0))
    droop = 0.0 if sitting else 2.0 * math.sin(phase * math.tau)
    f.shape(dark, lambda d: f.capsule(d, (head[0] - 3, head[1] - 4), (head[0] - 5 - droop, head[1] + 13), 4.2, 3.6))
    out = finish(f.image)
    px = out.load()
    ex, ey = int(round(head[0] + 4)), int(round(head[1] - 1))
    px[ex, ey] = rgb("1d1512")
    px[ex, ey + 1] = rgb("1d1512")
    px[ex + 1, ey + 2] = rgb("7a4a2a")
    px[ex - 1, ey - 2] = scale(coat[0], 0.7)
    px[ex, ey - 2] = scale(coat[0], 0.7)
    return out


def dog_sheet() -> Image.Image:
    frames = [draw_dog(True)] + [draw_dog(False, i / 4.0) for i in range(4)]
    out = Image.new("RGBA", (DW * len(frames), DH), CLEAR)
    for i, frame in enumerate(frames):
        out.paste(frame, (i * DW, 0))
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {name: sheet(name) for name in CAST}
    sheets["null"] = dog_sheet()
    for name, image in sheets.items():
        image.save(OUT / f"{name}.png")
        print(f"{name}.png {image.size[0]}x{image.size[1]}")
    if "--preview" in sys.argv:
        preview = ROOT / "tools" / "preview"
        preview.mkdir(parents=True, exist_ok=True)
        width = max(i.size[0] for i in sheets.values())
        height = sum(i.size[1] for i in sheets.values())
        board = Image.new("RGBA", (width, height), rgb("3a3340"))
        y = 0
        for image in sheets.values():
            board.alpha_composite(image, (0, y))
            y += image.size[1]
        board.resize((width * 3, height * 3), Image.NEAREST).save(preview / "cast.png")


if __name__ == "__main__":
    main()
