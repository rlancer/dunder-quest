"""Paint the rooms: five places the Lieutenant asks his questions, the night
street of the cold opens, the title's street and the desk the case files
sit on.

Each is drawn from shapes in room pixels (480x270), four times larger, then
averaged down to two texels a room pixel (960x540) and lit: every lamp and
window adds a pool of warm light, and the corners fall off. The palette is
then cut to a few dozen colours so it sits with the painted cast.

    python tools/scenery.py            # -> assets/backgrounds/*.png
    python tools/scenery.py gala club  # just these
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "backgrounds"

W, H = 480, 270
SS = 4
FLOOR = 198.0


def rgb(text: str) -> tuple[int, int, int]:
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16))


def mix(a: tuple, b: tuple, t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c: tuple, k: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


class Room:
    def __init__(self, seed: int = 1) -> None:
        self.image = Image.new("RGB", (W * SS, H * SS), (0, 0, 0))
        self.d = ImageDraw.Draw(self.image)
        self.lights: list[tuple[float, float, float, tuple, float, float]] = []
        self.rand = random.Random(seed)
        self.ambient = 0.92
        self.vignette = 0.42

    # --- Shapes, in room pixels ---

    def rect(self, x: float, y: float, w: float, h: float, color: tuple) -> None:
        x0, y0 = round(x * SS), round(y * SS)
        self.d.rectangle((x0, y0, max(x0, round((x + w) * SS) - 1), max(y0, round((y + h) * SS) - 1)), fill=color)

    def poly(self, points: list, color: tuple) -> None:
        self.d.polygon([(px * SS, py * SS) for px, py in points], fill=color)

    def oval(self, cx: float, cy: float, rx: float, ry: float, color: tuple) -> None:
        self.d.ellipse(((cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS), fill=color)

    def line(self, x0: float, y0: float, x1: float, y1: float, color: tuple, width: float = 1.0) -> None:
        self.d.line((x0 * SS, y0 * SS, x1 * SS, y1 * SS), fill=color, width=max(1, int(width * SS)))

    def arc_top(self, x: float, y: float, w: float, h: float, color: tuple) -> None:
        """A rectangle with a round top."""
        r = w / 2
        self.oval(x + r, y + r, r, r, color)
        self.rect(x, y + r, w, h - r, color)

    def vgrad(self, x: float, y: float, w: float, h: float, top: tuple, bottom: tuple) -> None:
        steps = max(1, int(h * SS))
        for i in range(steps):
            t = i / max(1, steps - 1)
            self.d.rectangle((x * SS, y * SS + i, (x + w) * SS - 1, y * SS + i), fill=mix(top, bottom, t))

    def glow(self, x: float, y: float, radius: float, color: tuple = (255, 214, 150), strength: float = 0.55, haze: float = 0.05) -> None:
        """A pool of light: it brightens what's there, and adds a little haze of its own."""
        self.lights.append((x, y, radius, color, strength, haze))

    # --- Things rooms are made of ---

    def wall(self, top: tuple, bottom: tuple, until: float = FLOOR) -> None:
        self.vgrad(0, 0, W, until, top, bottom)

    def stripes(self, y0: float, y1: float, period: float, color: tuple, width: float = 2.0) -> None:
        x = period / 2
        while x < W:
            self.rect(x, y0, width, y1 - y0, color)
            x += period

    def damask(self, y0: float, y1: float, color: tuple, step: float = 22.0) -> None:
        row = 0
        y = y0 + step / 2
        while y < y1:
            x = (step / 2 if row % 2 else step) - step
            while x < W + step:
                self.poly([(x, y - 5), (x + 3.5, y), (x, y + 5), (x - 3.5, y)], color)
                self.oval(x, y - 7.5, 1.3, 1.3, color)
                self.oval(x, y + 7.5, 1.3, 1.3, color)
                x += step
            y += step * 0.72
            row += 1

    def panels(self, y0: float, y1: float, base: tuple, period: float = 40.0) -> None:
        """Wood panelling: boards with a bevel."""
        self.rect(0, y0, W, y1 - y0, base)
        x = 0.0
        while x < W:
            self.rect(x, y0, 1.2, y1 - y0, shade(base, 0.72))
            self.rect(x + 1.2, y0, 1.0, y1 - y0, shade(base, 1.14))
            self.rect(x + 6, y0 + 6, period - 12, y1 - y0 - 12, shade(base, 0.9))
            self.rect(x + 7.2, y0 + 7.2, period - 14.4, y1 - y0 - 14.4, shade(base, 1.04))
            x += period
        self.rect(0, y0, W, 2, shade(base, 1.2))

    def floor(self, near: tuple, far: tuple, planks: float = 0.0, edge: tuple | None = None) -> None:
        self.vgrad(0, FLOOR, W, H - FLOOR, far, near)
        self.rect(0, FLOOR - 5, W, 5, edge if edge is not None else shade(far, 0.6))
        self.rect(0, FLOOR - 5, W, 1, shade(edge if edge is not None else far, 1.3))
        if planks:
            # Boards running away from the viewer, fanning out from the middle.
            x = -W * 1.0
            while x < W * 2.0:
                self.line(240 + (x - 240) * 0.52, FLOOR, x, H, shade(near, 0.8), 0.6)
                x += planks
            for y in (FLOOR + 10, FLOOR + 26, FLOOR + 48):
                self.rect(0, y, W, 0.6, shade(near, 0.86))

    def checker(self, a: tuple, b: tuple) -> None:
        """Marble squares running away to a point above the floor line."""
        self.rect(0, FLOOR - 5, W, 5, shade(a, 0.5))
        self.rect(0, FLOOR - 5, W, 1, shade(a, 0.8))
        vx, vy = 240.0, FLOOR - 64.0
        rows = [FLOOR + (H - FLOOR) * (i / 5.0) ** 1.7 for i in range(6)]

        def across(base_x: float, y: float) -> float:
            return vx + (base_x - vx) * (y - vy) / (H - vy)

        for i in range(5):
            y0, y1 = rows[i], rows[i + 1]
            for j in range(-8, 9):
                x0, x1 = 240 + j * 64 - 32, 240 + j * 64 + 32
                self.poly([(across(x0, y0), y0), (across(x1, y0), y0), (across(x1, y1), y1), (across(x0, y1), y1)], a if (i + j) % 2 == 0 else b)

    def carpet(self, color: tuple, y0: float = FLOOR + 14, inset: float = 30.0, border: tuple | None = None) -> None:
        self.poly([(inset + 26, y0), (W - inset - 26, y0), (W - inset + 6, H), (inset - 6, H)], color)
        if border is not None:
            self.line(inset + 30, y0 + 3, W - inset - 30, y0 + 3, border, 1.2)
            self.line(inset + 30, y0 + 3, inset + 6, H, border, 1.2)
            self.line(W - inset - 30, y0 + 3, W - inset - 6, H, border, 1.2)

    def window(self, x: float, y: float, w: float, h: float, frame: tuple, arched: bool = False, panes: int = 2,
               sky: tuple = ((14, 20, 48), (38, 44, 86)), city: bool = True, sea: bool = False) -> None:
        """A window on the night: sky, a far ridge with lights, maybe the sea."""
        if arched:
            self.arc_top(x - 3, y - 3, w + 6, h + 6, frame)
            self.arc_top(x, y, w, h, sky[0])
        else:
            self.rect(x - 3, y - 3, w + 6, h + 6, frame)
        for i in range(int(h)):
            t = i / max(1.0, h - 1)
            inset = 0.0
            if arched and i < w / 2:
                inset = w / 2 - math.sqrt(max(0.0, (w / 2) ** 2 - (w / 2 - i) ** 2))
            self.rect(x + inset, y + i, w - inset * 2, 1, mix(sky[0], sky[1], t))
        for _ in range(int(w * h / 260)):
            sx = x + 3 + self.rand.random() * (w - 6)
            sy = y + (6 if arched else 2) + self.rand.random() * h * 0.45
            self.rect(sx, sy, 0.6, 0.6, (212, 216, 240))
        ridge = y + h * (0.62 if not sea else 0.5)
        if sea:
            self.vgrad(x, ridge, w, y + h - ridge, (20, 40, 78), (10, 20, 46))
            moon_x = x + w * 0.68
            self.oval(moon_x, y + h * 0.22, 5, 5, (236, 232, 204))
            for i in range(12):
                wy = ridge + 2 + i * (y + h - ridge - 3) / 12
                half = 2 + i * 1.1
                self.rect(moon_x - half, wy, half * 2, 0.8, (150, 168, 196))
        elif city:
            points = [(x, y + h), (x, ridge + 6)]
            steps = 8
            for i in range(steps + 1):
                points.append((x + w * i / steps, ridge + math.sin(i * 1.7 + x) * 5 + (i % 3) * 1.5))
            points.append((x + w, y + h))
            self.poly(points, (16, 16, 34))
            for _ in range(int(w * 0.35)):
                lx = x + 2 + self.rand.random() * (w - 5)
                ly = ridge + 8 + self.rand.random() * max(1.0, y + h - ridge - 12)
                self.rect(lx, ly, 1.2, 1.0, self.rand.choice([(255, 206, 120), (255, 168, 92), (255, 236, 190), (150, 190, 255)]))
        for i in range(1, panes):
            self.rect(x + w * i / panes - 0.8, y, 1.6, h, frame)
        self.rect(x, y + h * 0.5 - 0.8, w, 1.6, frame)
        self.rect(x - 5, y + h + 3, w + 10, 3, shade(frame, 1.15))

    def drapes(self, x: float, y: float, w: float, h: float, color: tuple) -> None:
        folds = int(w / 4)
        for i in range(folds):
            self.rect(x + i * w / folds, y, w / folds, h, shade(color, 1.0 + 0.16 * math.sin(i * 1.9)))
        self.rect(x - 1, y - 3, w + 2, 4, shade(color, 0.7))

    def painting(self, x: float, y: float, w: float, h: float, frame: tuple, colors: list, kind: str = "abstract") -> None:
        self.rect(x - 2.5, y - 2.5, w + 5, h + 5, shade(frame, 0.7))
        self.rect(x - 2, y - 2, w + 4, h + 4, frame)
        self.rect(x, y, w, h, colors[0])
        if kind == "abstract":
            for i in range(5):
                bw = w * (0.2 + self.rand.random() * 0.35)
                bh = h * (0.2 + self.rand.random() * 0.4)
                self.rect(x + self.rand.random() * (w - bw), y + self.rand.random() * (h - bh), bw, bh, colors[1 + i % (len(colors) - 1)])
        elif kind == "portrait":
            self.oval(x + w / 2, y + h * 0.4, w * 0.2, h * 0.2, colors[1])
            self.poly([(x + w * 0.2, y + h), (x + w * 0.35, y + h * 0.62), (x + w * 0.65, y + h * 0.62), (x + w * 0.8, y + h)], colors[2])
        elif kind == "diploma":
            for i in range(4):
                self.rect(x + 3, y + 4 + i * (h - 10) / 4, w - 6, 0.8, colors[1])
            self.oval(x + w - 5, y + h - 5, 2.2, 2.2, colors[2])
        elif kind == "sun":
            self.oval(x + w / 2, y + h / 2, h * 0.3, h * 0.3, colors[1])
            for i in range(3):
                self.rect(x, y + h * (0.62 + i * 0.13), w, h * 0.06, colors[2])

    def sconce(self, x: float, y: float, color: tuple = (226, 180, 96)) -> None:
        self.rect(x - 1.5, y, 3, 9, shade(color, 0.6))
        self.poly([(x - 5, y), (x + 5, y), (x + 3, y - 9), (x - 3, y - 9)], (255, 232, 180))
        self.glow(x, y - 6, 46, strength=0.5)

    def floor_lamp(self, x: float, h: float = 62.0, shade_color: tuple = (240, 214, 160)) -> None:
        base = FLOOR + 4
        self.oval(x, base, 7, 2.2, (60, 46, 36))
        self.rect(x - 1, base - h, 2, h, (150, 118, 62))
        self.poly([(x - 10, base - h), (x + 10, base - h), (x + 6.5, base - h - 14), (x - 6.5, base - h - 14)], shade_color)
        self.glow(x, base - h - 4, 78, strength=0.62)

    def table_lamp(self, x: float, y: float, shade_color: tuple = (240, 214, 160), base: tuple = (120, 86, 52)) -> None:
        self.oval(x, y - 4, 3.5, 4.5, base)
        self.rect(x - 0.8, y - 11, 1.6, 4, shade(base, 0.8))
        self.poly([(x - 8, y - 11), (x + 8, y - 11), (x + 5, y - 21), (x - 5, y - 21)], shade_color)
        self.glow(x, y - 14, 60, strength=0.56)

    def plant(self, x: float, height: float = 46.0, pot: tuple = (150, 86, 56)) -> None:
        base = FLOOR + 4
        self.poly([(x - 7, base - 13), (x + 7, base - 13), (x + 5, base), (x - 5, base)], pot)
        self.rect(x - 8, base - 14.5, 16, 2.5, shade(pot, 1.2))
        greens = [(40, 92, 58), (58, 120, 66), (30, 72, 50), (74, 136, 76)]
        for i in range(11):
            a = math.radians(-155 + i * 13 + self.rand.uniform(-6, 6))
            length = height * self.rand.uniform(0.6, 1.0)
            tip = (x + math.cos(a) * length * 0.7, base - 14 + math.sin(a) * length)
            midp = (x + math.cos(a) * length * 0.4, base - 14 + math.sin(a) * length * 0.72)
            c = greens[i % 4]
            self.poly([(x - 1.2, base - 14), (midp[0] - 3.2, midp[1]), tip, (midp[0] + 3.2, midp[1]), (x + 1.2, base - 14)], c)

    def books(self, x: float, y: float, w: float, h: float, wood: tuple, shelves: int = 4) -> None:
        self.rect(x - 2.5, y - 2.5, w + 5, h + 5, shade(wood, 0.7))
        self.rect(x, y, w, h, shade(wood, 0.45))
        spines = [(140, 58, 48), (60, 86, 120), (182, 142, 70), (70, 110, 80), (120, 70, 110), (200, 190, 168), (90, 60, 44), (46, 60, 78)]
        gap = h / shelves
        for s in range(shelves):
            sy = y + s * gap
            bx = x + 1
            while bx < x + w - 3:
                bw = self.rand.choice([2, 2.5, 3, 3.5, 4])
                bh = gap - 4 - self.rand.random() * 4
                if self.rand.random() < 0.93:
                    c = self.rand.choice(spines)
                    self.rect(bx, sy + gap - 2 - bh, min(bw, x + w - 1 - bx), bh, c)
                    self.rect(bx, sy + gap - 2 - bh, 0.6, bh, shade(c, 1.25))
                bx += bw + 0.4
            self.rect(x, sy + gap - 2, w, 2, wood)

    def desk(self, x: float, w: float, h: float = 30.0, wood: tuple = (110, 70, 44)) -> float:
        """A desk standing on the floor; returns the y of its top."""
        top = FLOOR + 6 - h
        self.rect(x, top, w, h, wood)
        self.rect(x, top, w, 3, shade(wood, 1.28))
        self.rect(x, top + 3, w, 1, shade(wood, 0.6))
        self.rect(x + 4, top + 8, w - 8, h - 12, shade(wood, 0.86))
        self.rect(x + 5, top + 9, w - 10, h - 14, shade(wood, 0.96))
        return top

    def side_table(self, x: float, w: float = 26.0, h: float = 26.0, wood: tuple = (110, 70, 44)) -> float:
        top = FLOOR + 5 - h
        self.rect(x - w / 2, top, w, 3, shade(wood, 1.2))
        self.rect(x - w / 2 + 2, top + 3, 2.4, h - 3, shade(wood, 0.8))
        self.rect(x + w / 2 - 4.4, top + 3, 2.4, h - 3, shade(wood, 0.8))
        self.rect(x - w / 2 + 2, top + h * 0.6, w - 4, 1.6, shade(wood, 0.7))
        return top

    def papers(self, x: float, y: float, w: float = 14.0, n: int = 4, color: tuple = (236, 228, 204)) -> None:
        for i in range(n):
            self.rect(x - w / 2 + (i % 2) * 1.2, y - 1.6 * (i + 1), w, 1.6, shade(color, 1.0 - 0.06 * (i % 2)))
        self.rect(x - w / 2 + 2, y - 1.6 * n + 0.4, w - 5, 0.5, (120, 120, 130))

    def book(self, x: float, y: float, w: float = 16.0, h: float = 5.0, cover: tuple = (120, 40, 44)) -> None:
        self.rect(x - w / 2, y - h, w, h, cover)
        self.rect(x - w / 2 + 1, y - h + 1, w - 1, h - 2, (236, 228, 204))
        self.rect(x - w / 2, y - h, w, 1, shade(cover, 1.3))

    def phone(self, x: float, y: float, color: tuple = (40, 40, 46)) -> None:
        self.poly([(x - 7, y), (x + 7, y), (x + 5, y - 6), (x - 5, y - 6)], color)
        self.oval(x, y - 3.2, 2.6, 2.2, (214, 208, 190))
        self.rect(x - 8, y - 9, 16, 3, color)
        self.oval(x - 7.5, y - 7.5, 2.4, 2.4, color)
        self.oval(x + 7.5, y - 7.5, 2.4, 2.4, color)

    def sofa(self, x: float, w: float, color: tuple, h: float = 30.0) -> None:
        base = FLOOR + 6
        self.rect(x, base - h, w, h - 10, shade(color, 0.86))
        self.rect(x + 3, base - h + 3, w - 6, h - 18, shade(color, 1.05))
        self.rect(x - 4, base - h * 0.62, 9, h * 0.62 - 3, color)
        self.rect(x + w - 5, base - h * 0.62, 9, h * 0.62 - 3, color)
        self.rect(x + 3, base - 15, w - 6, 9, shade(color, 1.16))
        self.rect(x + 3, base - 15, w - 6, 1, shade(color, 1.34))
        self.rect(x + w / 2 - 0.5, base - 15, 1, 9, shade(color, 0.86))
        self.rect(x, base - 6, w, 4, shade(color, 0.8))
        for lx in (x + 2, x + w - 5):
            self.rect(lx, base - 2, 3, 3, (60, 40, 30))

    def people(self, x: float, y: float, n: int, spread: float, tones: list) -> None:
        """A few guests far off, as soft shapes."""
        for i in range(n):
            px = x + i * spread + self.rand.uniform(-3, 3)
            c = self.rand.choice(tones)
            self.oval(px, y - 22, 3.2, 3.6, (196, 158, 128))
            self.poly([(px - 5, y), (px - 4, y - 17), (px + 4, y - 17), (px + 5, y)], c)

    # --- Finishing ---

    def finish(self, colors: int = 112) -> Image.Image:
        small = self.image.reduce(SS // 2)
        a = np.asarray(small).astype(np.float32) / 255.0
        hh, ww = a.shape[:2]
        yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float32)
        light = np.full((hh, ww, 3), self.ambient, np.float32)
        dx = (xx - ww / 2) / (ww / 2)
        dy = (yy - hh * 0.45) / (hh / 2)
        light *= (1.0 - self.vignette * np.clip(dx * dx * 0.55 + dy * dy * 0.45, 0, 1))[..., None]
        haze = np.zeros((hh, ww, 3), np.float32)
        for lx, ly, radius, color, strength, mist in self.lights:
            dist = np.sqrt((xx - lx * 2) ** 2 + ((yy - ly * 2) * 1.15) ** 2) / (radius * 2)
            fall = np.clip(1.0 - dist, 0, 1) ** 2
            tint = np.array(color, np.float32) / 255.0
            light += (fall * strength)[..., None] * tint
            haze += (fall * mist)[..., None] * tint
        out = np.clip(a * light + haze, 0, 1)
        image = Image.fromarray((out * 255).astype(np.uint8), "RGB")
        # A short palette, no dither: light falls off in bands, like cel paint.
        return image.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")


