"""Generate the Human Backend's pixel art: the things on the desk and the diners.

Uses the Dunder Quest scenery helpers (the request and the pixel pass), like
../../tools/art.py. Reads OPENROUTER_API_KEY and OPENROUTER_BASE_URL from the
repo's .env and never prints the key. Raw output lands in tools/generated/
(ignored by git), pixel art in public/art/.

Every face is an invented cartoon; nobody is drawn to look like a real person.

    python tools/art.py                 # generate everything missing
    python tools/art.py ledger d3       # just these (again)
    python tools/art.py --install       # redo the pixel pass only
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT.parents[1] / "dunder-quest" / "tools"))

import generate_scenery as base  # noqa: E402

RAW = HERE / "generated"
OUT = ROOT / "public" / "art"

ITEM_STYLE = (
    "16-bit pixel art item for a comedy management game, one single object, centred, filling most of the "
    "frame, seen from the front at a slight three-quarter angle. Bold dark outline, flat shading, a small "
    "bright palette, chunky readable shapes. Transparent background, nothing else in the picture. "
    "No text, no letters, no numbers, no logos, no watermark, no frame."
)

FACE_STYLE = (
    "16-bit pixel art character close-up for the dialogue box of a comedy adventure game. Head and "
    "shoulders, facing the viewer, centred, the shoulders running off the bottom edge and the top of the "
    "head near the top edge. Big, simple, readable face: clear eyes, clear eyebrows, a clear mouth, bold "
    "dark outlines, flat shading, a limited palette. An invented original cartoon character who does not "
    "resemble any real person, actor or celebrity. Transparent background, nothing behind the character. "
    "No text, no letters, no logos, no watermark, no frame."
)

# name: (style, prompt, size)
ART: dict[str, tuple[str, str, int]] = {
    "notes": (ITEM_STYLE, "A small cork noticeboard in a wooden frame, completely bare brown cork with a "
              "few coloured push pins, nothing pinned to it.", 64),
    "ledger": (ITEM_STYLE, "A thick, heavy, old leather-bound ledger book lying closed, dark green cover "
               "with brass corners and a red ribbon bookmark.", 64),
    "stamp": (ITEM_STYLE, "A wooden-handled rubber stamp standing on a red ink pad.", 64),
    "ratecard": (ITEM_STYLE, "A chunky beige desk adding machine with big buttons and a curl of blank "
                 "paper receipt coming out of the top.", 64),
    "model": (ITEM_STYLE, "A mysterious fortune-teller's crystal ball glowing teal green, wired into a "
              "small black computer server box with blinking lights and cables.", 64),
    "key": (ITEM_STYLE, "A single shiny brass door key with a green plastic tag on a ring.", 48),
    "robot": (ITEM_STYLE, "A small desk robot arm with a white and green casing, a two-finger gripper "
              "and one round glowing green eye, looking pleased with itself.", 64),
    "door": (ITEM_STYLE, "The front of a tiny cosy Italian trattoria: a wooden door, a red and white "
             "striped awning, one window glowing warm yellow, a potted plant. Flat front view.", 64),
    "scooter": (ITEM_STYLE, "An electric kick scooter, bright orange, with a charging cable trailing "
                "from it ending in a plug.", 64),
    "phone": (ITEM_STYLE, "A modern smartphone standing upright, flat front view, dark slate body, a "
              "blank pale glowing screen.", 48),
    "d1": (FACE_STYLE, "A cheerful young Black woman with a big curly afro puff and gold hoop earrings; "
           "a mustard yellow jumper.", 48),
    "d2": (FACE_STYLE, "A tired middle-aged white man with a bald head, round glasses and a grey "
           "moustache; a brown cardigan.", 48),
    "d3": (FACE_STYLE, "A young East Asian man with a neat black undercut and a hopeful smile; a red "
           "bomber jacket.", 48),
    "d4": (FACE_STYLE, "An elegant older Latina woman with silver hair in a bob and red lipstick; a "
           "teal scarf.", 48),
    "d5": (FACE_STYLE, "A red-haired young woman with freckles, a messy bun and big headphones round "
           "her neck; a green hoodie.", 48),
    "d6": (FACE_STYLE, "A large cheerful bearded man with a turban; a navy blazer.", 48),
    "d7": (FACE_STYLE, "A teenager with bleached spiky hair, braces and a suspiciously innocent grin; "
           "a purple t-shirt.", 48),
    "d8": (FACE_STYLE, "A woman in a hijab, coral pink, with sharp eyebrows and an unimpressed look; a "
           "denim jacket.", 48),
    "nonna": (FACE_STYLE, "A tiny, fierce, elderly Italian grandmother who owns a restaurant: grey hair "
              "in a tight bun, thick eyebrows drawn together, arms-folded glare; a white apron over a "
              "black dress.", 48),
    "stranger": (FACE_STYLE, "A mysterious figure in a dark charcoal hoodie with the hood up, the face "
                 "entirely in black shadow except two round white eyes.", 48),
    "bot": (FACE_STYLE, "A boxy corporate robot head, glossy blue, with one red camera-lens eye, a "
            "little antenna and a tiny grey necktie.", 48),
}


def load_env() -> dict[str, str]:
    """The nearest .env above this file, so it also works from a git worktree
    inside the main checkout (whose .env isn't checked in)."""
    for folder in HERE.parents:
        path = folder / ".env"
        if path.exists():
            values: dict[str, str] = {}
            for line in path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    values[key.strip()] = value.strip().strip('"').strip("'")
            return values
    return {}


def generate(name: str, env: dict[str, str]) -> str:
    style, prompt, _ = ART[name]
    image = base.request_image(env["OPENROUTER_BASE_URL"].rstrip("/"), env["OPENROUTER_API_KEY"],
                               f"{style} {prompt}", "1:1", True)
    RAW.mkdir(parents=True, exist_ok=True)
    image.save(RAW / f"{name}.png")
    return name


def install(name: str) -> None:
    raw = RAW / f"{name}.png"
    if not raw.exists():
        return
    size = ART[name][2]
    image = Image.open(raw).convert("RGBA")
    box = image.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
    if box and ART[name][0] is ITEM_STYLE:
        # Items fill their square; faces keep the framing they were drawn with.
        w, h = box[2] - box[0], box[3] - box[1]
        side = max(w, h)
        cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(image.crop(box), (side // 2 - (cx - box[0]), side // 2 - (cy - box[1])))
        image = square
    OUT.mkdir(parents=True, exist_ok=True)
    base.pixelate(image, (size, size), 24, True).save(OUT / f"{name}.png", optimize=True)


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or list(ART)
    if "--install" not in sys.argv:
        env = load_env()
        todo = [n for n in names if args or not (RAW / f"{n}.png").exists()]
        with ThreadPoolExecutor(max_workers=6) as pool:
            jobs = {pool.submit(generate, n, env): n for n in todo}
            for job in as_completed(jobs):
                try:
                    print("generated", job.result(), flush=True)
                except Exception as exc:  # keep going; rerun for the ones that failed
                    print("FAILED", jobs[job], exc, flush=True)
    for name in names:
        install(name)
    print("installed", len(names))


if __name__ == "__main__":
    main()
