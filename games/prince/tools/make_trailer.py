"""Cut the Prince of Versions trailer from a Movie Maker capture of the bot.

A fast run of highlights on the beat of one original cue (oud, santur, ney,
frame drums): the title screen, then a card at a time ("A dagger that turns
back time." ...) between the moments that teach: a commit and Git's reply, a
death with a torch uncommitted and the sands running back, the Vizier's
sabotage commit, a reset past HEAD, a revert, the palace guard refusing
`main`, branches on the sand trail, and the merge conflict held through the
cue's dead stop, then a montage of rewinds and an end card with the URL.
Shots are laid out in the game's native 480x270 units but composed at
1920x1080 (`S` times that), so text is sharp: the game draws its text at
window resolution and is captured at 1920x1080 (`trailer/capture.sh`), and
the trailer's own cards are drawn at full size too. The pixel art stays on
whole-number nearest-neighbor scales. The mixing and encoding helpers come
from the Dunder Quest trailer (../../dunder-quest/tools/make_trailer.py).

The cue (`trailer/audio/cue_prince.wav`, from tools/trailer_audio.py) was
measured at 120 BPM: beats at 0.055 s + k/2, bars of four from there. It
drops out at bar 16 (32 s) with a hit on the next beat and a reversed swell
back in at bar 18, and its last hit is bar 30 (60 s). It plays from the
first frame; every cut lands on a beat or a bar, and the game's own sound
sits under it.

Shots find their capture frames by name in the run's MARK log
(`trailer/captures/run.log`), so a fresh capture needs no renumbering.
Needs ffmpeg on the PATH.

    bash trailer/capture.sh                 # -> trailer/captures/run/ + run.log, at 1920x1080
    python tools/make_trailer.py            # -> trailer/out/prince_trailer_{1080p,4k}.mp4 + prince_thumbnail.png
    python tools/make_trailer.py --stills   # one frame per shot, for checking the cut
    python tools/make_trailer.py --at 3 12.5   # frames at those trailer times
    python tools/make_trailer.py --thumb    # just the thumbnail (also copied to the site)
"""

from __future__ import annotations

import math
import re
import shutil
import subprocess
import sys
import wave
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Callable

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent.parent
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import make_trailer as dq  # noqa: E402
from make_trailer import flash, font  # noqa: E402

## `--capture NAME` cuts from trailer/captures/NAME/ and NAME.log instead of run.
_NAME = sys.argv[sys.argv.index("--capture") + 1] if "--capture" in sys.argv else "run"
CAPTURE = ROOT / "trailer" / "captures" / _NAME
LOG = ROOT / "trailer" / "captures" / f"{_NAME}.log"
AUDIO = ROOT / "trailer" / "audio"
OUT = ROOT / "trailer" / "out"
SITE_THUMB = REPO / "site" / "static" / "img" / "prince" / "trailer.png"
PIXEL = ROOT / "assets" / "fonts" / "PixelifySans.ttf"
MONO = ROOT / "assets" / "fonts" / "VT323.ttf"
GAME_AUDIO = ROOT / "assets" / "audio"

## Layout units are the game's native pixels; frames are S times that.
W, H = dq.W, dq.H
S = 4
CW, CH = W * S, H * S
FPS = dq.FPS
RATE = dq.RATE

# The game's palette (core/palette.gd), as 8-bit RGB.
INK = (18, 13, 26)
NIGHT = (23, 28, 51)
STONE = (84, 92, 128)
PAPER = (245, 235, 204)
SAND = (232, 186, 74)
SAND_PALE = (245, 227, 161)
TEAL = (110, 200, 204)
CRIMSON = (209, 51, 61)
VIOLET = (180, 139, 224)
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)

# --- The cue -----------------------------------------------------------------

CUE = "cue_prince"
BEAT = 0.5
## The cue's first beat, in cue time; the cue starts at trailer time 0.
CUE_BAR0 = 0.055
## Its last hit (bar 30), and where its tail has rung out.
LAST_HIT = CUE_BAR0 + 30 * 4 * BEAT
CUE_END = 63.5


def bar(n: float) -> float:
    return CUE_BAR0 + n * 4 * BEAT


def beat(k: float) -> float:
    return CUE_BAR0 + k * BEAT


# --- The capture's MARK log ---------------------------------------------------

