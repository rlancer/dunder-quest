/**
 * Holds the game's regex to a second, independent engine.
 *
 * The game matches with Godot's RegEx, which is PCRE2. This runs every
 * pattern that tests/replay.gd wrote to tests/out/patterns.json (every row
 * of up to three chips on every poster's table, hundreds of longer ones,
 * every solution and every lesson card's demo) through JavaScript's RegExp,
 * and demands:
 *
 * - where the game's chip-reader refuses a pattern, JavaScript throws on it
 *   (except the one house rule, a \1 before its group has closed, which
 *   JavaScript accepts and the game doesn't: see regex/rx.gd);
 * - where the game accepts one, JavaScript compiles it, and on every line
 *   finds the same match and the same text in every group.
 *
 * So nothing the game teaches is true of one engine only.
 *
 *     godot --headless --path . --script res://tests/replay.gd
 *     bun tests/verify_regex.ts
 */

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

type Span = [number, number];
type Pattern = { pattern: string; error?: string; house?: boolean; rows?: (Span[] | null)[] };
type Poster = { id: string; lines: string[]; patterns: Pattern[] };

const here = dirname(fileURLToPath(import.meta.url));
const posters: Poster[] = JSON.parse(readFileSync(join(here, "out", "patterns.json"), "utf8"));

const problems: string[] = [];
let checked = 0;
let refused = 0;

function compile(pattern: string): RegExp | null {
  try {
    // "u" makes JavaScript as strict as it gets about what is a pattern;
    // "d" reports where each group matched.
    return new RegExp(pattern, "ud");
  } catch {
    return null;
  }
}

for (const poster of posters) {
  for (const entry of poster.patterns) {
    checked += 1;
    const regex = compile(entry.pattern);
    if (entry.error) {
      refused += 1;
      if (regex !== null && !entry.house) {
        problems.push(`${poster.id}: the game refuses ${entry.pattern} (${entry.error}) but JavaScript accepts it`);
      }
      continue;
    }
    if (regex === null) {
      problems.push(`${poster.id}: the game accepts ${entry.pattern} but JavaScript refuses it`);
      continue;
    }
    poster.lines.forEach((line, i) => {
      const mine = entry.rows![i];
      const match = regex.exec(line);
      const theirs: Span[] | null = match === null ? null
        : Array.from(match.indices!, (span) => (span === undefined ? [-1, -1] : [span[0], span[1]]) as Span);
      if (JSON.stringify(mine) !== JSON.stringify(theirs)) {
        problems.push(`${poster.id}: ${entry.pattern} on "${line}": the game says ${JSON.stringify(mine)}, JavaScript says ${JSON.stringify(theirs)}`);
      }
    });
  }
}

for (const line of problems.slice(0, 40)) console.log("MISMATCH", line);
if (problems.length > 40) console.log(`... and ${problems.length - 40} more`);
console.log(`VERIFY result=${problems.length === 0 ? "ok" : `FAIL ${problems.length}`} posters=${posters.length} patterns=${checked} refused=${refused}`);
process.exit(problems.length === 0 ? 0 : 1);
