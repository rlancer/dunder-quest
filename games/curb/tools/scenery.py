"""Generate each scene's backdrop, the title art and the LA map.

Uses the Dunder Quest scenery helpers (the request and the pixel pass) from
../../dunder-quest/tools/generate_scenery.py, with this game's prompts.
Reads OPENROUTER_API_KEY and OPENROUTER_BASE_URL from the repo's .env and
never prints the key. Raw output lands in tools/generated/, pixel art in
assets/backgrounds/.

    python tools/scenery.py              # generate everything missing
    python tools/scenery.py deli golf    # just these
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
    "16-bit pixel art adventure game background, chunky readable shapes, limited palette, warm sunny "
    "Los Angeles light, slightly smug wealthy-Westside comedy mood, no people, no animals, no text, "
    "no letters, no signs with writing, no logos, no watermark, no UI."
)
ROOM = (
    "Flat side-on view of one room, like a stage set seen from the audience, camera at standing height. "
    "The floor is a plain strip across the bottom fifth of the frame and must stay clear of furniture so "
    "characters can stand on it; furniture stands against the back wall. Fills the whole frame: "
)

JOBS: dict[str, tuple[str, str]] = {
    "kitchen": (ROOM + "a big sunny modern kitchen in a Pacific Palisades house in the morning: white "
                "cabinets, a marble island at the back, an expensive espresso machine, a bowl of lemons, "
                "glass doors onto a pool and palm trees. " + STYLE, "16:9"),
    "deli": (ROOM + "an old-school Jewish delicatessen in Los Angeles: a long glass counter with pastrami, "
             "pickles and cheesecake, little paper sample cups on the counter, red vinyl booths, framed "
             "photos with no faces visible, a menu board with no readable writing. " + STYLE, "16:9"),
    "dinner": (ROOM + "the dining room of a comfortable Encino house during a dinner party at dusk: a long "
               "table with a white cloth, candles and wine glasses, a sideboard with a bottle of red wine, "
               "abstract paintings, warm lamps, sliding doors to a garden. " + STYLE, "16:9"),
    "lawn": (ROOM + "outside, a sunny suburban Los Angeles driveway and front lawn between two houses: "
             "a perfect green lawn, a garage with its door open showing tools and a red lawnmower, a low "
             "hedge, jacaranda trees, a blue sky. " + STYLE, "16:9"),
    "buffet": (ROOM + "the sunlit Sunday brunch room of an exclusive country club: a long buffet table with "
               "silver chafing dishes, a big ice bowl of shrimp, a carving station, white tablecloths, "
               "tall windows onto a golf course, potted palms. " + STYLE, "16:9"),
    "golf": (ROOM + "outside on a golf course in Los Angeles at midday: a putting green with a flag, a sand "
             "bunker, a white golf cart parked at the back, eucalyptus trees, hills and a hazy blue sky. "
             + STYLE, "16:9"),
    "bistro": (ROOM + "the front of a fashionable French bistro in Beverly Hills in the evening: a maitre d' "
               "podium with a reservation book, a velvet rope, little round tables with candles, mirrors, "
               "brass lamps, a dark red wall. " + STYLE, "16:9"),
    "returns": (ROOM + "the returns desk of an upscale department store: a long counter with a cash register "
                "and folded sweaters, racks of cashmere sweaters, shopping bags, bright store lighting, "
                "mannequins without faces. " + STYLE, "16:9"),
    "coffee": (ROOM + "a trendy Los Angeles coffee shop: a counter with a big shiny espresso machine and a "
               "pastry case, a chalkboard menu with no readable writing, hanging plants, Edison bulbs, "
               "a velvet rope for the queue. " + STYLE, "16:9"),
    "guestroom": (ROOM + "a guest bedroom in a big Pacific Palisades house that someone has clearly moved "
                  "into: an unmade bed, a suitcase exploded on the floor, sneakers, a big TV with a game "
                  "console, takeout boxes, sunny windows. " + STYLE, "16:9"),
    "title": (
        "Key art for a pixel-art comedy game title screen: a sunny Los Angeles street of Westside mansions "
        "with palm trees, a silver Prius parked by the curb, a perfect lawn, a pink and gold evening sky. "
        "Leave the whole left half calm and plain for a title and menu. No people. " + STYLE,
        "16:9",
    ),
    "map": (
        "Stylised top-down pixel-art map of the Westside of Los Angeles for a level select screen: the "
        "ocean on the left, beaches, hills, winding canyon roads, a golf course, palm-lined boulevards, "
        "little houses with pools, a few shopping streets. Muted and calm so markers stand out on top. "
        "No text, no labels. " + STYLE,
        "16:9",
    ),
}


def install(name: str) -> None:
    raw = Image.open(RAW / f"{name}.png").convert("RGBA")
    art = base.pixelate(raw, (480, 270), 48, False)
    OUT.mkdir(parents=True, exist_ok=True)
    art.save(OUT / f"{name}.png")
    print("installed", name, flush=True)


def generate(name: str, url: str, key: str) -> str:
    prompt, aspect = JOBS[name]
    image = base.request_image(url, key, prompt, aspect, False)
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
                print("failed", futures[future], str(exc)[:300].replace(key, "[REDACTED]"), flush=True)


if __name__ == "__main__":
    main()
