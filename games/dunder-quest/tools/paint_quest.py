"""Paint the Holy Grail quest's cast pixel by pixel.

Like the tiles and the old wizard, figures this small lose their faces when an
image model is squeezed down to them, so they are drawn here from character
maps. Every foe sheet is two idle frames side by side, 18x28 each, facing
left toward the player, with the held prop near (3, 6) where the stage's
additive glow sits.

    python tools/paint_quest.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites"

PALETTE = {
    ".": (0, 0, 0, 0),
    "K": (24, 14, 26, 255),
    "s": (236, 188, 150, 255),
    "z": (196, 140, 110, 255),
    "w": (244, 240, 232, 255),
    "W": (188, 184, 198, 255),
    "m": (214, 218, 230, 255),
    "M": (146, 152, 172, 255),
    "n": (88, 92, 114, 255),
    "r": (200, 56, 56, 255),
    "R": (128, 32, 42, 255),
    "y": (248, 208, 92, 255),
    "Y": (190, 140, 52, 255),
    "g": (110, 186, 96, 255),
    "G": (54, 114, 68, 255),
    "b": (84, 116, 196, 255),
    "B": (44, 60, 122, 255),
    "o": (156, 100, 58, 255),
    "O": (100, 60, 40, 255),
    "p": (124, 84, 164, 255),
    "P": (70, 44, 104, 255),
    "c": (252, 216, 98, 255),
    "C": (214, 160, 62, 255),
    "f": (255, 168, 60, 255),
    "F": (255, 238, 150, 255),
    "k": (44, 40, 54, 255),
    "j": (76, 72, 88, 255),
    "t": (214, 174, 124, 255),
    "T": (160, 120, 82, 255),
    "h": (206, 206, 212, 255),
    "e": (232, 72, 72, 255),
    "X": (236, 250, 255, 255),
    "x": (150, 214, 240, 255),
    "q": (236, 150, 160, 255),
}

# The squire: a too-big bucket helm, a red tabard, and two coconut halves.
SQUIRE = [
    "................",
    "....KKKKKKK.....",
    "...KmmmmmmmK....",
    "...KmMMMMMmK....",
    "...KmKKKKKMK....",
    "...KmMMMMMMK....",
    "...KmMKMKMMK....",
    "...KmMMMMMMK....",
    "...KnnnnnnnK....",
    "....KKKKKKK.....",
    "...KrrryrrrK....",
    "..KsKrryyrrKsK..",
    ".KOoKrrryrrKoOK.",
    ".KooKrrrrrrKooK.",
    ".KOoKrrrrrrKoOK.",
    "..KKKyyyyyyKKK..",
    "....KrrrrrrK....",
    "....KrrRrrrK....",
    "....KKKKKKKK....",
    ".....KtK.KtK....",
    ".....KtK.KtK....",
    ".....KoK.KoK....",
    "....KOOK.KOOK...",
    "....KKKK.KKKK...",
]

# A fluffy white bunny with long ears and very sharp teeth, facing right.
BUNNY = [
    "......KK.KK.........",
    ".....KwqKwqK........",
    ".....KwqKwqK........",
    "......KwKwK.........",
    "..KKKKKwwwwKK.......",
    ".KwwwwwwwwwKeK......",
    "KwwwwwwwwwwwwwK.....",
    "KwwwwwwwwwwwwwKK....",
    "KWwwwwwwwwwwwwwqK...",
    ".KWwwwwwwwwwwKwKwK..",
    "..KWWwKWWwKWWKKKK...",
    "...KKK.KKK.KKK......",
]

# A tin of luncheon meat: blue label, a pink slab on it.
TIN = [
    "............",
    "...KKKKKK...",
    "..KmmmmmmK..",
    ".KMmmmmmmMK.",
    ".KbbbbbbbbK.",
    ".KbqqqqqqbK.",
    ".KbqwqqqqbK.",
    ".KbqqqqqqbK.",
    ".KbbbbbbbbK.",
    ".KMnnnnnnMK.",
    "..KKKKKKKK..",
    "............",
]

# A castle gate: stone posts, a raised portcullis, and a golden glow inside.
GATE = [
    "........KKKKKKKK........",
    "......KKWWWWWWWWKK......",
    ".....KWWMMMMMMMMWWK.....",
    "....KWMMKKKKKKKKMMWK....",
    "...KWMKKnKnKnKnKKKMWK...",
    "...KWMKnKnKnKnKnKKMWK...",
    "..KWMKKKKKKKKKKKKKKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFyFFFFFFFFyFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKyFFFFyyFFFFyKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFFFyFFFFyFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKyFFFFFFFFFFyKMWK..",
    "..KWMKFFFFFyyFFFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFyFFFFFFFFyFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKyFFFFFFFFFFyKMWK..",
    "..KWMKFFFFyFFyFFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKyFFFFFFFFFFyKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFFFyFFFFyFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKyFFFFFFFFFFyKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFFFFyFFyFFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    "..KWMKyFFFFFFFFFFyKMWK..",
    "..KWMKFFFFFFFFFFFFKMWK..",
    ".KWWMKFFFFFFFFFFFFKMWWK.",
    ".KWMMKFFFFFFFFFFFFKMMWK.",
    "KWWMMMKFFFFFFFFFFKMMMWWK",
    "KKKKKKKKKKKKKKKKKKKKKKKK",
]

# The Knight Who Says Mi: antlers on a great helm, a sprig of shrubbery on a stick.
KNIGHT_A = [
    ".....K.K...K.K....",
    ".....KTK...KTK....",
    "......KTK.KTK.....",
    ".......KTKTK......",
    ".KGGK.KmmmmmK.....",
    "KGgGGKKmMMMmK.....",
    "KGGgGKKMKKKMK.....",
    ".KGGK.KMMMMMK.....",
    "..KoK.KnMMMnK.....",
    "..KoK.KnnnnnK.....",
    "..KoKKkkkkkkkkK...",
    ".KssKKkkrrrkkkkK..",
    "..KoKKkkkrkkkkkK..",
    "..KoK.KkkrkkkkkK..",
    "..KoK.KkkkkkkkkK..",
    "..KoK.KkkkkkkkkK..",
    "..KoK.KyyyyyyyyK..",
    "..KoK.KkkkkkkkkK..",
    "..KoK.KkkkkkkkkkK.",
    "..KoK.KkkkkkkkkkK.",
    "..KoK.KkkkkkkkkkK.",
    "..KoK.KKKKKKKKKKK.",
    "..KoK..KMMK.KMMK..",
    "..KoK..KMMK.KMMK..",
    "..KoK..KMMK.KMMK..",
    "..KoK..KnnK.KnnK..",
    "..KoK.KnnnK.KnnnK.",
    "..KKK.KKKKK.KKKKK.",
]

# The Cheesemonger: a round shopkeeper in an apron, holding up a cheese wedge.
CHEESE_A = [
    "..................",
    "..................",
    "..................",
    "........KKKKK.....",
    ".......KsssssK....",
    "..KK..KssssssK....",
    ".KccK.KsKsKssK....",
    "KcCcCKKssssszK....",
    "KccccKKOOOOOsK....",
    ".KKKK.KsssssK.....",
    "..KsK..KsssK......",
    "..KsKKKwwwwwKK....",
    "..KsKbKwwwwwwbK...",
    "...KbbKwwwwwwbbK..",
    "....KbKwwwwwwwbK..",
    "....KbKwwwwwwwbK..",
    "....KKKwwwwwwwbK..",
    ".....KwwwwwwwwbK..",
    ".....KwwwwwwwwwK..",
    ".....KWwwwwwwwwK..",
    ".....KWwwwwwwwwK..",
    ".....KWWwwwwwwWK..",
    ".....KKKKKKKKKKK..",
    "......KjjK.KjjK...",
    "......KjjK.KjjK...",
    "......KkkK.KkkK...",
    ".....KkkkK.KkkkK..",
    ".....KKKKK.KKKKK..",
]

# Tom the Enchanter: curled horns, a dark robe, and a staff with a flame.
ENCHANTER_A = [
    "..KK..............",
    ".KFfK.............",
    ".KfFfK............",
    "KfFFfK..KKKKK.....",
    "KffFfK.KjjjjjK....",
    ".KfffKKjjjjjjjKK..",
    "..KOK.KTKjjjjKTTK.",
    "..KoK.KTTKKKKTKTK.",
    "..KoK..KKssssKKK..",
    "..KoK...KsKsKsK...",
    "..KoK...KsssssK...",
    "..KoK...KhhhhhK...",
    "..KsKKKkKhhhhKkK..",
    "..KsKkkkkKhhKkkkK.",
    "..KoKkkkkkKKkkkkK.",
    "..KoK.KkkkkkkkkkK.",
    "..KoK.KkkkkkkkkkK.",
    "..KoK.KkkjkkkkkkK.",
    "..KoK.KkkjkkkkkkK.",
    "..KoK.KkkjkkkkkkK.",
    "..KoK.KkkkjkkkkkK.",
    "..KoK.KkkkjkkkkkkK",
    "..KoK.KkkkjkkkkkkK",
    "..KoK.KkkkkjkkkkkK",
    "..KoK.KkkkkjkkkkkK",
    "..KoK.KkkkkkjkkkkK",
    "..KoK.KkkkkkkkkkkK",
    "..KKK.KKKKKKKKKKKK",
]

# The Under-Minister: bowler hat, black suit, an umbrella, mid silly walk.
MINISTER_A = [
    "..................",
    "........KKKKK.....",
    ".......KkkkkkK....",
    ".......KkkkkkK....",
    "......KKKKKKKKK...",
    "..KKK..KssssK.....",
    ".KbbbK.KsKsssK....",
    "KbbbbbKKssssK.....",
    "KKKoKKK.KsszK.....",
    "...oK...KKwKK.....",
    "...oK..KkkwrkkK...",
    "...oK.KkkkwrkkkK..",
    "...oKKkkkkwrkkkK..",
    "...KssKkkkwkkkkK..",
    "....KKKkkkkkkkkK..",
    "......KkkkkkkkkK..",
    "......KkkkkkkkkK..",
    "......KkkkkkkkkK..",
    "......KjjjKjjjjK..",
    "......KjjjKKjjjjKK",
    "......KjjjK.KjjjjK",
    "......KjjjK..KjjjK",
    "......KjjjK...KKKK",
    "......KjjjK.......",
    "......KjjjK.......",
    "......KkkkK.......",
    ".....KkkkkK.......",
    ".....KKKKKK.......",
]

# The Bridgekeeper: a ragged hood, a long grey beard, a crooked staff.
KEEPER_A = [
    "..................",
    "..................",
    "..KK....KKKKK.....",
    ".KXxK..KOOOOOK....",
    ".KxXK.KOOooooOK...",
    "..KOK.KOKKKKoOK...",
    "..KoK.KOKsKsKoOK..",
    "..KoK.KOKssssKOK..",
    "..KoK.KOKhhhhKOK..",
    "..KoK.KOKhhhhhKOK.",
    "..KoK.KOKhhhhhKOK.",
    "..KsKKOOOKhhhKOOK.",
    "..KsKoOOoKhhhKoOK.",
    "..KoKoooooKhKooOK.",
    "..KoK.KooooKKoooK.",
    "..KoK.KooooooooOK.",
    "..KoK.KoOoooooOoK.",
    "..KoK.KooooOoooOK.",
    "..KoK.KoOooooooOK.",
    "..KoK.KooooooOooK.",
    "..KoK.KooOoooooOK.",
    "..KoK.KoooooOoooK.",
    "..KoK.KoOoooooOoK.",
    "..KoK.KooooOooooK.",
    "..KoK.KoOoooooOoK.",
    "..KoK.KoKoKoKoKoK.",
    "..KoK..K.K.K.K.K..",
    "..KKK.............",
]

# The Taunting Knight: a pot helm, a blue tabard with a gold lily, a pennant.
TAUNTER_A = [
    "KKKKKK............",
    "KyyyyyK...........",
    "KybbbyyK..........",
    "KyyyyyyyK.........",
    "KKKKKKKKKKKKKK....",
    "..KoK..KmmmmmmK...",
    "..KoK..KmMMMMmK...",
    "..KoK..KMKKKKMK...",
    "..KoK..KMMMMMMK...",
    "..KoK..KMMKMMMK...",
    "..KoK..KnnnnnnK...",
    "..KoKKKbbbbbbbbKK.",
    ".KssKbbbbbybbbbbK.",
    "..KoKbbbbyyybbbbK.",
    "..KoK.KbbbybbbbbK.",
    "..KoK.KbbybybbbbK.",
    "..KoK.KbbbbbbbbbK.",
    "..KoK.KYYYYYYYYYK.",
    "..KoK.KbbbbbbbbbK.",
    "..KoK.KbbbbbbbbbbK",
    "..KoK.KbbbbbbbbbbK",
    "..KoK.KKKKKKKKKKKK",
    "..KoK..KMMK.KMMK..",
    "..KoK..KMMK.KMMK..",
    "..KoK..KMMK.KMMK..",
    "..KoK..KnnK.KnnK..",
    "..KoK.KnnnK.KnnnK.",
    "..KKK.KKKKK.KKKKK.",
]

# A neatly trimmed shrubbery, for Shrubbery Wood.
SHRUB = [
    "....KKKKKKK.....",
    "..KKgggGgggKK...",
    ".KggggGggGgggK..",
    "KgggGgggggGgggK.",
    "KggGgggGgggggGK.",
    "KgGgggggggGgggK.",
    "KggggGgggggGggK.",
    ".KgggggGgggggK..",
    "..KKGgggggGKK...",
    "....KKKKKKKK....",
    ".....KoooK......",
    ".....KoOoK......",
    "....KKKKKKK.....",
    "...KTTTTTTTK....",
]

# The Grail: a golden cup with a gem, floating over the last gate.
GRAIL = [
    "............",
    ".KKKKKKKKKK.",
    ".KyFFFFFFyK.",
    ".KyyyyyyyyK.",
    ".KyyyeyyyYK.",
    "..KyyyyyYK..",
    "...KyyyYK...",
    "....KyYK....",
    "....KyYK....",
    "....KyYK....",
    "...KyyyYK...",
    "..KyyyyyYK..",
    "..KKKKKKKK..",
    "............",
]


def swap_rows(frame: list[str], rows: range, pairs: dict[str, str]) -> list[str]:
    """A copy of `frame` with `pairs` swapped on `rows`, for the second idle frame."""
    out = list(frame)
    for y in rows:
        out[y] = "".join(pairs.get(ch, ch) for ch in out[y])
    return out


def shift_rows(frame: list[str], rows: range, by: int) -> list[str]:
    """A copy with `rows` nudged sideways by `by` pixels, padding with clear."""
    out = list(frame)
    for y in rows:
        row = out[y]
        out[y] = ("." * by + row[: len(row) - by]) if by > 0 else (row[-by:] + "." * -by)
    return out


# Second frames: something sways in each.
KNIGHT_B = swap_rows(KNIGHT_A, range(4, 8), {"g": "G", "G": "g"})
CHEESE_B = shift_rows(CHEESE_A, range(5, 9), 0)
CHEESE_B = swap_rows(CHEESE_B, range(19, 22), {"W": "w", "w": "W"})
ENCHANTER_B = swap_rows(ENCHANTER_A, range(0, 6), {"f": "F", "F": "f"})
MINISTER_B = [
    *MINISTER_A[:18],
    "......KjjjKjjjjK..",
    "......KjjjKKjjjK..",
    "......KjjjK.KjjjK.",
    "......KjjjK.KjjjK.",
    "......KjjjK.KjjjK.",
    "......KjjjK.KjjjK.",
    "......KjjjK.KjjjK.",
    "......KkkkK.KkkkK.",
    ".....KkkkkKKkkkkK.",
    ".....KKKKKKKKKKKK.",
]
KEEPER_B = swap_rows(KEEPER_A, range(3, 5), {"X": "x", "x": "X"})
KEEPER_B = swap_rows(KEEPER_B, range(25, 27), {"o": "O"})
TAUNTER_B = shift_rows(TAUNTER_A, range(1, 4), 1)

FOES = {
    1: (KNIGHT_A, KNIGHT_B),
    2: (CHEESE_A, CHEESE_B),
    3: (ENCHANTER_A, ENCHANTER_B),
    4: (MINISTER_A, MINISTER_B),
    5: (KEEPER_A, KEEPER_B),
    6: (TAUNTER_A, TAUNTER_B),
}


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


def sheet(frames: list[list[str]]) -> Image.Image:
    painted = [paint(frame) for frame in frames]
    width, height = painted[0].size
    out = Image.new("RGBA", (width * len(painted), height), PALETTE["."])
    for index, frame in enumerate(painted):
        out.paste(frame, (index * width, 0))
    return out


def outlined(image: Image.Image) -> Image.Image:
    """Inks every opaque pixel that touches a clear one, like a cut-out's edge."""
    out = image.copy()
    width, height = image.size
    ink = PALETTE["K"]
    for y in range(height):
        for x in range(width):
            if image.getpixel((x, y))[3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or image.getpixel((nx, ny))[3] == 0:
                    out.putpixel((x, y), ink)
                    break
    return out


def giant_foot() -> Image.Image:
    """A bare leg and foot that comes down from the sky when a stage is cleared:
    a nod to the show's cut-out animation. Toes point left, the heel right."""
    width, height = 72, 96
    image = Image.new("RGBA", (width, height), PALETTE["."])
    draw = ImageDraw.Draw(image)
    skin, shade, deep = PALETTE["s"], PALETTE["z"], (164, 108, 86, 255)
    # The shin, from the top edge down to the ankle.
    draw.rectangle((32, 0, 60, 62), fill=skin)
    draw.rectangle((52, 0, 60, 62), fill=shade)
    # The foot in profile: the instep slopes from the ankle down to the toes.
    draw.polygon([(32, 54), (60, 54), (68, 70), (68, 91), (6, 91), (2, 86), (6, 80), (16, 74)], fill=skin)
    draw.polygon([(58, 60), (68, 70), (68, 91), (54, 91)], fill=shade)
    # Five toes along the front edge, biggest at the tip.
    for x, y, r in ((7, 84, 6), (14, 77, 4), (19, 74, 3), (24, 72, 3), (28, 70, 2)):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=skin)
    for x, y in ((4, 82), (13, 75), (18, 72), (23, 70)):
        draw.point((x, y), fill=PALETTE["w"])
    # The sole's shadow, an ankle bone and a knee crease.
    draw.line((8, 90, 66, 90), fill=deep)
    draw.ellipse((44, 52, 52, 60), fill=shade)
    draw.line((34, 30, 44, 30), fill=shade)
    return outlined(image)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = {
        "squire": sheet([SQUIRE]),
        "bunny": sheet([BUNNY]),
        "tin": sheet([TIN]),
        "castle_gate": sheet([GATE]),
        "shrub": sheet([SHRUB]),
        "grail": sheet([GRAIL]),
        "giant_foot": giant_foot(),
    }
    for stage, frames in FOES.items():
        jobs[f"foe_{stage}"] = sheet(list(frames))
    for name, image in jobs.items():
        image.save(OUT / f"{name}.png")
        print(f"wrote {name}.png {image.size}")


if __name__ == "__main__":
    main()
