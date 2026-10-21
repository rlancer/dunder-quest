"""Build the Ember Trail website into a static folder.

Every lesson page comes from `data/lessons.json`, the same bank the game
reads, so the scrolls and the wizard's questions on the site are the ones
the player meets on the trail. The web export of the game goes in `play/`
beside the pages (`scripts/export_web.sh` puts it there).

    python site/build.py build/site
"""

from __future__ import annotations

import html
import io
import json
import keyword
import shutil
import sys
import tokenize
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SITE = Path(__file__).resolve().parent
REPO = "https://github.com/rlancer/ember-trail"
## A rolling release CI refreshes on every push to main.
DOWNLOADS = f"{REPO}/releases/download/builds"
RELEASE_PAGE = f"{REPO}/releases/tag/builds"

## Stage facts the lesson bank doesn't carry: names and map spots match
## `common/game_progression.gd` and `levels/world_map.gd`, and each puzzle
## is the gadget its `levels/level_0N.gd` builds. `x`/`y` place the marker on
## `static/img/trail_map.png`, the world map cropped 22px from the top.
STAGES: list[dict] = [
    {
        "id": 1, "slug": "amber-hollow", "name": "Amber Hollow", "wizard": "Ash Hexer",
        "x": 78, "y": 94, "tint": "#8cd9ff",
        "shot": "tour_amber_index.png",
        "puzzle_title": "The index row",
        "puzzle_code": "loot = row[2]",
        "puzzle": "Four blocks marked ? hang over the start of the trail, under a slate that asks for row[2]. Each bump shows that block's index and what it holds. Only one of them gives you the bonus scroll, and it isn't the second block.",
        "spoiler": "Count from zero: row[0], row[1], row[2]. The third block holds the scroll.",
    },
    {
        "id": 2, "slug": "cinder-span", "name": "Cinder Span", "wizard": "Cinder Warlock",
        "x": 240, "y": 82, "tint": "#f28cff",
        "shot": "tour_span_vault.png",
        "puzzle_title": "The hash vault",
        "puzzle_code": "bucket = rune_hash(key) % 4",
        "puzzle": "Two rune keys, \"ash\" and \"ember\", lie on the route. Near the end a vault door has one lock per key and four bucket blocks numbered 0 to 3. Store each key by bumping the bucket it hashes to. The vault's rune hash adds up the letter codes of the key (ord in Python), then % 4 picks the bucket.",
        "spoiler": "\"ash\" is 97 + 115 + 104 = 316, and 316 % 4 is 0. \"ember\" adds up to 523, and 523 % 4 is 3.",
    },
    {
        "id": 3, "slug": "kiln-mouth", "name": "Kiln Mouth", "wizard": "Kiln Archmage",
        "x": 392, "y": 110, "tint": "#80ffa6",
        "shot": "tour_kiln_forge.png",
        "puzzle_title": "The loop forge",
        "puzzle_code": "for i in range(1, 9, 2):\n    seed(i)",
        "puzzle": "A forge block runs a for loop over a numbered ruler on the floor. Bump it and it drops a seed on every number the loop visits, one beat at a time, so you can watch range step along.",
        "spoiler": "It lights 1, 3, 5 and 7. range stops before 9, so 9 never lights.",
    },
    {
        "id": 4, "slug": "smelters-fork", "name": "Smelter's Fork", "wizard": "Smelt Oracle",
        "x": 326, "y": 54, "tint": "#99c7ff",
        "shot": "tour_fork_gate_shut.png",
        "puzzle_title": "The truth gates",
        "puzzle_code": "if heat > 1 and heat != 3:\n    gate.open()\n\nif heat % 2 == 1 and not heat == 1:\n    gate.open()",
        "puzzle": "Two walls of glass bars, too tall to jump, each stand on an if. A heat dial block in front of each gate turns heat through 0, 1, 2 and 3. The bars sink while the condition is True and rise again as soon as it turns False.",
        "spoiler": "The first gate opens at heat 2. The second opens only at heat 3.",
    },
    {
        "id": 5, "slug": "bellows-bridge", "name": "Bellows Bridge", "wizard": "Bellows Sage",
        "x": 214, "y": 32, "tint": "#ff9e66",
        "shot": "tour_bridge_calls.png",
        "puzzle_title": "The span bridge",
        "puzzle_code": "def span(n):\n    return n * 2 + 4\nbridge = span(?)  # gap 14",
        "puzzle": "The chasm is fourteen tiles wide, too far for any jump. Four call blocks marked 3, 4, 5 and 6 hang before the edge. Bumping one calls span with that number and lays a plank bridge as long as the value it returns. Too short and the planks fall into the chasm. Too long and they hit the far cliff and break.",
        "spoiler": "span(5) returns 5 * 2 + 4 = 14, the exact width of the gap.",
    },
    {
        "id": 6, "slug": "crucible-crown", "name": "Crucible Crown", "wizard": "Crucible King",
        "x": 108, "y": 30, "tint": "#ffd15c",
        "shot": "tour_crown_forges.png",
        "puzzle_title": "The comprehension stair",
        "puzzle_code": "A: [n for n in range(3)]\nB: [n * 2 for n in range(1, 5)]\nC: [n * 4 for n in range(3) if n != 1]\nsteps = ?  # up the crown",
        "puzzle": "The crown wall is eight tiles of sheer stone. Three forge blocks, A, B and C, each run a list comprehension. Bumping one builds a stair with one plank step for each number in its list, placed that many tiles high. A 0 builds nothing. Only one list gives you a stair you can climb.",
        "spoiler": "B builds [2, 4, 6, 8]: even steps, two tiles apart, all the way to the top.",
    },
]

