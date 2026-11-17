"""Cut the Just One More JOIN trailer from Movie Maker captures of the bot.

A fast run of highlights on the beat of one original cue (walking bass,
brushes, vibraphone, a wry bassoon): the title screen, then a card at a time
("Every case opens on the murder." ...) between the moments that sell it: a
cold open, the Lieutenant shuffling in with his dog, a record going into the
notebook as a table, a query spelled from chips and read to Records, the
printout, and then the false exit in one take, held through the cue's stop:
he says goodnight, makes for the door, and turns round. After it the
database's own error, a JOIN, a LEFT JOIN with its NULL, the five freeze
frames, and an end card with the URL. Shots are laid out in the game's
native 480x270 units but composed at 1920x1080 (`S` times that), so text is
sharp: the game draws its text at window resolution and is captured at
1920x1080 (`trailer/capture.sh`), and the trailer's own cards are drawn at
full size too. The mixing and encoding helpers come from the Dunder Quest
trailer (../../dunder-quest/tools/make_trailer.py).

The cue (`trailer/audio/cue_join.wav`, from tools/trailer_audio.py) was
measured at 120 BPM: beats at 0.09 s + k/2, bars of four from there. It
opens on three stabs, stops on a stab at bar 16 (32 s) with another two
beats later, plays a short solo phrase, and comes back in at bar 18; its
last hit is bar 27 (54 s), with a quiet tag after. It plays from the first
frame; every cut lands on a beat or a bar, and the game's own sound sits
under it.

Shots find their capture frames by name in each run's MARK log
(`trailer/captures/<run>.log`), so a fresh capture needs no renumbering.
Needs ffmpeg on the PATH.

    bash trailer/capture.sh                 # -> trailer/captures/{intro,c1..c5}/ + logs, at 1920x1080
    python tools/make_trailer.py            # -> trailer/out/join_trailer_{1080p,4k}.mp4 + join_thumbnail.png
    python tools/make_trailer.py --stills   # one frame per shot, for checking the cut
    python tools/make_trailer.py --at 3 12.5   # frames at those trailer times
    python tools/make_trailer.py --thumb    # just the thumbnail (also copied to the site)
"""

from __future__ import annotations

import re
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

CAPTURES = ROOT / "trailer" / "captures"
AUDIO = ROOT / "trailer" / "audio"
OUT = ROOT / "trailer" / "out"
SITE_THUMB = REPO / "site" / "static" / "img" / "lieutenant" / "trailer.png"
TITLES = ROOT / "assets" / "fonts" / "Caprasimo.ttf"
PIXEL = ROOT / "assets" / "fonts" / "PixelifySans.ttf"
MONO = ROOT / "assets" / "fonts" / "VT323.ttf"

## Layout units are the game's native pixels; frames are S times that.
W, H = dq.W, dq.H
S = 4
CW, CH = W * S, H * S
FPS = dq.FPS
RATE = dq.RATE

# The game's palette (core/palette.gd), as 8-bit RGB.
INK = (23, 18, 20)
PAPER = (245, 237, 214)
CREAM = (252, 230, 173)
EMBER = (240, 128, 51)
NOTE = (250, 242, 217)
NOTE_INK = (36, 36, 61)
NOTE_COVER = (77, 51, 36)
KEYWORD = (56, 51, 158)
STRING = (31, 112, 51)
GREY = (204, 199, 184)
BLACK = (0, 0, 0)

# --- The cue -----------------------------------------------------------------

CUE = "cue_join"
BEAT = 0.5
## The cue's first beat, in cue time; the cue starts at trailer time 0.
CUE_BAR0 = 0.09
## Its last hit (bar 27), and where its tag has rung out.
LAST_HIT = CUE_BAR0 + 27 * 4 * BEAT
CUE_END = 60.5


def bar(n: float) -> float:
    return CUE_BAR0 + n * 4 * BEAT


# --- The captures' MARK logs ---------------------------------------------------

