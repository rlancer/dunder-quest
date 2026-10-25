"""Paint the @dunderquest YouTube channel art: the profile picture, the
banner and the video watermark. Writes into `site/static/img/youtube/`, where
the brand kit's YouTube page links them; rerun it when the logo or the title
art changes.

    python tools/make_channel.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from make_og import (ASH, EMBER, GOLD, LABEL, NIGHT, PARCHMENT, PIXEL, Q_PIXELS, ROOT, SITE, font, logo,
                     shadowed, upscale)

OUT = SITE / "static" / "img" / "youtube"
## YouTube's banner: 2560x1440 is shown whole on TVs, cropped to a 2560-wide
## strip on desktop and to the middle 1546x423 on phones. Anything that has
## to be read stays inside that middle box.
BANNER_W, BANNER_H = 2560, 1440
SAFE_W, SAFE_H = 1546, 423


def avatar() -> Image.Image:
    """800x800, shown as a circle as small as 98px, so the logo's rounded
    border would be cut off: just the `__q__` on night, sized to sit inside
    the circle."""
    unit = 32
    img = Image.new("RGB", (800, 800), NIGHT)
    draw = ImageDraw.Draw(img)
    # Logo grid units: q 5 wide, two 2-unit underscores with a 1-unit space
    # on each side, 1 unit from the q. 17 units across, 7 down.
    x = (800 - 17 * unit) // 2
    top = (800 - 7 * unit) // 2
    baseline = top + 4 * unit
    for ux in (0, 3, 12, 15):
        draw.rectangle((x + ux * unit, baseline, x + (ux + 2) * unit - 1, baseline + unit - 1), fill=EMBER)
    for row, line in enumerate(Q_PIXELS):
        for col, cell in enumerate(line):
            if cell == "#":
                px, py = x + (6 + col) * unit, top + row * unit
                draw.rectangle((px, py, px + unit - 1, py + unit - 1), fill=PARCHMENT)
    return img


def watermark() -> Image.Image:
    """150x150 with a clear background, in the corner of every video: the
    128px logo, unscaled so its pixels stay sharp."""
    img = Image.new("RGBA", (150, 150), (0, 0, 0, 0))
    mark = logo().resize((128, 128), Image.NEAREST)
    img.paste(mark, (11, 11), mark)
    return img


def sprite(path: Path, scale: int) -> Image.Image:
    img = Image.open(path).convert("RGBA")
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def banner() -> Image.Image:
    """The title art behind the wordmark, with the squire on one side and the
    Flatmates.js pair on the other, since the channel carries both games."""
    art = Image.open(ROOT / "assets" / "backgrounds" / "title_art.png").convert("RGB")
    img = upscale(art, BANNER_W / art.width)
    img = Image.blend(img, Image.new("RGB", img.size, NIGHT), 0.25)
    sx, sy = (BANNER_W - SAFE_W) // 2, (BANNER_H - SAFE_H) // 2
    band = Image.new("L", img.size, 0)
    ImageDraw.Draw(band).rectangle((0, sy - 30, BANNER_W, sy + SAFE_H + 30), fill=200)
    img.paste(Image.new("RGB", img.size, NIGHT), (0, 0), band.filter(ImageFilter.GaussianBlur(40)))

    d = ImageDraw.Draw(img)
    big = font(PIXEL, 150)
    parts = (("__", EMBER), ("dunder_quest", GOLD), ("__", EMBER))
    x = (BANNER_W - sum(int(d.textlength(t, font=big)) for t, _ in parts)) // 2
    for text, fill in parts:
        shadowed(d, (x, sy + 40), text, big, fill, 8)
        x += int(d.textlength(text, font=big))
    tag = font(PIXEL, 58)
    line = "Pixel-art games that teach you to code"
    shadowed(d, ((BANNER_W - int(d.textlength(line, font=tag))) // 2, sy + 228), line, tag, PARCHMENT, 5)
    sub = font(LABEL, 56)
    line = ">>> Python · JavaScript · free in your browser"
    shadowed(d, ((BANNER_W - int(d.textlength(line, font=sub))) // 2, sy + 316), line, sub, ASH, 3)

    # The cast stands just outside the phone crop: desktops and TVs show
    # them, and phones lose nothing they need.
    floor = sy + SAFE_H - 10
    squire = sprite(ROOT / "assets" / "sprites" / "squire.png", 12)
    img.paste(squire, (sx - 60 - squire.width, floor - squire.height), squire)
    for i, name in enumerate(("clive", "jazz")):
        mate = sprite(SITE / "static" / "img" / "flatmates" / f"{name}.png", 12)
        img.paste(mate, (sx + SAFE_W + 60 + i * (mate.width + 24), floor - mate.height), mate)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, img in {"avatar.png": avatar(), "banner.png": banner(), "watermark.png": watermark()}.items():
        img.save(OUT / name, optimize=True)
        print(f"wrote {(OUT / name).relative_to(ROOT.parents[1])}")


if __name__ == "__main__":
    main()
