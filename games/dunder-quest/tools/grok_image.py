"""Ask the Grok CLI for an image, using its `grok login` instead of an OpenRouter key.

generate_scenery.request_image calls this when IMAGE_PROVIDER=grok. Each image
is its own headless Grok job, run in an empty temp folder with only image_gen
enabled, so the prompt is all that leaves the machine.

Grok's image_gen has two limits the callers don't: it returns JPGs with no
alpha, and only offers the aspects below. Transparency is asked for as a flat
magenta background and keyed out; other aspects are cropped from the nearest
wider one, and the prompt says which bands will be lost.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ASPECTS = ("1:1", "16:9", "9:16", "3:2", "2:3")
SESSIONS = Path(os.environ.get("GROK_HOME") or Path.home() / ".grok") / "sessions"
TIMEOUT_SECONDS = 300
KEY_DISTANCE = 80  # RGB distance from the background still counted as background, to absorb JPEG noise

ON_MAGENTA = (
    " Ignore any request for transparency: wherever the frame should be empty, fill it with one solid flat "
    "pure magenta #FF00FF, edge to edge, with no gradient, shadow, floor or vignette. Do not use magenta or "
    "hot pink anywhere in the subject."
)


def ratio(aspect: str) -> float:
    width, height = aspect.split(":")
    return int(width) / int(height)


def closest_aspect(aspect: str) -> str:
    """The native aspect closest to `aspect` that is at least as tall, so cropping only trims height."""
    wanted = ratio(aspect)
    taller = [a for a in ASPECTS if ratio(a) <= wanted]
    if not taller:
        raise ValueError(f"no native aspect can be cropped to {aspect}")
    return max(taller, key=ratio)


def crop_to_aspect(image: Image.Image, aspect: str) -> Image.Image:
    height = round(image.width / ratio(aspect))
    top = (image.height - height) // 2
    return image.crop((0, top, image.width, top + height))


def border_colour(rgb: np.ndarray) -> np.ndarray:
    """The commonest colour around the frame's edge, so a subject touching the edge doesn't skew it."""
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]))
    buckets = border // 16
    values, counts = np.unique(buckets, axis=0, return_counts=True)
    return border[(buckets == values[counts.argmax()]).all(axis=1)].mean(axis=0)


def key_out_magenta(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB")).astype(int)
    # Asked for #FF00FF, Grok paints anything from hot pink to raspberry, so measure what it painted.
    colour = border_colour(rgb)
    if min(colour[0], colour[2]) - colour[1] < 40:
        raise RuntimeError(f"Grok did not leave a magenta background to key out (found {colour.round()})")
    background = np.linalg.norm(rgb - colour, axis=-1) < KEY_DISTANCE
    alpha = Image.fromarray(np.where(background, 0, 255).astype("uint8"))
    # Shave one pixel off every edge to drop the pink fringe JPEG leaves around the subject.
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    subject = np.asarray(alpha) > 0
    if not subject.any():
        raise RuntimeError("nothing left after keying out the background")
    # Later steps blend and resize these pixels, so no magenta can stay hidden under the alpha.
    rgb[~subject] = rgb[subject].mean(axis=0)
    out = Image.fromarray(rgb.astype("uint8"))
    out.putalpha(alpha)
    return out


def saved_image(session_id: str) -> Path | None:
    for workspace in SESSIONS.iterdir():
        folder = workspace / session_id / "images"
        if folder.is_dir():
            files = sorted(folder.iterdir(), key=lambda path: path.stat().st_mtime)
            return files[-1] if files else None
    return None


def request_image(prompt: str, aspect: str, transparent: bool) -> Image.Image:
    native = closest_aspect(aspect)
    if native != aspect:
        lost = round((1 - ratio(native) / ratio(aspect)) * 50)
        prompt += (
            f" This will be cropped to {aspect}: the top {lost}% and bottom {lost}% of the frame are cut off, "
            "so keep everything that matters between them, including anything meant to touch the bottom edge."
        )
    if transparent:
        prompt += ON_MAGENTA
    instruction = f"Call image_gen exactly once with aspect_ratio {native} and this prompt, verbatim, then stop:\n\n{prompt}"
    with tempfile.TemporaryDirectory(prefix="gm-") as cwd:
        result = subprocess.run(
            [
                "grok", "-p", instruction,
                "--tools", "image_gen",
                "--permission-mode", "bypassPermissions",
                "--max-turns", "10",
                "--disable-web-search",
                "--output-format", "json",
                "--cwd", cwd,
            ],
            capture_output=True, text=True, encoding="utf-8", timeout=TIMEOUT_SECONDS,
        )
    # An unknown --tools entry leaves every other tool enabled, under bypassPermissions.
    if "names no tool" in result.stderr:
        raise RuntimeError(f"tool allowlist rejected: {result.stderr.strip()}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"grok exited {result.returncode}: {(result.stderr or result.stdout).strip()}") from exc
    path = saved_image(payload["sessionId"])
    if path is None:
        raise RuntimeError(f"no image produced: {str(payload.get('text')).strip()}")
    image = Image.open(path)
    image.load()
    if native != aspect:
        image = crop_to_aspect(image, aspect)
    return key_out_magenta(image) if transparent else image.convert("RGBA")
