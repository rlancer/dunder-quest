"""Paint the 1200x630 social preview cards the site's og:image tags point at.

Each card is the title art behind a headline in the game's own fonts. Stage
cards add that stage's wizard duel, so a shared lesson link shows the Python
question the player meets. Writes into `site/static/img/og/`; rerun it when a
stage name, topic or duel capture changes.

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
    "amber-hollow": "tour_amber_duel.png",
    "cinder-span": "tour_span_duel_wrong.png",
    "kiln-mouth": "tour_kiln_duel_hex.png",
    "smelters-fork": "tour_fork_duel.png",
    "bellows-bridge": "tour_bridge_duel.png",
    "crucible-crown": "tour_crown_duel.png",
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
    pebble = Image.open(ROOT / "assets" / "sprites" / "pebble.png").convert("RGBA")
    pebble = pebble.resize((pebble.width * 7, pebble.height * 7), Image.NEAREST)
    img.paste(pebble, (W // 2 - pebble.width // 2, H - pebble.height - 16), pebble)
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
    the rects in step with the SVG: a pixel q between two pairs of underscores,
    its tail dropping past them the way it does in typed `__q__`."""
    s = 4
    img = Image.new("RGBA", (128 * s, 128 * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, 128 * s - 1, 128 * s - 1), 16 * s, fill=NIGHT)
    draw.rounded_rectangle((4 * s, 4 * s, 124 * s - 1, 124 * s - 1), 12 * s, outline=GOLD, width=4 * s)
    for x, y, w, h, fill in [
        (56, 28, 24, 8, PARCHMENT), (48, 36, 8, 24, PARCHMENT), (72, 36, 8, 64, PARCHMENT), (56, 60, 16, 8, PARCHMENT),
        (12, 84, 14, 8, EMBER), (29, 84, 14, 8, EMBER), (85, 84, 14, 8, EMBER), (102, 84, 14, 8, EMBER),
    ]:
        draw.rectangle((x * s, y * s, (x + w) * s - 1, (y + h) * s - 1), fill=fill)
    return img


def main() -> None:
    bank = json.loads((ROOT / "data" / "lessons.json").read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    cards = {"home.png": home_card(), "lessons.png": lessons_card(bank), "logo.png": logo()}
    for stage in STAGES:
        cards[f"{stage['slug']}.png"] = stage_card(stage, bank[str(stage["id"])]["topic"])
    for name, img in cards.items():
        img.save(OUT / name, optimize=True)
        print(f"wrote {(OUT / name).relative_to(ROOT)}")


if __name__ == "__main__":
    main()
