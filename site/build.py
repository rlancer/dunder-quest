"""Build the Dunder Quest website into a static folder.

The site root is a splash of every game, with Curb Your Oxidation out
front; Dunder Quest's own page is `dunder-quest/`. Every lesson page comes from `data/lessons.json`, the same bank the game
reads, so the scrolls and the guardian's questions on the site are the ones
the player meets on the trail. The web export of the game goes in `play/`
beside the pages (`scripts/export_web.sh` puts it there). Flatmates.js, the
JavaScript game, gets its own page in `flatmates/` and its export in
`flatmates/play/`, and Curb Your Oxidation, the Rust game, the same in
`curb/` and `curb/play/`.

    python site/build.py build/site
    python site/build.py --play build/site/play/index.html
    python site/build.py --flatmates build/site/flatmates/play/index.html
    python site/build.py --curb build/site/curb/play/index.html
"""

from __future__ import annotations

import html
import io
import json
import keyword
import re
import shutil
import sys
import tokenize
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUEST = ROOT / "games" / "dunder-quest"
FLATMATES = ROOT / "games" / "flatmates"
CURB = ROOT / "games" / "curb"
SITE = Path(__file__).resolve().parent
REPO = "https://github.com/rlancer/dunder-quest"
## Social previews need absolute URLs, so every page points at production,
## even when built for the dev deploy.
SITE_URL = "https://dunderquest.com/"
## Cloudflare Web Analytics site token (dashboard: Analytics & Logs, Web
## Analytics). It's public, since it ships in every page. Empty leaves the
## beacon out.
CF_ANALYTICS_TOKEN = "6befdb51293b4efc966f8490afb169c8"
## The trailer on YouTube (built by tools/make_trailer.py). Dunder Quest's page
## shows its thumbnail and only loads the player once someone clicks it.
TRAILER_ID = "7a-I7FzQdD8"
## Flatmates.js's trailer, once it's on YouTube. Empty shows the thumbnail
## without a player.
FM_TRAILER_ID = "EJ2w4MgKSpU"
## Curb Your Oxidation's trailer, once it's on YouTube: paste its video ID
## here. Empty leaves the trailer off the /curb/ page.
CURB_TRAILER_ID = "QZsFLN5z7R4"
## The channel every trailer goes up on.
CHANNEL = "https://www.youtube.com/@dunderquest"
## A rolling release CI refreshes on every push to main.
DOWNLOADS = f"{REPO}/releases/download/builds"
RELEASE_PAGE = f"{REPO}/releases/tag/builds"

## Stage facts the lesson bank doesn't carry: names and map spots match
## `common/game_progression.gd` and `levels/world_map.gd`, and each puzzle
## is the gadget its `levels/level_0N.gd` builds. `x`/`y` place the marker on
## `static/img/trail_map.png`, the world map cropped 22px from the top.
## `wizard` is the guardian's name as it reads mid-sentence ("the Bridgekeeper").
STAGES: list[dict] = [
    {
        "id": 1, "slug": "shrubbery-wood", "name": "Shrubbery Wood", "wizard": "the Knight Who Says Mi",
        "x": 60, "y": 138, "tint": "#8cd9ff",
        "shot": "tour_amber_slice.png",
        "puzzle_title": "The slice bridge",
        "puzzle_code": "bridge = planks[?]\n# the pit is cells 1 to 10",
        "puzzle": "Near the end of the stage, a pit ten tiles wide is too far to jump. A ruler numbers its cells like a list, from 0 on the near edge to 11 on the far edge. Four slice blocks hang in front of it: 1:10, 1:11, 2:11 and :10. Bumping one lays planks on the cells that slice takes. A bridge holds only if it reaches both edges, so a slice that misses even one pit cell crumbles. (Over the start of the stage, a row of ? blocks under a slate reading row[2] hides a bonus scroll.)",
        "spoiler": "planks[1:11] takes cells 1 to 10, because a slice stops just before its second number. planks[1:10] stops at cell 9 and leaves a gap. For the bonus scroll, count from zero: row[2] is the third block.",
    },
    {
        "id": 2, "slug": "cheese-shoppe", "name": "The Cheese Shoppe", "wizard": "the Cheesemonger",
        "x": 130, "y": 110, "tint": "#f28cff",
        "shot": "tour_span_vault.png",
        "puzzle_title": "The hash vault",
        "puzzle_code": "bucket = rune_hash(key) % 4",
        "puzzle": "Two rune keys, \"brie\" and \"edam\", lie on the route. Near the end a vault door has one lock per key and four bucket blocks numbered 0 to 3. Store each key by bumping the bucket it hashes to. The vault's rune hash adds up the letter codes of the key (ord in Python), then % 4 picks the bucket.",
        "spoiler": "\"brie\" is 98 + 114 + 105 + 101 = 418, and 418 % 4 is 2. \"edam\" adds up to 407, and 407 % 4 is 3.",
    },
    {
        "id": 3, "slug": "cave-of-the-bunny", "name": "Cave of the Bunny", "wizard": "Tom the Enchanter",
        "x": 430, "y": 128, "tint": "#80ffa6",
        "shot": "tour_kiln_forge.png",
        "puzzle_title": "The loop lift",
        "puzzle_code": "for i in ?:\n    lift.rise()  # one notch\nA: range(1, 9, 3)\nB: range(4)\nC: range(10, 13)",
        "puzzle": "The cave wall is ten tiles of sheer brick. At its foot, an iron lift runs a for loop and rises one notch for every lap, and a gauge on the wall numbers the notches. Three range blocks each load a different range into the lift. Stand on the plate to run the loop and watch i count off each lap. You need four notches to jump onto the wall.",
        "spoiler": "range(4) runs four laps: 0, 1, 2, 3. The other two have bigger numbers but only three laps each: 1, 4, 7 and 10, 11, 12. Count the laps, not the size of the numbers.",
    },
    {
        "id": 4, "slug": "ministry-of-walks", "name": "Ministry of Walks", "wizard": "the Under-Minister",
        "x": 400, "y": 66, "tint": "#99c7ff",
        "shot": "tour_fork_gate_shut.png",
        "puzzle_title": "The truth gates",
        "puzzle_code": "if heat > 1 and heat != 3:\n    gate.open()\n\nif heat % 2 == 1 and not heat == 1:\n    gate.open()",
        "puzzle": "Two of the Ministry's gates, walls of glass bars too tall to jump, each stand on an if. A heat dial block in front of each gate turns heat through 0, 1, 2 and 3. The bars sink while the condition is True and rise again as soon as it turns False.",
        "spoiler": "The first gate opens at heat 2. The second opens only at heat 3.",
    },
    {
        "id": 5, "slug": "bridge-of-peril", "name": "Bridge of Peril", "wizard": "the Bridgekeeper",
        "x": 250, "y": 76, "tint": "#ff9e66",
        "shot": "tour_bridge_calls.png",
        "puzzle_title": "The span bridge",
        "puzzle_code": "def span(n):\n    return n * 2 + 4\nbridge = span(?)  # gap 14",
        "puzzle": "The chasm is fourteen tiles wide, too far for any jump. Four call blocks marked 3, 4, 5 and 6 hang before the edge. Bumping one calls span with that number and lays a plank bridge as long as the value it returns. Too short and the planks fall into the chasm. Too long and they hit the far cliff and break.",
        "spoiler": "span(5) returns 5 * 2 + 4 = 14, the exact width of the gap.",
    },
    {
        "id": 6, "slug": "castle-aargh", "name": "Castle Aargh", "wizard": "the Taunting Knight",
        "x": 96, "y": 36, "tint": "#ffd15c",
        "shot": "tour_crown_forges.png",
        "puzzle_title": "The comprehension stair",
        "puzzle_code": "A: [n for n in range(3)]\nB: [n * 2 for n in range(1, 5)]\nC: [n * 4 for n in range(3) if n != 1]\nsteps = ?  # up the wall",
        "puzzle": "The castle wall is eight tiles of sheer stone. Three blocks, A, B and C, each run a list comprehension. Bumping one builds a stair with one plank step for each number in its list, placed that many tiles high. A 0 builds nothing. Only one list gives you a stair you can climb.",
        "spoiler": "B builds [2, 4, 6, 8]: even steps, two tiles apart, all the way to the top.",
    },
]

## Every image the pages use, copied from the game's own art and test captures.
## `static/img` also holds the cropped world map and each guardian's first
## frame (`foes/foe_N.png`), both made by tools/make_og.py.
IMAGES = {
    "title_art.png": "assets/backgrounds/title_art.png",
    "squire.png": "assets/sprites/squire.png",
    "tin.png": "assets/sprites/tin.png",
    "bunny.png": "assets/sprites/bunny.png",
    "lantern_lit.png": "assets/sprites/lantern_lit.png",
    "castle_gate.png": "assets/sprites/castle_gate.png",
    "giant_foot.png": "assets/sprites/giant_foot.png",
    "grail.png": "assets/sprites/grail.png",
    "cache_stone.png": "assets/sprites/cache_stone.png",
    "clay_brick.png": "assets/sprites/clay_brick.png",
    "tile_ash.png": "assets/sprites/tile_ash.png",
    "icon.svg": "icon.svg",
}
SHOTS = [
    "tour_amber_scroll.png", "tour_amber_duel.png", "tour_amber_hint2.png",
    "tour_amber_book.png", "tour_bridge_built.png",
]
FONTS = {
    "PixelifySans.ttf": "assets/fonts/PixelifySans.ttf",
    "VT323.ttf": "assets/fonts/VT323.ttf",
}

BUILTINS = {"print", "range", "len", "sum", "min", "max", "sorted", "list", "dict",
            "set", "str", "int", "hash", "ord", "abs", "enumerate", "zip", "type", "bool"}


def esc(text: str) -> str:
    return html.escape(text, quote=True)


def highlight(code: str) -> str:
    """Python source as HTML spans. Falls back to plain text on a bad token."""
    lines = code.split("\n")
    marks: list[tuple[int, int, int, int, str]] = []
    try:
        for tok in tokenize.generate_tokens(io.StringIO(code + "\n").readline):
            cls = ""
            if tok.type == tokenize.COMMENT:
                cls = "c"
            elif tok.type == tokenize.STRING or tok.type in _fstring_types():
                cls = "s"
            elif tok.type == tokenize.NUMBER:
                cls = "n"
            elif tok.type == tokenize.NAME and (keyword.iskeyword(tok.string) or tok.string in ("True", "False", "None")):
                cls = "k"
            elif tok.type == tokenize.NAME and tok.string in BUILTINS:
                cls = "b"
            if cls:
                (sr, sc), (er, ec) = tok.start, tok.end
                marks.append((sr - 1, sc, er - 1, ec, cls))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        return esc(code)
    out: list[str] = []
    for row, line in enumerate(lines):
        spans = sorted((m for m in marks if m[0] == row and m[2] == row), key=lambda m: m[1])
        pos = 0
        buf = []
        for _, start, _, end, cls in spans:
            if start < pos:
                continue
            buf.append(esc(line[pos:start]))
            buf.append(f'<span class="{cls}">{esc(line[start:end])}</span>')
            pos = end
        buf.append(esc(line[pos:]))
        out.append("".join(buf))
    return "\n".join(out)


def _fstring_types() -> tuple[int, ...]:
    return tuple(getattr(tokenize, name) for name in ("FSTRING_START", "FSTRING_MIDDLE", "FSTRING_END") if hasattr(tokenize, name))


def code_block(code: str, label: str = "") -> str:
    head = f'<figcaption>{esc(label)}</figcaption>' if label else ""
    return f'<figure class="code">{head}<pre><code>{highlight(code)}</code></pre></figure>'


def stage_url(stage: dict, prefix: str) -> str:
    return f"{prefix}lessons/{stage['slug']}/"


## The logo, `__dunder_quest__`: the name written as a real Python dunder.
## Screen readers get the plain name. On a narrow screen it breaks after
## `dunder_`.
WORDMARK = ('<span class="wordmark"><span class="sr">Dunder Quest</span>'
            '<span aria-hidden="true"><i>__</i>dunder_<wbr>quest<i>__</i></span></span>')

## The site root is a splash of every game; Dunder Quest's own page is
## `dunder-quest/`, and its pages' logo goes there.
QUEST_PAGE = "dunder-quest/"
NAV = [("lessons/", "Lessons"), ("guide/", "How to play"), (f"{QUEST_PAGE}#download", "Download")]
HOME_NAV = [("curb/", "Curb Your Oxidation"), (QUEST_PAGE, "Dunder Quest"), ("flatmates/", "Flatmates.js")]
FRANKLIN = "&family=Libre+Franklin:ital,wght@0,400..900;1,400"


def head_tags(title: str, description: str, path: str | None, image: str, alt: str) -> str:
    """Social preview and analytics tags. `path` is the page's address under
    the site root, or None for pages with no address of their own (the 404)."""
    url = f"{SITE_URL}{path}" if path is not None else ""
    tags = [
        f'<link rel="canonical" href="{url}">' if url else "",
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Dunder Quest">',
        f'<meta property="og:title" content="{esc(title)}">',
        f'<meta property="og:description" content="{esc(description)}">',
        f'<meta property="og:url" content="{url}">' if url else "",
        f'<meta property="og:image" content="{SITE_URL}static/img/og/{image}">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        f'<meta property="og:image:alt" content="{esc(alt)}">',
        f'<meta property="og:logo" content="{SITE_URL}static/img/og/logo.png">',
        '<meta name="twitter:card" content="summary_large_image">',
        '<meta name="theme-color" content="#15122a">',
    ]
    if CF_ANALYTICS_TOKEN:
        tags.append(f"""<script defer src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon='{{"token": "{CF_ANALYTICS_TOKEN}"}}'></script>""")
    return "\n".join(t for t in tags if t)


def cap(text: str) -> str:
    """A guardian's name at the start of a line: "the Bridgekeeper" -> "The Bridgekeeper"."""
    return text[:1].upper() + text[1:]


HOME_ALT = "Dunder Quest title art: a squire clapping coconut halves looks out over a misty valley toward a shining castle."


def page(title: str, body: str, prefix: str, active: str = "", description: str = "", scripts: str = "",
         path: str | None = None, image: str = "home.png", image_alt: str = HOME_ALT,
         nav: list[tuple[str, str]] = NAV, brand: str = QUEST_PAGE, play: str = "play/", fonts: str = "",
         full_title: str = "", foot: str = "") -> str:
    links = []
    for href, label in nav:
        target = f"{prefix}{href}"
        current = ' aria-current="page"' if active == href else ""
        links.append(f'<a href="{target}"{current}>{label}</a>')
    full_title = full_title or ("Dunder Quest" if not title else f"{title} · Dunder Quest")
    desc = description or "Dunder Quest is a pixel-art platformer that teaches Python. Play it in your browser or download it."
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(full_title)}</title>
<meta name="description" content="{esc(desc)}">
{head_tags(full_title, desc, path, image, image_alt)}
<link rel="icon" href="{prefix}static/img/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400{fonts}&display=swap" rel="stylesheet">
<link rel="stylesheet" href="{prefix}static/style.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="{prefix}{brand}"><img src="{prefix}static/img/squire.png" alt="" width="16" height="24">{WORDMARK}</a>
  <nav aria-label="Site">{"".join(links)}</nav>
  <a class="btn btn-small" href="{prefix}{play}">Play</a>
</header>
<main id="main">
{body}
</main>
<footer class="foot">
  <p><img src="{prefix}static/img/tin.png" alt="" width="12" height="12"> {foot or "Dunder Quest. A squire's quest for the Grail, and six lessons of Python on the way."}</p>
  <p class="fine">Python is named after Monty Python, so the quest is a Holy Grail homage. Python programmers call names like <code>__init__</code> “dunders”, short for <b>d</b>ouble <b>under</b>score. Say <code>__quest__</code> out loud and you get the name.</p>
  <p><a href="{prefix}">All games</a> · <a href="{prefix}{QUEST_PAGE}">Dunder Quest</a> · <a href="{prefix}play/">Play in your browser</a> · <a href="{prefix}lessons/">Lessons</a> · <a href="{prefix}guide/">How to play</a> · <a href="{prefix}flatmates/">Flatmates.js</a> · <a href="{prefix}curb/">Curb Your Oxidation</a> · <a href="{CHANNEL}">YouTube</a> · <a href="{REPO}">Source on GitHub</a></p>
  <p><a class="help" href="{prefix}brand/" title="The brand kit">&gt;&gt;&gt; help(dunder_quest)</a></p>
