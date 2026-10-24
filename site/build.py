"""Build the Dunder Quest website into a static folder.

Every lesson page comes from `data/lessons.json`, the same bank the game
reads, so the scrolls and the guardian's questions on the site are the ones
the player meets on the trail. The web export of the game goes in `play/`
beside the pages (`scripts/export_web.sh` puts it there).

    python site/build.py build/site
    python site/build.py --play build/site/play/index.html
    python site/build.py --flatmates build/site/flatmates/index.html
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
SITE = Path(__file__).resolve().parent
REPO = "https://github.com/rlancer/dunder-quest"
## Social previews need absolute URLs, so every page points at production,
## even when built for the dev deploy.
SITE_URL = "https://dunderquest.com/"
## Cloudflare Web Analytics site token (dashboard: Analytics & Logs, Web
## Analytics). It's public, since it ships in every page. Empty leaves the
## beacon out.
CF_ANALYTICS_TOKEN = "6befdb51293b4efc966f8490afb169c8"
## The trailer on YouTube (built by tools/make_trailer.py). The home page shows
## its thumbnail and only loads the player once someone clicks it.
TRAILER_ID = "dXOdBei8838"
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

NAV = [("lessons/", "Lessons"), ("guide/", "How to play"), ("#download", "Download")]


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
         path: str | None = None, image: str = "home.png", image_alt: str = HOME_ALT) -> str:
    links = []
    for href, label in NAV:
        target = f"{prefix}{href}" if not href.startswith("#") else f"{prefix}{href}"
        current = ' aria-current="page"' if active == href else ""
        links.append(f'<a href="{target}"{current}>{label}</a>')
    full_title = "Dunder Quest" if not title else f"{title} · Dunder Quest"
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
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="{prefix}static/style.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="{prefix}"><img src="{prefix}static/img/squire.png" alt="" width="16" height="24">{WORDMARK}</a>
  <nav aria-label="Site">{"".join(links)}</nav>
  <a class="btn btn-small" href="{prefix}play/">Play</a>
</header>
<main id="main">
{body}
</main>
<footer class="foot">
  <p><img src="{prefix}static/img/tin.png" alt="" width="12" height="12"> Dunder Quest. A squire's quest for the Grail, and six lessons of Python on the way.</p>
  <p class="fine">Python is named after Monty Python, so the quest is a Holy Grail homage. Python programmers call names like <code>__init__</code> “dunders”, short for <b>d</b>ouble <b>under</b>score. Say <code>__quest__</code> out loud and you get the name.</p>
  <p><a href="{prefix}play/">Play in your browser</a> · <a href="{prefix}lessons/">Lessons</a> · <a href="{prefix}guide/">How to play</a> · <a href="{REPO}">Source on GitHub</a></p>
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
{downloads_section(prefix)}
"""
    return page("", body, prefix, scripts=f'<script src="{prefix}static/trailer.js"></script>', path="")


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


## The brand kit. The footer's `>>> help(dunder_quest)` is the only link to
## it. trailer/PLAN.md §4 has the palette; dusk, line, moss and zap are the
## site's additions.
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
## What goes in YouTube's upload form. The chapter times are the cut's bars:
## gameplay at bar 1, the gadgets at bar 8, the duels at bar 20, the end card
## at bar 28 (see `edit()` in tools/make_trailer.py).
YOUTUBE_TITLE = "Dunder Quest – Learn Python on a Very Silly Grail Quest | Official Trailer"
YOUTUBE_DESCRIPTION = f"""Python is named after Monty Python. So we made learning it a quest for the Grail.

Dunder Quest is a free pixel-art platformer where every stage teaches a piece of real Python. Slice a list to lay a bridge. Hash a key into the right bucket. Loop a lift up a cave wall. Then face the guardian at the exit, from the Knight Who Says Mi to the Bridgekeeper, who asks his questions... four. Answer by jumping into the right block while you dodge his spells.

▶ Play free in your browser: {SITE_URL}play/
▶ Windows, macOS and Linux: {SITE_URL}#download
▶ Every lesson and question: {SITE_URL}lessons/

What's inside
• 6 stages, 6 Python topics: lists, dictionaries, loops, booleans, functions, comprehensions
• 63 quiz questions, each checked against a real Python interpreter
• Lore scrolls and a Spellbook to study before each duel
• A squire, two coconut halves, killer bunnies, tins of spam, and a giant foot
• Keyboard, gamepad or touch. No signup.

How it was made
Opus 5.5 built the whole game: every line of Godot code, the pixel art painted from Python scripts, this website, and this trailer, cut from a scripted gameplay capture with no video editor. Image and music models made the backgrounds and soundtrack. My part was prompting and playtesting.
Source: {REPO}

0:00 Cold open
0:08 Six stages
0:22 Your code builds the world
0:46 Guardian duels
1:02 Play free

A fan homage. Not affiliated with or endorsed by Monty Python.

#python #learnpython #indiegame #pixelart #godot #codinggame"""
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


