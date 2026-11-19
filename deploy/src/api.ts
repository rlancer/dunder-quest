// The JSON API under /api/. Everything a page or a game needs: making a
// player, signing in with Google, cloud saves, leaderboards, certificates and
// screenshots. See deploy/README.md for the list.

import {
  GAMES, ORDER, bestLine, merge, normalize, randomName, summarize,
} from "../../site/static/social/games.js";
import { authenticate, createPlayer, issueToken, revokeToken, verifyGoogle } from "./auth";
import { type CertRow, type Env, type PlayerRow, type SaveRow, type ShotRow, now, randomId } from "./db";
import { allowedName } from "./names";

type Game = keyof typeof GAMES;
type Summary = ReturnType<typeof summarize>;

export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...headers },
  });
}

const fail = (status: number, error: string) => json({ error }, status);

function isGame(game: string): game is Game {
  return Object.hasOwn(GAMES, game);
}

async function body<T>(request: Request): Promise<Partial<T>> {
  try {
    const value = await request.json();
    return value && typeof value === "object" ? (value as Partial<T>) : {};
  } catch {
    return {};
  }
}

/** Over the per-IP write limit? Always false where no limiter is bound (local runs). */
async function limited(request: Request, env: Env, key: string): Promise<boolean> {
  if (!env.WRITE_LIMITER) return false;
  const ip = request.headers.get("CF-Connecting-IP") ?? "local";
  const { success } = await env.WRITE_LIMITER.limit({ key: `${key}:${ip}` });
  return !success;
}

/** What anyone may see of a player. */
export function publicPlayer(p: PlayerRow) {
  return { id: p.id, name: p.name, xp: p.xp, levels: p.levels, completed: p.completed, since: p.created_at };
}

function summaryOf(row: SaveRow): Summary {
  return summarize(row.game as Game, row.data);
}

export async function savesOf(env: Env, playerId: string): Promise<SaveRow[]> {
  const { results } = await env.DB.prepare("SELECT * FROM saves WHERE player_id = ?").bind(playerId).all<SaveRow>();
  return results.sort((a, b) => ORDER.indexOf(a.game) - ORDER.indexOf(b.game));
}

export async function certsOf(env: Env, playerId: string): Promise<CertRow[]> {
  const { results } = await env.DB.prepare(
    "SELECT id, player_id, game, name, issued_at, stats FROM certificates WHERE player_id = ? ORDER BY issued_at",
  ).bind(playerId).all<CertRow>();
  return results;
}

async function shotsOf(env: Env, playerId: string): Promise<ShotRow[]> {
  const { results } = await env.DB.prepare(
    "SELECT id, player_id, game, caption, type, width, height, created_at FROM shots WHERE player_id = ? ORDER BY created_at DESC LIMIT 60",
  ).bind(playerId).all<ShotRow>();
  return results;
}

export function certJson(c: CertRow) {
  return { id: c.id, game: c.game, name: c.name, issued: c.issued_at, stats: JSON.parse(c.stats) };
}

function shotJson(s: ShotRow) {
  const ext = s.type === "image/png" ? "png" : "jpg";
  return { id: s.id, game: s.game, caption: s.caption, url: `/s/${s.id}`, image: `/s/${s.id}.${ext}`, created: s.created_at };
}

/** Sums every game's save onto the player row, the overall leaderboard's source. */
async function retotal(env: Env, player: PlayerRow): Promise<PlayerRow> {
  const totals = await env.DB.prepare(
    "SELECT COALESCE(SUM(xp), 0) AS xp, COALESCE(SUM(count), 0) AS levels, COALESCE(SUM(complete), 0) AS completed FROM saves WHERE player_id = ?",
  ).bind(player.id).first<{ xp: number; levels: number; completed: number }>();
  const t = now();
  const xp = totals?.xp ?? 0;
  const reached = xp > player.xp ? t : player.reached_at;
  await env.DB.prepare("UPDATE players SET xp = ?, levels = ?, completed = ?, reached_at = ?, updated_at = ? WHERE id = ?")
    .bind(xp, totals?.levels ?? 0, totals?.completed ?? 0, reached, t, player.id).run();
  return { ...player, xp, levels: totals?.levels ?? 0, completed: totals?.completed ?? 0, reached_at: reached, updated_at: t };
}

