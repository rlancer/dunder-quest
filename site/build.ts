/**
 * Build the Dunder Quest website into a static folder.
 *
 * The site root is a splash of every game, with Curb Your Oxidation out
 * front; Dunder Quest's own page is `dunder-quest/`. Every lesson page comes from `data/lessons.json`, the same bank the game
 * reads, so the scrolls and the guardian's questions on the site are the ones
 * the player meets on the trail. The web export of the game goes in `play/`
 * beside the pages (`scripts/export_web.sh` puts it there). Flatmates.js, the
 * JavaScript game, gets its own page in `flatmates/` and its export in
 * `flatmates/play/`, and Curb Your Oxidation, the Rust game, the same in
 * `curb/` and `curb/play/`. Mission Silicon, the fourth game, is in
 * `mission-silicon/` and `mission-silicon/play/`, and has a card on the
 * splash after Dunder Quest and Flatmates.js.
 *
 *     bun site/build.ts build/site
 *     bun site/build.ts --play build/site/play/index.html
 *     bun site/build.ts --flatmates build/site/flatmates/play/index.html
 *     bun site/build.ts --curb build/site/curb/play/index.html
 *     bun site/build.ts --mission-silicon build/site/mission-silicon/play/index.html
 */

import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const SITE = import.meta.dir;
const ROOT = resolve(SITE, "..");
const QUEST = join(ROOT, "games", "dunder-quest");
const FLATMATES = join(ROOT, "games", "flatmates");
const CURB = join(ROOT, "games", "curb");
const MISSION = join(ROOT, "games", "mission-silicon");
const REPO = "https://github.com/rlancer/dunder-quest";
// Social previews need absolute URLs, so every page points at production,
// even when built for the dev deploy.
const SITE_URL = "https://dunderquest.com/";
// Cloudflare Web Analytics site token (dashboard: Analytics & Logs, Web
// Analytics). It's public, since it ships in every page. Empty leaves the
// beacon out.
const CF_ANALYTICS_TOKEN = "6befdb51293b4efc966f8490afb169c8";
// The trailer on YouTube (built by tools/make_trailer.py). Dunder Quest's page
// shows its thumbnail and only loads the player once someone clicks it.
const TRAILER_ID = "7a-I7FzQdD8";
// Flatmates.js's trailer, once it's on YouTube. Empty shows the thumbnail
// without a player.
const FM_TRAILER_ID = "EJ2w4MgKSpU";
// Curb Your Oxidation's trailer, once it's on YouTube: paste its video ID
// here. Empty leaves the trailer off the /curb/ page.
const CURB_TRAILER_ID = "QZsFLN5z7R4";
// The channel every trailer goes up on.
const CHANNEL = "https://www.youtube.com/@dunderquest";
// A rolling release CI refreshes on every push to main.
const DOWNLOADS = `${REPO}/releases/download/builds`;
const RELEASE_PAGE = `${REPO}/releases/tag/builds`;

// deno-lint-ignore no-explicit-any
type Json = any;

type Stage = {
  id: number; slug: string; name: string; wizard: string; x: number; y: number; tint: string; shot: string;
  puzzle_title: string; puzzle_code: string; puzzle: string; spoiler: string;
};

// Stage facts the lesson bank doesn't carry: names and map spots match
// `common/game_progression.gd` and `levels/world_map.gd`, and each puzzle
// is the gadget its `levels/level_0N.gd` builds. `x`/`y` place the marker on
// `static/img/trail_map.png`, the world map cropped 22px from the top.
// `wizard` is the guardian's name as it reads mid-sentence ("the Bridgekeeper").
const STAGES: Stage[] = [
  {
    id: 1, slug: "shrubbery-wood", name: "Shrubbery Wood", wizard: "the Knight Who Says Mi",
    x: 60, y: 138, tint: "#8cd9ff",
    shot: "tour_amber_slice.png",
    puzzle_title: "The slice bridge",
    puzzle_code: "bridge = planks[?]\n# the pit is cells 1 to 10",
    puzzle: "Near the end of the stage, a pit ten tiles wide is too far to jump. A ruler numbers its cells like a list, from 0 on the near edge to 11 on the far edge. Four slice blocks hang in front of it: 1:10, 1:11, 2:11 and :10. Bumping one lays planks on the cells that slice takes. A bridge holds only if it reaches both edges, so a slice that misses even one pit cell crumbles. (Over the start of the stage, a row of ? blocks under a slate reading row[2] hides a bonus scroll.)",
    spoiler: "planks[1:11] takes cells 1 to 10, because a slice stops just before its second number. planks[1:10] stops at cell 9 and leaves a gap. For the bonus scroll, count from zero: row[2] is the third block.",
  },
  {
    id: 2, slug: "cheese-shoppe", name: "The Cheese Shoppe", wizard: "the Cheesemonger",
    x: 130, y: 110, tint: "#f28cff",
    shot: "tour_span_vault.png",
    puzzle_title: "The hash vault",
    puzzle_code: "bucket = rune_hash(key) % 4",
    puzzle: "Two rune keys, \"brie\" and \"edam\", lie on the route. Near the end a vault door has one lock per key and four bucket blocks numbered 0 to 3. Store each key by bumping the bucket it hashes to. The vault's rune hash adds up the letter codes of the key (ord in Python), then % 4 picks the bucket.",
    spoiler: "\"brie\" is 98 + 114 + 105 + 101 = 418, and 418 % 4 is 2. \"edam\" adds up to 407, and 407 % 4 is 3.",
  },
  {
    id: 3, slug: "cave-of-the-bunny", name: "Cave of the Bunny", wizard: "Tom the Enchanter",
    x: 430, y: 128, tint: "#80ffa6",
    shot: "tour_kiln_forge.png",
    puzzle_title: "The loop lift",
    puzzle_code: "for i in ?:\n    lift.rise()  # one notch\nA: range(1, 9, 3)\nB: range(4)\nC: range(10, 13)",
    puzzle: "The cave wall is ten tiles of sheer brick. At its foot, an iron lift runs a for loop and rises one notch for every lap, and a gauge on the wall numbers the notches. Three range blocks each load a different range into the lift. Stand on the plate to run the loop and watch i count off each lap. You need four notches to jump onto the wall.",
    spoiler: "range(4) runs four laps: 0, 1, 2, 3. The other two have bigger numbers but only three laps each: 1, 4, 7 and 10, 11, 12. Count the laps, not the size of the numbers.",
  },
  {
    id: 4, slug: "ministry-of-walks", name: "Ministry of Walks", wizard: "the Under-Minister",
    x: 400, y: 66, tint: "#99c7ff",
    shot: "tour_fork_gate_shut.png",
    puzzle_title: "The truth gates",
    puzzle_code: "if heat > 1 and heat != 3:\n    gate.open()\n\nif heat % 2 == 1 and not heat == 1:\n    gate.open()",
    puzzle: "Two of the Ministry's gates, walls of glass bars too tall to jump, each stand on an if. A heat dial block in front of each gate turns heat through 0, 1, 2 and 3. The bars sink while the condition is True and rise again as soon as it turns False.",
    spoiler: "The first gate opens at heat 2. The second opens only at heat 3.",
  },
  {
    id: 5, slug: "bridge-of-peril", name: "Bridge of Peril", wizard: "the Bridgekeeper",
    x: 250, y: 76, tint: "#ff9e66",
    shot: "tour_bridge_calls.png",
    puzzle_title: "The span bridge",
    puzzle_code: "def span(n):\n    return n * 2 + 4\nbridge = span(?)  # gap 14",
    puzzle: "The chasm is fourteen tiles wide, too far for any jump. Four call blocks marked 3, 4, 5 and 6 hang before the edge. Bumping one calls span with that number and lays a plank bridge as long as the value it returns. Too short and the planks fall into the chasm. Too long and they hit the far cliff and break.",
    spoiler: "span(5) returns 5 * 2 + 4 = 14, the exact width of the gap.",
  },
  {
    id: 6, slug: "castle-aargh", name: "Castle Aargh", wizard: "the Taunting Knight",
    x: 96, y: 36, tint: "#ffd15c",
    shot: "tour_crown_forges.png",
    puzzle_title: "The comprehension stair",
    puzzle_code: "A: [n for n in range(3)]\nB: [n * 2 for n in range(1, 5)]\nC: [n * 4 for n in range(3) if n != 1]\nsteps = ?  # up the wall",
    puzzle: "The castle wall is eight tiles of sheer stone. Three blocks, A, B and C, each run a list comprehension. Bumping one builds a stair with one plank step for each number in its list, placed that many tiles high. A 0 builds nothing. Only one list gives you a stair you can climb.",
    spoiler: "B builds [2, 4, 6, 8]: even steps, two tiles apart, all the way to the top.",
  },
];

// Every image the pages use, copied from the game's own art and test captures.
// `static/img` also holds the cropped world map and each guardian's first
// frame (`foes/foe_N.png`), both made by tools/make_og.py.
const IMAGES: Record<string, string> = {
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
};
const SHOTS = [
  "tour_amber_scroll.png", "tour_amber_duel.png", "tour_amber_hint2.png",
  "tour_amber_book.png", "tour_bridge_built.png",
];
const FONTS: Record<string, string> = {
  "PixelifySans.ttf": "assets/fonts/PixelifySans.ttf",
  "VT323.ttf": "assets/fonts/VT323.ttf",
};

const BUILTINS = new Set(["print", "range", "len", "sum", "min", "max", "sorted", "list", "dict",
  "set", "str", "int", "hash", "ord", "abs", "enumerate", "zip", "type", "bool"]);
// Python's keyword.kwlist.
const PY_KEYWORDS = new Set(["False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
  "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is",
  "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"]);

function esc(text: string): string {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#x27;");
}

// Every literal replace, in full: String.replace would read `$` in the
// replacement as a pattern.
function rep(text: string, from: string, to: string): string {
  return text.split(from).join(to);
}

// A string's length in characters, not UTF-16 units, so an emoji counts once,
// as it does in YouTube's and the platforms' limits.
function len(text: string): number {
  return [...text].length;
}

// JSON with Python's spacing (", " and ": "), the way trial.js and pad.js
// have always been fed it. `ascii` escapes everything past ~ as \uXXXX.
function pyJson(value: Json, ascii = true): string {
  if (Array.isArray(value)) return `[${value.map((v) => pyJson(v, ascii)).join(", ")}]`;
  if (value instanceof Map) value = Object.fromEntries(value);
  if (value && typeof value === "object") {
    return `{${Object.entries(value).map(([k, v]) => `${pyJson(k, ascii)}: ${pyJson(v, ascii)}`).join(", ")}}`;
  }
  const text = JSON.stringify(value);
  return ascii ? text.replace(/[^\x20-\x7e]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, "0")}`) : text;
}

// Python's tokens, as far as the highlighter needs them: comments, strings
// (with their prefixes), numbers and names.
const PY_TOKEN = new RegExp([
  /(?<c>#[^\n]*)/u.source,
  /(?<s>(?<![\p{L}\p{N}_])(?:[rR][bBfF]?|[bBfF][rR]?|[uU])?(?:'''[\s\S]*?'''|"""[\s\S]*?"""|'(?:\\[\s\S]|[^'\\\n])*'|"(?:\\[\s\S]|[^"\\\n])*"))/u.source,
  /(?<w>[\p{L}_][\p{L}\p{N}_]*)/u.source,
  /(?<n>(?:0[xX](?:_?[0-9a-fA-F])+|0[oO](?:_?[0-7])+|0[bB](?:_?[01])+|(?:\d(?:_?\d)*(?:\.(?:\d(?:_?\d)*)?)?|\.\d(?:_?\d)*)(?:[eE][+-]?\d(?:_?\d)*)?[jJ]?))/u.source,
  /(?<q>['"])/u.source,
].join("|"), "gu");

/** Python source as HTML spans. Falls back to plain text on a bad token. */
function highlight(code: string): string {
  const out: string[] = [];
  let pos = 0;
  for (const m of code.matchAll(PY_TOKEN)) {
    const g = m.groups!;
    if (g.q) return esc(code); // a string that never ends
    let cls = "";
    if (g.c) cls = "c";
    else if (g.s) cls = "s";
    else if (g.n) cls = "n";
    else if (PY_KEYWORDS.has(g.w)) cls = "k";
    else if (BUILTINS.has(g.w)) cls = "b";
    // A token across lines (a triple-quoted string) stays plain.
    if (!cls || m[0].includes("\n")) continue;
    out.push(esc(code.slice(pos, m.index)), `<span class="${cls}">${esc(m[0])}</span>`);
    pos = m.index! + m[0].length;
  }
  out.push(esc(code.slice(pos)));
  return out.join("");
}

function codeBlock(code: string, label = ""): string {
  const head = label ? `<figcaption>${esc(label)}</figcaption>` : "";
  return `<figure class="code">${head}<pre><code>${highlight(code)}</code></pre></figure>`;
}

function stageUrl(stage: Stage, prefix: string): string {
  return `${prefix}lessons/${stage.slug}/`;
}

// The logo, `__dunder_quest__`: the name written as a real Python dunder.
// Screen readers get the plain name. On a narrow screen it breaks after
// `dunder_`.
const WORDMARK = '<span class="wordmark"><span class="sr">Dunder Quest</span>'
  + '<span aria-hidden="true"><i>__</i>dunder_<wbr>quest<i>__</i></span></span>';

// The site root is a splash of every game; Dunder Quest's own page is
// `dunder-quest/`, and its pages' logo goes there.
const QUEST_PAGE = "dunder-quest/";
const NAV: [string, string][] = [["lessons/", "Lessons"], ["guide/", "How to play"], [`${QUEST_PAGE}#download`, "Download"]];
const HOME_NAV: [string, string][] = [["curb/", "Curb Your Oxidation"], [QUEST_PAGE, "Dunder Quest"], ["flatmates/", "Flatmates.js"]];
const FRANKLIN = "&family=Libre+Franklin:ital,wght@0,400..900;1,400";

/** Social preview and analytics tags. `path` is the page's address under
 * the site root, or null for pages with no address of their own (the 404). */
function headTags(title: string, description: string, path: string | null, image: string, alt: string): string {
  const url = path !== null ? `${SITE_URL}${path}` : "";
  const tags = [
    url ? `<link rel="canonical" href="${url}">` : "",
    '<meta property="og:type" content="website">',
    '<meta property="og:site_name" content="Dunder Quest">',
    `<meta property="og:title" content="${esc(title)}">`,
    `<meta property="og:description" content="${esc(description)}">`,
    url ? `<meta property="og:url" content="${url}">` : "",
    `<meta property="og:image" content="${SITE_URL}static/img/og/${image}">`,
    '<meta property="og:image:width" content="1200">',
    '<meta property="og:image:height" content="630">',
    `<meta property="og:image:alt" content="${esc(alt)}">`,
    `<meta property="og:logo" content="${SITE_URL}static/img/og/logo.png">`,
    '<meta name="twitter:card" content="summary_large_image">',
    '<meta name="theme-color" content="#15122a">',
  ];
  if (CF_ANALYTICS_TOKEN) {
    tags.push(`<script defer src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon='{"token": "${CF_ANALYTICS_TOKEN}"}'></script>`);
  }
  return tags.filter((t) => t).join("\n");
}

/** A guardian's name at the start of a line: "the Bridgekeeper" -> "The Bridgekeeper". */
function cap(text: string): string {
  return text.slice(0, 1).toUpperCase() + text.slice(1);
}

const HOME_ALT = "Dunder Quest title art: a squire clapping coconut halves looks out over a misty valley toward a shining castle.";

type PageOptions = {
  active?: string; description?: string; scripts?: string; path?: string | null; image?: string; imageAlt?: string;
  nav?: [string, string][]; brand?: string; play?: string; fonts?: string; fullTitle?: string; foot?: string;
};

function page(title: string, body: string, prefix: string, {
  active = "", description = "", scripts = "", path = null, image = "home.png", imageAlt = HOME_ALT,
  nav = NAV, brand = QUEST_PAGE, play = "play/", fonts = "", fullTitle = "", foot = "",
}: PageOptions = {}): string {
  const links = nav.map(([href, label]) => {
    const current = active === href ? ' aria-current="page"' : "";
    return `<a href="${prefix}${href}"${current}>${label}</a>`;
  });
  fullTitle = fullTitle || (!title ? "Dunder Quest" : `${title} · Dunder Quest`);
  const desc = description || "Dunder Quest is a pixel-art platformer that teaches Python. Play it in your browser or download it.";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(fullTitle)}</title>
<meta name="description" content="${esc(desc)}">
${headTags(fullTitle, desc, path, image, imageAlt)}
<link rel="icon" href="${prefix}static/img/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400${fonts}&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${prefix}static/style.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="${prefix}${brand}"><img src="${prefix}static/img/squire.png" alt="" width="16" height="24">${WORDMARK}</a>
  <nav aria-label="Site">${links.join("")}</nav>
  <a class="btn btn-small" href="${prefix}${play}">Play</a>
</header>
<main id="main">
${body}
</main>
<footer class="foot">
  <p><img src="${prefix}static/img/tin.png" alt="" width="12" height="12"> ${foot || "Dunder Quest. A squire's quest for the Grail, and six lessons of Python on the way."}</p>
  <p class="fine">Python is named after Monty Python, so the quest is a Holy Grail homage. Python programmers call names like <code>__init__</code> “dunders”, short for <b>d</b>ouble <b>under</b>score. Say <code>__quest__</code> out loud and you get the name.</p>
  <p><a href="${prefix}">All games</a> · <a href="${prefix}${QUEST_PAGE}">Dunder Quest</a> · <a href="${prefix}play/">Play in your browser</a> · <a href="${prefix}lessons/">Lessons</a> · <a href="${prefix}guide/">How to play</a> · <a href="${prefix}flatmates/">Flatmates.js</a> · <a href="${prefix}curb/">Curb Your Oxidation</a> · <a href="${prefix}mission-silicon/">Mission Silicon</a> · <a href="${CHANNEL}">YouTube</a> · <a href="${REPO}">Source on GitHub</a></p>
  <p><a class="help" href="${prefix}brand/" title="The brand kit">&gt;&gt;&gt; help(dunder_quest)</a></p>
</footer>
${scripts}
</body>
</html>
`;
}

function downloadsSection(prefix: string): string {
  const rows = [
    ["Windows", "dunder-quest-windows.zip", "64-bit. Unzip and run <code>Dunder Quest.exe</code>. If SmartScreen warns about an unknown app, choose <em>More info</em>, then <em>Run anyway</em>. The build isn't code-signed."],
    ["macOS", "dunder-quest-macos.zip", "Universal, so it runs on Apple silicon and Intel. Unzip and move the app to Applications. The first time, right-click it and choose <em>Open</em>, because the build isn't notarized."],
    ["Linux", "dunder-quest-linux.zip", "x86_64. Unzip, then run <code>./dunder-quest.x86_64</code>. If it won't start, run <code>chmod +x</code> on the file first."],
  ];
  const items = rows.map(([osName, file, note]) =>
    `<li><a class="dl" href="${DOWNLOADS}/${file}"><span class="dl-os">${osName}</span><span class="dl-file">${file}</span></a><p>${note}</p></li>`,
  ).join("");
  return `
