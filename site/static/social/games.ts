// Every game the social layer knows, and how to read its save.
//
// The browser (play.ts and the other pages) and the Worker (deploy/src) both import this file,
// so a save is read, merged and scored the same way on both sides. Each game
// keeps its progress in one JSON file in user:// (see the game's
// core/progress.gd, or Dunder Quest's common/game_progression.gd); its Social
// autoload hands that text to the page, and the page sends it here.

/** A level: its id, its name, its lesson, and (for games with a collectible) how many it holds. */
export interface Level {
  id: number;
  name: string;
  lesson: string;
  max?: number;
}

/** What the site and the Worker know about a game. */
export interface GameDef {
  name: string;
  short: string;
  lang: string;
  page: string;
  play: string;
  og: string;
  unit: [string, string];
  accent: string;
  ink: string;
  tag: string;
  best: "time" | "tries";
  collectible?: [string, string];
  levels: Level[];
}

export type GameKey = "curb" | "dunder-quest" | "flatmates" | "prince" | "lieutenant" | "greedy" | "shell" | "nothing";

/** One entry per game: its name, the language it teaches, where it lives on
 * the site, the levels in the order they're played, and what it calls them. */
export const GAMES: Record<GameKey, GameDef> = {
  curb: {
    name: "Curb Your Oxidation",
    short: "Curb",
    lang: "Rust",
    page: "/curb/",
    play: "/curb/play/",
    og: "curb.png",
    unit: ["scene", "scenes"],
    accent: "#fad41c",
    ink: "#000000",
    tag: "#LearnRust",
    // Fewest tries is the tiebreak: the game counts a try per plan run past Sharon.
    best: "tries",
    levels: [
      { id: 1, name: "The Second Latte", lesson: "let and mut" },
      { id: 2, name: "The Sample Abuser", lesson: "Functions" },
      { id: 3, name: "The Regift", lesson: "Ownership and moves" },
      { id: 4, name: "The Lawnmower", lesson: "Borrowing with &" },
      { id: 5, name: "The Last Shrimp", lesson: "&mut: one at a time" },
      { id: 6, name: "The Mulligan", lesson: "Structs and methods" },
      { id: 7, name: "The Maybe", lesson: "Enums, match and Option" },
      { id: 8, name: "The Receipt", lesson: "Result and ?" },
      { id: 9, name: "Stop and Chat", lesson: "Vec and for loops" },
      { id: 10, name: "The Houseguest", lesson: "Lifetimes" },
    ],
  },
  "dunder-quest": {
    name: "Dunder Quest",
    short: "Dunder Quest",
    lang: "Python",
    page: "/dunder-quest/",
    play: "/play/",
    og: "home.png",
    unit: ["stage", "stages"],
    accent: "#f2b544",
    ink: "#15122a",
    tag: "#LearnPython",
    best: "time",
    collectible: ["emberseed", "emberseeds"],
    levels: [
      { id: 1, name: "Shrubbery Wood", lesson: "Lists & indexing", max: 8 },
      { id: 2, name: "The Cheese Shoppe", lesson: "Dictionaries & hashing", max: 4 },
      { id: 3, name: "Cave of the Bunny", lesson: "Loops & range", max: 7 },
      { id: 4, name: "Ministry of Walks", lesson: "Booleans & conditions", max: 6 },
      { id: 5, name: "Bridge of Peril", lesson: "Functions & return", max: 6 },
      { id: 6, name: "Castle Aargh", lesson: "Comprehensions", max: 7 },
    ],
  },
  flatmates: {
    name: "Flatmates.js",
    short: "Flatmates.js",
    lang: "JavaScript",
    page: "/flatmates/",
    play: "/flatmates/play/",
    og: "flatmates.png",
    unit: ["stage", "stages"],
    accent: "#f7de1f",
    ink: "#17161f",
    tag: "#LearnJavaScript",
    best: "time",
    collectible: ["biscuit", "biscuits"],
    levels: [
      { id: 1, name: "Flat 5B", lesson: "Calling methods", max: 6 },
      { id: 2, name: "Croydon Credit", lesson: "Variables & strings", max: 6 },
      { id: 3, name: "Band Practice", lesson: "Loops", max: 6 },
      { id: 4, name: "The Stag Do", lesson: "Events & callbacks", max: 6 },
      { id: 5, name: "East Croydon", lesson: "Timers & the event loop", max: 6 },
      { id: 6, name: "The Wedding", lesson: "async & await", max: 6 },
    ],
  },
  prince: {
    name: "Prince of Versions",
    short: "Prince of Versions",
    lang: "Git",
    page: "/prince/",
    play: "/prince/play/",
    og: "prince.png",
    unit: ["room", "rooms"],
    accent: "#e9b949",
    ink: "#171c33",
    tag: "#LearnGit",
    best: "time",
    levels: [
      { id: 1, name: "The Hall of Seals", lesson: "git commit" },
      { id: 2, name: "The Vizier's Seal", lesson: "git reset" },
      { id: 3, name: "The Princess's Bridge", lesson: "git revert" },
      { id: 4, name: "Two Doors", lesson: "git branch and merge" },
      { id: 5, name: "The Vizier's Gate", lesson: "Merge conflicts" },
    ],
  },
  lieutenant: {
    name: "Just One More JOIN",
    short: "Just One More JOIN",
    lang: "SQL",
    page: "/lieutenant/",
    play: "/lieutenant/play/",
    og: "lieutenant.png",
    unit: ["case", "cases"],
    accent: "#f08033",
    ink: "#211a20",
    tag: "#LearnSQL",
    best: "tries",
    levels: [
      { id: 1, name: "Select Company", lesson: "SELECT, FROM, WHERE" },
      { id: 2, name: "Out of Order", lesson: "LIKE, AND, OR, ORDER BY, LIMIT" },
      { id: 3, name: "Inner Circle", lesson: "JOIN ... ON" },
      { id: 4, name: "Group Therapy", lesson: "COUNT, GROUP BY, HAVING" },
      { id: 5, name: "Left for Dead", lesson: "LEFT JOIN, IS NULL" },
    ],
  },
  greedy: {
    name: "The Good, the Bad and the Greedy",
    short: "Good, Bad & Greedy",
    lang: "Regex",
    page: "/greedy/",
    play: "/greedy/play/",
    og: "greedy.png",
    unit: ["job", "jobs"],
    accent: "#e8a13a",
    ink: "#2a1710",
    tag: "#LearnRegex",
    // Fewest draws is the tiebreak: the game counts a try each time a poster is drawn.
    best: "tries",
    // A star for every poster written in par, the fewest chips it can be done in.
    collectible: ["star", "stars"],
    levels: [
      { id: 1, name: "A Town Called Hobson", lesson: "Letters, the dot, [sets] and \\d", max: 4 },
      { id: 2, name: "The Toll Gate", lesson: "Anchors ^ and $, and \\b", max: 4 },
      { id: 3, name: "Beans", lesson: "Quantifiers +, *, ? and {3}", max: 4 },
      { id: 4, name: "The Greedy and the Lazy", lesson: "Greedy .*, lazy .*?, ( ) and |", max: 4 },
      { id: 5, name: "Showdown at Backslash Ridge", lesson: "Everything at once, and \\1", max: 3 },
    ],
  },
  shell: {
    name: "Yes, Shell!",
    short: "Yes, Shell!",
    lang: "Bash",
    page: "/shell/",
    play: "/shell/play/",
    og: "shell.png",
    unit: ["shift", "shifts"],
    accent: "#f59e2e",
    ink: "#12161c",
    tag: "#LearnBash",
    // Fewest fires is the tiebreak: the game counts a try each time a line is fired.
    best: "tries",
    // A star for every ticket sent in par, the fewest chips it can be done in.
    collectible: ["star", "stars"],
    levels: [
      { id: 1, name: "Family Meal", lesson: "Commands: ls, cat, head and wc", max: 4 },
      { id: 2, name: "The Rail", lesson: "grep, and -v, -i and -c", max: 4 },
      { id: 3, name: "The Pass", lesson: "The pipe: |", max: 4 },
      { id: 4, name: "Mise en Place", lesson: "sort and uniq", max: 4 },
      { id: 5, name: "The Critic", lesson: "cut, tr, > and a five-command line", max: 4 },
    ],
  },
  nothing: {
    name: "A Game About Nothing",
    short: "Nothing",
    lang: "HTTP",
    page: "/nothing/",
    play: "/nothing/play/",
    og: "nothing.png",
    unit: ["episode", "episodes"],
    accent: "#e8b03a",
    ink: "#1c1421",
    tag: "#LearnHTTP",
    // Fewest takes is the tiebreak: the game counts a try each time a slip is sent.
    best: "tries",
    // A star for every scene done at par, with the fewest cards it can be.
    collectible: ["star", "stars"],
    levels: [
      { id: 1, name: "The Order", lesson: "Requests: GET and POST", max: 4 },
      { id: 2, name: "The Counter", lesson: "Headers and JSON bodies", max: 4 },
      { id: 3, name: "The Duplicate", lesson: "PUT, PATCH and DELETE", max: 4 },
      { id: 4, name: "The Mail", lesson: "Versions: ETags and If-Match", max: 4 },
      { id: 5, name: "The Table Read", lesson: "Tokens: 401 and 403", max: 4 },
    ],
  },
};


