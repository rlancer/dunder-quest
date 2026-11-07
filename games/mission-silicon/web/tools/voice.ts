// Records the Pilot's spoken lines (src/lines.ts) into voice/, one small mp3
// per line, with OpenAI's audio model through OpenRouter. Each cast member
// has a voice and a style in data/pilot.json's "cast". The model is told to
// read the line word for word, and its transcript is checked against the
// line; a line it paraphrases is recorded again. Reads the key from the
// repo's .env and never prints it.
//
//     bun tools/voice.ts            # every line that has no file yet
//     bun tools/voice.ts --prune    # also delete files no line uses
//
// Needs ffmpeg. Files are mono 24 kHz mp3 at 32 kbps, about 4 KB a second.

import { existsSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { allLines, voiceKey, type Line } from "../src/lines";
import { P } from "../src/model";

const HERE = dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, "$1"));
const OUT = resolve(HERE, "../voice");
const MODEL = "openai/gpt-audio-mini";
const TRIES = 3;

function findEnv(): string {
  // The repo's .env, from a worktree or the main checkout.
  let dir = resolve(HERE, "../../../..");
  for (const d of [dir, resolve(dir, "../../..")]) if (existsSync(join(d, ".env"))) return join(d, ".env");
  throw new Error("no .env with OPENROUTER_API_KEY found");
}

const env = await Bun.file(findEnv()).text();
const KEY = env.match(/^OPENROUTER_API_KEY=(.*)$/m)?.[1].replace(/["\r]/g, "").trim();
const BASE = (env.match(/^OPENROUTER_BASE_URL=(.*)$/m)?.[1].trim() || "https://openrouter.ai/api/v1").replace(/\/$/, "");
if (!KEY) throw new Error("OPENROUTER_API_KEY is missing from .env");

const words = (s: string) => s.toLowerCase().replace(/[^a-z0-9 ]+/g, " ").split(/\s+/).filter(Boolean);
const same = (a: string, b: string) => words(a).join(" ") === words(b).join(" ");

async function speak(l: Line): Promise<{ pcm: Buffer; transcript: string }> {
  const who = (P.cast as Record<string, { voice: string; style: string }>)[l.who];
  if (!who) throw new Error(`no voice for ${l.who}`);
  const body = {
    model: MODEL,
    modalities: ["text", "audio"],
    audio: { voice: who.voice, format: "pcm16" },
    stream: true,
    messages: [
      {
        role: "system",
        content:
          "You are a voice actor in a comedy about a tech startup. Read the user's line aloud exactly as written, " +
          "word for word, adding nothing, leaving nothing out, and saying nothing else. " +
          `Your character: ${who.style}`,
      },
      // Quote marks read as "say only this part", so the model gets the words without them.
      { role: "user", content: l.say.replace(/[“”"]/g, "") },
    ],
  };
  const r = await fetch(`${BASE}/chat/completions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`${r.status} ${(await r.text()).slice(0, 200)}`);
  let b64 = "";
  let transcript = "";
  for (const line of (await r.text()).split("\n")) {
    if (!line.startsWith("data: ") || line.includes("[DONE]")) continue;
    try {
      const a = JSON.parse(line.slice(6)).choices?.[0]?.delta?.audio;
      if (a?.data) b64 += a.data;
      if (a?.transcript) transcript += a.transcript;
    } catch {}
  }
  return { pcm: Buffer.from(b64, "base64"), transcript };
}

async function record(l: Line): Promise<string> {
  const dest = join(OUT, `${voiceKey(l)}.mp3`);
  for (let i = 1; i <= TRIES; i++) {
    const { pcm, transcript } = await speak(l);
    if (pcm.length < 4800 || !same(transcript, l.say)) {
      console.log(`  retry ${voiceKey(l)} (${i}): heard "${transcript.slice(0, 80)}"`);
      continue;
    }
    const raw = `${dest}.pcm`;
    await Bun.write(raw, pcm);
    const ff = Bun.spawnSync(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", "24000", "-ac", "1", "-i", raw,
      "-af", "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse",
      "-b:a", "32k", dest]);
    rmSync(raw);
    if (ff.exitCode !== 0) throw new Error(ff.stderr.toString());
    return `${voiceKey(l)} ${(pcm.length / 48000).toFixed(1)}s ${l.who}: ${l.say.slice(0, 50)}`;
  }
  throw new Error(`${voiceKey(l)} never read word for word: ${l.say}`);
}

mkdirSync(OUT, { recursive: true });
const lines = allLines();
const todo = lines.filter((l) => !existsSync(join(OUT, `${voiceKey(l)}.mp3`)));
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