<section class="section" id="download" aria-labelledby="dl-h">
  <p class="kicker">Download</p>
  <h2 id="dl-h">Play without a browser</h2>
  <p class="lede">The desktop builds are the same game, run natively instead of in WebAssembly. They start faster, have no audio unlock step, and keep your save in a normal file instead of browser storage.</p>
  <ul class="downloads">${items}</ul>
  <p class="fine">CI rebuilds these every time the game changes on main. SHA-256 checksums are on the <a href="${RELEASE_PAGE}">release page</a>.</p>
</section>`;
}

function buildHome(bank: Json, prefix = ""): string {
  const markers = STAGES.map((s) =>
    `<a class="pin" href="${stageUrl(s, prefix)}" style="left:${(s.x / 480 * 100).toFixed(3)}%;top:${(s.y / 168 * 100).toFixed(3)}%;--tint:${s.tint}">`
    + `<span class="pin-label"><b>${s.id} · ${esc(s.name)}</b>${esc(bank[String(s.id)].topic)}</span></a>`,
  ).join("");
  const trailList = STAGES.map((s) =>
    `<li><a href="${stageUrl(s, prefix)}"><span class="tl-name">${esc(s.name)}</span>`
    + `<span class="tl-topic">${esc(bank[String(s.id)].topic)}</span></a></li>`,
  ).join("");
  const totalQ = Object.values(bank).reduce((n: number, v: Json) => n + v.questions.length, 0);
  const totalS = Object.values(bank).reduce((n: number, v: Json) => n + v.scrolls.length, 0);
  const body = `
<section class="hero">
  <img class="hero-art" src="${prefix}static/img/title_art.png" alt="Pixel art of a small squire with coconut halves on a cliff, looking out over a misty valley toward a shining castle" width="480" height="270">
  <div class="hero-copy">
    <p class="prompt" aria-hidden="true">&gt;&gt;&gt; squire.__quest__()</p>
    <h1>${WORDMARK}</h1>
    <p class="tag">A platformer where every stage teaches you a piece of Python.</p>
    <p class="hero-sub">Guide a squire across six stages to the Grail. Read the lore scrolls on the way, and use real code to open the path through each stage. Then duel the guardian at the exit, from the Knight Who Says Mi to the Bridgekeeper: jump into the block with the right answer while you dodge his spells.</p>
    <div class="cta">
      <a class="btn" href="${prefix}play/">Play in your browser</a>
      <a class="btn btn-ghost" href="#download">Download for desktop</a>
      <a class="btn btn-ghost" href="#trailer">Watch the trailer</a>
    </div>
    <p class="fine">Keyboard, gamepad or touch. On a phone, turn it sideways and use the on-screen buttons.</p>
  </div>
</section>

<section class="section" id="trailer" aria-labelledby="trailer-h">
  <p class="kicker">The trailer</p>
  <h2 id="trailer-h">One minute on the trail</h2>
  <a class="trailer" href="https://www.youtube.com/watch?v=${TRAILER_ID}" data-yt="${TRAILER_ID}">
    <img src="${prefix}static/img/trailer.png" alt="Trailer thumbnail: Tom the Enchanter's duel on print(list(range(4))), under the Dunder Quest wordmark" width="1920" height="1080" loading="lazy">
    <span class="trailer-play" aria-hidden="true"></span>
    <span class="sr">Play the Dunder Quest trailer</span>
  </a>
  <p class="fine">More on the channel: <a href="${CHANNEL}">youtube.com/@dunderquest</a>.</p>
</section>

<section class="section" aria-labelledby="trail-h">
  <p class="kicker">The trail</p>
  <h2 id="trail-h">Six stages, six lessons</h2>
  <p class="lede">Each stop on the map is a Python topic, and they build on each other: lists first, comprehensions last. Pick a stage to read its lesson and practice its trial here on the site.</p>
  <div class="map">
    <img src="${prefix}static/img/trail_map.png" alt="The Dunder Quest world map: six stages across a storybook kingdom, from Shrubbery Wood to Castle Aargh" width="480" height="168">
    ${markers}
  </div>
  <ol class="trail-list">${trailList}</ol>
</section>

<section class="section" aria-labelledby="stage-h">
  <p class="kicker">Inside a stage</p>
  <h2 id="stage-h">Learn it, use it, prove it</h2>
  <ol class="loop">
    <li><img src="${prefix}static/img/shots/tour_amber_scroll.png" alt="A lore scroll card titled Counting from Zero, showing a short list example" width="480" height="270" loading="lazy">
      <h3>Read the scrolls</h3><p>Lore scrolls lie along the route. Touch one and it opens a card with a few lines of code and the idea behind them. Every scroll you read goes into your Spellbook.</p></li>
    <li><img src="${prefix}static/img/shots/tour_bridge_built.png" alt="A plank bridge built by calling span(5) across the Bridge of Peril chasm" width="480" height="270" loading="lazy">
      <h3>Code the way forward</h3><p>The only way through each stage is a gadget that runs real Python. You slice planks into a bridge, store keys in hash buckets, load a loop into a lift, or call the function that builds a bridge the exact length of the gap. Only the right code gets you across.</p></li>
    <li><img src="${prefix}static/img/shots/tour_amber_duel.png" alt="The Knight Who Says Mi's duel: his question across the top of the screen and four lettered answer blocks over the arena floor" width="480" height="270" loading="lazy">
      <h3>Duel the guardian</h3><p>A guardian holds every exit. His question shows at the top of the screen, and you answer by jumping into the lettered block while you dodge his spells. Each right answer breaks a ward. A wrong one gets you zapped and a new question. He'll give you a hint if you ask.</p></li>
  </ol>
  <p class="count"><b>${totalS}</b> lore scrolls · <b>${totalQ}</b> trial questions · every snippet checked against real Python</p>
</section>

<section class="section" aria-labelledby="fm-h">
  <p class="kicker">The second game</p>
  <h2 id="fm-h">Flatmates.js teaches JavaScript</h2>
  <a class="next-game" href="${prefix}flatmates/">
    <img src="${prefix}static/img/og/flatmates.png" alt="Flatmates.js: two flatmates by their front door on a Croydon tower block landing at dusk" width="1200" height="630" loading="lazy">
    <span><b>Two flatmates. Two points of view. One of them runs your JavaScript.</b>
    Swap between Clive and Jazz across six stops in Croydon, from calling a method to awaiting two promises, and script the one you aren't playing.
    <span class="next-go">Meet the flatmates →</span></span>
  </a>
</section>

<section class="section" aria-labelledby="cy-h">
  <p class="kicker">The third game</p>
  <h2 id="cy-h">Curb Your Oxidation teaches Rust</h2>
  <a class="next-game next-curb" href="${prefix}curb/">
    <img src="${prefix}static/img/og/curb.png" alt="Curb Your Oxidation: a black title card, the name in yellow serif, over a palm-lined Westside street at sunset" width="1200" height="630" loading="lazy">
    <span><b>The borrow checker is the unwritten social contract.</b>
    Ten petty disputes on the Westside, from a second latte to a houseguest who won't leave, each settled by a Rust program, from <code>let mut</code> to lifetimes.
    <span class="next-go">Meet Barry →</span></span>
  </a>
</section>
${downloadsSection(prefix)}
`;
  return page("", body, prefix, { scripts: `<script src="${prefix}static/trailer.js"></script>`, path: QUEST_PAGE });
}

const SPLASH_DESC = "Free pixel-art games that teach real programming: Rust in Curb Your Oxidation, Python in Dunder Quest "
  + "and JavaScript in Flatmates.js, and how apps are built with AI in Mission Silicon. Play them in your browser.";

/** The site root: every game, with Curb Your Oxidation out front on a
 * title card of its own. Each game's full page is a click away. */
function buildSplash(prefix = ""): string {
  const cy = `${prefix}static/img/curb/`;
  const beats = [["03_pad.png", "Write the plan", "Barry's legal pad open on gift.rs, with a blank picked out and three options below"],
    ["03_rant.png", "Get interrupted", "Sharon bursting in with error[E0382]: borrow of moved value"],
    ["03_run.png", "Watch it happen", "The plan playing out for real while the code highlights Sharon's println! line"]];
  const strip = beats.map(([file, label, alt]) =>
    `<li><img src="${cy}${file}" alt="${esc(alt)}" width="480" height="270" loading="lazy"><span>${label}</span></li>`).join("");
  const games = [
    ["game-dq", "Learn Python", "Dunder Quest", `${prefix}${QUEST_PAGE}`, `${prefix}play/`, "home.png", HOME_ALT,
      "A platformer on a very silly quest for the Grail. Slice a list to lay a bridge, loop a lift up a cave wall, "
      + "then duel the Bridgekeeper by jumping into the right answer. Six stages, lists to comprehensions.",
      "Meet the squire"],
    ["game-fm", "Learn JavaScript", "Flatmates.js", `${prefix}flatmates/`, `${prefix}flatmates/play/`, "flatmates.png", FLATMATES_ALT,
      "Two mismatched flatmates in a very small Croydon flat. Swap between Clive and Jazz across six stops, from "
      + "calling a method to awaiting two promises, and script the one you aren't playing.",
      "Meet the flatmates"],
    ["game-ms", "Build with AI", "Mission Silicon", `${prefix}mission-silicon/`, `${prefix}mission-silicon/play/`,
      "mission-silicon.png", MS_ALT,
      "You can't code. Your AI teammate can, a bit too confidently. Learn the decisions behind every app you'll build "
      + "with AI: where it runs, what stays on the server, build or rent. The voiced Pilot is playable now.",
      "Meet the house"],
  ];
  const cards = games.map(([cls, kick, name, about, play, og, alt, blurb, more]) => `
    <li class="game ${cls}">
      <a class="game-art" href="${about}"><img src="${prefix}static/img/og/${og}" alt="${esc(alt)}" width="1200" height="630" loading="lazy"></a>
      <div class="game-copy">
        <p class="kicker">${kick}</p>
        <h3><a href="${about}">${name}</a></h3>
        <p>${blurb}</p>
        <div class="cta"><a class="btn btn-small" href="${play}">Play ${name}</a><a class="game-more" href="${about}">${more} →</a></div>
      </div>
    </li>`).join("");
  const body = `
<section class="splash-intro">
  <p class="prompt" aria-hidden="true">&gt;&gt;&gt; help(games)</p>
  <h1>${WORDMARK}</h1>
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
        <a class="btn" href="${prefix}curb/play/">Play Curb Your Oxidation</a>
        <a class="btn btn-ghost" href="${prefix}curb/">Meet Barry</a>
      </div>
    </div>
    <div class="feature-media">
      ${trailerPlayer(CURB_TRAILER_ID, `${cy}trailer.png`, CURB_THUMB_ALT, "Curb Your Oxidation")}
    </div>
  </div>
  <ol class="feature-strip">${strip}</ol>
</section>

<section class="section" aria-labelledby="more-h">
  <p class="kicker">More games</p>
  <h2 id="more-h">Prefer Python, JavaScript, or no code at all?</h2>
  <ul class="games">${cards}
  </ul>
  <p class="count">Every snippet in every coding game is checked against the real thing: Python, Node and rustc. Trailers are on <a href="${CHANNEL}">youtube.com/@dunderquest</a>.</p>
</section>
`;
  // Links to the old home's sections (in trailer descriptions, for one) now
  // belong to Dunder Quest's page.
  const old = `<script>if (/^#(download|trailer)$/.test(location.hash)) location.replace("${prefix}${QUEST_PAGE}" + location.hash);</script>`;
  return page("", body, prefix, {
    description: SPLASH_DESC, path: "", nav: HOME_NAV, brand: "", play: "curb/play/",
    fonts: FRANKLIN, fullTitle: "Dunder Quest · Games that teach programming",
    foot: "Dunder Quest. Pixel-art games that teach Python, JavaScript, Rust, and building apps with AI.",
    scripts: `${old}\n<script src="${prefix}static/trailer.js"></script>`,
  });
}

function scrollCard(scroll: Json, topic: string): string {
  const raises = scroll.raises;
  const note = raises ? `<p class="raises">This code stops with <code>${esc(raises)}</code>, and that error is the point of the scroll.</p>` : "";
  return `<article class="scroll" id="${esc(scroll.id)}">
  <p class="scroll-kick">Lore scroll · ${esc(topic)}</p>
  <h3>${esc(scroll.title)}</h3>
  ${codeBlock(scroll.code.join("\n"))}
  <p class="insight">${esc(scroll.insight)}</p>${note}
</article>`;
}

function buildLesson(stage: Stage, lesson: Json, prefix: string): string {
  const idx = stage.id - 1;
  const prevS = idx > 0 ? STAGES[idx - 1] : null;
  const nextS = idx + 1 < STAGES.length ? STAGES[idx + 1] : null;
  const scrolls = lesson.scrolls.map((s: Json) => scrollCard(s, lesson.topic)).join("");
  const titles = new Map(lesson.scrolls.map((s: Json) => [s.id, s.title]));
  const insights = new Map(lesson.scrolls.map((s: Json) => [s.id, s.insight]));
  const questions = lesson.questions.map((q: Json) => ({
    code: highlight(q.code.join("\n")),
    prompt: q.prompt,
    options: q.options,
    answer: q.answer,
    explanation: q.explanation,
    hint: q.hint ?? "",
    scroll: titles.get(q.scroll ?? "") ?? "",
    insight: insights.get(q.scroll ?? "") ?? "",
  }));
  const trial = { wizard: cap(stage.wizard), trial: lesson.trial, questions };
  const data = rep(pyJson(trial, false), "</", "<\\/");
  let pager = '<nav class="pager" aria-label="Lessons">';
  pager += prevS ? `<a href="${stageUrl(prevS, prefix)}" rel="prev"><small>Previous stage</small>${esc(prevS.name)}</a>` : "<span></span>";
  pager += nextS ? `<a href="${stageUrl(nextS, prefix)}" rel="next"><small>Next stage</small>${esc(nextS.name)}</a>` : `<a href="${prefix}play/" rel="next"><small>Finished the trail?</small>Play the game</a>`;
  pager += "</nav>";
  const body = `
<article class="lesson" style="--tint:${stage.tint}">
  <header class="lesson-head">
    <p class="kicker">Stage ${stage.id} · ${esc(stage.name)}</p>
    <h1>${esc(lesson.topic)}</h1>
    <blockquote class="taunt"><img src="${prefix}static/img/foes/foe_${stage.id}.png" alt="" width="36" height="56"><p>“${esc(lesson.taunt)}”<cite>${esc(cap(stage.wizard))}</cite></p></blockquote>
  </header>

  <section class="section" aria-labelledby="scrolls-h">
    <h2 id="scrolls-h">Scrolls on the trail</h2>
    <p class="lede">These are the ${lesson.scrolls.length} lore scrolls you'll find in ${esc(stage.name)}, in the order the lesson teaches them. The comment after each <code>print</code> shows what it outputs.</p>
    <div class="scrolls">${scrolls}</div>
  </section>

  <section class="section puzzle" aria-labelledby="puzzle-h">
    <h2 id="puzzle-h">The stage puzzle: ${esc(stage.puzzle_title)}</h2>
    <div class="puzzle-grid">
      <img src="${prefix}static/img/shots/${stage.shot}" alt="In-game view of ${esc(stage.puzzle_title)} in ${esc(stage.name)}" width="480" height="270" loading="lazy">
      <div>
        <p>${esc(stage.puzzle)}</p>
        ${codeBlock(stage.puzzle_code, "Slate in the stage")}
        <details><summary>Show the answer</summary><p>${esc(stage.spoiler)}</p></details>
      </div>
    </div>
  </section>

  <section class="section" aria-labelledby="trial-h">
    <h2 id="trial-h">Practice ${esc(stage.wizard)}'s trial</h2>
    <p class="lede">In the game, ${esc(stage.wizard)} duels you in a sealed arena. His question shows across the top of the screen, and you answer by jumping up into the lettered block, A to D, while you dodge his spells. You need ${lesson.trial} right answers to banish him. These are his questions, drawn from all ${questions.length} in his bank. The hints work the same as in the game: ask once for his riddle, and ask again for him to rule out a wrong answer.</p>
    <div class="trial" data-trial>
      <noscript><p>The practice trial needs JavaScript. You can still play the game to sit the real one.</p></noscript>
    </div>
    <script type="application/json" id="trial-data">${data}</script>
  </section>
  ${pager}
</article>`;
  return page(`${lesson.topic} (${stage.name})`, body, prefix, {
    active: "lessons/",
    description: `Stage ${stage.id} of Dunder Quest teaches ${lesson.topic}: the lore scrolls, the stage puzzle, and a practice run of ${stage.wizard}'s trial.`,
    scripts: `<script src="${prefix}static/trial.js"></script>`,
    path: `lessons/${stage.slug}/`, image: `${stage.slug}.png`,
    imageAlt: `Stage ${stage.id}, ${stage.name}: ${lesson.topic}, with ${stage.wizard}'s duel question on screen.`,
  });
}

function buildLessonsIndex(bank: Json, prefix: string): string {
  const items = STAGES.map((stage) => {
    const lesson = bank[String(stage.id)];
    const scrollNames = lesson.scrolls.map((s: Json) => esc(s.title)).join(", ");
    return `<li style="--tint:${stage.tint}"><a href="${stageUrl(stage, prefix)}">
  <span class="li-stage">Stage ${stage.id} · ${esc(stage.name)}</span>
  <span class="li-topic">${esc(lesson.topic)}</span>
  <span class="li-scrolls">${scrollNames}</span>
  <span class="li-meta">${lesson.scrolls.length} scrolls · ${lesson.questions.length} questions · ${esc(cap(stage.wizard))}</span>
</a></li>`;
  });
  const body = `
<section class="section page-head">
  <p class="kicker">Lessons</p>
  <h1>The Python you learn on the trail</h1>
  <p class="lede">Every scroll, puzzle and guardian question from the game, one stage per page. Read them before you play, or come back after a stage to review. All the code is plain Python 3, so you can paste any snippet into a Python prompt and run it.</p>
</section>
<ol class="lesson-list">${items.join("")}</ol>`;
  return page("Lessons", body, prefix, {
    active: "lessons/", description: "All six Python lessons from Dunder Quest: lists, dictionaries, loops, conditions, functions and comprehensions.",
    path: "lessons/", image: "lessons.png", imageAlt: "The six Python topics in Dunder Quest, one per stage.",
  });
}