/** Stores a merged save and issues the game's certificate once it's finished. */
async function storeSave(env: Env, player: PlayerRow, game: Game, incoming: unknown) {
  const stored = await env.DB.prepare("SELECT * FROM saves WHERE player_id = ? AND game = ?")
    .bind(player.id, game).first<SaveRow>();
  const merged = merge(game, stored?.data ?? null, incoming);
  if (!merged) return null;
  const data = JSON.stringify(merged);
  const s = summarize(game, merged);
  const t = now();
  let changed = false;
  if (!stored || stored.data !== data) {
    changed = true;
    const reached = !stored || s.count > stored.count ? t : stored.reached_at;
    await env.DB.prepare(
      `INSERT INTO saves (player_id, game, data, count, complete, time, tries, collected, xp, reached_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (player_id, game) DO UPDATE SET data = excluded.data, count = excluded.count,
         complete = excluded.complete, time = excluded.time, tries = excluded.tries, collected = excluded.collected,
         xp = excluded.xp, reached_at = excluded.reached_at, updated_at = excluded.updated_at`,
    ).bind(player.id, game, data, s.count, s.complete ? 1 : 0, s.time, s.tries, s.collected, s.xp, reached, t).run();
    player = await retotal(env, player);
  }
  let certificate: (ReturnType<typeof certJson> & { fresh: boolean }) | null = null;
  if (s.complete) {
    const existing = await env.DB.prepare(
      "SELECT id, player_id, game, name, issued_at, stats FROM certificates WHERE player_id = ? AND game = ?",
    ).bind(player.id, game).first<CertRow>();
    const stats = JSON.stringify({ levels: s.count, time: s.time, tries: s.tries, collected: s.collected, collectMax: s.collectMax });
    if (existing) {
      // A better run later improves the stats on the certificate, never the date.
      if (existing.stats !== stats) {
        await env.DB.prepare("UPDATE certificates SET stats = ?, png = NULL WHERE id = ?").bind(stats, existing.id).run();
        existing.stats = stats;
      }
      certificate = { ...certJson(existing), fresh: false };
    } else {
      const cert: CertRow = { id: randomId(8), player_id: player.id, game, name: player.name, issued_at: t, stats };
      await env.DB.prepare("INSERT INTO certificates (id, player_id, game, name, issued_at, stats) VALUES (?, ?, ?, ?, ?, ?)")
        .bind(cert.id, cert.player_id, cert.game, cert.name, cert.issued_at, cert.stats).run();
      certificate = { ...certJson(cert), fresh: true };
    }
  }
  return { data, summary: s, certificate, player, changed };
}

/** Moves everything one player owns onto another (signing in with Google on a second device). */
async function absorb(env: Env, from: PlayerRow, into: PlayerRow): Promise<PlayerRow> {
  // Certificates first, so the earlier date of the two survives the merge.
  await env.DB.batch([
    env.DB.prepare("UPDATE shots SET player_id = ? WHERE player_id = ?").bind(into.id, from.id),
    // A certificate only moves if the other player has none for that game.
    env.DB.prepare(
      "UPDATE certificates SET player_id = ? WHERE player_id = ? AND game NOT IN (SELECT game FROM certificates WHERE player_id = ?)",
    ).bind(into.id, from.id, into.id),
    env.DB.prepare("DELETE FROM certificates WHERE player_id = ?").bind(from.id),
  ]);
  for (const row of await savesOf(env, from.id)) {
    const result = await storeSave(env, into, row.game as Game, row.data);
    if (result) into = result.player;
  }
  await env.DB.batch([
    env.DB.prepare("DELETE FROM saves WHERE player_id = ?").bind(from.id),
    env.DB.prepare("DELETE FROM tokens WHERE player_id = ?").bind(from.id),
    env.DB.prepare("DELETE FROM players WHERE id = ?").bind(from.id),
  ]);
  return into;
}

// ---- Leaderboards ----

type BoardRow = {
  rank: number; id: string; name: string; xp: number; count: number; total: number; complete: boolean; line: string;
};

const OVERALL_TOTAL = ORDER.reduce((n, g) => n + GAMES[g as Game].levels.length, 0);

