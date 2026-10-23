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


def gradient_left(img: Image.Image, width: int, strength: int) -> None:
    """Darken the left side so the headline reads over the art."""
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    for x in range(width):
        md.line([(x, 0), (x, H)], fill=int(strength * (1 - x / width) ** 1.4))
    img.paste(Image.new("RGB", img.size, NIGHT), (0, 0), mask)


def home_card() -> Image.Image:
    img = backdrop(0.1)
    gradient_left(img, 900, 215)
    d = ImageDraw.Draw(img)
    shadowed(d, (72, 150), "Ember Trail", font(PIXEL, 132), GOLD, 6)
    shadowed(d, (78, 310), "A pixel-art platformer", font(PIXEL, 54), PARCHMENT)
    shadowed(d, (78, 372), "that teaches Python", font(PIXEL, 54), PARCHMENT)
    shadowed(d, (80, 470), "Six stages · free in your browser", font(LABEL, 44), ASH, 3)
    return img


def lessons_card(bank: dict) -> Image.Image:
    img = backdrop(0.72)
    d = ImageDraw.Draw(img)
    shadowed(d, (72, 56), "EMBER TRAIL · LESSONS", font(LABEL, 44), GOLD, 3)
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
    bw = d.textlength("Ember Trail", font=brand)
    shadowed(d, (int(W - 64 - bw), 50), "Ember Trail", brand, GOLD, 3)

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
    """icon.svg as a 512px PNG for og:logo, which crawlers want raster."""
    s = 4
    img = Image.new("RGBA", (128 * s, 128 * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, 128 * s - 1, 128 * s - 1), 16 * s, fill="#2b2d42")
    draw.rounded_rectangle((36 * s, 28 * s, 92 * s - 1, 100 * s - 1), 8 * s, fill="#e85d4c")
    for x in (48, 68):
        draw.rectangle((x * s, 44 * s, (x + 12) * s - 1, 56 * s - 1), fill="#f7f3e9")
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
