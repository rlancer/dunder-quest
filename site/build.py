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
        "shot": "tour_amber_slice.png",
        "puzzle_title": "The slice bridge",
        "puzzle_code": "bridge = planks[?]\n# the pit is cells 1 to 10",
        "puzzle": "Near the end of the stage, a pit ten tiles wide is too far to jump. A ruler numbers its cells like a list, from 0 on the near edge to 11 on the far edge. Four slice blocks hang in front of it: 1:10, 1:11, 2:11 and :10. Bumping one lays planks on the cells that slice takes. A bridge holds only if it reaches both edges, so a slice that misses even one pit cell crumbles. (Over the start of the stage, a row of ? blocks under a slate reading row[2] hides a bonus scroll.)",
        "spoiler": "planks[1:11] takes cells 1 to 10, because a slice stops just before its second number. planks[1:10] stops at cell 9 and leaves a gap. For the bonus scroll, count from zero: row[2] is the third block.",
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
        "puzzle_title": "The loop lift",
        "puzzle_code": "for i in ?:\n    lift.rise()  # one notch\nA: range(1, 9, 3)\nB: range(4)\nC: range(10, 13)",
        "puzzle": "The kiln wall is ten tiles of sheer brick. At its foot, an iron lift runs a for loop and rises one notch for every lap, and a gauge on the wall numbers the notches. Three forge blocks each load a different range into the lift. Stand on the plate to run the loop and watch i count off each lap. You need four notches to jump onto the wall.",
        "spoiler": "range(4) runs four laps: 0, 1, 2, 3. The other two have bigger numbers but only three laps each: 1, 4, 7 and 10, 11, 12. Count the laps, not the size of the numbers.",
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