def build_brand(prefix: str) -> str:
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
    art = "".join(
        f'<li><a href="{img}{file}"><img src="{img}{file}" alt="" width="{w * s}" height="{h * s}" loading="lazy"></a>'
        f"<b>{esc(name)}</b><span>{esc(note)}</span></li>"
        for file, name, note, w, h, s in ART
    )
    facts = "".join(f"<div><dt>{k}</dt><dd>{esc(v)}</dd></div>" for k, v in TRAILER_FACTS)
    cuts = "".join(f"<tr><td>{a}</td><td>{esc(b)}</td><td>{esc(c)}</td></tr>" for a, b, c in TRAILER_CUTS)
    cards = [("home.png", "Home", "Home, How to play, and any page without its own card"),
             ("lessons.png", "Lessons", "The lessons index")]
    cards += [(f"{s['slug']}.png", f"{s['id']} · {s['name']}", "That stage's lesson page") for s in STAGES]
    card_items = "".join(
        f'<li><a href="{img}og/{file}"><img src="{img}og/{file}" alt="The {esc(name)} social card" width="1200" height="630" loading="lazy"></a>'
        f'<span class="og-crop" aria-hidden="true"><img src="{img}og/{file}" alt="" loading="lazy"></span>'
        f"<b>{esc(name)}</b><span>{esc(used)}</span></li>"
        for file, name, used in cards
    )
    launch = "".join(launch_post(*post) for post in LAUNCH)
    upload = "".join(
        f'<figure class="code post"><figcaption>{label} <span class="count">{len(text)} / {limit}</span>'
        f'<button class="copy" type="button" hidden>Copy</button></figcaption><pre><code>{esc(text)}</code></pre></figure>'
        for label, text, limit in (("YouTube title", YOUTUBE_TITLE, 100), ("YouTube description", YOUTUBE_DESCRIPTION, 5000)))
    body = f"""
<section class="section page-head">
  <p class="kicker">&gt;&gt;&gt; help(dunder_quest)</p>
  <h1>The brand kit</h1>
  <figure class="code pydoc"><pre><code>Help on package dunder_quest:

NAME
    dunder_quest - a pixel platformer where Python is the magic
    (and Monty Python is the plot)

DESCRIPTION
    The logo, colors, fonts, art, trailer and social cards, and
    where each one is made.</code></pre></figure>
</section>

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
</section>

<section class="section kit" aria-labelledby="art-h">
  <p class="kicker">dunder_quest.__art__</p>
  <h2 id="art-h">The art</h2>
  <p class="lede">The game draws at 480×270. Scale it by whole numbers with nearest-neighbor, never by fractions, or the pixels come out uneven. Click a piece for the original file.</p>
  <ul class="art">{art}</ul>
</section>

<section class="section kit" aria-labelledby="trailer-h">
  <p class="kicker">dunder_quest.__trailer__</p>
  <h2 id="trailer-h">The trailer</h2>
  <p class="lede">Built entirely from the game's repo by a Python script, with no video editor: real gameplay, captured frame by frame, with motion graphics in the game's own fonts and colors.</p>
  <div id="trailer">
  <a class="trailer" href="https://www.youtube.com/watch?v={TRAILER_ID}" data-yt="{TRAILER_ID}">
    <img src="{img}trailer.png" alt="Trailer thumbnail: Tom the Enchanter's duel on print(list(range(4))), under the Dunder Quest wordmark" width="1920" height="1080" loading="lazy">
    <span class="trailer-play" aria-hidden="true"></span>
    <span class="sr">Play the Dunder Quest trailer</span>
  </a>
  </div>
  <dl class="facts">{facts}</dl>
  <div class="table-wrap"><table>
    <thead><tr><th>Cut</th><th>Format</th><th>Where</th></tr></thead>
    <tbody>{cuts}</tbody>
  </table></div>
  <h3>Uploading it</h3>
  <p>The thumbnail: <a href="{img}trailer.png" download="dunder_quest_thumbnail.png">dunder_quest_thumbnail.png</a> (1920×1080, under YouTube's 2 MB limit). The title and description below are ready to paste. Check the chapter times against the uploaded video.</p>
  {upload}
  <p class="fine">How it's made: <a href="{REPO}/blob/main/trailer/README.md">trailer/README.md</a>.</p>
</section>

<section class="section kit" aria-labelledby="cards-h">
  <p class="kicker">dunder_quest.__cards__</p>
  <h2 id="cards-h">The social cards</h2>
  <p class="lede">What a link to each page looks like when it's shared. Chat apps show either the full card or a small square cut from its middle, shown beside each one, so anything that has to be read sits in the center.</p>
  <ul class="cards">{card_items}</ul>
  <p class="fine">Painted by <code>tools/make_og.py</code>.</p>
</section>

<section class="section kit" aria-labelledby="launch-h">
  <p class="kicker">dunder_quest.__launch__</p>
  <h2 id="launch-h">The launch posts</h2>
  <p class="lede">One post for each platform, ready to paste, in the order they go out on launch day. Post on a Tuesday, Wednesday or Thursday, starting with Hacker News at 8:30 AM Eastern, when both the US and Europe are reading. The rest follow through the day. Each one says what Opus 5.5 built and plainly what other models made. The ones with room for a story say why it's a learning game at all.</p>
  <ol class="launch">{launch}</ol>
  <p class="fine">Never ask for upvotes on any of them. Sharing a post is fine; asking for votes gets it removed. Once one does well, mention it in the others.</p>
</section>"""
    return page("Brand kit", body, prefix,
                description="The Dunder Quest brand kit: the logo, colors, fonts, art, trailer, social cards and launch posts.",
                scripts=f'<script src="{prefix}static/trailer.js"></script><script src="{prefix}static/copy.js"></script>', path="brand/")


