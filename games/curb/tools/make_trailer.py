"""Cut the Curb Your Oxidation trailer from a Movie Maker capture of the bot.

Cut like the promos for the kind of LA cringe comedy the game is a homage
to: plain white serif on black cards between the scenes, the squabbling
left to play, the sepia rehearsal stopping on a red line and Sharon bursting
in with the rustc error, Barry's squint held through an awkward silence, the
`unwrap()` panic, and a freeze frame with a bouncy tuba sting to end on.
Everything is composed at the game's native 480x270 and scaled by whole
numbers with nearest-neighbor, like the Dunder Quest and Flatmates.js
trailers, whose drawing, mixing and encoding helpers
(../../dunder-quest/tools/make_trailer.py) this reuses.

It opens cold on the game's own sound: Barry promising one latte, the
rehearsal, Sharon. Then the cue (`trailer/audio/cue_curb.wav`, an original
Italian-library-style comedy piece, 120 BPM, measured beats at 0.05 s + k/2
and bars from 1.05 s) comes in on its pickup and every cut after that lands
on a beat or a bar of it. The cue's own stops (32.2 s, 38.5 s) carry the
panic and the squint.

Shots find their capture frames by name in the run's MARK log
(`trailer/captures/run.log`), so a fresh capture needs no renumbering.
Needs ffmpeg on the PATH.

    godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_run.tscn > trailer/captures/run.log
    python tools/make_trailer.py            # -> trailer/out/curb_trailer_{1080p,4k}.mp4 + curb_thumbnail.png
    python tools/make_trailer.py --stills   # one frame per shot, for checking the cut
    python tools/make_trailer.py --at 3 12.5   # frames at those trailer times
    python tools/make_trailer.py --thumb    # just the thumbnail
"""

from __future__ import annotations

import math
import re
import subprocess
import sys
import wave
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Callable

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / "dunder-quest" / "tools"))

import make_trailer as dq  # noqa: E402
from make_trailer import draw_text, flash, font, panel  # noqa: E402

## `--capture NAME` cuts from trailer/captures/NAME/ and NAME.log instead of run.
_NAME = sys.argv[sys.argv.index("--capture") + 1] if "--capture" in sys.argv else "run"
CAPTURE = ROOT / "trailer" / "captures" / _NAME
LOG = ROOT / "trailer" / "captures" / f"{_NAME}.log"
AUDIO = ROOT / "trailer" / "audio"
OUT = ROOT / "trailer" / "out"
SERIF = ROOT / "assets" / "fonts" / "LibreBaskerville.ttf"
MONO = ROOT / "assets" / "fonts" / "VT323.ttf"
PIXEL = ROOT / "assets" / "fonts" / "PixelifySans.ttf"
GAME_AUDIO = ROOT / "assets" / "audio"

W, H = dq.W, dq.H
FPS = dq.FPS
RATE = dq.RATE

# The game's palette (core/palette.gd), as 8-bit RGB.
INK = (18, 15, 20)
PAPER = (247, 240, 219)
RED = (219, 61, 51)
AMBER = (255, 184, 82)
RUST = (217, 107, 46)
PAD = (252, 242, 158)
PAD_INK = (31, 36, 77)
SYN_KEYWORD = (143, 41, 143)
SYN_STRING = (31, 117, 46)
SYN_NUMBER = (184, 82, 15)
SYN_COMMENT = (112, 112, 128)
SYN_CALL = (26, 82, 168)
SYN_MACRO = (184, 51, 31)
SYN_TYPE = (15, 112, 128)
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GREY = (205, 205, 205)

# --- The cue -----------------------------------------------------------------

CUE = "cue_curb"
BEAT = 0.5
## The cue starts this far in (just before its pickup), at trailer time INTRO.
CUE_START = 0.8
## Where its bars fall, in cue time.
CUE_BAR0 = 1.05
## The cue's last chord has rung out here (cue time).
CUE_END = 62.7


def cue(t: float) -> float:
    """Trailer time of cue time `t`."""
    return INTRO + t - CUE_START


def bar(n: float) -> float:
    return cue(CUE_BAR0 + n * 4 * BEAT)