</footer>
{scripts}
</body>
</html>
"""


def downloads_section(prefix: str) -> str:
    rows = [
        ("Windows", "dunder-quest-windows.zip", "64-bit. Unzip and run <code>Dunder Quest.exe</code>. If SmartScreen warns about an unknown app, choose <em>More info</em>, then <em>Run anyway</em>. The build isn't code-signed."),
        ("macOS", "dunder-quest-macos.zip", "Universal, so it runs on Apple silicon and Intel. Unzip and move the app to Applications. The first time, right-click it and choose <em>Open</em>, because the build isn't notarized."),
        ("Linux", "dunder-quest-linux.zip", "x86_64. Unzip, then run <code>./dunder-quest.x86_64</code>. If it won't start, run <code>chmod +x</code> on the file first."),
    ]
    items = "".join(
        f'<li><a class="dl" href="{DOWNLOADS}/{file}"><span class="dl-os">{os_name}</span><span class="dl-file">{file}</span></a><p>{note}</p></li>'
        for os_name, file, note in rows
    )
    return f"""
<section class="section" id="download" aria-labelledby="dl-h">
  <p class="kicker">Download</p>
  <h2 id="dl-h">Play without a browser</h2>
  <p class="lede">The desktop builds are the same game, run natively instead of in WebAssembly. They start faster, have no audio unlock step, and keep your save in a normal file instead of browser storage.</p>
  <ul class="downloads">{items}</ul>
  <p class="fine">CI rebuilds these every time the game changes on main. SHA-256 checksums are on the <a href="{RELEASE_PAGE}">release page</a>.</p>
</section>"""


def build_home(bank: dict, prefix: str = "") -> str:
    markers = "".join(
        f'<a class="pin" href="{stage_url(s, prefix)}" style="left:{s["x"] / 480 * 100:.3f}%;top:{s["y"] / 168 * 100:.3f}%;--tint:{s["tint"]}">'
        f'<span class="pin-label"><b>{s["id"]} · {esc(s["name"])}</b>{esc(bank[str(s["id"])]["topic"])}</span></a>'
        for s in STAGES
    )
    trail_list = "".join(
        f'<li><a href="{stage_url(s, prefix)}"><span class="tl-name">{esc(s["name"])}</span>'
        f'<span class="tl-topic">{esc(bank[str(s["id"])]["topic"])}</span></a></li>'
        for s in STAGES
    )
    total_q = sum(len(v["questions"]) for v in bank.values())
    total_s = sum(len(v["scrolls"]) for v in bank.values())
    body = f"""
<section class="hero">
  <img class="hero-art" src="{prefix}static/img/title_art.png" alt="Pixel art of a small squire with coconut halves on a cliff, looking out over a misty valley toward a shining castle" width="480" height="270">
  <div class="hero-copy">
    <p class="prompt" aria-hidden="true">&gt;&gt;&gt; squire.__quest__()</p>
    <h1>{WORDMARK}</h1>
    <p class="tag">A platformer where every stage teaches you a piece of Python.</p>
    <p class="hero-sub">Guide a squire across six stages to the Grail. Read the lore scrolls on the way, and use real code to open the path through each stage. Then duel the guardian at the exit, from the Knight Who Says Mi to the Bridgekeeper: jump into the block with the right answer while you dodge his spells.</p>
    <div class="cta">
      <a class="btn" href="{prefix}play/">Play in your browser</a>
      <a class="btn btn-ghost" href="#download">Download for desktop</a>
      <a class="btn btn-ghost" href="#trailer">Watch the trailer</a>
    </div>
    <p class="fine">Keyboard, gamepad or touch. On a phone, turn it sideways and use the on-screen buttons.</p>
  </div>
</section>

<section class="section" id="trailer" aria-labelledby="trailer-h">
  <p class="kicker">The trailer</p>
  <h2 id="trailer-h">One minute on the trail</h2>
  <a class="trailer" href="https://www.youtube.com/watch?v={TRAILER_ID}" data-yt="{TRAILER_ID}">
    <img src="{prefix}static/img/trailer.png" alt="Trailer thumbnail: Tom the Enchanter's duel on print(list(range(4))), under the Dunder Quest wordmark" width="1920" height="1080" loading="lazy">
    <span class="trailer-play" aria-hidden="true"></span>
    <span class="sr">Play the Dunder Quest trailer</span>
  </a>
  <p class="fine">More on the channel: <a href="{CHANNEL}">youtube.com/@dunderquest</a>.</p>
</section>

<section class="section" aria-labelledby="trail-h">
  <p class="kicker">The trail</p>
  <h2 id="trail-h">Six stages, six lessons</h2>
  <p class="lede">Each stop on the map is a Python topic, and they build on each other: lists first, comprehensions last. Pick a stage to read its lesson and practice its trial here on the site.</p>
  <div class="map">
    <img src="{prefix}static/img/trail_map.png" alt="The Dunder Quest world map: six stages across a storybook kingdom, from Shrubbery Wood to Castle Aargh" width="480" height="168">
    {markers}
  </div>
  <ol class="trail-list">{trail_list}</ol>
</section>

<section class="section" aria-labelledby="stage-h">
  <p class="kicker">Inside a stage</p>
  <h2 id="stage-h">Learn it, use it, prove it</h2>
  <ol class="loop">
    <li><img src="{prefix}static/img/shots/tour_amber_scroll.png" alt="A lore scroll card titled Counting from Zero, showing a short list example" width="480" height="270" loading="lazy">
      <h3>Read the scrolls</h3><p>Lore scrolls lie along the route. Touch one and it opens a card with a few lines of code and the idea behind them. Every scroll you read goes into your Spellbook.</p></li>
    <li><img src="{prefix}static/img/shots/tour_bridge_built.png" alt="A plank bridge built by calling span(5) across the Bridge of Peril chasm" width="480" height="270" loading="lazy">
      <h3>Code the way forward</h3><p>The only way through each stage is a gadget that runs real Python. You slice planks into a bridge, store keys in hash buckets, load a loop into a lift, or call the function that builds a bridge the exact length of the gap. Only the right code gets you across.</p></li>
    <li><img src="{prefix}static/img/shots/tour_amber_duel.png" alt="The Knight Who Says Mi's duel: his question across the top of the screen and four lettered answer blocks over the arena floor" width="480" height="270" loading="lazy">
      <h3>Duel the guardian</h3><p>A guardian holds every exit. His question shows at the top of the screen, and you answer by jumping into the lettered block while you dodge his spells. Each right answer breaks a ward. A wrong one gets you zapped and a new question. He'll give you a hint if you ask.</p></li>
  </ol>
  <p class="count"><b>{total_s}</b> lore scrolls · <b>{total_q}</b> trial questions · every snippet checked against real Python</p>
</section>

<section class="section" aria-labelledby="fm-h">
  <p class="kicker">The second game</p>
  <h2 id="fm-h">Flatmates.js teaches JavaScript</h2>
  <a class="next-game" href="{prefix}flatmates/">
    <img src="{prefix}static/img/og/flatmates.png" alt="Flatmates.js: two flatmates by their front door on a Croydon tower block landing at dusk" width="1200" height="630" loading="lazy">
    <span><b>Two flatmates. Two points of view. One of them runs your JavaScript.</b>
    Swap between Clive and Jazz across six stops in Croydon, from calling a method to awaiting two promises, and script the one you aren't playing.
    <span class="next-go">Meet the flatmates →</span></span>
  </a>
</section>

<section class="section" aria-labelledby="cy-h">
  <p class="kicker">The third game</p>
  <h2 id="cy-h">Curb Your Oxidation teaches Rust</h2>
  <a class="next-game next-curb" href="{prefix}curb/">
    <img src="{prefix}static/img/og/curb.png" alt="Curb Your Oxidation: a black title card, the name in yellow serif, over a palm-lined Westside street at sunset" width="1200" height="630" loading="lazy">
    <span><b>The borrow checker is the unwritten social contract.</b>
    Ten petty disputes on the Westside, from a second latte to a houseguest who won't leave, each settled by a Rust program, from <code>let mut</code> to lifetimes.
    <span class="next-go">Meet Barry →</span></span>
  </a>
</section>
{downloads_section(prefix)}
"""
    return page("", body, prefix, scripts=f'<script src="{prefix}static/trailer.js"></script>', path=QUEST_PAGE)


SPLASH_DESC = ("Free pixel-art games that teach real programming: Rust in Curb Your Oxidation, Python in Dunder Quest "
               "and JavaScript in Flatmates.js. Play them in your browser.")


def build_splash(prefix: str = "") -> str:
    """The site root: every game, with Curb Your Oxidation out front on a
    title card of its own. Each game's full page is a click away."""
    cy = f"{prefix}static/img/curb/"
    beats = [("03_pad.png", "Write the plan", "Barry's legal pad open on gift.rs, with a blank picked out and three options below"),
             ("03_rant.png", "Get interrupted", "Sharon bursting in with error[E0382]: borrow of moved value"),
             ("03_run.png", "Watch it happen", "The plan playing out for real while the code highlights Sharon's println! line")]
    strip = "".join(
        f'<li><img src="{cy}{file}" alt="{esc(alt)}" width="480" height="270" loading="lazy"><span>{label}</span></li>'
        for file, label, alt in beats)
    games = [
        ("game-dq", "Learn Python", "Dunder Quest", f"{prefix}{QUEST_PAGE}", f"{prefix}play/", "home.png", HOME_ALT,
         "A platformer on a very silly quest for the Grail. Slice a list to lay a bridge, loop a lift up a cave wall, "
         "then duel the Bridgekeeper by jumping into the right answer. Six stages, lists to comprehensions.",
         "Meet the squire"),
        ("game-fm", "Learn JavaScript", "Flatmates.js", f"{prefix}flatmates/", f"{prefix}flatmates/play/", "flatmates.png", FLATMATES_ALT,
         "Two mismatched flatmates in a very small Croydon flat. Swap between Clive and Jazz across six stops, from "
         "calling a method to awaiting two promises, and script the one you aren't playing.",
         "Meet the flatmates"),
    ]
    cards = "".join(f"""
    <li class="game {cls}">
      <a class="game-art" href="{about}"><img src="{prefix}static/img/og/{og}" alt="{esc(alt)}" width="1200" height="630" loading="lazy"></a>
      <div class="game-copy">
        <p class="kicker">{kick}</p>
        <h3><a href="{about}">{name}</a></h3>
        <p>{blurb}</p>
        <div class="cta"><a class="btn btn-small" href="{play}">Play {name}</a><a class="game-more" href="{about}">{more} →</a></div>
      </div>
    </li>""" for cls, kick, name, about, play, og, alt, blurb, more in games)
    body = f"""
<section class="splash-intro">
  <p class="prompt" aria-hidden="true">&gt;&gt;&gt; help(games)</p>
  <h1>{WORDMARK}</h1>
  <p class="tag">Pixel-art games that teach real programming. Free, in your browser.</p>
</section>

<section class="feature" aria-labelledby="cy-h">
  <div class="feature-in">
    <div class="feature-copy">
      <p class="feature-kick">New · Learn Rust</p>
      <h2 id="cy-h">Curb Your Oxidation</h2>
      <p class="feature-tag">The borrow checker is the unwritten social contract.</p>
      <p>Barry Danvers lives by rules nobody else has heard of. Ten petty disputes on the Westside, over a latte, a lawnmower or the last shrimp, each settled by a short Rust program on his yellow legal pad, from <code>let mut</code> to lifetimes. Break the rules and Sharon interrupts at the exact line, with the real rustc error.</p>
      <div class="cta">
        <a class="btn" href="{prefix}curb/play/">Play Curb Your Oxidation</a>
        <a class="btn btn-ghost" href="{prefix}curb/">Meet Barry</a>
      </div>
    </div>
    <div class="feature-media">
      {trailer_player(CURB_TRAILER_ID, f"{cy}trailer.png", CURB_THUMB_ALT, "Curb Your Oxidation")}
    </div>
  </div>
  <ol class="feature-strip">{strip}</ol>
</section>

<section class="section" aria-labelledby="more-h">
  <p class="kicker">More games</p>
  <h2 id="more-h">Prefer Python, or JavaScript?</h2>
  <ul class="games">{cards}
  </ul>
  <p class="count">Every snippet in every game is checked against the real thing: Python, Node and rustc. Trailers for all three are on <a href="{CHANNEL}">youtube.com/@dunderquest</a>.</p>
</section>
"""
    ## Links to the old home's sections (in trailer descriptions, for one) now
    ## belong to Dunder Quest's page.
    old = f'<script>if (/^#(download|trailer)$/.test(location.hash)) location.replace("{prefix}{QUEST_PAGE}" + location.hash);</script>'
    return page("", body, prefix, description=SPLASH_DESC, path="", nav=HOME_NAV, brand="", play="curb/play/",
                fonts=FRANKLIN, full_title="Dunder Quest · Games that teach programming",
                foot="Dunder Quest. Pixel-art games that teach Python, JavaScript and Rust.",
                scripts=f'{old}\n<script src="{prefix}static/trailer.js"></script>')


def scroll_card(scroll: dict, topic: str) -> str:
    raises = scroll.get("raises")
    note = f'<p class="raises">This code stops with <code>{esc(raises)}</code>, and that error is the point of the scroll.</p>' if raises else ""
    return f"""<article class="scroll" id="{esc(scroll['id'])}">
  <p class="scroll-kick">Lore scroll · {esc(topic)}</p>
  <h3>{esc(scroll['title'])}</h3>
  {code_block(chr(10).join(scroll['code']))}
  <p class="insight">{esc(scroll['insight'])}</p>{note}
</article>"""


