/**
 * Holds the game's Rust up against the real rustc.
 *
 * For every plan in data/scenes.json, in every combination of its blanks, it
 * compiles the program with rustc and (when it builds) runs it. Then it checks:
 *
 *   * the starting picks fail with the error code the scene says,
 *   * the solution builds and prints exactly the lines the scene expects,
 *   * every lesson card builds and prints what it says (or fails with its code),
 *   * and, given tests/out/cases.json from the in-game checker
 *     (godot --headless --path . --script res://tests/cases.gd), that the
 *     checker agrees with rustc on every combination: same pass/fail, its
 *     first error code is one rustc reports, and the same output and panics.
 *
 *     bun tests/verify_rust.ts              # RUST result=ok (skips if rustc is missing)
 *     bun tests/verify_rust.ts --require    # fail if rustc is missing (CI)
 *
 * Needs rustc on the PATH (any recent stable, edition 2021).
 */

import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { availableParallelism, tmpdir } from "node:os";
import { join, resolve } from "node:path";

// deno-lint-ignore no-explicit-any
type Json = any;
type Result = { ok: boolean; codes: string[]; stdout: string[]; panic: boolean };

const ROOT = resolve(import.meta.dir, "..");
const DATA = JSON.parse(readFileSync(join(ROOT, "data", "scenes.json"), "utf-8"));
const CASES = join(ROOT, "tests", "out", "cases.json");
const [OPEN, CLOSE] = ["«", "»"];

function slotOrder(code: string[]): string[] {
  const order: string[] = [];
  for (const line of code) {
    let at = line.indexOf(OPEN);
    while (at >= 0) {
      const close = line.indexOf(CLOSE, at);
      const name = line.slice(at + 1, close);
      if (!order.includes(name)) order.push(name);
      at = line.indexOf(OPEN, close);
    }
  }
  return order;
}

function render(plan: Json, picks: Record<string, string>): string {
  const lines = plan.code.map((line: string) => {
    for (const [name, value] of Object.entries(picks)) line = line.split(`${OPEN}${name}${CLOSE}`).join(value);
    return line;
  });
  return lines.join("\n") + "\n";
}

function combos(plan: Json): Record<string, string>[] {
  let out: Record<string, string>[] = [{}];
  for (const name of slotOrder(plan.code)) {
    out = out.flatMap((picks) => plan.slots[name].map((value: string) => ({ ...picks, [name]: value })));
  }
  return out;
}

// Output lines, the way Python's str.splitlines() cuts them.
function lines(text: string): string[] {
  const out = text.split(/\r\n|\r|\n/);
  if (out.at(-1) === "") out.pop();
  return out;
}

/** Compile and run one program. */
async function rustc(source: string, work: string): Promise<Result> {
  const src = join(work, "main.rs");
  const exe = join(work, process.platform === "win32" ? "main.exe" : "main");
  writeFileSync(src, source, "utf-8");
  const build = Bun.spawn(["rustc", "--edition", "2021", "-A", "warnings", "--error-format=json", "-o", exe, src],
    { cwd: work, stdout: "pipe", stderr: "pipe" });
  const stderr = await new Response(build.stderr).text();
  if (await build.exited !== 0) {
    const codes: string[] = [];
    for (const line of lines(stderr)) {
      let diag: Json;
      try {
        diag = JSON.parse(line);
      } catch {
        continue;
      }
      if (diag?.level === "error") codes.push(diag.code?.code || "");
    }
    return { ok: false, codes, stdout: [], panic: false };
  }
  const run = Bun.spawn([exe], { stdout: "pipe", stderr: "pipe", timeout: 20_000 });
  const stdout = await new Response(run.stdout).text();
  const code = await run.exited;
  if (run.signalCode) throw new Error(`a program ran past 20 s:\n${source}`);
  return { ok: true, codes: [], stdout: lines(stdout), panic: code === 101 };
}

function cardSource(card: Json): string {
  const code = card.code.join("\n");
  if (code.includes("fn main(")) return code + "\n";
  return "fn main() {\n" + card.code.map((line: string) => "    " + line).join("\n") + "\n}\n";
}

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
const shown = (codes: string[]) => codes.length ? JSON.stringify(codes) : "ok";