def beat(k: float) -> float:
    return cue(CUE_BAR0 + k * BEAT)


# --- The capture's MARK log ---------------------------------------------------

@lru_cache(maxsize=None)
def marks() -> list[tuple[int, str]]:
    out = []
    for line in LOG.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"MARK (\d+) (.*)$", line)
        if m:
            out.append((int(m.group(1)), m.group(2)))
    return out


def mark(text: str, scene: int | None = None, nth: int = 0) -> int:
    """The frame of the `nth` MARK starting with `text`, inside `scene` if given."""
    lo, hi = 0, 1 << 30
    if scene is not None:
        lo = mark(f"scene {scene} ")
        nxt = [f for f, s in marks() if s.startswith(f"scene {scene + 1} ")]
        hi = nxt[0] if nxt else hi
    found = [f for f, s in marks() if s.startswith(text) and lo <= f < hi]
    if len(found) <= nth:
        sys.exit(f"no MARK '{text}' #{nth} in scene {scene}")
    return found[nth]


def after(frame: int) -> int:
    """The frame of the next MARK after `frame` (where that moment ends)."""
    return next(f for f, _ in marks() if f > frame)


# --- Rust, colored like the game's legal pad ----------------------------------

KEYWORDS = {"fn", "let", "mut", "if", "else", "match", "for", "in", "return", "struct", "enum", "impl",
            "self", "Self", "true", "false", "pub", "use", "loop", "while"}
TYPES = {"i32", "i64", "u32", "u8", "usize", "f64", "bool", "char", "str", "String", "Vec", "Option", "Result"}


def tokens(line: str) -> list[tuple[str, tuple]]:
    out: list[tuple[str, tuple]] = []
    i, n = 0, len(line)
    while i < n:
        ch = line[i]
        if line.startswith("//", i):
            out.append((line[i:], SYN_COMMENT))
            break
        if ch == '"':
            j = line.find('"', i + 1)
            j = n if j < 0 else j + 1
            out.append((line[i:j], SYN_STRING))
            i = j
            continue
        if ch == "'" and i + 1 < n and line[i + 1].isalpha():
            j = i + 1
            while j < n and (line[j].isalnum() or line[j] == "_"):
                j += 1
            out.append((line[i:j], SYN_KEYWORD))
            i = j
            continue
        if ch.isdigit():
            j = i
            while j < n and line[j].isdigit():
                j += 1
            out.append((line[i:j], SYN_NUMBER))
            i = j
            continue
        if ch.isalpha() or ch == "_":
            j = i
            while j < n and (line[j].isalnum() or line[j] == "_"):
                j += 1
            word = line[i:j]
            color = PAD_INK
            if word in KEYWORDS:
                color = SYN_KEYWORD
            elif j < n and line[j] == "!":
                color = SYN_MACRO
                word += "!"
                j += 1
            elif word in TYPES or word[0].isupper():
                color = SYN_TYPE
            elif j < n and line[j] == "(":
                color = SYN_CALL
            out.append((word, color))
            i = j
            continue
        out.append((ch, PAD_INK))
        i += 1
    return out


def draw_rust(img: Image.Image, xy: tuple[int, int], line: str, fnt) -> int:
    x, y = xy
    for word, color in tokens(line):
        draw_text(img, (x, y), word, fnt, color)
        x += int(fnt.getlength(word))
    return x


# --- Overlays -----------------------------------------------------------------

def serif_text(img: Image.Image, xy: tuple[int, int], s: str, size: int, color=WHITE, anchor: str = "mt") -> None:
    """Plain serif, antialiased at native size, as the game draws its title cards."""
    ImageDraw.Draw(img).text(xy, s, font=font(SERIF, size), fill=color, anchor={"mt": "ma", "lt": "la"}[anchor])


