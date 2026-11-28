// The social API end to end, on an in-memory SQLite standing in for D1:
// bun test deploy/test

import { afterAll, beforeAll, describe, expect, mock, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { assets, d1 } from "../dev";
import worker, { type Env } from "../src/worker";
import { bestLine, merge, normalize, summarize } from "../../site/static/social/games.js";

const CLIENT_ID = "test-client.apps.googleusercontent.com";
let site: string;
let env: Env;
const ctx = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;

beforeAll(() => {
  site = mkdtempSync(join(tmpdir(), "dq-site-"));
  writeFileSync(join(site, "404.html"), "<h1>lost</h1>");
  env = { DB: d1(":memory:"), ASSETS: assets(site), GOOGLE_CLIENT_ID: CLIENT_ID };
});

afterAll(() => rmSync(site, { recursive: true, force: true }));

async function call(method: string, path: string, { token = "", body }: { token?: string; body?: unknown } = {}) {
  const headers: Record<string, string> = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let payload: BodyInit | undefined;
  if (body instanceof FormData) payload = body;
  else if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const res = await worker.fetch(new Request(`https://dunderquest.test${path}`, { method, headers, body: payload }), env, ctx);
  const type = res.headers.get("Content-Type") ?? "";
  return { status: res.status, type, body: type.includes("json") ? await res.json() : type.startsWith("image/") ? new Uint8Array(await res.arrayBuffer()) : await res.text() } as {
    status: number; type: string; body: any;
  };
}

async function newPlayer(name?: string) {
  const res = await call("POST", "/api/players", { body: name ? { name } : {} });
  expect(res.status).toBe(201);
  return res.body as { token: string; player: { id: string; name: string } };
}

const curbSave = (cleared: number[], tries: Record<string, number> = {}) =>
  JSON.stringify({ current_scene: 1, cleared, tries, cards: [] });

describe("players", () => {
  test("a new player gets a silly name and a token", async () => {
    const { token, player } = await newPlayer();
    expect(player.name).toMatch(/^\w+ \w+ \d{3}$/);
    const me = await call("GET", "/api/me", { token });
    expect(me.body.player.id).toBe(player.id);
    expect(me.body.player.google).toBe(false);
  });

  test("names are cleaned and rude ones refused", async () => {
    const { token } = await newPlayer();
    expect((await call("PATCH", "/api/me", { token, body: { name: "  Sir   Robin " } })).body.player.name).toBe("Sir Robin");
    expect((await call("PATCH", "/api/me", { token, body: { name: "sh1thead" } })).status).toBe(400);
    expect((await call("PATCH", "/api/me", { token, body: { name: "x" } })).status).toBe(400);
  });

  test("a bad token is not signed in", async () => {
    expect((await call("GET", "/api/me", { token: "nope.nope" })).status).toBe(401);
  });

  test("deleting a player removes everything", async () => {
    const { token, player } = await newPlayer();
    await call("PUT", "/api/saves/curb", { token, body: { data: curbSave([1]) } });
    expect((await call("DELETE", "/api/me", { token })).status).toBe(200);
    expect((await call("GET", "/api/me", { token })).status).toBe(401);
    expect((await call("GET", `/u/${player.id}`)).status).toBe(404);
  });
});

describe("saves", () => {
  test("saves merge: progress from two devices adds up", async () => {
    const { token } = await newPlayer();
    let res = await call("PUT", "/api/saves/curb", { token, body: { data: curbSave([1, 2], { 1: 4, 2: 6 }) } });
    expect(res.status).toBe(200);
    expect(res.body.summary.count).toBe(2);
    res = await call("PUT", "/api/saves/curb", { token, body: { data: curbSave([1, 3], { 1: 2, 3: 5 }) } });
    expect(res.body.summary.cleared).toEqual([1, 2, 3]);
    expect(JSON.parse(res.body.data).tries).toEqual({ 1: 2, 2: 6, 3: 5 });
    const saves = await call("GET", "/api/saves", { token });
    expect(saves.body.saves.curb.summary.tries).toBe(13);
    expect(res.body.player.xp).toBe(300);
  });

  test("a greedy save keeps the fewest draws and the most stars", async () => {
    const one = { current_job: 2, cleared: [1, 2], tries: { 1: 3, 2: 5 }, stars: { 1: 4, 2: 1 }, cards: ["literal", "dot"] };
    const two = { current_job: 4, cleared: [1, 3, 9], tries: { 1: 6, 3: 2, 9: 1 }, stars: { 1: 2, 2: 3, 3: 9 }, cards: ["dot", "plus"], junk: 1 };
    // Unknown jobs, out-of-range stars and stray fields are dropped.
    expect(normalize("greedy", two)).toEqual({ current_job: 4, cleared: [1, 3], tries: { 1: 6, 3: 2 }, stars: { 1: 2, 2: 3, 3: 4 }, cards: ["dot", "plus"] });
    expect(normalize("greedy", { current_job: 7 })).toEqual({ current_job: 1, cleared: [], tries: {}, stars: {}, cards: [] });
    const both = merge("greedy", JSON.stringify(one), two);
    // Both have two jobs cleared, so the first save says where to carry on.
    expect(both).toEqual({ current_job: 2, cleared: [1, 2, 3], tries: { 1: 3, 2: 5, 3: 2 }, stars: { 1: 4, 2: 3, 3: 4 }, cards: ["literal", "dot", "plus"] });
    const s = summarize("greedy", both);
    expect(s.count).toBe(3);
    expect(s.tries).toBe(10);
    expect(s.collected).toBe(11);
    expect(s.collectMax).toBe(19);
    expect(s.xp).toBe(3 * 100 + 11 * 10);
    expect(bestLine("greedy", s)).toBe("10 tries");

    // And through the API, from two devices.
    const { token } = await newPlayer();
    let res = await call("PUT", "/api/saves/greedy", { token, body: { data: JSON.stringify(one) } });
    expect(res.status).toBe(200);
    res = await call("PUT", "/api/saves/greedy", { token, body: { data: JSON.stringify(two) } });
    expect(JSON.parse(res.body.data)).toEqual(both);
    expect(res.body.summary.tries).toBe(10);
    // Clearing all five issues the certificate.
    const all = { current_job: 5, cleared: [1, 2, 3, 4, 5], tries: { 4: 2, 5: 4 }, stars: { 5: 3 }, cards: [] };
    res = await call("PUT", "/api/saves/greedy", { token, body: { data: JSON.stringify(all) } });
    expect(res.body.summary.complete).toBe(true);
    expect(res.body.certificate.fresh).toBe(true);
    const png = await call("GET", `/c/${res.body.certificate.id}.png`);
    expect(png.type).toBe("image/png");
  });

  test("a shell save keeps the fewest fires and the most stars", async () => {
    const one = { current_shift: 2, cleared: [1, 2], tries: { 1: 3, 2: 5 }, stars: { 1: 4, 2: 1 }, cards: ["command", "cat"] };
    const two = { current_shift: 4, cleared: [1, 3, 9], tries: { 1: 6, 3: 2, 9: 1 }, stars: { 1: 2, 2: 3, 3: 9 }, cards: ["cat", "pipe"], junk: 1 };
    // Unknown shifts, out-of-range stars and stray fields are dropped.
    expect(normalize("shell", two)).toEqual({ current_shift: 4, cleared: [1, 3], tries: { 1: 6, 3: 2 }, stars: { 1: 2, 2: 3, 3: 4 }, cards: ["cat", "pipe"] });
    expect(normalize("shell", { current_shift: 7 })).toEqual({ current_shift: 1, cleared: [], tries: {}, stars: {}, cards: [] });
    const both = merge("shell", JSON.stringify(one), two);
    // Both have two shifts cleared, so the first save says where to carry on.
    expect(both).toEqual({ current_shift: 2, cleared: [1, 2, 3], tries: { 1: 3, 2: 5, 3: 2 }, stars: { 1: 4, 2: 3, 3: 4 }, cards: ["command", "cat", "pipe"] });
    const s = summarize("shell", both);
    expect(s.count).toBe(3);
    expect(s.tries).toBe(10);
    expect(s.collected).toBe(11);
    expect(s.collectMax).toBe(20);
    expect(s.xp).toBe(3 * 100 + 11 * 10);
    expect(bestLine("shell", s)).toBe("10 tries");

    // And through the API, from two devices.
    const { token } = await newPlayer();
    let res = await call("PUT", "/api/saves/shell", { token, body: { data: JSON.stringify(one) } });
    expect(res.status).toBe(200);
    res = await call("PUT", "/api/saves/shell", { token, body: { data: JSON.stringify(two) } });
    expect(JSON.parse(res.body.data)).toEqual(both);
    expect(res.body.summary.tries).toBe(10);
    // Clearing all five issues the certificate.
    const all = { current_shift: 5, cleared: [1, 2, 3, 4, 5], tries: { 4: 2, 5: 4 }, stars: { 5: 4 }, cards: [] };
    res = await call("PUT", "/api/saves/shell", { token, body: { data: JSON.stringify(all) } });
    expect(res.body.summary.complete).toBe(true);
    expect(res.body.certificate.fresh).toBe(true);
    const png = await call("GET", `/c/${res.body.certificate.id}.png`);
    expect(png.type).toBe("image/png");
  });

  test("a nothing save keeps the fewest takes and the most stars", async () => {
    const one = { current_episode: 2, cleared: [1, 2], tries: { 1: 8, 2: 9 }, stars: { 1: 4, 2: 2 }, cards: ["request", "path"] };
    const two = { current_episode: 4, cleared: [1, 3, 8], tries: { 1: 5, 3: 4, 8: 1 }, stars: { 1: 3, 2: 4, 3: 7 }, cards: ["path", "post"], junk: 1 };
    // Unknown episodes, out-of-range stars and stray fields are dropped.
    expect(normalize("nothing", two)).toEqual({ current_episode: 4, cleared: [1, 3], tries: { 1: 5, 3: 4 }, stars: { 1: 3, 2: 4, 3: 4 }, cards: ["path", "post"] });
    expect(normalize("nothing", { current_episode: 9 })).toEqual({ current_episode: 1, cleared: [], tries: {}, stars: {}, cards: [] });
    const both = merge("nothing", JSON.stringify(one), two);
    expect(both).toEqual({ current_episode: 2, cleared: [1, 2, 3], tries: { 1: 5, 2: 9, 3: 4 }, stars: { 1: 4, 2: 4, 3: 4 }, cards: ["request", "path", "post"] });
    const s = summarize("nothing", both);
    expect(s.count).toBe(3);
    expect(s.tries).toBe(18);
    expect(s.collected).toBe(12);
    expect(s.collectMax).toBe(20);
    expect(bestLine("nothing", s)).toBe("18 tries");

    // Clearing all five issues the certificate.
    const { token } = await newPlayer();
    const all = { current_episode: 5, cleared: [1, 2, 3, 4, 5], tries: { 1: 4, 2: 4, 3: 4, 4: 4, 5: 4 }, stars: { 5: 4 }, cards: [] };
    const res = await call("PUT", "/api/saves/nothing", { token, body: { data: JSON.stringify(all) } });
    expect(res.status).toBe(200);
    expect(res.body.summary.complete).toBe(true);
    expect(res.body.certificate.fresh).toBe(true);
    const png = await call("GET", `/c/${res.body.certificate.id}.png`);
    expect(png.type).toBe("image/png");
  });

  test("garbage isn't a save", async () => {
    const { token } = await newPlayer();
    expect((await call("PUT", "/api/saves/curb", { token, body: { data: "{nope" } })).status).toBe(400);
    expect((await call("PUT", "/api/saves/zork", { token, body: { data: "{}" } })).status).toBe(404);
    expect((await call("PUT", "/api/saves/curb", { body: { data: curbSave([1]) } })).status).toBe(401);
  });

  test("finishing a game issues one certificate, with a real PNG", async () => {
    const { token, player } = await newPlayer("Lieutenant Fan");
    const all = [1, 2, 3, 4, 5];
    const save = JSON.stringify({ current_case: 5, cleared: all, tries: { 1: 1, 2: 2, 3: 1, 4: 3, 5: 1 }, cards: [] });
    const first = await call("PUT", "/api/saves/lieutenant", { token, body: { data: save } });
    expect(first.body.certificate.fresh).toBe(true);
    expect(first.body.certificate.name).toBe("Lieutenant Fan");
    const again = await call("PUT", "/api/saves/lieutenant", { token, body: { data: save } });
    expect(again.body.certificate.fresh).toBe(false);
    expect(again.body.certificate.id).toBe(first.body.certificate.id);
    const id = first.body.certificate.id;
    const page = await call("GET", `/c/${id}`);
    expect(page.status).toBe(200);
    expect(page.body).toContain('property="og:image" content="https://dunderquest.test/c/');
    expect(page.body).toContain("linkedin.com/profile/add");
    expect(page.body).toContain(`data-owner="${player.id}"`);
    const png = await call("GET", `/c/${id}.png`);
    expect(png.type).toBe("image/png");
    expect([...png.body.slice(1, 4)]).toEqual([0x50, 0x4e, 0x47]);
    // Renaming the player renames the certificate that carried the old name.
    await call("PATCH", "/api/me", { token, body: { name: "Columbo Junior" } });
    const me = await call("GET", "/api/me", { token });
    expect(me.body.certificates[0].name).toBe("Columbo Junior");
    // Each save says when it was last played, for "continue where you left off".
    expect(Object.values(me.body.saves).every((s) => typeof (s as { played: unknown }).played === "number")).toBe(true);
    expect((await call("PATCH", `/api/certificates/${id}`, { token, body: { name: "R. Lancer" } })).body.name).toBe("R. Lancer");
    const other = await newPlayer();
    expect((await call("PATCH", `/api/certificates/${id}`, { token: other.token, body: { name: "Thief" } })).status).toBe(404);
  });
});

describe("leaderboards", () => {
  test("ranked by levels, then fewest tries, and I see my own rank", async () => {
    const fresh = d1(":memory:");
    const saved = env.DB;
    env.DB = fresh;
    try {
      const a = await newPlayer("Alpha Player");
      const b = await newPlayer("Bravo Player");
      const c = await newPlayer("Charlie Player");
      await call("PUT", "/api/saves/curb", { token: a.token, body: { data: curbSave([1, 2], { 1: 5, 2: 5 }) } });
      await call("PUT", "/api/saves/curb", { token: b.token, body: { data: curbSave([1, 2], { 1: 2, 2: 2 }) } });
      await call("PUT", "/api/saves/curb", { token: c.token, body: { data: curbSave([1, 2, 3], { 1: 9, 2: 9, 3: 9 }) } });
      const board = await call("GET", "/api/leaderboard?game=curb", { token: a.token });
      expect(board.body.rows.map((r: { name: string }) => r.name)).toEqual(["Charlie Player", "Bravo Player", "Alpha Player"]);
      expect(board.body.rows[1].line).toBe("4 tries");
      expect(board.body.me.rank).toBe(3);
      expect(board.body.players).toBe(3);
      const all = await call("GET", "/api/leaderboard?game=all", { token: b.token });
      expect(all.body.rows[0].name).toBe("Charlie Player");
      expect(all.body.me.rank).toBe(2);
      expect((await call("GET", "/api/leaderboard?game=zork")).status).toBe(404);
    } finally {
      env.DB = saved;
    }
  });
});

describe("screenshots", () => {
  // A 1x1 PNG.
  const PNG = Uint8Array.from(atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="), (c) => c.charCodeAt(0));

  test("upload, view with its own preview, and delete", async () => {
    const { token, player } = await newPlayer("Shutter Bug");
    const form = new FormData();
    form.set("game", "prince");
    form.set("caption", "Sealed my first commit!\u0000");
    form.set("image", new File([PNG], "shot.png", { type: "image/png" }));
    const res = await call("POST", "/api/shots", { token, body: form });
    expect(res.status).toBe(201);
    expect(res.body.caption).toBe("Sealed my first commit!");
    const page = await call("GET", res.body.url);
    expect(page.body).toContain(`<meta property="og:image" content="https://dunderquest.test/s/${res.body.id}.png">`);
    expect(page.body).toContain('<meta property="og:image:width" content="1">');
    expect(page.body).toContain("Shutter Bug");
    const img = await call("GET", res.body.image);
    expect(img.type).toBe("image/png");
    expect(img.body.length).toBe(PNG.length);
    const other = await newPlayer();
    expect((await call("DELETE", `/api/shots/${res.body.id}`, { token: other.token })).status).toBe(404);
    expect((await call("DELETE", `/api/shots/${res.body.id}`, { token })).status).toBe(200);
    expect((await call("GET", res.body.url)).status).toBe(404);
    expect(player.id).toBeTruthy();
  });

  test("only PNG and JPEG", async () => {
    const { token } = await newPlayer();
    const form = new FormData();
    form.set("game", "prince");
    form.set("image", new File([new TextEncoder().encode("<svg/>")], "x.svg", { type: "image/svg+xml" }));
    expect((await call("POST", "/api/shots", { token, body: form })).status).toBe(400);
  });
});

describe("profiles", () => {
  test("a public profile with a card image", async () => {
    const { token, player } = await newPlayer("Profile Person");
    await call("PUT", "/api/saves/prince", { token, body: { data: JSON.stringify({ cleared: { 1: 30.5, 2: 41 } }) } });
    const page = await call("GET", `/u/${player.id}`);
    expect(page.status).toBe(200);
    expect(page.body).toContain("Profile Person");
    expect(page.body).toContain("2 of 5 rooms");
    expect(page.body).toContain(`/u/${player.id}.png?v=`);
    const png = await call("GET", `/u/${player.id}.png`);
    expect(png.type).toBe("image/png");
  });
});

describe("google", () => {
  let keys: CryptoKeyPair;
  const KID = "test-key";

  beforeAll(async () => {
    keys = (await crypto.subtle.generateKey(
      { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
      true, ["sign", "verify"],
    )) as CryptoKeyPair;
    const jwk = { ...(await crypto.subtle.exportKey("jwk", keys.publicKey)), kid: KID, alg: "RS256", use: "sig" };
    const real = globalThis.fetch;
    globalThis.fetch = mock(async (input: RequestInfo | URL, init?: RequestInit) => {
      if (String(input).startsWith("https://www.googleapis.com/oauth2/v3/certs")) {
        return new Response(JSON.stringify({ keys: [jwk] }), { headers: { "Cache-Control": "max-age=600" } });
      }
      return real(input, init);
    }) as unknown as typeof fetch;
  });

  const b64 = (v: string | Uint8Array) => Buffer.from(v).toString("base64url");
  async function idToken(sub: string, overrides: Record<string, unknown> = {}) {
    const head = b64(JSON.stringify({ alg: "RS256", kid: KID, typ: "JWT" }));
    const body = b64(JSON.stringify({ iss: "https://accounts.google.com", aud: CLIENT_ID, sub, exp: Math.floor(Date.now() / 1000) + 600, ...overrides }));
    const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", keys.privateKey, new TextEncoder().encode(`${head}.${body}`)));
    return `${head}.${body}.${b64(sig)}`;
  }

  test("signing in on a second device brings that device's progress along", async () => {
    // Device one: plays, then links Google.
    const one = await newPlayer("Device One");
    await call("PUT", "/api/saves/curb", { token: one.token, body: { data: curbSave([1, 2]) } });
    const link = await call("POST", "/api/auth/google", { token: one.token, body: { credential: await idToken("sub-123") } });
    expect(link.status).toBe(200);
    expect(link.body.token).toBe("");
    expect(link.body.player.id).toBe(one.player.id);
    // Device two: plays anonymously, then signs in with the same Google account.
    const two = await newPlayer("Device Two");
    await call("PUT", "/api/saves/curb", { token: two.token, body: { data: curbSave([3]) } });
    await call("PUT", "/api/saves/prince", { token: two.token, body: { data: JSON.stringify({ cleared: { 1: 12 } }) } });
    const signIn = await call("POST", "/api/auth/google", { token: two.token, body: { credential: await idToken("sub-123") } });
    expect(signIn.body.player.id).toBe(one.player.id);
    expect(signIn.body.token).toBeTruthy();
    const me = await call("GET", "/api/me", { token: signIn.body.token });
    expect(me.body.saves.curb.cleared).toEqual([1, 2, 3]);
    expect(me.body.saves.prince.count).toBe(1);
    expect(me.body.player.google).toBe(true);
    // Device two's anonymous player is gone.
    expect((await call("GET", "/api/me", { token: two.token })).status).toBe(401);
    // A fresh browser signing in gets the account.
    const fresh = await call("POST", "/api/auth/google", { body: { credential: await idToken("sub-123") } });
    expect(fresh.body.player.id).toBe(one.player.id);
  });

  test("forged, expired or foreign tokens are refused", async () => {
    expect((await call("POST", "/api/auth/google", { body: { credential: await idToken("x", { aud: "someone-else" }) } })).status).toBe(401);
    expect((await call("POST", "/api/auth/google", { body: { credential: await idToken("x", { exp: 1000 }) } })).status).toBe(401);
    expect((await call("POST", "/api/auth/google", { body: { credential: await idToken("x", { iss: "evil.com" }) } })).status).toBe(401);
    const good = await idToken("x");
    const forged = good.slice(0, good.lastIndexOf(".") + 1) + b64(new Uint8Array(256));
    expect((await call("POST", "/api/auth/google", { body: { credential: forged } })).status).toBe(401);
  });
});

describe("feedback", () => {
  type Row = { id: string; player_id: string | null; game: string; kind: string; rating: number | null; message: string; contact: string; page: string; context: string; agent: string; status: string };
  const row = (id: string) => env.DB.prepare("SELECT * FROM feedback WHERE id = ?").bind(id).first<Row>();

  test("anyone can send it, guest or player, and it's kept cleaned", async () => {
    const guest = await call("POST", "/api/feedback", {
      body: { game: "curb", kind: "bug", rating: 4, message: "  Scene 3\r\n\r\n\r\n\r\nwon't load\u0007 ", contact: "me@example.com\nhi", page: "https://evil.example/curb/play/?x=1", context: "Last cleared: The Regift" },
    });
    expect(guest.status).toBe(201);
    const kept = await row(guest.body.id);
    expect(kept).toMatchObject({ player_id: null, game: "curb", kind: "bug", rating: 4, message: "Scene 3\n\nwon't load", contact: "me@example.com hi", page: "/curb/play/", context: "Last cleared: The Regift", status: "new" });
    const { token, player } = await newPlayer("Feedback Fan");
    const mine = await call("POST", "/api/feedback", { token, body: { kind: "idea", message: "More games please", rating: 9 } });
    expect(mine.status).toBe(201);
    expect(await row(mine.body.id)).toMatchObject({ player_id: player.id, game: "", kind: "idea", rating: null });
  });

  test("an empty message or an unknown game is refused, an unknown kind is 'other'", async () => {
    expect((await call("POST", "/api/feedback", { body: { message: " a " } })).status).toBe(400);
    expect((await call("POST", "/api/feedback", { body: { game: "nope", message: "hello there" } })).status).toBe(400);
    const odd = await call("POST", "/api/feedback", { body: { kind: "rant", message: "hello there" } });
    expect((await row(odd.body.id))?.kind).toBe("other");
  });

  test("a bot that fills in the hidden box is thanked and nothing is kept", async () => {
    const before = await env.DB.prepare("SELECT COUNT(*) AS n FROM feedback").first<{ n: number }>();
    const bot = await call("POST", "/api/feedback", { body: { message: "buy cheap things", website: "http://spam.example" } });
    expect(bot.status).toBe(201);
    const after = await env.DB.prepare("SELECT COUNT(*) AS n FROM feedback").first<{ n: number }>();
    expect(after?.n).toBe(before?.n);
  });

  test("with Turnstile set up, the token is checked with Cloudflare before anything is kept", async () => {
    const realFetch = globalThis.fetch;
    const asked: { secret: string; response: string }[] = [];
    globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input instanceof Request ? input.url : input);
      if (!url.startsWith("https://challenges.cloudflare.com/turnstile/v0/siteverify")) return realFetch(input, init);
      const form = init?.body as FormData;
      const sent = { secret: String(form.get("secret")), response: String(form.get("response")) };
      asked.push(sent);
      return Response.json({ success: sent.response === "good-token" });
    }) as typeof fetch;
    env.TURNSTILE_SITE_KEY = "site-key";
    env.TURNSTILE_SECRET = "secret-key";
    try {
      expect((await call("GET", "/api/config")).body.turnstile).toBe("site-key");
      const count = async () => (await env.DB.prepare("SELECT COUNT(*) AS n FROM feedback").first<{ n: number }>())?.n;
      const before = await count();
      expect((await call("POST", "/api/feedback", { body: { message: "no token at all" } })).status).toBe(403);
      expect((await call("POST", "/api/feedback", { body: { message: "a bad token", turnstile: "bad-token" } })).status).toBe(403);
      expect(await count()).toBe(before);
      const ok = await call("POST", "/api/feedback", { body: { message: "a good token", turnstile: "good-token" } });
      expect(ok.status).toBe(201);
      expect(asked.at(-1)).toEqual({ secret: "secret-key", response: "good-token" });
      expect(asked.length).toBe(2);
    } finally {
      globalThis.fetch = realFetch;
      env.TURNSTILE_SITE_KEY = "";
      env.TURNSTILE_SECRET = "";
    }
    // Without a secret, the site key isn't handed out, and nothing is checked.
    env.TURNSTILE_SITE_KEY = "site-key";
    expect((await call("GET", "/api/config")).body.turnstile).toBe("");
    expect((await call("POST", "/api/feedback", { body: { message: "no Turnstile yet" } })).status).toBe(201);
    env.TURNSTILE_SITE_KEY = "";
  });

  test("deleting a player deletes their feedback", async () => {
    const { token } = await newPlayer();
    const sent = await call("POST", "/api/feedback", { token, body: { message: "Forget me later" } });
    expect(await row(sent.body.id)).not.toBeNull();
    expect((await call("DELETE", "/api/me", { token })).status).toBe(200);
    expect(await row(sent.body.id)).toBeNull();
  });
});
