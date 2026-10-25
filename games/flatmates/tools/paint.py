"""Paint the flatmates, the tiles and the small props, pixel by pixel.

Figures this small lose their faces when an image model is squeezed down to
them, so they are drawn here from shapes. Each flatmate is a sheet of six
16x24 frames facing right: idle, two walk frames, jump, strum, press. The
tile sheet has one row per stage theme: floor top, fill, shelf, plank.

Also synthesizes the strum (a Karplus-Strong chord), so the guitar is ours.

    python tools/paint.py
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
AUDIO = ROOT / "assets" / "audio"

INK = (24, 20, 28, 255)
SKIN = (236, 196, 160, 255)
SKIN_DARK = (200, 150, 120, 255)

CLIVE = {
    "hair": (92, 60, 40, 255), "hair_dark": (62, 40, 28, 255),
    "top": (64, 84, 140, 255), "top_dark": (44, 58, 100, 255),
    "collar": (220, 228, 240, 255), "tie": (180, 50, 52, 255),
    "legs": (196, 176, 136, 255), "legs_dark": (156, 138, 104, 255),
    "shoes": (78, 50, 34, 255),
}
JAZZ = {
    "hair": (200, 160, 86, 255), "hair_dark": (150, 112, 56, 255),
    "top": (196, 58, 52, 255), "top_dark": (140, 38, 40, 255),
    "collar": (196, 58, 52, 255), "tie": None,
    "legs": (54, 66, 96, 255), "legs_dark": (38, 46, 70, 255),
    "shoes": (236, 236, 236, 255),
}
GUITAR = (186, 110, 52, 255)
GUITAR_DARK = (120, 70, 36, 255)


def px(d: ImageDraw.ImageDraw, x: int, y: int, c) -> None:
    d.point((x, y), fill=c)


def rect(d: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, c) -> None:
    d.rectangle((x0, y0, x1, y1), fill=c)


def figure(c: dict, frame: int, jazz: bool) -> Image.Image:
    img = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lift = -1 if frame == 3 else 0
    # Legs: idle together, walk A apart, walk B crossed, jump tucked.
    if frame == 1:
        legs = [(4, 6, 17, 21), (9, 11, 17, 21)]
        shoes = [(3, 6, 22, 23), (9, 12, 22, 23)]
    elif frame == 2:
        legs = [(6, 8, 17, 21), (7, 9, 17, 21)]
        shoes = [(6, 9, 22, 23), (7, 10, 22, 23)]
    elif frame == 3:
        legs = [(5, 7, 16, 19), (8, 10, 16, 20)]
        shoes = [(5, 8, 20, 21), (8, 11, 21, 22)]
    else:
        legs = [(5, 7, 17, 21), (8, 10, 17, 21)]
        shoes = [(5, 8, 22, 23), (8, 11, 22, 23)]
    for i, (x0, x1, y0, y1) in enumerate(legs):
        rect(d, x0, y0, x1, y1, c["legs_dark"] if i == 0 else c["legs"])
    for x0, x1, y0, y1 in shoes:
        rect(d, x0, y0, x1, y1, c["shoes"])
        if jazz:
            rect(d, x0, y1, x1, y1, (180, 180, 186, 255))
    # Torso.
    top = 10 + lift
    rect(d, 4, top, 11, 16 + lift, c["top"])
    rect(d, 4, top, 4, 16 + lift, c["top_dark"])
    if jazz:
        # A hoodie: pocket, strings, a band logo nobody can read.
        rect(d, 6, 14 + lift, 10, 15 + lift, c["top_dark"])
        px(d, 7, top + 1, (240, 230, 210, 255))
        px(d, 9, top + 1, (240, 230, 210, 255))
        rect(d, 7, top + 2, 9, top + 2, (250, 216, 80, 255))
    else:
        # A V-neck over a shirt and tie: the uniform of a man with a pension.
        rect(d, 7, top, 9, top + 1, c["collar"])
        px(d, 8, top + 2, c["collar"])
        rect(d, 8, top, 8, top + 3, c["tie"])
        rect(d, 4, 16 + lift, 11, 16 + lift, c["legs_dark"])
    # Arms.
    if frame == 3:
        rect(d, 11, top - 3, 12, top + 1, c["top"])
        rect(d, 11, top - 4, 12, top - 4, SKIN)
        rect(d, 3, top - 2, 4, top + 2, c["top_dark"])
    elif frame == 5:
        rect(d, 11, top + 1, 14, top + 2, c["top"])
        rect(d, 15, top + 1, 15, top + 2, SKIN)
        rect(d, 3, top + 1, 4, top + 5, c["top_dark"])
    elif frame == 4 and jazz:
        # Guitar across the body, strumming hand down.
        d.line((3, top + 6, 13, top + 1), fill=GUITAR_DARK)
        rect(d, 4, top + 3, 8, top + 6, GUITAR)
        px(d, 6, top + 4, INK)
        d.line((9, top + 3, 14, top), fill=GUITAR_DARK)
        rect(d, 9, top + 4, 10, top + 6, SKIN)
    elif frame == 4:
        # Clive's air guitar is a shrug.
        rect(d, 2, top, 3, top + 1, c["top"])
        rect(d, 12, top, 13, top + 1, c["top"])
        px(d, 1, top, SKIN)
        px(d, 14, top, SKIN)
    else:
        swing = {1: 1, 2: -1}.get(frame, 0)
        rect(d, 10, top + 1, 11, top + 5 + swing, c["top"])
        px(d, 11, top + 6 + swing, SKIN)
        rect(d, 4, top + 1, 4, top + 5 - swing, c["top_dark"])
    # Neck and head.
    rect(d, 7, 9 + lift, 9, 9 + lift, SKIN_DARK)
    rect(d, 5, 3 + lift, 11, 8 + lift, SKIN)
    rect(d, 5, 8 + lift, 11, 8 + lift, SKIN_DARK)
    px(d, 12, 5 + lift, SKIN)  # nose
    px(d, 10, 5 + lift, INK)   # eye
    if jazz:
        px(d, 10, 7 + lift, (170, 120, 96, 255))  # a lopsided grin
        px(d, 9, 7 + lift, (170, 120, 96, 255))
        # Hair everywhere, down past the ears.
        rect(d, 4, 1 + lift, 11, 3 + lift, c["hair"])
        rect(d, 4, 3 + lift, 6, 9 + lift, c["hair"])
        rect(d, 3, 4 + lift, 3, 8 + lift, c["hair_dark"])
        px(d, 12, 2 + lift, c["hair"])
        px(d, 8, 0 + lift, c["hair_dark"])
        px(d, 11, 4 + lift, c["hair"])
        # Stubble.
        px(d, 7, 8 + lift, SKIN_DARK)
        px(d, 9, 8 + lift, SKIN_DARK)
        if frame != 4:
            # The guitar's neck over his shoulder.
            d.line((2, top + 6, 5, top - 3), fill=GUITAR_DARK)
            px(d, 5, top - 4, INK)
    else:
        px(d, 9, 7 + lift, (150, 100, 90, 255))  # a thin, worried mouth
        px(d, 10, 7 + lift, (150, 100, 90, 255))
        # A neat side parting, short back and sides.
        rect(d, 5, 2 + lift, 11, 3 + lift, c["hair"])
        rect(d, 5, 3 + lift, 6, 6 + lift, c["hair"])
        rect(d, 5, 2 + lift, 7, 2 + lift, c["hair_dark"])
        px(d, 9, 4 + lift, c["hair"])
        # A furrowed brow.
        px(d, 10, 4 + lift, SKIN_DARK)
    return outline(img)


def outline(img: Image.Image) -> Image.Image:
    """A one-pixel dark edge around the figure, so it reads on any wall."""
    w, h = img.size
    src = img.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                dst[x, y] = src[x, y]
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                    dst[x, y] = INK
                    break
    return out


def sheet(colors: dict, jazz: bool) -> Image.Image:
    out = Image.new("RGBA", (16 * 6, 24), (0, 0, 0, 0))
    for frame in range(6):
        out.paste(figure(colors, frame, jazz), (frame * 16, 0))
    return out


# --- Tiles ------------------------------------------------------------------

THEMES = [
    # flat: brown carpet, floorboards under, an MDF shelf, a pine plank
    {"top": (122, 84, 62), "edge": (160, 116, 84), "fill": (70, 50, 42), "grain": (58, 40, 34),
     "shelf": (214, 196, 160), "plank": (196, 150, 96)},
    # office: grey carpet tiles, concrete, a desk top, a cable tray
    {"top": (110, 116, 130), "edge": (150, 156, 170), "fill": (70, 74, 86), "grain": (60, 64, 76),
     "shelf": (200, 180, 140), "plank": (150, 156, 170)},
    # cellar bar: a sticky wooden floor, brick, a beer crate, a scaffold board
    {"top": (110, 70, 44), "edge": (150, 100, 62), "fill": (120, 56, 46), "grain": (92, 40, 34),
     "shelf": (60, 110, 70), "plank": (176, 140, 90)},
    # farm: grass on soil, earth, a hay bale, a fence rail
    {"top": (96, 158, 72), "edge": (140, 196, 96), "fill": (106, 76, 52), "grain": (86, 60, 42),
     "shelf": (214, 178, 90), "plank": (150, 110, 70)},
    # station: paving with the yellow line, concrete, a steel bench, a grating
    {"top": (150, 150, 156), "edge": (242, 210, 60), "fill": (90, 92, 100), "grain": (78, 80, 88),
     "shelf": (120, 136, 156), "plank": (110, 116, 126)},
    # church: stone flags, stone, a pew, a red runner
    {"top": (170, 162, 150), "edge": (200, 192, 180), "fill": (120, 112, 104), "grain": (100, 94, 88),
     "shelf": (120, 76, 48), "plank": (170, 50, 56)},
]


def tiles() -> Image.Image:
    img = Image.new("RGBA", (64, 16 * len(THEMES)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(5)
    for row, t in enumerate(THEMES):
        y = row * 16
        # Floor top: a surface band with a bright lip, then the fill.
        rect(d, 0, y, 15, y + 15, t["fill"] + (255,))
        rect(d, 0, y, 15, y + 4, t["top"] + (255,))
        rect(d, 0, y, 15, y, t["edge"] + (255,))
        rect(d, 0, y + 5, 15, y + 5, t["grain"] + (255,))
        # A seam at each tile's left edge, so steps can be counted.
        rect(d, 0, y + 1, 0, y + 4, t["grain"] + (255,))
        # Fill: the same material with a little texture.
        rect(d, 16, y, 31, y + 15, t["fill"] + (255,))
        for _ in range(7):
            gx, gy = rng.randrange(16), rng.randrange(16)
            px(d, 16 + gx, y + gy, t["grain"] + (255,))
        if row == 2:
            # Brick courses for the cellar.
            for by in (3, 7, 11, 15):
                rect(d, 16, y + by, 31, y + by, t["grain"] + (255,))
            for bx, by in ((20, 0), (28, 4), (20, 8), (28, 12)):
                rect(d, bx, y + by, bx, y + by + 3, t["grain"] + (255,))
        for gx in (0, 8):
            px(d, gx, y + 10, t["grain"] + (255,))
        # Shelf: a solid slab with a lit top and a dark underside.
        rect(d, 32, y, 47, y + 15, t["shelf"] + (255,))
        rect(d, 32, y, 47, y + 1, tuple(min(255, v + 30) for v in t["shelf"]) + (255,))
        rect(d, 32, y + 14, 47, y + 15, tuple(max(0, v - 50) for v in t["shelf"]) + (255,))
        rect(d, 32, y, 32, y + 15, tuple(max(0, v - 30) for v in t["shelf"]) + (255,))
        # Plank: a thin board on top, see-through below.
        rect(d, 48, y, 63, y + 4, t["plank"] + (255,))
        rect(d, 48, y, 63, y, tuple(min(255, v + 30) for v in t["plank"]) + (255,))
        rect(d, 48, y + 4, 63, y + 4, tuple(max(0, v - 50) for v in t["plank"]) + (255,))
        for bx in (51, 59):
            px(d, bx, y + 2, tuple(max(0, v - 40) for v in t["plank"]) + (255,))
    return img


# --- The strum --------------------------------------------------------------

def strum(path: Path) -> None:
    """An open E major chord, plucked string by string: Karplus-Strong."""
    rate = 22050
    seconds = 1.2
    notes = [82.41, 123.47, 164.81, 207.65, 246.94, 329.63]
    total = int(rate * seconds)
    mix = [0.0] * total
    rng = random.Random(9)
    for index, freq in enumerate(notes):
        start = int(index * 0.012 * rate)
        period = int(rate / freq)
        buf = [rng.uniform(-1, 1) for _ in range(period)]
        for i in range(start, total):
            v = buf[(i - start) % period]
            nxt = buf[(i - start + 1) % period]
            buf[(i - start) % period] = 0.996 * 0.5 * (v + nxt)
            mix[i] += v * 0.22
    peak = max(abs(v) for v in mix) or 1.0
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        frames = bytearray()
        for i, v in enumerate(mix):
            fade = 1.0 if i < total - 2000 else (total - i) / 2000
            frames += struct.pack("<h", int(v / peak * 0.8 * fade * 32767))
        out.writeframes(bytes(frames))


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    sheet(CLIVE, False).save(SPRITES / "clive.png")
    sheet(JAZZ, True).save(SPRITES / "jazz.png")
    tiles().save(SPRITES / "tiles.png")
    strum(AUDIO / "strum.wav")
    # Big previews for checking by eye (not shipped).
    preview = ROOT / "tools" / "preview"
    preview.mkdir(exist_ok=True)
    for name in ("clive", "jazz", "tiles"):
        img = Image.open(SPRITES / f"{name}.png")
        img.resize((img.width * 8, img.height * 8), Image.NEAREST).save(preview / f"{name}.png")
    print("painted clive, jazz, tiles and the strum")


if __name__ == "__main__":
    main()