/** Game keys in the order the site shows them (Curb leads, as on the home page). */
export const ORDER: GameKey[] = ["curb", "dunder-quest", "flatmates", "prince", "lieutenant", "greedy", "shell", "nothing"];

/** XP: a level is worth 100, finishing a game 400 more, a collectible 10. */
export const XP = { level: 100, complete: 400, collectible: 10 };

/**
 * What a piece of feedback is about, in the order the form offers them: the
 * key the server stores, and the words the form and the admin page show.
 */
export const FEEDBACK_KINDS = {
  bug: "Something's broken",
  stuck: "I got stuck",
  idea: "An idea",
  praise: "I liked something",
  other: "Something else",
};

export type FeedbackKind = keyof typeof FEEDBACK_KINDS;

/** The longest feedback message the server takes, in characters. */
export const FEEDBACK_MAX = 4000;

/** The biggest save the server takes, in characters. Real saves are under 2 KB. */
export const MAX_SAVE = 16000;

/** {level id: number}, keyed by the id as a string, as the saves keep it. */
export type Numbers = Record<string, number>;

/** Dunder Quest's save: every stage keyed, false and 0 included. */
export interface DunderSave {
  current_stage_id: number;
  unlocked: Record<string, boolean>;
  cleared: Record<string, boolean>;
  best_seeds: Numbers;
  best_times: Numbers;
  total_deaths: number;
  scrolls: string[];
}