NAV = [("lessons/", "Lessons"), ("guide/", "How to play"), ("#download", "Download")]


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
  <p><a href="{prefix}play/">Play in your browser</a> · <a href="{prefix}lessons/">Lessons</a> · <a href="{prefix}guide/">How to play</a> · <a href="{REPO}">Source on GitHub</a></p>
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
    <p class="hero-sub">Guide a pebble across six stages to the kiln. Read the lore scrolls on the way, and use real code to open the path through each stage. Then duel the wizard at the exit: jump into the block with the right answer while you dodge his spells.</p>
    <div class="cta">
      <a class="btn" href="{prefix}play/">Play in your browser</a>
      <a class="btn btn-ghost" href="#download">Download for desktop</a>
    </div>
    <p class="fine">Keyboard, gamepad or touch. On a phone, turn it sideways and use the on-screen buttons.</p>
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
      <h3>Code the way forward</h3><p>The only way through each stage is a gadget that runs real Python. You slice planks into a bridge, store keys in hash buckets, load a loop into a lift, or call the function that builds a bridge the exact length of the gap. Only the right code gets you across.</p></li>
    <li><img src="{prefix}static/img/shots/tour_amber_duel.png" alt="The Ash Hexer's duel: his question across the top of the screen and four lettered answer blocks over the arena floor" width="480" height="270" loading="lazy">
      <h3>Duel the wizard</h3><p>A wizard holds every exit. His question shows at the top of the screen, and you answer by jumping into the lettered block while you dodge his spells. Each right answer breaks a ward. A wrong one gets you zapped and a new question. He'll give you a hint if you ask.</p></li>
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
    <p class="lede">In the game, the {esc(stage['wizard'])} duels you in a sealed arena. His question shows across the top of the screen, and you answer by jumping up into the lettered block, A to D, while you dodge his spells. You need {lesson['trial']} right answers to banish him. These are his questions, drawn from all {len(questions)} in his bank. The hints work the same as in the game: ask once for his riddle, and ask again for him to rule out a wrong answer.</p>
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
        ("Move", "A / D or ← / →", "D-pad or left stick", "Arrow buttons, bottom left"),
        ("Jump", "Space, W or ↑ (hold to jump higher and float)", "A / Cross", "Jump button, bottom right"),
        ("Confirm, next card", "Space or Enter", "A / Cross", "Tap anywhere"),
        ("Pause and Spellbook", "Esc or P", "Start / Options", "Pause, top right"),
        ("Back to world map", "M", "LB / L1", "Pause, then World map"),
        ("Ask the wizard for a hint", "H", "Y / Triangle", "? button, during a duel"),
        ("Fullscreen", "F11", "", "Fullscreen on the title screen (not on iPhone)"),
    ]
    rows = "".join(f"<tr><th scope=row>{a}</th><td data-label=Keyboard>{k}</td><td data-label=Gamepad>{p or '-'}</td><td data-label=Touch>{t}</td></tr>" for a, k, p, t in controls)
    things = [
        ("emberseed.png", 12, 12, "Emberseed", "The collectible. Each stage counts how many you found, and your best count shows on the world map."),
        ("cache_stone.png", 16, 16, "Cache stone", "Bump it from below and it gives you its seed. It only does this once."),
        ("clay_brick.png", 16, 16, "Clay brick", "Jump into it from below to break it."),
        ("copperling.png", 20, 12, "Copperling", "Walks back and forth on its ledge. Landing on it beats it. Touching it from the side knocks you out."),
        ("tile_ash.png", 16, 16, "Ash shelf", "Cracks under your feet, then falls. Keep moving. It comes back when you respawn."),
        ("lantern_lit.png", 12, 28, "Lantern", "A checkpoint. Walk past it to light it, and that's where you come back after a fall."),
        ("waygate.png", 24, 40, "Waygate", "The exit. It's behind the wizard's barrier, so you have to win his duel before you can reach it."),
        ("wizard.png", 18, 28, "Wizard", "Each stage ends in his arena. Walk in and the duel starts. See the section below. Touching him knocks you back."),
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
  <h2 id="lessons-h">Lessons, puzzles and the wizard's duel</h2>
  <div class="two">
    <figure class="shot"><img src="{prefix}static/img/shots/tour_amber_hint2.png" alt="The wizard's duel with one wrong answer dimmed and its block cracked after a second hint" width="480" height="270" loading="lazy"><figcaption>After a second hint, the wizard rules out one wrong answer and its block cracks.</figcaption></figure>
    <div>
      <p><b>Lore scrolls</b> teach the stage's topic. Touching one pauses the game and opens its card. Press Space or tap to keep going.</p>
      <p><b>The stage puzzle</b> is the way forward. Slates in the scenery show its code, and blocks you bump from below run it. Only the right answer builds the path. The <a href="{prefix}lessons/">lesson pages</a> explain each one.</p>
      <p><b>The wizard's duel</b> starts when you walk into his arena at the end of the stage. A seal closes behind you, his question appears across the top of the screen, and four lettered blocks hang over the floor. Jump up into the block with the right answer. Each right answer breaks one ward, the pips above his name. A wrong answer cracks that block, zaps you, and brings a different question. He mostly asks about scrolls you've read, so reading them on the way pays off.</p>
      <p><b>His spells:</b> after giving you a moment to read, he casts. Ward waves roll along the floor, so jump them. From Kiln Mouth on, hexes mark a spot and then strike, so step aside. You have three sparks, shown next to his name. A spell, a zap or bumping into him costs one. Lose all three and you wake at the lantern outside, but the wards you broke stay broken. The clock stops for the whole duel.</p>
      <p><b>Hints:</b> press H (or tap the ? button) once for his riddle and a reminder of the scroll the question comes from. Press it again and he rules out one wrong answer, and its block cracks. There's no third hint.</p>
    </div>
  </div>
</section>

<section class="section" aria-labelledby="book-h">
  <h2 id="book-h">Spellbook, results and saving</h2>
  <div class="two">
    <div>
      <p><b>Spellbook:</b> pause with Esc or the Pause button to open it. It keeps every scroll you've read, so you can study before a trial.</p>
      <p><b>Results:</b> when you clear a stage, you see your seeds, time and falls. Your best time and seed count for each stage show on the world map.</p>
      <p><b>Saving</b> happens automatically. In the browser, your progress is stored in that browser on that device, so clearing site data erases it. The desktop builds save to a file in the Godot user folder: <code>%APPDATA%\\Godot\\app_userdata\\Ember Trail\\</code> on Windows, <code>~/Library/Application Support/Godot/app_userdata/Ember Trail/</code> on macOS, and <code>~/.local/share/godot/app_userdata/Ember Trail/</code> on Linux. To start over, choose <em>New game</em> on the title screen and press it a second time to confirm.</p>
    </div>
    <figure class="shot"><img src="{prefix}static/img/shots/tour_amber_book.png" alt="The Spellbook in the pause menu listing scrolls read so far" width="480" height="270" loading="lazy"><figcaption>The Spellbook, from the pause menu.</figcaption></figure>
  </div>
</section>"""
    return page("How to play", body, prefix, "guide/", "Controls, enemies, checkpoints, lore scrolls, the wizard's trial and saving in Ember Trail.")


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
    write(out / "404.html", build_404("/"))
    print(f"site built into {out}")


if __name__ == "__main__":
    main()