function buildGuide(prefix: string): string {
  const controls = [
    ["Move", "A / D or ← / →", "D-pad or left stick", "Arrow buttons, bottom left"],
    ["Jump", "Space, W or ↑ (hold to jump higher and float)", "A / Cross", "Jump button, bottom right"],
    ["Confirm, next card", "Space or Enter", "A / Cross", "Tap anywhere"],
    ["Pause and Spellbook", "Esc or P", "Start / Options", "Pause, top right"],
    ["Back to world map", "M", "LB / L1", "Pause, then World map"],
    ["Ask the guardian for a hint", "H", "Y / Triangle", "? button, during a duel"],
    ["Fullscreen", "F11", "", "Fullscreen on the title screen (not on iPhone)"],
  ];
  const rows = controls.map(([a, k, p, t]) => `<tr><th scope=row>${a}</th><td data-label=Keyboard>${k}</td><td data-label=Gamepad>${p || "-"}</td><td data-label=Touch>${t}</td></tr>`).join("");
  const things: [string, number, number, string, string][] = [
    ["tin.png", 12, 12, "Tin of spam", "The collectible. Each stage counts how many you found, and your best count shows on the world map."],
    ["cache_stone.png", 16, 16, "Cache stone", "Bump it from below and it gives you its tin. It only does this once."],
    ["clay_brick.png", 16, 16, "Clay brick", "Jump into it from below to break it."],
    ["bunny.png", 20, 12, "Killer bunny", "Looks harmless. Walks back and forth on its ledge. Landing on it beats it. Touching it from the side knocks you out."],
    ["tile_ash.png", 16, 16, "Ash shelf", "Cracks under your feet, then falls. Keep moving. It comes back when you respawn."],
    ["lantern_lit.png", 12, 28, "Lantern", "A checkpoint. Walk past it to light it, and that's where you come back after a fall."],
    ["castle_gate.png", 24, 40, "Castle gate", "The exit. It's behind the guardian's barrier, so you have to win his duel before you can reach it. When you get there, watch the sky."],
    ["foes/foe_1.png", 12, 18, "Guardians", "Each stage ends in a guardian's arena: the Knight Who Says Mi, the Cheesemonger, Tom the Enchanter, the Under-Minister, the Bridgekeeper and the Taunting Knight. Walk in and the duel starts. Touching him knocks you back."],
  ];
  const cards = things.map(([img, w, h, name, text]) =>
    `<li><span class="sprite"><img src="${prefix}static/img/${img}" alt="" width="${w * 3}" height="${h * 3}"></span><div><h3>${name}</h3><p>${text}</p></div></li>`,
  ).join("");
  const body = `
<section class="section page-head">
  <p class="kicker">How to play</p>
  <h1>Field guide to the trail</h1>
  <p class="lede">Dunder Quest is a side-scrolling platformer. You play as a squire on a quest for the Grail, clopping coconut halves for want of a horse, and you clear a stage by reaching its castle gate. There are six stages, and clearing one opens the next on the world map.</p>
  <a class="btn" href="${prefix}play/">Play in your browser</a>
</section>

<section class="section" aria-labelledby="controls-h">
  <h2 id="controls-h">Controls</h2>
  <div class="table-wrap"><table class="controls">
    <thead><tr><th scope=col>Action</th><th scope=col>Keyboard</th><th scope=col>Gamepad</th><th scope=col>Touch</th></tr></thead>
    <tbody>${rows}</tbody>
  </table></div>
  <p class="fine">Holding jump floats you for a moment at the top and carries you further. Let go and you drop fast. In the browser, the game can't play sound until you press a key, click or tap once. The title screen takes care of that with your first press. On a phone, the buttons appear once you start a stage; in the Spellbook, tap the sides of the screen to turn pages.</p>
</section>

<section class="section" aria-labelledby="things-h">
  <h2 id="things-h">What you'll meet</h2>
  <ul class="things">${cards}</ul>
  <p>Glowing <b>ember tiles</b> knock you out if you touch them. A fall sends you back to the last lantern you lit, or to the start of the stage, and the clock keeps running.</p>
</section>

<section class="section" aria-labelledby="lessons-h">
  <h2 id="lessons-h">Lessons, puzzles and the guardian's duel</h2>
  <div class="two">
    <figure class="shot"><img src="${prefix}static/img/shots/tour_amber_hint2.png" alt="The guardian's duel with one wrong answer dimmed and its block cracked after a second hint" width="480" height="270" loading="lazy"><figcaption>After a second hint, the guardian rules out one wrong answer and its block cracks.</figcaption></figure>
    <div>
      <p><b>Lore scrolls</b> teach the stage's topic. Touching one pauses the game and opens its card. Press Space or tap to keep going.</p>
      <p><b>The stage puzzle</b> is the way forward. Slates in the scenery show its code, and blocks you bump from below run it. Only the right answer builds the path. The <a href="${prefix}lessons/">lesson pages</a> explain each one.</p>
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
    <figure class="shot"><img src="${prefix}static/img/shots/tour_amber_book.png" alt="The Spellbook in the pause menu listing scrolls read so far" width="480" height="270" loading="lazy"><figcaption>The Spellbook, from the pause menu.</figcaption></figure>
  </div>
</section>`;
  return page("How to play", body, prefix, {
    active: "guide/", description: "Controls, enemies, checkpoints, lore scrolls, the guardian's trial and saving in Dunder Quest.", path: "guide/",
  });
}

// The brand kit: /brand/ and a page for each part (BRAND_PAGES). The
// footer's `>>> help(dunder_quest)` is the only link to it.
// games/dunder-quest/trailer/PLAN.md §4 has the palette; dusk, line, moss
// and zap are the site's additions.
const PALETTE: [string, string, string][] = [
  ["GOLD", "#F2B544", "Headlines, the wordmark, strings in trailer code"],
  ["EMBER", "#FF8A3D", "Accents, the wordmark's underscores, keywords in trailer code"],
  ["PARCHMENT", "#F4E4C4", "Body text, numbers in trailer code"],
  ["ASH", "#B0A9D0", "Secondary text, comments in trailer code"],
  ["NIGHT", "#15122A", "Backgrounds, card fills, text shadows"],
  ["DUSK", "#232849", "The site's background, the game's sky"],
  ["LINE", "#4A4F86", "Panel borders"],
  ["MOSS", "#7BE08A", "A cleared stage, a right answer"],
  ["ZAP", "#FF7A7A", "A wrong answer, a hit"],
];
// Every line the game is pitched with, where it ships, and where to change it.
const COPY: [string, string, string][] = [
  ["A pixel platformer where Python is the magic.", "The pitch", "trailer/PLAN.md"],
  ["A platformer where every stage teaches you a piece of Python.", "Home page", "site/build.ts"],
  ["A pixel-art platformer that teaches Python", "Home social card", "tools/make_og.py"],
  ["Dunder Quest is a pixel-art platformer that teaches Python. Play it in your browser or download it.", "Search results", "site/build.ts"],
  ["LEARN PYTHON BY PLAYING", "Trailer thumbnail", "tools/make_trailer.py"],
  ["YOUR CODE / BUILDS THE WORLD", "Trailer hook", "tools/make_trailer.py"],
  ["A squire's quest for the Grail · Play free in your browser", "Trailer end card", "tools/make_trailer.py"],
];
type Art = [string, string, string, number, number, number];
// [file, name, note, native width, native height, scale]: art is only ever
// scaled by whole numbers, so each piece carries the scale it's shown at.
const ART: Art[] = [
  ["title_art.png", "Title art", "Behind the home page, every social card and the trailer's end card", 480, 270, 1],
  ["trail_map.png", "World map", "The six stages, from Shrubbery Wood to Castle Aargh", 480, 168, 1],
  ["squire.png", "The squire", "The hero", 16, 24, 4],
  ["foes/foe_1.png", "The Knight Who Says Mi", "The first of six guardians", 36, 56, 2],
  ["foes/foe_5.png", "The Bridgekeeper", "Asks his questions... four", 36, 56, 2],
  ["bunny.png", "Killer bunny", "Stomp it", 20, 12, 4],
  ["tin.png", "Tin of spam", "Collect it", 12, 12, 6],
  ["castle_gate.png", "Castle gate", "A stage's exit", 24, 40, 2],
  ["giant_foot.png", "The foot", "Stomps down when you clear a stage", 72, 96, 2],
  ["grail.png", "The Grail", "Over the very last gate", 12, 14, 6],
  ["shots/tour_bridge_built.png", "Bridge built", "span(5) lays the planks", 480, 270, 1],
  ["shots/tour_amber_duel.png", "Guardian duel", "Jump into the right answer", 480, 270, 1],
  ["shots/tour_amber_scroll.png", "Lore scroll", "A lesson card", 480, 270, 1],
];
const TRAILER_FACTS = [
  ["Length", "72 seconds, with a cold open"],
  ["Music", "A brass-band march, 120 BPM; every cut lands on a beat"],
  ["Loudness", "−14 LUFS, YouTube's target"],
  ["Pixels", "Drawn at 480×270, scaled ×4 for 1080p and ×8 for 4K"],
];
const TRAILER_CUTS = [
  ["4K master", "3840×2160, 60 fps", "YouTube"],
  ["1080p master", "1920×1080, 60 fps", "itch.io, press"],
  ["Thumbnail", "1920×1080, from the Cave of the Bunny duel", "YouTube, the home page"],
  ["Vertical Short", "1080×1920, under 60 s", "Shorts, TikTok, Reels (coming)"],
  ["GIF loops", "3–6 s of the bridge and a duel", "Social posts (coming)"],
];
const FM_TRAILER_FACTS = [
  ["Length", "66 seconds, with a cold open"],
  ["Music", "A sitcom band cue, 123 BPM, with a piano breakdown for the awkward bit"],
  ["Loudness", "−14 LUFS, YouTube's target"],
  ["Pixels", "Drawn at 480×270, scaled ×4 for 1080p and ×8 for 4K"],
];
// What goes in YouTube's upload form. The chapter times are the cut's bars:
// the gadgets at bar 8, the duels at bar 20, the end card at bar 28 (see
// `edit()` in tools/make_trailer.py). YouTube ignores chapters shorter than
// 10 s, so the 8 s cold open shares the first one.
const YOUTUBE_TITLE = "Dunder Quest – Learn Python on a Very Silly Grail Quest | Official Trailer";
const YOUTUBE_DESCRIPTION = `Python is named after Monty Python. So we made learning it a quest for the Grail.

Dunder Quest is a free pixel-art platformer where every stage teaches a piece of real Python. Slice a list to lay a bridge. Hash a key into the right bucket. Loop a lift up a cave wall. Then face the guardian at the exit, from the Knight Who Says Mi to the Bridgekeeper, who asks his questions... four. Answer by jumping into the right block while you dodge his spells.

▶ Play free in your browser: ${SITE_URL}play/
▶ Windows, macOS and Linux: ${SITE_URL}${QUEST_PAGE}#download
▶ Every lesson and question: ${SITE_URL}lessons/
▶ Prefer JavaScript? Flatmates.js: ${SITE_URL}flatmates/
▶ Or Rust? Curb Your Oxidation: ${SITE_URL}curb/

What's inside
• 6 stages, 6 Python topics: lists, dictionaries, loops, booleans, functions, comprehensions
• 63 quiz questions, each checked against a real Python interpreter
• Lore scrolls and a Spellbook to study before each duel
• A squire, two coconut halves, killer bunnies, tins of spam, and a giant foot
• Keyboard, gamepad or touch. No signup.

How it was made
Opus 5.5 built the whole game: every line of Godot code, the pixel art painted from Python scripts, this website, and this trailer, cut from a scripted gameplay capture with no video editor. Image and music models made the backgrounds and soundtrack. My part was prompting and playtesting.
Source: ${REPO}

0:00 Six stages to the Grail
0:22 Your code builds the world
0:46 Guardian duels
1:02 Play free

A fan homage. Not affiliated with or endorsed by Monty Python.

#python #learnpython #indiegame #pixelart #godot #codinggame`;
const YOUTUBE_TAGS = "learn python, python for beginners, coding game, educational game, pixel art, indie game, "
  + "godot, monty python, holy grail, dunder quest";
// The Flatmates.js trailer's chapters follow `cue_flat` (see `edit()` in
// flatmates/tools/make_trailer.py): the stops at bar 8 (18 s), the piano
// breakdown at bar 16 (34 s), the finale at bar 22 (45 s).
const FM_YOUTUBE_TITLE = "Flatmates.js – Learn JavaScript in a Very Small Croydon Flat | Official Trailer";
const FM_YOUTUBE_DESCRIPTION = `Two flatmates. Two points of view. One of them runs your JavaScript.

Flatmates.js is a free pixel-art game where you write the other flatmate's to-do list in real JavaScript, then swap into his head and live with what he does. Clive can't jump much. Jazz can jump, and that's about it. Script one to get the other across Croydon, from Flat 5B to a wedding he really shouldn't be playing.

▶ Play free in your browser: ${SITE_URL}flatmates/play/
▶ The six stops and their scripts: ${SITE_URL}flatmates/
▶ Prefer Python? Dunder Quest: ${SITE_URL}
▶ Or Rust? Curb Your Oxidation: ${SITE_URL}curb/

What's inside
• 6 stops, 6 pieces of JavaScript: methods, template literals, loops, events, timers, async/await
• Real scripts with blanks to fill, every snippet checked against Node
• Lesson cards in whoever's inner voice you're in
• A tram line, a stag do, a ticket barrier, and six custard creams per stop
• Keyboard, gamepad or touch. No signup.

How it was made
Opus 5.5 built the game: every line of Godot code, the sprites painted from Python scripts, its web page, and this trailer, cut from a scripted gameplay capture with no video editor. Image and music models made the backdrops and soundtrack. My part was prompting and playtesting.
Source: ${REPO}/tree/main/games/flatmates

0:00 Earlier that Saturday
0:18 Six stops
0:34 The awkward bit
0:45 The wedding

An homage to a certain Croydon flat-share sitcom. The names and jokes are winks, not the show's own; it isn't affiliated with or endorsed by anyone who made it.

#javascript #learnjavascript #indiegame #pixelart #godot #codinggame`;
const FM_YOUTUBE_TAGS = "learn javascript, javascript for beginners, coding game, educational game, pixel art, "
  + "indie game, godot, sitcom, flatmates.js, dunder quest";
// Curb Your Oxidation's trailer (games/curb/trailer/). The chapters are the
// ones `make_trailer.py` writes to `recut.log`.
const CURB_YOUTUBE_TITLE = "Curb Your Oxidation – Learn Rust, One Petty Dispute at a Time | Official Trailer";
const CURB_YOUTUBE_DESCRIPTION = `The borrow checker is the unwritten social contract.

Curb Your Oxidation is a free pixel-art game that teaches Rust. Barry Danvers, a semi-retired TV writer on the Westside of LA, lives by rules nobody else has heard of, and every petty dispute he gets into is settled by a plan: a short Rust program on his yellow legal pad. He plays it through in his head first, the way rustc reads your whole program before anything runs. Break the rules and Sharon bursts in at the exact line with the real rustc error, and an opinion about it. Get it right and the scene plays out, one println! at a time.

▶ Play free in your browser: ${SITE_URL}curb/play/
▶ The ten episodes and their plans: ${SITE_URL}curb/
▶ Prefer Python? Dunder Quest: ${SITE_URL}
▶ Or JavaScript? Flatmates.js: ${SITE_URL}flatmates/

What's inside
• 10 episodes, 10 pieces of Rust: let and mut, functions, ownership and moves, borrowing, &mut, structs and methods, enums and Option, Result and ?, Vec and loops, lifetimes
• Real rustc error codes, from E0382 to E0597, delivered by Sharon
• Every plan compiled with the real rustc, in every combination of its blanks
• A second latte, the last shrimp, a regifted candle, and a houseguest who said one night
• Keyboard, gamepad or touch. No signup.

How it was made
Opus 5.5 built the game: every line of Godot code, a small Rust checker written in GDScript, the cast painted from Python scripts, its web page, and this trailer, cut from a scripted gameplay capture with no video editor. Image and music models made the backdrops and soundtrack. My part was prompting and playtesting.
Source: ${REPO}/tree/main/games/curb

0:00 Barry has rules
0:24 The season, the panic, the squint
0:44 Freeze frames

An homage to a certain LA cringe-comedy series. The names, lines and music are original, not the show's own; it isn't affiliated with or endorsed by anyone who made it.

#rust #rustlang #learnrust #indiegame #pixelart #godot #codinggame`;
const CURB_YOUTUBE_TAGS = "learn rust, rust for beginners, rustlang, borrow checker, coding game, educational game, "
  + "pixel art, indie game, godot, sitcom, curb your oxidation, dunder quest";
// The channel's own fields, in YouTube Studio under Customization.
const CHANNEL_DESCRIPTION = `Free pixel-art games that teach you to code, playable in your browser.

Dunder Quest teaches Python on a very silly quest for the Grail: slice a list to lay a bridge, loop a lift up a cave wall, and answer the Bridgekeeper's questions... four. Flatmates.js teaches JavaScript in a very small Croydon flat: write the to-do list your flatmate runs, then live with what he does. Curb Your Oxidation teaches Rust on the Westside, where the borrow checker is the unwritten social contract.

Opus 5.5 built every game here end to end: the code, the sprites, the websites, and the trailers, cut from code with no video editor. Image and music models made the backdrops and soundtracks. I prompt and playtest.

Why learning games? I'm dyslexic, and I failed my spelling tests until my dad wrote me a spelling game in BASIC. After that I got 100 on every one. My kids are 5 and 2. Maybe some day these games are theirs.

Play free, no signup: ${SITE_URL}`;
const CHANNEL_KEYWORDS = '"learn python" "learn javascript" "coding game" "educational game" "pixel art" '
  + '"indie game" godot "programming for beginners" "dunder quest" flatmates.js "learn rust" "curb your oxidation"';
