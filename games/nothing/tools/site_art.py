"""Make the site's art for A Game About Nothing.

Copies the screenshots the page uses out of tests/shots/ (made by
`godot --path . res://tests/shots.tscn`, which needs a window; in a cloud
session, under `xvfb-run`) into site/static/img/nothing/, the cast's
portraits beside them, and paints the social card (1200x630) from the
title's art and the game's own fonts.

    python tools/site_art.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
SHOTS = ROOT / "tests" / "shots"
OUT = REPO / "site" / "static" / "img" / "nothing"
OG = REPO / "site" / "static" / "img" / "og" / "nothing.png"
FONTS = ROOT / "assets" / "fonts"

# Part of a screenshot's name -> the name the page uses.
PAGE = {
    "_title.png": "title", "prologue_4": "intro", "card_then": "card", "1d_rolling": "callback",
    "2c_rolling": "wait", "3d_rolling": "promise", "4d_rolling": "chain", "5d_rolling": "tableread",
    "1a_missed": "missed",
}
CAST = ["stu", "lenny", "dana", "zelnick", "vernon", "pratt"]

CREAM = (252, 245, 227)
MUSTARD = (232, 176, 58)
MUSTARD_LIGHT = (255, 217, 128)
BRICK = (181, 69, 46)
INK = (28, 20, 33)
PAPER = (247, 240, 219)
TEAL = (33, 128, 128)
BLUE = (51, 82, 158)


def shots() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for part, name in PAGE.items():
        found = sorted(p for p in SHOTS.glob("*.png") if part in p.name)
        if not found:
            raise SystemExit(f"no screenshot matching {part}: run tests/shots.tscn first")
        Image.open(found[0]).convert("RGB").resize((960, 540), Image.NEAREST).save(OUT / f"{name}.png", optimize=True)
        print(f"{name}.png <- {found[0].name}")
    for who in CAST:
        art = Image.open(ROOT / "assets" / "sprites" / f"{who}.png").convert("RGBA")
        art.resize((192, 192), Image.NEAREST).save(OUT / f"cast_{who}.png", optimize=True)
        print(f"cast_{who}.png")


def card() -> None:
    art = Image.open(ROOT / "assets" / "backgrounds" / "title.png").convert("RGB")
    card = art.resize((1200, 675), Image.NEAREST).crop((0, 22, 1200, 652)).convert("RGBA")
    d = ImageDraw.Draw(card)
    righteous = lambda size: ImageFont.truetype(str(FONTS / "Righteous.ttf"), size)  # noqa: E731
    mono = ImageFont.truetype(str(FONTS / "VT323.ttf"), 44)
    small = ImageFont.truetype(str(FONTS / "VT323.ttf"), 36)
    left = 640

    def put(at: tuple[int, int], words: str, font: ImageFont.FreeTypeFont, fill: tuple[int, int, int]) -> None:
        d.text((at[0] + 5, at[1] + 5), words, font=font, fill=(16, 10, 22))
        d.text(at, words, font=font, fill=fill)

    put((left, 40), "A GAME ABOUT", righteous(54), CREAM)
    put((left - 4, 98), "NOTHING", righteous(112), MUSTARD)
    put((left, 236), "Cue the lines. Roll tape.", mono, CREAM)
    words = "Learn the JavaScript event loop"
    d.rectangle((left, 292, left + 32 + int(d.textlength(words, font=small)), 338), fill=BRICK)
    d.text((left + 16, 296), words, font=small, fill=CREAM)
    put((left, 362), "a __dunder_quest__ game", small, MUSTARD_LIGHT)
    # A scrap of script, so the card says what kind of game it is.
    page = (left, 418, 1168, 598)
    d.rectangle(page, fill=PAPER, outline=(168, 156, 140), width=3)
    lines = [
        [("setTimeout", TEAL), ("(() => {", INK)],
        [("  log", TEAL), ("(", INK), ('"Zelnick bursts in"', BRICK), (");", INK)],
        [("}, ", INK), ("0", (153, 97, 13)), (");", INK)],
        [("log", TEAL), ("(", INK), ('"Stu sits down"', BRICK), (");", INK)],
    ]
    for row, words in enumerate(lines):
        x = left + 20
        for word, fill in words:
            d.text((x, 426 + row * 40), word, font=small, fill=fill)
            x += int(d.textlength(word, font=small))
    # Stu and Lenny, in the doorway.
    for who, x in (("lenny", 20), ("stu", 260)):
        face = Image.open(ROOT / "assets" / "sprites" / f"{who}.png").convert("RGBA").resize((288, 288), Image.NEAREST)
        card.alpha_composite(face, (x, 630 - 288))
    OG.parent.mkdir(parents=True, exist_ok=True)
    card.convert("RGB").save(OG, optimize=True)
    print(f"og/nothing.png {card.size[0]}x{card.size[1]}")


if __name__ == "__main__":
    shots()
    card()