@lru_cache(maxsize=None)
def marks() -> list[tuple[int, str]]:
    out = []
    for line in LOG.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"MARK (\d+) (.*)$", line)
        if m:
            out.append((int(m.group(1)), m.group(2)))
    return out


def mark(text: str, nth: int = 0) -> int:
    """The frame of the `nth` MARK starting with `text`."""
    found = [f for f, s in marks() if s.startswith(text)]
    if len(found) <= nth:
        sys.exit(f"no MARK '{text}' #{nth}")
    return found[nth]


# --- Sharp drawing, in native units --------------------------------------------

def width(s: str, path: Path, size: int) -> float:
    return font(path, size * S).getlength(s) / S


def text(img: Image.Image, xy: tuple[float, float], s: str, path: Path, size: int, color,
         anchor: str = "lt", outline=None, thick: int = 1, shadow=None, shadow_dy: int = 0) -> None:
    """`s` antialiased at full resolution; `xy`, `size`, `thick` and
    `shadow_dy` are in native pixels. `anchor` is 'lt' or 'mt'."""
    fnt = font(path, size * S)
    x, y = xy[0] * S, xy[1] * S
    pil_anchor = {"lt": "la", "mt": "ma"}[anchor]
    d = ImageDraw.Draw(img)
    stroke = thick * S if outline is not None else 0
    if shadow is not None and shadow_dy:
        d.text((x, y + shadow_dy * S), s, font=fnt, fill=shadow, anchor=pil_anchor, stroke_width=stroke, stroke_fill=shadow)
    d.text((x, y), s, font=fnt, fill=color, anchor=pil_anchor, stroke_width=stroke, stroke_fill=outline)


def rect(img: Image.Image, box: tuple[float, float, float, float], fill=None, border=None) -> None:
    x0, y0, x1, y1 = (round(v * S) for v in box)
    d = ImageDraw.Draw(img)
    if fill is not None:
        d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=fill)
    if border is not None:
        d.rectangle((x0, y0, x1 - 1, y1 - 1), outline=border, width=S)


# --- Overlays -----------------------------------------------------------------

def flash_fx(at: float, frames: int = 4, peak: float = 0.8, color=(255, 240, 200)):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) * FPS
        return flash(img, peak * (1 - k / frames), color) if 0 <= k < frames else img
    return fx


def shake_fx(at: float, amount: float = 3.0, length: float = 0.3):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = t - at
        if not 0 <= k < length:
            return img
        a = amount * (1 - k / length)
        if a < 0.5:
            return img
        dx = int(round(math.sin(t * 91.0) * a * S))
        dy = int(round(math.cos(t * 77.0) * a * S))
        out = Image.new("RGB", img.size, BLACK)
        out.paste(img, (dx, dy))
        return out
    return fx


