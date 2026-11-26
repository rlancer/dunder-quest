/**
 * Holds the game's event loop to the real one.
 *
 * The game plays its scripts with loop/engine.gd, an event loop written in
 * GDScript. tests/replay.gd writes every program the game can make to
 * tests/out/programs.json (every way every scene's cue cards can go on its
 * hooks, every lesson card's demo, and a set of probes no scene spells), as
 * the JavaScript text the player reads, with what the game says it logs.
 * This runs each one, as a script of its own, with the real JavaScript engine
 * (bun's), and demands that it logs exactly the same lines in exactly the
 * same order.
 *
 * Each program runs in a process of its own, so no program's timers share a
 * clock with another's. The game keeps out any program whose order would hang
 * on how quickly the computer gets round to a timer (replay.gd fails on one);
 * even so, a busy machine can be slow enough to make a timer late, so a
 * program that disagrees is run again, by itself, before it counts as wrong.
 *
 *     godot --headless --path . --script res://tests/replay.gd
 *     bun tests/verify_loop.ts            # with bun's engine (CI)
 *     bun tests/verify_loop.ts --node     # with Node's instead
 */

import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { availableParallelism, tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

type Program = { source: string; out: string[]; photo: boolean };
type Group = { id: string; programs: Program[] };

const here = dirname(fileURLToPath(import.meta.url));
const groups: Group[] = JSON.parse(readFileSync(join(here, "out", "programs.json"), "utf8"));
const root = mkdtempSync(join(tmpdir(), "game-about-nothing-"));
const problems: string[] = [];
const engine = process.argv.includes("--node") ? "node" : process.execPath;
let checked = 0;
let again = 0;

/** What the real engine logs for `source`, a line at a time. */
async function run(source: string, name: string): Promise<{ lines: string[]; error: string }> {
  const file = join(root, `${name}.js`);
  writeFileSync(file, source);
  const proc = Bun.spawn([engine, file], { stdout: "pipe", stderr: "pipe" });
  const [out, err] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text()]);
  await proc.exited;
  const lines = out.split("\n");
  if (lines.at(-1) === "") lines.pop();
  return { lines, error: proc.exitCode === 0 ? "" : err.trim().split("\n").slice(-3).join(" / ") };
}

const same = (a: string[], b: string[]) => a.length === b.length && a.every((x, i) => x === b[i]);

type Job = { group: string; index: number; program: Program };
const jobs: Job[] = groups.flatMap((g) => g.programs.map((program, index) => ({ group: g.id, index, program })));
const doubted: { job: Job; got: string[]; error: string }[] = [];

// Most of the time a program spends is waiting on its timers, so many run at once.
const lanes = Math.max(4, availableParallelism() * 4);
let next = 0;
await Promise.all(Array.from({ length: lanes }, async (_, lane) => {
  while (next < jobs.length) {
    const job = jobs[next++];
    if (job.program.photo) {
      problems.push(`${job.group} #${job.index}: the game let through a program whose timers are too close to call`);
      continue;
    }
    const { lines, error } = await run(job.program.source, `p${lane}`);
    checked++;
    if (error || !same(lines, job.program.out)) doubted.push({ job, got: lines, error });
  }
}));

// Anything that disagreed runs again on its own, with nothing else running.
for (const { job } of doubted) {
  again++;
  const { lines, error } = await run(job.program.source, "again");
  if (error) {
    problems.push(`${job.group} #${job.index}: it doesn't run: ${error}\n${job.program.source}`);
  } else if (!same(lines, job.program.out)) {
    problems.push(`${job.group} #${job.index}: the game says it logs\n  ${job.program.out.join(" | ")}\nbut JavaScript logs\n  ${lines.join(" | ")}\n${job.program.source}`);
  }
}

rmSync(root, { recursive: true, force: true });
for (const p of problems) console.log(`PROBLEM ${p}`);
console.log(`VERIFY result=${problems.length ? `FAIL ${problems.length}` : "ok"} programs=${checked} rerun=${again} engine=${engine === "node" ? "node" : `bun ${Bun.version}`}`);
process.exit(problems.length ? 1 : 0);
