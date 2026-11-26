"""Generate the backdrops and the cast's portraits.

Uses the Dunder Quest scenery helpers (the request and the pixel pass) from
../../dunder-quest/tools/generate_scenery.py, with this game's prompts. The
prompts describe an original sandwich shop and an original cast; they never
name or describe any show, its sets or its actors. Raw output lands in
tools/generated/, pixel art in assets/backgrounds/ and assets/sprites/. Never
prints the key.

    python tools/scenery.py                # generate everything missing
    python tools/scenery.py pass shell     # just these
    python tools/scenery.py --install      # redo the pixel pass only

The portraits are one set: if one is regenerated, look at it beside the rest.
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
from common import api  # noqa: E402

RAW = HERE / "generated"
BACKDROPS = ROOT / "assets" / "backgrounds"
SPRITES = ROOT / "assets" / "sprites"

STYLE = (
    "16-bit pixel art video game background, chunky readable shapes, limited palette of stainless steel grey, "
    "white tile, warm amber lamplight, deep night blue and a few touches of green tape and red, cosy and a "
    "little comic, no text, no letters, no writing, no signs with words, no logos, no watermark, no UI."
)
PORTRAIT = (
    "Pixel art character portrait for a comic restaurant-kitchen video game dialogue box: head and shoulders "
    "bust, facing three-quarters toward the viewer, big readable expressive face, bold dark outline, flat "
    "shading, limited palette, 16-bit console style, centered, filling most of the frame, plain fully "
    "transparent background, no text, no letters, no frame, no border. The character: "
)

# name -> (prompt, aspect, transparent, size, colors)
JOBS: dict[str, tuple[str, str, bool, tuple[int, int], int]] = {
    "title": (
        "Key art for a comic pixel-art game title screen: a small old brick corner sandwich shop at night on "
        "the left third of the picture, with a red-and-white striped awning, a blank unlit sign board, and a "
        "big front window glowing warm amber, under the dark steel girders of an elevated train line that "
        "crosses the top of the picture. Wet pavement reflecting the light. The right two thirds are calm, "
        "dark night sky and a low, dim, far-off city skyline, left empty for a title and a menu. No people. "
        + STYLE, "16:9", False, (480, 270), 48),
    "city": (
        "A big northern city skyline at dusk seen across a wide cold lake, tall dark towers with lit windows "
        "under an orange and deep blue sky, and in the middle distance an elevated commuter train with lit "
        "windows crossing a steel girder bridge. The sun low and reflected in the water. Calm lower third. No "
        "people. " + STYLE, "16:9", False, (480, 270), 48),
    "kitchen": (
        "The cramped back kitchen of an old sandwich shop seen straight-on: white tiled walls, a big steel "
        "extractor hood over a six-burner range and a flat-top grill, a steaming stock pot, hanging pans, "
        "steel counters with a wooden cutting board and a chef's knife, a shelf of plastic tubs each labelled "
        "with a strip of green tape, squeeze bottles, a worn red tile floor in the lower third. Bright and "
        "tidy. No people. " + STYLE, "16:9", False, (480, 270), 48),
    "pass": (
        "The pass of a restaurant kitchen seen straight-on from the dining side: a long stainless steel shelf "
        "under a row of glowing amber heat lamps, a metal rail above it with many small blank white paper "
        "order slips hanging from it, three plated sandwiches waiting under the lamps, a small brass service "
        "bell, and the busy steel kitchen out of focus behind. Calm dark steel in the lower third. No "
        "people. " + STYLE, "16:9", False, (480, 270), 48),
    "walkin": (
        "The inside of a restaurant walk-in refrigerator seen straight-on: tall wire shelving on three sides "
        "packed in perfect order with clear plastic tubs and cardboard boxes, every one labelled with a strip "
        "of green tape, crates of vegetables, a cold blue-white light overhead, a faint mist, a grey floor in "
        "the lower third. Very neat. No people. " + STYLE, "16:9", False, (480, 270), 48),
    "dining": (
        "The small dining room of an old neighbourhood sandwich shop dressed up for a big night, seen "
        "straight-on: dark red walls with framed pictures, a window on the night city, pendant lamps with "
        "warm pools of light, a few tables with white cloths, and in the middle one table set for a single "
        "guest with a candle, a folded napkin and a water glass. A wooden floor in the lower third. No "
        "people. " + STYLE, "16:9", False, (480, 270), 48),
    "chef": (PORTRAIT + "a tired but kind young head chef in their late twenties with messy dark brown hair, "
             "light stubble, dark circles under the eyes, a plain white t-shirt and a blue bib apron, a "
             "serious, focused look.", "1:1", True, (96, 96), 28),
    "shell": (PORTRAIT + "a calm, capable Black woman in her thirties who runs a restaurant kitchen's pass, "
              "her hair tied up in a green headscarf, a white chef's jacket, a pencil behind one ear, one "
              "eyebrow slightly raised and a small dry knowing smile.", "1:1", True, (96, 96), 28),
    "awk": (PORTRAIT + "a big, loud, warm-hearted older man in his sixties, bald on top with grey hair at the "
            "sides and a huge grey moustache, a dark red tracksuit jacket over a white polo shirt, a thin gold "
            "chain, mouth open mid-shout, arms-wide enthusiasm.", "1:1", True, (96, 96), 28),
    "dev": (PORTRAIT + "a deadpan young South Asian dishwasher in his early twenties with heavy-lidded eyes "
            "and a flat unimpressed mouth, an orange knit beanie, big headphones round his neck, a dark "
            "waterproof apron over a grey t-shirt.", "1:1", True, (96, 96), 28),
    "root": (PORTRAIT + "an elegant, formidable restaurant critic in her sixties with a sharp silver bob "
             "haircut, round dark-rimmed glasses, dark red lipstick, a black coat with a deep red silk "
             "scarf, one eyebrow arched, giving nothing away.", "1:1", True, (96, 96), 28),
}


def is_portrait(name: str) -> bool:
    return JOBS[name][2]


def install(name: str) -> None:
    _prompt, _aspect, transparent, size, colors = JOBS[name]
    raw = Image.open(RAW / f"{name}.png").convert("RGBA")
    if transparent:
        # Crop to what's drawn, then pad square, so every bust fills its box.
        box = raw.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
        if box:
            raw = raw.crop(box)
        side = max(raw.size)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(raw, ((side - raw.width) // 2, side - raw.height))
        raw = square
    art = base.pixelate(raw, size, colors, transparent)
    out = SPRITES if transparent else BACKDROPS
    out.mkdir(parents=True, exist_ok=True)
    art.save(out / f"{name}.png")
    print("installed", name, flush=True)


def generate(name: str, url: str, key: str) -> str:
    prompt, aspect, transparent, _size, _colors = JOBS[name]
    image = base.request_image(url, key, prompt, aspect, transparent)
    RAW.mkdir(parents=True, exist_ok=True)
    image.save(RAW / f"{name}.png")
    install(name)
    return name


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or [n for n in JOBS if not ((SPRITES if is_portrait(n) else BACKDROPS) / f"{n}.png").exists()]
    if "--install" in sys.argv:
        for name in args or list(JOBS):
            if (RAW / f"{name}.png").exists():
                install(name)
        return
    url, key = base.credentials() if base.uses_grok() else api()
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = {pool.submit(generate, name, url, key): name for name in names}
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:  # noqa: BLE001
                print("failed", futures[future], str(exc)[:300].replace(key, "[REDACTED]"), flush=True)


if __name__ == "__main__":
    main()
