"""Paint the 1200x630 social preview cards the site's og:image tags point at.

Each card is the title art behind a headline in the game's own fonts. Stage
cards add that stage's guardian duel, so a shared lesson link shows the Python
question the player meets. Writes into `site/static/img/og/`, plus
`site/favicon.ico` from the logo; rerun it when a stage name, topic, duel
capture or the logo changes.

    python tools/make_og.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "site"))
from build import STAGES  # noqa: E402

OUT = ROOT / "site" / "static" / "img" / "og"
FAVICON = ROOT / "site" / "favicon.ico"
W, H = 1200, 630
PIXEL = ROOT / "assets" / "fonts" / "PixelifySans.ttf"
LABEL = ROOT / "assets" / "fonts" / "VT323.ttf"
GOLD = (242, 181, 68)
PARCHMENT = (244, 228, 196)
ASH = (176, 169, 208)
EMBER = (255, 138, 61)
NIGHT = (21, 18, 42)
LINE = (74, 79, 134)

DUELS = {
    "shrubbery-wood": "tour_amber_duel.png",
    "cheese-shoppe": "tour_span_duel_wrong.png",
    "cave-of-the-bunny": "tour_kiln_duel_hex.png",
    "ministry-of-walks": "tour_fork_duel.png",
    "bridge-of-peril": "tour_bridge_duel.png",
    "castle-aargh": "tour_crown_duel.png",
}


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def upscale(img: Image.Image, scale: float) -> Image.Image:
    """Scale pixel art by a non-integer factor without uneven pixel widths:
    blow it up by a whole number first, then box-filter down to size."""
    whole = int(scale * 2 + 0.999)
    big = img.resize((img.width * whole, img.height * whole), Image.NEAREST)
    return big.resize((round(img.width * scale), round(img.height * scale)), Image.BOX)


def backdrop(dim: float) -> Image.Image:
    art = Image.open(ROOT / "assets" / "backgrounds" / "title_art.png").convert("RGB")
    art = upscale(art, 2.5)  # 1200x675
    art = art.crop((0, 20, W, 20 + H))
    shade = Image.new("RGB", art.size, NIGHT)
    return Image.blend(art, shade, dim)


def shadowed(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fnt, fill, offset: int = 4) -> None:
    x, y = xy
    draw.text((x + offset, y + offset), text, font=fnt, fill=NIGHT)
    draw.text((x, y), text, font=fnt, fill=fill)


def wordmark(draw: ImageDraw.ImageDraw, xy: tuple[int, int], fnt, offset: int = 4) -> int:
    """`__dunder_quest__`, the logo: gold letters between ember underscores,
    the way Python's dunder names sit between theirs. Returns the width drawn."""
    x, y = xy
    for part, fill in (("__", EMBER), ("dunder_quest", GOLD), ("__", EMBER)):
        shadowed(draw, (x, y), part, fnt, fill, offset)
        x += int(draw.textlength(part, font=fnt))
    return x - xy[0]


def wordmark_width(draw: ImageDraw.ImageDraw, fnt) -> int:
    return int(sum(draw.textlength(part, font=fnt) for part in ("__", "dunder_quest", "__")))


