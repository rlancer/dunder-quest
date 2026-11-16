// Holds the in-game SQL engine to the real SQLite (bun's built-in one).
//
// tests/replay.gd runs every beat's solution, every lesson card and every
// query the chips on a page can spell through the game's engine and writes
// what it got to tests/out/queries.jsonl. This loads the same case tables
// into SQLite, runs the same SQL text, and demands the same answer:
//
//   - the same columns, in the same order, with the same names;
//   - the same rows (in the same order when there's an ORDER BY, give or
//     take rows that tie on what they're sorted by);
//   - the same error text when it doesn't run;
//   - and where the game is stricter than SQLite on purpose (a bare column
//     beside an aggregate, kind "strict"), that SQLite really does accept it.
//
//   bun tests/verify_sql.ts            # after replay.gd has written the file
//
// Prints SQL result=ok, or the queries that differ.

import { Database } from "bun:sqlite";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

const ROOT = dirname(import.meta.dir);
const QUERIES = join(ROOT, "tests", "out", "queries.jsonl");

type Table = { columns: [string, string][]; rows: unknown[][] };
type Line = {
  case: number; beat: string; role: string; db: string; sql: string; ok: boolean;
  columns?: string[]; rows?: unknown[][]; ordered?: boolean; keys?: unknown[][]; limited?: boolean;
  error?: string; kind?: string;
};

if (!existsSync(QUERIES)) {
  console.log("SQL result=FAIL no tests/out/queries.jsonl: run tests/replay.gd first");
  process.exit(1);
}

const story = JSON.parse(readFileSync(join(ROOT, "data", "cases.json"), "utf8"));

function build(tables: Record<string, Table>): Database {
  const db = new Database(":memory:");
  for (const [name, table] of Object.entries(tables)) {
    db.run(`CREATE TABLE ${name} (${table.columns.map(([c, t]) => `${c} ${t}`).join(", ")})`);
    const insert = db.prepare(`INSERT INTO ${name} VALUES (${table.columns.map(() => "?").join(", ")})`);
    for (const row of table.rows) insert.run(...(row as any[]));
  }
  return db;
}

const dbs = new Map<string, Database>();
for (const c of story.cases) dbs.set(`case:${c.id}`, build(c.tables));
for (const [id, card] of Object.entries<any>(story.cards)) if (card.tables) dbs.set(`card:${id}`, build(card.tables));

// SQLite words this one two ways, depending on where it catches it.
const normal = (msg: string) => msg.replace(/^misuse of aggregate(?: function|:) /, "misuse of aggregate ");
const same = (a: unknown, b: unknown) =>
  typeof a === "number" && typeof b === "number" ? Math.abs(a - b) < 1e-9 : a === b;
const sameRow = (a: unknown[], b: unknown[]) => a.length === b.length && a.every((v, i) => same(v, b[i]));
const key = (row: unknown[]) => JSON.stringify(row);

function sameBag(a: unknown[][], b: unknown[][]): boolean {
  if (a.length !== b.length) return false;
  const left = a.map(key).sort();
  const right = b.map(key).sort();
  return left.every((v, i) => v === right[i]);
}

// Rows in the same order, except that rows the engine sorted on equal keys
// may come back from SQLite in either order.
function sameOrder(engine: unknown[][], keys: unknown[][], sqlite: unknown[][]): boolean {
  if (engine.length !== sqlite.length) return false;
  let start = 0;
  while (start < engine.length) {
    let end = start + 1;
    while (end < engine.length && key(keys[end]) === key(keys[start])) end++;
    if (!sameBag(engine.slice(start, end), sqlite.slice(start, end))) return false;
    start = end;
  }
  return true;
}

const lines: Line[] = readFileSync(QUERIES, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const fails: string[] = [];
const counts = { ok: 0, error: 0, strict: 0, solution: 0, card: 0 };
const solved = new Set<string>();

for (const line of lines) {
  const db = dbs.get(line.db);
  const where = `${line.beat} [${line.sql.replace(/\n/g, " ")}]`;
  if (!db) {
    fails.push(`${where}: no database ${line.db}`);
    continue;
  }
  let columns: string[] = [];
  let rows: unknown[][] = [];
  let error = "";
  try {
    const statement = db.query(line.sql);
    columns = statement.columnNames;
    rows = statement.values() as unknown[][];
  } catch (e: any) {
    error = String(e.message);
  }
  if (!line.ok) {
    if (line.kind === "strict") {
      counts.strict++;
      if (error) fails.push(`${where}: the game refuses this as non-standard, but SQLite fails too: ${error}`);
    } else {
      counts.error++;
      if (!error) fails.push(`${where}: the game says "${line.error}", SQLite runs it`);
      else if (normal(error) !== normal(line.error!)) fails.push(`${where}: the game says "${line.error}", SQLite says "${error}"`);
    }
    continue;
  }
  counts.ok++;
  if (error) {
    fails.push(`${where}: the game runs it, SQLite says "${error}"`);
    continue;
  }
  if (key(columns) !== key(line.columns!)) {
    fails.push(`${where}: columns ${key(line.columns!)} in the game, ${key(columns)} in SQLite`);
    continue;
  }
  const engine = line.rows!;
  // Numbers that are whole come back from JSON as the same number either way.
  const tidy = (table: unknown[][]) => table.map((r) => r.map((v) => (typeof v === "number" ? Number(v.toFixed(9)) : v)));
  const a = tidy(engine);
  const b = tidy(rows);
  let match: boolean;
  if (line.ordered && line.limited) {
    // A LIMIT can cut through a tie; then only the rows before the tie, and the count, are fixed.
    const keys = line.keys!;
    let cut = a.length;
    while (cut > 0 && key(keys[cut - 1]) === key(keys[a.length - 1])) cut--;
    match = a.length === b.length && sameOrder(a.slice(0, cut), keys.slice(0, cut), b.slice(0, cut));
  } else if (line.ordered) {
    match = sameOrder(a, line.keys!, b);
  } else if (line.limited) {
    // LIMIT with no ORDER BY: which rows come back is the database's choice.
    match = a.length === b.length;
  } else {
    match = sameBag(a, b);
  }
  if (!match) fails.push(`${where}: rows differ\n    game:   ${key(a)}\n    sqlite: ${key(b)}`);
  if (line.role === "solution") {
    counts.solution++;
    solved.add(line.beat);
    if (rows.length === 0) fails.push(`${where}: the solution returns nothing`);
  }
  if (line.role === "card") counts.card++;
}

for (const c of story.cases) for (const beat of c.beats) if (!solved.has(beat.id)) fails.push(`${beat.id}: no solution was replayed`);

const version = (new Database(":memory:").query("select sqlite_version() as v").get() as any).v;
if (fails.length) {
  console.log(`SQL result=FAIL (${fails.length} of ${lines.length} differ from SQLite ${version})`);
  for (const f of fails.slice(0, 40)) console.log("  " + f);
  process.exit(1);
}
console.log(
  `SQL result=ok  SQLite ${version} agrees on ${lines.length} queries: ${counts.ok} answers, ${counts.error} errors, ` +
    `${counts.strict} it accepts that the game refuses on purpose; ${counts.solution} solutions, ${counts.card} cards`,
);
