"""Cut one trailer for Prince of Versions and Just One More JOIN together.

It's for a single social post about both games (LinkedIn takes one video a
post). Nothing is captured or composed again: it cuts the two finished 1080p
masters, so each half keeps its own music, and every cut sits on a bar of its
cue (both cues are 120 BPM, a bar every 2 s), then ends on a shared card with
both addresses, under the JOIN cue's last hit and tag.

  Prince bars 0-8.5    the title, the dagger, a commit, the rewind, "A seal is a git commit."
  Prince bars 16-18    `git merge winch`: the conflict on the cue's hit, through the reversed swell
  JOIN   bars 0-19.5   the title, the cold open, a record, a query, Records, the false exit
  JOIN   bar 27 -> end the shared end card on the cue's last hit, with the sting and tag

The masters are git-ignored and live in the main checkout (see AGENTS.md), so
point --masters at it from a worktree. Run from the repo root:

    python site/combo_trailer.py --masters D:/src/dunder-quest --stills   # a frame from each shot
    python site/combo_trailer.py --masters D:/src/dunder-quest            # -> build/combo_trailer/

It writes combo_trailer_1080p.mp4 (H.264 + AAC, 60 fps, -14 LUFS) and the end
card as a PNG. Keep the output with the masters, as AGENTS.md says.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FPS = 60
W, H = 1920, 1080

PRINCE = "games/prince/trailer/out/prince_trailer_1080p.mp4"
JOIN = "games/lieutenant/trailer/out/join_trailer_1080p.mp4"

# The cues' bar grids, as each game's make_trailer.py measures them: Prince's
# cue starts after an 18.42 s cold open and its first beat is 0.055 s in;
# JOIN's first beat is 0.09 s in. A bar is 2 s.
P_BAR0 = 18.42 + 0.055
J_BAR0 = 0.09


def p_bar(n: float) -> float:
    return P_BAR0 + 2 * n


def j_bar(n: float) -> float:
    return J_BAR0 + 2 * n


# (master, start s, end s). The last segment's picture is replaced by the card.
SEGMENTS = [
    (PRINCE, p_bar(0), p_bar(8.5)),
    (PRINCE, p_bar(16), p_bar(18)),
    (JOIN, j_bar(0), j_bar(19.5)),
    (JOIN, j_bar(27), None),  # to the end of the JOIN master
]

FONTS_P = ROOT / "games/prince/assets/fonts"
FONTS_J = ROOT / "games/lieutenant/assets/fonts"
P_CREAM, P_GOLD, P_TEXT = (244, 225, 159), (231, 185, 74), (245, 233, 203)
J_CREAM, J_ORANGE, J_TEXT = (252, 228, 173), (239, 126, 51), (243, 235, 213)
TEAL = (109, 199, 203)
SHADOW = (8, 6, 14)


def run(*args: str) -> str:
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def duration(path: Path) -> float:
    return float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)))


def frame_at(path: Path, t: float, out: Path) -> Image.Image:
    run("ffmpeg", "-v", "error", "-y", "-ss", f"{t:.3f}", "-i", str(path), "-frames:v", "1", str(out))
    return Image.open(out).convert("RGB")


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def fit(path: Path, text: str, size: int, width: int) -> ImageFont.FreeTypeFont:
    f = font(path, size)
    while f.getlength(text) > width and size > 10:
        size -= 2
        f = font(path, size)
    return f


def say(d: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, f, fill, shadow: int = 0) -> None:
    if shadow:
        d.text((xy[0] + shadow, xy[1] + shadow), text, font=f, fill=SHADOW)
    d.text(xy, text, font=f, fill=fill)


def backdrop(path: Path) -> Image.Image:
    """A game's title backdrop (pixel art, no text), scaled up to 1080p."""
    return Image.open(path).convert("RGB").resize((W, H), Image.NEAREST)