def vignette(img: Image.Image, strength: int) -> None:
    """Darken toward the middle so centered text reads over the art."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse((W // 2 - 520, -80, W // 2 + 520, 520), fill=strength)
    img.paste(Image.new("RGB", img.size, NIGHT), (0, 0), mask.filter(ImageFilter.GaussianBlur(90)))


def home_card() -> Image.Image:
    """Chat apps often show this as a thumbnail cropped from the middle, so
    the wordmark is stacked and centered to survive a square crop."""
    img = backdrop(0.15)
    vignette(img, 200)
    d = ImageDraw.Draw(img)
    big = font(PIXEL, 132)
    lines = (("__", EMBER), ("dunder_", GOLD)), (("quest", GOLD), ("__", EMBER))
    for y, parts in zip((36, 168), lines):
        x = (W - sum(int(d.textlength(t, font=big)) for t, _ in parts)) // 2
        for text, fill in parts:
            shadowed(d, (x, y), text, big, fill, 7)
            x += int(d.textlength(text, font=big))
    tag = font(PIXEL, 44)
    line = "A pixel-art platformer that teaches Python"
    shadowed(d, ((W - int(d.textlength(line, font=tag))) // 2, 334), line, tag, PARCHMENT)
    squire = Image.open(ROOT / "assets" / "sprites" / "squire.png").convert("RGBA")
    squire = squire.resize((squire.width * 7, squire.height * 7), Image.NEAREST)
    img.paste(squire, (W // 2 - squire.width // 2, H - squire.height - 16), squire)
    return img


def lessons_card(bank: dict) -> Image.Image:
    img = backdrop(0.72)
    d = ImageDraw.Draw(img)
    shadowed(d, (72, 56), "__dunder_quest__ · LESSONS", font(LABEL, 44), GOLD, 3)
    shadowed(d, (72, 104), "The Python you learn on the trail", font(PIXEL, 60), PARCHMENT)
    topics = [bank[str(s["id"])]["topic"] for s in STAGES]
    row = font(PIXEL, 38)
    num = font(LABEL, 46)
    for i, (stage, topic) in enumerate(zip(STAGES, topics)):
        col, r = divmod(i, 3)
        x, y = 72 + col * 560, 250 + r * 105
        tint = tuple(int(stage["tint"][k:k + 2], 16) for k in (1, 3, 5))
        d.rectangle((x, y + 6, x + 52, y + 58), fill=NIGHT, outline=tint, width=3)
        d.text((x + 26, y + 33), str(stage["id"]), font=num, fill=tint, anchor="mm")
        shadowed(d, (x + 76, y + 8), topic, row, PARCHMENT, 3)
    return img


def stage_card(stage: dict, topic: str) -> Image.Image:
    img = backdrop(0.72)
    d = ImageDraw.Draw(img)
    tint = tuple(int(stage["tint"][k:k + 2], 16) for k in (1, 3, 5))
    shadowed(d, (64, 40), f"STAGE {stage['id']} · {stage['name'].upper()}", font(LABEL, 44), tint, 3)
    shadowed(d, (64, 84), topic, font(PIXEL, 76), PARCHMENT, 5)
    brand = font(PIXEL, 40)
    wordmark(d, (W - 64 - wordmark_width(d, brand), 50), brand, 3)

    duel = Image.open(ROOT / "tests" / "shots" / DUELS[stage["slug"]]).convert("RGB")
    shot = duel.resize((duel.width * 2, duel.height * 2), Image.NEAREST)
    x, y = (W - shot.width) // 2, 200
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rectangle((x - 10, y - 10, x + shot.width + 10, H + 20), fill=tint + (150,))
    img.paste(glow.filter(ImageFilter.GaussianBlur(14)), (0, 0), glow.filter(ImageFilter.GaussianBlur(14)))
    img.paste(shot.crop((0, 0, shot.width, H - y)), (x, y))
    d.rectangle((x - 4, y - 4, x + shot.width + 3, H + 4), outline=LINE, width=4)
    return img


def logo() -> Image.Image:
    """icon.svg as a 512px PNG for og:logo, which crawlers want raster. Keep
    the rects in step with the SVG: `__q__` drawn the way Pixelify Sans types
    it, on a 6px grid. The underscores sit on the baseline, level with the
    bottom of the q's bowl, and only its tail drops below."""
    s = 4
    img = Image.new("RGBA", (128 * s, 128 * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, 128 * s - 1, 128 * s - 1), 16 * s, fill=NIGHT)
    draw.rounded_rectangle((4 * s, 4 * s, 124 * s - 1, 124 * s - 1), 12 * s, outline=GOLD, width=4 * s)
    for x, y, w, h, fill in [
        (55, 43, 18, 6, PARCHMENT), (49, 49, 6, 18, PARCHMENT), (73, 49, 6, 36, PARCHMENT), (55, 67, 18, 6, PARCHMENT),
        (13, 67, 12, 6, EMBER), (31, 67, 12, 6, EMBER), (85, 67, 12, 6, EMBER), (103, 67, 12, 6, EMBER),
    ]:
        draw.rectangle((x * s, y * s, (x + w) * s - 1, (y + h) * s - 1), fill=fill)
    return img


