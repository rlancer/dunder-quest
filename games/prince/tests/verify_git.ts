/**
 * Holds the game's Git up against the real git.
 *
 * tests/replay.gd runs every room's history, triggers and solution, and a
 * set of probes (things a player might do that no solution does), through
 * the in-game Git model and writes each command to tests/out/replay.json.
 * This runs the same commands, in order, in a real repository, and checks
 * after every one that git agrees with the game:
 *
 *   * the same exit code,
 *   * every line the game prints is a line git printed,
 *   * the same branch checked out, the same commit id on every branch,
 *   * the same contents in every file (conflict markers included),
 *   * the same ORIG_HEAD and MERGE_HEAD,
 *
 * and that each room's solution ends on main, clean, with the exit open.
 * The commit ids match because the game hashes blobs, trees and commits the
 * way git does, with a fixed author date. Rooms with a guarded main get the
 * real pre-commit hook from data/levels.json.
 *
 *     godot --headless --path . --script res://tests/replay.gd
 *     bun tests/verify_git.ts              # GIT result=ok (skips if git or the replay is missing)
 *     bun tests/verify_git.ts --require    # fail instead of skipping (CI)
 */

import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

// deno-lint-ignore no-explicit-any
type Json = any;

const ROOT = resolve(import.meta.dir, "..");
const DATA = JSON.parse(readFileSync(join(ROOT, "data", "levels.json"), "utf-8"));
const REPLAY = join(ROOT, "tests", "out", "replay.json");
const REQUIRE = process.argv.includes("--require");

function skip(why: string): never {
  console.log(`GIT result=${REQUIRE ? "FAIL" : "skipped"} (${why})`);
  process.exit(REQUIRE ? 1 : 0);
}

const version = Bun.spawnSync(["git", "--version"]);
if (version.exitCode !== 0) skip("git is not on the PATH");
if (!existsSync(REPLAY)) skip("no tests/out/replay.json: run tests/replay.gd first");
const replay = JSON.parse(readFileSync(REPLAY, "utf-8"));
// An empty file stands in for the user's and the system's git config, so only git's defaults apply.
const CONFIG_DIR = mkdtempSync(join(tmpdir(), "prince-gitconfig-"));
const NO_CONFIG = join(CONFIG_DIR, "gitconfig");
writeFileSync(NO_CONFIG, "");

function git(dir: string, args: string[], author = "prince"): { code: number; lines: string[] } {
  const [name, email] = replay.authors[author];
  const run = Bun.spawnSync(["git", ...args], {
    cwd: dir,
    env: {
      PATH: process.env.PATH ?? "", SYSTEMROOT: process.env.SYSTEMROOT ?? "", HOME: dir,
      GIT_CONFIG_GLOBAL: NO_CONFIG, GIT_CONFIG_NOSYSTEM: "1", GIT_TERMINAL_PROMPT: "0",
      GIT_AUTHOR_NAME: name, GIT_AUTHOR_EMAIL: email, GIT_AUTHOR_DATE: replay.date,
      GIT_COMMITTER_NAME: name, GIT_COMMITTER_EMAIL: email, GIT_COMMITTER_DATE: replay.date,
      // A merge would open an editor for its message at a terminal; here it takes the default.
      GIT_MERGE_AUTOEDIT: "no", GIT_EDITOR: "true", LC_ALL: "C",
    },
  });
  const text = run.stdout.toString() + run.stderr.toString();
  return { code: run.exitCode, lines: text.split(/\r?\n/).map((l) => l.trimEnd()).filter((l) => l) };
}

function one(dir: string, args: string[]): string {
  const out = git(dir, args);
  return out.code === 0 ? (out.lines[0] ?? "") : "";
}

function state(dir: string): Json {
  const branches: Record<string, string> = {};
  for (const line of git(dir, ["for-each-ref", "--format=%(refname:short) %(objectname)", "refs/heads"]).lines) {
    const [name, sha] = line.split(" ");
    branches[name] = sha;
  }
  const work: Record<string, string> = {};
  for (const name of readdirSync(dir)) {
    if (statSync(join(dir, name)).isFile()) work[name] = readFileSync(join(dir, name), "utf-8");
  }
  return {
    head: one(dir, ["symbolic-ref", "--short", "HEAD"]), branches, work,
    orig_head: one(dir, ["rev-parse", "-q", "--verify", "ORIG_HEAD"]),
    merge_head: one(dir, ["rev-parse", "-q", "--verify", "MERGE_HEAD"]),
  };
}

