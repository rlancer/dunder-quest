"""Generate the Amber Hollow parallax layers and the title key art.

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
    "soft dusk light, no characters, no text, no letters, no logo, no watermark, no UI."
)

# name: (prompt, aspect, transparent, (width, height) in game pixels before 2x scale)
JOBS: dict[str, tuple[str, str, bool, tuple[int, int]]] = {
    "amber_far": (
        "Wide side-scrolling platformer sky layer at golden dusk: a huge low amber sun, "
        "layered peach and violet clouds, and very distant pale lavender mesas along the bottom third. "
        "Fills the whole frame, horizontally seamless left to right. " + STYLE,
        "21:9", False, (320, 135),
    ),
    "amber_mid": (
        "Side-scrolling platformer middle parallax layer: a band of rolling ochre and rust hills "
        "with a few round amber autumn trees and small clay ruins, occupying only the bottom half of the frame. "
        "Everything above the hills is fully transparent. Horizontally seamless. " + STYLE,
        "21:9", True, (320, 135),
    ),
    "amber_near": (
        "Side-scrolling platformer foreground parallax layer: a low strip of dark plum and deep brown "
        "silhouetted grass tufts, ferns and boulders hugging the bottom quarter of the frame only. "
        "Everything above is fully transparent. Horizontally seamless. " + STYLE,
        "21:9", True, (320, 135),
    ),
    "span_far": (
        "Wide side-scrolling platformer sky layer over a volcanic canyon at night-dusk: deep violet and "
        "maroon sky with drifting ash clouds, a faint red glow on the horizon, and distant dark basalt cliffs with "
        "tiny glowing lava falls along the bottom third. Muted and dark so foreground platforms stand out. "
        "Fills the whole frame, horizontally seamless left to right. " + STYLE,
        "21:9", False, (320, 135),
    ),
    "span_mid": (
        "Side-scrolling platformer middle parallax layer: a row of broken ancient stone bridge arches and "
        "crumbling pillars in dark plum and charcoal, faint ember-orange rim light, occupying only the bottom "
        "half of the frame. Everything above is fully transparent. Low contrast. Horizontally seamless. " + STYLE,
        "21:9", True, (320, 135),
    ),
    "span_near": (
        "Side-scrolling platformer foreground parallax layer: a low strip of near-black basalt rocks and "
        "jagged spires with a few small glowing ember cracks, hugging only the bottom fifth of the frame. "
        "Everything above is fully transparent. Horizontally seamless. " + STYLE,
        "21:9", True, (320, 135),
    ),
    "kiln_far": (
        "Wide side-scrolling platformer background: the cavernous interior of a gigantic ancient clay kiln, "
        "curved dark maroon firebrick walls and a vaulted ceiling, distant arched furnace openings glowing deep "
        "orange, heat haze and floating sparks. Dark and muted so foreground platforms stand out. "
        "Fills the whole frame, horizontally seamless left to right. " + STYLE,
        "21:9", False, (320, 135),
    ),
    "kiln_mid": (
        "Side-scrolling platformer middle parallax layer: stacks of huge fired clay pots, brick buttresses and "
        "hanging iron chains in dark brown silhouette with warm orange edge light, occupying the bottom half and "
        "a few chains hanging from the top edge. Everything else fully transparent. Low contrast. "
        "Horizontally seamless. " + STYLE,
        "21:9", True, (320, 135),
    ),
    "kiln_near": (
        "Side-scrolling platformer foreground parallax layer: a low strip of near-black slag heaps and broken "
        "brick rubble with tiny glowing coals, hugging only the bottom fifth of the frame. Everything above is "
        "fully transparent. Horizontally seamless. " + STYLE,
        "21:9", True, (320, 135),
    ),
    "world_map": (
        "Overworld map screen for a pixel platformer, seen from a slightly raised side angle, at violet dusk. "
        "A winding dirt trail runs left to right across the middle of the image. Three landmarks sit on it: "
        "on the left, a cozy golden autumn hollow with round amber trees and a small sandstone arch; "
        "in the upper middle, a crumbling stone bridge spanning a glowing ember chasm; on the right, a huge "
        "smoking clay kiln shaped like a volcano with an orange glowing mouth. The top tenth is calm night sky "
        "and the bottom quarter is soft dark foreground hills with no detail, reserved for interface panels. "
        + STYLE,
        "16:9", False, (480, 270),
    ),
    "title_art": (
        "Key art for a cozy pixel platformer title screen: a tiny round grey river-pebble hero with a green "
        "sprout on its head and a red clay scarf stands on a sandstone cliff edge at the lower left, looking out "
        "over a vast valley of amber hills, glowing ember-orange ruins and a distant smoking kiln volcano "
        "under a violet dusk sky with first stars. Leave the upper middle third calm and empty sky for a title. "
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
            "X-Title": "Amber Hollow",
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