## Every image the pages use, copied from the game's own art and test captures.
## `static/img` also holds the cropped world map and the wizard's first frame.
IMAGES = {
    "title_art.png": "assets/backgrounds/title_art.png",
    "pebble.png": "assets/sprites/pebble.png",
    "emberseed.png": "assets/sprites/emberseed.png",
    "copperling.png": "assets/sprites/copperling.png",
    "lantern_lit.png": "assets/sprites/lantern_lit.png",
    "waygate.png": "assets/sprites/waygate.png",
    "cache_stone.png": "assets/sprites/cache_stone.png",
    "clay_brick.png": "assets/sprites/clay_brick.png",
    "tile_ash.png": "assets/sprites/tile_ash.png",
    "icon.svg": "icon.svg",
}
SHOTS = [
    "tour_amber_scroll.png", "tour_amber_quiz.png", "tour_amber_hint2.png",
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


NAV = [("lessons/", "Lessons"), ("guide/", "How to play"), ("admin/", "Admin & testing"), ("#download", "Download")]


def page(title: str, body: str, prefix: str, active: str = "", description: str = "", scripts: str = "") -> str:
    links = []
    for href, label in NAV:
        target = f"{prefix}{href}" if not href.startswith("#") else f"{prefix}{href}"
        current = ' aria-current="page"' if active == href else ""
        links.append(f'<a href="{target}"{current}>{label}</a>')
    full_title = "Ember Trail" if not title else f"{title} · Ember Trail"
    desc = description or "Ember Trail is a pixel-art platformer that teaches Python. Play it in your browser or download it."
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(full_title)}</title>
<meta name="description" content="{esc(desc)}">
<link rel="icon" href="{prefix}static/img/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="{prefix}static/style.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="{prefix}"><img src="{prefix}static/img/pebble.png" alt="" width="16" height="24">Ember Trail</a>
  <nav aria-label="Site">{"".join(links)}</nav>
  <a class="btn btn-small" href="{prefix}play/">Play</a>
</header>
<main id="main">
{body}
</main>
<footer class="foot">
  <p><img src="{prefix}static/img/emberseed.png" alt="" width="12" height="12"> Ember Trail. A pebble's journey to the kiln, and six lessons of Python on the way.</p>
  <p><a href="{prefix}play/">Play in your browser</a> · <a href="{prefix}lessons/">Lessons</a> · <a href="{prefix}guide/">How to play</a> · <a href="{prefix}admin/">Admin &amp; testing</a> · <a href="{REPO}">Source on GitHub</a></p>