export async function leaderboard(env: Env, game: string, limit: number, me: PlayerRow | null) {
  limit = Math.max(1, Math.min(100, limit || 25));
  if (game === "all") {
    const { results } = await env.DB.prepare(
      "SELECT id, name, xp, levels, completed, reached_at FROM players WHERE hidden = 0 AND xp > 0 ORDER BY xp DESC, reached_at ASC LIMIT ?",
    ).bind(limit).all<PlayerRow>();
    const rows: BoardRow[] = results.map((p, i) => ({
      rank: i + 1, id: p.id, name: p.name, xp: p.xp, count: p.levels, total: OVERALL_TOTAL, complete: p.levels === OVERALL_TOTAL,
      line: p.completed ? `${p.completed} ${p.completed === 1 ? "game" : "games"} finished` : "",
    }));
    const players = await env.DB.prepare("SELECT COUNT(*) AS n FROM players WHERE hidden = 0 AND xp > 0").first<{ n: number }>();
    let mine = null;
    if (me && me.xp > 0 && !me.hidden) {
      const better = await env.DB.prepare(
        "SELECT COUNT(*) AS n FROM players WHERE hidden = 0 AND xp > 0 AND (xp > ? OR (xp = ? AND reached_at < ?))",
      ).bind(me.xp, me.xp, me.reached_at).first<{ n: number }>();
      mine = {
        rank: (better?.n ?? 0) + 1, id: me.id, name: me.name, xp: me.xp, count: me.levels, total: OVERALL_TOTAL,
        complete: me.levels === OVERALL_TOTAL, line: me.completed ? `${me.completed} ${me.completed === 1 ? "game" : "games"} finished` : "",
      };
    }
    return { game, rows, me: mine, players: players?.n ?? 0 };
  }
  if (!isGame(game)) return null;
  const metric = GAMES[game].best === "tries" ? "tries" : "time";
  const order = `s.count DESC, (s.${metric} <= 0) ASC, s.${metric} ASC, s.reached_at ASC`;
  const { results } = await env.DB.prepare(
    `SELECT s.*, p.name FROM saves s JOIN players p ON p.id = s.player_id
     WHERE s.game = ? AND s.count > 0 AND p.hidden = 0 ORDER BY ${order} LIMIT ?`,
  ).bind(game, limit).all<SaveRow & { name: string }>();
  const toRow = (r: SaveRow & { name: string }, rank: number): BoardRow => {
    const s = summaryOf(r);
    return { rank, id: r.player_id, name: r.name, xp: r.xp, count: r.count, total: s.total, complete: s.complete, line: bestLine(game, s) };
  };
  const rows = results.map((r, i) => toRow(r, i + 1));
  const players = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM saves s JOIN players p ON p.id = s.player_id WHERE s.game = ? AND s.count > 0 AND p.hidden = 0",
  ).bind(game).first<{ n: number }>();
  let mine = null;
  if (me && !me.hidden) {
    const own = await env.DB.prepare("SELECT * FROM saves WHERE player_id = ? AND game = ? AND count > 0")
      .bind(me.id, game).first<SaveRow>();
    if (own) {
      const m = own[metric];
      const none = m <= 0 ? 1 : 0;
      const better = await env.DB.prepare(
        `SELECT COUNT(*) AS n FROM saves s JOIN players p ON p.id = s.player_id
         WHERE s.game = ?1 AND s.count > 0 AND p.hidden = 0 AND (s.count > ?2 OR (s.count = ?2 AND (
           (s.${metric} <= 0) < ?3 OR ((s.${metric} <= 0) = ?3 AND (s.${metric} < ?4 OR (s.${metric} = ?4 AND s.reached_at < ?5))))))`,
      ).bind(game, own.count, none, m, own.reached_at).first<{ n: number }>();
      mine = toRow({ ...own, name: me.name }, (better?.n ?? 0) + 1);
    }
  }
  return { game, rows, me: mine, players: players?.n ?? 0 };
}

// ---- Screenshots ----

/** The width and height in a PNG's or a JPEG's header, or null if it's neither. */
export function imageSize(bytes: Uint8Array): { type: string; width: number; height: number } | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (bytes.length > 24 && view.getUint32(0) === 0x89504e47 && view.getUint32(4) === 0x0d0a1a0a) {
    return { type: "image/png", width: view.getUint32(16), height: view.getUint32(20) };
  }
  if (bytes.length > 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    let i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] !== 0xff) return null;
      const marker = bytes[i + 1];
      const size = view.getUint16(i + 2);
      // Start-of-frame markers carry the size; DHT (C4), JPG (C8) and DAC (CC) don't.
      if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
        return { type: "image/jpeg", height: view.getUint16(i + 5), width: view.getUint16(i + 7) };
      }
      i += 2 + size;
    }
  }
  return null;
}

/** D1 keeps a row under 2 MB; a 1200x630 card is a few hundred KB. */
const MAX_SHOT = 1_500_000;
const MAX_SHOTS_PER_PLAYER = 200;