# --- The rooms ---------------------------------------------------------------

GOLD = (212, 170, 86)
BRASS = (186, 142, 62)


def gala() -> Image.Image:
    """The Hartwell ballroom: wine-red walls, tall windows on the city, a
    chandelier, the guest book on its stand and the coat check by the door."""
    r = Room(11)
    r.wall((104, 34, 46), (128, 46, 54))
    r.damask(8, 150, (142, 60, 62))
    r.rect(0, 150, W, 48, (70, 40, 34))
    r.panels(150, FLOOR - 5, (92, 54, 40), 48)
    r.rect(0, 148, W, 3, GOLD)
    r.rect(0, 0, W, 9, (58, 30, 30))
    r.rect(0, 9, W, 2, GOLD)
    for x in (188, 262):
        r.window(x, 34, 44, 102, (74, 44, 34), arched=True)
        r.drapes(x - 14, 26, 12, 118, (150, 34, 44))
        r.drapes(x + 46, 26, 12, 118, (150, 34, 44))
    # The chandelier.
    r.rect(246, 0, 1.5, 22, BRASS)
    r.poly([(222, 30), (272, 30), (262, 22), (232, 22)], BRASS)
    for i in range(7):
        cx = 224 + i * 7.7
        r.rect(cx - 0.6, 30, 1.2, 9 + (3 if i % 2 else 0), (232, 226, 210))
        r.oval(cx, 41 + (3 if i % 2 else 0), 1.6, 2.2, (255, 244, 214))
    r.glow(247, 34, 150, strength=0.6)
    # A long table of glasses, far side of the room.
    r.rect(196, 168, 112, 30, (236, 230, 216))
    r.rect(196, 168, 112, 3, (252, 248, 238))
    for i in range(5):
        gx = 232 + i * 8
        for level in range(3 - abs(2 - i)):
            r.rect(gx, 162 - level * 6, 5, 5, (240, 222, 150))
            r.rect(gx, 162 - level * 6, 5, 1, (255, 246, 210))
    r.rect(204, 160, 14, 8, (120, 150, 110))
    r.rect(286, 158, 4, 10, (40, 70, 50))
    # The guest book, open on a lectern under its own lamp.
    r.rect(140, 196, 22, 4, (70, 42, 30))
    r.poly([(146, 196), (156, 196), (154, 170), (148, 170)], (96, 60, 40))
    r.rect(147.5, 172, 1.4, 24, (126, 82, 54))
    r.poly([(132, 172), (170, 162), (170, 167), (132, 177)], (84, 52, 36))
    r.poly([(134, 170.6), (150, 166.4), (150, 160.4), (134, 164.6)], (244, 238, 216))
    r.poly([(151, 166.2), (168, 161.8), (168, 155.8), (151, 160.2)], (232, 224, 200))
    for k in range(3):
        r.line(136, 166.4 + k * 1.6, 148, 163.2 + k * 1.6, (150, 140, 124), 0.5)
        r.line(153, 162 + k * 1.6, 166, 158.6 + k * 1.6, (150, 140, 124), 0.5)
    r.line(160, 152, 166, 140, (70, 70, 80), 0.7)
    r.rect(172, 128, 1.6, 40, BRASS)
    r.line(172.8, 129, 160, 126, BRASS, 1.4)
    r.poly([(153, 126), (166, 126), (163, 133), (156, 133)], (240, 214, 150))
    r.glow(159, 146, 46, strength=0.6)
    # The coat check: a hatch in the wall, coats on a rail, a brass bell.
    r.rect(398, 96, 78, 78, (50, 30, 26))
    r.rect(402, 100, 70, 70, (34, 22, 22))
    r.rect(404, 106, 66, 2, BRASS)
    coats = [(60, 60, 70), (150, 120, 84), (200, 196, 186), (90, 40, 46), (40, 40, 48), (120, 96, 60), (70, 84, 96)]
    for i, c in enumerate(coats):
        cx = 409 + i * 9
        r.line(cx, 106, cx, 111, (160, 160, 168), 0.6)
        r.poly([(cx - 4.5, 114), (cx, 110), (cx + 4.5, 114), (cx + 4, 150 + (i % 3) * 4), (cx - 4, 150 + (i % 3) * 4)], c)
    r.rect(394, 170, 86, 8, (110, 70, 44))
    r.rect(394, 170, 86, 2, (150, 100, 62))
    r.rect(398, 178, 78, 22, (84, 52, 36))
    r.oval(440, 168, 4, 3, BRASS)
    r.rect(416, 84, 42, 11, (30, 20, 20))
    r.rect(417, 85, 40, 9, GOLD)
    for i, word_x in enumerate((421, 428, 435, 442, 449)):
        r.rect(word_x, 87, 4, 5, (58, 30, 30))
    r.glow(437, 120, 70, strength=0.42)
    r.plant(24, 58)
    r.plant(372, 50)
    r.sconce(112, 92)
    r.sconce(344, 92)
    r.floor((120, 78, 46), (98, 62, 40), planks=34, edge=(60, 36, 28))
    r.carpet((122, 30, 40), border=GOLD)
    return r.finish()