def sand_wipe(at: float, length: float = 0.35):
    """A band of sand sweeping right to left across the cut, like the rewind."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) / length
        if not 0 <= k < 1:
            return img
        out = img.copy()
        d = ImageDraw.Draw(out)
        x = (1 - k) * (W + 80) - 40
        for i in range(60):
            gx = x + (i * 37 % 80) - 40
            gy = (i * 53) % H
            d.rectangle(((gx) * S, gy * S, (gx + 2) * S, (gy + 1) * S), fill=SAND_PALE if i % 3 else SAND)
        return out
    return fx


def zoomed(img: Image.Image, zoom: int, focus: tuple[int, int]) -> Image.Image:
    """Whole-number punch-in around `focus` (native pixels)."""
    if zoom == 1:
        return img
    cw, ch = W // zoom, H // zoom
    x = min(max(focus[0] - cw // 2, 0), W - cw)
    y = min(max(focus[1] - ch // 2, 0), H - ch)
    return img.crop((x * S, y * S, (x + cw) * S, (y + ch) * S)).resize((CW, CH), Image.NEAREST)


# --- Cards ----------------------------------------------------------------------

def black(_t: float) -> Image.Image:
    return Image.new("RGB", (CW, CH), INK)


def card(lines: list[str], size: int = 24, color=SAND):
    """A night card of Pixelify lines, centered, the first in sand."""
    def draw(t: float) -> Image.Image:
        img = black(t)
        step = int(size * 1.5)
        y = (H - step * len(lines)) // 2 + 2
        for k, s in enumerate(lines):
            text(img, (W / 2, y), s, PIXEL, size, color if k == 0 else PAPER, anchor="mt", shadow=BLACK, shadow_dy=2)
            y += step
        return img
    return draw


@lru_cache(maxsize=1)
def end_backdrop() -> Image.Image:
    art = Image.open(ROOT / "assets" / "backgrounds" / "title.png").convert("RGB").resize((CW, CH), Image.NEAREST)
    shade = Image.new("RGB", art.size, INK)
    mask = Image.linear_gradient("L").rotate(90).resize(art.size)  # dark on the left
    return Image.composite(art, shade, mask.point(lambda v: int(v * 0.75)))


def end_card(at: float):
    def draw(t: float) -> Image.Image:
        img = end_backdrop().copy()
        local = t - at
        text(img, (34, 48), "Prince of", PIXEL, 26, SAND_PALE, shadow=BLACK, shadow_dy=2)
        text(img, (34, 74), "Versions", PIXEL, 44, SAND, shadow=BLACK, shadow_dy=3)
        if local >= 0.8:
            text(img, (36, 130), "Learn Git. Turn back the sands.", MONO, 20, PAPER, shadow=BLACK, shadow_dy=1)
        if local >= 1.6:
            text(img, (36, 166), "Play free in your browser", PIXEL, 11, PAPER)
            text(img, (36, 180), "dunderquest.com/prince", MONO, 28, SAND, shadow=BLACK, shadow_dy=1)
        if local >= 2.4:
            text(img, (36, 226), "a __dunder_quest__ game", MONO, 18, TEAL)
        return img
    return draw


# --- Gameplay source ------------------------------------------------------------

@lru_cache(maxsize=48)
def capture(frame: int) -> Image.Image:
    path = CAPTURE / f"f{frame:08d}.png"
    if not path.exists():
        return Image.new("RGB", (CW, CH), INK)
    img = Image.open(path).convert("RGB")
    return img if img.size == (CW, CH) else img.resize((CW, CH), Image.NEAREST)


@dataclass
class Shot:
    """`start`..`end` in trailer seconds. `src` is the capture frame shown at
    `start`; `draw` paints a card instead. `fx` paint on top, in order."""
    start: float
    end: float
    src: int | None = None
    speed: float = 1.0
    zoom: int = 1
    focus: tuple[int, int] = (240, 135)
    draw: Callable[[float], Image.Image] | None = None
    fx: list[Callable[[Image.Image, float], Image.Image]] = field(default_factory=list)
    audio: float = 1.0
    label: str = ""

    def frame_at(self, t: float) -> int:
        return int(self.src + round((t - self.start) * FPS * self.speed))


## How long the last hit's sting and the end card run.
END_HOLD = 6.0
## The console comes up this many frames before a command runs (press_frames).
PRESS = 40


def cmd(text_: str, nth: int = 0) -> int:
    """The frame the dagger ran this git command (see trailer_run.gd)."""
    found = [f for f, s in marks() if s.startswith("git ") and s.split(" ", 3)[3] == text_]
    if len(found) <= nth:
        sys.exit(f"no git command '{text_}' #{nth}")
    return found[nth]


def edit() -> list[Shot]:
    shots: list[Shot] = []

    def add(start: float, end: float, **kw) -> Shot:
        shot = Shot(start, end, **kw)
        shots.append(shot)
        return shot

    # The title screen on the cue's first hit.
    add(0.0, bar(1.5), src=mark("title") + 6, label="title", audio=0.0)
    add(bar(1.5), bar(2.5), draw=card(["A dagger that", "turns back time."]), label="card dagger")

    # Room 1: a torch, a commit and Git's reply.
    play1 = mark("state 1 play")
    commit1 = cmd('commit -am "Light the first torch"')
    add(bar(2.5), bar(4.5), src=play1, label="torch and commit",
        fx=[flash_fx(bar(2.5) + (commit1 - play1) / FPS, 4, 0.5)])
    add(bar(4.5), bar(5.5), draw=card(["But only to a", "moment you sealed."]), label="card sealed")
    # The second torch, uncommitted, the spikes, and the sands running back.
    dead = mark("state 1 dead")
    add(bar(5.5), bar(6.5), src=dead - 75, label="death", fx=[shake_fx(bar(5.5) + 75 / FPS, 3, 0.3)])
    reset1 = cmd("reset --hard HEAD")
    add(bar(6.5), bar(7.5), src=reset1 - 50, label="rewind 1")
    add(bar(7.5), bar(8.5), draw=card(["A seal is a", "git commit."]), label="card seal")

    # The Vizier commits too: his speech, then his commit on top of yours.
    add(bar(8.5), bar(9.5), draw=card(["The Vizier", "commits too."], color=VIOLET), label="card vizier")
    sabotage = cmd('commit -am "Arm the spikes and bar the door"')
    add(bar(9.5), bar(11.5), src=sabotage - 150, label="vizier", fx=[flash_fx(bar(9.5) + 150 / FPS, 4, 0.6, VIOLET)])
    past_head = next(f for f, s in marks() if s.startswith("git 2 0 reset --hard ") and not s.endswith(" HEAD"))
    add(bar(11.5), bar(12.5), src=past_head - PRESS, label="reset past HEAD")
    # Room 3's revert, room 4's guard and branches.
    add(bar(12.5), bar(13.5), src=mark("git 3 0 revert") - PRESS, label="revert")
    add(bar(13.5), bar(14.5), src=mark("git 4 1 commit") - PRESS + 10, label="guard")
    add(bar(14.5), bar(15), src=cmd("switch -c left") - 6, label="branch left")
    add(bar(15), bar(15.5), src=cmd("switch -c right") - 6, label="branch right")
    add(bar(15.5), bar(16), src=cmd("merge left") + 6, label="merge left")

    # Bar 16: the cue stops dead, and so does the merge.
    conflict = mark("conflict 5")
    add(bar(16), beat(65), src=conflict - PRESS + 10, label="merge winch")
    add(beat(65), bar(16.75), src=conflict, label="conflict", fx=[flash_fx(beat(65), 5, 0.8, (255, 120, 110)), shake_fx(beat(65), 4, 0.4)])
    add(bar(16.75), bar(18), src=conflict + 45, speed=0.0, label="conflict held", audio=0.0, zoom=1)
    add(bar(18), bar(19), draw=card(["Real Git.", "Real commit ids."]), label="card real")
    add(bar(19), bar(20), src=cmd("add gate", 1) - PRESS + 10, label="resolve")
    # The Vizier stopped, the door, the lesson.
    viz5 = mark("state 5 cutscene")
    add(bar(20), bar(22), src=viz5 + 20, label="vizier flees")
    clear5 = mark("state 5 clear")
    add(bar(22), bar(23), src=clear5 - 70, label="the door")
    add(bar(23), bar(25), src=clear5 + 40, label="lesson 5")

    # Turn back the sands: a montage of rewinds, one a beat.
    rewinds = [f for f, s in marks() if s.startswith("state ") and s.endswith(" rewind")]
    picks = [rewinds[k] for k in (1, 3, 5, 7, 2, 9, 4, 10)]
    for k, f in enumerate(picks):
        at = bar(25) + k * BEAT
        add(at, at + BEAT, src=f + 2, label=f"rewind {k}", fx=[sand_wipe(at, 0.3)])
    add(bar(27), bar(28), draw=card(["Five rooms.", "Your first commit to", "your first merge conflict."], size=20), label="card five")
    # Back to the title, timed so the cue's last hit lands on the end card.
    add(bar(28), LAST_HIT, src=mark("title") + 30, speed=0.5, audio=0.0, label="title again")
    add(LAST_HIT, LAST_HIT + END_HOLD, draw=end_card(LAST_HIT), label="end card", fx=[flash_fx(LAST_HIT, 5, 0.7)])
    return shots


def chapters() -> list[tuple[float, str]]:
    """YouTube chapters (each at least 10 s long), for the video description."""
    return [(0.0, "The dagger turns back time"), (bar(8.5), "The Vizier commits too"),
            (bar(16), "The merge conflict"), (bar(24), "Five rooms of real Git")]


def cues() -> list[tuple[str, float, float]]:
    """(sound, trailer time, gain): this trailer's own effects."""
    out = [("slash", bar(1.5) - 0.05, 0.5),
           ("rewind", bar(6.5) + 50 / FPS - 0.05, 0.8),
           ("boom", beat(65) - 0.02, 0.8),
           ("rewind", bar(25) - 0.1, 0.6),
           ("sting", LAST_HIT, 0.9)]
    return out


