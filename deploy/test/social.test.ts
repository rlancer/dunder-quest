// The social API end to end, on an in-memory SQLite standing in for D1:
// bun test deploy/test

import { afterAll, beforeAll, describe, expect, mock, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { assets, d1 } from "../dev";
import worker, { type Env } from "../src/worker";

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