def build_lesson(stage: dict, lesson: dict, prefix: str) -> str:
    idx = stage["id"] - 1
    prev_s = STAGES[idx - 1] if idx > 0 else None
    next_s = STAGES[idx + 1] if idx + 1 < len(STAGES) else None
    scrolls = "".join(scroll_card(s, lesson["topic"]) for s in lesson["scrolls"])
    titles = {s["id"]: s["title"] for s in lesson["scrolls"]}
    insights = {s["id"]: s["insight"] for s in lesson["scrolls"]}
    questions = [
        {
            "code": highlight("\n".join(q["code"])),
            "prompt": q["prompt"],
            "options": q["options"],
            "answer": q["answer"],
            "explanation": q["explanation"],
            "hint": q.get("hint", ""),
            "scroll": titles.get(q.get("scroll", ""), ""),
            "insight": insights.get(q.get("scroll", ""), ""),
        }
        for q in lesson["questions"]
    ]
    trial = {"wizard": cap(stage["wizard"]), "trial": lesson["trial"], "questions": questions}
    data = json.dumps(trial, ensure_ascii=False).replace("</", "<\\/")
    pager = '<nav class="pager" aria-label="Lessons">'
    pager += f'<a href="{stage_url(prev_s, prefix)}" rel="prev"><small>Previous stage</small>{esc(prev_s["name"])}</a>' if prev_s else "<span></span>"
    pager += f'<a href="{stage_url(next_s, prefix)}" rel="next"><small>Next stage</small>{esc(next_s["name"])}</a>' if next_s else f'<a href="{prefix}play/" rel="next"><small>Finished the trail?</small>Play the game</a>'
    pager += "</nav>"
    body = f"""
<article class="lesson" style="--tint:{stage['tint']}">
  <header class="lesson-head">
    <p class="kicker">Stage {stage['id']} · {esc(stage['name'])}</p>
    <h1>{esc(lesson['topic'])}</h1>
    <blockquote class="taunt"><img src="{prefix}static/img/foes/foe_{stage['id']}.png" alt="" width="36" height="56"><p>“{esc(lesson['taunt'])}”<cite>{esc(cap(stage['wizard']))}</cite></p></blockquote>
  </header>

  <section class="section" aria-labelledby="scrolls-h">
    <h2 id="scrolls-h">Scrolls on the trail</h2>
    <p class="lede">These are the {len(lesson['scrolls'])} lore scrolls you'll find in {esc(stage['name'])}, in the order the lesson teaches them. The comment after each <code>print</code> shows what it outputs.</p>
    <div class="scrolls">{scrolls}</div>
  </section>

  <section class="section puzzle" aria-labelledby="puzzle-h">
    <h2 id="puzzle-h">The stage puzzle: {esc(stage['puzzle_title'])}</h2>
    <div class="puzzle-grid">
      <img src="{prefix}static/img/shots/{stage['shot']}" alt="In-game view of {esc(stage['puzzle_title'])} in {esc(stage['name'])}" width="480" height="270" loading="lazy">
      <div>
        <p>{esc(stage['puzzle'])}</p>
        {code_block(stage['puzzle_code'], 'Slate in the stage')}
        <details><summary>Show the answer</summary><p>{esc(stage['spoiler'])}</p></details>
      </div>
    </div>
  </section>

  <section class="section" aria-labelledby="trial-h">
    <h2 id="trial-h">Practice {esc(stage['wizard'])}'s trial</h2>
    <p class="lede">In the game, {esc(stage['wizard'])} duels you in a sealed arena. His question shows across the top of the screen, and you answer by jumping up into the lettered block, A to D, while you dodge his spells. You need {lesson['trial']} right answers to banish him. These are his questions, drawn from all {len(questions)} in his bank. The hints work the same as in the game: ask once for his riddle, and ask again for him to rule out a wrong answer.</p>
    <div class="trial" data-trial>
      <noscript><p>The practice trial needs JavaScript. You can still play the game to sit the real one.</p></noscript>
    </div>
    <script type="application/json" id="trial-data">{data}</script>
  </section>
  {pager}
</article>"""
    return page(
        f"{lesson['topic']} ({stage['name']})", body, prefix, "lessons/",
        f"Stage {stage['id']} of Dunder Quest teaches {lesson['topic']}: the lore scrolls, the stage puzzle, and a practice run of {stage['wizard']}'s trial.",
        f'<script src="{prefix}static/trial.js"></script>',
        path=f"lessons/{stage['slug']}/", image=f"{stage['slug']}.png",
        image_alt=f"Stage {stage['id']}, {stage['name']}: {lesson['topic']}, with {stage['wizard']}'s duel question on screen.",
    )


def build_lessons_index(bank: dict, prefix: str) -> str:
    items = []
    for stage in STAGES:
        lesson = bank[str(stage["id"])]
        scroll_names = ", ".join(esc(s["title"]) for s in lesson["scrolls"])
        items.append(f"""<li style="--tint:{stage['tint']}"><a href="{stage_url(stage, prefix)}">
  <span class="li-stage">Stage {stage['id']} · {esc(stage['name'])}</span>
  <span class="li-topic">{esc(lesson['topic'])}</span>
  <span class="li-scrolls">{scroll_names}</span>
  <span class="li-meta">{len(lesson['scrolls'])} scrolls · {len(lesson['questions'])} questions · {esc(cap(stage['wizard']))}</span>
</a></li>""")
    body = f"""
<section class="section page-head">
  <p class="kicker">Lessons</p>
  <h1>The Python you learn on the trail</h1>
  <p class="lede">Every scroll, puzzle and guardian question from the game, one stage per page. Read them before you play, or come back after a stage to review. All the code is plain Python 3, so you can paste any snippet into a Python prompt and run it.</p>
</section>
<ol class="lesson-list">{"".join(items)}</ol>"""
    return page("Lessons", body, prefix, "lessons/", "All six Python lessons from Dunder Quest: lists, dictionaries, loops, conditions, functions and comprehensions.",
                path="lessons/", image="lessons.png", image_alt="The six Python topics in Dunder Quest, one per stage.")


def build_guide(prefix: str) -> str:
    controls = [
        ("Move", "A / D or ← / →", "D-pad or left stick", "Arrow buttons, bottom left"),
        ("Jump", "Space, W or ↑ (hold to jump higher and float)", "A / Cross", "Jump button, bottom right"),
        ("Confirm, next card", "Space or Enter", "A / Cross", "Tap anywhere"),
        ("Pause and Spellbook", "Esc or P", "Start / Options", "Pause, top right"),
        ("Back to world map", "M", "LB / L1", "Pause, then World map"),
        ("Ask the guardian for a hint", "H", "Y / Triangle", "? button, during a duel"),
        ("Fullscreen", "F11", "", "Fullscreen on the title screen (not on iPhone)"),
    ]
    rows = "".join(f"<tr><th scope=row>{a}</th><td data-label=Keyboard>{k}</td><td data-label=Gamepad>{p or '-'}</td><td data-label=Touch>{t}</td></tr>" for a, k, p, t in controls)
    things = [
        ("tin.png", 12, 12, "Tin of spam", "The collectible. Each stage counts how many you found, and your best count shows on the world map."),
        ("cache_stone.png", 16, 16, "Cache stone", "Bump it from below and it gives you its tin. It only does this once."),
        ("clay_brick.png", 16, 16, "Clay brick", "Jump into it from below to break it."),
        ("bunny.png", 20, 12, "Killer bunny", "Looks harmless. Walks back and forth on its ledge. Landing on it beats it. Touching it from the side knocks you out."),
        ("tile_ash.png", 16, 16, "Ash shelf", "Cracks under your feet, then falls. Keep moving. It comes back when you respawn."),
        ("lantern_lit.png", 12, 28, "Lantern", "A checkpoint. Walk past it to light it, and that's where you come back after a fall."),
        ("castle_gate.png", 24, 40, "Castle gate", "The exit. It's behind the guardian's barrier, so you have to win his duel before you can reach it. When you get there, watch the sky."),
        ("foes/foe_1.png", 12, 18, "Guardians", "Each stage ends in a guardian's arena: the Knight Who Says Mi, the Cheesemonger, Tom the Enchanter, the Under-Minister, the Bridgekeeper and the Taunting Knight. Walk in and the duel starts. Touching him knocks you back."),
    ]
    cards = "".join(
        f'<li><span class="sprite"><img src="{prefix}static/img/{img}" alt="" width="{w * 3}" height="{h * 3}"></span><div><h3>{name}</h3><p>{text}</p></div></li>'
        for img, w, h, name, text in things
    )
    body = f"""
<section class="section page-head">
  <p class="kicker">How to play</p>
  <h1>Field guide to the trail</h1>
  <p class="lede">Dunder Quest is a side-scrolling platformer. You play as a squire on a quest for the Grail, clopping coconut halves for want of a horse, and you clear a stage by reaching its castle gate. There are six stages, and clearing one opens the next on the world map.</p>
  <a class="btn" href="{prefix}play/">Play in your browser</a>
</section>

<section class="section" aria-labelledby="controls-h">
  <h2 id="controls-h">Controls</h2>
  <div class="table-wrap"><table class="controls">
    <thead><tr><th scope=col>Action</th><th scope=col>Keyboard</th><th scope=col>Gamepad</th><th scope=col>Touch</th></tr></thead>
    <tbody>{rows}</tbody>
  </table></div>
  <p class="fine">Holding jump floats you for a moment at the top and carries you further. Let go and you drop fast. In the browser, the game can't play sound until you press a key, click or tap once. The title screen takes care of that with your first press. On a phone, the buttons appear once you start a stage; in the Spellbook, tap the sides of the screen to turn pages.</p>
</section>

<section class="section" aria-labelledby="things-h">
  <h2 id="things-h">What you'll meet</h2>
  <ul class="things">{cards}</ul>
  <p>Glowing <b>ember tiles</b> knock you out if you touch them. A fall sends you back to the last lantern you lit, or to the start of the stage, and the clock keeps running.</p>
</section>

<section class="section" aria-labelledby="lessons-h">
  <h2 id="lessons-h">Lessons, puzzles and the guardian's duel</h2>
  <div class="two">
    <figure class="shot"><img src="{prefix}static/img/shots/tour_amber_hint2.png" alt="The guardian's duel with one wrong answer dimmed and its block cracked after a second hint" width="480" height="270" loading="lazy"><figcaption>After a second hint, the guardian rules out one wrong answer and its block cracks.</figcaption></figure>
    <div>
      <p><b>Lore scrolls</b> teach the stage's topic. Touching one pauses the game and opens its card. Press Space or tap to keep going.</p>
      <p><b>The stage puzzle</b> is the way forward. Slates in the scenery show its code, and blocks you bump from below run it. Only the right answer builds the path. The <a href="{prefix}lessons/">lesson pages</a> explain each one.</p>
      <p><b>The guardian's duel</b> starts when you walk into his arena at the end of the stage. A seal closes behind you, his question appears across the top of the screen, and four lettered blocks hang over the floor. Jump up into the block with the right answer. Each right answer breaks one ward, the pips above his name. A wrong answer cracks that block, zaps you, and brings a different question. He mostly asks about scrolls you've read, so reading them on the way pays off.</p>
      <p><b>His spells:</b> after giving you a moment to read, he casts. Ward waves roll along the floor, so jump them. From Cave of the Bunny on, hexes mark a spot and then strike, so step aside. You have three sparks, shown next to his name. A spell, a zap or bumping into him costs one. Lose all three and you wake at the lantern outside, but the wards you broke stay broken. The clock stops for the whole duel.</p>
      <p><b>Hints:</b> press H (or tap the ? button) once for his riddle and a reminder of the scroll the question comes from. Press it again and he rules out one wrong answer, and its block cracks. There's no third hint.</p>
    </div>
  </div>
</section>

<section class="section" aria-labelledby="book-h">
  <h2 id="book-h">Spellbook, results and saving</h2>
  <div class="two">
    <div>
      <p><b>Spellbook:</b> pause with Esc or the Pause button to open it. It keeps every scroll you've read, so you can study before a trial.</p>
      <p><b>Results:</b> when you clear a stage, you see your tins, time and falls. Your best time and tin count for each stage show on the world map.</p>
      <p><b>Saving</b> happens automatically. In the browser, your progress is stored in that browser on that device, so clearing site data erases it. The desktop builds save to a file in the Godot user folder: <code>%APPDATA%\\Godot\\app_userdata\\Dunder Quest\\</code> on Windows, <code>~/Library/Application Support/Godot/app_userdata/Dunder Quest/</code> on macOS, and <code>~/.local/share/godot/app_userdata/Dunder Quest/</code> on Linux. To start over, choose <em>New game</em> on the title screen and press it a second time to confirm.</p>
    </div>
    <figure class="shot"><img src="{prefix}static/img/shots/tour_amber_book.png" alt="The Spellbook in the pause menu listing scrolls read so far" width="480" height="270" loading="lazy"><figcaption>The Spellbook, from the pause menu.</figcaption></figure>
  </div>
</section>"""
    return page("How to play", body, prefix, "guide/", "Controls, enemies, checkpoints, lore scrolls, the guardian's trial and saving in Dunder Quest.", path="guide/")


## The brand kit: /brand/ and a page for each part (BRAND_PAGES). The
## footer's `>>> help(dunder_quest)` is the only link to it.
## games/dunder-quest/trailer/PLAN.md §4 has the palette; dusk, line, moss
## and zap are the site's additions.
PALETTE = [
    ("GOLD", "#F2B544", "Headlines, the wordmark, strings in trailer code"),
    ("EMBER", "#FF8A3D", "Accents, the wordmark's underscores, keywords in trailer code"),
    ("PARCHMENT", "#F4E4C4", "Body text, numbers in trailer code"),
    ("ASH", "#B0A9D0", "Secondary text, comments in trailer code"),
    ("NIGHT", "#15122A", "Backgrounds, card fills, text shadows"),
    ("DUSK", "#232849", "The site's background, the game's sky"),
    ("LINE", "#4A4F86", "Panel borders"),
    ("MOSS", "#7BE08A", "A cleared stage, a right answer"),
    ("ZAP", "#FF7A7A", "A wrong answer, a hit"),
]
## Every line the game is pitched with, where it ships, and where to change it.
COPY = [
    ("A pixel platformer where Python is the magic.", "The pitch", "trailer/PLAN.md"),
    ("A platformer where every stage teaches you a piece of Python.", "Home page", "site/build.py"),
    ("A pixel-art platformer that teaches Python", "Home social card", "tools/make_og.py"),
    ("Dunder Quest is a pixel-art platformer that teaches Python. Play it in your browser or download it.", "Search results", "site/build.py"),
    ("LEARN PYTHON BY PLAYING", "Trailer thumbnail", "tools/make_trailer.py"),
    ("YOUR CODE / BUILDS THE WORLD", "Trailer hook", "tools/make_trailer.py"),
    ("A squire's quest for the Grail · Play free in your browser", "Trailer end card", "tools/make_trailer.py"),
]
## (file, name, note, native width, native height, scale): art is only ever
## scaled by whole numbers, so each piece carries the scale it's shown at.
ART = [
    ("title_art.png", "Title art", "Behind the home page, every social card and the trailer's end card", 480, 270, 1),
    ("trail_map.png", "World map", "The six stages, from Shrubbery Wood to Castle Aargh", 480, 168, 1),
    ("squire.png", "The squire", "The hero", 16, 24, 4),
    ("foes/foe_1.png", "The Knight Who Says Mi", "The first of six guardians", 36, 56, 2),
    ("foes/foe_5.png", "The Bridgekeeper", "Asks his questions... four", 36, 56, 2),
    ("bunny.png", "Killer bunny", "Stomp it", 20, 12, 4),
    ("tin.png", "Tin of spam", "Collect it", 12, 12, 6),
    ("castle_gate.png", "Castle gate", "A stage's exit", 24, 40, 2),
    ("giant_foot.png", "The foot", "Stomps down when you clear a stage", 72, 96, 2),
    ("grail.png", "The Grail", "Over the very last gate", 12, 14, 6),
    ("shots/tour_bridge_built.png", "Bridge built", "span(5) lays the planks", 480, 270, 1),
    ("shots/tour_amber_duel.png", "Guardian duel", "Jump into the right answer", 480, 270, 1),
    ("shots/tour_amber_scroll.png", "Lore scroll", "A lesson card", 480, 270, 1),
]
TRAILER_FACTS = [
    ("Length", "72 seconds, with a cold open"),
    ("Music", "A brass-band march, 120 BPM; every cut lands on a beat"),
    ("Loudness", "−14 LUFS, YouTube's target"),
    ("Pixels", "Drawn at 480×270, scaled ×4 for 1080p and ×8 for 4K"),
]
TRAILER_CUTS = [
    ("4K master", "3840×2160, 60 fps", "YouTube"),
    ("1080p master", "1920×1080, 60 fps", "itch.io, press"),
    ("Thumbnail", "1920×1080, from the Cave of the Bunny duel", "YouTube, the home page"),
    ("Vertical Short", "1080×1920, under 60 s", "Shorts, TikTok, Reels (coming)"),
    ("GIF loops", "3–6 s of the bridge and a duel", "Social posts (coming)"),
]
FM_TRAILER_FACTS = [
    ("Length", "66 seconds, with a cold open"),
    ("Music", "A sitcom band cue, 123 BPM, with a piano breakdown for the awkward bit"),
    ("Loudness", "−14 LUFS, YouTube's target"),
    ("Pixels", "Drawn at 480×270, scaled ×4 for 1080p and ×8 for 4K"),
]
## What goes in YouTube's upload form. The chapter times are the cut's bars:
## the gadgets at bar 8, the duels at bar 20, the end card at bar 28 (see
## `edit()` in tools/make_trailer.py). YouTube ignores chapters shorter than
## 10 s, so the 8 s cold open shares the first one.
YOUTUBE_TITLE = "Dunder Quest – Learn Python on a Very Silly Grail Quest | Official Trailer"
YOUTUBE_DESCRIPTION = f"""Python is named after Monty Python. So we made learning it a quest for the Grail.

Dunder Quest is a free pixel-art platformer where every stage teaches a piece of real Python. Slice a list to lay a bridge. Hash a key into the right bucket. Loop a lift up a cave wall. Then face the guardian at the exit, from the Knight Who Says Mi to the Bridgekeeper, who asks his questions... four. Answer by jumping into the right block while you dodge his spells.

▶ Play free in your browser: {SITE_URL}play/
▶ Windows, macOS and Linux: {SITE_URL}{QUEST_PAGE}#download
▶ Every lesson and question: {SITE_URL}lessons/
▶ Prefer JavaScript? Flatmates.js: {SITE_URL}flatmates/
▶ Or Rust? Curb Your Oxidation: {SITE_URL}curb/

What's inside
• 6 stages, 6 Python topics: lists, dictionaries, loops, booleans, functions, comprehensions
• 63 quiz questions, each checked against a real Python interpreter
• Lore scrolls and a Spellbook to study before each duel
• A squire, two coconut halves, killer bunnies, tins of spam, and a giant foot
• Keyboard, gamepad or touch. No signup.

How it was made
Opus 5.5 built the whole game: every line of Godot code, the pixel art painted from Python scripts, this website, and this trailer, cut from a scripted gameplay capture with no video editor. Image and music models made the backgrounds and soundtrack. My part was prompting and playtesting.
Source: {REPO}

0:00 Six stages to the Grail
0:22 Your code builds the world
0:46 Guardian duels
1:02 Play free

A fan homage. Not affiliated with or endorsed by Monty Python.

#python #learnpython #indiegame #pixelart #godot #codinggame"""
YOUTUBE_TAGS = ("learn python, python for beginners, coding game, educational game, pixel art, indie game, "
                "godot, monty python, holy grail, dunder quest")
