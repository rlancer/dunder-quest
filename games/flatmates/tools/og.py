"""Paint the social preview card for dunderquest.com/flatmates/.

The title art, scaled up on whole pixels, with the name and a line about
the game. Writes ../../site/static/img/og/flatmates.png (1200x630), next to the
Python game's cards.

    python tools/og.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[1] / "site" / "static" / "img" / "og" / "flatmates.png"
FONTS = ROOT / "assets" / "fonts"
PAPER = (244, 234, 214)
JS = (247, 223, 30)
INK = (20, 18, 26)


def shadowed(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, font, fill) -> int:
    x, y = xy
    draw.text((x + 4, y + 4), text, font=font, fill=INK)
    draw.text((x, y), text, font=font, fill=fill)
    return int(draw.textlength(text, font=font))


def main() -> None:
    art = Image.open(ROOT / "assets" / "backgrounds" / "title.png").convert("RGB")
    card = art.resize((art.width * 5 // 2, art.height * 5 // 2), Image.NEAREST).crop((0, 22, 1200, 652))
    shade = Image.new("RGBA", card.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).rectangle((0, 0, 700, 630), fill=(10, 8, 16, 120))
    card = Image.alpha_composite(card.convert("RGBA"), shade)
    draw = ImageDraw.Draw(card)
    big = ImageFont.truetype(str(FONTS / "PixelifySans.ttf"), 120)
    mono = ImageFont.truetype(str(FONTS / "VT323.ttf"), 52)
    x = 60
    x += shadowed(draw, (x, 120), "flatmates", big, PAPER)
    shadowed(draw, (x, 120), ".js", big, JS)
    shadowed(draw, (64, 290), "Two flatmates. Two points of view.", mono, PAPER)
    shadowed(draw, (64, 344), "One of them runs your JavaScript.", mono, PAPER)
    shadowed(draw, (64, 470), "a __dunder_quest__ game", mono, (255, 178, 76))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    card.convert("RGB").save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
