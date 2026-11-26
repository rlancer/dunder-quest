"""Make the site's art for Yes, Shell!

Copies the screenshots the page uses out of tests/shots/ (made by
`godot --path . res://tests/shots.tscn`, which needs a window) into
site/static/img/shell/, the cast's portraits beside them, and paints the
social card (1200x630) from the title's art and the game's own fonts.

    python tools/site_art.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent
SHOTS = ROOT / "tests" / "shots"
OUT = REPO / "site" / "static" / "img" / "shell"
OG = REPO / "site" / "static" / "img" / "og" / "shell.png"
FONTS = ROOT / "assets" / "fonts"

# Part of a screenshot's name -> the name the page uses.
PAGE = {
    "_title": "title", "prologue_7": "intro", "card_pipe": "card", "1c_written": "family",
    "2b_missed": "rail", "3d_written": "pass", "4d_sent": "mise", "5d_written": "critic",
}
CAST = ["chef", "shell", "awk", "dev", "root"]

CREAM = (247, 242, 224)
AMBER = (245, 158, 46)
PAPER = (242, 240, 230)
INK = (26, 28, 33)
RED = (194, 44, 34)
GREEN = (35, 128, 79)
TERM = (10, 15, 18)
TERM_TEXT = (209, 237, 214)


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
    d = ImageDraw.Draw(card)
    bebas = lambda size: ImageFont.truetype(str(FONTS / "BebasNeue.ttf"), size)  # noqa: E731
    mono = ImageFont.truetype(str(FONTS / "VT323.ttf"), 44)
    small = ImageFont.truetype(str(FONTS / "VT323.ttf"), 36)
    left = 640

    def put(at: tuple[int, int], words: str, font: ImageFont.FreeTypeFont, fill: tuple[int, int, int]) -> None:
        d.text((at[0] + 4, at[1] + 4), words, font=font, fill=(6, 8, 16))
        d.text(at, words, font=font, fill=fill)

    put((left, 44), "THE STANDARD INN PRESENTS", bebas(34), CREAM)
    put((left - 2, 88), "YES, SHELL!", bebas(146), AMBER)
    put((left, 252), "Read the ticket.", mono, PAPER)
    put((left, 294), "Build the line.", mono, PAPER)
    d.rectangle((left, 360, left + 420, 410), fill=RED)
    d.text((left + 16, 362), "Learn the command line", font=mono, fill=CREAM)
    put((left, 432), "a __dunder_quest__ game", small, AMBER)
    # A line on a terminal, so the card says what kind of game it is.
    d.rectangle((left, 500, 1168, 556), fill=TERM, outline=(74, 84, 98), width=3)
    x = left + 16
    for word, fill in (("$", (120, 222, 145)), ("grep", (255, 209, 107)), ("beef", TERM_TEXT), ("orders.txt", (120, 222, 145)),
                       ("|", CREAM), ("wc", (255, 209, 107)), ("-l", (247, 107, 84))):
        d.text((x, 508), word, font=small, fill=fill)
        x += int(d.textlength(word + " ", font=small))
    # Shell and the Chef, at the door.
    for who, x in (("shell", 10), ("chef", 250)):
        face = Image.open(ROOT / "assets" / "sprites" / f"{who}.png").convert("RGBA").resize((288, 288), Image.NEAREST)
        card.alpha_composite(face, (x, 630 - 288))
    OG.parent.mkdir(parents=True, exist_ok=True)
    card.convert("RGB").save(OG, optimize=True)
    print(f"og/shell.png {card.size[0]}x{card.size[1]}")


if __name__ == "__main__":
    shots()
    card()
