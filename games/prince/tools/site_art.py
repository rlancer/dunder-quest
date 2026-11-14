"""Make the site's art for Prince of Versions.

Copies the screenshots the page uses out of tests/shots/ (made by
`godot --path . res://tests/shots.tscn`, which needs a window) into
site/static/img/prince/, cuts the cast and the tiles out of the sprite sheets
for the brand kit (/brand/prince/), and paints the social card (1200x630)
from the title art and the game's own fonts.

    python tools/site_art.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
SHOTS = ROOT / "tests" / "shots"
OUT = REPO / "site" / "static" / "img" / "prince"
OG = REPO / "site" / "static" / "img" / "og" / "prince.png"
FONTS = ROOT / "assets" / "fonts"

# Screenshot -> the name the page uses.
PAGE = {
    "0_title": "title", "1_uncommitted": "commit", "1_dead": "dead", "2_vizier": "vizier",
    "4_guard": "guard", "5_conflict": "conflict", "5_merged": "merged", "3_lost": "lost",
}

INK = (20, 16, 28)
SAND = (233, 185, 73)
SAND_PALE = (246, 227, 161)
PAPER = (245, 235, 204)
TEAL = (110, 200, 204)


def shots() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for source, name in PAGE.items():
        path = SHOTS / f"{source}.png"
        if not path.exists():
            print("missing", path.name, "(run tests/shots.tscn first)")
            continue
        image = Image.open(path).convert("RGB").resize((960, 540), Image.Resampling.LANCZOS)
        image.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(OUT / f"{name}.png", optimize=True)
        print("copied", name)


# Brand kit art: [file, sheet, crop box or None for the whole sheet]. The
# sheets are painted at two texels to a room pixel (tools/paint.py).
PF = 64
DAGGER = 17
SPRITES = [
    ("cast_prince.png", "prince.png", (0, 0, PF, PF)),
    ("cast_dagger.png", "prince.png", (DAGGER * PF, 0, DAGGER * PF + PF, PF)),
    ("cast_vizier.png", "vizier.png", (0, 0, 48, 80)),
    ("cast_princess.png", "princess.png", None),
    ("kit_door.png", "door.png", None),
]


def sprites() -> None:
    """Native-size cuts; the page scales them by whole numbers."""
    OUT.mkdir(parents=True, exist_ok=True)
    for name, sheet, box in SPRITES:
        image = Image.open(ROOT / "assets" / "sprites" / sheet).convert("RGBA")
        (image.crop(box) if box else image).save(OUT / name, optimize=True)
        print("cut", name)
    # The tiles in a plain strip, without the sheet's padding round each one.
    sheet = Image.open(ROOT / "assets" / "sprites" / "tiles.png").convert("RGBA")
    count = sheet.width // 34
    strip = Image.new("RGBA", (32 * count, 32))
    for i in range(count):
        strip.paste(sheet.crop((i * 34 + 1, 1, i * 34 + 33, 33)), (i * 32, 0))
    strip.save(OUT / "kit_tiles.png", optimize=True)
    print("cut kit_tiles.png")


def card() -> None:
    art = Image.open(ROOT / "assets" / "backgrounds" / "title.png").convert("RGB")
    # 480x270 -> 1200x675, nearest, cropped to 630 tall.
    art = art.resize((1200, 675), Image.Resampling.NEAREST).crop((0, 22, 1200, 652))
    shade = Image.new("RGB", art.size, INK)
    mask = Image.new("L", art.size, 0)
    draw = ImageDraw.Draw(mask)
    for x in range(700):
        draw.line([(x, 0), (x, 630)], fill=int(215 * (1 - x / 700)))
    art.paste(shade, (0, 0), mask)
    draw = ImageDraw.Draw(art)
    pixel = lambda size: ImageFont.truetype(str(FONTS / "PixelifySans.ttf"), size)  # noqa: E731
    mono = lambda size: ImageFont.truetype(str(FONTS / "VT323.ttf"), size)  # noqa: E731
    draw.text((80, 150), "Prince of", font=pixel(84), fill=SAND_PALE)
    draw.text((80, 236), "Versions", font=pixel(112), fill=SAND)
    draw.text((84, 372), "Learn Git. Turn back the sands.", font=mono(46), fill=PAPER)
    draw.text((84, 424), "a __dunder_quest__ game", font=mono(38), fill=TEAL)
    prince = Image.open(ROOT / "assets" / "sprites" / "prince.png").convert("RGBA").crop((DAGGER * PF, 0, DAGGER * PF + PF, PF))
    prince = prince.resize((PF * 4, PF * 4), Image.Resampling.NEAREST)
    art.paste(prince, (600, 374), prince)
    OG.parent.mkdir(parents=True, exist_ok=True)
    art.save(OG, optimize=True)
    print("painted", OG.name, art.size)


if __name__ == "__main__":
    shots()
    sprites()
    card()
