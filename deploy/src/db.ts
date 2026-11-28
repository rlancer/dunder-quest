// The social layer's tables. The Worker creates them itself on the first
// request an isolate serves (every statement is IF NOT EXISTS), so a new
// database, the dev one or production, needs no migration step: `cf deploy`
// provisions the database by name and this fills it in.

export interface Env {
  DB: D1Database;
  ASSETS: Fetcher;
  /** The OAuth client ID from Google Cloud Console. Empty turns Google sign-in off. */
  GOOGLE_CLIENT_ID?: string;
  /** Per-IP limit on writes that cost something: new players, screenshots, feedback. */
  WRITE_LIMITER?: RateLimit;
}

const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS players (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    google_sub TEXT UNIQUE,
    xp INTEGER NOT NULL DEFAULT 0,
    levels INTEGER NOT NULL DEFAULT 0,
    completed INTEGER NOT NULL DEFAULT 0,
    reached_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    hidden INTEGER NOT NULL DEFAULT 0
  )`,
  `CREATE INDEX IF NOT EXISTS players_board ON players (xp DESC, reached_at)`,
  `CREATE TABLE IF NOT EXISTS tokens (
    hash TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    used_at INTEGER NOT NULL
  )`,
  `CREATE INDEX IF NOT EXISTS tokens_player ON tokens (player_id)`,
  `CREATE TABLE IF NOT EXISTS saves (
    player_id TEXT NOT NULL,
    game TEXT NOT NULL,
    data TEXT NOT NULL,
    count INTEGER NOT NULL,
    complete INTEGER NOT NULL,
    time REAL NOT NULL,
    tries INTEGER NOT NULL,
    collected INTEGER NOT NULL,
    xp INTEGER NOT NULL,
    reached_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (player_id, game)
  )`,
  `CREATE INDEX IF NOT EXISTS saves_board ON saves (game, count DESC, reached_at)`,
  `CREATE TABLE IF NOT EXISTS certificates (
    id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    game TEXT NOT NULL,
    name TEXT NOT NULL,
    issued_at INTEGER NOT NULL,
    stats TEXT NOT NULL,
    png BLOB,
    png_design INTEGER,
    UNIQUE (player_id, game)
  )`,
  `CREATE TABLE IF NOT EXISTS shots (
    id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    game TEXT NOT NULL,
    caption TEXT NOT NULL,
    type TEXT NOT NULL,
    image BLOB NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    hidden INTEGER NOT NULL DEFAULT 0
  )`,
  `CREATE INDEX IF NOT EXISTS shots_player ON shots (player_id, created_at DESC)`,
  // What players tell us, from the feedback form on every play page and at
  // /feedback/. Read on the admin area's Feedback page (stats/), which binds
  // this database too. `game` is '' for the site in general.
  `CREATE TABLE IF NOT EXISTS feedback (
    id TEXT PRIMARY KEY,
    player_id TEXT,
    game TEXT NOT NULL,
    kind TEXT NOT NULL,
    rating INTEGER,
    message TEXT NOT NULL,
    contact TEXT NOT NULL DEFAULT '',
    page TEXT NOT NULL DEFAULT '',
    context TEXT NOT NULL DEFAULT '',
    agent TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'new'
  )`,
  `CREATE INDEX IF NOT EXISTS feedback_recent ON feedback (created_at DESC)`,
];

const ready = new WeakMap<D1Database, Promise<void>>();

/** Creates the tables once per isolate and database; later calls wait on the same promise. */
export function ensureSchema(db: D1Database): Promise<void> {
  let done = ready.get(db);
  if (!done) {
    done = db.batch(SCHEMA.map((sql) => db.prepare(sql))).then(() => undefined);
    done.catch(() => ready.delete(db));
    ready.set(db, done);
  }
  return done;
}

export type PlayerRow = {
  id: string;
  name: string;
  google_sub: string | null;
  xp: number;
  levels: number;
  completed: number;
  reached_at: number;
  created_at: number;
  updated_at: number;
  hidden: number;
};

export type SaveRow = {
  player_id: string;
  game: string;
  data: string;
  count: number;
  complete: number;
  time: number;
  tries: number;
  collected: number;
  xp: number;
  reached_at: number;
  updated_at: number;
};

export type CertRow = {
  id: string;
  player_id: string;
  game: string;
  name: string;
  issued_at: number;
  stats: string;
};

export type ShotRow = {
  id: string;
  player_id: string;
  game: string;
  caption: string;
  type: string;
  width: number;
  height: number;
  created_at: number;
};

/** Random ids from an alphabet with no look-alikes (no 0/o, 1/l/i). */
const ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz";

export function randomId(length = 10): string {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  let out = "";
  for (const b of bytes) out += ALPHABET[b % ALPHABET.length];
  return out;
}

export function now(): number {
  return Math.floor(Date.now() / 1000);
}