@lru_cache(maxsize=None)
def marks(run: str) -> list[tuple[int, str]]:
    out = []
    for line in (CAPTURES / f"{run}.log").read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"MARK (\d+) (.*)$", line)
        if m:
            out.append((int(m.group(1)), m.group(2)))
    return out


def mark(run: str, text: str, nth: int = 0) -> int:
    """The frame of the `nth` MARK of `run` starting with `text`."""
    found = [f for f, s in marks(run) if s.startswith(text)]
    if len(found) <= nth:
        sys.exit(f"{run}: no MARK '{text}' #{nth}")
    return found[nth]


def said(run: str, words: str) -> int:
    """The frame a speech bubble containing `words` came up."""
    found = [f for f, s in marks(run) if s.startswith("say ") and words in s]
    if not found:
        sys.exit(f"{run}: nobody says '{words}'")
    return found[0]


# --- Sharp drawing, in native units --------------------------------------------

def width(s: str, path: Path, size: float) -> float:
    return font(path, int(size * S)).getlength(s) / S


def text(img: Image.Image, xy: tuple[float, float], s: str, path: Path, size: float, color,
         anchor: str = "lt", shadow=None, shadow_dy: float = 0) -> None:
    """`s` antialiased at full resolution; `xy`, `size` and `shadow_dy` are
    in native pixels. `anchor` is 'lt' or 'mt'."""
    fnt = font(path, int(size * S))
    x, y = xy[0] * S, xy[1] * S
    pil_anchor = {"lt": "la", "mt": "ma"}[anchor]
    d = ImageDraw.Draw(img)
    if shadow is not None and shadow_dy:
        d.text((x, y + shadow_dy * S), s, font=fnt, fill=shadow, anchor=pil_anchor)
    d.text((x, y), s, font=fnt, fill=color, anchor=pil_anchor)


def rect(img: Image.Image, box: tuple[float, float, float, float], fill=None, border=None) -> None:
    x0, y0, x1, y1 = (round(v * S) for v in box)
    d = ImageDraw.Draw(img)
    if fill is not None:
        d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=fill)
    if border is not None:
        d.rectangle((x0, y0, x1 - 1, y1 - 1), outline=border, width=S)


# --- Overlays -----------------------------------------------------------------

def flash_fx(at: float, frames: int = 4, peak: float = 0.6, color=(255, 240, 210)):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) * FPS
        return flash(img, peak * (1 - k / frames), color) if 0 <= k < frames else img
    return fx


# --- Cards ----------------------------------------------------------------------

def black(_t: float = 0.0) -> Image.Image:
    return Image.new("RGB", (CW, CH), BLACK)


def card(lines: list[str], size: int = 28):
    """A black card like the game's own title cards: the game's name small
    in ember, then the lines in the titles' fat serif, the last one ember."""
    def draw(_t: float) -> Image.Image:
        img = black()
        step = int(size * 1.3)
        top = (H - step * len(lines)) // 2 - 2
        text(img, (W / 2, top - 22), "JUST ONE MORE JOIN", MONO, 16, EMBER, anchor="mt")
        y = top
        for k, s in enumerate(lines):
            text(img, (W / 2, y), s, TITLES, size, EMBER if k == len(lines) - 1 and len(lines) > 1 else CREAM, anchor="mt")
            y += step
        return img
    return draw


def figure(img: Image.Image, who: str, cell: tuple[int, int], frame: int, feet: tuple[float, float],
           scale: float, flip: bool = False) -> None:
    """One frame of a cast sheet (painted at two texels to a room pixel),
    standing with its feet at `feet` (native pixels)."""
    sheet = Image.open(ROOT / "assets" / "sprites" / f"{who}.png").convert("RGBA")
    art = sheet.crop((frame * cell[0], 0, (frame + 1) * cell[0], cell[1]))
    if flip:
        art = art.transpose(Image.FLIP_LEFT_RIGHT)
    size = (round(cell[0] * scale * S), round(cell[1] * scale * S))
    art = art.resize(size, Image.NEAREST)
    img.paste(art, (round(feet[0] * S - size[0] / 2), round(feet[1] * S - size[1])), art)