# --- Rendering and sound --------------------------------------------------------

def render_frame(shots: list[Shot], t: float) -> Image.Image:
    shot = next((s for s in shots if s.start <= t < s.end), shots[-1])
    if shot.draw is not None:
        img = shot.draw(t)
    else:
        img = zoomed(capture(shot.frame_at(t)), shot.zoom, shot.focus).copy()
    for fx in shot.fx:
        img = fx(img, t)
    return img


def write_video(shots: list[Shot], total_s: float, path: Path) -> None:
    command = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{CW}x{CH}", "-r", str(FPS), "-i", "-", "-c:v", "ffv1", "-pix_fmt", "bgr0", str(path)]
    proc = subprocess.Popen(command, stdin=subprocess.PIPE)
    total = int(round(total_s * FPS))
    for n in range(total):
        proc.stdin.write(render_frame(shots, n / FPS).tobytes())
        if n % 600 == 0:
            print(f"frame {n}/{total}", flush=True)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed while writing the native video")


def mix_audio(shots: list[Shot], total_s: float, path: Path) -> None:
    n = int(total_s * RATE)
    music = np.zeros((n, 2), np.float32)
    score = dq.load_wav(AUDIO / f"{CUE}.wav")[:int(CUE_END * RATE)].copy()
    tail = int(1.5 * RATE)
    score[-tail:] *= np.linspace(1, 0, tail)[:, None]
    dq.place(music, score, 0.0, 1.0)
    game = np.zeros((n, 2), np.float32)
    source = dq.load_wav(CAPTURE / "f.wav")
    fade = int(0.01 * RATE)
    for shot in shots:
        if shot.src is None or shot.audio <= 0 or shot.speed != 1.0:
            continue
        a = int(shot.src / FPS * RATE)
        clip = source[a:a + int((shot.end - shot.start) * RATE)].copy()
        if len(clip) > 2 * fade:
            ramp = np.linspace(0, 1, fade)[:, None]
            clip[:fade] *= ramp
            clip[-fade:] *= ramp[::-1]
        dq.place(game, clip, shot.start, shot.audio * 0.7)
    sfx = np.zeros((n, 2), np.float32)
    for name, at, gain in cues():
        dq.place(sfx, dq.load_wav(AUDIO / f"{name}.wav"), at, gain)
    hits = np.abs(game * 2.5 + sfx).max(axis=1)
    env = np.convolve(hits, np.ones(2400) / 2400, mode="same")
    duck = 1.0 - np.clip(env * 2.0, 0.0, 0.35)
    game = 0.6 * np.tanh(game * 2.5 / 0.6)
    mix = music * 0.7 * duck[:, None] + game + sfx * 0.8
    end = int(1.0 * RATE)
    mix[-end:] *= np.linspace(1, 0, end)[:, None]
    peak = np.abs(mix).max()
    if peak > 0.98:
        mix *= 0.98 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())