def club() -> Image.Image:
    """The racquet club's lobby: panelling, a wall of trophies, the front
    desk with the car register, glass doors on the lot and its gate."""
    r = Room(22)
    r.wall((206, 196, 162), (190, 180, 146))
    r.stripes(8, 132, 16, (196, 186, 150), 5)
    r.panels(132, FLOOR - 5, (106, 70, 44), 44)
    r.rect(0, 130, W, 3, (70, 44, 30))
    r.rect(0, 0, W, 8, (70, 88, 60))
    r.rect(0, 8, W, 2, (232, 222, 190))
    # The trophy case.
    r.rect(196, 44, 96, 84, (70, 44, 30))
    r.rect(200, 48, 88, 76, (40, 34, 36))
    for row in range(2):
        r.rect(200, 84 + row * 38, 88, 2, (110, 74, 48))
        for i in range(5):
            tx = 210 + i * 17
            ty = 84 + row * 38
            tall = 10 + ((i * 7 + row * 3) % 9)
            color = GOLD if (i + row) % 3 else (198, 200, 208)
            r.rect(tx - 2.5, ty - 3, 5, 3, shade(color, 0.6))
            r.rect(tx - 0.8, ty - 7, 1.6, 4, color)
            r.poly([(tx - 4, ty - 7 - tall), (tx + 4, ty - 7 - tall), (tx + 2, ty - 7), (tx - 2, ty - 7)], color)
            r.rect(tx - 4, ty - 7 - tall, 1.2, tall * 0.6, shade(color, 1.3))
    r.glow(244, 70, 80, strength=0.4)
    # Crossed racquets and a row of old photographs.
    for sx in (-1, 1):
        r.line(340 - sx * 11, 92, 340 + sx * 7, 66, (150, 104, 60), 1.4)
        r.oval(340 + sx * 11, 56, 7, 9.5, (150, 104, 60))
        r.oval(340 + sx * 11, 56, 5.4, 7.9, (214, 206, 176))
    for i in range(3):
        r.painting(112 + i * 28, 62 + (i % 2) * 6, 18, 22, (60, 40, 30), [(196, 186, 160), (90, 90, 96), (236, 236, 228)], "portrait")
    r.rect(118, 40, 70, 12, (70, 88, 60))
    r.poly([(118, 40), (188, 40), (180, 46), (188, 52), (118, 52)], (232, 222, 190))
    # The front desk, with the register open on it.
    top = r.desk(84, 104, 40, (96, 62, 40))
    r.rect(82, top - 2, 108, 3, (140, 96, 60))
    r.book(138, top - 2, 22, 5, (40, 70, 52))
    r.rect(128, top - 8.5, 20, 1.2, (240, 232, 208))
    r.table_lamp(104, top - 2, (120, 160, 110), BRASS)
    r.oval(170, top - 4, 3.5, 2.5, BRASS)
    # Glass doors on the car park at night, the gate booth and its barrier.
    r.rect(380, 62, 96, 138, (60, 40, 30))
    for i in range(2):
        dx = 384 + i * 46
        r.vgrad(dx, 66, 42, 132, (14, 20, 44), (30, 34, 60))
        r.rect(dx, 150, 42, 48, (26, 28, 36))
        r.rect(dx, 148, 42, 2, (60, 64, 76))
    r.rect(404, 124, 16, 26, (70, 70, 80))
    r.rect(406, 128, 12, 9, (255, 220, 140))
    r.rect(402, 121, 20, 3, (90, 90, 100))
    r.line(420, 142, 466, 138, (236, 236, 228), 1.4)
    for i in range(4):
        r.rect(428 + i * 10, 138.6 - i * 0.9, 5, 1.6, (200, 50, 46))
    for cx, c in ((392, (40, 40, 48)), (448, (130, 36, 40))):
        r.poly([(cx, 164), (cx + 5, 157), (cx + 19, 157), (cx + 24, 164), (cx + 24, 170), (cx, 170)], c)
        r.rect(cx + 6, 158.5, 12, 4, (60, 80, 110))
    r.rect(424, 66, 6, 132, (60, 40, 30))
    r.oval(421, 134, 1.6, 4, BRASS)
    r.oval(433, 134, 1.6, 4, BRASS)
    r.glow(412, 132, 40, (255, 210, 140), 0.4)
    # The gate man's clipboards, hung by the door.
    for i, cx in enumerate((362, 372)):
        r.rect(cx - 4.5, 150 + i * 3, 9, 13, (120, 84, 52))
        r.rect(cx - 3.5, 152 + i * 3, 7, 10, (240, 234, 214))
        r.rect(cx - 1.5, 149 + i * 3, 3, 2.4, (190, 190, 198))
        for k in range(3):
            r.rect(cx - 2.5, 154.5 + i * 3 + k * 2.4, 5, 0.6, (120, 120, 130))
    r.plant(26, 54, (70, 88, 60))
    r.floor_lamp(60, 64, (232, 222, 190))
    r.floor((58, 96, 70), (44, 78, 58), edge=(60, 40, 30))
    for i in range(9):
        r.line(240 + (i - 4) * 38, FLOOR, 240 + (i - 4) * 96, H, (50, 86, 62), 0.5)
    return r.finish()