def half(bg: Image.Image) -> Image.Image:
    """The right half of a game's title backdrop, darkened toward the left so
    the text over it reads."""
    im = bg.crop((W // 2, 0, W, H))
    shade = Image.new("L", im.size)
    for x in range(im.width):
        a = int(255 * (0.78 - 0.38 * x / im.width))
        shade.paste(a, (x, 0, x + 1, im.height))
    return Image.composite(Image.new("RGB", im.size, SHADOW), im, shade)


def end_card() -> Image.Image:
    card = Image.new("RGB", (W, H), SHADOW)
    card.paste(half(backdrop(ROOT / "games/prince/assets/backgrounds/title.png")), (0, 0))
    card.paste(half(backdrop(ROOT / "games/lieutenant/assets/backgrounds/title.png")), (W // 2, 0))
    d = ImageDraw.Draw(card)
    d.rectangle((W // 2 - 2, 0, W // 2 + 1, 860), fill=(60, 52, 80))
    x0, x1, span = 80, W // 2 + 80, W // 2 - 160

    pix, mono, cap = FONTS_P / "PixelifySans.ttf", FONTS_P / "VT323.ttf", FONTS_J / "Caprasimo.ttf"
    say(d, (x0, 150), "Prince of", fit(pix, "Prince of", 96, span), P_CREAM, 6)
    say(d, (x0, 250), "Versions", fit(pix, "Versions", 170, span), P_GOLD, 8)
    say(d, (x0, 500), "Learn Git.", font(mono, 84), P_TEXT)
    say(d, (x0, 620), "dunderquest.com/prince", fit(mono, "dunderquest.com/prince", 76, span), P_GOLD)

    say(d, (x1, 150), "Just One More", fit(cap, "Just One More", 92, span), J_CREAM, 5)
    say(d, (x1, 250), "JOIN", fit(cap, "JOIN", 180, span), J_ORANGE, 7)
    say(d, (x1, 500), "Learn SQL.", font(mono, 84), J_TEXT)
    say(d, (x1, 620), "dunderquest.com/lieutenant", fit(mono, "dunderquest.com/lieutenant", 76, span), J_ORANGE)

    d.rectangle((0, 860, W, H), fill=SHADOW)
    line = "Free in your browser. No signup."
    f = font(pix, 54)
    say(d, ((W - int(f.getlength(line))) // 2, 900), line, f, P_TEXT)
    brand = "a __dunder_quest__ production"
    f = font(mono, 52)
    say(d, ((W - int(f.getlength(brand))) // 2, 985), brand, f, TEAL)
    return card


def loudness(path: Path) -> float:
    err = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--masters", type=Path, default=ROOT, help="the checkout that holds the trailer masters")
    ap.add_argument("--out", type=Path, default=ROOT / "build/combo_trailer")
    ap.add_argument("--stills", action="store_true", help="a contact sheet, one frame per shot, and the card")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp())

    segs = []
    for master, a, b in SEGMENTS:
        path = args.masters / master
        b = duration(path) if b is None else b
        fa, fb = round(a * FPS), round(b * FPS)  # whole frames, so picture and sound cut together
        segs.append((path, fa / FPS, fb / FPS))

    card = end_card()
    card_png = args.out / "combo_end_card.png"
    card.save(card_png)

    total = sum(b - a for _, a, b in segs)
    t = 0.0
    for i, (path, a, b) in enumerate(segs):
        print(f"SHOT {t:6.2f}-{t + b - a:6.2f}  {path.name} {a:.3f}-{b:.3f}")
        t += b - a
    print(f"LENGTH {total:.2f} s")

    if args.stills:
        times = [a + 0.5 for _, a, _ in segs[:-1]] + [b - 0.3 for _, _, b in segs[:-1]]
        shots = [frame_at(p, x, tmp / f"s{k}.png") for k, ((p, _, _), x) in
                 enumerate(zip(segs[:-1] * 2, times))] + [card]
        sheet = Image.new("RGB", (4 * 480, 2 * 270))
        for k, im in enumerate(shots[:8]):
            sheet.paste(im.resize((480, 270)), ((k % 4) * 480, (k // 4) * 270))
        sheet.save(args.out / "stills.png")
        print(f"STILLS {args.out / 'stills.png'}")
        return

    inputs: list[str] = []
    parts = []
    for i, (path, a, b) in enumerate(segs):
        inputs += ["-i", str(path)]
        fade = 0.012  # a few ms either side of every cut, so the sound doesn't click
        parts.append(f"[{i}:a]atrim={a:.6f}:{b:.6f},asetpts=PTS-STARTPTS,"
                     f"afade=t=in:d={fade},afade=t=out:st={b - a - fade:.6f}:d={fade}[a{i}]")
        if i < len(segs) - 1:
            parts.append(f"[{i}:v]trim={a:.6f}:{b:.6f},setpts=PTS-STARTPTS,fps={FPS}[v{i}]")
    n = len(segs)
    last = n - 1
    inputs += ["-loop", "1", "-framerate", str(FPS), "-t", f"{segs[-1][2] - segs[-1][1]:.6f}", "-i", str(card_png)]
    parts.append(f"[{n}:v]format=yuv420p,setsar=1[v{last}]")
    parts.append("".join(f"[v{i}][a{i}]" for i in range(n)) + f"concat=n={n}:v=1:a=1[v][a]")

    raw = args.out / "combo_raw.mp4"
    common = ["-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS),
              "-movflags", "+faststart"]
    run("ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(parts), "-map", "[v]", "-map", "[a]",
        *common, "-c:a", "pcm_s16le", str(raw.with_suffix(".mkv")))

    gain = -14.0 - loudness(raw.with_suffix(".mkv"))
    out = args.out / "combo_trailer_1080p.mp4"
    run("ffmpeg", "-v", "error", "-y", "-i", str(raw.with_suffix(".mkv")), "-c:v", "copy",
        "-af", f"volume={gain:.2f}dB,alimiter=limit=0.89:level=false", "-c:a", "aac", "-b:a", "192k",
        "-ar", "48000", "-movflags", "+faststart", str(out))
    raw.with_suffix(".mkv").unlink()
    print(f"OUT {out} {out.stat().st_size / 1e6:.1f} MB, {loudness(out):.1f} LUFS")
    print(json.dumps({"length": round(total, 2)}))


if __name__ == "__main__":
    main()
