"""Paint the 16x16 stage tiles and blocks pixel by pixel.

Image models lose everything when squeezed to 16x16, so these are drawn here
with one shared palette. Output goes straight into assets/sprites.

Tileset atlas columns: ground, fill, slab, one-way plank, ember x3 (animated).

    python tools/paint_tiles.py
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites"

CLEAR = (0, 0, 0, 0)
INK = (34, 20, 30, 255)

MOSS_HI = (156, 214, 120, 255)
MOSS = (92, 170, 98, 255)
MOSS_LO = (52, 118, 82, 255)

SAND_HI = (246, 206, 140, 255)
SAND = (222, 170, 102, 255)
SAND_MID = (196, 140, 80, 255)
SAND_LO = (160, 106, 62, 255)

EARTH_HI = (150, 96, 64, 255)
EARTH = (118, 72, 52, 255)
EARTH_LO = (88, 52, 42, 255)
EARTH_DEEP = (66, 38, 36, 255)

WOOD_HI = (232, 168, 96, 255)
WOOD = (190, 120, 64, 255)
WOOD_LO = (130, 76, 44, 255)
NAIL = (238, 226, 200, 255)

CRUST = (58, 24, 28, 255)
CRUST_HI = (96, 38, 34, 255)
GLOW_LO = (204, 64, 30, 255)
GLOW = (255, 132, 40, 255)
GLOW_HI = (255, 220, 120, 255)

CLAY_HI = (236, 136, 96, 255)
CLAY = (200, 98, 66, 255)
CLAY_LO = (146, 62, 48, 255)
MORTAR = (98, 46, 44, 255)

RUNE = (255, 196, 72, 255)
RUNE_HI = (255, 244, 186, 255)

ASH_HI = (210, 200, 196, 255)
ASH = (168, 156, 158, 255)
ASH_LO = (118, 106, 114, 255)


def tile() -> Image.Image:
    return Image.new("RGBA", (16, 16), CLEAR)


def put(image: Image.Image, x: int, y: int, color: tuple) -> None:
    if 0 <= x < image.width and 0 <= y < image.height:
        image.putpixel((x, y), color)


def rect(image: Image.Image, x0: int, y0: int, x1: int, y1: int, color: tuple) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(image, x, y, color)


def speckle(image: Image.Image, rng: random.Random, area: tuple[int, int, int, int], colors: list, count: int) -> None:
    x0, y0, x1, y1 = area
    for _ in range(count):
        put(image, rng.randint(x0, x1), rng.randint(y0, y1), rng.choice(colors))


def pebble(image: Image.Image, x: int, y: int, light: tuple, dark: tuple) -> None:
    put(image, x, y, light)
    put(image, x + 1, y, light)
    put(image, x, y + 1, dark)
    put(image, x + 1, y + 1, dark)


def paint_fill(seed: int = 3) -> Image.Image:
    """Packed earth with strata. Tiles seamlessly in both directions."""
    rng = random.Random(seed)
    image = tile()
    rect(image, 0, 0, 15, 15, EARTH)
    for y in (4, 11):
        for x in range(16):
            if rng.random() < 0.8:
                put(image, x, y, EARTH_LO)
            if rng.random() < 0.35:
                put(image, x, y - 1, EARTH_HI)
    speckle(image, rng, (0, 0, 15, 15), [EARTH_LO, EARTH_DEEP], 14)
    speckle(image, rng, (0, 0, 15, 15), [EARTH_HI], 6)
    pebble(image, 3, 7, SAND_LO, EARTH_DEEP)
    pebble(image, 11, 13, SAND_LO, EARTH_DEEP)
    pebble(image, 12, 1, EARTH_HI, EARTH_DEEP)
    return image


def paint_ground() -> Image.Image:
    """Moss lip over sandstone, then earth. Repeats left to right."""
    rng = random.Random(7)
    image = paint_fill(seed=11)
    rect(image, 0, 3, 15, 8, SAND)
    rect(image, 0, 3, 15, 3, SAND_HI)
    for x in range(16):
        put(image, x, 9, SAND_LO if x % 5 else SAND_MID)
        if rng.random() < 0.5:
            put(image, x, 10, SAND_LO)
    speckle(image, rng, (0, 4, 15, 8), [SAND_MID, SAND_HI], 10)
    pebble(image, 5, 6, SAND_HI, SAND_LO)
    pebble(image, 12, 5, SAND_HI, SAND_LO)
    # moss cap with a sawtooth fringe that hangs over the sand
    rect(image, 0, 0, 15, 2, MOSS)
    for x in range(16):
        put(image, x, 0, MOSS_HI if x % 3 != 1 else MOSS)
        if x % 4 in (0, 1):
            put(image, x, 3, MOSS_LO)
        if x % 7 == 2:
            put(image, x, 4, MOSS_LO)
    put(image, 6, 1, MOSS_HI)
    put(image, 13, 1, MOSS_HI)
    return image


def paint_slab() -> Image.Image:
    """A carved sandstone block. Reads as a solid floating platform."""
    image = tile()
    rect(image, 0, 0, 15, 15, SAND)
    rect(image, 0, 0, 15, 1, SAND_HI)
    rect(image, 0, 0, 0, 14, SAND_HI)
    rect(image, 15, 1, 15, 15, SAND_LO)
    rect(image, 0, 14, 15, 15, SAND_LO)
    rect(image, 1, 7, 14, 7, SAND_MID)
    rect(image, 7, 2, 7, 6, SAND_MID)
    rect(image, 3, 8, 3, 13, SAND_MID)
    rect(image, 11, 8, 11, 13, SAND_MID)
    for x, y in ((4, 3), (11, 4), (6, 10), (13, 11), (1, 12)):
        put(image, x, y, SAND_LO)
    rect(image, 0, 15, 15, 15, INK)
    return image


def paint_plank() -> Image.Image:
    """One-way plank. Collision is the top 5px, so the wood lives there."""
    image = tile()
    rect(image, 0, 0, 15, 4, WOOD)
    rect(image, 0, 0, 15, 0, WOOD_HI)
    rect(image, 0, 4, 15, 4, WOOD_LO)
    for x in (4, 11):
        put(image, x, 2, WOOD_LO)
        put(image, x + 1, 2, WOOD_LO)
    put(image, 1, 2, NAIL)
    put(image, 14, 2, NAIL)
    # small brackets so the plank does not float as a bare line
    for x in (2, 13):
        rect(image, x, 5, x, 7, WOOD_LO)
    put(image, 3, 5, WOOD_LO)
    put(image, 12, 5, WOOD_LO)
    return image


def paint_ember(frame: int) -> Image.Image:
    """Glowing coal with flickering cracks and flame tips. Kills on touch."""
    rng = random.Random(41)
    image = tile()
    rect(image, 0, 0, 15, 15, CRUST)
    speckle(image, rng, (0, 2, 15, 15), [CRUST_HI], 18)
    cracks = [
        [(1, 4), (2, 5), (3, 5), (4, 6), (5, 7), (6, 7), (7, 8)],
        [(9, 3), (10, 4), (10, 5), (11, 6), (12, 6), (13, 7), (14, 8)],
        [(7, 8), (8, 9), (8, 10), (9, 11), (10, 12), (11, 13)],
        [(3, 10), (4, 11), (4, 12), (5, 13), (6, 14)],
    ]
    for index, crack in enumerate(cracks):
        bright = (index + frame) % 3
        for x, y in crack:
            put(image, x, y, GLOW if bright else GLOW_HI)
            put(image, x, y + 1, GLOW_LO)
    # molten top edge
    for x in range(16):
        wave = (x + frame * 2) % 6
        put(image, x, 0, GLOW_HI if wave < 2 else GLOW)
        put(image, x, 1, GLOW if wave < 4 else GLOW_LO)
    # flame tips poking up from the surface
    for x in range(16):
        if (x + frame * 3) % 7 == 0:
            put(image, x, 0, GLOW_HI)
            put(image, x, 2, GLOW)
    return image


def paint_clay_brick() -> Image.Image:
    image = tile()
    rect(image, 0, 0, 15, 15, MORTAR)
    rows = [(1, 6, [(1, 6), (8, 14)]), (8, 13, [(0, 2), (4, 11), (13, 15)])]
    for y0, y1, bricks in rows:
        for x0, x1 in bricks:
            rect(image, x0, y0, x1, y1, CLAY)
            rect(image, x0, y0, x1, y0, CLAY_HI)
            rect(image, x0, y1, x1, y1, CLAY_LO)
    for x, y in ((3, 3), (11, 4), (6, 11), (9, 10), (14, 10)):
        put(image, x, y, CLAY_LO)
    put(image, 12, 2, MORTAR)
    put(image, 13, 3, MORTAR)
    rect(image, 0, 15, 15, 15, INK)
    rect(image, 0, 0, 15, 0, INK)
    rect(image, 0, 0, 0, 15, INK)
    rect(image, 15, 0, 15, 15, INK)
    return image


def paint_cache(spent: bool) -> Image.Image:
    image = tile()
    base, hi, lo = (SAND_MID, SAND, SAND_LO) if spent else (SAND, SAND_HI, SAND_LO)
    rect(image, 0, 0, 15, 15, INK)
    rect(image, 1, 1, 14, 14, base)
    rect(image, 1, 1, 14, 1, hi)
    rect(image, 1, 1, 1, 13, hi)
    rect(image, 14, 2, 14, 14, lo)
    rect(image, 2, 14, 14, 14, lo)
    for x, y in ((2, 2), (13, 2), (2, 13), (13, 13)):
        put(image, x, y, lo)
    if spent:
        rect(image, 5, 5, 10, 10, lo)
        rect(image, 6, 6, 9, 9, base)
        return image
    spiral = [
        (7, 7), (8, 7), (8, 8), (7, 8), (6, 8), (6, 7), (6, 6), (7, 6), (8, 6), (9, 6),
        (9, 7), (9, 8), (9, 9), (8, 9), (7, 9), (6, 9), (5, 9), (5, 8), (5, 7), (5, 6), (5, 5),
        (6, 5), (7, 5), (8, 5), (9, 5), (10, 5),
    ]
    for x, y in spiral:
        put(image, x, y, RUNE)
    put(image, 7, 7, RUNE_HI)
    put(image, 10, 5, RUNE_HI)
    return image


def paint_ash() -> Image.Image:
    """Crumbling ash shelf. Pale and cracked so it never reads as a safe slab."""
    rng = random.Random(5)
    image = tile()
    rect(image, 0, 0, 15, 11, ASH)
    rect(image, 0, 0, 15, 0, ASH_HI)
    rect(image, 0, 11, 15, 11, ASH_LO)
    speckle(image, rng, (0, 1, 15, 10), [ASH_LO, ASH_HI], 14)
    for x, y in ((3, 1), (4, 2), (4, 3), (5, 4), (11, 2), (10, 3), (10, 4), (9, 5), (9, 6)):
        put(image, x, y, ASH_LO)
    # ragged underside drips
    for x in range(16):
        if x % 3 == 0:
            put(image, x, 12, ASH_LO)
        if x % 5 == 1:
            put(image, x, 13, ASH_LO)
    return image


def paint_lantern(lit: bool) -> Image.Image:
    """Checkpoint post, 12x28. Feet at the bottom row. Lit shows the flame."""
    image = Image.new("RGBA", (12, 28), CLEAR)
    # post
    rect(image, 5, 11, 6, 27, WOOD)
    rect(image, 5, 11, 5, 27, WOOD_HI)
    rect(image, 3, 26, 8, 27, SAND_LO)
    rect(image, 4, 25, 7, 25, SAND_MID)
    # lantern cage
    rect(image, 2, 2, 9, 10, INK)
    rect(image, 1, 1, 10, 1, INK)
    rect(image, 4, 0, 7, 0, INK)
    window = (GLOW_HI, GLOW) if lit else ((70, 62, 80, 255), (48, 40, 58, 255))
    rect(image, 3, 3, 8, 9, window[1])
    rect(image, 4, 4, 7, 8, window[0])
    if lit:
        put(image, 5, 4, (255, 250, 220, 255))
        put(image, 6, 5, (255, 250, 220, 255))
    rect(image, 2, 6, 9, 6, INK)
    if not lit:
        rect(image, 5, 3, 6, 9, INK)
    rect(image, 1, 10, 10, 10, SAND_LO)
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = [paint_ground(), paint_fill(), paint_slab(), paint_plank()] + [paint_ember(f) for f in range(3)]
    sheet = Image.new("RGBA", (16 * len(tiles), 16), CLEAR)
    for index, image in enumerate(tiles):
        sheet.paste(image, (index * 16, 0))
    sheet.save(OUT / "tileset.png")
    for name, image in (
        ("tile_ground", tiles[0]),
        ("tile_fill", tiles[1]),
        ("tile_slab", tiles[2]),
        ("tile_one_way", tiles[3]),
        ("clay_brick", paint_clay_brick()),
        ("cache_stone", paint_cache(False)),
        ("cache_stone_spent", paint_cache(True)),
        ("tile_ash", paint_ash()),
        ("lantern_unlit", paint_lantern(False)),
        ("lantern_lit", paint_lantern(True)),
    ):
        image.save(OUT / f"{name}.png")
    print("PAINTED", sheet.size)


if __name__ == "__main__":
    main()