</footer>
{scripts}
</body>
</html>
"""


def downloads_section(prefix: str) -> str:
    rows = [
        ("Windows", "ember-trail-windows.zip", "64-bit. Unzip and run <code>Ember Trail.exe</code>. If SmartScreen warns about an unknown app, choose <em>More info</em>, then <em>Run anyway</em>. The build isn't code-signed."),
        ("macOS", "ember-trail-macos.zip", "Universal, so it runs on Apple silicon and Intel. Unzip and move the app to Applications. The first time, right-click it and choose <em>Open</em>, because the build isn't notarized."),
        ("Linux", "ember-trail-linux.zip", "x86_64. Unzip, then run <code>./ember-trail.x86_64</code>. If it won't start, run <code>chmod +x</code> on the file first."),
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
  <img class="hero-art" src="{prefix}static/img/title_art.png" alt="Pixel art of a small pebble on a cliff, looking out over an autumn valley toward a smoking kiln" width="480" height="270">
  <div class="hero-copy">
    <h1>Ember Trail</h1>
    <p class="tag">A platformer where every stage teaches you a piece of Python.</p>
    <p class="hero-sub">Guide a pebble across six stages to the kiln. Read the lore scrolls on the way, solve each stage's puzzle with real code, then beat the wizard blocking the exit by answering his questions.</p>
    <div class="cta">
      <a class="btn" href="{prefix}play/">Play in your browser</a>
      <a class="btn btn-ghost" href="#download">Download for desktop</a>
    </div>
    <p class="fine">Keyboard or gamepad. Works best in Chrome, Edge or Firefox on a computer.</p>
  </div>
</section>

<section class="section" aria-labelledby="trail-h">
  <p class="kicker">The trail</p>
  <h2 id="trail-h">Six stages, six lessons</h2>
  <p class="lede">Each stop on the map is a Python topic, and they build on each other: lists first, comprehensions last. Pick a stage to read its lesson and practice its trial here on the site.</p>
  <div class="map">
    <img src="{prefix}static/img/trail_map.png" alt="The Ember Trail world map: six stages along a dirt trail from Amber Hollow to Crucible Crown" width="480" height="168">
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
    <li><img src="{prefix}static/img/shots/tour_bridge_built.png" alt="A plank bridge built by calling span(5) across the Bellows Bridge chasm" width="480" height="270" loading="lazy">
      <h3>Solve the puzzle</h3><p>Each stage has a gadget that runs real Python. You bump the right index, store keys in hash buckets, or call the function that builds a bridge the exact length of the gap.</p></li>
    <li><img src="{prefix}static/img/shots/tour_amber_quiz.png" alt="The Ash Hexer's quiz panel asking what a snippet prints" width="480" height="270" loading="lazy">
      <h3>Face the wizard</h3><p>A wizard blocks every exit. Each right answer breaks one of his wards. A wrong answer gets you zapped and a new question. He'll give you a hint if you ask.</p></li>
  </ol>
  <p class="count"><b>{total_s}</b> lore scrolls · <b>{total_q}</b> trial questions · every snippet checked against real Python</p>
</section>
{downloads_section(prefix)}
"""
    return page("", body, prefix)


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
    trial = {"wizard": stage["wizard"], "trial": lesson["trial"], "questions": questions}
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
    <blockquote class="taunt"><img src="{prefix}static/img/wizard.png" alt="" width="36" height="56"><p>“{esc(lesson['taunt'])}”<cite>{esc(stage['wizard'])}</cite></p></blockquote>
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
    <h2 id="trial-h">Practice the {esc(stage['wizard'])}'s trial</h2>
    <p class="lede">In the game, you need {lesson['trial']} right answers to banish the {esc(stage['wizard'])}. These are his questions, drawn from all {len(questions)} in his bank. The hints work the same as in the game: ask once for his riddle, and ask again for him to rule out a wrong answer.</p>
    <div class="trial" data-trial>
      <noscript><p>The practice trial needs JavaScript. You can still play the game to sit the real one.</p></noscript>
    </div>
    <script type="application/json" id="trial-data">{data}</script>
  </section>
  {pager}
</article>"""
    return page(
        f"{lesson['topic']} ({stage['name']})", body, prefix, "lessons/",
        f"Stage {stage['id']} of Ember Trail teaches {lesson['topic']}: the lore scrolls, the stage puzzle, and a practice run of the {stage['wizard']}'s trial.",
        f'<script src="{prefix}static/trial.js"></script>',
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
  <span class="li-meta">{len(lesson['scrolls'])} scrolls · {len(lesson['questions'])} questions · {esc(stage['wizard'])}</span>
</a></li>""")
    body = f"""
<section class="section page-head">
  <p class="kicker">Lessons</p>
  <h1>The Python you learn on the trail</h1>
  <p class="lede">Every scroll, puzzle and wizard question from the game, one stage per page. Read them before you play, or come back after a stage to review. All the code is plain Python 3, so you can paste any snippet into a Python prompt and run it.</p>
</section>
<ol class="lesson-list">{"".join(items)}</ol>"""
    return page("Lessons", body, prefix, "lessons/", "All six Python lessons from Ember Trail: lists, dictionaries, loops, conditions, functions and comprehensions.")