const CHANNEL_LINKS = [
  ["Play Dunder Quest", `${SITE_URL}play/`],
  ["Play Flatmates.js", `${SITE_URL}flatmates/play/`],
  ["Play Curb Your Oxidation", `${SITE_URL}curb/play/`],
  ["Source on GitHub", REPO],
];
// [file, name, size YouTube asks for, where it goes, alt]
const CHANNEL_ART = [
  ["banner.png", "Banner", "2560×1440; phones show only the middle 1546×423",
    "Customization → Branding → Banner image",
    "The wordmark and 'Pixel-art games that teach you to code' over the title art, with the squire on the left and Clive and Jazz on the right"],
  ["avatar.png", "Profile picture", "800×800, shown as a circle as small as 98 px",
    "Customization → Branding → Picture", "The Dunder Quest q between its underscores, on night blue"],
  ["watermark.png", "Video watermark", "150×150, clear background",
    "Customization → Branding → Video watermark, shown for the entire video", "The Dunder Quest icon"],
];
const CHANNEL_PLAYLISTS = [
  ["Trailers", "Every trailer, newest first. Set the Dunder Quest trailer as the channel trailer for visitors who haven't subscribed."],
  ["Dunder Quest", "The Python game: its trailer, and later the Short and the GIF loops cut to video."],
  ["Flatmates.js", "The JavaScript game: its trailer, and later its Short."],
  ["Curb Your Oxidation", "The Rust game: its trailer, and later its Short."],
];
// Studio's upload settings that are the same for every video.
const UPLOAD_SETTINGS = [
  ["Audience", "No, it's not made for kids. The trailers are pitched at teen and adult beginners and developers. Answer it honestly for each video, because it changes comments and notifications."],
  ["Altered or synthetic content", "No. YouTube asks only about realistic footage, and these are pixel art. The descriptions already say what the models made."],
  ["Category", "Gaming"],
  ["Language", "English, for the video and the title and description"],
  ["Thumbnail", "Upload the PNG below. Each is 1920×1080 and under YouTube's 2 MB limit."],
  ["Video file", "The 4K master from the game's trailer/out/. YouTube makes every smaller size from it."],
  ["End screen", "Subscribe, plus the other game's trailer, over the end card"],
];
// A launch post is the post itself, or [label, post] for one with its own label.
type Post = string | [string, string];
type Launch = [string, string, string, Post[], string];
// The launch: one post per platform, in the order they go out on launch
// day. Times are US Eastern on a Tuesday. Every post says what Opus 5.5 did
// and what other models made, because readers open the repo and check.
// [platform, when, title or "", [post, or [label, post]], tips]
const LAUNCH: Launch[] = [
  ["Hacker News", "8:30 AM", "Show HN: Dunder Quest – a Python platformer Opus 5.5 built in four days", [
    ["URL", `${SITE_URL}play/`],
    ["First comment, posted right away", "I wanted to see how far Opus 5.5 could take a game end to end, so I let it build one. "
    + "Dunder Quest is a pixel platformer where Python is the magic: you bump slice blocks to lay a bridge, "
    + "load a range() into a lift, and duel the Bridgekeeper by jumping into the right answer. Python is named after Monty Python, so it's a Holy Grail quest: a squire clopping coconuts, a Knight Who Says Mi, a giant foot. Six stages, free in the browser, no signup.\n\n"
    + "Over four days Opus wrote all of the Godot code, painted the tiles and the whole cast pixel by pixel from Python scripts, "
    + "prompted image, music and sound models for the rest, built this site, and cut the 62 s trailer from a scripted "
    + "gameplay capture with no video editor. I wrote the prompts and playtested.\n\n"
    + "Where it struggled: duels were hard to read until it added a camera that eases in, and some jumps still need a human playtest. "
    + "The list it kept is in GAME_IMPROVEMENTS.md.\n\n"
    + "Why a learning game: I'm dyslexic, and I was failing my spelling tests until my dad wrote me a spelling game in BASIC. "
    + "After that I got 100 on every one. My kids are 5 and 2, too young for Python, but maybe some day this is theirs.\n\n"
    + `Source: ${REPO}`],
  ], "Link the game itself, not the home page. Stay in the thread for the first three hours and answer everything, the skeptics first. Never ask anyone for upvotes: HN spots vote rings and buries the post. If it sinks, email hn@ycombinator.com and ask about the second-chance pool."],
  ["X", "8:45 AM", "", [
    "I let Opus 5.5 build a whole game in four days.\n\n"
    + "Dunder Quest: a pixel platformer where Python is the magic. Slice a list to lay a bridge, loop a lift up a wall, answer the Bridgekeeper's questions... four.\n\n"
    + `Free in your browser 👇\n${SITE_URL}`,
    "Opus wrote every line of Godot code, painted the tiles pixel by pixel in Python, and prompted image and music models for the rest.\n\n"
    + "It even cut the trailer from code. No video editor anywhere.",
    "Why a learning game? I'm dyslexic. I failed spelling tests until my dad wrote me a spelling game in BASIC. Then I got 100 on every one.\n\n"
    + "My kids are 5 and 2. Too young for Python, but maybe some day.",
    "My part: prompts and playtesting.\n\n"
    + `Everything it made is on GitHub, commit by commit:\n${REPO}`,
  ], "Upload the 1080p trailer to the first post as a video, not a YouTube link: native video autoplays in the feed. Tag @AnthropicAI and @claudeai on the last post. Pin the thread."],
  ["Bluesky", "9:00 AM", "", [
    "I let Opus 5.5 build a whole game in four days: Dunder Quest, a pixel platformer where Python is the magic. "
    + "Opus wrote the code, painted the tiles in Python and cut the trailer with no video editor.\n\n"
    + `Free in your browser: ${SITE_URL}`,
    "Why a learning game: I'm dyslexic, and I failed spelling tests until my dad wrote me a spelling game in BASIC. "
    + "Then I got 100 on every one.\n\n"
    + "My kids are 5 and 2, too young for Python. Maybe some day.",
  ], "Attach the trailer as a video to the first post and reply to it with the second. Bluesky caps posts at 300 characters. Add the GitHub link as a third reply."],
  ["r/godot", "10:00 AM", "Opus 5.5 built this Python-teaching platformer in Godot 4 in four days, trailer included", [
    "Dunder Quest is a pixel platformer where every stage teaches a piece of Python: slices, hashing, loops, conditions. "
    + "A Monty Python guardian at the end of each stage asks a question and you answer by jumping into a block.\n\n"
    + "The whole thing was built by Opus 5.5 over four days. It wrote the GDScript, painted the tiles from Python scripts, "
    + "and made the trailer by recording the game with --write-movie and compositing it in Python. I prompted and playtested.\n\n"
    + `Play it in the browser (web export): ${SITE_URL}play/\n`
    + `Source: ${REPO}\n\n`
    + "Happy to answer questions about how it handled the Godot side.",
  ], "Use the Showcase flair and upload the trailer as a Reddit video. r/godot cares about the engine, so lead with the Godot details in the comments."],
  ["r/Python", "11:00 AM", "Dunder Quest: a browser platformer that teaches Python, built end to end by Opus 5.5", [
    "**What My Project Does**\n\n"
    + "Dunder Quest is a free pixel platformer that teaches Python. Each of its six stages is built around one idea: "
    + "you slice a list to lay a bridge, hash keys into a vault, and run a for loop to raise a lift. "
    + "Monty Python-style guardians quiz you on real Python, and every question is checked against a real interpreter.\n\n"
    + "**Target Audience**\n\n"
    + "Beginners learning Python, and people curious about what a coding model can build alone. It's a finished, playable game, not a demo.\n\n"
    + "**Comparison**\n\n"
    + "Most coding games are puzzles in a code editor. Here the code changes the world you run and jump through. "
    + "It was also built entirely by Opus 5.5, from the game to its art pipeline and trailer, all in Python and GDScript.\n\n"
    + `Play: ${SITE_URL}\nSource: ${REPO}`,
  ], "r/Python only allows project posts as Showcase posts in exactly these three sections. Post it as a text post with the link inside."],
  ["LinkedIn", "12:00 PM", "", [
    "I'm dyslexic, and as a kid I failed my spelling tests. Then my dad wrote me a spelling game in BASIC. "
    + "After that I got 100 on every test.\n\n"
    + "This week I gave Opus 5.5 a blank repo and four days to make a learning game of its own. It came back with a finished one.\n\n"
    + "Dunder Quest is a pixel platformer that teaches Python: six stages, each built around one idea, and a Monty Python guardian at the end of each "
    + "who checks you understood it.\n\n"
    + "Opus wrote all of the code, painted the art in Python, directed image and music models for the rest, built the website, "
    + "and cut the trailer from code. My job was prompting and playtesting.\n\n"
    + "What struck me most was the judgment, not the speed. It kept its own list of what wasn't working, "
    + "like duels that were hard to read on a phone, and fixed them.\n\n"
    + "My kids are 5 and 2, too young for Python. But my dad's game is why I can spell, "
    + "and maybe some day this one is theirs.\n\n"
    + `Play it free in your browser: ${SITE_URL}`,
  ], "Native video gets far more reach than a link card, so upload the trailer. Put the link in the post, not the first comment."],
  ["r/WebGames", "1:00 PM", "Dunder Quest – a Monty Python quest that teaches Python [free, no signup]", [
    ["URL", `${SITE_URL}play/`],
  ], "A link post straight to the game. Check it loads on a phone first: most players will tap it there."],
];
// Curb Your Oxidation's own launch, in the same shape as LAUNCH. These are
// Rob's own posts, the one place that names the show, as "inspired by".
const CURB_LAUNCH: Launch[] = [
  ["LinkedIn", "", "", [
    "I wanted a fun way to learn Rust, so I had Claude make me a game inspired by Curb Your Enthusiasm. "
    + "What it made is pure brilliance.\n\n"
    + "In Curb Your Oxidation, the borrow checker is the unwritten social contract. Barry Danvers plots his petty etiquette "
    + "standoffs in Rust, and his wife Sharon cuts in at the exact line rustc would reject, with the real error code.\n\n"
    + "Everyone's vibe coding now. This one makes you understand the rules.\n\n"
    + `Learn Rust. Mind your manners. 👇\n${SITE_URL}curb/\n\n`
    + "#rustlang #learntocode #gamedev",
  ], "Upload the Curb trailer as a native video rather than leaning on the link card. Post it from your own account: it names the show, which only Rob's own posts may do. Keep it \"inspired by\", with nothing that suggests the network is involved."],
];

// The brand kit's pages, in the order help(dunder_quest) lists them:
// [slug, title, what's on it].
const BRAND_PAGES = [
  ["identity", "Logo, voice, colors and type", "The wordmark, every line the game is pitched with, the palette and the fonts."],
  ["art", "Art and social cards", "The sprites and scenes, and the card each page shows when its link is shared."],
  ["curb", "Curb Your Oxidation", "The Rust game's name, lines, palette, type, cast and cards."],
  ["flatmates", "Flatmates.js", "The JavaScript game's wordmark, lines, palette, type, art and cards."],
  ["trailers", "The trailers", "Every game's trailer, how each is made, and every cut."],
  ["youtube", "The YouTube channel", "The @dunderquest channel art, its description and links, and each video's upload form."],
  ["launch", "The launch posts", "One post per platform, ready to paste, in the order they go out."],
];

/** Text to paste somewhere else, with a Copy button (static/copy.js) and
 * an optional length against that field's limit. */
function copyBlock(label: string, text: string, count = ""): string {
  count = count ? ` <span class="count">${count}</span>` : "";
  return `<figure class="code post"><figcaption>${esc(label)}${count}`
    + '<button class="copy" type="button" hidden>Copy</button></figcaption>'
    + `<pre><code>${esc(text)}</code></pre></figure>`;
}

/** One page of the brand kit at /brand/<slug>/, under a row of links to
 * the others. */
function brandPage(slug: string, body: string, prefix: string, scripts = "", fonts = ""): string {
  const [, title, description] = BRAND_PAGES.find(([s]) => s === slug)!;
  const links = BRAND_PAGES.map(([s]) =>
    `<a href="${prefix}brand/${s}/"${s === slug ? " aria-current=page" : ""}>${s}</a>`).join("");
  const head = `
<nav class="kit-nav" aria-label="Brand kit"><a href="${prefix}brand/">help(dunder_quest)</a>${links}</nav>
<section class="section page-head kit-head">
  <p class="kicker">&gt;&gt;&gt; help(dunder_quest.${slug})</p>
  <h1>${esc(title)}</h1>
  <p class="lede">${esc(description)}</p>
</section>`;
  return page(`${title} · Brand kit`, head + body, prefix, {
    description: `The Dunder Quest brand kit: ${description[0].toLowerCase()}${description.slice(1)}`,
    scripts: scripts + `<script src="${prefix}static/copy.js"></script>`, path: `brand/${slug}/`, fonts,
  });
}

/** /brand/, the way in: what help() prints for a package, with each page
 * of the kit as one of its modules. */
function buildBrand(prefix: string): string {
  const width = Math.max(...BRAND_PAGES.map(([s]) => s.length));
  const contents = BRAND_PAGES.map(([s, t]) =>
    `    <a href="${s}/">${s}</a>${" ".repeat(width - s.length)}  ${esc(t)}`).join("\n");
  const pages = BRAND_PAGES.map(([s, t, d]) =>
    `<li><a href="${s}/"><code>dunder_quest.${s}</code><b>${esc(t)}</b><span>${esc(d)}</span></a></li>`).join("");
  const body = `
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
${contents}</code></pre></figure>
  <ul class="kit-pages">${pages}</ul>
</section>`;
  return page("Brand kit", body, prefix, {
    description: "The Dunder Quest brand kit: the logo, colors, fonts, art, trailers, YouTube channel and launch posts.",
    path: "brand/",
  });
}

function swatchList(palette: [string, string, string][]): string {
  return palette.map(([name, hex, use]) =>
    `<li><span class="chip" style="background:${hex}"></span>`
    + `<code>${name} = "${hex}"</code><span>${esc(use)}</span></li>`,
  ).join("");
}

function copyTable(rows: [string, string, string][]): string {
  const body = rows.map(([line, where, src]) =>
    `<tr><td>${esc(line)}</td><td>${esc(where)}</td><td>`
    + src.split(", ").map((one) => `<code>${esc(one)}</code>`).join("<br>") + "</td></tr>",
  ).join("");
  return `<div class="table-wrap"><table>\n    <thead><tr><th>Line</th><th>Where</th><th>Made in</th></tr></thead>\n`
    + `    <tbody>${body}</tbody>\n  </table></div>`;
}

function buildBrandIdentity(prefix: string): string {
  const img = `${prefix}static/img/`;
  const body = `
<section class="section kit" aria-labelledby="logo-h">
  <p class="kicker">dunder_quest.__logo__</p>
  <h2 id="logo-h">The wordmark</h2>
  <p class="lede">The name written as a real Python dunder: gold letters between ember underscores, the way <code>__init__</code> sits between its own. Lowercase, one word, underscores kept. In a sentence, the game is just Dunder Quest.</p>
  <div class="kit-logo">
    <p class="kit-mark" aria-hidden="true"><i>__</i>dunder_<wbr>quest<i>__</i></p>
    <a href="${img}og/logo.png"><img src="${img}og/logo.png" alt="The Dunder Quest icon: a pixel q between two pairs of underscores" width="128" height="128"></a>
  </div>
  <p class="fine">Download the icon as <a href="${img}og/logo.png">PNG</a> or <a href="${img}icon.svg">SVG</a>.</p>
</section>

<section class="section kit" aria-labelledby="voice-h">
  <p class="kicker">dunder_quest.__doc__</p>
  <h2 id="voice-h">How it's described</h2>
  <p class="lede">Every line says "platformer" and "Python", because the hook is that your code changes the world.</p>
  ${copyTable(COPY)}
</section>

<section class="section kit" aria-labelledby="color-h">
  <p class="kicker">dunder_quest.__colors__</p>
  <h2 id="color-h">The palette</h2>
  <ul class="swatches">${swatchList(PALETTE)}</ul>
  <figure class="code kit-code"><figcaption>Code in the trailer and on the cards</figcaption><pre><code><i class="kw">for</i> i <i class="kw">in</i> range(<i class="nm">4</i>):
    lift.rise()  <i class="cm"># one notch</i>
key = <i class="st">"spam"</i></code></pre></figure>
</section>

<section class="section kit" aria-labelledby="type-h">
  <p class="kicker">dunder_quest.__fonts__</p>
  <h2 id="type-h">The type</h2>
  <ul class="specimens">
    <li><p class="sp-pixel">Six stages to the Grail</p><b>Pixelify Sans</b> <span>Headlines and the wordmark · <a href="${prefix}static/fonts/PixelifySans.ttf">TTF</a></span></li>
    <li><p class="sp-label">&gt;&gt;&gt; import adventure</p><b>VT323</b> <span>Code, prompts and labels · <a href="${prefix}static/fonts/VT323.ttf">TTF</a></span></li>
    <li><p class="sp-body">Guide a squire across six stages to the Grail.</p><b>Atkinson Hyperlegible</b> <span>Body text on this site</span></li>
  </ul>
  <p class="fine">All three are under the SIL Open Font License.</p>
</section>`;
  return brandPage("identity", body, prefix);
}

/** Pieces of art as [file, name, note, native width, native height, scale]. */
function artList(img: string, art: Art[]): string {
  return art.map(([file, name, note, w, h, s]) =>
    `<li><a href="${img}${file}"><img src="${img}${file}" alt="" width="${w * s}" height="${h * s}" loading="lazy"></a>`
    + `<b>${esc(name)}</b><span>${esc(note)}</span></li>`,
  ).join("");
}

/** Social cards from static/img/og/, each with the square a chat app
 * might cut from it. */
function cardList(img: string, cards: [string, string, string][]): string {
  return cards.map(([file, name, used]) =>
    `<li><a href="${img}og/${file}"><img src="${img}og/${file}" alt="The ${esc(name)} social card" width="1200" height="630" loading="lazy"></a>`
    + `<span class="og-crop" aria-hidden="true"><img src="${img}og/${file}" alt="" loading="lazy"></span>`
    + `<b>${esc(name)}</b><span>${esc(used)}</span></li>`,
  ).join("");
}

function buildBrandArt(prefix: string): string {
  const img = `${prefix}static/img/`;
  const art = artList(img, ART);
  const cards: [string, string, string][] = [["home.png", "Home", "Home, Dunder Quest, How to play, and any page without its own card"],
    ["lessons.png", "Lessons", "The lessons index"],
    ["flatmates.png", "Flatmates.js", "The Flatmates.js page and its game"],
    ["curb.png", "Curb Your Oxidation", "The Curb Your Oxidation page and its game"]];
  cards.push(...STAGES.map((s): [string, string, string] => [`${s.slug}.png`, `${s.id} · ${s.name}`, "That stage's lesson page"]));
  const cardItems = cardList(img, cards);
  const body = `
<section class="section kit" aria-labelledby="art-h">
  <p class="kicker">dunder_quest.__art__</p>
  <h2 id="art-h">The art</h2>
  <p class="lede">The game draws at 480×270. Scale it by whole numbers with nearest-neighbor, never by fractions, or the pixels come out uneven. Click a piece for the original file.</p>
  <ul class="art">${art}</ul>
</section>

<section class="section kit" aria-labelledby="cards-h">
  <p class="kicker">dunder_quest.__cards__</p>
  <h2 id="cards-h">The social cards</h2>
  <p class="lede">What a link to each page looks like when it's shared. Chat apps show either the full card or a small square cut from its middle, shown beside each one, so anything that has to be read sits in the center.</p>
  <ul class="cards">${cardItems}</ul>
  <p class="fine">Painted by <code>games/dunder-quest/tools/make_og.py</code>, <code>games/flatmates/tools/og.py</code> and <code>site/curb_art.py</code>.</p>
</section>`;
  return brandPage("art", body, prefix);
}

// Python's round(), which rounds halves to even.
function pyRound(x: number): number {
  const r = Math.round(x);
  return Math.abs(x % 1) === 0.5 && r % 2 !== 0 ? r - 1 : r;
}

/** A game's core/palette.gd as hex, so the kit's swatches are the game's
 * own colors and can't drift from them. */
