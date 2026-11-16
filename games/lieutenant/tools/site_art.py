"""Make the site's art for Just One More JOIN.

Copies the screenshots the page uses out of tests/shots/ (made by
`godot --path . res://tests/shots.tscn`, which needs a window) into
site/static/img/lieutenant/, and paints the social card (1200x630) from the
title's street, the cast's sheets and the game's own fonts.

    python tools/site_art.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
SHOTS = ROOT / "tests" / "shots"
OUT = REPO / "site" / "static" / "img" / "lieutenant"
OG = REPO / "site" / "static" / "img" / "og" / "lieutenant.png"
FONTS = ROOT / "assets" / "fonts"

# Screenshot -> the name the page uses.
PAGE = {
    "00_title": "title", "0p_prologue_5": "query", "1_cold_3": "cold", "3_solution_3c": "notebook",
    "5_printout_5b_ok": "null", "4_printout_4c_misuse_of_aggregate": "error", "5_say_3_point": "door",
    "5_freeze": "freeze",
}

CREAM = (252, 230, 173)
EMBER = (240, 128, 51)
PAPER = (245, 237, 214)


def shots() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for source, name in PAGE.items():
        path = SHOTS / f"{source}.png"
        if not path.exists():
            raise SystemExit(f"{path} is missing: run tests/shots.tscn first")
        Image.open(path).convert("RGB").resize((960, 540), Image.LANCZOS).save(OUT / f"{name}.png", optimize=True)
        print(f"{name}.png")


def card() -> None:
    street = Image.open(ROOT / "assets" / "backgrounds" / "title.png").convert("RGB")
    street = street.resize((1200, 675), Image.NEAREST).crop((0, 30, 1200, 660))
    card = street.convert("RGBA")
    # The Lieutenant and Null, under the lamp.
    for sheet, frame, width, height, feet in (("lt", 0, 64, 128, (958, 570)), ("null", 0, 80, 48, (1066, 580))):
        art = Image.open(ROOT / "assets" / "sprites" / f"{sheet}.png").convert("RGBA").crop((frame * width, 0, (frame + 1) * width, height))
        if sheet == "lt":
            art = art.transpose(Image.FLIP_LEFT_RIGHT)
        art = art.resize((width * 2, height * 2), Image.NEAREST)
        card.alpha_composite(art, (feet[0] - width, feet[1] - height * 2))
    d = ImageDraw.Draw(card)
    big = ImageFont.truetype(str(FONTS / "Caprasimo.ttf"), 96)
    huge = ImageFont.truetype(str(FONTS / "Caprasimo.ttf"), 150)
    mono = ImageFont.truetype(str(FONTS / "VT323.ttf"), 44)
    small = ImageFont.truetype(str(FONTS / "VT323.ttf"), 36)
    for dx, dy in ((4, 4),):
        d.text((70 + dx, 62 + dy), "Just One More", font=big, fill=(10, 8, 20))
        d.text((66 + dx, 150 + dy), "JOIN", font=huge, fill=(10, 8, 20))
    d.text((70, 62), "Just One More", font=big, fill=CREAM)
    d.text((66, 150), "JOIN", font=huge, fill=EMBER)
    d.text((72, 336), "He knows who did it.", font=mono, fill=PAPER)
    d.text((72, 378), "He needs a query that proves it.", font=mono, fill=PAPER)
    d.rectangle((72, 440, 72 + 190, 440 + 50), fill=EMBER)
    d.text((88, 442), "Learn SQL", font=mono, fill=(23, 18, 15))
    d.text((72, 508), "a __dunder_quest__ game", font=small, fill=EMBER)
    OG.parent.mkdir(parents=True, exist_ok=True)
    card.convert("RGB").save(OG, optimize=True)
    print(f"og/lieutenant.png {card.size[0]}x{card.size[1]}")


if __name__ == "__main__":
    shots()
    card()
