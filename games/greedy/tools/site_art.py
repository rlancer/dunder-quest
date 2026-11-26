"""Make the site's art for The Good, the Bad and the Greedy.

Copies the screenshots the page uses out of tests/shots/ (made by
`godot --path . res://tests/shots.tscn`, which needs a window) into
site/static/img/greedy/, the cast's portraits beside them, and paints the
social card (1200x630) from the title's art and the game's own fonts.

    python tools/site_art.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
SHOTS = ROOT / "tests" / "shots"
OUT = REPO / "site" / "static" / "img" / "greedy"
OG = REPO / "site" / "static" / "img" / "og" / "greedy.png"
FONTS = ROOT / "assets" / "fonts"

# Part of a screenshot's name -> the name the page uses.
PAGE = {
    "_title": "title", "prologue_8": "intro", "card_greedy": "card", "1b_written": "street",
    "2_say_sheriff": "toll", "3_title": "beans", "4_say_dot": "saloon", "5c_written": "showdown",
}
CAST = ["sheriff", "kid", "dot", "mayor", "gibber", "backtrack"]

CREAM = (250, 232, 190)
GOLD = (240, 176, 56)
PAPER = (236, 218, 170)
INK = (36, 20, 14)
RED = (176, 48, 36)


def shots() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for part, name in PAGE.items():
        found = sorted(SHOTS.glob(f"*{part}*.png"))
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
    # The Sheriff and the Kid, in the corner.
    for who, x in (("kid", 30), ("sheriff", 270)):
        face = Image.open(ROOT / "assets" / "sprites" / f"{who}.png").convert("RGBA").resize((288, 288), Image.NEAREST)
        card.alpha_composite(face, (x, 630 - 288))
    d = ImageDraw.Draw(card)
    rye = lambda size: ImageFont.truetype(str(FONTS / "Rye.ttf"), size)  # noqa: E731
    mono = ImageFont.truetype(str(FONTS / "VT323.ttf"), 44)
    small = ImageFont.truetype(str(FONTS / "VT323.ttf"), 36)
    left = 640

    def put(at: tuple[int, int], words: str, font: ImageFont.FreeTypeFont, fill: tuple[int, int, int]) -> None:
        d.text((at[0] + 4, at[1] + 4), words, font=font, fill=(16, 8, 20))
        d.text(at, words, font=font, fill=fill)

    put((left, 60), "The Good, the Bad", rye(50), CREAM)
    put((left, 122), "and the", rye(36), CREAM)
    put((left - 4, 164), "GREEDY", rye(112), GOLD)
    put((left, 312), "Write the poster.", mono, PAPER)
    put((left, 354), "Catch who fits.", mono, PAPER)
    d.rectangle((left, 420, left + 250, 470), fill=RED)
    d.text((left + 16, 422), "Learn regex", font=mono, fill=CREAM)
    put((left, 500), "a __dunder_quest__ game", small, GOLD)
    # A poster chip row, so the card says what kind of game it is.
    x = left
    for chip in ("^", "H", ".", "nk", "\\b"):
        wide = int(d.textlength(chip, font=small)) + 22
        d.rectangle((x, 560, x + wide, 604), fill=PAPER, outline=INK, width=3)
        d.text((x + 11, 562), chip, font=small, fill=INK)
        x += wide + 10
    OG.parent.mkdir(parents=True, exist_ok=True)
    card.convert("RGB").save(OG, optimize=True)
    print(f"og/greedy.png {card.size[0]}x{card.size[1]}")


if __name__ == "__main__":
    shots()
    card()