## The Flatmates.js trailer's chapters follow `cue_flat` (see `edit()` in
## flatmates/tools/make_trailer.py): the stops at bar 8 (18 s), the piano
## breakdown at bar 16 (34 s), the finale at bar 22 (45 s).
FM_YOUTUBE_TITLE = "Flatmates.js – Learn JavaScript in a Very Small Croydon Flat | Official Trailer"
FM_YOUTUBE_DESCRIPTION = f"""Two flatmates. Two points of view. One of them runs your JavaScript.

Flatmates.js is a free pixel-art game where you write the other flatmate's to-do list in real JavaScript, then swap into his head and live with what he does. Clive can't jump much. Jazz can jump, and that's about it. Script one to get the other across Croydon, from Flat 5B to a wedding he really shouldn't be playing.

▶ Play free in your browser: {SITE_URL}flatmates/play/
▶ The six stops and their scripts: {SITE_URL}flatmates/
▶ Prefer Python? Dunder Quest: {SITE_URL}
▶ Or Rust? Curb Your Oxidation: {SITE_URL}curb/

What's inside
• 6 stops, 6 pieces of JavaScript: methods, template literals, loops, events, timers, async/await
• Real scripts with blanks to fill, every snippet checked against Node
• Lesson cards in whoever's inner voice you're in
• A tram line, a stag do, a ticket barrier, and six custard creams per stop
• Keyboard, gamepad or touch. No signup.

How it was made
Opus 5.5 built the game: every line of Godot code, the sprites painted from Python scripts, its web page, and this trailer, cut from a scripted gameplay capture with no video editor. Image and music models made the backdrops and soundtrack. My part was prompting and playtesting.
Source: {REPO}/tree/main/games/flatmates

0:00 Earlier that Saturday
0:18 Six stops
0:34 The awkward bit
0:45 The wedding

An homage to a certain Croydon flat-share sitcom. The names and jokes are winks, not the show's own; it isn't affiliated with or endorsed by anyone who made it.

#javascript #learnjavascript #indiegame #pixelart #godot #codinggame"""
FM_YOUTUBE_TAGS = ("learn javascript, javascript for beginners, coding game, educational game, pixel art, "
                   "indie game, godot, sitcom, flatmates.js, dunder quest")
## Curb Your Oxidation's trailer (games/curb/trailer/). The chapters are the
## ones `make_trailer.py` writes to `recut.log`.
CURB_YOUTUBE_TITLE = "Curb Your Oxidation – Learn Rust, One Petty Dispute at a Time | Official Trailer"
CURB_YOUTUBE_DESCRIPTION = f"""The borrow checker is the unwritten social contract.

Curb Your Oxidation is a free pixel-art game that teaches Rust. Barry Danvers, a semi-retired TV writer on the Westside of LA, lives by rules nobody else has heard of, and every petty dispute he gets into is settled by a plan: a short Rust program on his yellow legal pad. He plays it through in his head first, the way rustc reads your whole program before anything runs. Break the rules and Sharon bursts in at the exact line with the real rustc error, and an opinion about it. Get it right and the scene plays out, one println! at a time.

▶ Play free in your browser: {SITE_URL}curb/play/
▶ The ten episodes and their plans: {SITE_URL}curb/
▶ Prefer Python? Dunder Quest: {SITE_URL}
▶ Or JavaScript? Flatmates.js: {SITE_URL}flatmates/

What's inside
• 10 episodes, 10 pieces of Rust: let and mut, functions, ownership and moves, borrowing, &mut, structs and methods, enums and Option, Result and ?, Vec and loops, lifetimes
• Real rustc error codes, from E0382 to E0597, delivered by Sharon
• Every plan compiled with the real rustc, in every combination of its blanks
• A second latte, the last shrimp, a regifted candle, and a houseguest who said one night
• Keyboard, gamepad or touch. No signup.

How it was made
Opus 5.5 built the game: every line of Godot code, a small Rust checker written in GDScript, the cast painted from Python scripts, its web page, and this trailer, cut from a scripted gameplay capture with no video editor. Image and music models made the backdrops and soundtrack. My part was prompting and playtesting.
Source: {REPO}/tree/main/games/curb

0:00 Barry has rules
0:24 The season, the panic, the squint
0:44 Freeze frames

An homage to a certain LA cringe-comedy series. The names, lines and music are original, not the show's own; it isn't affiliated with or endorsed by anyone who made it.

#rust #rustlang #learnrust #indiegame #pixelart #godot #codinggame"""
CURB_YOUTUBE_TAGS = ("learn rust, rust for beginners, rustlang, borrow checker, coding game, educational game, "
                     "pixel art, indie game, godot, sitcom, curb your oxidation, dunder quest")
## The channel's own fields, in YouTube Studio under Customization.
CHANNEL_DESCRIPTION = f"""Free pixel-art games that teach you to code, playable in your browser.

Dunder Quest teaches Python on a very silly quest for the Grail: slice a list to lay a bridge, loop a lift up a cave wall, and answer the Bridgekeeper's questions... four. Flatmates.js teaches JavaScript in a very small Croydon flat: write the to-do list your flatmate runs, then live with what he does. Curb Your Oxidation teaches Rust on the Westside, where the borrow checker is the unwritten social contract.

Opus 5.5 built every game here end to end: the code, the sprites, the websites, and the trailers, cut from code with no video editor. Image and music models made the backdrops and soundtracks. I prompt and playtest.

Why learning games? I'm dyslexic, and I failed my spelling tests until my dad wrote me a spelling game in BASIC. After that I got 100 on every one. My kids are 5 and 2. Maybe some day these games are theirs.

Play free, no signup: {SITE_URL}"""
CHANNEL_KEYWORDS = ('"learn python" "learn javascript" "coding game" "educational game" "pixel art" '
                    '"indie game" godot "programming for beginners" "dunder quest" flatmates.js "learn rust" "curb your oxidation"')
CHANNEL_LINKS = [
    ("Play Dunder Quest", f"{SITE_URL}play/"),
    ("Play Flatmates.js", f"{SITE_URL}flatmates/play/"),
    ("Play Curb Your Oxidation", f"{SITE_URL}curb/play/"),
    ("Source on GitHub", REPO),
]
## (file, name, size YouTube asks for, where it goes, alt)
CHANNEL_ART = [
    ("banner.png", "Banner", "2560×1440; phones show only the middle 1546×423",
     "Customization → Branding → Banner image",
     "The wordmark and 'Pixel-art games that teach you to code' over the title art, with the squire on the left and Clive and Jazz on the right"),
    ("avatar.png", "Profile picture", "800×800, shown as a circle as small as 98 px",
     "Customization → Branding → Picture", "The Dunder Quest q between its underscores, on night blue"),
    ("watermark.png", "Video watermark", "150×150, clear background",
     "Customization → Branding → Video watermark, shown for the entire video", "The Dunder Quest icon"),
]
CHANNEL_PLAYLISTS = [
    ("Trailers", "Every trailer, newest first. Set the Dunder Quest trailer as the channel trailer for visitors who haven't subscribed."),
    ("Dunder Quest", "The Python game: its trailer, and later the Short and the GIF loops cut to video."),
    ("Flatmates.js", "The JavaScript game: its trailer, and later its Short."),
    ("Curb Your Oxidation", "The Rust game: its trailer, and later its Short."),
]
## Studio's upload settings that are the same for every video.
UPLOAD_SETTINGS = [
    ("Audience", "No, it's not made for kids. The trailers are pitched at teen and adult beginners and developers. Answer it honestly for each video, because it changes comments and notifications."),
    ("Altered or synthetic content", "No. YouTube asks only about realistic footage, and these are pixel art. The descriptions already say what the models made."),
    ("Category", "Gaming"),
    ("Language", "English, for the video and the title and description"),
    ("Thumbnail", "Upload the PNG below. Each is 1920×1080 and under YouTube's 2 MB limit."),
    ("Video file", "The 4K master from the game's trailer/out/. YouTube makes every smaller size from it."),
    ("End screen", "Subscribe, plus the other game's trailer, over the end card"),
]
## The launch: one post per platform, in the order they go out on launch
## day. Times are US Eastern on a Tuesday. Every post says what Opus 5.5 did
## and what other models made, because readers open the repo and check.
## (platform, when, title or "", [post, or (label, post)], tips)
LAUNCH = [
    ("Hacker News", "8:30 AM", "Show HN: Dunder Quest – a Python platformer Opus 5.5 built in four days", [
        ("URL", f"{SITE_URL}play/"),
        ("First comment, posted right away", "I wanted to see how far Opus 5.5 could take a game end to end, so I let it build one. "
        "Dunder Quest is a pixel platformer where Python is the magic: you bump slice blocks to lay a bridge, "
        "load a range() into a lift, and duel the Bridgekeeper by jumping into the right answer. Python is named after Monty Python, so it's a Holy Grail quest: a squire clopping coconuts, a Knight Who Says Mi, a giant foot. Six stages, free in the browser, no signup.\n\n"
        "Over four days Opus wrote all of the Godot code, painted the tiles and the whole cast pixel by pixel from Python scripts, "
        "prompted image, music and sound models for the rest, built this site, and cut the 62 s trailer from a scripted "
        "gameplay capture with no video editor. I wrote the prompts and playtested.\n\n"
        "Where it struggled: duels were hard to read until it added a camera that eases in, and some jumps still need a human playtest. "
        "The list it kept is in GAME_IMPROVEMENTS.md.\n\n"
        "Why a learning game: I'm dyslexic, and I was failing my spelling tests until my dad wrote me a spelling game in BASIC. "
        "After that I got 100 on every one. My kids are 5 and 2, too young for Python, but maybe some day this is theirs.\n\n"
        f"Source: {REPO}"),
    ], "Link the game itself, not the home page. Stay in the thread for the first three hours and answer everything, the skeptics first. Never ask anyone for upvotes: HN spots vote rings and buries the post. If it sinks, email hn@ycombinator.com and ask about the second-chance pool."),
    ("X", "8:45 AM", "", [
        "I let Opus 5.5 build a whole game in four days.\n\n"
        "Dunder Quest: a pixel platformer where Python is the magic. Slice a list to lay a bridge, loop a lift up a wall, answer the Bridgekeeper's questions... four.\n\n"
        f"Free in your browser 👇\n{SITE_URL}",
        "Opus wrote every line of Godot code, painted the tiles pixel by pixel in Python, and prompted image and music models for the rest.\n\n"
        "It even cut the trailer from code. No video editor anywhere.",
        "Why a learning game? I'm dyslexic. I failed spelling tests until my dad wrote me a spelling game in BASIC. Then I got 100 on every one.\n\n"
        "My kids are 5 and 2. Too young for Python, but maybe some day.",
        "My part: prompts and playtesting.\n\n"
        f"Everything it made is on GitHub, commit by commit:\n{REPO}",
    ], "Upload the 1080p trailer to the first post as a video, not a YouTube link: native video autoplays in the feed. Tag @AnthropicAI and @claudeai on the last post. Pin the thread."),
    ("Bluesky", "9:00 AM", "", [
        "I let Opus 5.5 build a whole game in four days: Dunder Quest, a pixel platformer where Python is the magic. "
        "Opus wrote the code, painted the tiles in Python and cut the trailer with no video editor.\n\n"
        f"Free in your browser: {SITE_URL}",
        "Why a learning game: I'm dyslexic, and I failed spelling tests until my dad wrote me a spelling game in BASIC. "
        "Then I got 100 on every one.\n\n"
        "My kids are 5 and 2, too young for Python. Maybe some day.",
    ], "Attach the trailer as a video to the first post and reply to it with the second. Bluesky caps posts at 300 characters. Add the GitHub link as a third reply."),
    ("r/godot", "10:00 AM", "Opus 5.5 built this Python-teaching platformer in Godot 4 in four days, trailer included", [
        "Dunder Quest is a pixel platformer where every stage teaches a piece of Python: slices, hashing, loops, conditions. "
        "A Monty Python guardian at the end of each stage asks a question and you answer by jumping into a block.\n\n"
        "The whole thing was built by Opus 5.5 over four days. It wrote the GDScript, painted the tiles from Python scripts, "
        "and made the trailer by recording the game with --write-movie and compositing it in Python. I prompted and playtested.\n\n"
        f"Play it in the browser (web export): {SITE_URL}play/\n"
        f"Source: {REPO}\n\n"
        "Happy to answer questions about how it handled the Godot side.",
    ], "Use the Showcase flair and upload the trailer as a Reddit video. r/godot cares about the engine, so lead with the Godot details in the comments."),
    ("r/Python", "11:00 AM", "Dunder Quest: a browser platformer that teaches Python, built end to end by Opus 5.5", [
        "**What My Project Does**\n\n"
        "Dunder Quest is a free pixel platformer that teaches Python. Each of its six stages is built around one idea: "
        "you slice a list to lay a bridge, hash keys into a vault, and run a for loop to raise a lift. "
        "Monty Python-style guardians quiz you on real Python, and every question is checked against a real interpreter.\n\n"
        "**Target Audience**\n\n"
        "Beginners learning Python, and people curious about what a coding model can build alone. It's a finished, playable game, not a demo.\n\n"
        "**Comparison**\n\n"
        "Most coding games are puzzles in a code editor. Here the code changes the world you run and jump through. "
        "It was also built entirely by Opus 5.5, from the game to its art pipeline and trailer, all in Python and GDScript.\n\n"
        f"Play: {SITE_URL}\nSource: {REPO}",
    ], "r/Python only allows project posts as Showcase posts in exactly these three sections. Post it as a text post with the link inside."),
    ("LinkedIn", "12:00 PM", "", [
        "I'm dyslexic, and as a kid I failed my spelling tests. Then my dad wrote me a spelling game in BASIC. "
        "After that I got 100 on every test.\n\n"
        "This week I gave Opus 5.5 a blank repo and four days to make a learning game of its own. It came back with a finished one.\n\n"
        "Dunder Quest is a pixel platformer that teaches Python: six stages, each built around one idea, and a Monty Python guardian at the end of each "
        "who checks you understood it.\n\n"
        "Opus wrote all of the code, painted the art in Python, directed image and music models for the rest, built the website, "
        "and cut the trailer from code. My job was prompting and playtesting.\n\n"
        "What struck me most was the judgment, not the speed. It kept its own list of what wasn't working, "
        "like duels that were hard to read on a phone, and fixed them.\n\n"
        "My kids are 5 and 2, too young for Python. But my dad's game is why I can spell, "
        "and maybe some day this one is theirs.\n\n"
        f"Play it free in your browser: {SITE_URL}",
    ], "Native video gets far more reach than a link card, so upload the trailer. Put the link in the post, not the first comment."),
    ("r/WebGames", "1:00 PM", "Dunder Quest – a Monty Python quest that teaches Python [free, no signup]", [
        ("URL", f"{SITE_URL}play/"),
    ], "A link post straight to the game. Check it loads on a phone first: most players will tap it there."),
]


