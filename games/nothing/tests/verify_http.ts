/**
 * Holds the game's HTTP to the real thing.
 *
 * The game answers its requests with http/http.gd, a set of counters written
 * in GDScript. tests/replay.gd writes every request the game can make to
 * tests/out/requests.json (every slip every scene's cards can make, every
 * lesson card's demo, and a set of probes at every counter), with the counter
 * and data it went to and what the game says came back. This runs a real HTTP
 * server (Bun.serve) with the same counters, written again in TypeScript
 * (http/counter.ts), sends it each request with real fetch over a real
 * socket, and demands:
 *
 * - the same status and reason phrase (the ones the server's HTTP stack puts
 *   on the wire, not the game's own table);
 * - the same headers the game shows (Content-Type, Location, ETag, Allow,
 *   WWW-Authenticate), and no others of those;
 * - the same body, character for character;
 * - the same data left on the counter afterwards.
 *
 * And it holds every response to the rules of HTTP (RFC 9110) the game
 * teaches: a 201 says where in Location, a 405 and an OPTIONS say what's
 * allowed in Allow, a 401 says how to log in in WWW-Authenticate, a 204, a
 * 304 and any answer to HEAD have no body, HEAD gets GET's status and
 * headers, a 304 carries its ETag.
 *
 *     godot --headless --path . --script res://tests/replay.gd
 *     bun tests/verify_http.ts
 */

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { type Counter, type State, respond } from "../http/counter.ts";

type Slip = { method: string; path: string; headers: string[]; body: string };
type Entry = {
  id: string; counter: Counter; data: Record<string, any>; versions: Record<string, number>; slip: Slip;
  status: number; reason: string; headers: [string, string][]; body: string; state: State;
};

const here = dirname(fileURLToPath(import.meta.url));
const entries: Entry[] = JSON.parse(readFileSync(join(here, "out", "requests.json"), "utf8"));
const SHOWN = ["Content-Type", "Location", "ETag", "Allow", "WWW-Authenticate"];

// --- The server, and the requests ------------------------------------------------


let counter: Counter;
let state: State;
const server = Bun.serve({
  port: 0,
  async fetch(req) {
    const headers: Record<string, string> = {};
    req.headers.forEach((value, name) => { headers[name] = value; });
    const a = respond(counter, state, { method: req.method, path: new URL(req.url).pathname, headers, body: await req.text() });
    return new Response(a.body, { status: a.status, headers: a.headers });
  },
});
const base = `http://localhost:${server.port}`;
const problems: string[] = [];
const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

for (const e of entries) {
  counter = e.counter;
  state = { items: structuredClone(e.data), v: { ...e.versions } };
  const headers = new Headers();
  for (const card of e.slip.headers) {
    const at = card.indexOf(": ");
    headers.append(card.slice(0, at), card.slice(at + 2));
  }
  const res = await fetch(base + e.slip.path, { method: e.slip.method, headers, body: e.slip.body === "" ? undefined : e.slip.body });
  const text = await res.text();
  const got: [string, string][] = [];
  for (const name of SHOWN) {
    const value = res.headers.get(name);
    if (value !== null) got.push([name, value]);
  }
  const where = `${e.id}: ${e.slip.method} ${e.slip.path} ${e.slip.headers.join(" | ")} ${e.slip.body}`;
  if (res.status !== e.status || res.statusText !== e.reason) problems.push(`${where}\n  game: ${e.status} ${e.reason}\n  real: ${res.status} ${res.statusText}`);
  if (!same(got, e.headers)) problems.push(`${where}\n  game headers: ${JSON.stringify(e.headers)}\n  real headers: ${JSON.stringify(got)}`);
  if (text !== e.body) problems.push(`${where}\n  game body: ${e.body}\n  real body: ${text}`);
  if (!same(state.items, e.state.items) || !same(state.v, e.state.v)) problems.push(`${where}\n  game left: ${JSON.stringify(e.state)}\n  real left: ${JSON.stringify(state)}`);
  // The rules of HTTP the game teaches, on what really came back.
  const has = (h: string) => res.headers.get(h) !== null;
  if (res.status === 201 && !has("Location")) problems.push(`${where}: a 201 with no Location`);
  if ((res.status === 405 || (e.slip.method === "OPTIONS" && res.ok)) && !has("Allow")) problems.push(`${where}: a ${res.status} with no Allow`);
  if (res.status === 401 && !has("WWW-Authenticate")) problems.push(`${where}: a 401 with no WWW-Authenticate`);
  if ((res.status === 204 || res.status === 304 || e.slip.method === "HEAD") && text !== "") problems.push(`${where}: a body where there can't be one`);
  if (res.status === 304 && !has("ETag")) problems.push(`${where}: a 304 with no ETag`);
  if (e.slip.method === "HEAD") {
    state = { items: structuredClone(e.data), v: { ...e.versions } };
    const get = await fetch(base + e.slip.path, { method: "GET", headers });
    await get.text();
    const getHeaders = SHOWN.map((h) => [h, get.headers.get(h)]).filter(([, v]) => v !== null);
    if (get.status !== res.status || !same(getHeaders, got)) problems.push(`${where}: HEAD and GET disagree`);
  }
}

server.stop(true);
for (const p of problems) console.log(`PROBLEM ${p}`);
console.log(`VERIFY result=${problems.length ? `FAIL ${problems.length}` : "ok"} requests=${entries.length} server=bun ${Bun.version}`);
process.exit(problems.length ? 1 : 0);
