"""Generate each stage's backdrop, the title art and the line map's picture.

Uses the Dunder Quest scenery helpers (the request, the seamless fold and the
pixel pass) from ../../tools/generate_scenery.py, with this game's prompts.
Reads OPENROUTER_API_KEY and OPENROUTER_BASE_URL from the repo's .env and
never prints the key. Raw output lands in tools/generated/, pixel art in
assets/backgrounds/.

    python tools/scenery.py              # generate everything missing
    python tools/scenery.py flat_far     # just these
    python tools/scenery.py --install    # redo the pixel pass only
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
OUT = ROOT / "assets" / "backgrounds"

STYLE = (
    "16-bit pixel art video game background, chunky readable shapes, limited muted palette, "
    "drab early-2000s suburban London, slightly melancholy and funny, no people, no text, no letters, "
    "no logos, no watermark, no UI."
)
FAR = "Wide side-scrolling platformer background, fills the whole frame, horizontally seamless left to right, muted and low contrast so foreground platforms stand out: "
MID = "Side-scrolling platformer middle parallax layer, occupying only the bottom half of the frame, everything above fully transparent, low contrast, horizontally seamless: "

JOBS: dict[str, tuple[str, str, bool, tuple[int, int]]] = {
    "flat_far": (FAR + "the back wall of a cramped rented flat in a Croydon tower block: magnolia woodchip wallpaper, a radiator, a cheap bookshelf, a framed film poster with no writing, a net-curtained window showing grey tower blocks under a white sky, a doorway into a narrow hall. " + STYLE, "21:9", False, (320, 135)),
    "flat_near": (MID + "flat-share clutter in silhouette: a coffee table with pizza boxes, a guitar on a stand, a clothes horse with socks, a pile of library books, a lava lamp, an exercise bike used as a coat rack. " + STYLE, "21:9", True, (320, 135)),
    "office_far": (FAR + "a drab open-plan loans office on a high floor: grey fabric partitions, humming strip lights, a water cooler, blank motivational posters, a wall of windows showing Croydon office towers at dusk. " + STYLE, "21:9", False, (320, 135)),
    "office_near": (MID + "office furniture in silhouette: swivel chairs, grey filing cabinets, a photocopier, a sad potted yucca, a stack of box files. " + STYLE, "21:9", True, (320, 135)),
    "cellar_far": (FAR + "a damp basement under a pub used as a band rehearsal room: whitewashed brick arches, fairy lights, an egg-box soundproofed wall, faded gig posters with no writing, a tiny stage with a red curtain. " + STYLE, "21:9", False, (320, 135)),
    "cellar_near": (MID + "band gear in silhouette: guitar amps, a drum kit, microphone stands, tangled cables, beer crates, a broken keyboard. " + STYLE, "21:9", True, (320, 135)),
    "farm_far": (FAR + "rainy English countryside on a cheap weekend away: soggy green fields, drystone walls, a muddy farmyard, a rented holiday cottage with a wonky roof, low grey clouds, a few sheep far away. " + STYLE, "21:9", False, (320, 135)),
    "farm_near": (MID + "a country lane edge in silhouette: hedgerows, hay bales, a five-bar gate, a muddy tractor tyre, nettles, a wonky signpost with no writing. " + STYLE, "21:9", True, (320, 135)),
    "station_far": (FAR + "a busy suburban railway station platform in the evening: a long canopy roof, a departure board with no readable text, glass walls, the lights of office towers behind, a tram in the distance. " + STYLE, "21:9", False, (320, 135)),
    "station_near": (MID + "station furniture in silhouette: metal benches, bins, ticket machines, a vending machine, a pigeon on a railing, a lost umbrella. " + STYLE, "21:9", True, (320, 135)),
    "church_far": (FAR + "inside a small English parish church dressed for a wedding: stained glass windows of simple colored shapes, white flower arrangements, wooden roof beams, ribbons on the pews, warm candle light. " + STYLE, "21:9", False, (320, 135)),
    "church_near": (MID + "wedding dressing in silhouette: wooden pews with white bows, flower stands, a harp, a table of presents, a three-tier cake on a trolley. " + STYLE, "21:9", True, (320, 135)),
    "title": (
        "Key art for a pixel platformer title screen: the outside landing of a 1960s Croydon tower block at dusk, a "
        "front door with a brass number plate, a doormat, a bin bag, and through the stairwell window a view of tower "
        "blocks, a tram line and a pink and orange sky. At the lower right two small figures stand by the door: one "
        "neat young man in a navy V-neck jumper, shirt and tie, arms folded, worried; one scruffy young man with "
        "shaggy blond hair in a red hoodie holding a guitar, grinning. Leave the upper left half calm and dark for "
        "a title and menu. " + STYLE,
        "16:9", False, (480, 270),
    ),
    "map": (
        "Stylised aerial view of a grey suburban town at dusk for a level select screen: tower blocks, an office "
        "district, a railway station, a pub, green fields at the edge of town and a church with a spire, the street "
        "lights coming on. No roads drawn in color, no text, no lines across the middle. " + STYLE,
        "16:9", False, (480, 270),
    ),
}


def install(name: str) -> None:
    _prompt, _aspect, transparent, size = JOBS[name]
    raw = Image.open(RAW / f"{name}.png").convert("RGBA")
    if size == (320, 135):
        raw = base.seamless(raw, raw.width // 12)
    art = base.pixelate(raw, size, 40 if transparent else 48, transparent)
    OUT.mkdir(parents=True, exist_ok=True)
    art.save(OUT / f"{name}.png")
    print("installed", name)


def generate(name: str, url: str, key: str) -> str:
    prompt, aspect, transparent, _size = JOBS[name]
    image = base.request_image(url, key, prompt, aspect, transparent)
    RAW.mkdir(parents=True, exist_ok=True)
    image.save(RAW / f"{name}.png")
    install(name)
    return name


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or [n for n in JOBS if not (OUT / f"{n}.png").exists()]
    if "--install" in sys.argv:
        for name in names:
            install(name)
        return
    env = base.load_env()
    url = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
    key = env.get("OPENROUTER_API_KEY", "")
    if not key:
        sys.exit("OPENROUTER_API_KEY is missing from .env")
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(generate, name, url, key): name for name in names}
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:  # noqa: BLE001
                print("failed", futures[future], str(exc)[:300])


if __name__ == "__main__":
    main()