@lru_cache(maxsize=1)
def end_backdrop() -> Image.Image:
    """The title's street with the Lieutenant and Null under the lamp, as the
    title screen stands them, darkened on the left for the words."""
    art = Image.open(ROOT / "assets" / "backgrounds" / "title.png").convert("RGB").resize((CW, CH), Image.NEAREST)
    figure(art, "lt", (64, 128), 0, (380, 244), 0.75, flip=True)
    figure(art, "null", (80, 48), 0, (330, 246), 0.75, flip=True)
    shade = Image.new("RGB", art.size, INK)
    mask = Image.linear_gradient("L").rotate(90).resize(art.size)  # dark on the left
    return Image.composite(art, shade, mask.point(lambda v: int(90 + v * 0.65)))


def end_card(at: float):
    def draw(t: float) -> Image.Image:
        img = end_backdrop().copy()
        local = t - at
        text(img, (38, 36), "Just One More", TITLES, 30, CREAM, shadow=BLACK, shadow_dy=1.5)
        text(img, (37, 66), "JOIN", TITLES, 50, EMBER, shadow=BLACK, shadow_dy=2)
        if local >= 0.8:
            text(img, (40, 128), "He knows who did it.", MONO, 20, PAPER, shadow=BLACK, shadow_dy=1)
            text(img, (40, 145), "He needs a query that proves it.", MONO, 20, PAPER, shadow=BLACK, shadow_dy=1)
        if local >= 1.6:
            text(img, (40, 176), "Learn SQL. Play free in your browser", PIXEL, 11, PAPER)
            text(img, (40, 190), "dunderquest.com/lieutenant", MONO, 28, EMBER, shadow=BLACK, shadow_dy=1)
        if local >= 2.4:
            text(img, (40, 232), "a __dunder_quest__ game", MONO, 18, CREAM)
        return img
    return draw


# --- Gameplay source ------------------------------------------------------------

@lru_cache(maxsize=48)
def capture(run: str, frame: int) -> Image.Image:
    path = CAPTURES / run / f"f{frame:08d}.png"
    if not path.exists():
        return Image.new("RGB", (CW, CH), INK)
    img = Image.open(path).convert("RGB")
    return img if img.size == (CW, CH) else img.resize((CW, CH), Image.NEAREST)


@dataclass
class Shot:
    """`start`..`end` in trailer seconds. `src` is the frame of capture `run`
    shown at `start`; `draw` paints a card instead. `fx` paint on top."""
    start: float
    end: float
    run: str = ""
    src: int | None = None
    speed: float = 1.0
    draw: Callable[[float], Image.Image] | None = None
    fx: list[Callable[[Image.Image, float], Image.Image]] = field(default_factory=list)
    audio: float = 1.0
    label: str = ""

    def frame_at(self, t: float) -> int:
        return int(self.src + round((t - self.start) * FPS * self.speed))


## How long the last hit's sting and the end card run.
END_HOLD = 6.0
## The cue's two stabs at the stop: bar 16, and two beats later.
STAB_1 = bar(16)
STAB_2 = bar(16.5)