# The q from the logo's grid, for drawing it again at favicon sizes.
Q_PIXELS = [".###.", "#...#", "#...#", "#...#", ".####", "....#", "....#"]


def tiny_logo(n: int, border: int, unit: int, under: int, pairs: int, space: int, gap: int) -> Image.Image:
    """The logo redrawn on whole pixels at favicon size, since shrinking the
    128px art blurs it. `under` is each underscore's width, `pairs` how many
    sit on each side (one at 16px, where two run together anyway), `space`
    the gap between two underscores, and `gap` the gap to the q."""
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, n - 1, n - 1), fill=GOLD)
    draw.rectangle((border, border, n - 1 - border, n - 1 - border), fill=NIGHT)
    for corner in ((0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)):
        img.putpixel(corner, (0, 0, 0, 0))
    side = pairs * under + (pairs - 1) * space
    x = (n - 2 * side - 2 * gap - 5 * unit) // 2
    top = (n - 7 * unit) // 2
    baseline = top + 4 * unit

    def underscores(x: int) -> int:
        for _ in range(pairs):
            draw.rectangle((x, baseline, x + under - 1, baseline + unit - 1), fill=EMBER)
            x += under + space
        return x - space

    x = underscores(x) + gap
    for row, line in enumerate(Q_PIXELS):
        for col, cell in enumerate(line):
            if cell == "#":
                px, py = x + col * unit, top + row * unit
                draw.rectangle((px, py, px + unit - 1, py + unit - 1), fill=PARCHMENT)
    underscores(x + 5 * unit + gap)
    return img


def favicon() -> None:
    """/favicon.ico, for tools that ask for that path instead of reading the
    page's icon link. site/build.py copies it to the site root."""
    sizes = [tiny_logo(16, 1, 1, 3, 1, 0, 1), tiny_logo(32, 1, 2, 3, 2, 1, 2), tiny_logo(48, 2, 3, 4, 2, 2, 3)]
    sizes[-1].save(FAVICON, format="ICO", sizes=[im.size for im in sizes], append_images=sizes[:-1])
    print(f"wrote {FAVICON.relative_to(ROOT)}")


def site_art() -> None:
    """The world map cropped for the home page's trail (its pins come from
    `x`/`y` in site/build.py), and each guardian's first frame at 2x for the
    lesson pages."""
    art = ROOT / "site" / "static" / "img"
    world = Image.open(ROOT / "assets" / "backgrounds" / "world_map.png").convert("RGB")
    world.crop((0, 22, 480, 190)).save(art / "trail_map.png")
    (art / "foes").mkdir(exist_ok=True)
    for stage in STAGES:
        sheet = Image.open(ROOT / "assets" / "sprites" / f"foe_{stage['id']}.png").convert("RGBA")
        frame = sheet.crop((0, 0, sheet.width // 2, sheet.height))
        frame.resize((frame.width * 2, frame.height * 2), Image.NEAREST).save(art / "foes" / f"foe_{stage['id']}.png")


def main() -> None:
    bank = json.loads((ROOT / "data" / "lessons.json").read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    cards = {"home.png": home_card(), "lessons.png": lessons_card(bank), "logo.png": logo()}
    favicon()
    site_art()
    for stage in STAGES:
        cards[f"{stage['slug']}.png"] = stage_card(stage, bank[str(stage["id"])]["topic"])
    for name, img in cards.items():
        img.save(OUT / name, optimize=True)
        print(f"wrote {(OUT / name).relative_to(ROOT)}")


if __name__ == "__main__":
    main()