export interface FlatmatesSave {
  current_stage: number;
  cleared: number[];
  biscuits: Numbers;
  times: Numbers;
  thoughts: string[];
  falls: number;
}

export interface CurbSave {
  current_scene: number;
  cleared: number[];
  tries: Numbers;
  cards: string[];
}

export interface LieutenantSave {
  current_case: number;
  cleared: number[];
  tries: Numbers;
  cards: string[];
}

/** The regex, shell and HTTP games: the Lieutenant's shape plus stars, with their own name for the level to carry on from. */
export interface StarSave {
  current_job?: number;
  current_shift?: number;
  current_episode?: number;
  cleared: number[];
  tries: Numbers;
  stars: Numbers;
  cards: string[];
}

/** Prince of Versions keeps {room: best seconds}. */
export interface PrinceSave {
  cleared: Numbers;
}

export type Save = DunderSave | FlatmatesSave | CurbSave | LieutenantSave | StarSave | PrinceSave;

/** What a save adds up to (see summarize()). */
export interface Summary {
  game: string;
  cleared: number[];
  count: number;
  total: number;
  complete: boolean;
  time: number;
  tries: number;
  collected: number;
  collectMax: number;
  xp: number;
}

type StarGame = "greedy" | "shell" | "nothing";
type CurrentKey = "current_job" | "current_shift" | "current_episode";