def edit() -> list[Shot]:
    shots: list[Shot] = []

    def add(start: float, end: float, **kw) -> Shot:
        shot = Shot(start, end, **kw)
        shots.append(shot)
        return shot

    # The title screen on the cue's three opening stabs.
    add(0.0, bar(1.5), run="intro", src=mark("intro", "title") + 40, label="title", audio=0.0)
    add(bar(1.5), bar(2.5), draw=card(["Every case opens", "on the murder."]), label="card murder")

    # Case 1's cold open: the partner, then the thing he thought of.
    add(bar(2.5), bar(4.5), run="c1", src=mark("c1", "caption 1 2") + 6, label="cold open", audio=0.0)
    add(bar(4.5), bar(6), run="c1", src=mark("c1", "titlecard 1") - 182, label="thought of everything", audio=0.0)
    add(bar(6), bar(7), draw=card(["You know who did it.", "Now prove it."]), label="card prove")

    # The Lieutenant and his dog, then the record that becomes a table.
    add(bar(7), bar(8), run="c1", src=mark("c1", "arrive 1") + 4, label="arrival")
    add(bar(8), bar(9), draw=card(["The city's records", "only answer in SQL."]), label="card sql")
    add(bar(9), bar(10), run="c1", src=mark("c1", "slip 1 guests") - 8, label="a record, as a table")

    # One query, spelled chip by chip, read to Records, and the printout.
    dial = mark("c1", "dial 1b")
    add(bar(10), bar(12.5), run="c1", src=dial - 180, label="spell, call, printout",
        fx=[flash_fx(bar(10) + (mark("c1", "printout 1b") - (dial - 180)) / FPS, 4, 0.35)])
    add(bar(12.5), bar(13.5), run="c1", src=said("c1", "Are we finished, Lieutenant?") + 4, label="are we finished")

    # The false exit, in one take: goodnight, the door, the cue's stop, and
    # the bubble on its second stab. The band is back in under her reply.
    turn = said("c4", "It's a silly thing")
    take = turn - round((STAB_2 - bar(13.5)) * FPS)
    add(bar(13.5), bar(19.5), run="c4", src=take, label="the false exit")

    # It's real SQL: the database's own error, a JOIN, and a NULL.
    add(bar(19.5), bar(20.5), draw=card(["Real SQL.", "Real errors."]), label="card real")
    add(bar(20.5), bar(21.5), run="c3", src=mark("c3", "printout 3b error") + 30, speed=0.0, label="no such column", audio=0.0)
    add(bar(21.5), bar(22.5), run="c3", src=mark("c3", "printout 3b ok") + 30, speed=0.0, label="join", audio=0.0)
    add(bar(22.5), bar(23.5), run="c5", src=mark("c5", "printout 5b ok") + 30, speed=0.0, label="left join, null", audio=0.0)

    # Five freeze frames, two beats each.
    for k, run in enumerate(["c1", "c2", "c3", "c4", "c5"]):
        at = bar(23.5) + k * 2 * BEAT
        add(at, at + 2 * BEAT, run=run, src=mark(run, "freeze") + 20, label=f"freeze {k + 1}", audio=0.0,
            fx=[flash_fx(at, 4, 0.5)])
    add(bar(26), LAST_HIT, draw=card(["Five cases.", "From SELECT", "to LEFT JOIN."], size=26), label="card five")
    add(LAST_HIT, LAST_HIT + END_HOLD, draw=end_card(LAST_HIT), label="end card", fx=[flash_fx(LAST_HIT, 5, 0.6)])
    return shots


def chapters() -> list[tuple[float, str]]:
    """YouTube chapters (each at least 10 s long), for the video description."""
    return [(0.0, "Every case opens on the murder"), (bar(7), "Ask Records, in SQL"),
            (bar(13.5), "One more question"), (bar(19.5), "Real SQL, real errors")]


def cues() -> list[tuple[str, float, float]]:
    """(sound, trailer time, gain): this trailer's own effects."""
    return [("hit", bar(6) - 0.02, 0.5),
            ("teletype", bar(20.5), 0.35),
            ("teletype", bar(22.5), 0.3),
            ("sting", LAST_HIT, 0.8)]


# --- Rendering and sound --------------------------------------------------------

def render_frame(shots: list[Shot], t: float) -> Image.Image:
    shot = next((s for s in shots if s.start <= t < s.end), shots[-1])
    if shot.draw is not None:
        img = shot.draw(t)
    else:
        img = capture(shot.run, shot.frame_at(t)).copy()
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


@lru_cache(maxsize=None)
def capture_sound(run: str) -> np.ndarray:
    return dq.load_wav(CAPTURES / run / "f.wav")


