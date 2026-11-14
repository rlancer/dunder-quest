"""Generate each room's backdrop and the title art.

Uses the Dunder Quest scenery helpers (the request and the pixel pass) from
../../dunder-quest/tools/generate_scenery.py, with this game's prompts. The
prompts describe an original palace; they never name or describe any other
game's rooms. Raw output lands in tools/generated/, pixel art in
assets/backgrounds/. Never prints the key.

    python tools/scenery.py              # generate everything missing
    python tools/scenery.py hall gate    # just these
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
sys.path.insert(0, str(HERE))

import generate_scenery as base  # noqa: E402
from common import api  # noqa: E402

RAW = HERE / "generated"
OUT = ROOT / "assets" / "backgrounds"

STYLE = (
    "16-bit pixel art video game background, chunky readable shapes, limited palette of deep night blues, "
    "teal and lamp gold, moody and mysterious, no people, no animals, no text, no letters, no writing, "
    "no logos, no watermark, no UI."
)
WALL = (
    "A flat, straight-on view of the back wall of a room inside an old Persian palace at night, used as the "
    "far background layer of a side-scrolling platformer, so it is all wall and no floor: nothing in the "
    "foreground, no furniture, even lighting, low contrast, slightly dark so characters stand out in front. "
    "Fills the whole frame: "
)

JOBS: dict[str, tuple[str, str]] = {
    "hall": (WALL + "a long hall of tall pointed arches and slim columns, geometric mosaic tilework in blue and "
             "teal, carved plaster, small brass lamps hanging on chains, moonlight through lattice windows. "
             + STYLE, "16:9"),
    "dungeon": (WALL + "a palace dungeon: rough dark stone blocks, iron rings and chains on the wall, barred "
                "arched alcoves, a few dying wall torches, damp moss, deep shadow. " + STYLE, "16:9"),
    "chasm": (WALL + "a great cavern under the palace: the far rock wall of a deep chasm with carved stone "
              "arches and broken pillars built into the cliff, a thin waterfall, faint blue moonlight from "
              "a crack far above. " + STYLE, "16:9"),
    "doors": (WALL + "a palace antechamber with rows of identical arched niches and star-pattern tiles, "
              "heavy drapes, brass lanterns, a carpet hung on the wall, everything symmetrical. "
              + STYLE, "16:9"),
    "gate": (WALL + "a grand throne-hall wall: enormous arches, a huge round window of coloured glass showing "
             "a full moon, purple banners, tall golden candle stands, an ominous violet glow. "
             + STYLE, "16:9"),
    "title": (
        "Key art for a pixel-art adventure game title screen: a Persian palace of domes and minarets on a "
        "cliff at night under a huge full moon, a tall tower with one lit window, stars, sand dunes below, "
        "sand blowing off the dunes in a long glowing golden ribbon across the sky. Leave the left half calm "
        "and dark for a title and menu. No people. " + STYLE,
        "16:9",
    ),
}


def install(name: str) -> None:
    raw = Image.open(RAW / f"{name}.png").convert("RGBA")
    art = base.pixelate(raw, (480, 270), 40, False)
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
    url, key = base.credentials() if base.uses_grok() else api()
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(generate, name, url, key): name for name in names}
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as exc:  # noqa: BLE001
                print("failed", futures[future], str(exc)[:300].replace(key, "[REDACTED]"), flush=True)


if __name__ == "__main__":
    main()