/** Where the games that keep a star count per level keep the level to carry on from. */
const CURRENT: Record<StarGame, CurrentKey> = { greedy: "current_job", shell: "current_shift", nothing: "current_episode" };

const isObj = (v: unknown): v is Record<string, unknown> => v !== null && typeof v === "object" && !Array.isArray(v);
const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : Number.parseFloat(v as string));

/** The ids of a game's levels, as numbers. */
function levelIds(game: GameKey): number[] {
  return GAMES[game].levels.map((l) => l.id);
}

/** A set of level ids from an array of ids, or from an {id: true} map. */
function idSet(game: GameKey, value: unknown): Set<number> {
  const valid = new Set(levelIds(game));
  const out = new Set<number>();
  if (Array.isArray(value)) {
    for (const v of value) if (valid.has(Math.trunc(num(v)))) out.add(Math.trunc(num(v)));
  } else if (isObj(value)) {
    for (const [k, v] of Object.entries(value)) if (v && valid.has(Math.trunc(num(k)))) out.add(Math.trunc(num(k)));
  }
  return out;
}

/** {id: number} keeping only real levels and finite values above zero. */
function idNumbers(game: GameKey, value: unknown, integer = false): Numbers {
  const valid = new Set(levelIds(game));
  const out: Numbers = {};
  if (!isObj(value)) return out;
  for (const [k, v] of Object.entries(value)) {
    const id = Math.trunc(num(k));
    let n = num(v);
    if (!valid.has(id) || !Number.isFinite(n) || n <= 0 || n > 1e7) continue;
    if (integer) n = Math.round(n);
    out[id] = n;
  }
  return out;
}

/** Best of two {id: n} maps: the lower value (a time or a try count) or the higher (a count). */
function bestOf(a: Numbers, b: Numbers, lower: boolean): Numbers {
  const out = { ...a };
  for (const [k, v] of Object.entries(b)) {
    if (!(k in out)) out[k] = v;
    else out[k] = lower ? Math.min(out[k], v) : Math.max(out[k], v);
  }
  return out;
}

function strings(value: unknown, limit = 200): string[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((v): v is string => typeof v === "string" && v.length <= 80))].slice(0, limit);
}

const keyed = (obj: Numbers): Numbers => Object.fromEntries(Object.entries(obj).map(([k, v]) => [String(k), v]));
const sorted = (set: Set<number>): number[] => [...set].sort((a, b) => a - b);
const clampId = (game: GameKey, v: unknown, fallback = 1): number => {
  const n = Math.trunc(num(v));
  const ids = levelIds(game);
  return ids.includes(n) ? n : fallback;
};

/**
 * A save in a known shape: only real levels, only sane numbers, nothing
 * else. Every save the server stores, and every save the page hands back
 * to a game, goes through here first, so a game never loads a field it
 * doesn't expect. Returns null for anything that isn't a save at all.
 */
