"""Generate original sprites and audio for Shrubbery Wood.

Reads OPENROUTER_API_KEY and OPENROUTER_BASE_URL from the project .env.
Never prints the key. Image and audio model ids come from the live API.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import math
import struct
import subprocess
import urllib.error
import urllib.request
import wave
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
ASSET_SPRITES = ROOT / "assets" / "sprites"
ASSET_AUDIO = ROOT / "assets" / "audio"
OUT_SPRITES = ROOT / "tools" / "generated" / "sprites"
OUT_AUDIO = ROOT / "tools" / "generated" / "audio"
LOG_PATH = ROOT / "tools" / "generation_log.txt"
MANIFEST_PATH = ROOT / "tools" / "manifest.json"

SPRITE_SPECS = {
    "pebble": ("feet", (16, 24)),
    "copperling": ("feet", (20, 12)),
    "emberseed": ("center", (12, 12)),
    "cache_stone": ("fill", (16, 16)),
    "cache_stone_spent": ("fill", (16, 16)),
    "clay_brick": ("fill", (16, 16)),
    "waygate": ("feet", (24, 40)),
    "tile_ground": ("fill", (16, 16)),
    "tile_fill": ("fill", (16, 16)),
    "tile_slab": ("fill", (16, 16)),
    "tile_one_way": ("plank", (16, 16)),
}

PROMPTS = {
    "pebble": (
        "A single original video-game hero sprite: a round river pebble with a tiny green sprout, "
        "a short clay scarf, and stubby feet, facing right. Flat dusk colors, bold dark outline, "
        "16-bit pixel art, centered, full body visible, isolated on a flat magenta #FF00FF background. "
        "No text, no watermark, no logo, not a copy of any existing character."
    ),
    "copperling": (
        "A single original low wide beetle enemy sprite, copper shell with teal spots, tiny legs, "
        "facing right, cute, bold dark outline, flat colors, 16-bit pixel art, centered, "
        "isolated on a flat magenta #FF00FF background. No text, no logo, not a copy of any existing creature."
    ),
    "emberseed": (
        "A single original collectible sprite: a small glowing amber seed gem with a teal leaf highlight. "
        "Bold outline, flat colors, 16-bit pixel art, centered, isolated on a flat magenta #FF00FF background. "
        "No text, no coin, no logo."
    ),
    "cache_stone": (
        "A single original square game block of honey sandstone with a carved spiral rune and a little teal moss. "
        "Bold outline, flat colors, 16-bit pixel art, the block fills the frame edge to edge. "
        "No letters, no question mark, no logo."
    ),
    "cache_stone_spent": (
        "A single original square game block of dim empty honey sandstone with a hollow carved square and no rune. "
        "Bold outline, flat colors, 16-bit pixel art, the block fills the frame edge to edge. No letters, no logo."
    ),
    "clay_brick": (
        "A single original breakable dry terracotta clay brick, cracked corners, chips, "
        "bold outline, flat colors, 16-bit pixel art, the brick fills the frame edge to edge. No letters, no logo."
    ),
    "waygate": (
        "A single original tall stone archway sprite, honey sandstone posts and a small teal flame in the opening. "
        "Bold outline, flat colors, 16-bit pixel art, centered, isolated on a flat magenta #FF00FF background. "
        "No flag, no text, no logo."
    ),
    "tile_ground": (
        "Seamless square ground tile, top quarter teal moss, lower three quarters warm honey sandstone. "
        "16-bit pixel art, the texture fills the entire frame edge to edge, no border, no text, no background."
    ),
    "tile_fill": (
        "Seamless square underground tile of warm sandstone blocks, no moss. "
        "16-bit pixel art, the texture fills the entire frame edge to edge, no border, no text."
    ),
    "tile_slab": (
        "Seamless square platform tile, a flat cap of layered honey sandstone with a darker bottom edge. "
        "16-bit pixel art, the texture fills the entire frame edge to edge, no border, no text."
    ),
    "tile_one_way": (
        "A single thin wooden plank, honey colored, horizontal, bold outline, 16-bit pixel art, "
        "sitting in the top of the frame, isolated on a flat magenta #FF00FF background. No text, no logo."
    ),
}

SFX_PROMPTS = {
    "jump": "A single 0.2 second sound effect of a soft clay pop hop. No voice, no speech, no music, no melody.",
    "stomp": "A single 0.25 second sound effect of a soft boot squashing moss. No voice, no speech, no music.",
    "pickup": "A single 0.25 second bright glassy chime, one note. No voice, no speech, no music.",
    "bump": "A single 0.2 second hollow sandstone knock. No voice, no speech, no music.",
    "break": "A single 0.35 second dry clay pot crack. No voice, no speech, no music.",
    "goal": "A single 1 second warm bell and flute cadence that resolves. No voice, no lyrics, no speech.",
}

MUSIC_PROMPT = (
    "Instrumental only. No vocals, no lyrics, no speech, no humming. "
    "A short original looping piece of dusk adventure music for a small platformer: "
    "soft kalimba, clay flute, and a quiet hand drum. Moderate tempo, warm and playful. "
    "Do not imitate any existing game soundtrack."
)


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def redact(text: str, secret: str) -> str:
    if secret:
        text = text.replace(secret, "[REDACTED]")
    return text


def log(message: str, secret: str = "") -> None:
    safe = redact(message, secret)
    print(safe, flush=True)
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(safe + "\n")


def request_json(url: str, key: str, payload: dict | None = None, timeout: int = 180) -> tuple[dict, str]:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "http://localhost",
        "X-Title": "Dunder Quest",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if payload else "GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read()
            content_type = response.headers.get("Content-Type", "")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")[:900]
        raise RuntimeError(f"HTTP {exc.code} {redact(body, key)}") from exc
    text = raw.decode("utf-8", "replace")
    return json.loads(text), content_type


def request_bytes(url: str, key: str, payload: dict, timeout: int = 180) -> tuple[bytes, str]:
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "http://localhost",
        "X-Title": "Dunder Quest",
    }
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read()
            content_type = response.headers.get("Content-Type", "")
            return raw, content_type
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")[:900]
        raise RuntimeError(f"HTTP {exc.code} {redact(body, key)}") from exc


def param_values(params: dict, name: str) -> list:
    spec = params.get(name) or {}
    if isinstance(spec, dict):
        return list(spec.get("values") or [])
    return []


def choose_image_model(models: list[dict]) -> tuple[str, dict]:
    ranked: list[tuple[int, str, dict]] = []
    for model in models:
        model_id = str(model.get("id") or "")
        params = model.get("supported_parameters") or {}
        if not isinstance(params, dict):
            params = {}
        score = 0
        backgrounds = param_values(params, "background")
        formats = param_values(params, "output_format")
        if "transparent" in backgrounds and "png" in formats:
            score += 10
        elif "png" in formats:
            score += 4
        lowered = model_id.lower()
        if "gpt-image" in lowered:
            score += 6
        elif "flash-image" in lowered or ("gemini" in lowered and "image" in lowered):
            score += 5
        elif "seedream" in lowered:
            score += 3
        ranked.append((score, model_id, params))
    ranked.sort(key=lambda item: (-item[0], item[1]))
    if not ranked or not ranked[0][1]:
        raise RuntimeError("Image model list was empty")
    return ranked[0][1], ranked[0][2]


def image_body(model_id: str, params: dict, prompt: str) -> dict:
    body: dict = {"model": model_id, "prompt": prompt}
    if "n" in params:
        body["n"] = 1
    formats = param_values(params, "output_format")
    if "png" in formats:
        body["output_format"] = "png"
    backgrounds = param_values(params, "background")
    if "transparent" in backgrounds:
        body["background"] = "transparent"
    ratios = param_values(params, "aspect_ratio")
    if "1:1" in ratios:
        body["aspect_ratio"] = "1:1"
    resolutions = param_values(params, "resolution")
    for preferred in ("1K", "512", "768"):
        if preferred in resolutions:
            body["resolution"] = preferred
            break
    qualities = param_values(params, "quality")
    if "medium" in qualities:
        body["quality"] = "medium"
    elif "low" in qualities:
        body["quality"] = "low"
    return body


def write_beep(path: Path, frequency: float, duration: float) -> None:
    rate = 22050
    count = int(rate * duration)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        frames = bytearray()
        for index in range(count):
            envelope = 1.0
            if index < 80:
                envelope = index / 80.0
            elif index > count - 180:
                envelope = max(0.0, (count - index) / 180.0)
            sample = int(envelope * 0.35 * 32767 * math.sin(2 * math.pi * frequency * index / rate))
            frames += struct.pack("<h", sample)
        handle.writeframes(frames)


def mark_placeholder(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 2, 2), fill=(255, 0, 255, 255))
    if image.width >= 16 and image.height >= 16:
        draw.text((1, image.height - 9), "PH", fill=(255, 0, 255, 255))
    return image


def write_placeholders() -> None:
    ASSET_SPRITES.mkdir(parents=True, exist_ok=True)
    ASSET_AUDIO.mkdir(parents=True, exist_ok=True)

    def save(name: str, image: Image.Image) -> None:
        mark_placeholder(image).save(ASSET_SPRITES / f"{name}.png")

    pebble = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(pebble)
    draw.ellipse((2, 6, 13, 20), fill=(150, 144, 136, 255))
    draw.rectangle((7, 2, 9, 8), fill=(70, 150, 90, 255))
    draw.rectangle((4, 12, 12, 15), fill=(176, 92, 64, 255))
    save("pebble", pebble)

    bug = Image.new("RGBA", (20, 12), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bug)
    draw.ellipse((1, 2, 18, 10), fill=(184, 112, 58, 255))
    draw.ellipse((4, 4, 8, 7), fill=(64, 160, 150, 255))
    save("copperling", bug)

    seed = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    draw = ImageDraw.Draw(seed)
    draw.ellipse((2, 2, 9, 10), fill=(232, 164, 54, 255))
    draw.polygon([(6, 1), (8, 4), (5, 4)], fill=(64, 170, 150, 255))
    save("emberseed", seed)

    cache = Image.new("RGBA", (16, 16), (196, 146, 86, 255))
    draw = ImageDraw.Draw(cache)
    draw.ellipse((4, 4, 11, 11), outline=(84, 54, 36, 255))
    save("cache_stone", cache)

    spent = Image.new("RGBA", (16, 16), (148, 116, 78, 255))
    draw = ImageDraw.Draw(spent)
    draw.rectangle((5, 5, 10, 10), outline=(70, 48, 32, 255))
    save("cache_stone_spent", spent)

    brick = Image.new("RGBA", (16, 16), (176, 84, 58, 255))
    draw = ImageDraw.Draw(brick)
    draw.line((2, 3, 8, 9), fill=(110, 42, 32, 255))
    draw.line((9, 2, 14, 8), fill=(110, 42, 32, 255))
    save("clay_brick", brick)

    gate = Image.new("RGBA", (24, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(gate)
    draw.rectangle((2, 8, 6, 38), fill=(186, 140, 82, 255))
    draw.rectangle((17, 8, 21, 38), fill=(186, 140, 82, 255))
    draw.arc((2, 4, 21, 22), 180, 360, fill=(186, 140, 82, 255), width=3)
    draw.ellipse((10, 16, 14, 22), fill=(70, 200, 180, 255))
    save("waygate", gate)

    ground = Image.new("RGBA", (16, 16), (186, 140, 82, 255))
    draw = ImageDraw.Draw(ground)
    draw.rectangle((0, 0, 15, 4), fill=(62, 140, 96, 255))
    save("tile_ground", ground)

    fill = Image.new("RGBA", (16, 16), (168, 122, 74, 255))
    draw = ImageDraw.Draw(fill)
    draw.line((0, 8, 15, 8), fill=(130, 90, 52, 255))
    save("tile_fill", fill)

    slab = Image.new("RGBA", (16, 16), (210, 168, 110, 255))
    draw = ImageDraw.Draw(slab)
    draw.rectangle((0, 12, 15, 15), fill=(120, 78, 48, 255))
    save("tile_slab", slab)

    plank = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(plank)
    draw.rectangle((0, 1, 15, 5), fill=(168, 112, 64, 255))
    save("tile_one_way", plank)

    sheet = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    for index, name in enumerate(("tile_ground", "tile_fill", "tile_slab", "tile_one_way")):
        tile = Image.open(ASSET_SPRITES / f"{name}.png").convert("RGBA")
        sheet.paste(tile, (index * 16, 0), tile)
    sheet.save(ASSET_SPRITES / "tileset.png")

    tones = {
        "jump": 520,
        "stomp": 180,
        "pickup": 880,
        "bump": 240,
        "break": 140,
        "goal": 660,
    }
    for name, frequency in tones.items():
        write_beep(ASSET_AUDIO / f"{name}.wav", frequency, 0.22 if name != "goal" else 0.6)
    write_beep(ASSET_AUDIO / "music_loop.wav", 330, 1.2)
    print("PLACEHOLDERS ready", flush=True)


def corner_color(image: Image.Image) -> tuple[int, int, int]:
    pixels = image.load()
    width, height = image.size
    samples = [
        pixels[0, 0],
        pixels[width - 1, 0],
        pixels[0, height - 1],
        pixels[max(0, width - 1), max(0, height - 1)],
    ]
    return (
        sum(sample[0] for sample in samples) // 4,
        sum(sample[1] for sample in samples) // 4,
        sum(sample[2] for sample in samples) // 4,
    )


def close_color(color: tuple[int, int, int], target: tuple[int, int, int], tolerance: int) -> bool:
    return all(abs(color[channel] - target[channel]) <= tolerance for channel in range(3))


def knock_out_background(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    background = corner_color(image)
    magenta = (255, 0, 255)
    seen: set[tuple[int, int]] = set()
    stack = [(x, 0) for x in range(width)] + [(x, height - 1) for x in range(width)]
    stack += [(0, y) for y in range(height)] + [(width - 1, y) for y in range(height)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or x < 0 or y < 0 or x >= width or y >= height:
            continue
        seen.add((x, y))
        red, green, blue, alpha = pixels[x, y]
        if alpha < 16 or close_color((red, green, blue), background, 48) or close_color((red, green, blue), magenta, 70):
            pixels[x, y] = (red, green, blue, 0)
            stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return image


def quantize_rgba(image: Image.Image, colors: int) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    reduced = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    reduced.putalpha(alpha)
    return reduced


def fit_sprite(image: Image.Image, size: tuple[int, int], mode: str) -> Image.Image:
    image = image.convert("RGBA")
    if mode != "fill":
        image = knock_out_background(image)
    alpha_box = image.getchannel("A").getbbox() if mode != "fill" else image.getbbox()
    if alpha_box:
        image = image.crop(alpha_box)
    if mode == "plank":
        plank = image.resize((size[0], max(4, size[1] // 3)), Image.Resampling.BOX)
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        canvas.paste(plank, (0, 1), plank)
        return quantize_rgba(canvas, 12)
    resized = image.resize(size, Image.Resampling.BOX)
    if mode == "fill":
        opaque = Image.new("RGBA", size, (0, 0, 0, 255))
        opaque.alpha_composite(resized)
        return quantize_rgba(opaque, 14)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    if mode == "feet":
        x = (size[0] - resized.width) // 2
        y = size[1] - resized.height
    else:
        x = (size[0] - resized.width) // 2
        y = (size[1] - resized.height) // 2
    canvas.paste(resized, (x, y), resized)
    return quantize_rgba(canvas, 12)


def looks_blank(image: Image.Image) -> bool:
    alpha = image.getchannel("A")
    if alpha.getbbox() is None:
        return True
    return alpha.getextrema()[1] == 0


def save_png_atomic(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".part.png")
    image.save(temporary, "PNG")
    temporary.replace(path)


def generate_image(base: str, key: str, model_id: str, params: dict, name: str) -> str:
    url = f"{base}/images"
    body = image_body(model_id, params, PROMPTS[name])
    payload, _content_type = request_json(url, key, body, timeout=180)
    data = payload.get("data") or []
    if not data or "b64_json" not in data[0]:
        raise RuntimeError(f"{name} image response had no b64_json")
    raw = base64.b64decode(data[0]["b64_json"])
    source = Image.open(io.BytesIO(raw))
    source.load()
    mode, size = SPRITE_SPECS[name]
    fitted = fit_sprite(source, size, mode)
    if looks_blank(fitted):
        raise RuntimeError(f"{name} image was blank after processing")
    save_png_atomic(fitted, OUT_SPRITES / f"{name}.png")
    return name


def compose_tileset() -> None:
    sheet = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    for index, name in enumerate(("tile_ground", "tile_fill", "tile_slab", "tile_one_way")):
        tile = Image.open(OUT_SPRITES / f"{name}.png").convert("RGBA").resize((16, 16), Image.Resampling.NEAREST)
        sheet.paste(tile, (index * 16, 0), tile)
    save_png_atomic(sheet, OUT_SPRITES / "tileset.png")


def find_model(base: str, key: str, model_id: str) -> bool:
    try:
        payload, _content_type = request_json(f"{base}/models/{model_id}", key, None, timeout=60)
    except RuntimeError:
        return False
    return bool(payload.get("id") or payload.get("data"))


def list_models(base: str, key: str, query: str) -> list[str]:
    payload, _content_type = request_json(f"{base}/models?{query}", key, None, timeout=60)
    data = payload.get("data") or []
    return [str(item.get("id")) for item in data if item.get("id")]


def decode_audio_chunks(chunks: list[str]) -> bytes:
    parts: list[bytes] = []
    for chunk in chunks:
        cleaned = "".join(chunk.split())
        if cleaned:
            parts.append(base64.b64decode(cleaned))
    data = b"".join(parts)
    if data.startswith(b"ID3") or (len(data) > 2 and data[0] == 0xFF):
        return data
    joined = "".join("".join(chunk.split()) for chunk in chunks)
    return base64.b64decode(joined) if joined else b""


def audio_from_json(payload: dict) -> bytes:
    chunks: list[str] = []

    def visit(node: object) -> None:
        if isinstance(node, dict):
            audio = node.get("audio")
            if isinstance(audio, dict) and isinstance(audio.get("data"), str):
                chunks.append(audio["data"])
            for value in node.values():
                visit(value)
        elif isinstance(node, list):
            for value in node:
                visit(value)

    visit(payload)
    return decode_audio_chunks(chunks)


def audio_from_sse(raw: bytes) -> bytes:
    chunks: list[str] = []
    for line in raw.splitlines():
        if not line.startswith(b"data:"):
            continue
        payload = line[5:].strip()
        if payload == b"[DONE]" or not payload:
            continue
        try:
            obj = json.loads(payload)
        except json.JSONDecodeError:
            continue
        found = audio_from_json(obj)
        if found:
            chunks.append(base64.b64encode(found).decode("ascii"))
    if not chunks:
        return b""
    return decode_audio_chunks(chunks)


def ffmpeg_to_wav(source: Path, dest: Path, duration: float | None, stereo: bool) -> None:
    command = ["ffmpeg", "-y", "-i", str(source)]
    if duration is not None:
        command.extend(["-t", f"{duration:.2f}"])
    command.extend(
        [
            "-ac",
            "2" if stereo else "1",
            "-ar",
            "44100" if stereo else "22050",
            "-c:a",
            "pcm_s16le",
            str(dest),
        ]
    )
    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode != 0:
        tail = (completed.stderr or "")[-400:]
        raise RuntimeError(f"ffmpeg failed: {tail}")


def generate_music(base: str, key: str, model_id: str) -> None:
    url = f"{base}/chat/completions"
    attempts = [
        {
            "model": model_id,
            "messages": [{"role": "user", "content": MUSIC_PROMPT}],
            "modalities": ["text", "audio"],
            "audio": {"format": "mp3"},
            "stream": True,
        },
        {
            "model": model_id,
            "messages": [{"role": "user", "content": MUSIC_PROMPT}],
            "modalities": ["text", "audio"],
            "stream": True,
        },
    ]
    last_error = "no attempt"
    for body in attempts:
        try:
            raw, content_type = request_bytes(url, key, body, timeout=240)
        except RuntimeError as exc:
            last_error = str(exc)
            continue
        if "application/json" in content_type or raw[:1] in (b"{", b"["):
            try:
                audio = audio_from_json(json.loads(raw.decode("utf-8", "replace")))
            except json.JSONDecodeError:
                audio = b""
        else:
            audio = audio_from_sse(raw)
            if not audio and raw[:3] == b"ID3":
                audio = raw
        if len(audio) > 10000:
            temp = OUT_AUDIO / "music_loop.mp3"
            temp.write_bytes(audio)
            ffmpeg_to_wav(temp, OUT_AUDIO / "music_loop.wav", None, True)
            return
        last_error = f"music response was {len(audio)} bytes, type {content_type}"
    raise RuntimeError(last_error)


def generate_sfx(base: str, key: str, model_id: str, name: str) -> str:
    url = f"{base}/audio/speech"
    body = {"model": model_id, "input": SFX_PROMPTS[name], "response_format": "mp3"}
    raw, content_type = request_bytes(url, key, body, timeout=180)
    if "json" in content_type or raw[:1] == b"{":
        raise RuntimeError(redact(raw.decode("utf-8", "replace")[:500], key))
    if len(raw) < 400:
        raise RuntimeError(f"{name} audio was only {len(raw)} bytes")
    temp = OUT_AUDIO / f"{name}.mp3"
    temp.write_bytes(raw)
    limit = 1.4 if name == "goal" else 0.7
    ffmpeg_to_wav(temp, OUT_AUDIO / f"{name}.wav", limit, False)
    return name


def generate_all(secret: str, base: str, key: str) -> dict:
    manifest: dict = {"images": {}, "audio": {}, "failures": []}
    image_payload, _content_type = request_json(f"{base}/images/models", key, None, timeout=60)
    image_models = image_payload.get("data") or []
    summary = []
    for model in image_models[:12]:
        params = model.get("supported_parameters") or {}
        summary.append(
            {
                "id": model.get("id"),
                "background": param_values(params, "background"),
                "output_format": param_values(params, "output_format"),
                "resolution": param_values(params, "resolution"),
            }
        )
    log("IMAGE_MODELS " + json.dumps(summary), secret)
    model_id, params = choose_image_model(image_models)
    manifest["image_model"] = model_id
    log(f"IMAGE_MODEL {model_id} params={sorted(params.keys())}", secret)

    OUT_SPRITES.mkdir(parents=True, exist_ok=True)
    OUT_AUDIO.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {
            pool.submit(generate_image, base, key, model_id, params, name): name for name in PROMPTS
        }
        for future in as_completed(futures):
            name = futures[future]
            try:
                future.result()
                manifest["images"][name] = "generated"
                log(f"IMAGE ok {name}", secret)
            except Exception as exc:  # noqa: BLE001 - record each failed asset
                manifest["images"][name] = "failed"
                manifest["failures"].append({"item": name, "error": redact(str(exc), secret)[:500]})
                log(f"IMAGE fail {name}: {exc}", secret)
    try:
        compose_tileset()
        manifest["images"]["tileset"] = "generated"
        log("IMAGE ok tileset", secret)
    except Exception as exc:  # noqa: BLE001
        manifest["images"]["tileset"] = "failed"
        manifest["failures"].append({"item": "tileset", "error": redact(str(exc), secret)[:500]})
        log(f"IMAGE fail tileset: {exc}", secret)

    music_id = "google/lyria-3-clip-preview"
    if not find_model(base, key, music_id):
        audio_ids = list_models(base, key, "output_modalities=audio")
        log("AUDIO_MODELS " + ", ".join(audio_ids[:20]), secret)
        lyria = [model for model in audio_ids if "lyria" in model]
        music_id = lyria[0] if lyria else ""
    manifest["music_model"] = music_id
    if music_id:
        try:
            generate_music(base, key, music_id)
            manifest["audio"]["music_loop"] = "generated"
            log(f"AUDIO ok music_loop via {music_id}", secret)
        except Exception as exc:  # noqa: BLE001
            manifest["audio"]["music_loop"] = "failed"
            manifest["failures"].append({"item": "music_loop", "error": redact(str(exc), secret)[:500]})
            log(f"AUDIO fail music_loop: {exc}", secret)
    else:
        manifest["audio"]["music_loop"] = "failed"
        manifest["failures"].append({"item": "music_loop", "error": "No Lyria music model in the API list"})
        log("AUDIO fail music_loop: model missing", secret)

    sfx_id = "bytedance-seed/seed-audio-1-0"
    speech_ids = list_models(base, key, "output_modalities=speech")
    log("SPEECH_MODELS " + ", ".join(speech_ids[:30]), secret)
    if sfx_id not in speech_ids:
        seeded = [model for model in speech_ids if "seed-audio" in model]
        sfx_id = seeded[0] if seeded else ""
    manifest["sfx_model"] = sfx_id
    if sfx_id:
        for name in SFX_PROMPTS:
            try:
                generate_sfx(base, key, sfx_id, name)
                manifest["audio"][name] = "generated"
                log(f"AUDIO ok {name} via {sfx_id}", secret)
            except Exception as exc:  # noqa: BLE001
                manifest["audio"][name] = "failed"
                manifest["failures"].append({"item": name, "error": redact(str(exc), secret)[:500]})
                log(f"AUDIO fail {name}: {exc}", secret)
    else:
        for name in SFX_PROMPTS:
            manifest["audio"][name] = "failed"
            manifest["failures"].append({"item": name, "error": "Seed Audio non-speech model was not listed"})
        log("AUDIO fail sfx: seed-audio model missing", secret)

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    log("GENERATE done", secret)
    return manifest


def install_generated() -> list[str]:
    installed: list[str] = []
    for folder, dest_root in ((OUT_SPRITES, ASSET_SPRITES), (OUT_AUDIO, ASSET_AUDIO)):
        if not folder.exists():
            continue
        for path in folder.iterdir():
            if path.suffix.lower() not in {".png", ".wav"}:
                continue
            target = dest_root / path.name
            target.write_bytes(path.read_bytes())
            installed.append(str(target.relative_to(ROOT)))
    return installed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--placeholders", action="store_true")
    parser.add_argument("--generate", action="store_true")
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    if not (args.placeholders or args.generate or args.install):
        args.placeholders = True
        args.generate = True
    if args.placeholders:
        write_placeholders()
    if args.generate:
        env = load_env(ENV_PATH)
        key = env.get("OPENROUTER_API_KEY", "")
        base = env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
        if not key:
            log("GENERATE skipped: OPENROUTER_API_KEY missing")
            return
        LOG_PATH.write_text("", encoding="utf-8")
        generate_all(key, base, key)
    if args.install:
        installed = install_generated()
        log("INSTALLED " + ", ".join(installed))


if __name__ == "__main__":
    main()
