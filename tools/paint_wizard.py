"""Paint the dark wizard who guards each stage, pixel by pixel.

Like the tiles, an 18x28 figure loses its face and staff when an image model
is squeezed down this far, so it is drawn here from a character map.
Two idle frames side by side: the robe hem and beard sway between them.
The staff orb is painted pale so the scene's additive glow can tint it per stage.

    python tools/paint_wizard.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites"

PALETTE = {
    ".": (0, 0, 0, 0),
    "K": (24, 14, 26, 255),
    "H": (46, 28, 66, 255),
    "h": (74, 46, 104, 255),
    "i": (112, 78, 150, 255),
    "R": (34, 22, 50, 255),
    "r": (58, 38, 86, 255),
    "q": (84, 58, 118, 255),
    "t": (176, 112, 54, 255),
    "T": (246, 196, 104, 255),
    "S": (16, 10, 18, 255),
    "E": (255, 196, 72, 255),
    "e": (204, 92, 40, 255),
    "B": (206, 200, 210, 255),
    "b": (146, 138, 156, 255),
    "W": (104, 60, 38, 255),
    "w": (164, 104, 58, 255),
    "O": (236, 250, 255, 255),
    "o": (150, 214, 240, 255),
    "p": (84, 136, 186, 255),
    "G": (176, 156, 166, 255),
    "g": (120, 100, 116, 255),
}

# Facing left, toward the player. Staff in the near hand, hat tip bent back.
FRAME_A = [
    "..............KK..",
    ".............KhK..",
    "............KhhK..",
    "...........KhhK...",
    "..KKK.....KhhhK...",
    ".KoOoK....KhihK...",
    ".KOOoK...KhhihK...",
    ".KpopK...KhhihhK..",
    "..KWK...KhhhhihK..",
    "..KwK..KttTtttttK.",
    "..KwK.KHHHHHHHHHHK",
    "..KwK.KKKKKKKKKKKK",
    "..KwK..KSESSESSK..",
    "..KwK..KSSSSSSSK..",
    "..KwKKKBBBBBBbSK..",
    "..KGGgKBBBBBbbrRK.",
    "..KGGgKbBBBBbrrRK.",
    "..KwKKrKBBBbrrqrRK",
    "..KwK.KrKBBbrqrrRK",
    "..KwK.KrrKbrrqrrRK",
    "..KwK.KrrrrrrqrrRK",
    "..KwK.KrrrrrqrrrRK",
    "..KwK.KrrrrrqrrRRK",
    "..KwK.KrrrrqrrrRRK",
    "..KwK.KrrrrqrrrRRK",
    "..KwKKrrrrqrrrrRRK",
    "..KWKKtTtttttttttK",
    "..KKK.KKKKKKKKKKK.",
]

FRAME_B = [
    "..............KK..",
    ".............KhK..",
    "............KhhK..",
    "...........KhhK...",
    "..KKK.....KhhhK...",
    ".KoOoK....KhihK...",
    ".KOOOK...KhhihK...",
    ".KpopK...KhhihhK..",
    "..KWK...KhhhhihK..",
    "..KwK..KttTtttttK.",
    "..KwK.KHHHHHHHHHHK",
    "..KwK.KKKKKKKKKKKK",
    "..KwK..KSESSESSK..",
    "..KwK..KSSSSSSSK..",
    "..KwKKKBBBBBBbSK..",
    "..KGGgKBBBBBbbrRK.",
    "..KGGgKbBBBBbrrRK.",
    "..KwKKrKbBBBbrqrRK",
    "..KwK.KrKbBBbqrrRK",
    "..KwK.KrrKbbrqrrRK",
    "..KwK.KrrrrrrqrrRK",
    "..KwK.KrrrrrqrrrRK",
    "..KwK.KrrrrrqrrRRK",
    "..KwK.KrrrrqrrrRRK",
    "..KwK.KrrrrqrrrRRK",
    "..KwK.KrrrqrrrrRRK",
    "..KWKKKtTttttttttK",
    "..KKK..KKKKKKKKKK.",
]


def paint(frame: list[str]) -> Image.Image:
    height = len(frame)
    width = len(frame[0])
    image = Image.new("RGBA", (width, height), PALETTE["."])
    for y, row in enumerate(frame):
        if len(row) != width:
            raise ValueError(f"row {y} is {len(row)} wide, expected {width}: {row!r}")
        for x, key in enumerate(row):
            image.putpixel((x, y), PALETTE[key])
    return image


def main() -> None:
    frames = [paint(FRAME_A), paint(FRAME_B)]
    width, height = frames[0].size
    sheet = Image.new("RGBA", (width * len(frames), height), PALETTE["."])
    for index, frame in enumerate(frames):
        sheet.paste(frame, (index * width, 0))
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / "wizard.png")
    print(f"wrote {OUT / 'wizard.png'} {sheet.size}")


if __name__ == "__main__":
    main()