export function normalize(game: string, raw: unknown): Save | null {
  let save = raw;
  if (typeof raw === "string") {
    if (raw.length > MAX_SAVE) return null;
    try {
      save = JSON.parse(raw);
    } catch {
      return null;
    }
  }
  if (!isObj(save) || !GAMES[game as GameKey]) return null;
  switch (game) {
    case "dunder-quest": {
      const cleared = idSet(game, save.cleared);
      const unlocked = idSet(game, save.unlocked);
      unlocked.add(1);
      for (const id of cleared) if (id + 1 <= levelIds(game).length) unlocked.add(id + 1);
      const seeds = idNumbers(game, save.best_seeds, true);
      for (const l of GAMES[game].levels) if (seeds[l.id] > l.max!) seeds[l.id] = l.max!;
      const times = idNumbers(game, save.best_times);
      // The game writes every stage, false and 0 included; so do we.
      const all = <T>(fn: (id: number) => T): Record<string, T> => Object.fromEntries(levelIds(game).map((id) => [String(id), fn(id)]));
      return {
        current_stage_id: clampId(game, save.current_stage_id),
        unlocked: all((id) => unlocked.has(id)),
        cleared: all((id) => cleared.has(id)),
        best_seeds: all((id) => seeds[id] ?? 0),
        best_times: all((id) => times[id] ?? 0),
        total_deaths: Math.max(0, Math.min(1e6, Math.trunc(num(save.total_deaths)) || 0)),
        scrolls: strings(save.scrolls),
      } satisfies DunderSave;
    }
    case "flatmates": {
      const biscuits = idNumbers(game, save.biscuits, true);
      for (const l of GAMES[game].levels) if (biscuits[l.id] > l.max!) biscuits[l.id] = l.max!;
      return {
        current_stage: clampId(game, save.current_stage),
        cleared: sorted(idSet(game, save.cleared)),
        biscuits: keyed(biscuits),
        times: keyed(idNumbers(game, save.times)),
        thoughts: strings(save.thoughts),
        falls: Math.max(0, Math.min(1e6, Math.trunc(num(save.falls)) || 0)),
      } satisfies FlatmatesSave;
    }
    case "curb":
      return {
        current_scene: clampId(game, save.current_scene),
        cleared: sorted(idSet(game, save.cleared)),
        tries: keyed(idNumbers(game, save.tries, true)),
        cards: strings(save.cards),
      } satisfies CurbSave;
    case "lieutenant":
      return {
        current_case: clampId(game, save.current_case),
        cleared: sorted(idSet(game, save.cleared)),
        tries: keyed(idNumbers(game, save.tries, true)),
        cards: strings(save.cards),
      } satisfies LieutenantSave;
    case "greedy":
    case "shell":
    case "nothing": {
      // The Lieutenant's shape, plus a star count per job, capped at its posters.
      // (Yes, Shell! keeps the same save, with shifts for jobs, and A Game
      // About Nothing with episodes.)
      const at = CURRENT[game];
      const stars = idNumbers(game, save.stars, true);
      for (const l of GAMES[game].levels) if (stars[l.id] > l.max!) stars[l.id] = l.max!;
      return {
        [at]: clampId(game, save[at]),
        cleared: sorted(idSet(game, save.cleared)),
        tries: keyed(idNumbers(game, save.tries, true)),
        stars: keyed(stars),
        cards: strings(save.cards),
      } satisfies StarSave;
    }
    case "prince": {
      // Prince keeps {room: best seconds}; a room is cleared if it's there at all.
      const out: Numbers = {};
      const valid = new Set(levelIds(game));
      if (isObj(save.cleared)) {
        for (const [k, v] of Object.entries(save.cleared)) {
          const id = Math.trunc(num(k));
          const s = num(v);
          if (valid.has(id) && Number.isFinite(s) && s >= 0 && s < 1e7) out[String(id)] = s;
        }
      }
      return { cleared: out } satisfies PrinceSave;
    }
  }
  return null;
}

/**
 * Two saves of the same game made one, keeping the best of each: every level
 * cleared on either, the best time, the fewest tries, the most collectibles,
 * every lesson card read. Progress made on one device is never lost by
 * playing on another. Either side may be null.
 */