def malibu() -> Image.Image:
    """Brandt's house on the beach: a picture window on the moonlit sea, a
    zodiac wheel, a telescope, and the telephone table by the door."""
    r = Room(33)
    r.wall((60, 44, 86), (78, 52, 96))
    r.stripes(8, FLOOR - 5, 30, (70, 50, 96), 10)
    r.rect(0, 0, W, 8, (34, 26, 52))
    r.rect(0, 8, W, 2, GOLD)
    r.window(150, 40, 150, 100, (44, 32, 62), panes=3, sea=True)
    # The zodiac wheel.
    cx, cy = 356, 84
    r.oval(cx, cy, 31, 31, GOLD)
    r.oval(cx, cy, 28.5, 28.5, (30, 28, 66))
    r.oval(cx, cy, 19, 19, GOLD)
    r.oval(cx, cy, 17.5, 17.5, (46, 38, 92))
    for i in range(12):
        a = i * math.tau / 12
        r.line(cx + math.cos(a) * 18, cy + math.sin(a) * 18, cx + math.cos(a) * 28, cy + math.sin(a) * 28, GOLD, 0.7)
        b = a + math.tau / 24
        r.oval(cx + math.cos(b) * 23.4, cy + math.sin(b) * 23.4, 1.8, 1.8, (236, 214, 150))
    r.oval(cx, cy, 6.5, 6.5, (240, 200, 110))
    for i in range(8):
        a = i * math.tau / 8
        r.line(cx + math.cos(a) * 8, cy + math.sin(a) * 8, cx + math.cos(a) * 13, cy + math.sin(a) * 13, (240, 200, 110), 0.9)
    r.glow(cx, cy, 60, (255, 200, 120), 0.3)
    # A star chart, a telescope at the window.
    r.painting(52, 50, 52, 40, GOLD, [(20, 22, 54), (236, 226, 190), (150, 170, 220)], "abstract")
    for i in range(14):
        r.oval(55 + r.rand.random() * 46, 53 + r.rand.random() * 34, 0.7, 0.7, (240, 236, 210))
    r.line(196, 196, 212, 150, (70, 60, 60), 1.2)
    r.line(228, 196, 212, 150, (70, 60, 60), 1.2)
    r.line(212, 196, 212, 150, (70, 60, 60), 1.2)
    r.line(196, 156, 236, 134, BRASS, 5)
    r.line(232, 136, 242, 130, (236, 214, 150), 6)
    # A low sofa and a lava lamp.
    r.sofa(244, 96, (190, 96, 40), 32)
    r.oval(274, 178, 9, 6, (120, 60, 130))
    r.oval(312, 178, 9, 6, (226, 178, 70))
    top = r.side_table(372, 22, 30, (70, 50, 40))
    r.poly([(368, top), (376, top), (374.5, top - 5), (369.5, top - 5)], BRASS)
    r.poly([(369.5, top - 5), (374.5, top - 5), (373.4, top - 22), (370.6, top - 22)], (236, 96, 70))
    r.oval(372, top - 10, 1.6, 2.4, (255, 190, 90))
    r.oval(371.6, top - 17, 1.2, 1.8, (255, 190, 90))
    r.glow(372, top - 12, 46, (255, 130, 90), 0.5)
    # The toll records, on a table by the chart.
    top = r.side_table(136, 32, 28, (70, 50, 40))
    r.papers(134, top, 20, 6)
    r.rect(140, top - 12, 9, 1.4, (236, 228, 204))
    r.table_lamp(124, top, (236, 190, 110), (120, 60, 130))
    # The telephone table by the door, with the reverse directory.
    r.rect(452, 70, 28, 130, (44, 32, 62))
    r.rect(456, 74, 24, 124, (86, 60, 50))
    r.oval(460, 138, 1.8, 1.8, BRASS)
    top = r.side_table(432, 30, 30, (70, 50, 40))
    r.phone(424, top, (150, 40, 44))
    r.book(440, top, 15, 7, (60, 60, 70))
    # Beads in the doorway on the left.
    for i in range(9):
        bx = 6 + i * 4.4
        for k in range(26):
            r.oval(bx, 14 + k * 7 + (i % 2) * 3.5, 1.1, 1.5, [(226, 178, 70), (236, 96, 70), (120, 60, 130)][(i + k) % 3])
    r.plant(104, 44, (120, 60, 130))
    r.floor((86, 54, 44), (66, 42, 40), planks=40, edge=(34, 26, 52))
    r.carpet((204, 110, 44), FLOOR + 12, 60, (236, 190, 110))
    return r.finish()


