"""Copy the art the dunderquest.com/flatmates/ page shows into the site.

The title art, each flatmate's standing frame, and the screenshots from
tests/shots/ (run tests/shots.tscn first). Writes ../../site/static/img/flatmates/,
which is committed, since tests/shots/ isn't.

    python tools/site_art.py
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[1] / "site" / "static" / "img" / "flatmates"
## The flatmate sheets are 16x24 frames side by side; the first is standing.
FRAME = (0, 0, 16, 24)
SHOTS = [f"stage{n}_start.png" for n in range(1, 7)] + ["stage1_card.png", "stage3_editor.png"]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "assets" / "backgrounds" / "title.png", OUT / "title.png")
    for who in ("clive", "jazz"):
        Image.open(ROOT / "assets" / "sprites" / f"{who}.png").crop(FRAME).save(OUT / f"{who}.png")
    for name in SHOTS:
        shutil.copyfile(ROOT / "tests" / "shots" / name, OUT / name)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