export function merge(game: string, a: unknown, b: unknown): Save | null {
  const x = a ? normalize(game, a) : null;
  const y = b ? normalize(game, b) : null;
  if (!x) return y;
  if (!y) return x;
  const ahead = summarize(game, y).count > summarize(game, x).count ? y : x;
  switch (game) {
    case "dunder-quest": {
      const [p, q, at] = [x, y, ahead] as DunderSave[];
      const or = (m: Record<string, boolean>, n: Record<string, boolean>) => Object.fromEntries(Object.keys(m).map((k) => [k, Boolean(m[k] || n[k])]));
      const nonzero = (m: Numbers) => Object.fromEntries(Object.entries(m).filter(([, v]) => v > 0));
      const times = bestOf(nonzero(p.best_times), nonzero(q.best_times), true);
      const seeds = bestOf(p.best_seeds, q.best_seeds, false);
      return normalize(game, {
        current_stage_id: at.current_stage_id,
        unlocked: or(p.unlocked, q.unlocked),
        cleared: or(p.cleared, q.cleared),
        best_seeds: seeds,
        best_times: times,
        total_deaths: Math.max(p.total_deaths, q.total_deaths),
        scrolls: [...p.scrolls, ...q.scrolls],
      });
    }
    case "flatmates": {
      const [p, q, at] = [x, y, ahead] as FlatmatesSave[];
      return normalize(game, {
        current_stage: at.current_stage,
        cleared: [...p.cleared, ...q.cleared],
        biscuits: bestOf(p.biscuits, q.biscuits, false),
        times: bestOf(p.times, q.times, true),
        thoughts: [...p.thoughts, ...q.thoughts],
        falls: Math.max(p.falls, q.falls),
      });
    }
    case "curb": {
      const [p, q, at] = [x, y, ahead] as CurbSave[];
      return normalize(game, {
        current_scene: at.current_scene,
        cleared: [...p.cleared, ...q.cleared],
        tries: bestOf(p.tries, q.tries, true),
        cards: [...p.cards, ...q.cards],
      });
    }
    case "lieutenant": {
      const [p, q, at] = [x, y, ahead] as LieutenantSave[];
      return normalize(game, {
        current_case: at.current_case,
        cleared: [...p.cleared, ...q.cleared],
        tries: bestOf(p.tries, q.tries, true),
        cards: [...p.cards, ...q.cards],
      });
    }
    case "greedy":
    case "shell":
    case "nothing": {
      const [p, q, at] = [x, y, ahead] as StarSave[];
      return normalize(game, {
        [CURRENT[game]]: at[CURRENT[game]],
        cleared: [...p.cleared, ...q.cleared],
        tries: bestOf(p.tries, q.tries, true),
        stars: bestOf(p.stars, q.stars, false),
        cards: [...p.cards, ...q.cards],
      });
    }
    case "prince": {
      const [p, q] = [x, y] as PrinceSave[];
      // A time of 0 means "cleared, untimed"; any real time beats it.
      const out = { ...p.cleared };
      for (const [k, v] of Object.entries(q.cleared)) {
        if (!(k in out) || out[k] <= 0) out[k] = v;
        else if (v > 0) out[k] = Math.min(out[k], v);
      }
      return normalize(game, { cleared: out });
    }
  }
  return x;
}

/**
 * What a save adds up to: which levels are cleared, whether the game is
 * finished, the total of the best times (or tries) over the cleared levels,
 * the collectibles, and the XP. The leaderboards rank on these.
 */