function godotPalette(game: string): Record<string, string> {
  const text = read(join(game, "core", "palette.gd"));
  const out: Record<string, string> = {};
  for (const m of text.matchAll(/const (\w+) := Color\(([\d.]+), ([\d.]+), ([\d.]+)/g)) {
    out[m[1]] = "#" + m.slice(2).map((v) => pyRound(parseFloat(v) * 255).toString(16).padStart(2, "0")).join("");
  }
  return out;
}

// Curb Your Oxidation's page of the kit: [palette.gd name, what it's for].
const CURB_PALETTE = [
  ["YELLOW", "The name, and the accents on black"],
  ["INK", "Title cards, and the trailer's cards"],
  ["PAPER", "Text on the title cards"],
  ["RUST", "Rust itself, and the pad's line marker"],
  ["RED", "The line rustc rejects, where Sharon comes in"],
  ["STUCCO", "Westside walls"],
  ["POOL", "Westside pools"],
  ["SEPIA", "The rehearsal: a plan playing in Barry's head"],
  ["PAD", "Barry's yellow legal pad"],
  ["PAD_RULE", "The pad's blue rules"],
  ["PAD_MARGIN", "The pad's red margin"],
  ["PAD_INK", "The plans, written on the pad"],
];
const CURB_ROLES: Record<string, string> = {
  barry: "The hero", gil: "Barry's manager and best friend", sharon: "The borrow checker",
  carol: "Barry's ex-wife", lamont: "The houseguest", ted: "The neighbor with the lawnmower",
};
const CURB_PAD_SAMPLE = 'let wine = String::from("a nice Barolo");\n'
  + "let host_gift = &wine; // a borrow, not a move\n"
  + 'println!("I brought {host_gift}.");';

/** A trailer's YouTube thumbnail, in a row of social cards. */
function thumbItem(src: string, alt: string): string {
  return `<li><a href="${src}"><img src="${src}" alt="${esc(alt)}" width="1920" height="1080" loading="lazy"></a>`
    + "<b>Trailer thumbnail</b><span>The YouTube video, and the page's trailer</span></li>";
}

function buildBrandCurb(prefix: string): string {
  const img = `${prefix}static/img/`;
  const cy = `${img}curb/`;
  const colors = godotPalette(CURB);
  const names = JSON.parse(read(join(CURB, "data", "scenes.json"))).cast;
  const copy: [string, string, string][] = [
    ["The borrow checker is the unwritten social contract. Learn Rust.", "Page hero", "site/build.ts"],
    ["The borrow checker is the unwritten social contract.", "Social card, the home page's title card",
      "site/curb_art.py, site/build.ts"],
    ["learn Rust · a __dunder_quest__ game", "Social card", "site/curb_art.py"],
    ["Barry Danvers has rules. So does Rust. And somebody is always checking.", "Trailer cold open, a card at a time",
      "games/curb/tools/make_trailer.py"],
    ["Learn Rust. Mind your manners.", "Trailer end card", "games/curb/tools/make_trailer.py"],
    ["LEARN RUST · error[E0382]: borrow of moved value", "Trailer thumbnail", "games/curb/tools/make_trailer.py"],
    [CURB_DESC, "Search results", "site/build.ts"],
  ];
  const art: Art[] = [["title.png", "Title art", "The title screen, the page's hero and the social card", 480, 270, 1]];
  art.push(...CURB_CAST.map((w): Art => [`${w}.png`, names[w].full, CURB_ROLES[w], 24, 48, 2]));
  art.push(...["barry", "sharon"].map((w): Art => [`${w}_face.png`, `${names[w].full}, close up`, "On the page's cast list", 48, 48, 2]));
  art.push(["03_pad.png", "The legal pad", "Writing the plan", 480, 270, 1],
    ["03_rant.png", "The interruption", "Sharon, at the line rustc rejects", 480, 270, 1],
    ["03_run.png", "The plan plays out", "Every println! said out loud", 480, 270, 1]);
  const cast = CURB_CAST.map((w) => names[w].full).join(", ");
  const body = `
<section class="section kit" aria-labelledby="cy-logo-h">
  <p class="kicker">curb.__logo__</p>
  <h2 id="cy-logo-h">The name</h2>
  <p class="lede">Set like a title card: heavy Franklin Gothic, in yellow on black, centered. The game uses Libre Franklin at weight 800 to 900. The URL and the repo folder are just <code>curb</code>.</p>
  <div class="kit-logo cy-logo">
    <p class="kit-mark cy-mark">Curb Your Oxidation</p>
    <a href="${cy}icon.svg"><img src="${cy}icon.svg" alt="The Curb Your Oxidation icon: a pixel face squinting inside a rust-orange frame" width="128" height="128"></a>
  </div>
  <p class="fine">Download the icon as <a href="${cy}icon.svg">SVG</a>. It's <code>games/curb/icon.svg</code>.</p>
</section>

<section class="section kit" aria-labelledby="cy-voice-h">
  <p class="kicker">curb.__doc__</p>
  <h2 id="cy-voice-h">How it's described</h2>
  <p class="lede">The hook is that Rust's rules are etiquette, so the lines pair the borrow checker with manners.</p>
  ${copyTable(copy)}
  <p>It's an homage to a certain LA cringe-comedy series, and copies its format, tone and tropes as closely as it can, with three limits. Names are homage names only: ${esc(cast)}. None of the show's catchphrases or lines appear. The music is original, never a recreation of its theme. And nothing public names the show.</p>
</section>

<section class="section kit" aria-labelledby="cy-color-h">
  <p class="kicker">curb.__colors__</p>
  <h2 id="cy-color-h">The palette</h2>
  <p class="lede">Westside daylight and black title cards, read from <code>games/curb/core/palette.gd</code>.</p>
  <ul class="swatches">${swatchList(CURB_PALETTE.map(([n, use]): [string, string, string] => [n, colors[n], use]))}</ul>
  <figure class="code kit-pad"><figcaption>Code on Barry's pad</figcaption><pre><code>${highlightRs(CURB_PAD_SAMPLE)}</code></pre></figure>
</section>

<section class="section kit" aria-labelledby="cy-type-h">
  <p class="kicker">curb.__fonts__</p>
  <h2 id="cy-type-h">The type</h2>
  <ul class="specimens">
    <li><p class="sp-franklin">Curb Your Oxidation</p><b>Libre Franklin</b> <span>The name and every title card, in the game, on this site and in the trailer · <a href="${prefix}static/fonts/LibreFranklin.ttf">TTF</a></span></li>
    <li><p class="sp-label">error[E0382]: borrow of moved value</p><b>VT323</b> <span>The code on Barry's pad in the game, and the trailer's URL · <a href="${prefix}static/fonts/VT323.ttf">TTF</a></span></li>
    <li><p class="sp-pixel">LEARN RUST</p><b>Pixelify Sans</b> <span>Lesson card titles in the game, and the trailer thumbnail · <a href="${prefix}static/fonts/PixelifySans.ttf">TTF</a></span></li>
    <li><p class="sp-body">Barry Danvers lives by rules nobody else has heard of.</p><b>Atkinson Hyperlegible</b> <span>Body text on this site</span></li>
  </ul>
  <p class="fine">All four are under the SIL Open Font License. Libre Franklin is a free revival of Franklin Gothic, whose heavy cut is commercial.</p>
</section>

<section class="section kit" aria-labelledby="cy-art-h">
  <p class="kicker">curb.__art__</p>
  <h2 id="cy-art-h">The cast and the art</h2>
  <p class="lede">The game draws at 480×270. Scale it by whole numbers with nearest-neighbor. Click a piece for the original file.</p>
  <ul class="art">${artList(cy, art)}</ul>
</section>

<section class="section kit" aria-labelledby="cy-cards-h">
  <p class="kicker">curb.__cards__</p>
  <h2 id="cy-cards-h">The social card and the thumbnail</h2>
  <ul class="cards">${cardList(img, [["curb.png", "Curb Your Oxidation", "The Curb Your Oxidation page and its game"]])}${thumbItem(cy + "trailer.png", CURB_THUMB_ALT)}</ul>
  <p class="fine">The card is painted by <code>site/curb_art.py</code>, the thumbnail by <code>games/curb/tools/make_trailer.py</code>. The trailer itself is on <a href="${prefix}brand/trailers/">the trailers page</a>, and its upload form on <a href="${prefix}brand/youtube/">the YouTube page</a>.</p>
</section>

<section class="section kit" aria-labelledby="cy-launch-h">
  <p class="kicker">curb.__launch__</p>
  <h2 id="cy-launch-h">The launch posts</h2>
  <p class="lede">Curb's LinkedIn post and the rest of its launch copy lead <a href="${prefix}brand/launch/#launch-curb-h">the launch page</a>.</p>
</section>`;
  return brandPage("curb", body, prefix, "", "&family=Libre+Franklin:wght@800..900");
}

// Flatmates.js's page of the kit: [palette.gd name, what it's for].
const FM_PALETTE = [
  ["JS", "JavaScript yellow: the .js of the wordmark"],
  ["PAPER", "The rest of the wordmark, and text"],
  ["INK", "Outlines and shadows"],
  ["CLIVE", "Clive's blue, for when you're in his head"],
  ["JAZZ", "Jazz's red, for when you're in his"],
  ["AMBER", "\"a __dunder_quest__ game\" on the card"],
  ["MAGNOLIA", "The flat's magnolia walls"],
  ["CARPET", "The flat's brown carpet"],
  ["CODE_BG", "A laptop's screen"],
  ["GREEN", "A lit amp, a keypad that took the code"],
  ["RED", "A keypad that didn't"],
];

function buildBrandFlatmates(prefix: string): string {
  const img = `${prefix}static/img/`;
  const fm = `${img}flatmates/`;
  const colors = godotPalette(FLATMATES);
  const copy: [string, string, string][] = [
    ["Two flatmates. Two points of view. One of them runs your JavaScript.", "Page hero, social card, trailer title card",
      "site/build.ts, games/flatmates/tools/og.py, games/flatmates/tools/make_trailer.py"],
    ["Two mismatched flatmates in a very small Croydon flat.", "Home page card", "site/build.ts"],
    ["Learn JavaScript. Blame your flatmate.", "Trailer thumbnail", "games/flatmates/tools/make_trailer.py"],
    ["Learn JavaScript. Mostly by accident.", "Trailer end card", "games/flatmates/tools/make_trailer.py"],
    ["a __dunder_quest__ game", "Social card, trailer end card",
      "games/flatmates/tools/og.py, games/flatmates/tools/make_trailer.py"],
    [FLATMATES_DESC, "Search results", "site/build.ts"],
  ];
  const art: Art[] = [["title.png", "Title art", "The page's hero and the social card", 480, 270, 1],
    ["clive.png", "Clive", "Works in credit. Can't jump much", 16, 24, 4],
    ["jazz.png", "Jazz", "Between bands. Can jump, and that's about it", 16, 24, 4],
    ["stage3_editor.png", "The laptop", "The other flatmate's script, with a blank to fill", 480, 270, 1],
    ["stage1_card.png", "An inner voice", "A lesson card, in whoever's head you're in", 480, 270, 1]];
  art.push(...FM_STOPS.map((s): Art => [`stage${s.id}_start.png`, s.name, `Stop ${s.id}, ${s.stop}`, 480, 270, 1]));
  const sample = rep(FM_STOPS[0].code, "{}", "jazz.jump();");
  const body = `
<section class="section kit" aria-labelledby="fm-logo-h">
  <p class="kicker">flatmates.__logo__</p>
  <h2 id="fm-logo-h">The wordmark</h2>
  <p class="lede">The name written as a JavaScript file: lowercase <b>flatmates</b> in paper, then <b>.js</b> in JavaScript yellow, in Pixelify Sans. In a sentence, it's Flatmates.js.</p>
  <div class="kit-logo fm-logo">
    <p class="kit-mark fm-mark">flatmates<i>.js</i></p>
    <a href="${fm}icon.svg"><img src="${fm}icon.svg" alt="The Flatmates.js icon: two front doors side by side in a yellow frame" width="128" height="128"></a>
  </div>
  <p class="fine">Download the icon as <a href="${fm}icon.svg">SVG</a>. It's <code>games/flatmates/icon.svg</code>.</p>
</section>

<section class="section kit" aria-labelledby="fm-voice-h">
  <p class="kicker">flatmates.__doc__</p>
  <h2 id="fm-voice-h">How it's described</h2>
  <p class="lede">The hook is the other point of view: you write the script, and your flatmate lives with it.</p>
  ${copyTable(copy)}
  <p>It's an homage to a certain Croydon flat-share sitcom. Names are homage names only: Clive, Jazz, Big Ron, Tess from Accounts. None of the show's lines appear, and nothing public names the show.</p>
</section>

<section class="section kit" aria-labelledby="fm-color-h">
  <p class="kicker">flatmates.__colors__</p>
  <h2 id="fm-color-h">The palette</h2>
  <p class="lede">A Croydon flat and a laptop's syntax colors, read from <code>games/flatmates/core/palette.gd</code>.</p>
  <ul class="swatches">${swatchList(FM_PALETTE.map(([n, use]): [string, string, string] => [n, colors[n], use]))}</ul>
  <figure class="code kit-laptop"><figcaption>jazz.js, on a laptop</figcaption><pre><code>${highlightJs(sample)}</code></pre></figure>
</section>

<section class="section kit" aria-labelledby="fm-type-h">
  <p class="kicker">flatmates.__fonts__</p>
  <h2 id="fm-type-h">The type</h2>
  <ul class="specimens">
    <li><p class="sp-pixel">flatmates.js</p><b>Pixelify Sans</b> <span>The wordmark, on the title screen, the social card and the trailer · <a href="${prefix}static/fonts/PixelifySans.ttf">TTF</a></span></li>
    <li><p class="sp-label">Two flatmates. Two points of view.</p><b>VT323</b> <span>Names and labels in the game, and the lines on the card and in the trailer · <a href="${prefix}static/fonts/VT323.ttf">TTF</a></span></li>
    <li><p class="sp-mono">jazz.walk(7);</p><b>Atkinson Hyperlegible Mono</b> <span>The laptops' code on this site</span></li>
    <li><p class="sp-body">Clive can't jump much. Jazz can jump, and that's about it.</p><b>Atkinson Hyperlegible</b> <span>Body text on this site</span></li>
  </ul>
  <p class="fine">All four are under the SIL Open Font License.</p>
</section>

<section class="section kit" aria-labelledby="fm-art-h">
  <p class="kicker">flatmates.__art__</p>
  <h2 id="fm-art-h">The flatmates and the art</h2>
  <p class="lede">The game draws at 480×270. Scale it by whole numbers with nearest-neighbor. Click a piece for the original file.</p>
  <ul class="art">${artList(fm, art)}</ul>
</section>

<section class="section kit" aria-labelledby="fm-cards-h">
  <p class="kicker">flatmates.__cards__</p>
  <h2 id="fm-cards-h">The social card and the thumbnail</h2>
  <ul class="cards">${cardList(img, [["flatmates.png", "Flatmates.js", "The Flatmates.js page and its game"]])}${thumbItem(fm + "trailer.png", FM_THUMB_ALT)}</ul>
  <p class="fine">The card is painted by <code>games/flatmates/tools/og.py</code>, the thumbnail by <code>games/flatmates/tools/make_trailer.py</code>. The trailer itself is on <a href="${prefix}brand/trailers/">the trailers page</a>, and its upload form on <a href="${prefix}brand/youtube/">the YouTube page</a>.</p>
</section>`;
  return brandPage("flatmates", body, prefix);
}

const DQ_THUMB_ALT = "Trailer thumbnail: Tom the Enchanter's duel on print(list(range(4))), under the Dunder Quest wordmark";
const FM_THUMB_ALT = "Flatmates.js trailer thumbnail: Clive and Jazz on their sofas, under 'Learn JavaScript. Blame your flatmate.' and jazz.walk(7);";
const CURB_THUMB_ALT = "Curb Your Oxidation trailer thumbnail: the title in yellow serif on black, over Sharon interrupting with error[E0382]";

/** A trailer's thumbnail that turns into the player when clicked
 * (static/trailer.js), or just the thumbnail before it's uploaded. */
function trailerPlayer(video: string, thumb: string, alt: string, name: string): string {
  const image = `<img src="${thumb}" alt="${esc(alt)}" width="1920" height="1080" loading="lazy">`;
  if (!video) return `<div class="trailer">${image}</div>`;
  return `<a class="trailer" href="https://www.youtube.com/watch?v=${video}" data-yt="${video}">${image}`
    + `<span class="trailer-play" aria-hidden="true"></span><span class="sr">Play the ${esc(name)} trailer</span></a>`;
}

function buildBrandTrailers(prefix: string): string {
  const img = `${prefix}static/img/`;
  const facts = TRAILER_FACTS.map(([k, v]) => `<div><dt>${k}</dt><dd>${esc(v)}</dd></div>`).join("");
  const fmFacts = FM_TRAILER_FACTS.map(([k, v]) => `<div><dt>${k}</dt><dd>${esc(v)}</dd></div>`).join("");
  const cuts = TRAILER_CUTS.map(([a, b, c]) => `<tr><td>${a}</td><td>${esc(b)}</td><td>${esc(c)}</td></tr>`).join("");
  const body = `
<section class="section kit" aria-labelledby="trailer-h">
  <p class="kicker">dunder_quest.__trailer__</p>
  <h2 id="trailer-h">Dunder Quest</h2>
  <p class="lede">Built entirely from the game's repo by a Python script, with no video editor: real gameplay, captured frame by frame, with motion graphics in the game's own fonts and colors.</p>
  <div id="trailer">${trailerPlayer(TRAILER_ID, `${img}trailer.png`, DQ_THUMB_ALT, "Dunder Quest")}</div>
  <dl class="facts">${facts}</dl>
  <div class="table-wrap"><table>
    <thead><tr><th>Cut</th><th>Format</th><th>Where</th></tr></thead>
    <tbody>${cuts}</tbody>
  </table></div>
  <p class="fine">How it's made: <a href="${REPO}/blob/main/games/dunder-quest/trailer/README.md">games/dunder-quest/trailer/README.md</a>.</p>
</section>

<section class="section kit" aria-labelledby="fm-trailer-h">
  <p class="kicker">flatmates.__trailer__</p>
  <h2 id="fm-trailer-h">Flatmates.js</h2>
  <p class="lede">Played as a flat-share sitcom: the inner voices do the talking, the camera sits in one flatmate's head and stares at the other, and the jokes land in the awkward silences. Made the same way, from the repo, with no video editor.</p>
  ${trailerPlayer(FM_TRAILER_ID, `${img}flatmates/trailer.png`, FM_THUMB_ALT, "Flatmates.js")}
  <dl class="facts">${fmFacts}</dl>
  <p class="fine">How it's made: <a href="${REPO}/blob/main/games/flatmates/trailer/README.md">games/flatmates/trailer/README.md</a>.</p>
</section>

<section class="section kit" aria-labelledby="cy-trailer-h">
  <p class="kicker">curb.__trailer__</p>
  <h2 id="cy-trailer-h">Curb Your Oxidation</h2>
  <p class="lede">Cut like the series it's an homage to: black title cards, a squint, a freeze frame and a tuba, cut fast to the music. Made the same way, from the repo, with no video editor.</p>
  ${trailerPlayer(CURB_TRAILER_ID, `${img}curb/trailer.png`, CURB_THUMB_ALT, "Curb Your Oxidation")}
  <p class="fine">Its working files are in <code>games/curb/trailer/</code>.</p>
</section>

<section class="section kit">
  <p>Uploading them? The titles, descriptions and thumbnails are on <a href="${prefix}brand/youtube/">the YouTube page</a>.</p>
</section>`;
  return brandPage("trailers", body, prefix, `<script src="${prefix}static/trailer.js"></script>`);
}

/** One video's YouTube upload form, field by field. */
function uploadKit(name: string, video: string, thumb: string, download: string, title: string, description: string,
  tags: string, playlist: string, master: string): string {
  const status = video
    ? `Live at <a href="https://www.youtube.com/watch?v=${video}">youtube.com/watch?v=${video}</a>.`
    : "Not uploaded yet.";
  return `
  <article class="upload">
    <h3>${esc(name)} trailer</h3>
    <p class="fine">${status} Playlists: Trailers, ${esc(playlist)}. Video file: <code>${esc(master)}</code>.</p>
    <div class="upload-grid">
      <figure class="shot"><a href="${thumb}" download="${download}"><img src="${thumb}" alt="" width="1920" height="1080" loading="lazy"></a>
        <figcaption>Thumbnail: <a href="${thumb}" download="${download}">${download}</a>, 1920×1080</figcaption></figure>
      <div>
        ${copyBlock("Title", title, `${len(title)} / 100`)}
        ${copyBlock("Tags", tags, `${len(tags)} / 500`)}
      </div>
    </div>
    ${copyBlock("Description", description, `${len(description)} / 5000`)}
  </article>`;
}

function buildBrandYoutube(prefix: string): string {
  const img = `${prefix}static/img/`;
  const art = CHANNEL_ART.map(([file, name, size, where, alt]) =>
    `<li class="yt-${file.slice(0, -4)}"><a href="${img}youtube/${file}" download="dunder_quest_${file}">`
    + `<img src="${img}youtube/${file}" alt="${esc(alt)}" loading="lazy"></a>`
    + `<b>${esc(name)}</b><span>${esc(size)}</span><span>${esc(where)}</span></li>`,
  ).join("");
  const links = CHANNEL_LINKS.map(([title, url], i) =>
    copyBlock(`Link ${i + 1}: title`, title) + copyBlock(`Link ${i + 1}: URL`, url)).join("");
  const playlists = CHANNEL_PLAYLISTS.map(([n, what]) => `<tr><td>${esc(n)}</td><td>${esc(what)}</td></tr>`).join("");
  const settings = UPLOAD_SETTINGS.map(([k, v]) => `<tr><th scope=row>${esc(k)}</th><td>${esc(v)}</td></tr>`).join("");
  const kits = uploadKit("Dunder Quest", TRAILER_ID, `${img}trailer.png`, "dunder_quest_thumbnail.png",
    YOUTUBE_TITLE, YOUTUBE_DESCRIPTION, YOUTUBE_TAGS, "Dunder Quest",
    "games/dunder-quest/trailer/out/dunder_quest_trailer_4k.mp4")
    + uploadKit("Flatmates.js", FM_TRAILER_ID, `${img}flatmates/trailer.png`, "flatmates_thumbnail.png",
      FM_YOUTUBE_TITLE, FM_YOUTUBE_DESCRIPTION, FM_YOUTUBE_TAGS, "Flatmates.js",
      "games/flatmates/trailer/out/flatmates_trailer_4k.mp4")
    + uploadKit("Curb Your Oxidation", CURB_TRAILER_ID, `${img}curb/trailer.png`, "curb_thumbnail.png",
      CURB_YOUTUBE_TITLE, CURB_YOUTUBE_DESCRIPTION, CURB_YOUTUBE_TAGS, "Curb Your Oxidation",
      "games/curb/trailer/out/curb_trailer_4k.mp4");
  const body = `
<section class="section kit" aria-labelledby="channel-h">
  <p class="kicker">dunder_quest.__channel__</p>
  <h2 id="channel-h">@dunderquest</h2>
  <p class="lede">One channel for every game: <a href="${CHANNEL}">youtube.com/@dunderquest</a>. Everything YouTube Studio asks for is below, ready to upload or paste.</p>
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
  <ul class="yt-art">${art}</ul>
  <p class="fine">Painted by <code>games/dunder-quest/tools/make_channel.py</code>.</p>
</section>

<section class="section kit" aria-labelledby="yt-about-h">
  <p class="kicker">dunder_quest.__channel__.about</p>
  <h2 id="yt-about-h">The channel's details</h2>
  <p class="lede">In Studio under Customization → Basic info, plus the keywords under Settings → Channel.</p>
  ${copyBlock("Description", CHANNEL_DESCRIPTION, `${len(CHANNEL_DESCRIPTION)} / 1000`)}
  ${copyBlock("Keywords", CHANNEL_KEYWORDS, `${len(CHANNEL_KEYWORDS)} / 500`)}
  <div class="yt-links">${links}</div>
  <h3>Playlists</h3>
  <div class="table-wrap"><table>
    <thead><tr><th>Playlist</th><th>What goes in it</th></tr></thead>
    <tbody>${playlists}</tbody>
  </table></div>
</section>

<section class="section kit" aria-labelledby="yt-videos-h">
  <p class="kicker">dunder_quest.__channel__.videos</p>
  <h2 id="yt-videos-h">The videos</h2>
  <p class="lede">Each trailer's upload form, field by field. Check the chapter times against the uploaded video: YouTube needs the first at 0:00, at least three, and each at least 10 seconds long.</p>
  <div class="table-wrap"><table class="settings">
    <thead><tr><th scope=col>Setting</th><th scope=col>For every video</th></tr></thead>
    <tbody>${settings}</tbody>
  </table></div>
  ${kits}
  <p class="fine">Once a trailer is up, put its video ID in <code>TRAILER_ID</code>, <code>FM_TRAILER_ID</code> or <code>CURB_TRAILER_ID</code> in <code>site/build.ts</code>, and the site embeds it.</p>
</section>`;
  return brandPage("youtube", body, prefix);
}

function buildBrandLaunch(prefix: string): string {
  const launch = LAUNCH.map((post) => launchPost(...post)).join("");
  const curb = CURB_LAUNCH.map((post) => launchPost(...post)).join("");
  const body = `
<section class="section kit" aria-labelledby="launch-curb-h">
  <p class="kicker">curb.__launch__</p>
  <h2 id="launch-curb-h">Curb Your Oxidation</h2>
  <p class="lede">The Rust game's posts. The hook: a fun way to learn Rust, in a world where everyone's vibe coding. They're for Rob's own accounts, so unlike the rest of Curb's copy they name the show, as "inspired by".</p>
  <ol class="launch">${curb}</ol>
</section>

<section class="section kit" aria-labelledby="launch-h">
  <p class="kicker">dunder_quest.__launch__</p>
  <h2 id="launch-h">Dunder Quest's launch day</h2>
  <p class="lede">Post on a Tuesday, Wednesday or Thursday, starting with Hacker News at 8:30 AM Eastern, when both the US and Europe are reading. The rest follow through the day. Each one says what Opus 5.5 built and plainly what other models made. The ones with room for a story say why it's a learning game at all.</p>
  <ol class="launch">${launch}</ol>
  <p class="fine">Never ask for upvotes on any of them. Sharing a post is fine; asking for votes gets it removed. Once one does well, mention it in the others.</p>
</section>`;
  return brandPage("launch", body, prefix);
}

// X counts every link as 23 characters, whatever its length.
const LIMITS: Record<string, number> = { X: 280, Bluesky: 300 };

function postLength(platform: string, text: string): number {
  if (platform === "X") return len(text.replace(/https?:\/\/\S+/g, "x".repeat(23)));
  return len(text);
}

function launchPost(platform: string, when: string, title: string, posts: Post[], tips: string): string {
  const block = (label: string, text: string): string => {
    const limit = LIMITS[platform];
    return copyBlock(label, text, limit ? `${postLength(platform, text)} / ${limit}` : "");
  };
  let blocks = title ? block("Title", title) : "";
  posts.forEach((post, i) => {
    const [label, text] = Array.isArray(post) ? post
      : [posts.length > 1 ? `Post ${i + 1} of ${posts.length}` : "Post", post];
    blocks += block(label, text);
  });
  when = when ? `<span class="when">${esc(when)}</span> ` : ""; // Curb's launch has no times yet
  return `<li><h3>${when}${esc(platform)}</h3>`
    + `${blocks}<p class="fine">${esc(tips)}</p></li>`;
}

function build404(prefix: string): string {
  const body = `
<section class="section page-head lost">
  <p class="kicker">404</p>
  <h1>That page isn't on the trail</h1>
  <figure class="code traceback"><pre><code>Traceback (most recent call last):
  File "quest.py", line 404, in &lt;module&gt;
    page = trail.pages[address]
<span class="err">KeyError</span>: 'this page'</code></pre></figure>
  <p class="lede">Check the address for a typo, or start again from one of these.</p>
  <div class="cta"><a class="btn" href="${prefix}">Home</a><a class="btn btn-ghost" href="${prefix}lessons/">Lessons</a><a class="btn btn-ghost" href="${prefix}play/">Play</a></div>
</section>`;
  return page("Page not found", body, prefix);
}

// Lesson pages renamed in the Holy Grail rework: old slug -> new slug. Their
// old addresses were already shared, so `_redirects` keeps them working.
const OLD_SLUGS: Record<string, string> = {
  "amber-hollow": "shrubbery-wood",
  "cinder-span": "cheese-shoppe",
  "kiln-mouth": "cave-of-the-bunny",
  "smelters-fork": "ministry-of-walks",
  "bellows-bridge": "bridge-of-peril",
  "crucible-crown": "castle-aargh",
};

// A text file with \n line ends, however git checked it out.
function read(path: string): string {
  return readFileSync(path, "utf-8").replace(/\r\n?/g, "\n");
}

function write(path: string, text: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text, "utf-8");
}

