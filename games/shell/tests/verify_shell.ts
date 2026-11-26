/**
 * Holds the game's shell to the real one.
 *
 * The game runs its lines with sh/shell.gd, a shell written in GDScript.
 * This runs every line that tests/replay.gd wrote to tests/out/lines.json
 * (every row of up to three chips on every ticket's table, hundreds of
 * longer ones, every solution, every lesson card's demo and a set of
 * probes) through bash and the GNU tools, in a folder holding the same
 * files, and demands:
 *
 * - where the game runs a line, bash prints exactly the same, writes
 *   exactly the same files, and complains about nothing;
 * - where the game gives an error, bash gives that error too, in the same
 *   words (a syntax error only has to be one: bash words those differently
 *   from version to version; and where two commands on a line both fail,
 *   bash only has to complain, since they talk over each other);
 * - where the game says a command is waiting on the keyboard (its own
 *   rule: a first command with no file), bash, handed nothing, runs it
 *   without complaint.
 *
 * Lines the game declines to model ("unsupported", and a line that reads a
 * file it is writing) are counted and skipped: the game refuses them, so
 * it teaches nothing wrong about them.
 *
 *     godot --headless --path . --script res://tests/replay.gd
 *     bun tests/verify_shell.ts
 */

import { mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

type Entry = { line: string; out?: string; files?: Record<string, string>; error?: string; kind?: string; count?: number };
type Group = { id: string; files: Record<string, string>; lines: Entry[] };

const here = dirname(fileURLToPath(import.meta.url));
const groups: Group[] = JSON.parse(readFileSync(join(here, "out", "lines.json"), "utf8"));
const root = mkdtempSync(join(tmpdir(), "yes-shell-"));
const env = { LC_ALL: "C", PATH: process.env.PATH ?? "/usr/bin:/bin" };

const problems: string[] = [];
let checked = 0;
let ran = 0;
let refused = 0;
let waiting = 0;
let skipped = 0;
let folder = 0;

/** bash's complaints, without the "line 1" it adds when run from -c. */
function complaints(stderr: string): string[] {
  return stderr.split("\n").filter((l) => l !== "").map((l) => l.replace(/^bash: (-c: )?line \d+: /, "bash: "));
}

for (const group of groups) {
  for (const entry of group.lines) {
    checked += 1;
    if (entry.kind === "unsupported" || entry.kind === "clobber" || entry.kind === "empty") {
      skipped += 1;
      continue;
    }
    const dir = join(root, String(folder++));
    mkdirSync(dir);
    for (const [name, text] of Object.entries(group.files)) writeFileSync(join(dir, name), text);
    const result = Bun.spawnSync(["bash", "-c", "--", entry.line], { cwd: dir, env, stdin: "ignore", stdout: "pipe", stderr: "pipe" });
    const stdout = result.stdout.toString();
    const said = complaints(result.stderr.toString());
    const where = `${group.id}: ${entry.line}`;
    if (entry.error === undefined) {
      ran += 1;
      if (said.length > 0) problems.push(`${where}: the game runs it, bash says ${JSON.stringify(said[0])}`);
      else if (stdout !== entry.out) problems.push(`${where}: the game prints ${JSON.stringify(entry.out)}, bash prints ${JSON.stringify(stdout)}`);
      const made: Record<string, string> = {};
      for (const name of readdirSync(dir)) {
        const text = readFileSync(join(dir, name), "utf8");
        if (group.files[name] !== text) made[name] = text;
      }
      if (JSON.stringify(Object.entries(made).sort()) !== JSON.stringify(Object.entries(entry.files ?? {}).sort())) {
        problems.push(`${where}: the game writes ${JSON.stringify(entry.files)}, bash writes ${JSON.stringify(made)}`);
      }
    } else if (entry.kind === "waiting") {
      waiting += 1;
      if (said.length > 0) problems.push(`${where}: the game says it would wait on the keyboard, bash says ${JSON.stringify(said[0])}`);
    } else if (entry.kind === "syntax") {
      refused += 1;
      if (!said.some((l) => l.includes("syntax error"))) problems.push(`${where}: the game calls it a syntax error, bash says ${JSON.stringify(said)}`);
    } else {
      refused += 1;
      const first = entry.error.split("\n")[0];
      // Two commands failing at once write over each other, and one may be
      // cut off before it speaks, so then bash only has to have complained.
      if ((entry.count ?? 1) > 1 ? said.length === 0 : !said.includes(first)) problems.push(`${where}: the game says ${JSON.stringify(first)}, bash says ${JSON.stringify(said)}`);
    }
    rmSync(dir, { recursive: true, force: true });
  }
}
rmSync(root, { recursive: true, force: true });

for (const line of problems.slice(0, 40)) console.log("MISMATCH", line);
if (problems.length > 40) console.log(`... and ${problems.length - 40} more`);
console.log(`VERIFY result=${problems.length === 0 ? "ok" : `FAIL ${problems.length}`} lines=${checked} ran=${ran} refused=${refused} waiting=${waiting} skipped=${skipped}`);
process.exit(problems.length === 0 ? 0 : 1);
