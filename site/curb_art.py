"""Make what dunderquest.com/curb/ shows for Curb Your Oxidation.

- Copies the title art, each episode's opening, the screenshots the page
  uses (from games/curb/tests/shots/: run `godot --path . res://tests/shots.tscn
  -- scene=N` in games/curb first), and a close-up and a standing frame for
  each of the main cast into site/static/img/curb/.
- Paints the social preview card, site/static/img/og/curb.png (1200x630): a
  black title card, the name in the show's yellow serif, over the Westside
  at sunset.
- Paints site/static/img/curb/trailer.png (1920x1080), the trailer's
  thumbnail, unless the trailer has its own at
  games/curb/trailer/out/curb_thumbnail.png, which it copies instead.
- Writes site/curb_cases.json: the in-game checker's verdict on every
  combination of every plan's blanks (games/curb/tests/out/cases.json, from
  `godot --headless --path . --script res://tests/cases.gd`), so the pads on
  the page answer exactly as the game does.

Everything it writes is committed, since the shots and cases aren't.

    python site/curb_art.py
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SITE = Path(__file__).resolve().parent
CURB = SITE.parent / "games" / "curb"
OUT = SITE / "static" / "img" / "curb"
OG = SITE / "static" / "img" / "og" / "curb.png"
FONTS = CURB / "assets" / "fonts"
SHOTS = CURB / "tests" / "shots"
INK = (18, 15, 20)
PAPER = (247, 240, 219)
RUST = (217, 107, 46)
EMBER = (255, 178, 76)
## The show's yellow (Palette.YELLOW), for the name.
YELLOW = (250, 212, 28)
CAST = ["barry", "gil", "sharon", "carol", "lamont", "ted"]
## Screenshots the page shows: how a plan goes, in scene 3, and each
## episode's opening bicker.
PAGE_SHOTS = ["03_pad.png", "03_rant.png", "03_run.png"]
PAGE_SHOTS += [f"{n:02d}_opening.png" for n in range(1, 11)]


def centered(draw: ImageDraw.ImageDraw, y: int, text: str, font, fill, width: int) -> None:
    w = draw.textlength(text, font=font)
    draw.text(((width - w) / 2, y), text, font=font, fill=fill)


def og_card() -> None:
    art = Image.open(CURB / "assets" / "backgrounds" / "title.png").convert("RGB")
    art = art.resize((art.width * 5 // 2, art.height * 5 // 2), Image.NEAREST)
    card = Image.new("RGB", (1200, 630), INK)
    card.paste(art.crop((0, 675 - 290, 1200, 675)), (0, 340))
    draw = ImageDraw.Draw(card)
    serif = ImageFont.truetype(str(FONTS / "LibreBaskerville.ttf"), 86)
    small = ImageFont.truetype(str(FONTS / "LibreBaskerville.ttf"), 32)
    mono = ImageFont.truetype(str(FONTS / "VT323.ttf"), 44)
    centered(draw, 70, "Curb Your Oxidation", serif, YELLOW, 1200)
    centered(draw, 196, "The borrow checker is the unwritten social contract.", small, PAPER, 1200)
    centered(draw, 262, "learn Rust · a __dunder_quest__ game", mono, EMBER, 1200)
    OG.parent.mkdir(parents=True, exist_ok=True)
    card.save(OG)
    print("wrote", OG)


def thumbnail() -> None:
    own = CURB / "trailer" / "out" / "curb_thumbnail.png"
    if own.exists():
        shutil.copyfile(own, OUT / "trailer.png")
        print("copied", own)
        return
    shot = Image.open(SHOTS / "03_rant.png").convert("RGB").resize((1920, 1080), Image.NEAREST)
    thumb = Image.new("RGB", (1920, 1080), INK)
    thumb.paste(shot.crop((0, 380, 1920, 1080)), (0, 380))
    draw = ImageDraw.Draw(thumb)
    serif = ImageFont.truetype(str(FONTS / "LibreBaskerville.ttf"), 150)
    small = ImageFont.truetype(str(FONTS / "LibreBaskerville.ttf"), 56)
    centered(draw, 60, "Curb Your Oxidation", serif, YELLOW, 1920)
    centered(draw, 260, "Learn Rust. Mind your manners.", small, EMBER, 1920)
    thumb.save(OUT / "trailer.png")
    print("wrote", OUT / "trailer.png")


def cases() -> None:
    raw = json.loads((CURB / "tests" / "out" / "cases.json").read_text(encoding="utf-8"))
    keep = ("plan", "picks", "ok", "first", "stdout", "panic")
    trimmed = [{k: c[k] for k in keep if k in c} for c in raw]
    path = SITE / "curb_cases.json"
    path.write_text(json.dumps(trimmed, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", path, len(trimmed), "combinations")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(CURB / "assets" / "backgrounds" / "title.png", OUT / "title.png")
    for who in CAST:
        Image.open(CURB / "assets" / "sprites" / f"{who}_face.png").crop((0, 0, 48, 48)).save(OUT / f"{who}_face.png")
        Image.open(CURB / "assets" / "sprites" / f"{who}.png").crop((0, 0, 24, 48)).save(OUT / f"{who}.png")
    for name in PAGE_SHOTS:
        shutil.copyfile(SHOTS / name, OUT / name)
    og_card()
    thumbnail()
    cases()
    print("wrote", OUT)


if __name__ == "__main__":
    main()