def build_guide(prefix: str) -> str:
    controls = [
        ("Move", "A / D or ← / →", "D-pad or left stick"),
        ("Jump", "Space, W or ↑ (hold to jump higher)", "A / Cross"),
        ("Confirm, next card", "Space or Enter", "A / Cross"),
        ("Pause and Spellbook", "Esc or P", "Start / Options"),
        ("Back to world map", "M", "LB / L1"),
        ("Ask the wizard for a hint", "H", "Y / Triangle"),
        ("Fullscreen", "F11", ""),
    ]
    rows = "".join(f"<tr><th scope=row>{a}</th><td>{k}</td><td>{p or '-'}</td></tr>" for a, k, p in controls)
    things = [
        ("emberseed.png", 12, 12, "Emberseed", "The collectible. Each stage counts how many you found, and your best count shows on the world map."),
        ("cache_stone.png", 16, 16, "Cache stone", "Bump it from below and it gives you its seed. It only does this once."),
        ("clay_brick.png", 16, 16, "Clay brick", "Jump into it from below to break it."),
        ("copperling.png", 20, 12, "Copperling", "Walks back and forth on its ledge. Landing on it beats it. Touching it from the side knocks you out."),
        ("tile_ash.png", 16, 16, "Ash shelf", "Cracks under your feet, then falls. Keep moving. It comes back when you respawn."),
        ("lantern_lit.png", 12, 28, "Lantern", "A checkpoint. Walk past it to light it, and that's where you come back after a fall."),
        ("waygate.png", 24, 40, "Waygate", "The exit. It's behind the wizard's barrier, so you have to pass his trial before you can reach it."),
        ("wizard.png", 18, 28, "Wizard", "Each stage has one. Walk up to him to start his trial, and see the section below."),
    ]
    cards = "".join(
        f'<li><span class="sprite"><img src="{prefix}static/img/{img}" alt="" width="{w * 3}" height="{h * 3}"></span><div><h3>{name}</h3><p>{text}</p></div></li>'
        for img, w, h, name, text in things
    )
    body = f"""
<section class="section page-head">
  <p class="kicker">How to play</p>
  <h1>Field guide to the trail</h1>
  <p class="lede">Ember Trail is a side-scrolling platformer. You play as a pebble, and you clear a stage by reaching its waygate. There are six stages, and clearing one opens the next on the world map.</p>
  <a class="btn" href="{prefix}play/">Play in your browser</a>
</section>

<section class="section" aria-labelledby="controls-h">
  <h2 id="controls-h">Controls</h2>
  <div class="table-wrap"><table class="controls">
    <thead><tr><th scope=col>Action</th><th scope=col>Keyboard</th><th scope=col>Gamepad</th></tr></thead>
    <tbody>{rows}</tbody>
  </table></div>
  <p class="fine">In the browser, the game can't play sound until you press a key or click once. The title screen takes care of that with your first press.</p>
</section>

<section class="section" aria-labelledby="things-h">
  <h2 id="things-h">What you'll meet</h2>
  <ul class="things">{cards}</ul>
  <p>Glowing <b>ember tiles</b> knock you out if you touch them. A fall sends you back to the last lantern you lit, or to the start of the stage, and the clock keeps running.</p>
</section>

<section class="section" aria-labelledby="lessons-h">
  <h2 id="lessons-h">Lessons, puzzles and the wizard's trial</h2>
  <div class="two">
    <figure class="shot"><img src="{prefix}static/img/shots/tour_amber_hint2.png" alt="The wizard's quiz with one wrong option dimmed after a second hint" width="480" height="270" loading="lazy"><figcaption>After a second hint, the wizard rules out one wrong answer.</figcaption></figure>
    <div>
      <p><b>Lore scrolls</b> teach the stage's topic. Touching one pauses the game and opens its card. Press Space to keep going.</p>
      <p><b>The stage puzzle</b> uses that topic. Slates in the scenery show its code, and blocks you bump from below act it out. The <a href="{prefix}lessons/">lesson pages</a> explain each one.</p>
      <p><b>The wizard's trial</b> starts when you walk up to him. Pick an answer with move and Jump. Each right answer breaks one ward, the pips above his name. A wrong answer zaps you and he asks a different question. He mostly asks about scrolls you've read, so reading them on the way pays off.</p>
      <p><b>Hints:</b> press H once for his riddle and a reminder of the scroll the question comes from. Press it again and he rules out one wrong option. There's no third hint.</p>
    </div>
  </div>
</section>

<section class="section" aria-labelledby="book-h">
  <h2 id="book-h">Spellbook, results and saving</h2>
  <div class="two">
    <div>
      <p><b>Spellbook:</b> pause with Esc to open it. It keeps every scroll you've read, so you can study before a trial.</p>
      <p><b>Results:</b> when you clear a stage, you see your seeds, time and falls. Your best time and seed count for each stage show on the world map.</p>
      <p><b>Saving</b> happens automatically. In the browser, your progress is stored in that browser on that device, so clearing site data erases it. The desktop builds save to a file (the <a href="{prefix}admin/#save">admin page</a> says where). To start over, choose <em>New game</em> on the title screen and press it a second time to confirm.</p>
    </div>
    <figure class="shot"><img src="{prefix}static/img/shots/tour_amber_book.png" alt="The Spellbook in the pause menu listing scrolls read so far" width="480" height="270" loading="lazy"><figcaption>The Spellbook, from the pause menu.</figcaption></figure>
  </div>
</section>"""
    return page("How to play", body, prefix, "guide/", "Controls, enemies, checkpoints, lore scrolls, the wizard's trial and saving in Ember Trail.")


