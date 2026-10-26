"""Paint the cast, pixel by pixel: a sprite sheet and a close-up face for each.

Faces this small lose everything when an image model is squeezed down to
them, so they're drawn here from shapes. Every sheet is six 24x48 frames
facing right: idle, two walk frames, talk (a hand out), squint (arms folded,
eyes narrowed) and yell (arms up). Every face sheet is four 48x48 close-ups:
neutral, talk, squint, yell.

Everyone is an archetype with an invented name; nobody is drawn to look like
a real person.

    python tools/paint.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"

INK = (24, 20, 28, 255)
WHITE = (240, 236, 228, 255)
MOUTH = (110, 40, 44, 255)
TONGUE = (200, 90, 90, 255)

LIGHT = (240, 198, 164, 255)
TAN = (214, 166, 124, 255)
OLIVE = (200, 150, 110, 255)
BROWN = (120, 78, 52, 255)


def shade(c, k=0.75):
    return (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)


CAST = {
    # The hero: tall and thin, bald on top with a fringe, big glasses, a navy half-zip.
    "barry": dict(skin=LIGHT, hair=(170, 166, 160, 255), style="fringe", glasses=True, beard=None,
                  top=(52, 62, 104, 255), collar=(214, 220, 232, 255), top_style="halfzip",
                  legs=(186, 170, 140, 255), shoes=(90, 62, 44, 255), tall=True, wide=False),
    # The manager: stocky, dark hair going thin, a short grey-black beard, an untucked dark shirt.
    "gil": dict(skin=LIGHT, hair=(58, 50, 46, 255), style="thin", glasses=True, beard=(80, 74, 72, 255),
                top=(44, 46, 54, 255), collar=(44, 46, 54, 255), top_style="shirt",
                legs=(54, 60, 80, 255), shoes=(30, 28, 30, 255), tall=False, wide=True),
    # The manager's wife: a mountain of auburn curls, gold earrings, a loud magenta top.
    "sharon": dict(skin=LIGHT, hair=(150, 62, 40, 255), style="curls", glasses=False, beard=None,
                   top=(186, 44, 112, 255), collar=(230, 190, 60, 255), top_style="blouse",
                   legs=(30, 30, 38, 255), shoes=(160, 30, 40, 255), tall=False, wide=False, lips=True),
    # The ex-wife: a neat blonde bob, a soft blue blouse.
    "carol": dict(skin=LIGHT, hair=(226, 196, 120, 255), style="bob", glasses=False, beard=None,
                  top=(120, 160, 210, 255), collar=(236, 236, 240, 255), top_style="blouse",
                  legs=(220, 214, 200, 255), shoes=(180, 140, 110, 255), tall=False, wide=False, lips=True),
    # The houseguest: tall, short hair and a beard, an orange track jacket, a gold chain.
    "lamont": dict(skin=BROWN, hair=(26, 22, 22, 255), style="short", glasses=False, beard=(30, 24, 24, 255),
                   top=(232, 118, 40, 255), collar=(240, 240, 240, 255), top_style="track",
                   legs=(40, 40, 50, 255), shoes=(240, 240, 240, 255), tall=True, wide=False, chain=True),
    # The neighbor: a ball cap, a green polo, very white sneakers.
    "ted": dict(skin=TAN, hair=(110, 80, 50, 255), style="cap", cap=(40, 70, 140, 255), glasses=False, beard=None,
                top=(70, 140, 90, 255), collar=(70, 140, 90, 255), top_style="polo",
                legs=(200, 180, 140, 255), shoes=(244, 244, 244, 255), tall=False, wide=False),
    # The deli man: white hair round the sides, a white moustache, an apron.
    "sol": dict(skin=LIGHT, hair=(236, 236, 236, 255), style="fringe", glasses=False, beard=None, tache=(236, 236, 236, 255),
                top=(150, 60, 50, 255), collar=(150, 60, 50, 255), top_style="apron",
                legs=(60, 60, 70, 255), shoes=(30, 28, 30, 255), tall=False, wide=True),
    # The club manager: silver side parting, a navy blazer and a club tie.
    "whit": dict(skin=TAN, hair=(196, 196, 204, 255), style="parted", glasses=False, beard=None,
                 top=(30, 44, 86, 255), collar=(236, 236, 240, 255), top_style="blazer", tie=(150, 30, 40, 255),
                 legs=(200, 196, 180, 255), shoes=(90, 50, 30, 255), tall=True, wide=False),
    # The maitre d': slicked black hair, a pencil moustache, a dinner jacket.
    "philippe": dict(skin=OLIVE, hair=(20, 18, 20, 255), style="slick", glasses=False, beard=None, tache=(20, 18, 20, 255),
                     top=(24, 24, 30, 255), collar=(240, 240, 240, 255), top_style="tux",
                     legs=(24, 24, 30, 255), shoes=(10, 10, 12, 255), tall=True, wide=False),
    # The returns clerk: a brown ponytail, a red store vest, a lanyard.
    "dana": dict(skin=TAN, hair=(100, 64, 40, 255), style="ponytail", glasses=True, beard=None,
                 top=(190, 40, 44, 255), collar=(236, 236, 240, 255), top_style="vest",
                 legs=(50, 54, 70, 255), shoes=(30, 28, 30, 255), tall=False, wide=False, lips=True),
    # The barista: a beanie, a beard, a canvas apron.
    "rain": dict(skin=LIGHT, hair=(130, 90, 50, 255), style="beanie", cap=(90, 110, 80, 255), glasses=False, beard=(130, 90, 50, 255),
                 top=(70, 70, 76, 255), collar=(70, 70, 76, 255), top_style="apron2",
                 legs=(60, 70, 90, 255), shoes=(120, 80, 50, 255), tall=False, wide=False),
}


def rect(d, x0, y0, x1, y1, c):
    if c is not None:
        d.rectangle((x0, y0, x1, y1), fill=c)


# --- The full figure ---------------------------------------------------------

def figure(s: dict, pose: int) -> Image.Image:
    """pose: 0 idle, 1 walk A, 2 walk B, 3 talk, 4 squint, 5 yell."""
    img = Image.new("RGBA", (24, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = 2 if s["tall"] else 5
    wide = 1 if s["wide"] else 0
    skin, top_c = s["skin"], s["top"]
    # Legs and shoes.
    if pose == 1:
        legs = [(7, 9), (14, 16)]
    elif pose == 2:
        legs = [(10, 12), (11, 13)]
    else:
        legs = [(8, 10), (13, 15)]
    for i, (x0, x1) in enumerate(legs):
        rect(d, x0, 31, x1, 44, shade(s["legs"], 0.82) if i == 0 else s["legs"])
        rect(d, x0, 45, x1 + 1, 47, s["shoes"])
    # Torso.
    t0 = top + 13
    rect(d, 6 - wide, t0, 17 + wide, 31, top_c)
    rect(d, 6 - wide, t0, 7 - wide, 31, shade(top_c))
    style = s["top_style"]
    collar = s["collar"]
    if style == "halfzip":
        rect(d, 10, t0, 13, t0 + 1, collar)
        rect(d, 11, t0 + 2, 12, t0 + 5, shade(top_c, 0.6))
    elif style == "shirt":
        rect(d, 10, t0, 13, t0 + 1, shade(top_c, 1.4))
    elif style == "blouse":
        rect(d, 9, t0, 14, t0 + 1, skin)
        if s.get("lips"):
            rect(d, 11, t0 + 1, 12, t0 + 1, collar)
    elif style == "track":
        rect(d, 11, t0, 12, 31, collar)
        rect(d, 6, t0, 6, 31, collar)
        rect(d, 17, t0, 17, 31, collar)
    elif style == "polo":
        rect(d, 9, t0, 14, t0 + 1, shade(top_c, 1.25))
        rect(d, 11, t0 + 2, 12, t0 + 3, shade(top_c, 0.7))
    elif style in ("apron", "apron2"):
        apron = WHITE if style == "apron" else (176, 150, 110, 255)
        rect(d, 8, t0 + 3, 15, 33, apron)
        rect(d, 9, t0, 14, t0 + 2, shade(top_c, 1.2))
    elif style in ("blazer", "tux"):
        rect(d, 10, t0, 13, t0 + 7, collar)
        tie = (20, 20, 24, 255) if style == "tux" else s.get("tie")
        if style == "tux":
            rect(d, 10, t0 + 1, 13, t0 + 1, tie)
        else:
            rect(d, 11, t0 + 1, 12, t0 + 7, tie)
    elif style == "vest":
        rect(d, 10, t0, 13, 31, collar)
        rect(d, 11, t0, 12, t0 + 9, (60, 90, 200, 255))
    if s.get("chain"):
        rect(d, 9, t0 + 3, 14, t0 + 3, (240, 200, 60, 255))
    # Arms.
    sleeve = shade(top_c, 0.9)
    if pose == 3:  # a hand out, making a point
        rect(d, 5 - wide, t0 + 1, 6 - wide, t0 + 11, sleeve)
        rect(d, 5 - wide, t0 + 12, 6 - wide, t0 + 13, skin)
        rect(d, 17 + wide, t0 + 3, 21, t0 + 5, sleeve)
        rect(d, 22, t0 + 2, 23, t0 + 5, skin)
    elif pose == 4:  # arms folded
        rect(d, 5 - wide, t0 + 1, 6 - wide, t0 + 7, sleeve)
        rect(d, 17 + wide, t0 + 1, 18 + wide, t0 + 7, sleeve)
        rect(d, 6 - wide, t0 + 6, 17 + wide, t0 + 9, shade(top_c, 0.8))
        rect(d, 6 - wide, t0 + 7, 7 - wide, t0 + 8, skin)
        rect(d, 16 + wide, t0 + 7, 17 + wide, t0 + 8, skin)
    elif pose == 5:  # arms up
        rect(d, 3 - wide, t0 - 7, 5 - wide, t0 + 2, sleeve)
        rect(d, 18 + wide, t0 - 7, 20 + wide, t0 + 2, sleeve)
        rect(d, 3 - wide, t0 - 9, 5 - wide, t0 - 8, skin)
        rect(d, 18 + wide, t0 - 9, 20 + wide, t0 - 8, skin)
    else:
        swing = 1 if pose == 1 else (-1 if pose == 2 else 0)
        rect(d, 5 - wide, t0 + 1, 6 - wide, t0 + 11, sleeve)
        rect(d, 5 - wide, t0 + 12 + max(swing, 0), 6 - wide, t0 + 13 + max(swing, 0), skin)
        rect(d, 17 + wide, t0 + 1, 18 + wide, t0 + 11, sleeve)
        rect(d, 17 + wide, t0 + 12 + max(-swing, 0), 18 + wide, t0 + 13 + max(-swing, 0), skin)
    # Head.
    head(d, s, 7, top, pose)
    return img


def head(d, s, x, y, pose):
    skin, hair = s["skin"], s["hair"]
    style = s["style"]
    if style == "curls":
        rect(d, x - 3, y - 3, x + 12, y + 12, hair)
        for (px, py) in [(x - 3, y - 3), (x + 12, y - 3), (x - 2, y + 12), (x + 11, y + 12), (x + 4, y - 3)]:
            d.point((px, py), fill=shade(hair, 0.7))
    if style == "ponytail":
        rect(d, x - 3, y + 2, x - 1, y + 9, hair)
    rect(d, x, y, x + 9, y + 11, skin)
    rect(d, x + 9, y + 5, x + 10, y + 7, skin)  # nose, facing right
    rect(d, x, y, x, y + 11, shade(skin, 0.88))
    # Hair.
    if style == "fringe":
        rect(d, x, y + 3, x + 1, y + 8, hair)
        rect(d, x + 2, y + 3, x + 2, y + 5, hair)
        d.point((x + 7, y + 3), fill=hair)
    elif style == "thin":
        rect(d, x, y, x + 8, y + 1, shade(hair, 1.1))
        rect(d, x, y + 2, x + 1, y + 7, hair)
        d.point((x + 4, y), fill=skin)
    elif style == "curls":
        rect(d, x, y, x + 9, y + 1, hair)
        rect(d, x, y + 2, x + 1, y + 11, hair)
    elif style == "bob":
        rect(d, x - 1, y - 1, x + 9, y + 2, hair)
        rect(d, x - 1, y + 3, x + 2, y + 10, hair)
        rect(d, x + 9, y + 2, x + 9, y + 4, hair)
    elif style == "short":
        rect(d, x, y, x + 9, y + 2, hair)
        rect(d, x, y + 3, x + 1, y + 5, hair)
    elif style == "cap":
        rect(d, x - 1, y - 1, x + 9, y + 2, s["cap"])
        rect(d, x + 8, y + 2, x + 12, y + 3, shade(s["cap"], 0.8))
        rect(d, x, y + 3, x + 1, y + 6, hair)
    elif style == "parted":
        rect(d, x, y, x + 9, y + 2, hair)
        rect(d, x, y + 3, x + 1, y + 6, hair)
        d.point((x + 6, y + 1), fill=shade(hair, 0.7))
    elif style == "slick":
        rect(d, x, y - 1, x + 9, y + 2, hair)
        rect(d, x, y + 3, x + 2, y + 6, hair)
        rect(d, x + 3, y, x + 9, y, shade(hair, 1.6))
    elif style == "ponytail":
        rect(d, x, y, x + 9, y + 2, hair)
        rect(d, x, y + 3, x + 1, y + 7, hair)
    elif style == "beanie":
        rect(d, x - 1, y - 2, x + 9, y + 2, s["cap"])
        rect(d, x - 1, y + 2, x + 9, y + 2, shade(s["cap"], 0.75))
        rect(d, x, y + 3, x + 1, y + 6, hair)
    if s.get("beard"):
        rect(d, x + 3, y + 8, x + 9, y + 11, s["beard"])
        rect(d, x + 1, y + 6, x + 2, y + 10, s["beard"])
    # Eyes (facing right, so both sit toward the right of the head).
    ex1, ex2, ey = x + 4, x + 7, y + 5
    if pose == 4:
        rect(d, ex1 - 1, ey, ex1, ey, INK)
        rect(d, ex2, ey, ex2 + 1, ey, INK)
        rect(d, ex1 - 1, ey - 2, ex1 + 1, ey - 2, shade(s["hair"], 0.6) if style != "fringe" else INK)
        rect(d, ex2 - 1, ey - 1, ex2 + 1, ey - 1, INK)
    else:
        d.point((ex1, ey), fill=INK)
        d.point((ex2, ey), fill=INK)
        if pose == 5:
            d.point((ex1 - 1, ey - 2), fill=INK)
            d.point((ex2 + 1, ey - 2), fill=INK)
    if s["glasses"]:
        # Frames: a bar across the top and the outer rims, so the eyes still read.
        rect(d, ex1 - 1, ey - 1, ex2 + 1, ey - 1, INK)
        d.point((ex1 - 1, ey), fill=INK)
        d.point((ex2 + 1, ey), fill=INK)
        d.point((ex1 - 1, ey + 1), fill=INK)
        d.point((ex2 + 1, ey + 1), fill=INK)
    if s.get("tache"):
        rect(d, x + 5, y + 8, x + 9, y + 8, s["tache"])
    # Mouth.
    my = y + 9
    if pose == 3:
        rect(d, x + 6, my, x + 8, my + 1, MOUTH)
    elif pose == 5:
        rect(d, x + 5, my - 1, x + 8, my + 1, MOUTH)
        d.point((x + 6, my + 1), fill=TONGUE)
    elif pose == 4:
        rect(d, x + 6, my, x + 8, my, shade(skin, 0.6))
    else:
        rect(d, x + 6, my, x + 8, my, shade(skin, 0.65) if not s.get("lips") else (180, 50, 60, 255))
    if s.get("lips") and pose == 3:
        rect(d, x + 6, my, x + 8, my + 1, (160, 40, 50, 255))
    if style == "curls" or s.get("lips"):
        d.point((x + 1, y + 8), fill=(240, 200, 60, 255))


# --- The close-up ------------------------------------------------------------

def face(s: dict, pose: int) -> Image.Image:
    """pose: 0 neutral, 1 talk, 2 squint, 3 yell. 48x48, facing the viewer."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin, hair, top = s["skin"], s["hair"], s["top"]
    style = s["style"]
    # Backdrop.
    rect(d, 0, 0, 47, 47, (52, 46, 58, 255))
    # Shoulders.
    rect(d, 6, 38, 41, 47, top)
    rect(d, 20, 36, 27, 40, skin)
    st = s["top_style"]
    if st in ("blazer", "tux"):
        rect(d, 19, 38, 28, 47, s["collar"])
        rect(d, 22, 38, 25, 47, s.get("tie") or (20, 20, 24, 255)) if st == "blazer" else rect(d, 21, 39, 26, 40, (20, 20, 24, 255))
    elif st == "halfzip":
        rect(d, 18, 37, 29, 39, s["collar"])
        rect(d, 23, 40, 24, 47, shade(top, 0.6))
    elif st == "track":
        rect(d, 23, 38, 24, 47, s["collar"])
    elif st in ("apron", "apron2"):
        rect(d, 14, 41, 33, 47, WHITE if st == "apron" else (176, 150, 110, 255))
    elif st == "vest":
        rect(d, 18, 38, 29, 47, s["collar"])
    if s.get("chain"):
        rect(d, 18, 40, 29, 40, (240, 200, 60, 255))
    # Hair behind.
    if style == "curls":
        d.ellipse((3, 0, 44, 42), fill=hair)
        for (px, py) in [(8, 6), (38, 8), (6, 24), (40, 26), (14, 2), (30, 1), (10, 36), (36, 36)]:
            d.ellipse((px - 2, py - 2, px + 2, py + 2), fill=shade(hair, 0.75))
    elif style == "bob":
        rect(d, 10, 4, 37, 34, hair)
    elif style == "ponytail":
        rect(d, 36, 12, 41, 30, hair)
    # Head.
    d.ellipse((12, 5, 35, 37), fill=skin)
    # Hair on top.
    if style == "fringe":
        rect(d, 11, 15, 14, 26, hair)
        rect(d, 33, 15, 36, 26, hair)
        d.point((22, 7), fill=shade(skin, 0.9))
    elif style == "thin":
        d.chord((13, 4, 34, 18), 180, 360, fill=hair)
        rect(d, 11, 13, 14, 24, hair)
        rect(d, 33, 13, 36, 24, hair)
        rect(d, 20, 6, 27, 9, skin)
    elif style == "curls":
        d.chord((10, 1, 37, 20), 180, 360, fill=hair)
    elif style == "bob":
        d.chord((10, 1, 37, 22), 180, 360, fill=hair)
        rect(d, 11, 10, 18, 14, hair)
    elif style == "short":
        d.chord((12, 3, 35, 17), 180, 360, fill=hair)
    elif style == "cap":
        d.chord((10, 1, 37, 19), 180, 360, fill=s["cap"])
        rect(d, 10, 10, 41, 13, shade(s["cap"], 0.8))
    elif style == "parted":
        d.chord((12, 3, 35, 18), 180, 360, fill=hair)
        rect(d, 18, 5, 18, 10, shade(hair, 0.7))
    elif style == "slick":
        d.chord((12, 2, 35, 18), 180, 360, fill=hair)
        rect(d, 16, 5, 30, 6, shade(hair, 1.8))
    elif style == "ponytail":
        d.chord((12, 3, 35, 18), 180, 360, fill=hair)
    elif style == "beanie":
        d.chord((10, -2, 37, 20), 180, 360, fill=s["cap"])
        rect(d, 11, 9, 36, 12, shade(s["cap"], 0.75))
    if s.get("beard"):
        d.chord((12, 14, 35, 39), 0, 180, fill=s["beard"])
        rect(d, 13, 22, 15, 30, s["beard"])
        rect(d, 32, 22, 34, 30, s["beard"])
    # Ears.
    rect(d, 10, 19, 12, 24, shade(skin, 0.9))
    rect(d, 35, 19, 37, 24, shade(skin, 0.9))
    if style == "curls" or s.get("lips"):
        rect(d, 10, 25, 11, 27, (240, 200, 60, 255))
        rect(d, 36, 25, 37, 27, (240, 200, 60, 255))
    # Eyes and brows.
    lx, rx, ey = 18, 27, 20
    brow = shade(hair, 0.7) if style not in ("fringe", "thin") else shade(hair, 0.6)
    if style == "fringe" and hair[0] > 200:
        brow = (200, 200, 200, 255)
    if pose == 2:
        # The squint: lids down to a slit, brows low and pulled in.
        rect(d, lx - 1, ey, lx + 3, ey, INK)
        rect(d, rx - 1, ey, rx + 3, ey, INK)
        rect(d, lx - 1, ey - 1, lx + 3, ey - 1, shade(skin, 0.8))
        rect(d, rx - 1, ey - 1, rx + 3, ey - 1, shade(skin, 0.8))
        d.line((lx - 2, ey - 4, lx + 4, ey - 2), fill=brow, width=2)
        d.line((rx - 1, ey - 2, rx + 5, ey - 4), fill=brow, width=2)
    else:
        rect(d, lx, ey - 1, lx + 2, ey + 1, WHITE)
        rect(d, rx, ey - 1, rx + 2, ey + 1, WHITE)
        rect(d, lx + 1, ey - 1, lx + 2, ey + 1, INK)
        rect(d, rx + 1, ey - 1, rx + 2, ey + 1, INK)
        if pose == 3:
            d.line((lx - 2, ey - 5, lx + 4, ey - 3), fill=brow, width=2)
            d.line((rx - 1, ey - 3, rx + 5, ey - 5), fill=brow, width=2)
        else:
            rect(d, lx - 1, ey - 4, lx + 3, ey - 4, brow)
            rect(d, rx - 1, ey - 4, rx + 3, ey - 4, brow)
    if s["glasses"]:
        d.rectangle((lx - 3, ey - 3, lx + 4, ey + 3), outline=INK)
        d.rectangle((rx - 2, ey - 3, rx + 5, ey + 3), outline=INK)
        rect(d, lx + 5, ey - 1, rx - 3, ey - 1, INK)
        if pose == 2:
            # Behind glasses the squint has to read through the frames: heavy
            # lids inside the lenses and brows pulled down over the rims,
            # one lower than the other.
            rect(d, lx - 2, ey - 2, lx + 3, ey - 1, shade(skin, 0.8))
            rect(d, rx - 1, ey - 2, rx + 4, ey - 1, shade(skin, 0.8))
            rect(d, lx - 2, ey, lx + 3, ey, INK)
            rect(d, rx - 1, ey, rx + 4, ey, INK)
            dark = shade(hair, 0.55)
            d.line((lx - 3, ey - 7, lx + 4, ey - 5), fill=dark, width=2)
            d.line((rx - 2, ey - 5, rx + 5, ey - 7), fill=dark, width=2)
    # Nose.
    rect(d, 23, 22, 24, 27, shade(skin, 0.82))
    if s.get("tache"):
        rect(d, 18, 28, 29, 29, s["tache"])
    # Mouth.
    lips = (176, 48, 60, 255) if s.get("lips") else shade(skin, 0.6)
    if pose == 1:
        rect(d, 20, 30, 27, 32, MOUTH)
        rect(d, 20, 30, 27, 30, lips)
    elif pose == 3:
        d.ellipse((18, 29, 29, 36), fill=MOUTH)
        rect(d, 21, 34, 26, 35, TONGUE)
    elif pose == 2:
        rect(d, 20, 31, 27, 31, shade(skin, 0.55))
        d.point((27, 30), fill=shade(skin, 0.55))
    else:
        rect(d, 20, 31, 27, 31, lips)
    return img


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    for who, spec in CAST.items():
        sheet = Image.new("RGBA", (24 * 6, 48), (0, 0, 0, 0))
        for pose in range(6):
            sheet.paste(figure(spec, pose), (24 * pose, 0))
        sheet.save(SPRITES / f"{who}.png")
        faces = Image.new("RGBA", (48 * 4, 48), (0, 0, 0, 0))
        for pose in range(4):
            faces.paste(face(spec, pose), (48 * pose, 0))
        faces.save(SPRITES / f"{who}_face.png")
        print("painted", who)


if __name__ == "__main__":
    main()