## The brand kit's pages, in the order help(dunder_quest) lists them:
## (slug, title, what's on it).
BRAND_PAGES = [
    ("identity", "Logo, voice, colors and type", "The wordmark, every line the game is pitched with, the palette and the fonts."),
    ("art", "Art and social cards", "The sprites and scenes, and the card each page shows when its link is shared."),
    ("trailers", "The trailers", "Every game's trailer, how each is made, and every cut."),
    ("youtube", "The YouTube channel", "The @dunderquest channel art, its description and links, and each video's upload form."),
    ("launch", "The launch posts", "One post per platform, ready to paste, in the order they go out."),
]


def copy_block(label: str, text: str, count: str = "") -> str:
    """Text to paste somewhere else, with a Copy button (static/copy.js) and
    an optional length against that field's limit."""
    count = f' <span class="count">{count}</span>' if count else ""
    return (f'<figure class="code post"><figcaption>{esc(label)}{count}'
            f'<button class="copy" type="button" hidden>Copy</button></figcaption>'
            f"<pre><code>{esc(text)}</code></pre></figure>")


def brand_page(slug: str, body: str, prefix: str, scripts: str = "") -> str:
    """One page of the brand kit at /brand/<slug>/, under a row of links to
    the others."""
    title, description = next((t, d) for s, t, d in BRAND_PAGES if s == slug)
    links = "".join(
        f'<a href="{prefix}brand/{s}/"{" aria-current=page" if s == slug else ""}>{s}</a>'
        for s, _, _ in BRAND_PAGES)
    head = f"""
<nav class="kit-nav" aria-label="Brand kit"><a href="{prefix}brand/">help(dunder_quest)</a>{links}</nav>
<section class="section page-head kit-head">
  <p class="kicker">&gt;&gt;&gt; help(dunder_quest.{slug})</p>
  <h1>{esc(title)}</h1>
  <p class="lede">{esc(description)}</p>
</section>"""
    return page(f"{title} · Brand kit", head + body, prefix,
                description=f"The Dunder Quest brand kit: {description[0].lower()}{description[1:]}",
                scripts=scripts + f'<script src="{prefix}static/copy.js"></script>', path=f"brand/{slug}/")


def build_brand(prefix: str) -> str:
    """/brand/, the way in: what help() prints for a package, with each page
    of the kit as one of its modules."""
    width = max(len(s) for s, _, _ in BRAND_PAGES)
    contents = "\n".join(
        f'    <a href="{s}/">{s}</a>{" " * (width - len(s))}  {esc(t)}' for s, t, _ in BRAND_PAGES)
    pages = "".join(
        f'<li><a href="{s}/"><code>dunder_quest.{s}</code><b>{esc(t)}</b><span>{esc(d)}</span></a></li>'
        for s, t, d in BRAND_PAGES)
    body = f"""
<section class="section page-head">
  <p class="kicker">&gt;&gt;&gt; help(dunder_quest)</p>
  <h1>The brand kit</h1>
  <figure class="code pydoc"><pre><code>Help on package dunder_quest:

NAME
    dunder_quest - pixel-art games that teach you to code
    (and Monty Python is the plot)

DESCRIPTION
    The logo, colors, fonts, art, trailers, YouTube channel and
    launch posts, and where each one is made.

PACKAGE CONTENTS
{contents}</code></pre></figure>
  <ul class="kit-pages">{pages}</ul>
</section>"""
    return page("Brand kit", body, prefix,
                description="The Dunder Quest brand kit: the logo, colors, fonts, art, trailers, YouTube channel and launch posts.",
                path="brand/")


def build_brand_identity(prefix: str) -> str:
    img = f"{prefix}static/img/"
    swatches = "".join(
        f'<li><span class="chip" style="background:{hex_}"></span>'
        f'<code>{name} = "{hex_}"</code><span>{esc(use)}</span></li>'
        for name, hex_, use in PALETTE
    )
    copy_rows = "".join(
        f"<tr><td>{esc(line)}</td><td>{esc(where)}</td><td><code>{esc(src)}</code></td></tr>"
        for line, where, src in COPY
    )
    body = f"""
<section class="section kit" aria-labelledby="logo-h">
  <p class="kicker">dunder_quest.__logo__</p>
  <h2 id="logo-h">The wordmark</h2>
  <p class="lede">The name written as a real Python dunder: gold letters between ember underscores, the way <code>__init__</code> sits between its own. Lowercase, one word, underscores kept. In a sentence, the game is just Dunder Quest.</p>
  <div class="kit-logo">
    <p class="kit-mark" aria-hidden="true"><i>__</i>dunder_<wbr>quest<i>__</i></p>
    <a href="{img}og/logo.png"><img src="{img}og/logo.png" alt="The Dunder Quest icon: a pixel q between two pairs of underscores" width="128" height="128"></a>
  </div>
  <p class="fine">Download the icon as <a href="{img}og/logo.png">PNG</a> or <a href="{img}icon.svg">SVG</a>.</p>
</section>

<section class="section kit" aria-labelledby="voice-h">
  <p class="kicker">dunder_quest.__doc__</p>
  <h2 id="voice-h">How it's described</h2>
  <p class="lede">Every line says "platformer" and "Python", because the hook is that your code changes the world.</p>
  <div class="table-wrap"><table>
    <thead><tr><th>Line</th><th>Where</th><th>Made in</th></tr></thead>
    <tbody>{copy_rows}</tbody>
  </table></div>
</section>

<section class="section kit" aria-labelledby="color-h">
  <p class="kicker">dunder_quest.__colors__</p>
  <h2 id="color-h">The palette</h2>
  <ul class="swatches">{swatches}</ul>
  <figure class="code kit-code"><figcaption>Code in the trailer and on the cards</figcaption><pre><code><i class="kw">for</i> i <i class="kw">in</i> range(<i class="nm">4</i>):
    lift.rise()  <i class="cm"># one notch</i>
key = <i class="st">"spam"</i></code></pre></figure>
</section>

<section class="section kit" aria-labelledby="type-h">
  <p class="kicker">dunder_quest.__fonts__</p>
  <h2 id="type-h">The type</h2>
  <ul class="specimens">
    <li><p class="sp-pixel">Six stages to the Grail</p><b>Pixelify Sans</b> <span>Headlines and the wordmark · <a href="{prefix}static/fonts/PixelifySans.ttf">TTF</a></span></li>
    <li><p class="sp-label">&gt;&gt;&gt; import adventure</p><b>VT323</b> <span>Code, prompts and labels · <a href="{prefix}static/fonts/VT323.ttf">TTF</a></span></li>
    <li><p class="sp-body">Guide a squire across six stages to the Grail.</p><b>Atkinson Hyperlegible</b> <span>Body text on this site</span></li>
  </ul>
  <p class="fine">All three are under the SIL Open Font License.</p>
</section>"""
    return brand_page("identity", body, prefix)


def build_brand_art(prefix: str) -> str:
    img = f"{prefix}static/img/"
    art = "".join(
        f'<li><a href="{img}{file}"><img src="{img}{file}" alt="" width="{w * s}" height="{h * s}" loading="lazy"></a>'
        f"<b>{esc(name)}</b><span>{esc(note)}</span></li>"
        for file, name, note, w, h, s in ART
    )
    cards = [("home.png", "Home", "Home, Dunder Quest, How to play, and any page without its own card"),
             ("lessons.png", "Lessons", "The lessons index"),
             ("flatmates.png", "Flatmates.js", "The Flatmates.js page and its game"),
             ("curb.png", "Curb Your Oxidation", "The Curb Your Oxidation page and its game")]
    cards += [(f"{s['slug']}.png", f"{s['id']} · {s['name']}", "That stage's lesson page") for s in STAGES]
    card_items = "".join(
        f'<li><a href="{img}og/{file}"><img src="{img}og/{file}" alt="The {esc(name)} social card" width="1200" height="630" loading="lazy"></a>'
        f'<span class="og-crop" aria-hidden="true"><img src="{img}og/{file}" alt="" loading="lazy"></span>'
        f"<b>{esc(name)}</b><span>{esc(used)}</span></li>"
        for file, name, used in cards
    )
    body = f"""
<section class="section kit" aria-labelledby="art-h">
  <p class="kicker">dunder_quest.__art__</p>
  <h2 id="art-h">The art</h2>
  <p class="lede">The game draws at 480×270. Scale it by whole numbers with nearest-neighbor, never by fractions, or the pixels come out uneven. Click a piece for the original file.</p>
  <ul class="art">{art}</ul>
</section>

<section class="section kit" aria-labelledby="cards-h">
  <p class="kicker">dunder_quest.__cards__</p>
  <h2 id="cards-h">The social cards</h2>
  <p class="lede">What a link to each page looks like when it's shared. Chat apps show either the full card or a small square cut from its middle, shown beside each one, so anything that has to be read sits in the center.</p>
  <ul class="cards">{card_items}</ul>
  <p class="fine">Painted by <code>games/dunder-quest/tools/make_og.py</code>, <code>games/flatmates/tools/og.py</code> and <code>site/curb_art.py</code>.</p>
</section>"""
    return brand_page("art", body, prefix)


DQ_THUMB_ALT = "Trailer thumbnail: Tom the Enchanter's duel on print(list(range(4))), under the Dunder Quest wordmark"
FM_THUMB_ALT = "Flatmates.js trailer thumbnail: Clive and Jazz on their sofas, under 'Learn JavaScript. Blame your flatmate.' and jazz.walk(7);"
CURB_THUMB_ALT = "Curb Your Oxidation trailer thumbnail: the title in yellow serif on black, over Sharon interrupting with error[E0382]"


def trailer_player(video: str, thumb: str, alt: str, name: str) -> str:
    """A trailer's thumbnail that turns into the player when clicked
    (static/trailer.js), or just the thumbnail before it's uploaded."""
    image = f'<img src="{thumb}" alt="{esc(alt)}" width="1920" height="1080" loading="lazy">'
    if not video:
        return f'<div class="trailer">{image}</div>'
    return (f'<a class="trailer" href="https://www.youtube.com/watch?v={video}" data-yt="{video}">{image}'
            f'<span class="trailer-play" aria-hidden="true"></span><span class="sr">Play the {esc(name)} trailer</span></a>')


def build_brand_trailers(prefix: str) -> str:
    img = f"{prefix}static/img/"
    facts = "".join(f"<div><dt>{k}</dt><dd>{esc(v)}</dd></div>" for k, v in TRAILER_FACTS)
    fm_facts = "".join(f"<div><dt>{k}</dt><dd>{esc(v)}</dd></div>" for k, v in FM_TRAILER_FACTS)
    cuts = "".join(f"<tr><td>{a}</td><td>{esc(b)}</td><td>{esc(c)}</td></tr>" for a, b, c in TRAILER_CUTS)
    body = f"""
<section class="section kit" aria-labelledby="trailer-h">
  <p class="kicker">dunder_quest.__trailer__</p>
  <h2 id="trailer-h">Dunder Quest</h2>
  <p class="lede">Built entirely from the game's repo by a Python script, with no video editor: real gameplay, captured frame by frame, with motion graphics in the game's own fonts and colors.</p>
  <div id="trailer">{trailer_player(TRAILER_ID, f"{img}trailer.png", DQ_THUMB_ALT, "Dunder Quest")}</div>
  <dl class="facts">{facts}</dl>
  <div class="table-wrap"><table>
    <thead><tr><th>Cut</th><th>Format</th><th>Where</th></tr></thead>
    <tbody>{cuts}</tbody>
  </table></div>
  <p class="fine">How it's made: <a href="{REPO}/blob/main/games/dunder-quest/trailer/README.md">games/dunder-quest/trailer/README.md</a>.</p>
</section>

<section class="section kit" aria-labelledby="fm-trailer-h">
  <p class="kicker">flatmates.__trailer__</p>
  <h2 id="fm-trailer-h">Flatmates.js</h2>
  <p class="lede">Played as a flat-share sitcom: the inner voices do the talking, the camera sits in one flatmate's head and stares at the other, and the jokes land in the awkward silences. Made the same way, from the repo, with no video editor.</p>
  {trailer_player(FM_TRAILER_ID, f"{img}flatmates/trailer.png", FM_THUMB_ALT, "Flatmates.js")}
  <dl class="facts">{fm_facts}</dl>
  <p class="fine">How it's made: <a href="{REPO}/blob/main/games/flatmates/trailer/README.md">games/flatmates/trailer/README.md</a>.</p>
</section>

<section class="section kit" aria-labelledby="cy-trailer-h">
  <p class="kicker">curb.__trailer__</p>
  <h2 id="cy-trailer-h">Curb Your Oxidation</h2>
  <p class="lede">Cut like the series it's an homage to: black title cards, a squint, a freeze frame and a tuba, cut fast to the music. Made the same way, from the repo, with no video editor.</p>
  {trailer_player(CURB_TRAILER_ID, f"{img}curb/trailer.png", CURB_THUMB_ALT, "Curb Your Oxidation")}
  <p class="fine">Its working files are in <code>games/curb/trailer/</code>.</p>
</section>

<section class="section kit">
  <p>Uploading them? The titles, descriptions and thumbnails are on <a href="{prefix}brand/youtube/">the YouTube page</a>.</p>
</section>"""
    return brand_page("trailers", body, prefix, scripts=f'<script src="{prefix}static/trailer.js"></script>')


def upload_kit(name: str, video: str, thumb: str, download: str, title: str, description: str, tags: str,
               playlist: str, master: str) -> str:
    """One video's YouTube upload form, field by field."""
    status = (f'Live at <a href="https://www.youtube.com/watch?v={video}">youtube.com/watch?v={video}</a>.'
              if video else "Not uploaded yet.")
    return f"""
  <article class="upload">
    <h3>{esc(name)} trailer</h3>
    <p class="fine">{status} Playlists: Trailers, {esc(playlist)}. Video file: <code>{esc(master)}</code>.</p>
    <div class="upload-grid">
      <figure class="shot"><a href="{thumb}" download="{download}"><img src="{thumb}" alt="" width="1920" height="1080" loading="lazy"></a>
        <figcaption>Thumbnail: <a href="{thumb}" download="{download}">{download}</a>, 1920×1080</figcaption></figure>
      <div>
        {copy_block("Title", title, f"{len(title)} / 100")}
        {copy_block("Tags", tags, f"{len(tags)} / 500")}
      </div>
    </div>
    {copy_block("Description", description, f"{len(description)} / 5000")}
  </article>"""


