"""Generate the cast's full-body sprites for the web Pilot's sitcom scenes.

Each character is asked for as one sheet of four poses in a row (standing,
two walking steps, talking with a gesture), so the poses match; the sheet is
cut apart on its empty columns and each pose pixelated to the same height,
feet on the bottom edge, into assets/sprites/<who>.png as a strip of four
frames. Uses the same request and pixel pass as tools/art.py.

    python tools/sprites.py                # generate everything missing
    python tools/sprites.py ricky gilroy   # just these
    python tools/sprites.py --install      # redo the cut and pixel pass only
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))
sys.path.insert(0, str(HERE))

import generate_scenery as base  # noqa: E402
from art import CAST  # noqa: E402

RAW = HERE / "generated" / "sprites"
OUT = ROOT / "assets" / "sprites"
H = 96  # frame height in game pixels; the stage is 480x270
W = 64  # frame width, figure centred, feet on the bottom edge
POSES = 4

SHEET_STYLE = (
    "A sprite sheet for a 16-bit pixel art comedy adventure game, in the style of classic point-and-click "
    "adventure games. The SAME character drawn exactly four times in a single horizontal row, evenly spaced "
    "with clear empty space between them, each one full body from the top of the head to the shoes, all the "
    "same size, standing on the same baseline, facing to the right in a three-quarter side view: "
    "1) standing relaxed; 2) walking, left foot forward; 3) walking, right foot forward; 4) talking, one hand "
    "raised in an expressive gesture, mouth open. Identical face, hair, clothes, colours and proportions in "
    "all four. Slightly big head, cartoon proportions, bold dark outlines, flat shading, limited palette. An "
    "invented original cartoon character who does not resemble any real person, actor or celebrity. "
    "Transparent background, nothing behind the characters, no shadows on the ground. No text, no numbers, "
    "no letters, no logos, no watermark, no frame."
)

# Aleister Jr. can't walk: it rolls about on an office chair.
BODIES = {
    "aleister": "Not a person: an old chunky beige computer monitor with a bright green pixel face on its black "
                "screen (two square eyes and a wide, eager smile), riding on a black wheeled office chair; "
                "two thin bendy cable arms come out of its sides. In the walking poses the chair rolls and "
                "the arms swing; in the talking pose one cable arm points up eagerly.",
    "walter": CAST["walter"] + " Charcoal trousers, plain dark shoes. Stands very still and stiff, arms by "
              "his sides, even when walking.",
    "galen": CAST["galen"] + " Slim dark jeans and expensive minimalist white sneakers.",
    "veronica": CAST["veronica"] + " Grey tailored trousers, black flats; holds a phone.",
    "ulrich": CAST["ulrich"] + " Baggy cargo shorts, socks and sandals, a big belly, a swaggering walk.",
    "ricky": CAST["ricky"] + " Slim jeans, worn sneakers, hunched shoulders, an anxious walk.",
    "gilroy": CAST["gilroy"] + " Black jeans, black boots, hands in pockets when walking.",
    "danesh": CAST["danesh"] + " Chinos, clean white sneakers, a slightly puffed-out chest.",
    "gerard": CAST["gerard"] + " Pressed grey trousers, sensible brown shoes, a lanyard, holding a clipboard.",
}


def frames(sheet: Image.Image) -> list[Image.Image]:
    """Cut the sheet on its empty columns into the figures, left to right."""
    alpha = sheet.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    w, h = alpha.size
    cols = [any(alpha.getpixel((x, y)) for y in range(0, h, 2)) for x in range(w)]
    runs, start = [], None
    for x, on in enumerate(cols + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > w // 40:  # skip stray specks
                runs.append((start, x))
            start = None
    # A figure with a gap in it (a raised arm) can split; merge the narrowest gaps.
    while len(runs) > POSES:
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = gaps.index(min(gaps))
        runs[i : i + 2] = [(runs[i][0], runs[i + 1][1])]
    if len(runs) != POSES:
        raise RuntimeError(f"found {len(runs)} figures, wanted {POSES}")
    out = []
    for x0, x1 in runs:
        crop = sheet.crop((x0, 0, x1, h))
        box = crop.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
        out.append(crop.crop(box))
    return out


def install(name: str) -> None:
    sheet = Image.open(RAW / f"{name}.png").convert("RGBA")
    figs = frames(sheet)
    # One scale for all four, from the tallest, so poses don't change size.
    tall = max(f.height for f in figs)
    scale = (H - 2) / tall
    strip = Image.new("RGBA", (W * POSES, H), (0, 0, 0, 0))
    for k, f in enumerate(figs):
        size = (max(1, round(f.width * scale)), max(1, round(f.height * scale)))
        size = (min(size[0], W), size[1])
        px = base.pixelate(f, size, 24, True)
        strip.alpha_composite(px, (k * W + (W - size[0]) // 2, H - size[1]))
    OUT.mkdir(parents=True, exist_ok=True)
    strip.save(OUT / f"{name}.png", optimize=True)
    print("installed", name, flush=True)


def generate(name: str, url: str, key: str) -> str:
    image = base.request_image(url, key, BODIES[name] + " " + SHEET_STYLE, "16:9", True)
    RAW.mkdir(parents=True, exist_ok=True)
    (RAW.parent / ".gdignore").touch()
    image.save(RAW / f"{name}.png")
    install(name)
    return name


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or [n for n in BODIES if not (OUT / f"{n}.png").exists()]
    if "--install" in sys.argv:
        for name in names:
            install(name)
        return
    url, key = base.credentials()
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = {pool.submit(generate, name, url, key): name for name in names}
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:  # noqa: BLE001
                print("failed", futures[future], str(exc)[:300].replace(key, "[REDACTED]"), flush=True)


if __name__ == "__main__":
    main()