async function main(): Promise<void> {
  if (!Bun.which("rustc")) {
    console.log("RUST result=skipped: rustc is not on the PATH (install Rust from https://rustup.rs)");
    process.exit(process.argv.includes("--require") ? 1 : 0);
  }
  const version = Bun.spawnSync(["rustc", "--version"]).stdout.toString().trim();
  console.log(`using ${version}`);

  const jobs: [string, string, string][] = []; // [kind, key, source]
  const plans = new Map<string, Json>();
  for (const scene of DATA.scenes) {
    for (const plan of scene.plans) {
      plans.set(plan.id, plan);
      for (const picks of combos(plan)) jobs.push(["plan", plan.id, render(plan, picks)]);
    }
  }
  for (const [cid, card] of Object.entries(DATA.cards)) jobs.push(["card", cid, cardSource(card)]);

  // As many rustc processes at once as there are cores.
  const results: Result[] = new Array(jobs.length);
  let next = 0;
  const worker = async () => {
    while (next < jobs.length) {
      const i = next++;
      const tmp = mkdtempSync(join(tmpdir(), "verify-rust-"));
      try {
        results[i] = await rustc(jobs[i][2], tmp);
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
    }
  };
  await Promise.all(Array.from({ length: availableParallelism() || 4 }, worker));
  const bySource = new Map<string, Result>();
  jobs.forEach(([kind, key, source], i) => { if (kind === "plan") bySource.set(`${key}\0${source}`, results[i]); });

  const fails: string[] = [];
  for (const [pid, plan] of plans) {
    const start = bySource.get(`${pid}\0${render(plan, plan.start)}`)!;
    const want = plan.start_error;
    if (want && (start.ok || !start.codes.includes(want))) {
      fails.push(`${pid}: start picks gave ${shown(start.codes)}, the scene says ${want}`);
    }
    const solved = bySource.get(`${pid}\0${render(plan, plan.solution)}`)!;
    if (!solved.ok) {
      fails.push(`${pid}: solution fails to build: ${JSON.stringify(solved.codes)}`);
    } else if (!same(solved.stdout, plan.expect) || solved.panic) {
      fails.push(`${pid}: solution printed ${JSON.stringify(solved.stdout)}, the scene expects ${JSON.stringify(plan.expect)}`);
    }
  }
  jobs.forEach(([kind, cid], i) => {
    if (kind !== "card") return;
    const card = DATA.cards[cid];
    const result = results[i];
    if ("error" in card) {
      if (result.ok || !result.codes.includes(card.error)) {
        fails.push(`card ${cid}: expected ${card.error}, rustc gave ${shown(result.codes)}`);
      }
    } else if (!result.ok) {
      fails.push(`card ${cid}: fails to build: ${JSON.stringify(result.codes)}`);
    } else if ("output" in card && !same(result.stdout, card.output)) {
      fails.push(`card ${cid}: printed ${JSON.stringify(result.stdout)}, the card says ${JSON.stringify(card.output)}`);
    }
  });

  let compared = 0;
  if (existsSync(CASES)) {
    for (const c of JSON.parse(readFileSync(CASES, "utf-8"))) {
      const truth = bySource.get(`${c.plan}\0${c.source}`);
      if (!truth) {
        fails.push(`${c.plan}: cases.json is stale (re-run tests/cases.gd)`);
        break;
      }
      compared++;
      const label = `${c.plan} ${JSON.stringify(c.picks)}`;
      if (c.ok !== truth.ok) {
        fails.push(`${label}: checker says ${c.ok ? "ok" : JSON.stringify(c.codes.slice(0, 1))}, rustc says ${shown(truth.ok ? [] : truth.codes)}`);
      } else if (!truth.ok && !truth.codes.includes(c.codes[0])) {
        fails.push(`${label}: checker's ${c.codes[0]} isn't among rustc's ${JSON.stringify(truth.codes)}`);
      } else if (truth.ok && (!same(c.stdout, truth.stdout) || Boolean(c.panic) !== truth.panic)) {
        fails.push(`${label}: checker ran ${JSON.stringify(c.stdout)} (panic ${Boolean(c.panic)}), binary printed ${JSON.stringify(truth.stdout)} (panic ${truth.panic})`);
      }
    }
  } else {
    console.log("note: no tests/out/cases.json, so the in-game checker wasn't compared (run tests/cases.gd first)");
  }

  for (const fail of fails) console.log("FAIL", fail);
  console.log(`RUST ${jobs.length} programs built, ${compared} checker verdicts compared, result=${fails.length ? "FAIL" : "ok"}`);
  process.exit(fails.length ? 1 : 0);
}

await main();