def build_brand_youtube(prefix: str) -> str:
    img = f"{prefix}static/img/"
    art = "".join(
        f'<li class="yt-{file[:-4]}"><a href="{img}youtube/{file}" download="dunder_quest_{file}">'
        f'<img src="{img}youtube/{file}" alt="{esc(alt)}" loading="lazy"></a>'
        f"<b>{esc(name)}</b><span>{esc(size)}</span><span>{esc(where)}</span></li>"
        for file, name, size, where, alt in CHANNEL_ART
    )
    links = "".join(copy_block(f"Link {i + 1}: title", title) + copy_block(f"Link {i + 1}: URL", url)
                    for i, (title, url) in enumerate(CHANNEL_LINKS))
    playlists = "".join(f"<tr><td>{esc(n)}</td><td>{esc(what)}</td></tr>" for n, what in CHANNEL_PLAYLISTS)
    settings = "".join(f"<tr><th scope=row>{esc(k)}</th><td>{esc(v)}</td></tr>" for k, v in UPLOAD_SETTINGS)
    kits = (upload_kit("Dunder Quest", TRAILER_ID, f"{img}trailer.png", "dunder_quest_thumbnail.png",
                       YOUTUBE_TITLE, YOUTUBE_DESCRIPTION, YOUTUBE_TAGS, "Dunder Quest",
                       "games/dunder-quest/trailer/out/dunder_quest_trailer_4k.mp4")
            + upload_kit("Flatmates.js", FM_TRAILER_ID, f"{img}flatmates/trailer.png", "flatmates_thumbnail.png",
                         FM_YOUTUBE_TITLE, FM_YOUTUBE_DESCRIPTION, FM_YOUTUBE_TAGS, "Flatmates.js",
                         "games/flatmates/trailer/out/flatmates_trailer_4k.mp4")
            + upload_kit("Curb Your Oxidation", CURB_TRAILER_ID, f"{img}curb/trailer.png", "curb_thumbnail.png",
                         CURB_YOUTUBE_TITLE, CURB_YOUTUBE_DESCRIPTION, CURB_YOUTUBE_TAGS, "Curb Your Oxidation",
                         "games/curb/trailer/out/curb_trailer_4k.mp4"))
    body = f"""
<section class="section kit" aria-labelledby="channel-h">
  <p class="kicker">dunder_quest.__channel__</p>
  <h2 id="channel-h">@dunderquest</h2>
  <p class="lede">One channel for every game: <a href="{CHANNEL}">youtube.com/@dunderquest</a>. Everything YouTube Studio asks for is below, ready to upload or paste.</p>
  <dl class="facts">
    <div><dt>Name</dt><dd>Dunder Quest</dd></div>
    <div><dt>Handle</dt><dd>@dunderquest</dd></div>
    <div><dt>Channel trailer</dt><dd>The Dunder Quest trailer</dd></div>
    <div><dt>Featured video</dt><dd>The newest trailer</dd></div>
  </dl>
</section>

<section class="section kit" aria-labelledby="yt-art-h">
  <p class="kicker">dunder_quest.__channel__.art</p>
  <h2 id="yt-art-h">The channel art</h2>
  <p class="lede">Click one to download it. On the banner, the dashed box is what a phone shows; the cast stands just outside it, so desktops and TVs see them and phones lose nothing they need.</p>
  <ul class="yt-art">{art}</ul>
  <p class="fine">Painted by <code>games/dunder-quest/tools/make_channel.py</code>.</p>
</section>

<section class="section kit" aria-labelledby="yt-about-h">
  <p class="kicker">dunder_quest.__channel__.about</p>
  <h2 id="yt-about-h">The channel's details</h2>
  <p class="lede">In Studio under Customization → Basic info, plus the keywords under Settings → Channel.</p>
  {copy_block("Description", CHANNEL_DESCRIPTION, f"{len(CHANNEL_DESCRIPTION)} / 1000")}
  {copy_block("Keywords", CHANNEL_KEYWORDS, f"{len(CHANNEL_KEYWORDS)} / 500")}
  <div class="yt-links">{links}</div>
  <h3>Playlists</h3>
  <div class="table-wrap"><table>
    <thead><tr><th>Playlist</th><th>What goes in it</th></tr></thead>
    <tbody>{playlists}</tbody>
  </table></div>
</section>

<section class="section kit" aria-labelledby="yt-videos-h">
  <p class="kicker">dunder_quest.__channel__.videos</p>
  <h2 id="yt-videos-h">The videos</h2>
  <p class="lede">Each trailer's upload form, field by field. Check the chapter times against the uploaded video: YouTube needs the first at 0:00, at least three, and each at least 10 seconds long.</p>
  <div class="table-wrap"><table class="settings">
    <thead><tr><th scope=col>Setting</th><th scope=col>For every video</th></tr></thead>
    <tbody>{settings}</tbody>
  </table></div>
  {kits}
  <p class="fine">Once a trailer is up, put its video ID in <code>TRAILER_ID</code>, <code>FM_TRAILER_ID</code> or <code>CURB_TRAILER_ID</code> in <code>site/build.py</code>, and the site embeds it.</p>
</section>"""
    return brand_page("youtube", body, prefix)


def build_brand_launch(prefix: str) -> str:
    launch = "".join(launch_post(*post) for post in LAUNCH)
    body = f"""
<section class="section kit" aria-labelledby="launch-h">
  <p class="kicker">dunder_quest.__launch__</p>
  <h2 id="launch-h">Launch day</h2>
  <p class="lede">Post on a Tuesday, Wednesday or Thursday, starting with Hacker News at 8:30 AM Eastern, when both the US and Europe are reading. The rest follow through the day. Each one says what Opus 5.5 built and plainly what other models made. The ones with room for a story say why it's a learning game at all.</p>
  <ol class="launch">{launch}</ol>
  <p class="fine">Never ask for upvotes on any of them. Sharing a post is fine; asking for votes gets it removed. Once one does well, mention it in the others.</p>
</section>"""
    return brand_page("launch", body, prefix)


## X counts every link as 23 characters, whatever its length.
LIMITS = {"X": 280, "Bluesky": 300}


def post_length(platform: str, text: str) -> int:
    if platform == "X":
        return len(re.sub(r"https?://\S+", "x" * 23, text))
    return len(text)


def launch_post(platform: str, when: str, title: str, posts: list[str], tips: str) -> str:
    def block(label: str, text: str) -> str:
        limit = LIMITS.get(platform)
        return copy_block(label, text, f"{post_length(platform, text)} / {limit}" if limit else "")
    blocks = block("Title", title) if title else ""
    for i, post in enumerate(posts):
        label, text = post if isinstance(post, tuple) else (f"Post {i + 1} of {len(posts)}" if len(posts) > 1 else "Post", post)
        blocks += block(label, text)
    return (f'<li><h3><span class="when">{esc(when)}</span> {esc(platform)}</h3>'
            f"{blocks}<p class=\"fine\">{esc(tips)}</p></li>")


def build_404(prefix: str) -> str:
    body = f"""
<section class="section page-head lost">
  <p class="kicker">404</p>
  <h1>That page isn't on the trail</h1>
  <figure class="code traceback"><pre><code>Traceback (most recent call last):
  File "quest.py", line 404, in &lt;module&gt;
    page = trail.pages[address]
<span class="err">KeyError</span>: 'this page'</code></pre></figure>
  <p class="lede">Check the address for a typo, or start again from one of these.</p>
  <div class="cta"><a class="btn" href="{prefix}">Home</a><a class="btn btn-ghost" href="{prefix}lessons/">Lessons</a><a class="btn btn-ghost" href="{prefix}play/">Play</a></div>
</section>"""
    return page("Page not found", body, prefix)


## Lesson pages renamed in the Holy Grail rework: old slug -> new slug. Their
## old addresses were already shared, so `_redirects` keeps them working.
OLD_SLUGS = {
    "amber-hollow": "shrubbery-wood",
    "cinder-span": "cheese-shoppe",
    "kiln-mouth": "cave-of-the-bunny",
    "smelters-fork": "ministry-of-walks",
    "bellows-bridge": "bridge-of-peril",
    "crucible-crown": "castle-aargh",
}


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def tag_play_page(index: Path) -> None:
    """Give the game's exported page the same preview and analytics tags as
    the site. Godot writes play/index.html after this script builds the
    pages, so `scripts/export_web.sh` runs this as a second step."""
    desc = "Play Dunder Quest, a pixel-art platformer that teaches Python, right in your browser."
    text = index.read_text(encoding="utf-8")
    if 'property="og:title"' in text:
        return
    tags = f'<meta name="description" content="{esc(desc)}">\n{head_tags("Play Dunder Quest", desc, "play/", "home.png", HOME_ALT)}\n'
    index.write_text(text.replace("</head>", tags + "</head>", 1), encoding="utf-8")
    print(f"tagged {index}")


FLATMATES_ALT = "Flatmates.js title art: two flatmates by their front door on a Croydon tower block landing at dusk."
FLATMATES_DESC = ("Flatmates.js, a Dunder Quest game: two mismatched flatmates, two points of view, and the JavaScript "
                  "one of them runs. Play it free in your browser.")


def tag_flatmates_page(index: Path) -> None:
    """The same tags for Flatmates.js, the JavaScript game in flatmates/,
    which Godot exports to flatmates/play/index.html."""
    desc = "Play Flatmates.js, the Dunder Quest game that teaches JavaScript, right in your browser."
    text = index.read_text(encoding="utf-8")
    if 'property="og:title"' in text:
        return
    tags = (f'<meta name="description" content="{esc(desc)}">\n'
            f'{head_tags("Play Flatmates.js · Dunder Quest", desc, "flatmates/play/", "flatmates.png", FLATMATES_ALT)}\n')
    index.write_text(text.replace("</head>", tags + "</head>", 1), encoding="utf-8")
    print(f"tagged {index}")


## Flatmates.js's own page at /flatmates/, in its Croydon colors. Its lesson
## cards come from `flatmates/data/lessons.json`, the bank the game reads.
## The stops match `flatmates/core/progress.gd`, each puzzle is the one its
## `flatmates/stages/stage_N.gd` lays out, and each laptop is a script from
## that stage with one blank, as the game's editor shows it. `{}` is the
## blank; every option is (text, works, what happens). Art comes from
## `flatmates/tools/site_art.py`.
FM_STOPS: list[dict] = [
    {
        "id": 1, "slug": "flat-5b", "name": "Flat 5B", "stop": "Hermes House",
        "puzzle": "The kitchen door only stays open while someone stands on the doormat, and left alone Jazz drifts back to the sofa. So Clive scripts him onto the mat. In the hall the floorboards are up, a hole five boards wide that Clive can't jump. Jazz has to walk to the edge, jump it and step onto the rug that folds the boards down, in that order.",
        "file": "jazz.js", "runs": "Jazz runs this.",
        "code": "// To the edge, over the hole, onto the rug.\njazz.walk(3);\n{}\njazz.walk(1);",
        "options": [
            ("jazz.jump();", True, "Jazz walks to the edge, clears the hole and lands on the rug. The boards fold down for Clive."),
            ("jazz.walk(5);", False, "Jazz walks five more boards, straight into the hole. He seems fine. He usually does."),
            ("jazz.jump;", False, "Without the brackets nothing calls the method, so Jazz only thinks about jumping. He stops at the edge."),
        ],
    },
    {
        "id": 2, "slug": "croydon-credit", "name": "Croydon Credit", "stop": "Croydon Credit",
        "puzzle": "Jazz has come into Clive's office to ask for a loan, which Clive is not allowed to give him. The staff door's keypad wants the desk number, then the extension, and the building's laptop builds the code from two constants. Past the door, the lift goes to whatever floor its script says, but only for a number: \"2\" in quotes is a string, and the lift refuses it.",
        "file": "door.js", "runs": "The building runs this.",
        "code": "const desk = 12;\nconst ext = 7;\nconst code = {};\nkeypad.enter(code);",
        "options": [
            ("`${desk}${ext}`", True, "The keypad gets \"127\": the value of desk, then the value of ext. The staff door opens."),
            ("`desk${ext}`", False, "Outside ${ }, desk is just the word desk. The keypad gets \"desk7\" and beeps at you."),
            ("desk + ext", False, "Two numbers added together make 19. The keypad wanted them side by side."),
        ],
    },
    {
        "id": 3, "slug": "band-practice", "name": "Band Practice", "stop": "The Cellar Bar",
        "puzzle": "The band's stage in the cellar bar is five tiles up. Every strum lifts the speaker stack one notch, so a loop that strums four times carries Clive up to where he can climb off. Five is too loud, and the landlord pulls the plug. Up top, three amps each raise a riser into a stair, and only a for...of over the whole array switches on all three.",
        "file": "jazz.js", "runs": "Jazz runs this.",
        "code": "// Each strum lifts the speakers one notch.\nfor (let i = 0; i {} 4; i++) {\n  jazz.strum();\n}",
        "options": [
            ("<", True, "i goes 0, 1, 2, 3: four strums, four notches, and Clive climbs off onto the stage."),
            ("<=", False, "i goes 0 to 4. That's five strums, and the fifth is too loud. The landlord pulls the plug."),
            (">", False, "0 > 4 is false before the first lap, so the loop never runs. Jazz doesn't strum once. Not unheard of."),
        ],
    },
    {
        "id": 4, "slug": "the-stag-do", "name": "The Stag Do", "stop": "Wet Bottom Farm",
        "puzzle": "Two farm gates, one behind the other, and two plates up in the hay loft, one for each gate. Clive needs Jazz on the first plate until he's between the gates, then on the second. A plain list of steps can't wait for that. A listener can: when Clive rings the bell in the pen, the callback walks Jazz along the loft.",
        "file": "jazz.js", "runs": "Jazz runs this.",
        "code": "jazz.walk(2);\nbell.addEventListener({}, () => {\n  jazz.walk(4);\n});",
        "options": [
            ("\"ring\"", True, "Clive rings the bell, the callback runs, and Jazz walks along the loft to the second plate."),
            ("\"click\"", False, "The bell never clicks. It rings. Jazz waits on the first plate for an event that never comes."),
            ("\"ding\"", False, "Close, but the event is called \"ring\". Jazz listens for a ding forever, which suits him."),
        ],
    },
    {
        "id": 5, "slug": "east-croydon", "name": "East Croydon", "stop": "East Croydon",
        "puzzle": "The ticket barrier opens for one second when someone presses the help button, and the button is a long walk from the barrier. setTimeout presses it later, once Clive has had time to get there. On the platform, the train doors open when the tannoy hears \"mind\", \"the\", \"gap!\" in that order, and the laptop logs \"gap!\" from a setTimeout of 0.",
        "file": "jazz.js", "runs": "Jazz runs this.",
        "code": "// Jazz is at the help button.\nsetTimeout(() => {\n  jazz.press();\n}, {});",
        "options": [
            ("2500", True, "Two and a half seconds later Jazz presses the button, just as Clive reaches the barrier. It opens for him."),
            ("500", False, "Half a second is too soon. The barrier opens and shuts again while Clive is still walking."),
            ("0", False, "A timer of 0 still waits for the script to finish, but not for Clive. The barrier opens to nobody."),
        ],
    },
    {
        "id": 6, "slug": "the-wedding", "name": "The Wedding", "stop": "St Agatha's",
        "puzzle": "Tess from Accounts is marrying Gary from Sales. Jazz is the music, and Clive, against his better judgement, is doing a reading. Jazz has to play the march once Clive reaches the altar, and await is how his script waits. Out the back, the getaway car leaves on car.drive(), so it should wait on Promise.all of both flatmates reaching it, or it goes with nobody in it.",
        "file": "jazz.js", "runs": "Jazz runs this.",
        "code": "async function ceremony() {\n  {} clive.reach(altar);\n  jazz.strum();\n}\nceremony();",
        "options": [
            ("await", True, "The function pauses until Clive reaches the altar, then Jazz plays the march, on cue for once."),
            ("", False, "Without await, Jazz strums straight away, to an empty aisle. Clive arrives to silence."),
        ],
    },
]
FM_KEYWORDS = {"const", "let", "var", "for", "of", "in", "if", "else", "return", "function", "async", "await",
               "new", "true", "false", "null", "undefined", "typeof", "while"}
FM_TOKEN = re.compile(r"(?P<c>//[^\n]*)|(?P<s>\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)"
                      r"|(?P<n>\b\d+(?:\.\d+)?\b)|(?P<w>[A-Za-z_$][\w$]*)(?P<call>\s*\()?")
FM_BLANK = "\x00"


def highlight_js(code: str) -> str:
    """JavaScript as HTML spans, with the game's editor's colors: keywords,
    strings, numbers, comments, and the names of calls. FM_BLANK passes
    through untouched."""
    out: list[str] = []
    pos = 0
    for m in FM_TOKEN.finditer(code):
        out.append(esc(code[pos:m.start()]))
        pos = m.end()
        if m.group("w"):
            word = m.group("w")
            cls = "k" if word in FM_KEYWORDS else "b" if m.group("call") else ""
            out.append(f'<span class="{cls}">{esc(word)}</span>' if cls else esc(word))
            out.append(esc(m.group("call") or ""))
        else:
            cls = m.lastgroup or ""
            out.append(f'<span class="{cls}">{esc(m.group())}</span>')
    out.append(esc(code[pos:]))
    return "".join(out)


def js_block(code: str) -> str:
    return f'<figure class="code"><pre><code>{highlight_js(code)}</code></pre></figure>'