def mix_audio(shots: list[Shot], total_s: float, path: Path) -> None:
    n = int(total_s * RATE)
    music = np.zeros((n, 2), np.float32)
    score = dq.load_wav(AUDIO / f"{CUE}.wav")[:int(CUE_END * RATE)].copy()
    tail = int(1.5 * RATE)
    score[-tail:] *= np.linspace(1, 0, tail)[:, None]
    dq.place(music, score, 0.0, 1.0)
    game = np.zeros((n, 2), np.float32)
    fade = int(0.01 * RATE)
    for shot in shots:
        if shot.src is None or shot.audio <= 0 or shot.speed != 1.0:
            continue
        a = int(shot.src / FPS * RATE)
        clip = capture_sound(shot.run)[a:a + int((shot.end - shot.start) * RATE)].copy()
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
    """A 1920x1080 YouTube thumbnail: the Lieutenant with a finger raised
    and a suspect with her arms folded, in the hotel, under the name, with
    'Learn SQL' and a query on a strip of his notebook."""
    scene = Image.open(ROOT / "assets" / "backgrounds" / "hotel.png").convert("RGB").resize((CW, CH), Image.NEAREST)
    img = Image.blend(scene, Image.new("RGB", (CW, CH), INK), 0.45)
    # The Lieutenant's raised finger is his fourth frame; a suspect's folded
    # arms are her third (tools/paint.py).
    figure(img, "lt", (64, 128), 3, (78, 292), 1.75)
    figure(img, "harrow", (64, 128), 2, (408, 292), 1.75, flip=True)
    rect(img, (0, 0, W, 60), fill=BLACK)
    rect(img, (0, 60, W, 62), fill=EMBER)
    name = "Just One More "
    total = width(name, TITLES, 34) + width("JOIN", TITLES, 34)
    x = (W - total) / 2
    text(img, (x, 9), name, TITLES, 34, CREAM)
    text(img, (x + width(name, TITLES, 34), 9), "JOIN", TITLES, 34, EMBER)
    text(img, (W / 2, 84), "LEARN", PIXEL, 26, PAPER, anchor="mt", shadow=BLACK, shadow_dy=2)
    text(img, (W / 2, 106), "SQL", TITLES, 64, EMBER, anchor="mt", shadow=BLACK, shadow_dy=3)
    # A strip of notebook paper with the prologue's query (case 1's guest book).
    parts = [("SELECT ", KEYWORD), ("name ", NOTE_INK), ("FROM ", KEYWORD), ("guests ", NOTE_INK),
             ("WHERE ", KEYWORD), ("arrived > ", NOTE_INK), ("'21:00'", STRING)]
    tw = sum(width(s, MONO, 24) for s, _ in parts)
    rect(img, ((W - tw) / 2 - 10, 206, (W + tw) / 2 + 10, 238), fill=NOTE, border=NOTE_COVER)
    x = (W - tw) / 2
    for s, color in parts:
        text(img, (x, 209), s, MONO, 24, color)
        x += width(s, MONO, 24)
    img.save(path, optimize=True)
    print(f"WROTE {path.relative_to(ROOT.parent)}")
    SITE_THUMB.parent.mkdir(parents=True, exist_ok=True)
    img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(SITE_THUMB, optimize=True)
    print(f"WROTE {SITE_THUMB.relative_to(REPO)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if "--thumb" in sys.argv:
        thumbnail(OUT / "join_thumbnail.png")
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
            print(f"{shot.start:6.2f}-{shot.end:6.2f} {shot.label} {shot.run} src={shot.src}")
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
    encode(native, OUT / "mix.wav", 1, OUT / "join_trailer_1080p.mp4", 12)
    if "--no-4k" not in sys.argv:
        encode(native, OUT / "mix.wav", 2, OUT / "join_trailer_4k.mp4", 16)
    thumbnail(OUT / "join_thumbnail.png")


if __name__ == "__main__":
    main()
