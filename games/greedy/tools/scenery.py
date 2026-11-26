"""Generate the backdrops and the cast's portraits.

Uses the Dunder Quest scenery helpers (the request and the pixel pass) from
../../dunder-quest/tools/generate_scenery.py, with this game's prompts. The
prompts describe an original frontier town and an original cast; they never
name or describe any film, its sets or its actors. Raw output lands in
tools/generated/, pixel art in assets/backgrounds/ and assets/sprites/. Never
prints the key.

    python tools/scenery.py                # generate everything missing
    python tools/scenery.py street dot     # just these
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
    "16-bit pixel art video game background, chunky readable shapes, limited warm palette of sunburnt orange, "
    "dusty tan, weathered wood brown, cactus green and deep sunset purple, comic and cheerful, no text, no "
    "letters, no writing, no signs with words, no logos, no watermark, no UI."
)
PORTRAIT = (
    "Pixel art character portrait for a comic western video game dialogue box: head and shoulders bust, "
    "facing three-quarters toward the viewer, big readable expressive face, bold dark outline, flat shading, "
    "limited warm palette, 16-bit console style, centered, filling most of the frame, plain fully transparent "
    "background, no text, no letters, no frame, no border. The character: "
)

# name -> (prompt, aspect, transparent, size, colors)
JOBS: dict[str, tuple[str, str, bool, tuple[int, int], int]] = {
    "title": (
        "Key art for a comic pixel-art western game title screen: a small frontier town of wooden storefronts "
        "on a dusty main street at sunset, seen from the end of the street, under a huge orange and purple sky. "
        "Behind the town stands one enormous thin slab of red rock leaning steeply to one side, like a giant "
        "leaning plank of stone, with the low sun beside it. Cacti and a water tower. Leave the left half calm "
        "and dark for a title and a menu. No people. " + STYLE, "16:9", False, (480, 270), 48),
    "street": (
        "A straight-on side view of the main street of a small frontier town at mid-morning: a row of wooden "
        "false-front buildings (a general store, a bank, a barber, a church steeple at the end), boardwalks, "
        "hitching rails, barrels, a water trough, a wide dusty street in the lower third, blue sky with a few "
        "clouds. No people, no horses. " + STYLE, "16:9", False, (480, 270), 48),
    "desert": (
        "A vast, flat, completely empty desert under a blazing noon sun, a few cacti and distant mesas, and in "
        "the exact middle of all that empty space one lonely toll gate: a small wooden booth and a striped "
        "red-and-white barrier arm across nothing, with no fence and no road on either side, absurd and tiny in "
        "the huge landscape. No people. " + STYLE, "16:9", False, (480, 270), 48),
    "camp": (
        "A campsite in a rocky canyon at night: a crackling campfire in the middle with a big black iron pot of "
        "beans hanging over it, tin plates and spoons on the ground, bedrolls and saddles around the fire, "
        "saguaro cacti, canyon walls, a starry deep blue sky and a crescent moon. Warm firelight. No people, no "
        "horses. " + STYLE, "16:9", False, (480, 270), 48),
    "saloon": (
        "The inside of a frontier saloon seen straight-on: a long polished wooden bar with bottles on shelves "
        "and a big mirror behind it, an upright piano, round card tables and chairs, swinging doors at the "
        "left, oil lamp chandeliers, red wallpaper, warm lamplight. No people. " + STYLE, "16:9", False,
        (480, 270), 48),
    "decoy": (
        "A fake frontier town built as a decoy on a dusty plain at high noon, seen from the side so the trick "
        "shows: the storefronts are only flat painted plywood fronts with nothing behind them, propped up from "
        "behind by slanted timber braces and sandbags, like a film set, one front leaning a little, a painted "
        "cardboard church steeple, tumbleweeds, a harsh sun overhead. No people. " + STYLE, "16:9", False,
        (480, 270), 48),
    "band": (
        "A wide open desert at golden hour and, set up in the middle of nowhere among the cacti, a full dance "
        "orchestra in white dinner jackets playing on a little bandstand: rows of tiny musicians with trumpets, "
        "trombones and saxophones, a grand piano, a double bass and a drum kit, music stands, completely out of "
        "place in the wilderness. Tiny figures, no faces visible. " + STYLE, "16:9", False, (480, 270), 48),
    "sunset": (
        "Two tiny riders on horseback seen from behind in silhouette, riding away down a desert trail into an "
        "enormous setting sun, long shadows, mesas and cacti in silhouette, a glowing orange, pink and purple "
        "sky filling most of the frame. Calm lower third. " + STYLE, "16:9", False, (480, 270), 48),
    "sheriff": (PORTRAIT + "a lean, calm, handsome Black frontier sheriff in his thirties with a neat "
                "moustache, a wide tan hat, a spotless tan jacket with a big gold star badge and a mustard "
                "neckerchief, one eyebrow raised, the hint of a smile.", "1:1", True, (96, 96), 28),
    "kid": (PORTRAIT + "a scruffy, sleepy-eyed gunslinger deputy with sandy hair, stubble, half-closed "
            "relaxed eyes and a lazy lopsided grin, a battered grey hat pushed far back on his head, a faded "
            "blue shirt, a small tin deputy star, a stalk of straw in the corner of his mouth.", "1:1", True,
            (96, 96), 28),
    "dot": (PORTRAIT + "a glamorous, smirking outlaw queen in her forties with dark red hair, a black "
            "flat-brimmed hat with a single silver star pinned on it, a red polka-dot neckerchief, a black "
            "riding coat, one eyebrow arched, very pleased with herself.", "1:1", True, (96, 96), 28),
    "mayor": (PORTRAIT + "a round, flustered, pink-faced frontier town mayor with huge grey mutton-chop "
              "whiskers, a tall black top hat, a green waistcoat and a red-white-and-blue sash, wide anxious "
              "eyes and a hopeful smile.", "1:1", True, (96, 96), 28),
    "gibber": (PORTRAIT + "a wild-eyed, cackling old prospector with an enormous tangled white beard, a "
               "floppy shapeless brown hat, one tooth, a red union suit under braces, squinting one eye and "
               "shouting happily.", "1:1", True, (96, 96), 28),
    "backtrack": (PORTRAIT + "an enormous, gentle, slow-witted outlaw henchman with a huge square jaw and "
                  "a neck wider than his head, a tiny bowler hat perched on top, heavy brows, a deeply "
                  "puzzled frown, a patched brown vest.", "1:1", True, (96, 96), 28),
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
    if name == "title":
        # The rock the town is named for has to lean the way a backslash does.
        raw = raw.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
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