def fm_laptop(stop: dict) -> str:
    """The stop's laptop: tap the blank or an option, then Run. Without
    JavaScript, the options and the answer still show."""
    code = highlight_js(stop["code"].replace("{}", FM_BLANK))
    code = code.replace(FM_BLANK, '<button class="blank" type="button" aria-label="The blank: tap to change it" disabled>?</button>')
    picks = "".join(
        f'<li><button class="pick" type="button" data-ok="{str(ok).lower()}" data-result="{esc(result)}" aria-pressed="false" disabled>'
        f'<code>{esc(text) if text else "(nothing)"}</code></button></li>'
        for text, ok, result in stop["options"]
    )
    answer = next((text, result) for text, ok, result in stop["options"] if ok)
    return f"""<figure class="laptop" data-laptop>
  <figcaption><b>{esc(stop['file'])}</b> {esc(stop['runs'])}</figcaption>
  <pre><code>{code}</code></pre>
  <div class="laptop-bar"><span>Options:</span><ul class="picks">{picks}</ul><button class="run" type="button" disabled>Run</button></div>
  <p class="out" role="status" hidden><b></b> <span></span></p>
  <details><summary>Show the answer</summary><p><code>{esc(answer[0])}</code>. {esc(answer[1])}</p></details>
</figure>"""


FM_WHO = {"clive": "Clive", "jazz": "Jazz"}


def fm_card(card: dict) -> str:
    who = card["who"]
    return f"""<article class="voice voice-{who}">
  <p class="voice-kick">{FM_WHO[who]}'s inner voice</p>
  <h4>{esc(card['title'])}</h4>
  {js_block(chr(10).join(card['code']))}
  <p>{esc(card['text'])}</p>
</article>"""


def build_flatmates(prefix: str) -> str:
    """The Flatmates.js page. `prefix` reaches the site root; the game itself
    is in `play/` next to this page."""
    img = f"{prefix}static/img/flatmates/"
    bank = json.loads((FLATMATES / "data" / "lessons.json").read_text(encoding="utf-8"))
    line = "".join(
        f'<li><a href="#{s["slug"]}"><span class="ln-stop">{esc(s["stop"])}</span>'
        f'<span class="ln-lesson">{esc(bank[str(s["id"])]["lesson"])}</span></a></li>'
        for s in FM_STOPS
    )
    stops = []
    for s in FM_STOPS:
        lesson = bank[str(s["id"])]
        cards = "".join(fm_card(c) for c in lesson["cards"] if c["id"] != "c1_heads")
        stops.append(f"""
<article class="stop" id="{s['slug']}">
  <header>
    <p class="kicker"><span class="roundel">{s['id']}</span> {esc(s['stop'])}</p>
    <h3>{esc(s['name'])} <span>{esc(lesson['lesson'])}</span></h3>
  </header>
  <div class="stop-grid">
    <div>
      <img src="{img}stage{s['id']}_start.png" alt="{esc(s['name'])}, as the stage opens" width="480" height="270" loading="lazy">
      <p>{esc(s['puzzle'])}</p>
    </div>
    {fm_laptop(s)}
  </div>
  <div class="voices">{cards}</div>
</article>""")
    controls = [
        ("Move", "A / D or ← / →", "D-pad or left stick"),
        ("Jump", "Space, W or ↑", "A / Cross"),
        ("Swap heads", "Tab or Q", "Y / Triangle or RB"),
        ("Open a laptop, ring a bell, pull a lever", "E", "X / Square"),
        ("Run the script", "R", "LB / L1"),
        ("Pause", "Esc or P", "Start / Options"),
    ]
    rows = "".join(f"<tr><th scope=row>{a}</th><td data-label=Keyboard>{k}</td><td data-label=Gamepad>{p}</td></tr>" for a, k, p in controls)
    total = sum(len(v["cards"]) for v in bank.values())
    body = f"""
<section class="hero fm-hero">
  <img class="hero-art" src="{img}title.png" alt="Pixel art of two flatmates, one in a suit with his arms folded and one holding a guitar, by their front door on a tower block landing at dusk" width="480" height="270">
  <div class="hero-copy">
    <p class="prompt" aria-hidden="true">&gt; node flat5b.js</p>
    <h1>flatmates<i>.js</i></h1>
    <p class="tag">Two flatmates. Two points of view. One of them runs your JavaScript.</p>
    <p class="hero-sub">Clive can't jump much. Jazz can jump, and that's about it. Swap between their heads to get the pair of them across Croydon, and write the script that the one you aren't playing runs, or he'll wander back to the sofa.</p>
    <div class="cta">
      <a class="btn" href="play/">Play in your browser</a>
      <a class="btn btn-ghost" href="#line">See the six stops</a>
    </div>
    <p class="fine">Free, no signup. Keyboard, gamepad or touch.</p>
  </div>
</section>

<section class="section" id="trailer" aria-labelledby="trailer-h">
  <p class="kicker">The trailer</p>
  <h2 id="trailer-h">Earlier that Saturday</h2>
  {trailer_player(FM_TRAILER_ID, f"{img}trailer.png", FM_THUMB_ALT, "Flatmates.js")}
  <p class="fine">More on the channel: <a href="{CHANNEL}">youtube.com/@dunderquest</a>.</p>
</section>

<section class="section" id="heads" aria-labelledby="heads-h">
  <p class="kicker">Two heads, one flat</p>
  <h2 id="heads-h">You're whichever one you aren't scripting</h2>
  <ul class="mates">
    <li class="mate-clive"><img src="{img}clive.png" alt="" width="64" height="96">
      <div><h3>Clive</h3><p>Works in credit at Croydon Credit. Owns a tie for weekends. Jumps like a man carrying a briefcase, because he usually is. Left alone, he drifts back to his armchair.</p></div></li>
    <li class="mate-jazz"><img src="{img}jazz.png" alt="" width="64" height="96">
      <div><h3>Jazz</h3><p>Would-be rock god, between bands. Jumps high and does very little else. Left alone, he drifts back to the sofa, where his real work happens.</p></div></li>
  </ul>
  <ol class="loop">
    <li><img src="{img}stage3_editor.png" alt="A laptop's editor open on jazz.js: a for loop with a blank where the comparison goes" width="480" height="270" loading="lazy">
      <h3>Open his laptop</h3><p>Laptops around each stage open the other flatmate's to-do list as real JavaScript, with blanks to fill. Pick what goes in each one.</p></li>
    <li><img src="{img}stage4_start.png" alt="The stag do at a farm: Clive in the pen below, Jazz up in the hay loft by two plates" width="480" height="270" loading="lazy">
      <h3>Run it, then swap</h3><p>Run the script and you swap into the other head. He does what you wrote while you play his flatmate, in JavaScript's order: his lines first, then timers, listeners and awaits.</p></li>
    <li><img src="{img}stage1_card.png" alt="Clive's inner voice card: Objects and methods, with jazz.walk(7) and jazz.jump()" width="480" height="270" loading="lazy">
      <h3>Listen to the inner voice</h3><p>Each flatmate thinks out loud along the top of the screen. Some thoughts open a lesson card, with the code and the idea behind it, in whoever's voice you're in.</p></li>
  </ol>
</section>

<section class="section" id="line" aria-labelledby="line-h">
  <p class="kicker">The Croydon line</p>
  <h2 id="line-h">Six stops, six pieces of JavaScript</h2>
  <p class="lede">The game is a tram line across Croydon, and each stop teaches one idea. They build on each other, from calling a method to awaiting two promises at once. Every stop has a laptop below, with one of its scripts to try.</p>
  <ol class="line">{line}</ol>
  {"".join(stops)}
  <p class="count"><b>{total}</b> lesson cards · <b>6</b> stops · every snippet checked against Node</p>
</section>

<section class="section" id="controls" aria-labelledby="controls-h">
  <p class="kicker">Controls</p>
  <h2 id="controls-h">How to play</h2>
  <div class="table-wrap"><table class="controls">
    <thead><tr><th scope=col>Action</th><th scope=col>Keyboard</th><th scope=col>Gamepad</th></tr></thead>
    <tbody>{rows}</tbody>
  </table></div>
  <p class="fine">On a phone or tablet, turn it sideways: the on-screen buttons include Swap and Code. A fall sends you back to the last Wi-Fi router you passed. Each stop hides six custard creams. Your progress saves in this browser, separately from Dunder Quest's.</p>
  <a class="btn" href="play/">Play Flatmates.js</a>
</section>

<section class="section fm-family" aria-labelledby="family-h">
  <p class="kicker">a {WORDMARK} game</p>
  <h2 id="family-h">Prefer Python?</h2>
  <p class="lede">Flatmates.js is the second Dunder Quest game. The first, <a href="{prefix}{QUEST_PAGE}">Dunder Quest</a>, teaches Python on a quest for the Grail: slice a list to lay a bridge, loop a lift up a cave wall, and duel the Bridgekeeper. The third, <a href="{prefix}curb/">Curb Your Oxidation</a>, teaches Rust on the Westside of LA.</p>
  <p class="fine">Flatmates.js is an homage to a certain Croydon flat-share sitcom. The names and jokes are winks, not the show's own characters or lines, and it isn't affiliated with or endorsed by anyone who made it.</p>
</section>"""
    return fm_page(body, prefix)


FM_NAV = [("#heads", "Two heads"), ("#line", "The stops"), ("#controls", "How to play")]


def fm_page(body: str, prefix: str) -> str:
    links = "".join(f'<a href="{href}">{label}</a>' for href, label in FM_NAV)
    title = "Flatmates.js · Dunder Quest"
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{esc(FLATMATES_DESC)}">
{head_tags(title, FLATMATES_DESC, "flatmates/", "flatmates.png", FLATMATES_ALT)}
<link rel="icon" href="{prefix}static/img/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="{prefix}static/style.css">
<link rel="stylesheet" href="{prefix}static/flatmates.css">
</head>
<body class="fm">
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="./"><img src="{prefix}static/img/flatmates/clive.png" alt="" width="16" height="24"><span>flatmates<i>.js</i></span></a>
  <nav aria-label="Flatmates.js">{links}<a class="fm-home" href="{prefix}">All games</a></nav>
  <a class="btn btn-small" href="play/">Play</a>
</header>
<main id="main">
{body}
</main>
<footer class="foot">
  <p><img src="{prefix}static/img/flatmates/jazz.png" alt="" width="16" height="24"> Flatmates.js. Two flatmates, one Croydon, six stops of JavaScript.</p>
  <p><a href="play/">Play in your browser</a> · <a href="#line">The stops</a> · <a href="{prefix}{QUEST_PAGE}">Dunder Quest, the Python game</a> · <a href="{REPO}/tree/main/games/flatmates">Source on GitHub</a></p>
</footer>
<script src="{prefix}static/laptop.js"></script>
<script src="{prefix}static/trailer.js"></script>
</body>
</html>
"""



CURB_ALT = "Curb Your Oxidation: a black title card, the name in yellow serif, over a palm-lined Westside street at sunset."
CURB_DESC = ("Curb Your Oxidation, a Dunder Quest game that teaches Rust: the borrow checker is the unwritten "
             "social contract, and every petty dispute is settled by a Rust program. Play it free in your browser.")


def tag_curb_page(index: Path) -> None:
    """The same tags for Curb Your Oxidation, the Rust game in curb/, which
    Godot exports to curb/play/index.html."""
    desc = "Play Curb Your Oxidation, the Dunder Quest game that teaches Rust, right in your browser."
    text = index.read_text(encoding="utf-8")
    if 'property="og:title"' in text:
        return
    tags = (f'<meta name="description" content="{esc(desc)}">\n'
            f'{head_tags("Play Curb Your Oxidation · Dunder Quest", desc, "curb/play/", "curb.png", CURB_ALT)}\n')
    index.write_text(text.replace("</head>", tags + "</head>", 1), encoding="utf-8")
    print(f"tagged {index}")


## Curb Your Oxidation's own page at /curb/: black title cards in heavy Franklin Gothic
## on a bright Westside page. Everything about the season comes from
## `curb/data/scenes.json`, the data the game plays, and every pad answers
## from `site/curb_cases.json`, the in-game checker's verdict on each
## combination of blanks (both made by `site/curb_art.py`, which also copies
## the art).
CURB_RS_KEYWORDS = {"fn", "let", "mut", "match", "if", "else", "for", "in", "impl", "struct", "enum", "self",
                    "Self", "return", "pub", "use", "while", "loop", "as", "ref", "move", "true", "false"}
CURB_RS_TYPES = {"i32", "i64", "u32", "usize", "f64", "bool", "str", "String", "Vec", "Option", "Result",
                 "Some", "None", "Ok", "Err"}
CURB_TOKEN = re.compile(r"(?P<c>//[^\n]*)|(?P<s>\"(?:\\.|[^\"\\])*\")|(?P<l>'[a-z_]+\b(?!'))"
                        r"|(?P<n>\b\d+(?:\.\d+)?\b)|(?P<w>[A-Za-z_][\w]*)(?P<bang>!)?(?P<call>\s*\()?")
## The cast on the page, in the order they're introduced.
CURB_CAST = ["barry", "gil", "sharon", "carol", "lamont", "ted"]
CURB_CAST_NOTES = {
    "barry": "Semi-retired TV writer on the Westside. Lives by rules nobody else has heard of, and holds everyone to them.",
    "gil": "Barry's manager and best friend. Endlessly patient, which Barry tests daily.",
    "sharon": "Gil's wife, and the borrow checker. When a plan breaks the rules, she bursts in at the exact line, with rustc's own error and an opinion about it.",
    "carol": "Barry's ex-wife, somehow still on speaking terms. Counts his minutes.",
    "lamont": "The houseguest who came for one night. It's been six weeks.",
    "ted": "The neighbor whose lawnmower has been in Barry's garage for six weeks.",
}


def highlight_rs(code: str) -> str:
    """Rust as HTML spans, in the pad's ink colors: keywords, types, strings,
    numbers, lifetimes, comments, macros and calls. Private-use characters
    (the blanks) pass through untouched."""
    out: list[str] = []
    pos = 0
    for m in CURB_TOKEN.finditer(code):
        out.append(esc(code[pos:m.start()]))
        pos = m.end()
        if m.group("w"):
            word = m.group("w")
            if m.group("bang"):
                out.append(f'<span class="m">{esc(word)}!</span>')
            else:
                cls = ("k" if word in CURB_RS_KEYWORDS else "t" if word in CURB_RS_TYPES or word[:1].isupper()
                       else "b" if m.group("call") else "")
                out.append(f'<span class="{cls}">{esc(word)}</span>' if cls else esc(word))
            out.append(esc(m.group("call") or ""))
        else:
            out.append(f'<span class="{m.lastgroup}">{esc(m.group())}</span>')
    out.append(esc(code[pos:]))
    return "".join(out)


def curb_said(data: dict, line: list) -> str:
    """One line of dialogue, as a script would print it."""
    who = data["cast"].get(line[0], {}).get("name", line[0].title())
    return f'<p><b>{esc(who)}</b> {esc(line[1])}</p>'


def curb_verdict(data: dict, plan: dict, case: dict) -> dict:
    """What the scene does with one combination of blanks, the way the game
    plays it: Sharon's interruption, the scene playing out, or a panic."""
    def lines(say: list) -> list:
        return [[data["cast"][w]["name"], t] for w, t, *_ in say]
    if not case["ok"]:
        code, rest = case["first"].split(" line ", 1)
        line, msg = rest.split(": ", 1)
        rant = plan.get("rants", {}).get(code) or data["rants"].get(code, data["rants"]["syntax"])
        return {"kind": "err", "head": f"error[{code}]: {msg}", "at": f"--> {plan['file']}:{line}",
                "lines": [["Sharon", rant]]}
    out = list(case["stdout"])
    if case["panic"]:
        out.append(f"thread 'main' panicked: {case['panic']}")
        return {"kind": "panic", "out": out, "lines": lines(plan.get("panic_line") or [["sharon", data["rants"]["panic"]]])}
    if case["stdout"] == plan["expect"]:
        key = ",".join(f"{k}={v}" for k, v in case["picks"].items())
        return {"kind": "ok", "out": out, "lines": lines(plan.get("remarks", {}).get(key, []) + plan["success"])}
    return {"kind": "wrong", "out": out, "lines": lines(plan.get("wrong") or [[plan["npc"], data["rants"]["wrong"]]])}