## X counts every link as 23 characters, whatever its length.
LIMITS = {"X": 280, "Bluesky": 300}


def post_length(platform: str, text: str) -> int:
    if platform == "X":
        return len(re.sub(r"https?://\S+", "x" * 23, text))
    return len(text)


def launch_post(platform: str, when: str, title: str, posts: list[str], tips: str) -> str:
    def block(label: str, text: str) -> str:
        limit = LIMITS.get(platform)
        count = f' <span class="count">{post_length(platform, text)} / {limit}</span>' if limit else ""
        return (f'<figure class="code post"><figcaption>{esc(label)}{count}'
                f'<button class="copy" type="button" hidden>Copy</button></figcaption>'
                f"<pre><code>{esc(text)}</code></pre></figure>")
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


def tag_flatmates_page(index: Path) -> None:
    """The same tags for Flatmates.js, the JavaScript game in flatmates/,
    which Godot exports to flatmates/index.html."""
    desc = ("Flatmates.js, a Dunder Quest game: two mismatched flatmates, two points of view, and the JavaScript "
            "one of them runs. Play it free in your browser.")
    text = index.read_text(encoding="utf-8")
    if 'property="og:title"' in text:
        return
    tags = (f'<meta name="description" content="{esc(desc)}">\n'
            f'{head_tags("Flatmates.js · Dunder Quest", desc, "flatmates/", "flatmates.png", FLATMATES_ALT)}\n')
    index.write_text(text.replace("</head>", tags + "</head>", 1), encoding="utf-8")
    print(f"tagged {index}")


def main() -> None:
    if sys.argv[1:2] == ["--play"]:
        tag_play_page(Path(sys.argv[2]))
        return
    if sys.argv[1:2] == ["--flatmates"]:
        tag_flatmates_page(Path(sys.argv[2]))
        return
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "build" / "site").resolve()
    out.mkdir(parents=True, exist_ok=True)
    bank = json.loads((ROOT / "data" / "lessons.json").read_text(encoding="utf-8"))

    static = out / "static"
    if static.exists():
        shutil.rmtree(static)
    shutil.copytree(SITE / "static", static)
    shutil.copyfile(SITE / "favicon.ico", out / "favicon.ico")  # painted by tools/make_og.py
    for name, src in IMAGES.items():
        shutil.copyfile(ROOT / src, static / "img" / name)
    (static / "img" / "shots").mkdir(parents=True, exist_ok=True)
    for name in SHOTS + [s["shot"] for s in STAGES]:
        shutil.copyfile(ROOT / "tests" / "shots" / name, static / "img" / "shots" / name)
    (static / "fonts").mkdir(exist_ok=True)
    for name, src in FONTS.items():
        shutil.copyfile(ROOT / src, static / "fonts" / name)

    write(out / "index.html", build_home(bank, ""))
    write(out / "lessons" / "index.html", build_lessons_index(bank, "../"))
    for stage in STAGES:
        write(out / "lessons" / stage["slug"] / "index.html", build_lesson(stage, bank[str(stage["id"])], "../../"))
    write(out / "guide" / "index.html", build_guide("../"))
    write(out / "brand" / "index.html", build_brand("../"))
    write(out / "404.html", build_404("/"))
    write(out / "_redirects", "".join(
        f"/lessons/{old}/ /lessons/{new}/ 301\n/lessons/{old} /lessons/{new}/ 301\n" for old, new in OLD_SLUGS.items()))
    print(f"site built into {out}")


if __name__ == "__main__":
    main()
