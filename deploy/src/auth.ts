// Who is asking. A player is a random id and a secret the browser keeps in
// localStorage; it travels as `Authorization: Bearer <token>`. Nobody has to
// sign up: the first time a game saves, the page makes a player with a silly
// name. Signing in with Google only ties that player to a Google account, so
// the same progress follows them to another device. The server keeps a
// SHA-256 of each token, never the token itself, and of Google keeps only the
// account's opaque `sub`: no email, no name, no picture.

import { type Env, type PlayerRow, now, randomId } from "./db";

export async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function base64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64url(text: string): Uint8Array {
  const s = atob(text.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((text.length + 3) % 4));
  return Uint8Array.from(s, (c) => c.charCodeAt(0));
}

/** A new token for a player, stored hashed. */
export async function issueToken(env: Env, playerId: string): Promise<string> {
  const token = `${playerId}.${base64url(crypto.getRandomValues(new Uint8Array(24)))}`;
  const t = now();
  await env.DB.prepare("INSERT INTO tokens (hash, player_id, created_at, used_at) VALUES (?, ?, ?, ?)")
    .bind(await sha256(token), playerId, t, t)
    .run();
  return token;
}

export function bearer(request: Request): string {
  const header = request.headers.get("Authorization") ?? "";
  return header.startsWith("Bearer ") ? header.slice(7).trim() : "";
}

/** The player behind the request's token, or null. */
export async function authenticate(request: Request, env: Env): Promise<PlayerRow | null> {
  const token = bearer(request);
  if (!token || token.length > 100) return null;
  const hash = await sha256(token);
  const row = await env.DB.prepare(
    "SELECT p.*, t.used_at AS token_used FROM tokens t JOIN players p ON p.id = t.player_id WHERE t.hash = ?",
  ).bind(hash).first<PlayerRow & { token_used: number }>();
  if (!row) return null;
  // Touch the token at most once a day, to keep writes down.
  const t = now();
  if (t - row.token_used > 86400) {
    await env.DB.prepare("UPDATE tokens SET used_at = ? WHERE hash = ?").bind(t, hash).run();
  }
  const { token_used: _, ...player } = row;
  return player;
}

export async function revokeToken(request: Request, env: Env): Promise<void> {
  const token = bearer(request);
  if (token) await env.DB.prepare("DELETE FROM tokens WHERE hash = ?").bind(await sha256(token)).run();
}

export async function createPlayer(env: Env, name: string, googleSub: string | null = null): Promise<PlayerRow> {
  const t = now();
  const player: PlayerRow = {
    id: randomId(10), name, google_sub: googleSub, xp: 0, levels: 0, completed: 0,
    reached_at: t, created_at: t, updated_at: t, hidden: 0,
  };
  await env.DB.prepare(
    "INSERT INTO players (id, name, google_sub, xp, levels, completed, reached_at, created_at, updated_at) VALUES (?, ?, ?, 0, 0, 0, ?, ?, ?)",
  ).bind(player.id, name, googleSub, t, t, t).run();
  return player;
}

// Google's signing keys, cached for as long as Google says they're good.
type Jwk = JsonWebKey & { kid: string };
let googleKeys: { keys: Jwk[]; until: number } | null = null;

async function googleKey(kid: string): Promise<CryptoKey | null> {
  if (!googleKeys || googleKeys.until < Date.now() || !googleKeys.keys.some((k) => k.kid === kid)) {
    const res = await fetch("https://www.googleapis.com/oauth2/v3/certs");
    if (!res.ok) return null;
    const age = /max-age=(\d+)/.exec(res.headers.get("Cache-Control") ?? "");
    const body = (await res.json()) as { keys: Jwk[] };
    googleKeys = { keys: body.keys, until: Date.now() + (age ? Number(age[1]) * 1000 : 3600_000) };
  }
  const jwk = googleKeys.keys.find((k) => k.kid === kid);
  if (!jwk) return null;
  return crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
}

/**
 * The Google account `sub` in a Sign in with Google ID token, once its
 * signature, issuer, audience and expiry check out; otherwise null.
 */
export async function verifyGoogle(credential: string, clientId: string): Promise<string | null> {
  const parts = credential.split(".");
  if (parts.length !== 3 || !clientId) return null;
  try {
    const header = JSON.parse(new TextDecoder().decode(fromBase64url(parts[0])));
    const payload = JSON.parse(new TextDecoder().decode(fromBase64url(parts[1])));
    if (header.alg !== "RS256" || typeof header.kid !== "string") return null;
    const key = await googleKey(header.kid);
    if (!key) return null;
    const ok = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5", key, fromBase64url(parts[2]), new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
    );
    if (!ok) return null;
    if (payload.iss !== "accounts.google.com" && payload.iss !== "https://accounts.google.com") return null;
    if (payload.aud !== clientId) return null;
    if (typeof payload.exp !== "number" || payload.exp * 1000 < Date.now()) return null;
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}