/** Give a game's exported page the same preview and analytics tags as the
 * site. Godot (or Vite) writes the page after this script builds the site,
 * so `scripts/export_web.sh` runs this as a second step. */
function tagGamePage(index: string, title: string, desc: string, path: string, image: string, alt: string): void {
  const text = read(index);
  if (text.includes('property="og:title"')) return;
  const tags = `<meta name="description" content="${esc(desc)}">\n${headTags(title, desc, path, image, alt)}\n`;
  write(index, text.replace("</head>", () => tags + "</head>"));
  console.log(`tagged ${index}`);
}

function tagPlayPage(index: string): void {
  const desc = "Play Dunder Quest, a pixel-art platformer that teaches Python, right in your browser.";
  tagGamePage(index, "Play Dunder Quest", desc, "play/", "home.png", HOME_ALT);
}

const FLATMATES_ALT = "Flatmates.js title art: two flatmates by their front door on a Croydon tower block landing at dusk.";
const FLATMATES_DESC = "Flatmates.js, a Dunder Quest game: two mismatched flatmates, two points of view, and the JavaScript "
  + "one of them runs. Play it free in your browser.";

/** The same tags for Flatmates.js, the JavaScript game in flatmates/,
 * which Godot exports to flatmates/play/index.html. */
function tagFlatmatesPage(index: string): void {
  const desc = "Play Flatmates.js, the Dunder Quest game that teaches JavaScript, right in your browser.";
  tagGamePage(index, "Play Flatmates.js · Dunder Quest", desc, "flatmates/play/", "flatmates.png", FLATMATES_ALT);
}

type FmStop = {
  id: number; slug: string; name: string; stop: string; puzzle: string; file: string; runs: string; code: string;
  options: [string, boolean, string][];
};

// Flatmates.js's own page at /flatmates/, in its Croydon colors. Its lesson
// cards come from `flatmates/data/lessons.json`, the bank the game reads.
// The stops match `flatmates/core/progress.gd`, each puzzle is the one its
// `flatmates/stages/stage_N.gd` lays out, and each laptop is a script from
// that stage with one blank, as the game's editor shows it. `{}` is the
// blank; every option is [text, works, what happens]. Art comes from
// `flatmates/tools/site_art.py`.
const FM_STOPS: FmStop[] = [
  {
    id: 1, slug: "flat-5b", name: "Flat 5B", stop: "Hermes House",
    puzzle: "The kitchen door only stays open while someone stands on the doormat, and left alone Jazz drifts back to the sofa. So Clive scripts him onto the mat. In the hall the floorboards are up, a hole five boards wide that Clive can't jump. Jazz has to walk to the edge, jump it and step onto the rug that folds the boards down, in that order.",
    file: "jazz.js", runs: "Jazz runs this.",
    code: "// To the edge, over the hole, onto the rug.\njazz.walk(3);\n{}\njazz.walk(1);",
    options: [
      ["jazz.jump();", true, "Jazz walks to the edge, clears the hole and lands on the rug. The boards fold down for Clive."],
      ["jazz.walk(5);", false, "Jazz walks five more boards, straight into the hole. He seems fine. He usually does."],
      ["jazz.jump;", false, "Without the brackets nothing calls the method, so Jazz only thinks about jumping. He stops at the edge."],
    ],
  },
  {
    id: 2, slug: "croydon-credit", name: "Croydon Credit", stop: "Croydon Credit",
    puzzle: "Jazz has come into Clive's office to ask for a loan, which Clive is not allowed to give him. The staff door's keypad wants the desk number, then the extension, and the building's laptop builds the code from two constants. Past the door, the lift goes to whatever floor its script says, but only for a number: \"2\" in quotes is a string, and the lift refuses it.",
    file: "door.js", runs: "The building runs this.",
    code: "const desk = 12;\nconst ext = 7;\nconst code = {};\nkeypad.enter(code);",
    options: [
      ["`${desk}${ext}`", true, "The keypad gets \"127\": the value of desk, then the value of ext. The staff door opens."],
      ["`desk${ext}`", false, "Outside ${ }, desk is just the word desk. The keypad gets \"desk7\" and beeps at you."],
      ["desk + ext", false, "Two numbers added together make 19. The keypad wanted them side by side."],
    ],
  },
  {
    id: 3, slug: "band-practice", name: "Band Practice", stop: "The Cellar Bar",
    puzzle: "The band's stage in the cellar bar is five tiles up. Every strum lifts the speaker stack one notch, so a loop that strums four times carries Clive up to where he can climb off. Five is too loud, and the landlord pulls the plug. Up top, three amps each raise a riser into a stair, and only a for...of over the whole array switches on all three.",
    file: "jazz.js", runs: "Jazz runs this.",
    code: "// Each strum lifts the speakers one notch.\nfor (let i = 0; i {} 4; i++) {\n  jazz.strum();\n}",
    options: [
      ["<", true, "i goes 0, 1, 2, 3: four strums, four notches, and Clive climbs off onto the stage."],
      ["<=", false, "i goes 0 to 4. That's five strums, and the fifth is too loud. The landlord pulls the plug."],
      [">", false, "0 > 4 is false before the first lap, so the loop never runs. Jazz doesn't strum once. Not unheard of."],
    ],
  },
  {
    id: 4, slug: "the-stag-do", name: "The Stag Do", stop: "Wet Bottom Farm",
    puzzle: "Two farm gates, one behind the other, and two plates up in the hay loft, one for each gate. Clive needs Jazz on the first plate until he's between the gates, then on the second. A plain list of steps can't wait for that. A listener can: when Clive rings the bell in the pen, the callback walks Jazz along the loft.",
    file: "jazz.js", runs: "Jazz runs this.",
    code: "jazz.walk(2);\nbell.addEventListener({}, () => {\n  jazz.walk(4);\n});",
    options: [
      ["\"ring\"", true, "Clive rings the bell, the callback runs, and Jazz walks along the loft to the second plate."],
      ["\"click\"", false, "The bell never clicks. It rings. Jazz waits on the first plate for an event that never comes."],
      ["\"ding\"", false, "Close, but the event is called \"ring\". Jazz listens for a ding forever, which suits him."],
    ],
  },
  {
    id: 5, slug: "east-croydon", name: "East Croydon", stop: "East Croydon",
    puzzle: "The ticket barrier opens for one second when someone presses the help button, and the button is a long walk from the barrier. setTimeout presses it later, once Clive has had time to get there. On the platform, the train doors open when the tannoy hears \"mind\", \"the\", \"gap!\" in that order, and the laptop logs \"gap!\" from a setTimeout of 0.",
    file: "jazz.js", runs: "Jazz runs this.",
    code: "// Jazz is at the help button.\nsetTimeout(() => {\n  jazz.press();\n}, {});",
    options: [
      ["2500", true, "Two and a half seconds later Jazz presses the button, just as Clive reaches the barrier. It opens for him."],
      ["500", false, "Half a second is too soon. The barrier opens and shuts again while Clive is still walking."],
      ["0", false, "A timer of 0 still waits for the script to finish, but not for Clive. The barrier opens to nobody."],
    ],
  },
  {
    id: 6, slug: "the-wedding", name: "The Wedding", stop: "St Agatha's",
    puzzle: "Tess from Accounts is marrying Gary from Sales. Jazz is the music, and Clive, against his better judgement, is doing a reading. Jazz has to play the march once Clive reaches the altar, and await is how his script waits. Out the back, the getaway car leaves on car.drive(), so it should wait on Promise.all of both flatmates reaching it, or it goes with nobody in it.",
    file: "jazz.js", runs: "Jazz runs this.",
    code: "async function ceremony() {\n  {} clive.reach(altar);\n  jazz.strum();\n}\nceremony();",
    options: [
      ["await", true, "The function pauses until Clive reaches the altar, then Jazz plays the march, on cue for once."],
      ["", false, "Without await, Jazz strums straight away, to an empty aisle. Clive arrives to silence."],
    ],
  },
];
const FM_KEYWORDS = new Set(["const", "let", "var", "for", "of", "in", "if", "else", "return", "function", "async", "await",
  "new", "true", "false", "null", "undefined", "typeof", "while"]);
// Python's Unicode \w, \d and \b, which the highlighters were written against.
const W = String.raw`[\p{L}\p{N}_]`;
const D = String.raw`\p{Nd}`;
const NUMBER = String.raw`(?<!${W})${D}+(?:\.${D}+)?(?!${W})`;
const FM_TOKEN = new RegExp(String.raw`(?<c>//[^\n]*)|(?<s>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|` + "`" + String.raw`(?:\\.|[^` + "`" + String.raw`\\])*` + "`)"
  + String.raw`|(?<n>${NUMBER})|(?<w>[A-Za-z_$](?:${W}|\$)*)(?<call>\s*\()?`, "gu");
const FM_BLANK = "\x00";

/** JavaScript as HTML spans, with the game's editor's colors: keywords,
 * strings, numbers, comments, and the names of calls. FM_BLANK passes
 * through untouched. */
function highlightJs(code: string): string {
  const out: string[] = [];
  let pos = 0;
  for (const m of code.matchAll(FM_TOKEN)) {
    const g = m.groups!;
    out.push(esc(code.slice(pos, m.index)));
    pos = m.index! + m[0].length;
    if (g.w) {
      const cls = FM_KEYWORDS.has(g.w) ? "k" : g.call ? "b" : "";
      out.push(cls ? `<span class="${cls}">${esc(g.w)}</span>` : esc(g.w));
      out.push(esc(g.call ?? ""));
    } else {
      const cls = g.c ? "c" : g.s ? "s" : "n";
      out.push(`<span class="${cls}">${esc(m[0])}</span>`);
    }
  }
  out.push(esc(code.slice(pos)));
  return out.join("");
}

function jsBlock(code: string): string {
  return `<figure class="code"><pre><code>${highlightJs(code)}</code></pre></figure>`;
}

/** The stop's laptop: tap the blank or an option, then Run. Without
 * JavaScript, the options and the answer still show. */
function fmLaptop(stop: FmStop): string {
  let code = highlightJs(rep(stop.code, "{}", FM_BLANK));
  code = rep(code, FM_BLANK, '<button class="blank" type="button" aria-label="The blank: tap to change it" disabled>?</button>');
  const picks = stop.options.map(([text, ok, result]) =>
    `<li><button class="pick" type="button" data-ok="${ok}" data-result="${esc(result)}" aria-pressed="false" disabled>`
    + `<code>${text ? esc(text) : "(nothing)"}</code></button></li>`,
  ).join("");
  const [answer, , why] = stop.options.find(([, ok]) => ok)!;
  return `<figure class="laptop" data-laptop>
  <figcaption><b>${esc(stop.file)}</b> ${esc(stop.runs)}</figcaption>
  <pre><code>${code}</code></pre>
  <div class="laptop-bar"><span>Options:</span><ul class="picks">${picks}</ul><button class="run" type="button" disabled>Run</button></div>
  <p class="out" role="status" hidden><b></b> <span></span></p>
  <details><summary>Show the answer</summary><p><code>${esc(answer)}</code>. ${esc(why)}</p></details>
</figure>`;
}