def office() -> Image.Image:
    """Dr. Sloane's consulting room: panelling, diplomas, a wall of books,
    her desk with the State Board's file on it, and the couch."""
    r = Room(44)
    r.wall((96, 108, 94), (110, 120, 102))
    r.panels(120, FLOOR - 5, (104, 68, 42), 52)
    r.rect(0, 118, W, 3, (64, 42, 28))
    r.rect(0, 0, W, 8, (64, 42, 28))
    r.books(212, 22, 104, 96, (96, 62, 40), 4)
    # A window with the blinds half down.
    r.window(346, 36, 58, 78, (64, 42, 28), city=True)
    for i in range(9):
        r.rect(346, 36 + i * 5, 58, 2.6, (226, 220, 200))
    r.rect(346, 34, 58, 3, (200, 194, 176))
    # Diplomas over the desk.
    for i, (dx, dy) in enumerate(((56, 40), (92, 40), (56, 70), (92, 70), (128, 54))):
        r.painting(dx, dy, 26, 20, (60, 40, 28) if i % 2 else GOLD, [(240, 234, 214), (150, 146, 136), (176, 50, 46)], "diploma")
    # The desk: a blotter, the file, a lamp, a telephone.
    top = r.desk(70, 124, 36, (88, 54, 36))
    r.rect(66, top - 2, 132, 3, (126, 82, 52))
    r.rect(104, top - 3.5, 46, 1.5, (40, 70, 60))
    r.rect(120, top - 6.5, 24, 3, (214, 180, 110))
    r.rect(121, top - 8, 22, 1.5, (240, 234, 214))
    r.rect(138, top - 9.4, 8, 1.4, (214, 180, 110))
    r.table_lamp(88, top - 2, (70, 130, 110), BRASS)
    r.phone(176, top - 2)
    r.rect(40, FLOOR - 40, 22, 46, (60, 38, 28))
    r.rect(36, FLOOR - 62, 30, 24, (70, 46, 32))
    # The couch, with a raised head and a pillow, and the doctor's chair behind it.
    base = FLOOR + 6
    r.rect(384, base - 50, 24, 44, (70, 46, 32))
    r.rect(387, base - 47, 18, 24, (104, 70, 48))
    r.rect(372, base - 20, 104, 15, (136, 66, 48))
    r.rect(372, base - 20, 104, 2.4, (176, 94, 68))
    r.poly([(440, base - 20), (468, base - 44), (478, base - 40), (478, base - 20)], (136, 66, 48))
    r.poly([(442, base - 20), (468, base - 42), (470, base - 39), (446, base - 20)], (176, 94, 68))
    r.oval(456, base - 27, 10, 5.5, (232, 220, 196))
    for bx in range(380, 440, 12):
        r.oval(bx, base - 12, 1.0, 1.0, (96, 44, 34))
    for lx in (376, 470):
        r.rect(lx, base - 5, 3.4, 6, (50, 32, 24))
    r.painting(422, 46, 46, 56, (60, 40, 28), [(226, 214, 190), (190, 96, 60), (70, 110, 110), (40, 40, 50)], "abstract")
    r.plant(340, 50, (96, 108, 94))
    r.floor_lamp(22, 66, (236, 214, 170))
    r.floor((112, 80, 56), (90, 64, 46), planks=36, edge=(64, 42, 28))
    r.carpet((70, 100, 96), FLOOR + 12, 44, (190, 176, 140))
    return r.finish()