export function summarize(game: string, raw: unknown): Summary {
  const def = GAMES[game as GameKey];
  const save = raw ? normalize(game, raw) : null;
  const total = def.levels.length;
  const empty: Summary = { game, cleared: [], count: 0, total, complete: false, time: 0, tries: 0, collected: 0, collectMax: 0, xp: 0 };
  if (!save) return empty;
  let cleared: number[] = [];
  let time = 0;
  let tries = 0;
  let collected = 0;
  switch (game) {
    case "dunder-quest": {
      const s = save as DunderSave;
      cleared = levelIds(game).filter((id) => s.cleared[String(id)]);
      for (const id of cleared) time += s.best_times[String(id)] || 0;
      for (const v of Object.values(s.best_seeds)) collected += v;
      break;
    }
    case "flatmates": {
      const s = save as FlatmatesSave;
      cleared = s.cleared;
      for (const id of cleared) time += s.times[String(id)] || 0;
      for (const v of Object.values(s.biscuits)) collected += v;
      break;
    }
    case "curb":
    case "lieutenant": {
      const s = save as CurbSave | LieutenantSave;
      cleared = s.cleared;
      for (const id of cleared) tries += s.tries[String(id)] || 0;
      break;
    }
    case "greedy":
    case "shell":
    case "nothing": {
      const s = save as StarSave;
      cleared = s.cleared;
      for (const id of cleared) tries += s.tries[String(id)] || 0;
      for (const v of Object.values(s.stars)) collected += v;
      break;
    }
    case "prince": {
      const s = save as PrinceSave;
      cleared = Object.keys(s.cleared).map(Number).sort((a, b) => a - b);
      for (const id of cleared) time += s.cleared[String(id)] || 0;
      break;
    }
  }
  const collectMax = def.collectible ? def.levels.reduce((n, l) => n + (l.max || 0), 0) : 0;
  const count = cleared.length;
  const complete = count === total;
  const xp = count * XP.level + (complete ? XP.complete : 0) + collected * XP.collectible;
  return { game, cleared, count, total, complete, time: Math.round(time * 10) / 10, tries, collected, collectMax, xp };
}

/** Total XP and levels across every game a player has a save for. */
export function overall(summaries: Iterable<Pick<Summary, "xp" | "count" | "complete">>): { xp: number; count: number; total: number; complete: number } {
  let xp = 0;
  let count = 0;
  let complete = 0;
  for (const s of summaries) {
    xp += s.xp;
    count += s.count;
    if (s.complete) complete += 1;
  }
  const total = ORDER.reduce((n, g) => n + GAMES[g].levels.length, 0);
  return { xp, count, total, complete };
}

/** "3:07" or "1:02:45" for a number of seconds. */
export function formatTime(seconds: number): string {
  const s = Math.round(seconds);
  if (!s) return "";
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = String(s % 60).padStart(2, "0");
  return h ? `${h}:${String(m).padStart(2, "0")}:${r}` : `${m}:${r}`;
}

/** The line a leaderboard shows under a player's progress in one game. */
export function bestLine(game: string, s: Pick<Summary, "count" | "tries" | "time">): string {
  const def = GAMES[game as GameKey];
  if (!s.count) return "";
  if (def.best === "tries") return s.tries ? `${s.tries} ${s.tries === 1 ? "try" : "tries"}` : "";
  return s.time ? formatTime(s.time) : "";
}

/** Fun default names, so a new player is on the boards without typing anything. */
const FIRST = ["Brave", "Plucky", "Rumpled", "Squinting", "Sleepy", "Dapper", "Curious", "Peckish", "Nimble", "Gallant",
  "Jaunty", "Wily", "Earnest", "Dashing", "Humble", "Mighty", "Sly", "Valiant", "Zesty", "Bold"];
const SECOND = ["Squire", "Rustacean", "Pythonista", "Flatmate", "Lieutenant", "Prince", "Coder", "Hacker", "Knight",
  "Detective", "Enchanter", "Committer", "Borrower", "Debugger", "Scribe", "Wizard", "Basset", "Merger", "Shrubber", "Joiner", "Deputy", "Wrangler", "Expediter", "Saucier"];

export function randomName(rand: () => number = Math.random): string {
  const pick = (list: string[]) => list[Math.floor(rand() * list.length)];
  return `${pick(FIRST)} ${pick(SECOND)} ${Math.floor(rand() * 900) + 100}`;
}

/** A display name made safe: trimmed, collapsed, 2 to 32 characters, no control characters. */
export function cleanName(name: unknown): string {
  if (typeof name !== "string") return "";
  const out = name.normalize("NFKC").replace(/[\p{C}<>]/gu, "").replace(/\s+/g, " ").trim();
  return out.length >= 2 && out.length <= 32 ? out : "";
}