def encode(native: Path, audio: Path, scale: int, out: Path, crf: int) -> None:
    """Whole-number nearest-neighbor upscale of the 1920x1080 master to H.264
    + AAC, YouTube/Steam friendly."""
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(native), "-i", str(audio),
               "-vf", f"scale={CW * scale}:{CH * scale}:flags=neighbor",
               "-c:v", "libx264", "-preset", "slow", "-crf", str(crf), "-pix_fmt", "yuv420p",
               "-tune", "animation", "-r", str(FPS), "-c:a", "aac", "-b:a", "320k", "-ar", str(RATE),
               "-shortest", "-movflags", "+faststart", str(out)]
    subprocess.run(command, check=True)
    print(f"WROTE {out.relative_to(ROOT.parent)}", flush=True)


def thumbnail(path: Path) -> None:
    """A 1920x1080 YouTube thumbnail: the Prince raising the dagger, the
    Vizier opposite, under the name, with the command that turns back time."""
    scene = Image.open(ROOT / "assets" / "backgrounds" / "hall.png").convert("RGB").resize((CW, CH), Image.NEAREST)
    img = Image.blend(scene, Image.new("RGB", (CW, CH), INK), 0.5)
    sprites = ROOT / "assets" / "sprites"
    # Both sheets are painted at two texels to a room pixel (tools/paint.py):
    # the Prince's dagger frame is the 18th 64x64 cell, the Vizier's arms-up
    # frame the second 48x80 one.
    prince = Image.open(sprites / "prince.png").convert("RGBA").crop((17 * 64, 0, 18 * 64, 64))
    vizier = Image.open(sprites / "vizier.png").convert("RGBA").crop((48, 0, 96, 80))
    prince = prince.resize((64 * 3 * S, 64 * 3 * S), Image.NEAREST)
    vizier = vizier.resize((48 * 5 * S // 2, 80 * 5 * S // 2), Image.NEAREST)
    img.paste(prince, (-18 * S, 76 * S), prince)
    img.paste(vizier, (346 * S, 70 * S), vizier)
    rect(img, (0, 0, W, 58), fill=INK)
    rect(img, (0, 58, W, 60), fill=SAND)
    text(img, (W / 2, 8), "Prince of Versions", PIXEL, 34, SAND, anchor="mt", shadow=BLACK, shadow_dy=2)
    text(img, (W / 2, 100), "LEARN", PIXEL, 26, PAPER, outline=INK, thick=2, anchor="mt")
    text(img, (W / 2, 128), "GIT", PIXEL, 58, SAND, outline=INK, thick=2, shadow=BLACK, shadow_dy=3, anchor="mt")
    msg = "$ git reset --hard HEAD~1"
    tw = width(msg, MONO, 24)
    rect(img, ((W - tw) / 2 - 10, 222, (W + tw) / 2 + 10, 252), fill=INK, border=SAND)
    text(img, (W / 2, 225), msg, MONO, 24, SAND_PALE, anchor="mt")
    img.save(path, optimize=True)
    print(f"WROTE {path.relative_to(ROOT.parent)}")
    SITE_THUMB.parent.mkdir(parents=True, exist_ok=True)
    img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(SITE_THUMB, optimize=True)
    print(f"WROTE {SITE_THUMB.relative_to(REPO)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if "--thumb" in sys.argv:
        thumbnail(OUT / "prince_thumbnail.png")
        return
    shots = edit()
    total = shots[-1].end
    print(f"length {total:.2f}s")
    for at, name in chapters():
        print(f"CHAPTER {int(at) // 60}:{int(at) % 60:02d} {name}")
    if "--stills" in sys.argv:
        sheet = Image.new("RGB", (W * 4, H * ((len(shots) + 3) // 4)), "black")
        for k, shot in enumerate(shots):
            mid = min(shot.end - 1 / FPS, shot.start + (shot.end - shot.start) * 0.7)
            img = render_frame(shots, mid)
            text(img, (2, 2), f"{k} {shot.label} {shot.start:.1f}", MONO, 16, (255, 0, 255))
            sheet.paste(img.resize((W, H), Image.LANCZOS), ((k % 4) * W, (k // 4) * H))
        sheet.save(OUT / "stills.png")
        print(f"WROTE {(OUT / 'stills.png').relative_to(ROOT.parent)}")
        for shot in shots:
            print(f"{shot.start:6.2f}-{shot.end:6.2f} {shot.label} src={shot.src}")
        return
    if "--at" in sys.argv:
        times = [float(a) for a in sys.argv[sys.argv.index("--at") + 1:]]
        tw, th = (CW, CH) if len(times) == 1 else (CW // 2, CH // 2)
        sheet = Image.new("RGB", (tw * 2 if len(times) > 1 else tw, th * ((len(times) + 1) // 2)), "black")
        for k, t in enumerate(times):
            sheet.paste(render_frame(shots, t).resize((tw, th), Image.LANCZOS), ((k % 2) * tw, (k // 2) * th))
        sheet.save(OUT / "at.png")
        print(f"WROTE {(OUT / 'at.png').relative_to(ROOT.parent)}")
        return
    native = OUT / "native.mkv"
    if "--audio-only" not in sys.argv or not native.exists():
        write_video(shots, total, native)
    mix_audio(shots, total, OUT / "mix_raw.wav")
    dq.normalize(OUT / "mix_raw.wav", OUT / "mix.wav")
    encode(native, OUT / "mix.wav", 1, OUT / "prince_trailer_1080p.mp4", 12)
    if "--no-4k" not in sys.argv:
        encode(native, OUT / "mix.wav", 2, OUT / "prince_trailer_4k.mp4", 16)
    thumbnail(OUT / "prince_thumbnail.png")


if __name__ == "__main__":
    main()