def code_chip(line: str, at: float, until: float, y: int = 228, border=RUST):
    """One line of Rust on a strip of legal-pad yellow that wipes open."""
    fnt = font(MONO, 18)

    def fx(img: Image.Image, t: float) -> Image.Image:
        if not at <= t < until:
            return img
        tw = int(fnt.getlength(line))
        pw, ph = tw + 18, 22
        x0 = (W - pw) // 2
        grow = min(1.0, (t - at) * 10, (until - t) * 12)
        width = int(pw * grow)
        if width < 4:
            return img
        panel(img, (x0, y, x0 + width, y + ph), fill=PAD, border=border)
        ImageDraw.Draw(img).rectangle((x0, y, x0 + 1, y + ph - 1), fill=RUST)
        if width == pw:
            draw_rust(img, (x0 + 9, y + 2), line, fnt)
        return img
    return fx


def caption(s: str, at: float, until: float, y: int = 230, size: int = 13, color=WHITE):
    """A plain serif caption on a black strip, like a subtitle."""
    def fx(img: Image.Image, t: float) -> Image.Image:
        if at <= t < until:
            f = font(SERIF, size)
            tw = int(f.getlength(s))
            ImageDraw.Draw(img).rectangle(((W - tw) // 2 - 8, y - 4, (W + tw) // 2 + 8, y + size + 6), fill=BLACK)
            serif_text(img, (W // 2, y), s, size, color)
        return img
    return fx


def flash_fx(at: float, frames: int = 4, peak: float = 0.8):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) * FPS
        return flash(img, peak * (1 - k / frames)) if 0 <= k < frames else img
    return fx


def shake_fx(at: float, amount: float = 3.0, length: float = 0.25):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = t - at
        return dq.shaken(img, amount * (1 - k / length), t) if 0 <= k < length else img
    return fx


def freeze_tint(img: Image.Image, t: float) -> Image.Image:
    """The end-of-scene freeze frame: a touch drained and warm."""
    gray = img.convert("L").convert("RGB")
    return Image.blend(Image.blend(img, gray, 0.35), Image.new("RGB", img.size, (130, 100, 60)), 0.12)


def fade_from_black(at: float, length: float):
    def fx(img: Image.Image, t: float) -> Image.Image:
        k = (t - at) / length
        return Image.blend(Image.new("RGB", img.size, BLACK), img, max(0.0, min(1.0, k))) if k < 1 else img
    return fx


# --- Cards ----------------------------------------------------------------------

def black(_t: float) -> Image.Image:
    return Image.new("RGB", (W, H), BLACK)


def card(lines: list[tuple[str, int]], at: float = -1.0, gap: float = 0.0):
    """A black card of plain serif lines, centered; each line can wait `gap`."""
    def draw(t: float) -> Image.Image:
        img = black(t)
        total = sum(int(size * 1.6) for _, size in lines)
        y = (H - total) // 2 + 4
        for k, (s, size) in enumerate(lines):
            if t >= at + k * gap:
                serif_text(img, (W // 2, y), s, size, WHITE if k == 0 else GREY)
            y += int(size * 1.6)
        return img
    return draw


def end_card(at: float):
    def draw(t: float) -> Image.Image:
        img = black(t)
        local = t - at
        serif_text(img, (W // 2, 70), "Curb Your Oxidation", 28)
        if local >= 0.8:
            serif_text(img, (W // 2, 112), "Learn Rust. Mind your manners.", 13, GREY)
        if local >= 1.6:
            serif_text(img, (W // 2, 150), "Play free in your browser", 11, GREY)
            draw_text(img, (W // 2, 166), "dunderquest.com/curb", font(MONO, 26), AMBER, anchor="mt")
        if local >= 2.4:
            draw_text(img, (W // 2, 222), "a __dunder_quest__ game", font(MONO, 18), RUST, anchor="mt")
        return img
    return draw


# --- Gameplay source ------------------------------------------------------------

@lru_cache(maxsize=256)
def capture(frame: int) -> Image.Image:
    path = CAPTURE / f"f{frame:08d}.png"
    if not path.exists():
        return Image.new("RGB", (W, H), INK)
    return Image.open(path).convert("RGB")


@dataclass
class Shot:
    """`start`..`end` in trailer seconds. `src` is the capture frame shown at
    `start`; `draw` paints a card instead. `fx` paint on top, in order."""
    start: float
    end: float
    src: int | None = None
    speed: float = 1.0
    zoom: int = 1
    focus: tuple[int, int] = (240, 150)
    draw: Callable[[float], Image.Image] | None = None
    fx: list[Callable[[Image.Image, float], Image.Image]] = field(default_factory=list)
    audio: float = 1.0
    label: str = ""

    def frame_at(self, t: float) -> int:
        return int(self.src + round((t - self.start) * FPS * self.speed))


## The cold open, in capture frames of scene 1 (filled in by `edit`).
INTRO = 0.0


def cold_open() -> list[tuple[int, int, str]]:
    """(from, to, label) capture ranges played back to back before the cue."""
    say = [f for f, s in marks() if s.startswith("say ") and f < mark("card", 1)]
    one = say[1]                          # Barry: One. One latte.
    rehearsal = mark("rehearsal 1a", 1)
    rant = mark("rant E0384", 1)
    squint = mark("squint barry", 1)
    return [
        (one + 1, say[2] + 1, "one latte"),
        (say[2] + 1, say[3] + 1, "write it down"),
        (say[3] + 1, say[3] + 140, "a tuesday"),
        (mark("pad 1a", 1) + 20, mark("pad 1a", 1) + 80, "the pad"),
        (rehearsal - 4, rant, "rehearsal"),
        (rant, rant + 170, "sharon"),
        (squint, squint + 110, "is that a rule"),
    ]


def edit() -> list[Shot]:
    global INTRO
    shots: list[Shot] = []

    def add(start: float, end: float, **kw) -> Shot:
        shot = Shot(start, end, **kw)
        shots.append(shot)
        return shot

    # Cold open: straight in, on the game's own sound.
    t = 0.0
    for a, b, label in cold_open():
        length = (b - a) / FPS
        fx = []
        if label == "sharon":
            fx = [shake_fx(t, 3, 0.3)]
        add(t, t + length, src=a, label=label, fx=fx)
        t += length
    # A beat of black before the cue's pickup.
    add(t, t + 0.35, draw=black, label="beat")
    INTRO = t + 0.35

    # The title on the cue's first big hit.
    title_at = cue(2.55)
    add(INTRO, title_at, draw=black, label="pickup")
    add(title_at, bar(2), draw=card([("Curb Your Oxidation", 30)]), label="title")

    # Who, what, and who's checking: card, footage, card, footage.
    etiquette = mark("say barry If we don't open it tonight", 3)
    add(bar(2), bar(2.5), draw=card([("Barry Danvers has rules.", 18)]), label="card barry")
    add(bar(2.5), bar(4), src=etiquette + 1, label="the etiquette")
    add(bar(4), bar(4.5), draw=card([("So does Rust.", 18)]), label="card rust")
    pad = mark("pad 3a", 3)
    add(bar(4.5), bar(5.5), src=pad + 10, label="the pad",
        fx=[caption("Every plan is a real Rust program.", bar(4.5) + BEAT, bar(5.5), y=120, size=12)])
    add(bar(5.5), bar(6), draw=card([("And somebody", 18), ("is always checking.", 18)], bar(5.5), BEAT), label="card checking")
    rant3 = mark("rant E0382", 3)
    add(bar(6), bar(6.5), src=rant3 - int(BEAT * 2 * FPS) + 6, label="rehearsal 3a")
    add(bar(6.5), bar(8), src=rant3, label="rant 3a", fx=[shake_fx(bar(6.5), 3, 0.3)])

    # The season: ten disputes, a bar each, on the game's own title cards.
    season = [
        (4, "admire(&mower);", mark("run 4a", 4) + 20),
        (5, "let barry = &mut tray;", mark("run 5a", 5) + 30),
        (6, "fn add_stroke(&mut self)", mark("run 6a", 6) + 20),
        (7, 'Answer::Maybe => println!("Philippe: The bar."),', mark("run 7a", 7) + 30),
        (8, "fn refund(receipt: bool) -> Result<i32, String>", mark("run 8a", 8) + 40),
        (9, "for f in &friends {", mark("run 9a", 9) + 30),
        (10, "fn longest<'a>(a: &'a str, b: &'a str) -> &'a str", mark("run 10a", 10) + 20),
    ]
    for k, (n, code, src) in enumerate(season):
        at = bar(8 + k)
        title = mark(f"scene {n} ")
        add(at, at + BEAT * 1.5, src=title + 40, speed=0.0, label=f"title {n}")
        add(at + BEAT * 1.5, bar(9 + k), src=src, label=f"run {n}",
            fx=[code_chip(code, at + BEAT * 1.75, bar(9 + k) - BEAT / 4)])
    # Bar 15: the music stops dead for a beat, and so does the plan.
    panic = mark("panic 8b", 8)
    add(bar(15), cue(32.2), src=panic - int((cue(32.2) - bar(15)) * FPS) - 10, label="before panic")
    add(cue(32.2), cue(35.2), src=panic, label="panic",
        fx=[flash_fx(cue(32.2), 4, 0.8), shake_fx(cue(32.2), 3, 0.3)])
    # The breakdown: the rehearsal and Sharon, on the shrimp tray.
    rant5 = mark("rant E0499", 5)
    add(cue(35.2), cue(38.5) - 2.4, src=rant5 - int(0.9 * FPS), label="rehearsal 5a")
    add(cue(38.5) - 2.4, cue(38.5), src=rant5 + 10, label="rant 5a")
    # The cue's long silence: Barry's squint, held.
    squint = mark("squint barry", 6)
    add(cue(38.5), bar(20), src=squint + 40, speed=0.0,
        label="the squint")
    # It starts up again: the other kinds of trouble.
    add(bar(20), bar(21), src=mark("rant E0004", 7) + 20, label="rant maybe")
    add(bar(21), bar(22), src=mark("rant E0597", 10) + 20, label="rant key")

    # Finale: three endings, two bars each: the last awkward lines, then the freeze.
    for k, n in enumerate([3, 5, 8]):
        at = bar(22 + k * 2)
        fr = mark(f"freeze {n}")
        hold = at + BEAT * 6
        add(at, hold, src=fr - int((hold - at) * FPS), label=f"ending {n}", fx=[flash_fx(at, 3, 0.4)])
        add(hold, bar(24 + k * 2), src=fr + 4, speed=0.0, label=f"freeze {n}",
            fx=[freeze_tint, flash_fx(hold, 3, 0.5)])
    # The houseguest, timed so his freeze lands on the cue's last chord.
    last = mark("freeze 10")
    end_hit = cue(CUE_END) - 0.45
    add(bar(28), end_hit, src=last - int((end_hit - bar(28)) * FPS), label="houseguest")
    add(end_hit, end_hit + STING_HOLD, src=last + 4, speed=0.0, audio=0.0, label="last freeze",
        fx=[freeze_tint, flash_fx(end_hit, 3, 0.6)])
    add(end_hit + STING_HOLD, end_hit + STING_HOLD + END_HOLD, draw=end_card(end_hit + STING_HOLD), label="end card")
    return shots


## How long the last freeze holds for the sting, and the end card after it.
STING_HOLD = 3.4
END_HOLD = 6.0


def chapters() -> list[tuple[float, str]]:
    """YouTube chapters (each at least 10 s long), for the video description."""
    return [(0.0, "Cold open: one latte"), (INTRO, "Barry has rules"), (bar(8), "The season"),
            (bar(15), "The panic, the shrimp, the squint"), (bar(22), "Freeze frames")]


def length(shots: list[Shot]) -> float:
    return shots[-1].end


def cues() -> list[tuple[str, float, float]]:
    """(sound, trailer time, gain): this trailer's own effects."""
    end_hit = cue(CUE_END) - 0.45
    return [
        ("swish", bar(2) - 0.1, 0.4),
        ("scratch", cue(32.2) - 0.02, 0.7),
        ("sting", end_hit + 0.1, 1.0),
    ]


# --- Rendering and sound --------------------------------------------------------

def render_frame(shots: list[Shot], t: float) -> Image.Image:
    shot = next((s for s in shots if s.start <= t < s.end), shots[-1])
    if shot.draw is not None:
        img = shot.draw(t)
    else:
        img = dq.zoomed(capture(shot.frame_at(t)), shot.zoom, shot.focus).copy()
    for fx in shot.fx:
        img = fx(img, t)
    return img


def write_video(shots: list[Shot], total_s: float, path: Path) -> None:
    command = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "ffv1", "-pix_fmt", "bgr0", str(path)]
    proc = subprocess.Popen(command, stdin=subprocess.PIPE)
    total = int(round(total_s * FPS))
    for n in range(total):
        proc.stdin.write(render_frame(shots, n / FPS).tobytes())
        if n % 600 == 0:
            print(f"frame {n}/{total}", flush=True)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed while writing the native video")


def decode(path: Path) -> np.ndarray:
    """Any audio file as float32 stereo at RATE, through ffmpeg."""
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "s16le", "-ac", "2",
                          "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).reshape(-1, 2).astype(np.float32) / 32768.0


def mix_audio(shots: list[Shot], total_s: float, path: Path) -> None:
    n = int(total_s * RATE)
    music = np.zeros((n, 2), np.float32)
    score = dq.load_wav(AUDIO / f"{CUE}.wav")[int(CUE_START * RATE):int(CUE_END * RATE)]
    dq.place(music, score, INTRO, 1.0)
    # Under the end card, the game's own title tune, faded in low.
    end = shots[-1]
    tune = decode(GAME_AUDIO / "music_title.ogg")[:int((end.end - end.start) * RATE)].copy()
    tune *= np.minimum(1.0, np.linspace(0, (end.end - end.start) / 1.5, len(tune)))[:, None]
    dq.place(music, tune, end.start, 0.55)
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
        # Before the cue, the game is the whole soundtrack; after, it sits under.
        dq.place(game, clip, shot.start, shot.audio if shot.end <= INTRO else shot.audio * 0.7)
    sfx = np.zeros((n, 2), np.float32)
    for name, at, gain in cues():
        dq.place(sfx, dq.load_wav(AUDIO / f"{name}.wav"), at, gain)
    # Room tone under the cold open (the game has no voices), leveled and
    # faded out into the beat of black before the cue.
    room = dq.load_wav(AUDIO / "kitchen.wav")[:int(INTRO * RATE)].copy()
    room *= 0.03 / max(1e-6, float(np.sqrt((room ** 2).mean())))
    room *= np.minimum(1.0, np.linspace(len(room) / RATE, 0, len(room)) / 0.6)[:, None]
    dq.place(sfx, np.clip(room, -0.5, 0.5), 0.0, 1.0)
    hits = np.abs(game * 2.5 + sfx).max(axis=1)
    env = np.convolve(hits, np.ones(2400) / 2400, mode="same")
    duck = 1.0 - np.clip(env * 2.0, 0.0, 0.35)
    game = 0.6 * np.tanh(game * 2.5 / 0.6)
    mix = music * 0.62 * duck[:, None] + game + sfx * 0.8
    tail = int(1.0 * RATE)
    mix[-tail:] *= np.linspace(1, 0, tail)[:, None]
    peak = np.abs(mix).max()
    if peak > 0.98:
        mix *= 0.98 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())


def encode(native: Path, audio: Path, scale: int, out: Path, crf: int) -> None:
    """Whole-number nearest-neighbor upscale to H.264 + AAC, YouTube/Steam friendly."""
    command = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(native), "-i", str(audio),
               "-vf", f"scale={W * scale}:{H * scale}:flags=neighbor",
               "-c:v", "libx264", "-preset", "slow", "-crf", str(crf), "-pix_fmt", "yuv420p",
               "-tune", "animation", "-r", str(FPS), "-c:a", "aac", "-b:a", "320k", "-ar", str(RATE),
               "-shortest", "-movflags", "+faststart", str(out)]
    subprocess.run(command, check=True)
    print(f"WROTE {out.relative_to(ROOT.parent)}", flush=True)


def thumbnail(path: Path) -> None:
    """A 1920x1080 YouTube thumbnail: Barry's squint and Sharon mid-rant,
    face to face over the rustc error, under the name in plain serif."""
    img = Image.new("RGB", (W, H), BLACK)
    scene = Image.open(ROOT / "assets" / "backgrounds" / "dinner.png").convert("RGB").resize((W, H), Image.NEAREST)
    img.paste(Image.blend(scene, Image.new("RGB", (W, H), BLACK), 0.45), (0, 0))
    faces = ROOT / "assets" / "sprites"
    barry = Image.open(faces / "barry_face.png").convert("RGBA").crop((96, 0, 144, 48)).resize((144, 144), Image.NEAREST)
    sharon = Image.open(faces / "sharon_face.png").convert("RGBA").crop((144, 0, 192, 48)).resize((144, 144), Image.NEAREST)
    d = ImageDraw.Draw(img)
    for box, face, edge in (((24, 74), barry, PAPER), ((312, 74), sharon, RED)):
        x, y = box
        d.rectangle((x - 4, y - 4, x + 147, y + 147), fill=INK)
        d.rectangle((x - 2, y - 2, x + 145, y + 145), fill=edge)
        img.paste(face, (x, y), face)
    d.rectangle((0, 0, W, 60), fill=BLACK)
    serif_text(img, (W // 2, 12), "Curb Your Oxidation", 30)
    msg = "error[E0382]: borrow of moved value"
    f = font(MONO, 22)
    tw = int(f.getlength(msg))
    panel(img, ((W - tw) // 2 - 10, 228, (W + tw) // 2 + 10, 256), fill=INK, border=RED)
    draw_text(img, (W // 2, 231), msg, f, (240, 120, 110), anchor="mt")
    draw_text(img, (W // 2, 104), "LEARN", font(PIXEL, 24), PAPER, outline=INK, thick=2, anchor="mt")
    draw_text(img, (W // 2, 130), "RUST", font(PIXEL, 44), RUST, outline=INK, thick=2,
              shadow=BLACK, shadow_dy=3, anchor="mt")
    img.resize((W * 4, H * 4), Image.NEAREST).save(path)
    print(f"WROTE {path.relative_to(ROOT.parent)}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if "--thumb" in sys.argv:
        thumbnail(OUT / "curb_thumbnail.png")
        return
    shots = edit()
    total = length(shots)
    print(f"length {total:.2f}s, cue in at {INTRO:.2f}s")
    for at, name in chapters():
        print(f"CHAPTER {int(at) // 60}:{int(at) % 60:02d} {name}")
    if "--stills" in sys.argv:
        sheet = Image.new("RGB", (W * 4, H * ((len(shots) + 3) // 4)), "black")
        for k, shot in enumerate(shots):
            mid = min(shot.end - 1 / FPS, shot.start + (shot.end - shot.start) * 0.7)
            img = render_frame(shots, mid)
            draw_text(img, (2, 2), f"{k} {shot.label} {shot.start:.1f}", font(MONO, 16), (255, 0, 255))
            sheet.paste(img, ((k % 4) * W, (k // 4) * H))
        sheet.save(OUT / "stills.png")
        print(f"WROTE {(OUT / 'stills.png').relative_to(ROOT.parent)}")
        for shot in shots:
            print(f"{shot.start:6.2f}-{shot.end:6.2f} {shot.label} src={shot.src}")
        return
    if "--at" in sys.argv:
        times = [float(a) for a in sys.argv[sys.argv.index("--at") + 1:]]
        sheet = Image.new("RGB", (W * 2, H * ((len(times) + 1) // 2)), "black")
        for k, t in enumerate(times):
            sheet.paste(render_frame(shots, t), ((k % 2) * W, (k // 2) * H))
        sheet.save(OUT / "at.png")
        print(f"WROTE {(OUT / 'at.png').relative_to(ROOT.parent)}")
        return
    native = OUT / "native.mkv"
    if "--audio-only" not in sys.argv or not native.exists():
        write_video(shots, total, native)
    mix_audio(shots, total, OUT / "mix_raw.wav")
    dq.normalize(OUT / "mix_raw.wav", OUT / "mix.wav")
    encode(native, OUT / "mix.wav", 4, OUT / "curb_trailer_1080p.mp4", 12)
    if "--no-4k" not in sys.argv:
        encode(native, OUT / "mix.wav", 8, OUT / "curb_trailer_4k.mp4", 16)
    thumbnail(OUT / "curb_thumbnail.png")


if __name__ == "__main__":
    main()
