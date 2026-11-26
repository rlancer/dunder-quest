"""Generate the backdrops and the cast's portraits.

Uses the Dunder Quest scenery helpers (the request and the pixel pass) from
../../dunder-quest/tools/generate_scenery.py, with this game's prompts. The
prompts describe an original New York apartment, diner, restaurant, garage,
network office and comedy club, and an original cast of sitcom types; they
never name or describe any show, its sets or its actors. Raw output lands in
tools/generated/, pixel art in assets/backgrounds/ and assets/sprites/. Never
prints the key.

    python tools/scenery.py                  # generate everything missing
    python tools/scenery.py diner stu        # just these
    python tools/scenery.py --install        # redo the pixel pass only

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
    "16-bit pixel art video game background, chunky readable shapes, a warm early-1990s palette of plum, teal, "
    "mustard yellow, cream and brick red, soft lamplight, cosy and a little comic, no people, no text, no letters, "
    "no writing, no signs with words, no logos, no watermark, no UI."
)
PORTRAIT = (
    "Pixel art character portrait for a comic early-1990s New York sitcom video game dialogue box: head and "
    "shoulders bust, facing three-quarters toward the viewer, big readable expressive face, bold dark outline, "
    "flat shading, limited palette, 16-bit console style, centered, filling most of the frame, plain fully "
    "transparent background, no text, no letters, no frame, no border. An original character, not resembling any "
    "real person or actor. The character: "
)

# name -> (prompt, aspect, transparent, size, colors)
JOBS: dict[str, tuple[str, str, bool, tuple[int, int], int]] = {
    "title": (
        "Key art for a comic pixel-art game title screen: a small corner coffee shop on a New York street at dusk "
        "on the left third of the picture, with a big glowing plate-glass window, a striped awning, a blank unlit "
        "neon sign shape with no letters, red-brick brownstone apartment buildings with fire escapes beside it, a "
        "yellow taxi at the kerb and steam rising from a manhole. The right two thirds are a calm plum and teal "
        "dusk sky over far-off rooftops and water towers, left empty for a title and a menu. No people. "
        + STYLE, "16:9", False, (480, 270), 48),
    "street": (
        "A quiet residential street on the Upper West Side of New York at golden hour, seen straight-on: a row of "
        "red-brick and brownstone apartment buildings with black iron fire escapes, stoops with steps, small "
        "trees, parked 1990s cars, a corner coffee shop with a lit window, wooden water towers on the roofs "
        "against a peach and lilac sky. Calm pavement in the lower third. No people. "
        + STYLE, "16:9", False, (480, 270), 48),
    "apartment": (
        "The living room of a 1990s New York one-bedroom apartment seen straight-on, like a sitcom set: a mustard "
        "yellow couch facing the viewer in the middle, a low coffee table, a bicycle hung on the wall, a "
        "kitchen counter with stools on the right and a row of colourful cereal boxes on a shelf, a front door "
        "on the left, plum and teal walls, a big window with blinds and the city at dusk beyond. A wooden floor "
        "in the lower third. Tidy and warm. No people. " + STYLE, "16:9", False, (480, 270), 48),
    "restaurant": (
        "The waiting area of a busy old Chinese restaurant in New York at night, seen straight-on: a wooden "
        "host podium with a reservation book and a little lamp, red paper lanterns hanging from the ceiling, a "
        "gold-framed mirror, a big round fish tank, a bench along the wall to wait on, and through an archway "
        "a glimpse of the dining room with round tables and white cloths. Red, gold and dark wood. A patterned "
        "carpet in the lower third. No people. " + STYLE, "16:9", False, (480, 270), 48),
    "diner": (
        "The inside of a classic New York corner diner in the daytime, seen straight-on: a row of teal vinyl "
        "booths along a big window onto the street, a long counter with chrome-rimmed stools on the right, a "
        "glass case of pies and cakes, coffee pots on warmers, a pass-through window to the kitchen, chequered "
        "black and white floor tiles in the lower third. Bright and cosy. No people. "
        + STYLE, "16:9", False, (480, 270), 48),
    "garage": (
        "The inside of a big multi-storey concrete parking garage in New York, seen straight-on: rows of "
        "parked early-1990s cars in many colours, fat concrete pillars painted with big level numbers, a ramp "
        "going up on one side, buzzing fluorescent tube lights, yellow painted lines on a grey floor in the "
        "lower third, an exit sign shape with no letters glowing green. Slightly gloomy, a little eerie, still "
        "comic. No people. " + STYLE, "16:9", False, (480, 270), 48),
    "network": (
        "A television network's conference room high in a Manhattan skyscraper, seen straight-on: a very long "
        "polished dark wood table with leather chairs, water jugs and neat stacks of script pages, a wall of "
        "windows behind it onto the midtown skyline at dusk, a big old tube television on a stand in the "
        "corner, a potted fern. Cool navy and mahogany with warm lamplight. A carpet in the lower third. "
        "No people. " + STYLE, "16:9", False, (480, 270), 48),
    "club": (
        "The small stage of a basement comedy club in New York at night, seen straight-on from the audience: a "
        "red exposed-brick back wall, a single microphone on a stand in the middle of a low wooden stage, a "
        "stool beside it with a glass of water, a warm spotlight pool, the backs of a few empty cafe tables "
        "with candles in the dark lower third. No people. " + STYLE, "16:9", False, (480, 270), 48),
    "stu": (PORTRAIT + "a neat, wry stand-up comedian in his mid thirties with short tidy dark hair, a long face, "
            "a slightly raised eyebrow and an amused half smile, wearing a crisp light blue button-down shirt "
            "under an open grey sport jacket.", "1:1", True, (96, 96), 28),
    "lenny": (PORTRAIT + "a nervous, fast-talking man in his mid thirties with a round face, thinning sandy-red "
              "curly hair, big round tortoiseshell glasses, sweating a little, eyes wide in panic, wearing a "
              "rumpled mustard cardigan over a striped polo shirt.", "1:1", True, (96, 96), 28),
    "dana": (PORTRAIT + "a sharp, sarcastic woman in her early thirties with big wavy auburn hair pinned up with "
             "a clip, bright green eyes, an unimpressed smirk, wearing a teal blazer with big shoulder pads over "
             "a cream blouse and small gold hoop earrings.", "1:1", True, (96, 96), 28),
    "zelnick": (PORTRAIT + "a tall, lanky, wild-eyed neighbour in his forties with a big shock of upswept grey "
                "and black hair standing straight up, bushy eyebrows, mouth open in delighted surprise, wearing "
                "a loud orange and brown 1970s bowling shirt with a wide collar.", "1:1", True, (96, 96), 28),
    "vernon": (PORTRAIT + "a smug, portly mail carrier in his forties with a neat black moustache, a round "
               "face and a self-satisfied smile, wearing a light blue uniform shirt with a dark blue patch on "
               "the shoulder and a blue postal cap.", "1:1", True, (96, 96), 28),
    "pratt": (PORTRAIT + "a stern, humourless television network executive in his sixties with slicked-back "
              "silver hair, a long straight face that has never laughed, half-moon reading glasses low on his "
              "nose, wearing a dark navy pinstripe suit, a white shirt and a deep red tie.", "1:1", True, (96, 96), 28),
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
