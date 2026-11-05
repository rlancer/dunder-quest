"""Generate the title flyover's parallax layers: the sky over the bay, the
downtown skyline and the Mission's Victorian houses.

Like tools/art.py, it uses the Dunder Quest scenery helpers (the request and
the pixel pass) from ../../dunder-quest/tools/generate_scenery.py, reads
OPENROUTER_API_KEY and OPENROUTER_BASE_URL from the repo's .env and never
prints the key. Raw output lands in tools/generated/ (ignored by git and
Godot), pixel art in assets/flyover/.

The art has no writing on it: the companies' names are signs the game draws
itself in its pixel font (ui/flyover.gd), so no company's logo artwork is
ever copied.

    python tools/flyover.py               # generate everything missing
    python tools/flyover.py city          # just this one
    python tools/flyover.py --install     # redo the pixel pass only
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import generate_scenery as base  # noqa: E402

RAW = HERE / "generated"
OUT = ROOT / "assets" / "flyover"

STYLE = (
    "16-bit pixel art, bright and toy-like like a miniature model town, chunky readable shapes, a limited "
    "cheerful palette, clean dark outlines. No people, no animals, no cars, no text, no letters, no numbers, "
    "no readable writing, no signs, no logos, no watermark, no UI."
)

# name: (prompt, transparent, how it's sized). Sized "fill" is cropped to
# exactly (w, h); sized "height" is cropped to what's drawn and scaled to h
# pixels tall, its width following.
LAYERS: dict[str, tuple[str, bool, tuple[str, int, int]]] = {
    "sky": (
        "Wide side-on panorama, the far background of a side-scrolling flyover of San Francisco on a sunny "
        "afternoon: a clear bright blue sky with a few puffy white clouds in the top half; below it the bay, "
        "glittering blue water across the bottom third; on the far left the red-orange towers and cables of "
        "the Golden Gate Bridge with white fog rolling over green hills behind it; low hazy blue hills along "
        "the horizon in the middle; on the far right, small in the distance, the long grey suspension span of "
        "the Bay Bridge. Nothing in the foreground, no buildings. Fills the whole frame. " + STYLE,
        False, ("fill", 600, 270),
    ),
    "city": (
        "Side-on skyline layer for a side-scrolling flyover of downtown San Francisco: one continuous dense "
        "row of office towers of many different heights, widths and colours, all standing on one flat base "
        "line along the bottom edge of the frame and filling it from the left edge to the right edge: glass "
        "towers in teal and blue, cream stone towers, brick blocks, and among them the white, sharply pointed "
        "Transamerica Pyramid left of centre and the very tall, slim, rounded-top Salesforce Tower right of "
        "centre. Most towers have plain flat rooftops. Everything above the buildings is fully transparent, "
        "nothing behind them. " + STYLE,
        True, ("height", 0, 180),
    ),
    "houses": (
        "Side-on foreground layer for a side-scrolling flyover of San Francisco's Mission District: one "
        "continuous row of narrow, tall painted Victorian row houses side by side, filling the frame from the "
        "left edge to the right edge, all standing on one flat base line along the bottom edge: pastel pink, "
        "sky blue, butter yellow, lavender and mint houses with white trim, bay windows and pointed gables, "
        "two palm trees between them, and at the far right end one slightly shabby pale grey-green Victorian "
        "with a flat roof and a crooked TV aerial. Everything above the rooftops is fully transparent, nothing "
        "behind them. " + STYLE,
        True, ("height", 0, 130),
    ),
}


def install(name: str) -> None:
    _prompt, transparent, (how, w, h) = LAYERS[name]
    raw = Image.open(RAW / f"flyover_{name}.png").convert("RGBA")
    if how == "fill":
        scale = max(w / raw.width, h / raw.height)
        raw = raw.resize((round(raw.width * scale), round(raw.height * scale)), Image.Resampling.LANCZOS)
        left = (raw.width - w) // 2
        top = raw.height - h
        raw = raw.crop((left, top, left + w, top + h))
        size = (w, h)
    else:
        box = raw.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox() or (0, 0, *raw.size)
        raw = raw.crop(box)
        size = (round(raw.width * h / raw.height), h)
    art = base.pixelate(raw, size, 48 if transparent else 32, transparent)
    if not transparent:
        art = art.convert("RGB").quantize(32, dither=Image.Dither.NONE)
    OUT.mkdir(parents=True, exist_ok=True)
    art.save(OUT / f"{name}.png", optimize=True)
    print("installed", name, art.size, flush=True)


def generate(name: str, url: str, key: str) -> str:
    prompt, transparent, _size = LAYERS[name]
    image = base.request_image(url, key, prompt, "21:9", transparent)
    RAW.mkdir(parents=True, exist_ok=True)
    (RAW / ".gdignore").touch()
    image.save(RAW / f"flyover_{name}.png")
    install(name)
    return name


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or [n for n in LAYERS if not (OUT / f"{n}.png").exists()]
    if "--install" in sys.argv:
        for name in names:
            install(name)
        return
    env = base.load_env()
    url = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    key = env.get("OPENROUTER_API_KEY", "")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = {pool.submit(generate, name, url, key): name for name in names}
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:  # noqa: BLE001
                print("failed", futures[future], str(exc)[:300].replace(key, "[REDACTED]"), flush=True)


if __name__ == "__main__":
    main()