def curb_pad(data: dict, plan: dict, cases: list[dict]) -> str:
    """A plan on Barry's yellow legal pad: tap a blank to cycle its options,
    then Run it (static/pad.js). It opens on the scene's starting picks, so
    the first run fails the way the game's does. Without JavaScript the
    options and the answer still show."""
    order: list[str] = []
    for line in plan["code"]:
        order += [n for n in re.findall(r"«(\w+)»", line) if n not in order]
    src = "\n".join(plan["code"])
    for i, name in enumerate(order):
        src = src.replace(f"«{name}»", chr(0xE000 + i))
    code = highlight_rs(src)
    for i, name in enumerate(order):
        opts = plan["slots"][name]
        start = opts.index(plan["start"][name])
        code = code.replace(chr(0xE000 + i), (
            f'<button class="blank" type="button" data-pick="{start}" '
            f"data-options='{esc(json.dumps(opts))}' aria-label=\"Blank {i + 1}: tap to change it\" disabled>"
            f"{esc(opts[start]) or '…'}</button>"))
    verdicts = {}
    for case in cases:
        if case["plan"] == plan["id"]:
            key = ",".join(str(plan["slots"][n].index(case["picks"][n])) for n in order)
            verdicts[key] = curb_verdict(data, plan, case)
    options = "".join(
        f'<li><span>Blank {i + 1}:</span> '
        + " · ".join(f"<code>{esc(o) if o else '(nothing)'}</code>" for o in plan["slots"][n]) + "</li>"
        for i, n in enumerate(order))
    solution = " and ".join(f"<code>{esc(plan['solution'][n]) or '(nothing)'}</code>" for n in order)
    said = "".join(f"<li><code>{esc(line)}</code></li>" for line in plan["expect"])
    return f"""<figure class="pad" data-pad data-verdicts='{esc(json.dumps(verdicts, ensure_ascii=False))}'>
  <figcaption><b>{esc(plan['file'])}</b> {esc(plan['title'])}</figcaption>
  <pre><code>{code}</code></pre>
  <ul class="pad-options">{options}</ul>
  <p class="pad-hint"><b>Barry, thinking:</b> {esc(plan['hint'])}</p>
  <div class="pad-bar"><span>Tap a blank to change it.</span><button class="run" type="button" disabled>Run it</button></div>
  <div class="pad-out" role="status" hidden></div>
  <details><summary>Show the answer</summary><p>{solution}. Then the scene plays out, one line per <code>println!</code>:</p><ol class="pad-said">{said}</ol></details>
</figure>"""


def curb_card(data: dict, card: dict) -> str:
    who = data["cast"][card["who"]]["name"]
    tail = (f'<p class="rule-err">error[{esc(card["error"])}]</p>' if card.get("error")
            else '<p class="rule-out">prints ' + " ".join(f"<code>{esc(o)}</code>" for o in card.get("output", [])) + "</p>")
    return f"""<article class="rule">
  <p class="rule-kick">{esc(who)} explains</p>
  <h4>{esc(card['title'])}</h4>
  <figure class="code"><pre><code>{highlight_rs(chr(10).join(card['code']))}</code></pre></figure>
  {tail}
  <p>{esc(card['text'])}</p>
</article>"""


def build_curb(prefix: str) -> str:
    """The Curb Your Oxidation page. `prefix` reaches the site root; the game
    itself is in `play/` next to this page."""
    img = f"{prefix}static/img/curb/"
    data = json.loads((CURB / "data" / "scenes.json").read_text(encoding="utf-8"))
    cases = json.loads((SITE / "curb_cases.json").read_text(encoding="utf-8"))
    scenes = data["scenes"]
    guide = "".join(
        f'<li><a href="#ep{s["id"]}"><span class="ep-n">Episode {s["id"]}</span>'
        f'<span class="ep-t">{esc(s["title"])}</span><span class="ep-l">{esc(s["lesson"])}</span></a></li>'
        for s in scenes)
    episodes = []
    for s in scenes:
        cards = "".join(curb_card(data, data["cards"][p["card"]]) for p in s["plans"])
        cast = ", ".join(data["cast"][c]["name"] for c, _ in s["cast"])
        episodes.append(f"""
<article class="ep" id="ep{s['id']}">
  <header class="title-card"><p>Episode {s['id']}</p><h3>{esc(s['title'])}</h3></header>
  <p class="ep-meta"><b>{esc(s['place'])}</b> · {esc(s['lesson'])} · with {esc(cast)}</p>
  <div class="ep-grid">
    <div>
      <img src="{img}{s['id']:02d}_opening.png" alt="{esc(s['place'])}, as the episode opens" width="480" height="270" loading="lazy">
      <div class="script">{"".join(curb_said(data, line) for line in s['opening'])}</div>
    </div>
    {curb_pad(data, s["plans"][0], cases)}
  </div>
  <div class="rules">{cards}</div>
</article>""")
    cast = "".join(
        f'<li class="who-{w}"><img src="{img}{w}_face.png" alt="" width="96" height="96">'
        f'<div><h3>{esc(data["cast"][w]["full"])}</h3><p>{esc(CURB_CAST_NOTES[w])}</p></div></li>'
        for w in CURB_CAST)
    codes: list[str] = []
    for s in scenes:
        for p in s["plans"]:
            if p["start_error"] not in codes:
                codes.append(p["start_error"])
    rulebook = "".join(f'<li><code>error[{c}]</code><q>{esc(data["rants"][c])}</q></li>' for c in codes)
    controls = [
        ("Walk", "← / → or A / D", "D-pad or left stick"),
        ("Talk, open a plan", "E, Space or Enter", "X / Square or A / Cross"),
        ("Pick a blank on the pad", "← / →", "D-pad left and right"),
        ("Change the blank", "↑ / ↓", "D-pad up and down"),
        ("Run the plan", "Enter or R", "LB / L1"),
        ("Close the pad, pause", "Esc or P", "Start / Options"),
    ]
    rows = "".join(f"<tr><th scope=row>{a}</th><td data-label=Keyboard>{k}</td><td data-label=Gamepad>{p}</td></tr>" for a, k, p in controls)
    ## No trailer yet: the section appears once CURB_TRAILER_ID is set.
    trailer = "" if not CURB_TRAILER_ID else f"""
<section class="section" id="trailer" aria-labelledby="trailer-h">
  <p class="kicker">The trailer</p>
  <h2 id="trailer-h">Previously, on the Westside</h2>
  {trailer_player(CURB_TRAILER_ID, f"{img}trailer.png", CURB_THUMB_ALT, "Curb Your Oxidation")}
  <p class="fine">More on the channel: <a href="{CHANNEL}">youtube.com/@dunderquest</a>.</p>
</section>
"""
    total = len(data["cards"])
    plans = sum(len(s["plans"]) for s in scenes)
    body = f"""
<section class="cy-hero">
  <div class="title-card cy-title">
    <p class="prompt" aria-hidden="true">$ cargo run --bin barry</p>
    <h1>Curb Your Oxidation</h1>
    <p class="tag">The borrow checker is the unwritten social contract. Learn Rust.</p>
    <p class="hero-sub">Barry Danvers lives by rules nobody else has heard of. Every petty dispute on the Westside, over a latte, a lawnmower or the last shrimp, is settled by a plan, and every plan is a short Rust program on his yellow legal pad. Break the rules and Sharon will let you know. At the exact line.</p>
    <div class="cta">
      <a class="btn" href="play/">Play in your browser</a>
      <a class="btn btn-ghost" href="#season">See the ten episodes</a>
    </div>
    <p class="fine">Free, no signup. Keyboard, gamepad or touch.</p>
  </div>
  <img class="cy-strip" src="{img}title.png" alt="Pixel art of a palm-lined Westside street at sunset, a silver hybrid parked at the curb" width="480" height="270">
</section>
{trailer}
<section class="section" id="how" aria-labelledby="how-h">
  <p class="kicker">How an episode goes</p>
  <h2 id="how-h">Plan it. Rehearse it. Get interrupted.</h2>
  <p class="lede">The way rustc reads your whole program before anything runs, Barry plays every plan through in his head first. If it breaks the rules, it never happens. If it compiles, every <code>println!</code> is somebody saying that line out loud.</p>
  <ol class="loop">
    <li><img src="{img}03_pad.png" alt="Barry's legal pad open on gift.rs, with the blank in let host_gift = wine; picked out and three options below" width="480" height="270" loading="lazy">
      <h3>Write the plan</h3><p>Talk to someone and the dispute turns into a short Rust program on Barry's legal pad, with blanks to fill. Pick what goes in each.</p></li>
    <li><img src="{img}03_rant.png" alt="Sharon bursting in with error[E0382]: borrow of moved value" width="480" height="270" loading="lazy">
      <h3>Rehearse it, in sepia</h3><p>Barry runs it in his head, line by line. Break a rule and Sharon bursts in at that line with the real rustc error, <code>error[E0382]</code> and all, and an opinion about it.</p></li>
    <li><img src="{img}03_run.png" alt="The plan playing out for real: Sharon says Thanks for the Barolo while the code highlights her println! line" width="480" height="270" loading="lazy">
      <h3>Watch it happen</h3><p>When it compiles, the scene plays it out for real, and only moves on if the program prints exactly what should happen. Then a squint, a freeze frame, and the tuba.</p></li>
  </ol>
</section>

<section class="section" id="cast" aria-labelledby="cast-h">
  <p class="kicker">Starring</p>
  <h2 id="cast-h">The cast</h2>
  <ul class="cast">{cast}</ul>
  <p class="fine">Also appearing: Sol at the deli, who counts the samples; Whit Thornbury, who manages the country club; Philippe, maître d' of a bistro Barry can't get into; Dana at returns, who has heard it all; and Rain, the barista.</p>
</section>

<section class="section" id="season" aria-labelledby="season-h">
  <p class="kicker">The season</p>
  <h2 id="season-h">Ten episodes, ten pieces of Rust</h2>
  <p class="lede">Each episode is one petty dispute and one idea, and they build on each other: from <code>let mut</code> to ownership, borrowing and lifetimes. Every episode below has one of its plans on a pad to try. It opens on Barry's first idea, which is wrong.</p>
  <ol class="guide">{guide}</ol>
  {"".join(episodes)}
  <p class="count"><b>{total}</b> lesson cards · <b>{plans}</b> plans · every one compiled with the real rustc</p>
</section>

<section class="section" id="rules" aria-labelledby="rules-h">
  <p class="kicker">The rulebook</p>
  <h2 id="rules-h">rustc, as Sharon puts it</h2>
  <p class="lede">The error codes are the compiler's own. The delivery is Sharon's.</p>
  <ul class="rulebook">{rulebook}</ul>
</section>

<section class="section" id="controls" aria-labelledby="controls-h">
  <p class="kicker">Controls</p>
  <h2 id="controls-h">How to play</h2>
  <div class="table-wrap"><table class="controls">
    <thead><tr><th scope=col>Action</th><th scope=col>Keyboard</th><th scope=col>Gamepad</th></tr></thead>
    <tbody>{rows}</tbody>
  </table></div>
  <p class="fine">On a phone or tablet, turn it sideways and tap: tap someone to talk, tap a blank to change it. Your progress saves in this browser, separately from the other games'.</p>
  <a class="btn" href="play/">Play Curb Your Oxidation</a>
</section>

<section class="section cy-family" aria-labelledby="family-h">
  <p class="kicker">a {WORDMARK} game</p>
  <h2 id="family-h">Prefer Python, or JavaScript?</h2>
  <p class="lede">Curb Your Oxidation is the third Dunder Quest game. <a href="{prefix}{QUEST_PAGE}">Dunder Quest</a> teaches Python on a quest for the Grail, and <a href="{prefix}flatmates/">Flatmates.js</a> teaches JavaScript in a very small Croydon flat.</p>
  <p class="fine">Curb Your Oxidation is an homage to a certain LA cringe-comedy series. The names, lines and music are original, not the show's own, and it isn't affiliated with or endorsed by anyone who made it.</p>
</section>"""
    return curb_page(body, prefix)


CURB_NAV = [("#cast", "The cast"), ("#season", "Episodes"), ("#controls", "How to play")]


def curb_page(body: str, prefix: str) -> str:
    links = "".join(f'<a href="{href}">{label}</a>' for href, label in CURB_NAV)
    title = "Curb Your Oxidation · Dunder Quest"
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{esc(CURB_DESC)}">
{head_tags(title, CURB_DESC, "curb/", "curb.png", CURB_ALT)}
<link rel="icon" href="{prefix}static/img/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&family=Libre+Franklin:ital,wght@0,400..900;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="{prefix}static/style.css">
<link rel="stylesheet" href="{prefix}static/curb.css">
</head>
<body class="cy">
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="./"><img src="{prefix}static/img/curb/barry.png" alt="" width="12" height="24"><span>Curb Your Oxidation</span></a>
  <nav aria-label="Curb Your Oxidation">{links}<a class="cy-home" href="{prefix}">All games</a></nav>
  <a class="btn btn-small" href="play/">Play</a>
</header>
<main id="main">
{body}
</main>
<footer class="foot">
  <p><img src="{prefix}static/img/curb/sharon.png" alt="" width="12" height="24"> Curb Your Oxidation. One Westside, ten petty disputes, ten pieces of Rust.</p>
  <p><a href="play/">Play in your browser</a> · <a href="#season">The episodes</a> · <a href="{prefix}{QUEST_PAGE}">Dunder Quest, the Python game</a> · <a href="{prefix}flatmates/">Flatmates.js, the JavaScript game</a> · <a href="{REPO}/tree/main/games/curb">Source on GitHub</a></p>
</footer>
<script src="{prefix}static/pad.js"></script>
<script src="{prefix}static/trailer.js"></script>
</body>
</html>
"""


def main() -> None:
    if sys.argv[1:2] == ["--play"]:
        tag_play_page(Path(sys.argv[2]))
        return
    if sys.argv[1:2] == ["--flatmates"]:
        tag_flatmates_page(Path(sys.argv[2]))
        return
    if sys.argv[1:2] == ["--curb"]:
        tag_curb_page(Path(sys.argv[2]))
        return
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "build" / "site").resolve()
    out.mkdir(parents=True, exist_ok=True)
    bank = json.loads((QUEST / "data" / "lessons.json").read_text(encoding="utf-8"))

    static = out / "static"
    if static.exists():
        shutil.rmtree(static)
    shutil.copytree(SITE / "static", static)
    shutil.copyfile(SITE / "favicon.ico", out / "favicon.ico")  # painted by tools/make_og.py
    for name, src in IMAGES.items():
        shutil.copyfile(QUEST / src, static / "img" / name)
    (static / "img" / "shots").mkdir(parents=True, exist_ok=True)
    for name in SHOTS + [s["shot"] for s in STAGES]:
        shutil.copyfile(QUEST / "tests" / "shots" / name, static / "img" / "shots" / name)
    (static / "fonts").mkdir(exist_ok=True)
    for name, src in FONTS.items():
        shutil.copyfile(QUEST / src, static / "fonts" / name)

    write(out / "index.html", build_splash(""))
    write(out / QUEST_PAGE / "index.html", build_home(bank, "../"))
    write(out / "lessons" / "index.html", build_lessons_index(bank, "../"))
    for stage in STAGES:
        write(out / "lessons" / stage["slug"] / "index.html", build_lesson(stage, bank[str(stage["id"])], "../../"))
    write(out / "guide" / "index.html", build_guide("../"))
    write(out / "brand" / "index.html", build_brand("../"))
    for slug, build in (("identity", build_brand_identity), ("art", build_brand_art), ("trailers", build_brand_trailers),
                        ("youtube", build_brand_youtube), ("launch", build_brand_launch)):
        write(out / "brand" / slug / "index.html", build("../../"))
    write(out / "flatmates" / "index.html", build_flatmates("../"))
    write(out / "curb" / "index.html", build_curb("../"))
    write(out / "404.html", build_404("/"))
    write(out / "_redirects", "".join(
        f"/lessons/{old}/ /lessons/{new}/ 301\n/lessons/{old} /lessons/{new}/ 301\n" for old, new in OLD_SLUGS.items()))
    print(f"site built into {out}")


if __name__ == "__main__":
    main()