const FM_WHO: Record<string, string> = { clive: "Clive", jazz: "Jazz" };

function fmCard(card: Json): string {
  const who = card.who;
  return `<article class="voice voice-${who}">
  <p class="voice-kick">${FM_WHO[who]}'s inner voice</p>
  <h4>${esc(card.title)}</h4>
  ${jsBlock(card.code.join("\n"))}
  <p>${esc(card.text)}</p>
</article>`;
}

/** The Flatmates.js page. `prefix` reaches the site root; the game itself
 * is in `play/` next to this page. */
function buildFlatmates(prefix: string): string {
  const img = `${prefix}static/img/flatmates/`;
  const bank = JSON.parse(read(join(FLATMATES, "data", "lessons.json")));
  const line = FM_STOPS.map((s) =>
    `<li><a href="#${s.slug}"><span class="ln-stop">${esc(s.stop)}</span>`
    + `<span class="ln-lesson">${esc(bank[String(s.id)].lesson)}</span></a></li>`,
  ).join("");
  const stops = FM_STOPS.map((s) => {
    const lesson = bank[String(s.id)];
    const cards = lesson.cards.filter((c: Json) => c.id !== "c1_heads").map(fmCard).join("");
    return `
<article class="stop" id="${s.slug}">
  <header>
    <p class="kicker"><span class="roundel">${s.id}</span> ${esc(s.stop)}</p>
    <h3>${esc(s.name)} <span>${esc(lesson.lesson)}</span></h3>
  </header>
  <div class="stop-grid">
    <div>
      <img src="${img}stage${s.id}_start.png" alt="${esc(s.name)}, as the stage opens" width="480" height="270" loading="lazy">
      <p>${esc(s.puzzle)}</p>
    </div>
    ${fmLaptop(s)}
  </div>
  <div class="voices">${cards}</div>
</article>`;
  });
  const controls = [
    ["Move", "A / D or ← / →", "D-pad or left stick"],
    ["Jump", "Space, W or ↑", "A / Cross"],
    ["Swap heads", "Tab or Q", "Y / Triangle or RB"],
    ["Open a laptop, ring a bell, pull a lever", "E", "X / Square"],
    ["Run the script", "R", "LB / L1"],
    ["Pause", "Esc or P", "Start / Options"],
  ];
  const rows = controls.map(([a, k, p]) => `<tr><th scope=row>${a}</th><td data-label=Keyboard>${k}</td><td data-label=Gamepad>${p}</td></tr>`).join("");
  const total = Object.values(bank).reduce((n: number, v: Json) => n + v.cards.length, 0);
  const body = `
<section class="hero fm-hero">
  <img class="hero-art" src="${img}title.png" alt="Pixel art of two flatmates, one in a suit with his arms folded and one holding a guitar, by their front door on a tower block landing at dusk" width="480" height="270">
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
  ${trailerPlayer(FM_TRAILER_ID, `${img}trailer.png`, FM_THUMB_ALT, "Flatmates.js")}
  <p class="fine">More on the channel: <a href="${CHANNEL}">youtube.com/@dunderquest</a>.</p>
</section>

<section class="section" id="heads" aria-labelledby="heads-h">
  <p class="kicker">Two heads, one flat</p>
  <h2 id="heads-h">You're whichever one you aren't scripting</h2>
  <ul class="mates">
    <li class="mate-clive"><img src="${img}clive.png" alt="" width="64" height="96">
      <div><h3>Clive</h3><p>Works in credit at Croydon Credit. Owns a tie for weekends. Jumps like a man carrying a briefcase, because he usually is. Left alone, he drifts back to his armchair.</p></div></li>
    <li class="mate-jazz"><img src="${img}jazz.png" alt="" width="64" height="96">
      <div><h3>Jazz</h3><p>Would-be rock god, between bands. Jumps high and does very little else. Left alone, he drifts back to the sofa, where his real work happens.</p></div></li>
  </ul>
  <ol class="loop">
    <li><img src="${img}stage3_editor.png" alt="A laptop's editor open on jazz.js: a for loop with a blank where the comparison goes" width="480" height="270" loading="lazy">
      <h3>Open his laptop</h3><p>Laptops around each stage open the other flatmate's to-do list as real JavaScript, with blanks to fill. Pick what goes in each one.</p></li>
    <li><img src="${img}stage4_start.png" alt="The stag do at a farm: Clive in the pen below, Jazz up in the hay loft by two plates" width="480" height="270" loading="lazy">
      <h3>Run it, then swap</h3><p>Run the script and you swap into the other head. He does what you wrote while you play his flatmate, in JavaScript's order: his lines first, then timers, listeners and awaits.</p></li>
    <li><img src="${img}stage1_card.png" alt="Clive's inner voice card: Objects and methods, with jazz.walk(7) and jazz.jump()" width="480" height="270" loading="lazy">
      <h3>Listen to the inner voice</h3><p>Each flatmate thinks out loud along the top of the screen. Some thoughts open a lesson card, with the code and the idea behind it, in whoever's voice you're in.</p></li>
  </ol>
</section>

<section class="section" id="line" aria-labelledby="line-h">
  <p class="kicker">The Croydon line</p>
  <h2 id="line-h">Six stops, six pieces of JavaScript</h2>
  <p class="lede">The game is a tram line across Croydon, and each stop teaches one idea. They build on each other, from calling a method to awaiting two promises at once. Every stop has a laptop below, with one of its scripts to try.</p>
  <ol class="line">${line}</ol>
  ${stops.join("")}
  <p class="count"><b>${total}</b> lesson cards · <b>6</b> stops · every snippet checked against Node</p>
</section>

<section class="section" id="controls" aria-labelledby="controls-h">
  <p class="kicker">Controls</p>
  <h2 id="controls-h">How to play</h2>
  <div class="table-wrap"><table class="controls">
    <thead><tr><th scope=col>Action</th><th scope=col>Keyboard</th><th scope=col>Gamepad</th></tr></thead>
    <tbody>${rows}</tbody>
  </table></div>
  <p class="fine">On a phone or tablet, turn it sideways: the on-screen buttons include Swap and Code. A fall sends you back to the last Wi-Fi router you passed. Each stop hides six custard creams. Your progress saves in this browser, separately from Dunder Quest's.</p>
  <a class="btn" href="play/">Play Flatmates.js</a>
</section>

<section class="section fm-family" aria-labelledby="family-h">
  <p class="kicker">a ${WORDMARK} game</p>
  <h2 id="family-h">Prefer Python?</h2>
  <p class="lede">Flatmates.js is the second Dunder Quest game. The first, <a href="${prefix}${QUEST_PAGE}">Dunder Quest</a>, teaches Python on a quest for the Grail: slice a list to lay a bridge, loop a lift up a cave wall, and duel the Bridgekeeper. The third, <a href="${prefix}curb/">Curb Your Oxidation</a>, teaches Rust on the Westside of LA.</p>
  <p class="fine">Flatmates.js is an homage to a certain Croydon flat-share sitcom. The names and jokes are winks, not the show's own characters or lines, and it isn't affiliated with or endorsed by anyone who made it.</p>
</section>`;
  return fmPage(body, prefix);
}

const FM_NAV = [["#heads", "Two heads"], ["#line", "The stops"], ["#controls", "How to play"]];