def hotel() -> Image.Image:
    """The Harrow Grand's dining room, the anniversary dinner still on the
    tables: columns, the seating chart on its easel, the service elevator."""
    r = Room(55)
    r.wall((40, 60, 74), (52, 74, 86))
    r.damask(10, 138, (58, 84, 98), 26)
    r.rect(0, 138, W, 60, (206, 198, 184))
    for x in range(0, W, 60):
        r.rect(x, 140, 1, 53, (182, 172, 158))
    r.rect(0, 136, W, 3, GOLD)
    r.rect(0, 0, W, 10, (28, 40, 50))
    r.rect(0, 10, W, 2, GOLD)
    # The banner: fifty years.
    r.poly([(170, 20), (310, 20), (304, 31), (310, 42), (170, 42), (176, 31)], (150, 34, 50))
    r.rect(178, 23, 124, 1, GOLD)
    r.rect(178, 38, 124, 1, GOLD)
    # "50" in gold blocks.
    for (bx, by, bw, bh) in ((226, 26, 9, 2), (226, 26, 2.4, 6), (226, 30, 9, 2), (232.6, 30, 2.4, 6), (226, 34.4, 9, 2),
                             (243, 26, 9, 2), (243, 26, 2.4, 10.4), (249.6, 26, 2.4, 10.4), (243, 34.4, 9, 2)):
        r.rect(bx, by, bw, bh, GOLD)
    # Columns.
    for x in (92, 388):
        r.rect(x - 9, 12, 18, FLOOR - 16, (226, 220, 206))
        r.rect(x - 9, 12, 4, FLOOR - 16, (244, 240, 230))
        r.rect(x + 5, 12, 4, FLOOR - 16, (190, 182, 168))
        r.rect(x - 13, 12, 26, 6, (236, 230, 216))
        r.rect(x - 13, FLOOR - 12, 26, 8, (236, 230, 216))
    # The tables, dinner abandoned on them.
    for tx, n in ((204, 3), (296, 3)):
        r.oval(tx, 172, 36, 7, (244, 240, 232))
        r.poly([(tx - 36, 172), (tx + 36, 172), (tx + 31, 200), (tx - 31, 200)], (226, 220, 210))
        for i in range(n):
            px = tx - 20 + i * 20
            r.oval(px, 170.5, 5, 1.6, (255, 255, 250))
            r.rect(px + 6, 163, 1.4, 7, (240, 222, 150))
        r.rect(tx - 1, 156, 2, 14, BRASS)
        r.oval(tx, 154, 1.6, 2.4, (255, 236, 170))
        r.glow(tx, 156, 44, strength=0.42)
        for i in range(2):
            cx = tx - 30 + i * 60
            r.rect(cx - 5, 160, 10, 22, (150, 34, 50))
            r.rect(cx - 5, 160, 10, 2, GOLD)
    r.sconce(140, 92)
    r.sconce(340, 92)
    r.window(232, 58, 34, 68, (206, 198, 184), arched=True)
    # The seating chart on its easel.
    r.line(124, 200, 136, 142, (110, 74, 48), 1.4)
    r.line(150, 200, 138, 142, (110, 74, 48), 1.4)
    r.line(137, 204, 137, 150, (90, 60, 40), 1.2)
    r.rect(118, 134, 38, 46, (150, 34, 50))
    r.rect(120, 136, 34, 42, (244, 238, 220))
    r.rect(124, 139, 26, 2, (150, 34, 50))
    for row in range(2):
        for col in range(2):
            ox, oy = 128.5 + col * 17, 152 + row * 14
            r.oval(ox, oy, 5, 4, (206, 198, 184))
            for k in range(5):
                a = k * math.tau / 5
                r.oval(ox + math.cos(a) * 6.4, oy + math.sin(a) * 5.2, 0.9, 0.9, (90, 60, 40))
    r.rect(116, 180, 42, 2.4, (110, 74, 48))
    # The service elevator: a brass door, a dial above it, a keyhole beside.
    r.rect(416, 60, 52, 140, (120, 92, 44))
    r.rect(420, 64, 44, 134, BRASS)
    r.rect(441.4, 64, 1.2, 134, (110, 82, 36))
    for i in range(3):
        r.rect(424, 72 + i * 42, 14, 34, (204, 160, 78))
        r.rect(446, 72 + i * 42, 14, 34, (204, 160, 78))
    r.oval(442, 50, 12, 9, (120, 92, 44))
    r.oval(442, 50, 10, 7.4, (240, 232, 208))
    r.line(442, 53, 448, 46, (150, 34, 50), 1.0)
    for i in range(5):
        a = math.pi + i * math.pi / 4
        r.oval(442 + math.cos(a) * 8, 52 + math.sin(a) * 6, 0.7, 0.7, (60, 50, 40))
    r.rect(404, 128, 7, 12, (120, 92, 44))
    r.oval(407.5, 132, 1.6, 1.6, (40, 30, 24))
    r.rect(407, 133, 1, 4, (40, 30, 24))
    r.rect(424, 40, 0.1, 0.1, GOLD)
    r.glow(442, 52, 44, strength=0.4)
    r.plant(30, 56, (150, 34, 50))
    r.plant(356, 40, (150, 34, 50))
    r.checker((214, 206, 190), (58, 78, 90))
    r.carpet((150, 34, 50), FLOOR + 12, 70, GOLD)
    return r.finish()


