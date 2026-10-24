"""Generate the six stages' parallax layers, the world map and the title key art.

Reads OPENROUTER_API_KEY and OPENROUTER_BASE_URL from the project .env.
Never prints the key. Raw model output lands in tools/generated/scenery,
and the downscaled pixel art is written into assets/backgrounds.

    python tools/generate_scenery.py            # generate + install
    python tools/generate_scenery.py --install  # re-run the pixel pass only
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "tools" / "generated" / "scenery"
OUT = ROOT / "assets" / "backgrounds"
MODEL = "openai/gpt-image-2.5-flare"

STYLE = (
    "16-bit pixel art video game background, chunky readable shapes, limited warm palette, "
    "soft storybook medieval light, no characters, no text, no letters, no logo, no watermark, no UI."
)

# name: (prompt, aspect, transparent, (width, height) in game pixels before 2x scale)
JOBS: dict[str, tuple[str, str, bool, tuple[int, int]]] = {
    "wood_far": (
        'Wide side-scrolling platformer sky layer over an ancient misty forest at dawn: pale gold and mint sky, soft layered clouds, very distant blue-green hills topped with tiny castle turrets along the bottom third. Fills the whole frame, horizontally seamless left to right. ' + STYLE,
        "21:9", False, (320, 135),
    ),
    "wood_mid": (
        'Side-scrolling platformer middle parallax layer: a band of gnarled old oak trees, mossy trunks and round neatly trimmed shrubberies of different sizes in muted greens, occupying only the bottom half of the frame. Everything above is fully transparent. Low contrast. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "wood_near": (
        'Side-scrolling platformer foreground parallax layer: a low strip of dark green bracken, ferns, tree roots and little round bushes in silhouette, hugging only the bottom fifth of the frame. Everything above is fully transparent. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "shoppe_far": (
        'Wide side-scrolling platformer background of a medieval village high street at golden afternoon: timber-framed shop fronts with crooked roofs, hanging shop signs with no writing, a distant church spire and soft clouds. Muted so foreground platforms stand out. Fills the whole frame, horizontally seamless left to right. ' + STYLE,
        "21:9", False, (320, 135),
    ),
    "shoppe_mid": (
        'Side-scrolling platformer middle parallax layer: market stalls with striped awnings, wooden crates, barrels and empty shelves of round cheese wheels, all in muted warm browns and creams, occupying only the bottom half of the frame. Everything above is fully transparent. Low contrast. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "shoppe_near": (
        'Side-scrolling platformer foreground parallax layer: a low strip of dark cobbles, sacks, a cart wheel and straw in silhouette, hugging only the bottom fifth of the frame. Everything above is fully transparent. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "cave_far": (
        'Wide side-scrolling platformer background: the inside of a huge dim rocky cave, grey-blue stone walls, many small round burrow holes, a few shafts of cold light from cracks above, scattered pebbles. Dark and muted so foreground platforms stand out. Fills the whole frame, horizontally seamless left to right. ' + STYLE,
        "21:9", False, (320, 135),
    ),
    "cave_mid": (
        'Side-scrolling platformer middle parallax layer: rock columns, stalagmites and stalactites hanging from the top edge, a few carrots and leafy turnip tops poking from the rubble, slate grey silhouettes with cool rim light, occupying the bottom half and the top edge only; everything else fully transparent. Low contrast. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "cave_near": (
        'Side-scrolling platformer foreground parallax layer: a low strip of near-black boulders and rubble with a few tiny glinting crystals, hugging only the bottom fifth of the frame. Everything above is fully transparent. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "ministry_far": (
        'Wide side-scrolling platformer background: the grand interior of an old government ministry hall, tall stone columns, long arched windows letting in pale blue light, tiled floor perspective, grand but silly, cool blues and greys. Muted so foreground platforms stand out. Fills the whole frame, horizontally seamless left to right. ' + STYLE,
        "21:9", False, (320, 135),
    ),
    "ministry_mid": (
        'Side-scrolling platformer middle parallax layer: rows of filing cabinets, tall stacks of paper, hat stands with bowler hats and umbrellas, in muted slate blue, occupying only the bottom half of the frame. Everything above is fully transparent. Low contrast. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "ministry_near": (
        'Side-scrolling platformer foreground parallax layer: a low strip of dark office clutter, a bench, paper heaps and a potted plant in silhouette, hugging only the bottom fifth of the frame. Everything above is fully transparent. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "gorge_far": (
        'Wide side-scrolling platformer sky layer over a deep misty mountain gorge at sunset: coral and violet sky, towering dark cliffs either side, wisps of fog rising from the bottomless chasm, a tiny distant castle on a far peak. Muted so foreground platforms stand out. Fills the whole frame, horizontally seamless left to right. ' + STYLE,
        "21:9", False, (320, 135),
    ),
    "gorge_mid": (
        'Side-scrolling platformer middle parallax layer: jagged rocky crags, a frayed old rope bridge in the distance and a few dead trees, dark plum silhouettes with warm rim light, occupying only the bottom half of the frame. Everything above is fully transparent. Low contrast. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "gorge_near": (
        'Side-scrolling platformer foreground parallax layer: a low strip of near-black cliff-edge rocks and dry grass tufts, hugging only the bottom fifth of the frame. Everything above is fully transparent. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "castle_far": (
        'Wide side-scrolling platformer sky layer at dramatic golden dusk: a vast sky with a single bright beam of light breaking through clouds, and a huge silhouetted castle with many towers and flags on a hill along the bottom third. Fills the whole frame, horizontally seamless left to right. ' + STYLE,
        "21:9", False, (320, 135),
    ),
    "castle_mid": (
        'Side-scrolling platformer middle parallax layer: crenellated castle battlements, round towers, banners on poles and a wooden siege catapult, in muted rose and stone grey, occupying only the bottom half of the frame. Everything above is fully transparent. Low contrast. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "castle_near": (
        'Side-scrolling platformer foreground parallax layer: a low strip of dark castle rubble, a broken cart and long grass in silhouette, hugging only the bottom fifth of the frame. Everything above is fully transparent. Horizontally seamless. ' + STYLE,
        "21:9", True, (320, 135),
    ),
    "world_map": (
        "Overworld map of a storybook medieval kingdom for a pixel platformer, seen from a slightly raised angle, "
        "at dawn. Gentle green hills, a misty forest on the lower left, a little village with a market on the left "
        "middle, a rocky cave mouth on the right, a grand stone ministry building on the upper right, a deep gorge "
        "crossed by a rope bridge in the upper middle, and a tall castle on a hill at the upper left. No roads or paths. "
        "The bottom quarter is soft dark foreground hills with no detail, reserved for interface panels. "
        + STYLE,
        "16:9", False, (480, 270),
    ),
    "title_art": (
        "Key art for a silly medieval quest pixel platformer title screen: a tiny squire in a too-big helmet and a "
        "tabard, clapping two coconut halves together, stands on a grassy cliff edge at the lower left, looking over "
        "a valley of round shrubberies and a misty gorge toward a distant shining castle under a dawn sky. A beam of "
        "golden light breaks through the clouds onto the castle. Leave the upper middle third calm, empty sky for a title. "
        + STYLE,
        "16:9", False, (480, 270),
    ),
}


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    path = ROOT / ".env"
    if not path.exists():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def request_image(base: str, key: str, prompt: str, aspect: str, transparent: bool) -> Image.Image:
    body = {
        "model": MODEL,
        "prompt": prompt,
        "n": 1,
        "aspect_ratio": aspect,
        "quality": "high",
        "background": "transparent" if transparent else "opaque",
    }
    req = urllib.request.Request(
        f"{base}/images",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "http://localhost",
            "X-Title": "Dunder Quest",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=400) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:600].replace(key, "[REDACTED]")
        raise RuntimeError(f"HTTP {exc.code} {detail}") from exc
    data = payload.get("data") or []
    if not data or "b64_json" not in data[0]:
        raise RuntimeError("response had no b64_json")
    image = Image.open(io.BytesIO(base64.b64decode(data[0]["b64_json"])))
    image.load()
    return image.convert("RGBA")


def seamless(image: Image.Image, band: int) -> Image.Image:
    """Fold the right band over the left one so Parallax2D repeats without a seam.

    The result is `band` pixels narrower. Its last column was originally next to
    the first column of the folded band, so the wrap is continuous.
    """
    width, height = image.size
    out = image.crop((0, 0, width - band, height))
    for x in range(band):
        t = x / float(band)
        tail = image.crop((width - band + x, 0, width - band + x + 1, height))
        head = image.crop((x, 0, x + 1, height))
        out.paste(Image.blend(tail, head, t), (x, 0))
    return out


def pixelate(image: Image.Image, size: tuple[int, int], colors: int, transparent: bool) -> Image.Image:
    image = image.resize(size, Image.Resampling.LANCZOS)
    alpha = image.getchannel("A").point(lambda a: 255 if a >= 128 else 0) if transparent else None
    rgb = image.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    reduced = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    if alpha is not None:
        reduced.putalpha(alpha)
    return reduced


def install(name: str) -> None:
    _prompt, _aspect, transparent, size = JOBS[name]
    source = Image.open(RAW / f"{name}.png").convert("RGBA")
    if name not in ("title_art", "world_map"):
        source = seamless(source, source.width // 10)
    colors = 40 if name in ("title_art", "world_map") else 24
    final = pixelate(source, size, colors, transparent)
    OUT.mkdir(parents=True, exist_ok=True)
    final.save(OUT / f"{name}.png")
    print(f"INSTALLED {name} {final.size}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--install", action="store_true", help="skip the API and redo the pixel pass")
    parser.add_argument("only", nargs="*", help="limit to these job names")
    args = parser.parse_args()
    names = args.only or list(JOBS)
    if not args.install:
        env = load_env()
        key = env.get("OPENROUTER_API_KEY", "")
        base = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
        if not key:
            sys.exit("OPENROUTER_API_KEY is missing from .env")
        RAW.mkdir(parents=True, exist_ok=True)
        with ThreadPoolExecutor(max_workers=4) as pool:
            futures = {pool.submit(request_image, base, key, *JOBS[n][:3]): n for n in names}
            for future in as_completed(futures):
                name = futures[future]
                try:
                    future.result().save(RAW / f"{name}.png")
                    print(f"IMAGE ok {name}", flush=True)
                except Exception as exc:  # keep the other jobs going
                    print(f"IMAGE fail {name}: {exc}", flush=True)
    for name in names:
        if (RAW / f"{name}.png").exists():
            install(name)


if __name__ == "__main__":
    main()