function cleanCaption(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw.normalize("NFKC").replace(/[\p{Cc}\p{Cf}]/gu, (c) => (c === "\n" ? "\n" : "")).replace(/\n{3,}/g, "\n\n").trim().slice(0, 280);
}

async function postShot(request: Request, env: Env, me: PlayerRow): Promise<Response> {
  if (await limited(request, env, "shot")) return fail(429, "Too many screenshots at once. Try again in a minute.");
  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return fail(400, "Send the screenshot as a form.");
  }
  const game = String(form.get("game") ?? "");
  if (!isGame(game)) return fail(400, "Unknown game.");
  const file = form.get("image");
  if (!file || typeof file === "string") return fail(400, "No image.");
  if (file.size > MAX_SHOT) return fail(413, "That image is too big.");
  const bytes = new Uint8Array(await file.arrayBuffer());
  const info = imageSize(bytes);
  if (!info || info.width > 4096 || info.height > 4096 || !info.width || !info.height) return fail(400, "Send a PNG or a JPEG.");
  const count = await env.DB.prepare("SELECT COUNT(*) AS n FROM shots WHERE player_id = ?").bind(me.id).first<{ n: number }>();
  if ((count?.n ?? 0) >= MAX_SHOTS_PER_PLAYER) return fail(409, "You have a lot of screenshots! Delete some on your profile first.");
  const shot: ShotRow = {
    id: randomId(10), player_id: me.id, game, caption: cleanCaption(form.get("caption")), type: info.type,
    width: info.width, height: info.height, created_at: now(),
  };
  await env.DB.prepare(
    "INSERT INTO shots (id, player_id, game, caption, type, image, width, height, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
  ).bind(shot.id, shot.player_id, shot.game, shot.caption, shot.type, bytes, shot.width, shot.height, shot.created_at).run();
  return json(shotJson(shot), 201);
}

// ---- The router ----

