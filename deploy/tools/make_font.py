"""Rasterize Pixelify Sans into the bitmap font the Worker draws certificates with.

The Worker has no font renderer, so the glyphs are drawn here once, at the
size where Pixelify Sans lands exactly on its pixel grid, and written to
deploy/src/font.ts as bits. Run it again only to add characters:

    mise exec -- python deploy/tools/make_font.py
"""

import base64
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "games" / "dunder-quest" / "assets" / "fonts" / "PixelifySans.ttf"
OUT = ROOT / "deploy" / "src" / "font.ts"
SIZE = 12  # 1px strokes, an 8px cap height

CHARS = [chr(c) for c in range(32, 127)] + [chr(c) for c in range(0xA1, 0x100)]
CHARS += list("\u2018\u2019\u201c\u201d\u2013\u2014\u2022\u2026\u2605\u2713\u20ac")


def render(font: ImageFont.FreeTypeFont, ch: str, height: int) -> bytes:
    img = Image.new("L", (40, height), 0)
    draw = ImageDraw.Draw(img)
    draw.fontmode = "1"
    draw.text((2, 0), ch, font=font, fill=255)
    return img.tobytes()


def main() -> None:
    font = ImageFont.truetype(str(FONT), SIZE)
    ascent, descent = font.getmetrics()
    height = ascent + descent
    glyphs = {}
    missing = render(font, "", height)  # the font has no private-use glyphs: this is its .notdef box
    for ch in CHARS:
        if ch != " " and render(font, ch, height) == missing:
            continue
        advance = round(font.getlength(ch))
        img = Image.new("L", (advance + 8, height), 0)
        draw = ImageDraw.Draw(img)
        draw.fontmode = "1"
        draw.text((2, 0), ch, font=font, fill=255)
        box = img.getbbox()
        if box is None:
            glyphs[ch] = [advance, 0, 0, ""]
            continue
        x0, x1 = box[0], box[2]
        width = x1 - x0
        bits = "".join("1" if img.getpixel((x, y)) > 127 else "0" for y in range(height) for x in range(x0, x1))
        bits += "0" * (-len(bits) % 8)
        packed = bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))
        glyphs[ch] = [advance, x0 - 2, width, base64.b64encode(packed).decode()]
    body = json.dumps(glyphs, ensure_ascii=True, separators=(",", ":"))
    OUT.write_text(
        "// Pixelify Sans (SIL Open Font License) at %dpx, drawn by deploy/tools/make_font.py.\n"
        "// Each glyph: [advance, x offset, width, rows of bits as base64]. Don't edit by hand.\n\n"
        "export const FONT_HEIGHT = %d;\nexport const FONT_ASCENT = %d;\n"
        "export const GLYPHS: Record<string, [number, number, number, string]> = %s;\n" % (SIZE, height, ascent, body),
        encoding="utf-8",
    )
    print(f"{len(glyphs)} glyphs, {height}px tall, into {OUT}")


if __name__ == "__main__":
    main()
