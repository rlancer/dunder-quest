// Records the Pilot's spoken lines (src/lines.ts) into voice/, one small mp3
// per line, with ElevenLabs v4 through OpenRouter's speech API. Each cast
// member has a voice in data/pilot.json's "cast", and each line has its
// direction in tools/directions.json: the same words with tags like [flatly]
// or [pause], which are performed, not read out. Reads the key from the
// repo's .env and never prints it.
//
//     bun tools/voice.ts            # every line that has no file yet
//     bun tools/voice.ts --force    # record every line again
//     bun tools/voice.ts --prune    # also delete files no line uses
//
// To redo one line after changing its direction, delete its file and run this.
// Needs ffmpeg. Files are mono 24 kHz mp3 at 32 kbps, about 4 KB a second.

import { existsSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import directions from "./directions.json";
import { allLines, voiceKey, type Line } from "../src/lines";
import { P } from "../src/model";

const HERE = dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, "$1"));
const OUT = resolve(HERE, "../voice");
const MODEL = "elevenlabs/eleven-v4";
const TRIES = 3;
// Spelled for the ear only: the model reads the brand as "forecast" otherwise.
const SOUNDS: [RegExp, string][] = [
  [/Forkcast/g, "Fork-cast"],
  [/forkcast/g, "fork-cast"],
  [/NEXT_PUBLIC/g, "next public"],
];

function findEnv(): string {
  // The repo's .env, from a worktree or the main checkout.
  let dir = resolve(HERE, "../../../..");
  for (const d of [dir, resolve(dir, "../../..")]) if (existsSync(join(d, ".env"))) return join(d, ".env");
  throw new Error("no .env with OPENROUTER_API_KEY found");
}

const env = await Bun.file(findEnv()).text();
const KEY = env.match(/^OPENROUTER_API_KEY=(.*)$/m)?.[1].replace(/["\r]/g, "").trim();
const BASE = (env.match(/^OPENROUTER_BASE_URL=(.*)$/m)?.[1].replace(/["\r]/g, "").trim() || "https://openrouter.ai/api/v1").replace(/\/$/, "");
if (!KEY) throw new Error("OPENROUTER_API_KEY is missing from .env");

const words = (s: string) => s.toLowerCase().replace(/[^a-z0-9 ]+/g, " ").split(/\s+/).filter(Boolean);
const same = (a: string, b: string) => words(a).join(" ") === words(b).join(" ");
const untagged = (s: string) => s.replace(/\[[^\]]+\]/g, " ");

// A line's direction, checked against its words so an edited line can't speak its old ones.
function script(l: Line): string {
  const tagged = (directions as Record<string, string>)[voiceKey(l)];
  if (!tagged) throw new Error(`${voiceKey(l)} has no direction in tools/directions.json: ${l.say}`);
  if (!same(untagged(tagged), l.say)) throw new Error(`${voiceKey(l)} direction has different words: ${tagged}`);
  // Quote marks can make the model change its reading, so it gets the words without them.
  return SOUNDS.reduce((s, [from, to]) => s.replace(from, to), tagged.replace(/[“”"]/g, ""));
}

async function speak(l: Line): Promise<ArrayBuffer> {
  const who = (P.cast as Record<string, { voice: string }>)[l.who];
  if (!who) throw new Error(`no voice for ${l.who}`);
  const r = await fetch(`${BASE}/audio/speech`, {
    method: "POST",
    headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: MODEL, input: script(l), voice: who.voice, response_format: "mp3" }),
  });
  if (!r.ok) throw new Error(`${r.status} ${(await r.text()).slice(0, 200)}`);
  return r.arrayBuffer();
}

function seconds(file: string): number {
  return Number(Bun.spawnSync(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file]).stdout.toString().trim());
}

async function record(l: Line): Promise<string> {
  const dest = join(OUT, `${voiceKey(l)}.mp3`);
  for (let i = 1; i <= TRIES; i++) {
    const raw = `${dest}.raw`;
    await Bun.write(raw, await speak(l));
    const ff = Bun.spawnSync(["ffmpeg", "-y", "-loglevel", "error", "-f", "mp3", "-i", raw,
      "-af", "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse",
      "-ac", "1", "-ar", "24000", "-b:a", "32k", dest]);
    rmSync(raw);
    if (ff.exitCode !== 0) throw new Error(ff.stderr.toString());
    const s = seconds(dest);
    if (s >= 0.3) return `${voiceKey(l)} ${s.toFixed(1)}s ${l.who}: ${l.say.slice(0, 50)}`;
    console.log(`  retry ${voiceKey(l)} (${i}): only ${s}s of audio`);
  }
  throw new Error(`${voiceKey(l)} came back with no audio: ${l.say}`);
}

mkdirSync(OUT, { recursive: true });
const lines = allLines();
const force = process.argv.includes("--force");
const todo = lines.filter((l) => force || !existsSync(join(OUT, `${voiceKey(l)}.mp3`)));
for (const l of todo) script(l);
console.log(`${lines.length} lines, ${todo.length} to record`);
const failed: string[] = [];
for (let i = 0; i < todo.length; i += 4) {
  const done = await Promise.allSettled(todo.slice(i, i + 4).map(record));
  for (const d of done) d.status === "fulfilled" ? console.log(d.value) : (console.log(`FAILED ${d.reason}`), failed.push(String(d.reason)));
}
if (process.argv.includes("--prune")) {
  const keep = new Set(lines.map((l) => `${voiceKey(l)}.mp3`));
  for (const f of readdirSync(OUT)) if (f.endsWith(".mp3") && !keep.has(f)) (rmSync(join(OUT, f)), console.log(`pruned ${f}`));
}
if (failed.length) process.exit(1);