function same(a: Json, b: Json): boolean {
  const keys = (o: Json) => JSON.stringify(Object.keys(o).sort().map((k) => [k, o[k]]));
  return a.head === b.head && a.orig_head === b.orig_head && a.merge_head === b.merge_head
    && keys(a.branches) === keys(b.branches) && keys(a.work) === keys(b.work);
}

const fails: string[] = [];
let commands = 0;

for (const run of replay.runs) {
  const level = DATA.levels.find((l: Json) => l.id === run.level);
  const where = `room ${run.level} (${run.name})`;
  const dir = mkdtempSync(join(tmpdir(), "prince-git-"));
  try {
    git(dir, ["init", "-q", "-b", "main"]);
    for (const [key, value] of [["core.autocrlf", "false"], ["commit.gpgsign", "false"],
      // Leave "into main" off a merge message's default on every git version, as current git does.
      ["merge.suppressDest", "main"]]) git(dir, ["config", key, value]);
    run.log.forEach((entry: Json, index: number) => {
      // The guard arrives once the room's own history is written.
      if (index === run.setup && run.protect_main) {
        const hook = join(dir, ".git", "hooks", "pre-commit");
        mkdirSync(join(dir, ".git", "hooks"), { recursive: true });
        writeFileSync(hook, DATA.guard_hook.join("\n") + "\n");
        chmodSync(hook, 0o755);
      }
      if (entry.init) {
        for (const [name, value] of Object.entries(entry.init)) writeFileSync(join(dir, name), `${value}\n`);
        git(dir, ["add", "-A"], entry.author);
        const made = git(dir, ["commit", "-q", "-m", entry.message], entry.author);
        if (made.code !== 0) fails.push(`${where}: the first commit failed: ${made.lines.join(" / ")}`);
        return;
      }
      if (entry.write) {
        for (const [name, text] of Object.entries(entry.write)) writeFileSync(join(dir, name), text as string);
        return;
      }
      commands += 1;
      const shown = `git ${entry.cmd.join(" ")}`;
      const real = git(dir, entry.cmd, entry.author ?? "prince");
      if (real.code !== entry.exit) {
        fails.push(`${where}: \`${shown}\` exits ${real.code} in git, ${entry.exit} in the game (${real.lines.join(" / ")})`);
      }
      for (const line of entry.out) {
        if (!real.lines.includes(line.trimEnd())) {
          fails.push(`${where}: \`${shown}\`: the game prints ${JSON.stringify(line)}, git printed ${JSON.stringify(real.lines)}`);
        }
      }
      const now = state(dir);
      if (!same(now, entry.state)) {
        fails.push(`${where}: after \`${shown}\` git has ${JSON.stringify(now)}, the game ${JSON.stringify(entry.state)}`);
      }
    });
    if (run.name === "solution") {
      const now = state(dir);
      const clean = git(dir, ["status", "--porcelain"]).lines.length === 0;
      const open = now.head === "main" && clean && !now.merge_head
        && Object.entries(level.exit_when).every(([file, value]) => now.work[file] === `${value}\n`);
      if (!open) fails.push(`${where}: in git, the solution doesn't leave main clean with the exit open`);
      if (!run.exit_open) fails.push(`${where}: in the game, the solution doesn't open the exit`);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

rmSync(CONFIG_DIR, { recursive: true, force: true });
const which = version.stdout.toString().trim();
if (fails.length) {
  console.log(`GIT result=FAIL (${fails.length} problems in ${commands} commands, ${which})`);
  for (const fail of fails.slice(0, 12)) console.log("  " + fail);
  process.exit(1);
}
console.log(`GIT result=ok (${commands} commands in ${replay.runs.length} runs agree with ${which})`);