def _street(r: Room, lamp_x: float, car: bool) -> None:
    """A street in the hills at night: the city below, palms, one lamp."""
    r.vgrad(0, 0, W, 90, (12, 14, 44), (44, 36, 88))
    r.vgrad(0, 90, W, 70, (44, 36, 88), (150, 74, 96))
    for _ in range(70):
        r.rect(r.rand.random() * W, r.rand.random() * 84, 0.8, 0.8, (226, 228, 248))
    r.oval(92, 40, 13, 13, (248, 240, 208))
    r.oval(98, 36, 12.5, 12.5, (20, 20, 56))
    # Far hills with a scatter of house lights, then the grid of the city.
    pts = [(0, 200), (0, 126)]
    for i in range(13):
        pts.append((i * 40, 120 + math.sin(i * 1.3) * 12 + (i % 2) * 6))
    pts.append((W, 200))
    r.poly(pts, (40, 30, 70))
    for _ in range(40):
        r.rect(r.rand.random() * W, 134 + r.rand.random() * 16, 1.4, 1.2, r.rand.choice([(255, 206, 120), (255, 236, 190)]))
    r.vgrad(0, 152, W, 46, (34, 26, 60), (22, 20, 46))
    for i in range(9):
        y = 155 + i * 4.6
        for _ in range(26 + i * 4):
            r.rect(r.rand.random() * W, y, 1.6 + r.rand.random(), 1.1, r.rand.choice([(255, 206, 120), (255, 168, 92), (255, 236, 190), (150, 190, 255), (255, 120, 100)]))
    # Palms.
    for px, ph in ((40, 118), (148, 96), (330, 110), (462, 126)):
        r.line(px, 200, px + 3, 200 - ph, (14, 10, 28), 2.4)
        for i in range(9):
            a = math.radians(-170 + i * 20)
            tip = (px + 3 + math.cos(a) * 24, 200 - ph + math.sin(a) * 12 + 9)
            midp = (px + 3 + math.cos(a) * 13, 200 - ph + math.sin(a) * 10 - 1)
            r.poly([(px + 2, 200 - ph), midp, tip, (midp[0], midp[1] + 4.5)], (14, 10, 28))
    # The kerb and the road, with the lamp's pool on it.
    r.rect(0, 196, W, 6, (92, 86, 110))
    r.rect(0, 196, W, 1.2, (136, 128, 150))
    r.vgrad(0, 202, W, 68, (62, 58, 82), (44, 40, 60))
    r.oval(lamp_x - 21, 238, 86, 22, (84, 76, 96))
    r.oval(lamp_x - 21, 238, 58, 14, (108, 96, 106))
    for i in range(6):
        r.rect(20 + i * 86, 258, 40, 2.2, (190, 176, 120))
    if car:
        # A convertible that has seen better decades.
        cx = 214
        r.oval(cx + 50, 246, 56, 5, (34, 30, 46))
        r.oval(cx + 16, 238, 9, 9, (20, 18, 26))
        r.oval(cx + 78, 238, 9, 9, (20, 18, 26))
        r.poly([(cx, 236), (cx + 2, 222), (cx + 30, 219), (cx + 40, 206), (cx + 66, 206), (cx + 74, 219), (cx + 96, 223), (cx + 98, 236)], (126, 146, 150))
        r.poly([(cx + 2, 222), (cx + 30, 219), (cx + 74, 219), (cx + 96, 223), (cx + 96, 226), (cx + 2, 226)], (154, 172, 172))
        r.poly([(cx + 42, 208), (cx + 64, 208), (cx + 70, 219), (cx + 34, 219)], (52, 60, 84))
        r.rect(cx + 52, 208, 1.4, 11, (126, 146, 150))
        r.rect(cx, 231, 98, 2, (186, 190, 184))
        r.oval(cx + 16, 238, 4, 4, (150, 150, 156))
        r.oval(cx + 78, 238, 4, 4, (150, 150, 156))
        r.rect(cx + 94, 224, 4, 3.4, (255, 232, 160))
        r.rect(cx, 224, 2.4, 3.4, (200, 60, 50))
        r.rect(cx + 12, 226, 16, 5, (106, 120, 122))
    # The lamp.
    r.rect(lamp_x - 1.5, 96, 3, 106, (56, 54, 72))
    r.line(lamp_x, 97, lamp_x - 20, 92, (56, 54, 72), 2.4)
    r.poly([(lamp_x - 28, 92), (lamp_x - 14, 92), (lamp_x - 17, 98), (lamp_x - 25, 98)], (255, 240, 190))
    r.glow(lamp_x - 21, 100, 46, (255, 220, 160), 0.6, 0.32)
    r.glow(lamp_x - 21, 200, 150, (255, 210, 150), 0.7, 0.1)