function fmPage(body: string, prefix: string): string {
  const links = FM_NAV.map(([href, label]) => `<a href="${href}">${label}</a>`).join("");
  const title = "Flatmates.js · Dunder Quest";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${esc(FLATMATES_DESC)}">
${headTags(title, FLATMATES_DESC, "flatmates/", "flatmates.png", FLATMATES_ALT)}
<link rel="icon" href="${prefix}static/img/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${prefix}static/style.css">
<link rel="stylesheet" href="${prefix}static/flatmates.css">
</head>
<body class="fm">
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="./"><img src="${prefix}static/img/flatmates/clive.png" alt="" width="16" height="24"><span>flatmates<i>.js</i></span></a>
  <nav aria-label="Flatmates.js">${links}<a class="fm-home" href="${prefix}">All games</a></nav>
  <a class="btn btn-small" href="play/">Play</a>
</header>
<main id="main">
${body}
</main>
<footer class="foot">
  <p><img src="${prefix}static/img/flatmates/jazz.png" alt="" width="16" height="24"> Flatmates.js. Two flatmates, one Croydon, six stops of JavaScript.</p>
  <p><a href="play/">Play in your browser</a> · <a href="#line">The stops</a> · <a href="${prefix}${QUEST_PAGE}">Dunder Quest, the Python game</a> · <a href="${REPO}/tree/main/games/flatmates">Source on GitHub</a></p>
</footer>
<script src="${prefix}static/laptop.js"></script>
<script src="${prefix}static/trailer.js"></script>
</body>
</html>
`;
}

const CURB_ALT = "Curb Your Oxidation: a black title card, the name in yellow serif, over a palm-lined Westside street at sunset.";
const CURB_DESC = "Curb Your Oxidation, a Dunder Quest game that teaches Rust: the borrow checker is the unwritten "
  + "social contract, and every petty dispute is settled by a Rust program. Play it free in your browser.";

/** The same tags for Curb Your Oxidation, the Rust game in curb/, which
 * Godot exports to curb/play/index.html. */
function tagCurbPage(index: string): void {
  const desc = "Play Curb Your Oxidation, the Dunder Quest game that teaches Rust, right in your browser.";
  tagGamePage(index, "Play Curb Your Oxidation · Dunder Quest", desc, "curb/play/", "curb.png", CURB_ALT);
}

// Curb Your Oxidation's own page at /curb/: black title cards in heavy Franklin Gothic
// on a bright Westside page. Everything about the season comes from
// `curb/data/scenes.json`, the data the game plays, and every pad answers
// from `site/curb_cases.json`, the in-game checker's verdict on each
// combination of blanks (both made by `site/curb_art.py`, which also copies
// the art).
const CURB_RS_KEYWORDS = new Set(["fn", "let", "mut", "match", "if", "else", "for", "in", "impl", "struct", "enum", "self",
  "Self", "return", "pub", "use", "while", "loop", "as", "ref", "move", "true", "false"]);
const CURB_RS_TYPES = new Set(["i32", "i64", "u32", "usize", "f64", "bool", "str", "String", "Vec", "Option", "Result",
  "Some", "None", "Ok", "Err"]);
const CURB_TOKEN = new RegExp(String.raw`(?<c>//[^\n]*)|(?<s>"(?:\\.|[^"\\])*")|(?<l>'[a-z_]+(?!${W})(?!'))`
  + String.raw`|(?<n>${NUMBER})|(?<w>[A-Za-z_]${W}*)(?<bang>!)?(?<call>\s*\()?`, "gu");
// The cast on the page, in the order they're introduced.
const CURB_CAST = ["barry", "gil", "sharon", "carol", "lamont", "ted"];
const CURB_CAST_NOTES: Record<string, string> = {
  barry: "Semi-retired TV writer on the Westside. Lives by rules nobody else has heard of, and holds everyone to them.",
  gil: "Barry's manager and best friend. Endlessly patient, which Barry tests daily.",
  sharon: "Gil's wife, and the borrow checker. When a plan breaks the rules, she bursts in at the exact line, with rustc's own error and an opinion about it.",
  carol: "Barry's ex-wife, somehow still on speaking terms. Counts his minutes.",
  lamont: "The houseguest who came for one night. It's been six weeks.",
  ted: "The neighbor whose lawnmower has been in Barry's garage for six weeks.",
};

/** Rust as HTML spans, in the pad's ink colors: keywords, types, strings,
 * numbers, lifetimes, comments, macros and calls. Private-use characters
 * (the blanks) pass through untouched. */
function highlightRs(code: string): string {
  const out: string[] = [];
  let pos = 0;
  for (const m of code.matchAll(CURB_TOKEN)) {
    const g = m.groups!;
    out.push(esc(code.slice(pos, m.index)));
    pos = m.index! + m[0].length;
    if (g.w) {
      const word = g.w;
      if (g.bang) {
        out.push(`<span class="m">${esc(word)}!</span>`);
      } else {
        const cls = CURB_RS_KEYWORDS.has(word) ? "k" : CURB_RS_TYPES.has(word) || /^\p{Lu}/u.test(word) ? "t"
          : g.call ? "b" : "";
        out.push(cls ? `<span class="${cls}">${esc(word)}</span>` : esc(word));
      }
      out.push(esc(g.call ?? ""));
    } else {
      const cls = g.c ? "c" : g.s ? "s" : g.l ? "l" : "n";
      out.push(`<span class="${cls}">${esc(m[0])}</span>`);
    }
  }
  out.push(esc(code.slice(pos)));
  return out.join("");
}

// Python's str.title(), for a name the cast list doesn't have.
function pyTitle(text: string): string {
  return text.replace(/\p{L}+/gu, (w) => w[0].toUpperCase() + w.slice(1).toLowerCase());
}

/** One line of dialogue, as a script would print it. */
function curbSaid(data: Json, line: Json[]): string {
  const who = data.cast[line[0]]?.name ?? pyTitle(line[0]);
  return `<p><b>${esc(who)}</b> ${esc(line[1])}</p>`;
}

// A string split once, the way Python's str.split(sep, 1) does it.
function splitOnce(text: string, sep: string): [string, string] {
  const at = text.indexOf(sep);
  return [text.slice(0, at), text.slice(at + sep.length)];
}

/** What the scene does with one combination of blanks, the way the game
 * plays it: Sharon's interruption, the scene playing out, or a panic. */
function curbVerdict(data: Json, plan: Json, c: Json): Json {
  const lines = (say: Json[]): Json[] => say.map(([w, t]) => [data.cast[w].name, t]);
  if (!c.ok) {
    const [code, rest] = splitOnce(c.first, " line ");
    const [line, msg] = splitOnce(rest, ": ");
    const rant = plan.rants?.[code] || (data.rants[code] ?? data.rants.syntax);
    return { kind: "err", head: `error[${code}]: ${msg}`, at: `--> ${plan.file}:${line}`, lines: [["Sharon", rant]] };
  }
  const out = [...c.stdout];
  if (c.panic) {
    out.push(`thread 'main' panicked: ${c.panic}`);
    return { kind: "panic", out, lines: lines(plan.panic_line?.length ? plan.panic_line : [["sharon", data.rants.panic]]) };
  }
  if (JSON.stringify(c.stdout) === JSON.stringify(plan.expect)) {
    const key = Object.entries(c.picks).map(([k, v]) => `${k}=${v}`).join(",");
    return { kind: "ok", out, lines: lines([...(plan.remarks?.[key] ?? []), ...plan.success]) };
  }
  return { kind: "wrong", out, lines: lines(plan.wrong?.length ? plan.wrong : [[plan.npc, data.rants.wrong]]) };
}

/** A plan on Barry's yellow legal pad: tap a blank to cycle its options,
 * then Run it (static/pad.js). It opens on the scene's starting picks, so
 * the first run fails the way the game's does. Without JavaScript the
 * options and the answer still show. */
function curbPad(data: Json, plan: Json, cases: Json[]): string {
  const order: string[] = [];
  for (const line of plan.code) {
    for (const [, n] of line.matchAll(/«(\w+)»/g)) if (!order.includes(n)) order.push(n);
  }
  let src = plan.code.join("\n");
  order.forEach((name, i) => { src = rep(src, `«${name}»`, String.fromCharCode(0xE000 + i)); });
  let code = highlightRs(src);
  order.forEach((name, i) => {
    const opts = plan.slots[name];
    const start = opts.indexOf(plan.start[name]);
    code = rep(code, String.fromCharCode(0xE000 + i),
      `<button class="blank" type="button" data-pick="${start}" `
      + `data-options='${esc(pyJson(opts))}' aria-label="Blank ${i + 1}: tap to change it" disabled>`
      + `${esc(opts[start]) || "…"}</button>`);
  });
  // A Map, so keys like "0" keep the cases' order instead of sorting first.
  const verdicts = new Map<string, Json>();
  for (const c of cases) {
    if (c.plan === plan.id) {
      const key = order.map((n) => String(plan.slots[n].indexOf(c.picks[n]))).join(",");
      verdicts.set(key, curbVerdict(data, plan, c));
    }
  }
  const options = order.map((n, i) =>
    `<li><span>Blank ${i + 1}:</span> `
    + plan.slots[n].map((o: string) => `<code>${o ? esc(o) : "(nothing)"}</code>`).join(" · ") + "</li>").join("");
  const solution = order.map((n) => `<code>${esc(plan.solution[n]) || "(nothing)"}</code>`).join(" and ");
  const said = plan.expect.map((line: string) => `<li><code>${esc(line)}</code></li>`).join("");
  return `<figure class="pad" data-pad data-verdicts='${esc(pyJson(verdicts, false))}'>
  <figcaption><b>${esc(plan.file)}</b> ${esc(plan.title)}</figcaption>
  <pre><code>${code}</code></pre>
  <ul class="pad-options">${options}</ul>
  <p class="pad-hint"><b>Barry, thinking:</b> ${esc(plan.hint)}</p>
  <div class="pad-bar"><span>Tap a blank to change it.</span><button class="run" type="button" disabled>Run it</button></div>
  <div class="pad-out" role="status" hidden></div>
  <details><summary>Show the answer</summary><p>${solution}. Then the scene plays out, one line per <code>println!</code>:</p><ol class="pad-said">${said}</ol></details>
</figure>`;
}

function curbCard(data: Json, card: Json): string {
  const who = data.cast[card.who].name;
  const tail = card.error ? `<p class="rule-err">error[${esc(card.error)}]</p>`
    : '<p class="rule-out">prints ' + (card.output ?? []).map((o: string) => `<code>${esc(o)}</code>`).join(" ") + "</p>";
  return `<article class="rule">
  <p class="rule-kick">${esc(who)} explains</p>
  <h4>${esc(card.title)}</h4>
  <figure class="code"><pre><code>${highlightRs(card.code.join("\n"))}</code></pre></figure>
  ${tail}
  <p>${esc(card.text)}</p>
</article>`;
}

/** The Curb Your Oxidation page. `prefix` reaches the site root; the game
 * itself is in `play/` next to this page. */
function buildCurb(prefix: string): string {
  const img = `${prefix}static/img/curb/`;
  const data = JSON.parse(read(join(CURB, "data", "scenes.json")));
  const cases = JSON.parse(read(join(SITE, "curb_cases.json")));
  const scenes: Json[] = data.scenes;
  const guide = scenes.map((s) =>
    `<li><a href="#ep${s.id}"><span class="ep-n">Episode ${s.id}</span>`
    + `<span class="ep-t">${esc(s.title)}</span><span class="ep-l">${esc(s.lesson)}</span></a></li>`).join("");
  const episodes = scenes.map((s) => {
    const cards = s.plans.map((p: Json) => curbCard(data, data.cards[p.card])).join("");
    const cast = s.cast.map(([c]: Json[]) => data.cast[c].name).join(", ");
    return `
<article class="ep" id="ep${s.id}">
  <header class="title-card"><p>Episode ${s.id}</p><h3>${esc(s.title)}</h3></header>
  <p class="ep-meta"><b>${esc(s.place)}</b> · ${esc(s.lesson)} · with ${esc(cast)}</p>
  <div class="ep-grid">
    <div>
      <img src="${img}${String(s.id).padStart(2, "0")}_opening.png" alt="${esc(s.place)}, as the episode opens" width="480" height="270" loading="lazy">
      <div class="script">${s.opening.map((line: Json[]) => curbSaid(data, line)).join("")}</div>
    </div>
    ${curbPad(data, s.plans[0], cases)}
  </div>
  <div class="rules">${cards}</div>
</article>`;
  });
  const cast = CURB_CAST.map((w) =>
    `<li class="who-${w}"><img src="${img}${w}_face.png" alt="" width="96" height="96">`
    + `<div><h3>${esc(data.cast[w].full)}</h3><p>${esc(CURB_CAST_NOTES[w])}</p></div></li>`).join("");
  const codes: string[] = [];
  for (const s of scenes) {
    for (const p of s.plans) {
      if (!codes.includes(p.start_error)) codes.push(p.start_error);
    }
  }
  const rulebook = codes.map((c) => `<li><code>error[${c}]</code><q>${esc(data.rants[c])}</q></li>`).join("");
  const controls = [
    ["Walk", "← / → or A / D", "D-pad or left stick"],
    ["Talk, open a plan", "E, Space or Enter", "X / Square or A / Cross"],
    ["Pick a blank on the pad", "← / →", "D-pad left and right"],
    ["Change the blank", "↑ / ↓", "D-pad up and down"],
    ["Run the plan", "Enter or R", "LB / L1"],
    ["Close the pad, pause", "Esc or P", "Start / Options"],
  ];
  const rows = controls.map(([a, k, p]) => `<tr><th scope=row>${a}</th><td data-label=Keyboard>${k}</td><td data-label=Gamepad>${p}</td></tr>`).join("");
  // No trailer yet: the section appears once CURB_TRAILER_ID is set.
  const trailer = !CURB_TRAILER_ID ? "" : `
<section class="section" id="trailer" aria-labelledby="trailer-h">
  <p class="kicker">The trailer</p>
  <h2 id="trailer-h">Previously, on the Westside</h2>
  ${trailerPlayer(CURB_TRAILER_ID, `${img}trailer.png`, CURB_THUMB_ALT, "Curb Your Oxidation")}
  <p class="fine">More on the channel: <a href="${CHANNEL}">youtube.com/@dunderquest</a>.</p>
</section>
`;
  const total = Object.keys(data.cards).length;
  const plans = scenes.reduce((n, s) => n + s.plans.length, 0);
  const body = `
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
  <img class="cy-strip" src="${img}title.png" alt="Pixel art of a palm-lined Westside street at sunset, a silver hybrid parked at the curb" width="480" height="270">
</section>
${trailer}
<section class="section" id="how" aria-labelledby="how-h">
  <p class="kicker">How an episode goes</p>
  <h2 id="how-h">Plan it. Rehearse it. Get interrupted.</h2>
  <p class="lede">The way rustc reads your whole program before anything runs, Barry plays every plan through in his head first. If it breaks the rules, it never happens. If it compiles, every <code>println!</code> is somebody saying that line out loud.</p>
  <ol class="loop">
    <li><img src="${img}03_pad.png" alt="Barry's legal pad open on gift.rs, with the blank in let host_gift = wine; picked out and three options below" width="480" height="270" loading="lazy">
      <h3>Write the plan</h3><p>Talk to someone and the dispute turns into a short Rust program on Barry's legal pad, with blanks to fill. Pick what goes in each.</p></li>
    <li><img src="${img}03_rant.png" alt="Sharon bursting in with error[E0382]: borrow of moved value" width="480" height="270" loading="lazy">
      <h3>Rehearse it, in sepia</h3><p>Barry runs it in his head, line by line. Break a rule and Sharon bursts in at that line with the real rustc error, <code>error[E0382]</code> and all, and an opinion about it.</p></li>
    <li><img src="${img}03_run.png" alt="The plan playing out for real: Sharon says Thanks for the Barolo while the code highlights her println! line" width="480" height="270" loading="lazy">
      <h3>Watch it happen</h3><p>When it compiles, the scene plays it out for real, and only moves on if the program prints exactly what should happen. Then a squint, a freeze frame, and the tuba.</p></li>
  </ol>
</section>

<section class="section" id="cast" aria-labelledby="cast-h">
  <p class="kicker">Starring</p>
  <h2 id="cast-h">The cast</h2>
  <ul class="cast">${cast}</ul>
  <p class="fine">Also appearing: Sol at the deli, who counts the samples; Whit Thornbury, who manages the country club; Philippe, maître d' of a bistro Barry can't get into; Dana at returns, who has heard it all; and Rain, the barista.</p>
</section>

<section class="section" id="season" aria-labelledby="season-h">
  <p class="kicker">The season</p>
  <h2 id="season-h">Ten episodes, ten pieces of Rust</h2>
  <p class="lede">Each episode is one petty dispute and one idea, and they build on each other: from <code>let mut</code> to ownership, borrowing and lifetimes. Every episode below has one of its plans on a pad to try. It opens on Barry's first idea, which is wrong.</p>
  <ol class="guide">${guide}</ol>
  ${episodes.join("")}
  <p class="count"><b>${total}</b> lesson cards · <b>${plans}</b> plans · every one compiled with the real rustc</p>
</section>

<section class="section" id="rules" aria-labelledby="rules-h">
  <p class="kicker">The rulebook</p>
  <h2 id="rules-h">rustc, as Sharon puts it</h2>
  <p class="lede">The error codes are the compiler's own. The delivery is Sharon's.</p>
  <ul class="rulebook">${rulebook}</ul>
</section>

<section class="section" id="controls" aria-labelledby="controls-h">
  <p class="kicker">Controls</p>
  <h2 id="controls-h">How to play</h2>
  <div class="table-wrap"><table class="controls">
    <thead><tr><th scope=col>Action</th><th scope=col>Keyboard</th><th scope=col>Gamepad</th></tr></thead>
    <tbody>${rows}</tbody>
  </table></div>
  <p class="fine">On a phone or tablet, turn it sideways and tap: tap someone to talk, tap a blank to change it. Your progress saves in this browser, separately from the other games'.</p>
  <a class="btn" href="play/">Play Curb Your Oxidation</a>
</section>

<section class="section cy-family" aria-labelledby="family-h">
  <p class="kicker">a ${WORDMARK} game</p>
  <h2 id="family-h">Prefer Python, or JavaScript?</h2>
  <p class="lede">Curb Your Oxidation is the third Dunder Quest game. <a href="${prefix}${QUEST_PAGE}">Dunder Quest</a> teaches Python on a quest for the Grail, and <a href="${prefix}flatmates/">Flatmates.js</a> teaches JavaScript in a very small Croydon flat.</p>
  <p class="fine">Curb Your Oxidation is an homage to a certain LA cringe-comedy series. The names, lines and music are original, not the show's own, and it isn't affiliated with or endorsed by anyone who made it.</p>
</section>`;
  return curbPage(body, prefix);
}

const CURB_NAV = [["#cast", "The cast"], ["#season", "Episodes"], ["#controls", "How to play"]];

function curbPage(body: string, prefix: string): string {
  const links = CURB_NAV.map(([href, label]) => `<a href="${href}">${label}</a>`).join("");
  const title = "Curb Your Oxidation · Dunder Quest";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${esc(CURB_DESC)}">
${headTags(title, CURB_DESC, "curb/", "curb.png", CURB_ALT)}
<link rel="icon" href="${prefix}static/img/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&family=Libre+Franklin:ital,wght@0,400..900;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${prefix}static/style.css">
<link rel="stylesheet" href="${prefix}static/curb.css">
</head>
<body class="cy">
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="./"><img src="${prefix}static/img/curb/barry.png" alt="" width="12" height="24"><span>Curb Your Oxidation</span></a>
  <nav aria-label="Curb Your Oxidation">${links}<a class="cy-home" href="${prefix}">All games</a></nav>
  <a class="btn btn-small" href="play/">Play</a>
</header>
<main id="main">
${body}
</main>
<footer class="foot">
  <p><img src="${prefix}static/img/curb/sharon.png" alt="" width="12" height="24"> Curb Your Oxidation. One Westside, ten petty disputes, ten pieces of Rust.</p>
  <p><a href="play/">Play in your browser</a> · <a href="#season">The episodes</a> · <a href="${prefix}${QUEST_PAGE}">Dunder Quest, the Python game</a> · <a href="${prefix}flatmates/">Flatmates.js, the JavaScript game</a> · <a href="${REPO}/tree/main/games/curb">Source on GitHub</a></p>
</footer>
<script src="${prefix}static/pad.js"></script>
<script src="${prefix}static/trailer.js"></script>
</body>
</html>
`;
}

// Mission Silicon's page at /mission-silicon/, the fourth game, being rebuilt
// as a web app (`mission-silicon/web/`) to teach first: startup green on
// off-white, Montserrat ExtraBold headings. The cast and the season outline
// come from `mission-silicon/data/season.json`, the Pilot from
// `data/pilot.json`, and the modules from `mission-silicon/CURRICULUM.md`.
// The screenshots are of the web Pilot.
const MS_ALT = "Mission Silicon: the name in heavy slate type on off-white, beside the game's whiteboard of servers with traffic running through it.";
const MS_DESC = "Mission Silicon, a Dunder Quest game in the making: you're a non-technical founder launching an AI startup, "
  + "and your AI coding assistant is very sure of itself. Learn how web apps are built by steering one. "
  + "The Pilot is free to play in your browser, voiced, on a phone or a computer; the rest of the season is being rebuilt.";

/** The same tags for Mission Silicon, in mission-silicon/, whose web app
 * is built to mission-silicon/play/index.html. */
function tagMissionSiliconPage(index: string): void {
  const desc = "Play the Pilot of Mission Silicon, the Dunder Quest game about building apps with AI, right in your browser.";
  tagGamePage(index, "Play Mission Silicon · Dunder Quest", desc, "mission-silicon/play/", "mission-silicon.png", MS_ALT);
}

/** Module number (or "capstone") to its title, from the curriculum's headings. */
function msModules(): Record<string, string> {
  const text = read(join(MISSION, "CURRICULUM.md"));
  const out: Record<string, string> = {};
  for (const m of text.matchAll(/^## Module (\d+): (.+)$/gm)) out[m[1]] = m[2].trim();
  const capstone = text.match(/^## Capstone: (.+)$/m);
  if (capstone) out.capstone = capstone[1].trim();
  return out;
}

function buildMissionSilicon(prefix: string): string {
  const data = JSON.parse(read(join(MISSION, "data", "season.json")));
  const img = `${prefix}static/img/mission-silicon/`;
  // Only the Pilot is playable while the season is rebuilt to teach first.
  const built = new Map([[1, JSON.parse(read(join(MISSION, "data", "pilot.json")))]]);
  const modules = msModules();
  const cast = Object.values(data.cast).map((p: Json) =>
    `<li><b>${esc(p.full)}</b> <span>${esc(p.role)}</span></li>`).join("");
  const season = data.outline.map((entry: Json) => {
    const names = entry.modules.map((m: Json) => {
      const key = String(m);
      const title = modules[key] ?? "";
      const label = key === "capstone" ? "The whole picture" : `Module ${key}`;
      return title ? `${label}: ${esc(title.split(",")[0].split(":")[0])}` : label;
    });
    const playable = built.has(entry.id);
    const state = playable ? '<a class="ms-tag" href="play/">Play it</a>' : '<span class="ms-tag ms-soon">Being rebuilt</span>';
    return `<li${playable ? " class=ms-live" : ""}><span class="ms-num">${entry.id}</span>`
      + `<b>${esc(entry.title)}</b> ${state}<small>${names.join("; ")}</small></li>`;
  });
  const steps = [
    ["planning.png", "Make the real decisions",
      "Every episode turns on a few architecture decisions you'll face building anything with AI: where the app runs, what goes "
      + "on the phone and what stays on the server, whether to build or rent. The house argues each one out while the whiteboard "
      + "checks it against what the app needs, then everyone turns to you. Pick wrong and you see it go wrong, and why it'd be right elsewhere."],
    ["trouble.png", "Read the AI's plan",
      "Aleister Jr., your AI teammate, writes up a plan in real tools: Next.js, Supabase, Vercel. Put every line on the map of "
      + "your app. The one you can't place is the one to question."],
    ["postmortem.png", "Watch it go live",
      "Two hundred diners try it on their phones and laptops, and every result traces back to a decision you made. Then the "
      + "team writes it down: what you chose, why, what it cost, and when to look again."],
  ];
  const stepHtml = steps.map(([shot, h, p]) =>
    `<li><img src="${img}${shot}" alt="" width="720" height="405" loading="lazy"><h3>${esc(h)}</h3><p>${esc(p)}</p></li>`).join("");
  const body = `
<section class="ms-hero">
  <p class="ms-kicker">a dunder_quest game · being rebuilt to teach first</p>
  <h1>Mission Silicon</h1>
  <p class="ms-lede">You've moved into an incubator house to launch an AI startup, and you can't code. Your AI coding assistant can. It's fast, tireless, and very sure of itself. Learn enough about how apps are built (servers, databases, caches, scaling, security, the AI itself) to tell it what to build, and when to say no.</p>
  <p class="ms-actions"><a class="ms-btn" href="play/">Play the Pilot</a></p>
  <p class="ms-fine">Episode 1, voiced by the cast. Works on a phone or a computer. The rest of the season is being rebuilt.</p>
  <p class="ms-fine">Or try <a href="lab/">the Lab</a>, a proof of concept: your AI says the app is done, and you find out whether it is.</p>
  <img class="ms-shot" src="${img}live.png" alt="Thursday in the Pilot: two hundred diners as squares by device, iPhones, Android phones and laptops, beside a clock, a meter against the nine-in-ten goal, and the 4:40 iPhone bug and its fix" width="720" height="405">
</section>
<section class="ms-section" id="how">
  <h2>How it plays</h2>
  <ol class="ms-steps">${stepHtml}</ol>
</section>
<section class="ms-section" id="house">
  <h2>The house</h2>
  <p>Forkcast is an AI dinner concierge: tell it what kind of evening you want, and it finds the restaurant and books the table. You're its founder. These are the people (and the machine) around you.</p>
  <ul class="ms-cast">${cast}</ul>
</section>
<section class="ms-section" id="season">
  <h2>The season</h2>
  <p>The season runs from a landing page to a company in several cities, and every episode teaches a piece of how web apps are built. You never write code: you learn enough to direct an AI that does. It's being rebuilt to teach first, one episode at a time, starting with the Pilot.</p>
  <ol class="ms-season">${season.join("")}</ol>
</section>
`;
  return msPage(body, prefix);
}

function msPage(body: string, prefix: string): string {
  const title = "Mission Silicon · Dunder Quest";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${esc(MS_DESC)}">
${headTags(title, MS_DESC, "mission-silicon/", "mission-silicon.png", MS_ALT)}
<link rel="icon" href="${prefix}static/img/mission-silicon/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&family=Montserrat:wght@800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="${prefix}static/mission-silicon.css">
</head>
<body class="ms">
<a class="skip" href="#main">Skip to content</a>
<header class="ms-bar">
  <a class="ms-brand" href="./">Mission Silicon</a>
  <nav aria-label="Mission Silicon"><a href="#how">How it plays</a><a href="#season">The season</a><a href="${prefix}">All games</a></nav>
  <a class="ms-btn ms-btn-small" href="play/">Play</a>
</header>
<main id="main">
${body}
</main>
<footer class="ms-foot">
  <p>Mission Silicon. One incubator house, one AI teammate, and how apps get built.</p>
  <p><a href="play/">Play in your browser</a> · <a href="${prefix}curb/">Curb Your Oxidation, the Rust game</a> · <a href="${prefix}${QUEST_PAGE}">Dunder Quest, the Python game</a> · <a href="${prefix}flatmates/">Flatmates.js, the JavaScript game</a> · <a href="${REPO}/tree/main/games/mission-silicon">Source on GitHub</a></p>
</footer>
</body>
</html>
`;
}

function main(): void {
  const args = process.argv.slice(2);
  const tag: Record<string, (index: string) => void> = {
    "--mission-silicon": tagMissionSiliconPage, "--play": tagPlayPage,
    "--flatmates": tagFlatmatesPage, "--curb": tagCurbPage,
  };
  if (args[0] in tag) {
    tag[args[0]](args[1]);
    return;
  }
  const out = resolve(args[0] ?? join(ROOT, "build", "site"));
  mkdirSync(out, { recursive: true });
  const bank = JSON.parse(read(join(QUEST, "data", "lessons.json")));

  const statics = join(out, "static");
  if (existsSync(statics)) rmSync(statics, { recursive: true });
  cpSync(join(SITE, "static"), statics, { recursive: true });
  copyFileSync(join(SITE, "favicon.ico"), join(out, "favicon.ico")); // painted by tools/make_og.py
  for (const [name, src] of Object.entries(IMAGES)) copyFileSync(join(QUEST, src), join(statics, "img", name));
  mkdirSync(join(statics, "img", "shots"), { recursive: true });
  for (const name of [...SHOTS, ...STAGES.map((s) => s.shot)]) {
    copyFileSync(join(QUEST, "tests", "shots", name), join(statics, "img", "shots", name));
  }
  mkdirSync(join(statics, "fonts"), { recursive: true });
  for (const [name, src] of Object.entries(FONTS)) copyFileSync(join(QUEST, src), join(statics, "fonts", name));
  copyFileSync(join(CURB, "assets", "fonts", "LibreFranklin.ttf"), join(statics, "fonts", "LibreFranklin.ttf"));
  for (const [game, folder] of [[CURB, "curb"], [FLATMATES, "flatmates"]]) { // their icons, for the brand kit
    copyFileSync(join(game, "icon.svg"), join(statics, "img", folder, "icon.svg"));
  }

  write(join(out, "index.html"), buildSplash(""));
  write(join(out, QUEST_PAGE, "index.html"), buildHome(bank, "../"));
  write(join(out, "lessons", "index.html"), buildLessonsIndex(bank, "../"));
  for (const stage of STAGES) {
    write(join(out, "lessons", stage.slug, "index.html"), buildLesson(stage, bank[String(stage.id)], "../../"));
  }
  write(join(out, "guide", "index.html"), buildGuide("../"));
  write(join(out, "brand", "index.html"), buildBrand("../"));
  const brand: [string, (prefix: string) => string][] = [["identity", buildBrandIdentity], ["art", buildBrandArt],
    ["curb", buildBrandCurb], ["flatmates", buildBrandFlatmates], ["trailers", buildBrandTrailers],
    ["youtube", buildBrandYoutube], ["launch", buildBrandLaunch]];
  for (const [slug, build] of brand) write(join(out, "brand", slug, "index.html"), build("../../"));
  write(join(out, "flatmates", "index.html"), buildFlatmates("../"));
  write(join(out, "curb", "index.html"), buildCurb("../"));
  write(join(out, "mission-silicon", "index.html"), buildMissionSilicon("../"));
  write(join(out, "404.html"), build404("/"));
  write(join(out, "_redirects"), Object.entries(OLD_SLUGS).map(([old, slug]) =>
    `/lessons/${old}/ /lessons/${slug}/ 301\n/lessons/${old} /lessons/${slug}/ 301\n`).join(""));
  console.log(`site built into ${out}`);
}

main();