export async function handleApi(request: Request, env: Env, url: URL): Promise<Response> {
  const path = url.pathname.replace(/\/+$/, "");
  const method = request.method;
  const me = await authenticate(request, env);
  const signedIn = () => (me ? null : fail(401, "Not signed in."));

  if (path === "/api/config" && method === "GET") {
    return json({ google: env.GOOGLE_CLIENT_ID ?? "", games: ORDER });
  }

  if (path === "/api/players" && method === "POST") {
    if (await limited(request, env, "player")) return fail(429, "Too many new players from here. Try again in a minute.");
    const { name } = await body<{ name: string }>(request);
    const player = await createPlayer(env, allowedName(name) || randomName());
    return json({ token: await issueToken(env, player.id), player: { ...publicPlayer(player), google: false } }, 201);
  }

  if (path === "/api/me") {
    if (method === "GET") {
      if (!me) return fail(401, "Not signed in.");
      const saves = await savesOf(env, me.id);
      return json({
        player: { ...publicPlayer(me), google: Boolean(me.google_sub) },
        saves: Object.fromEntries(saves.map((r) => [r.game, summaryOf(r)])),
        certificates: (await certsOf(env, me.id)).map(certJson),
        shots: (await shotsOf(env, me.id)).map(shotJson),
      });
    }
    if (method === "PATCH") {
      if (!me) return fail(401, "Not signed in.");
      const { name } = await body<{ name: string }>(request);
      const clean = allowedName(name);
      if (!clean) return fail(400, "Pick a name of 2 to 32 letters, and keep it friendly.");
      // Certificates that still carry the old name follow the new one.
      await env.DB.batch([
        env.DB.prepare("UPDATE players SET name = ?, updated_at = ? WHERE id = ?").bind(clean, now(), me.id),
        env.DB.prepare("UPDATE certificates SET name = ?, png = NULL WHERE player_id = ? AND name = ?").bind(clean, me.id, me.name),
      ]);
      return json({ player: { ...publicPlayer({ ...me, name: clean }), google: Boolean(me.google_sub) } });
    }
    if (method === "DELETE") {
      if (!me) return fail(401, "Not signed in.");
      await env.DB.batch(["shots", "certificates", "saves", "tokens"].map((table) =>
        env.DB.prepare(`DELETE FROM ${table} WHERE player_id = ?`).bind(me.id)).concat(
        env.DB.prepare("DELETE FROM players WHERE id = ?").bind(me.id),
      ));
      return json({ deleted: true });
    }
  }

  if (path === "/api/auth/google" && method === "POST") {
    const clientId = env.GOOGLE_CLIENT_ID ?? "";
    if (!clientId) return fail(503, "Google sign-in isn't set up yet.");
    const { credential } = await body<{ credential: string }>(request);
    const sub = typeof credential === "string" ? await verifyGoogle(credential, clientId) : null;
    if (!sub) return fail(401, "Google didn't vouch for that sign-in. Try again.");
    let player = await env.DB.prepare("SELECT * FROM players WHERE google_sub = ?").bind(sub).first<PlayerRow>();
    let token: string;
    if (player && me && player.id !== me.id) {
      // This device's progress joins the account's.
      player = await absorb(env, me, player);
      token = await issueToken(env, player.id);
    } else if (player) {
      token = me && me.id === player.id ? "" : await issueToken(env, player.id);
    } else if (me) {
      await env.DB.prepare("UPDATE players SET google_sub = ?, updated_at = ? WHERE id = ?").bind(sub, now(), me.id).run();
      player = { ...me, google_sub: sub };
      token = "";
    } else {
      player = await createPlayer(env, randomName(), sub);
      token = await issueToken(env, player.id);
    }
    return json({ token, player: { ...publicPlayer(player), google: true } });
  }

  if (path === "/api/auth/logout" && method === "POST") {
    await revokeToken(request, env);
    return json({ ok: true });
  }

  if (path === "/api/saves" && method === "GET") {
    const err = signedIn();
    if (err || !me) return err!;
    const saves = await savesOf(env, me.id);
    return json({ saves: Object.fromEntries(saves.map((r) => [r.game, { data: r.data, summary: summaryOf(r) }])) });
  }

  const saveMatch = /^\/api\/saves\/([a-z-]+)$/.exec(path);
  if (saveMatch && method === "PUT") {
    const err = signedIn();
    if (err || !me) return err!;
    const game = saveMatch[1];
    if (!isGame(game)) return fail(404, "Unknown game.");
    const { data } = await body<{ data: unknown }>(request);
    if (!normalize(game, data as string)) return fail(400, "That isn't a save for this game.");
    const result = await storeSave(env, me, game, data);
    if (!result) return fail(400, "That isn't a save for this game.");
    const board = await leaderboard(env, game, 1, result.player);
    return json({
      data: result.data, summary: result.summary, certificate: result.certificate, rank: board?.me?.rank ?? null,
      player: { ...publicPlayer(result.player), google: Boolean(result.player.google_sub) },
    });
  }

  if (path === "/api/leaderboard" && method === "GET") {
    const board = await leaderboard(env, url.searchParams.get("game") ?? "all", Number(url.searchParams.get("limit")), me);
    if (!board) return fail(404, "Unknown game.");
    return json(board, 200, { "Cache-Control": me ? "no-store" : "public, max-age=30" });
  }

  if (path === "/api/feed" && method === "GET") {
    const { results } = await env.DB.prepare(
      `SELECT c.id, c.player_id, c.game, c.name, c.issued_at, c.stats FROM certificates c
       JOIN players p ON p.id = c.player_id WHERE p.hidden = 0 ORDER BY c.issued_at DESC LIMIT 12`,
    ).all<CertRow>();
    return json({ certificates: results.map((c) => ({ ...certJson(c), player: c.player_id })) }, 200, { "Cache-Control": "public, max-age=60" });
  }

  const certMatch = /^\/api\/certificates\/([a-z0-9]+)$/.exec(path);
  if (certMatch && method === "PATCH") {
    const err = signedIn();
    if (err || !me) return err!;
    const { name } = await body<{ name: string }>(request);
    const clean = allowedName(name);
    if (!clean) return fail(400, "Pick a name of 2 to 32 letters, and keep it friendly.");
    const res = await env.DB.prepare("UPDATE certificates SET name = ?, png = NULL WHERE id = ? AND player_id = ?")
      .bind(clean, certMatch[1], me.id).run();
    if (!res.meta.changes) return fail(404, "No such certificate of yours.");
    return json({ id: certMatch[1], name: clean });
  }

  if (path === "/api/shots" && method === "POST") {
    if (!me) return fail(401, "Not signed in.");
    return postShot(request, env, me);
  }

  const shotMatch = /^\/api\/shots\/([a-z0-9]+)$/.exec(path);
  if (shotMatch && method === "DELETE") {
    if (!me) return fail(401, "Not signed in.");
    const res = await env.DB.prepare("DELETE FROM shots WHERE id = ? AND player_id = ?").bind(shotMatch[1], me.id).run();
    if (!res.meta.changes) return fail(404, "No such screenshot of yours.");
    return json({ deleted: true });
  }

  return fail(404, "No such API.");
}