def night() -> Image.Image:
    r = Room(66)
    r.ambient = 0.8
    _street(r, 300, False)
    return r.finish()


def title() -> Image.Image:
    r = Room(77)
    r.ambient = 0.8
    r.vignette = 0.5
    _street(r, 420, True)
    return r.finish()


def desk() -> Image.Image:
    """The Lieutenant's desk, from above: wood, a coffee ring, an ashtray."""
    r = Room(88)
    r.ambient = 0.8
    r.rect(0, 0, W, H, (96, 62, 40))
    y = 0.0
    while y < H:
        r.rect(0, y, W, 0.8, (78, 50, 32))
        for _ in range(5):
            gx = r.rand.random() * W
            r.rect(gx, y + 4 + r.rand.random() * 22, 30 + r.rand.random() * 60, 0.6, (106, 70, 46))
        y += 34
    r.oval(440, 232, 16, 16, (60, 60, 68))
    r.oval(440, 232, 12, 12, (30, 30, 36))
    r.line(432, 228, 452, 220, (106, 74, 46), 3)
    r.oval(453, 219.6, 1.8, 1.8, (233, 113, 42))
    r.oval(40, 250, 13, 13, (70, 46, 32))
    r.oval(40, 250, 11.4, 11.4, (96, 62, 40))
    r.line(196, 258, 250, 262, (226, 190, 70), 2.2)
    r.poly([(250, 260.6), (256, 262.4), (250, 263.4)], (214, 180, 150))
    r.glow(240, 110, 260, (255, 226, 180), 0.5)
    return r.finish(48)


ROOMS = {"gala": gala, "club": club, "malibu": malibu, "office": office, "hotel": hotel, "night": night, "title": title, "desk": desk}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    names = [a for a in sys.argv[1:] if not a.startswith("-")] or list(ROOMS)
    for name in names:
        image = ROOMS[name]()
        image.save(OUT / f"{name}.png", optimize=True)
        print(f"{name}.png {image.size[0]}x{image.size[1]} {(OUT / f'{name}.png').stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