def build_admin(prefix: str) -> str:
    tests = [
        ("tests/flow_check.tscn", "Drives the menus through real scene changes: title, map, Amber Hollow, pause, a fall and respawn, a full wizard trial, and back. Prints <code>FLOW result=ok</code>."),
        ("tests/lesson_check.tscn", "Drives each stage's lesson gadgets with real input: scroll cards, the index row, the vault, the forges, the gates, hints and the Spellbook."),
        ("tests/high_country_check.tscn", "A bot plays stages 4 to 6 from start to finish, solving each gadget and sitting each trial."),
        ("tests/playtest.tscn", "A bot plays stages 1 to 3 section by section and saves screenshots of key moments to <code>tests/shots</code>."),
        ("tests/span_verify.tscn", "Checks that Cinder Span's route can be completed, using real jump heights."),
        ("tests/kiln_verify.tscn", "The same route check for Kiln Mouth."),
        ("tests/look_tour.tscn", "Opens each screen in a real window and saves a screenshot to <code>tests/shots/tour_*.png</code>. Add <code>-- --only=fork</code> to capture only matching steps."),
    ]
    test_rows = "".join(f"<tr><th scope=row><code>{t}</code></th><td>{d}</td></tr>" for t, d in tests)
    stage_rows = "".join(
        f"<tr><td><kbd>{s['id']}</kbd></td><td>{esc(s['name'])}</td><td><code>res://levels/level_0{s['id']}.tscn</code></td></tr>"
        for s in STAGES
    )
    body = f"""
<section class="section page-head">
  <p class="kicker">Admin &amp; testing</p>
  <h1>Developer controls</h1>
  <p class="lede">Shortcuts for testing the game without playing through it. They work only in <b>debug builds</b>, meaning a run started from the Godot editor or with the <code>godot</code> command. The game on this site and the downloads are release builds, so players can't use them.</p>
</section>

<section class="section" aria-labelledby="skip-h">
  <h2 id="skip-h">Skip to any stage</h2>
  <p>On the world map, press a <b>number key</b> to go straight into that stage, even if it's locked. Your save doesn't change, so locked stages stay locked on the map. Clearing a stage this way records the clear as usual and unlocks the next stage.</p>
  <div class="table-wrap"><table>
    <thead><tr><th scope=col>Key</th><th scope=col>Stage</th><th scope=col>Scene</th></tr></thead>
    <tbody>{stage_rows}</tbody>
  </table></div>
  <p class="fine">This is <code>_debug_stage_skip</code> in <code>levels/world_map.gd</code>, gated on <code>OS.is_debug_build()</code>.</p>
</section>

<section class="section" aria-labelledby="cli-h">
  <h2 id="cli-h">Launch a scene directly</h2>
  <p>Pass a scene path to skip the title and map. Each stage scene runs on its own.</p>
  {code_block('godot --path . res://levels/level_04.tscn      # straight into Smelter\'s Fork' + chr(10) + 'godot --path . res://levels/world_map.tscn     # straight to the map' + chr(10) + 'godot --path .                                 # normal start, title screen', 'Terminal, from the repo root')}
  <p>In the editor, open a stage scene and press <kbd>F6</kbd> (Run Current Scene) to do the same thing.</p>
</section>

<section class="section" aria-labelledby="save-h" id="save">
  <h2 id="save-h">Progress and the save file</h2>
  <p>Progress lives in <code>user://cinder_progression.json</code>. It stores unlocked and cleared stages, best seeds and times, total falls, and the scrolls you've read.</p>
  <div class="table-wrap"><table>
    <thead><tr><th scope=col>Where it runs</th><th scope=col>Location</th></tr></thead>
    <tbody>
      <tr><th scope=row>Windows</th><td><code>%APPDATA%\\Godot\\app_userdata\\Ember Trail\\</code></td></tr>
      <tr><th scope=row>macOS</th><td><code>~/Library/Application Support/Godot/app_userdata/Ember Trail/</code></td></tr>
      <tr><th scope=row>Linux</th><td><code>~/.local/share/godot/app_userdata/Ember Trail/</code></td></tr>
      <tr><th scope=row>Browser</th><td>The browser's IndexedDB for this site. Clear the site data to reset it.</td></tr>
    </tbody>
  </table></div>
  <p><b>Reset:</b> on the title screen, choose <em>New game</em> and press it again to confirm. That deletes the file.</p>
  <p><b>Unlock everything:</b> with the game closed, edit the file and set every stage under <code>"unlocked"</code> to <code>true</code>.</p>
  {code_block('"unlocked": {"1": true, "2": true, "3": true, "4": true, "5": true, "6": true}', 'cinder_progression.json')}
  <p class="fine">Tests set <code>GameProgression.persist = false</code> so a bot run never overwrites your real save.</p>
</section>

<section class="section" aria-labelledby="tests-h">
  <h2 id="tests-h">Test scenes</h2>
  <p>Run any of these headless from the repo root with <code>godot --headless --path . res://&lt;scene&gt;</code>. <code>look_tour</code> needs a real window, so leave out <code>--headless</code>.</p>
  <div class="table-wrap"><table>
    <thead><tr><th scope=col>Scene</th><th scope=col>What it checks</th></tr></thead>
    <tbody>{test_rows}</tbody>
  </table></div>
  <h3>Lesson bank</h3>
  <p><code>python tools/verify_quiz.py</code> runs every scroll and question snippet in <code>data/lessons.json</code> in a fresh Python process. It checks that each marked answer matches what Python actually prints, and that every card fits on the game's screen. Run it after any change to the lessons. This site is built from the same file.</p>
</section>

<section class="section" aria-labelledby="deploy-h">
  <h2 id="deploy-h">Builds and deploys</h2>
  <ul class="plain">
    <li><b>Push to <code>main</code>:</b> deploys this site and the browser game to production, and replaces the desktop downloads on the <a href="{RELEASE_PAGE}"><code>builds</code> release</a>.</li>
    <li><b>Push to <code>dev</code>:</b> deploys to the dev site.</li>
    <li><b>Pull request:</b> builds everything, including the desktop exports, and runs a deploy dry run. Nothing is published.</li>
  </ul>
  {code_block('bash scripts/export_web.sh       # site + browser game into build/site' + chr(10) + 'bash scripts/export_desktop.sh   # desktop zips into build/downloads', 'Build locally on Linux (needs bash, curl, zip and unzip; fetches Godot 4.7.2)')}
  <p class="fine">To preview only the site, run <code>python site/build.py build/site</code>, then <code>python -m http.server -d build/site</code>, and open <code>localhost:8000</code>. The play link works only after a web export.</p>
</section>"""
    return page("Admin & testing", body, prefix, "admin/", "Debug-build stage skip, launching scenes directly, the save file, test scenes and the build pipeline for Ember Trail.")


def build_404(prefix: str) -> str:
    body = f"""
<section class="section page-head lost">
  <p class="kicker">404</p>
  <h1>That page isn't on the trail</h1>
  <p class="lede">Check the address for a typo, or start again from one of these.</p>
  <div class="cta"><a class="btn" href="{prefix}">Home</a><a class="btn btn-ghost" href="{prefix}lessons/">Lessons</a><a class="btn btn-ghost" href="{prefix}play/">Play</a></div>
</section>"""
    return page("Page not found", body, prefix)


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "build" / "site").resolve()
    out.mkdir(parents=True, exist_ok=True)
    bank = json.loads((ROOT / "data" / "lessons.json").read_text(encoding="utf-8"))

    static = out / "static"
    if static.exists():
        shutil.rmtree(static)
    shutil.copytree(SITE / "static", static)
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
    write(out / "admin" / "index.html", build_admin("../"))
    write(out / "404.html", build_404("/"))
    print(f"site built into {out}")


if __name__ == "__main__":
    main()
