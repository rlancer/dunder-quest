// The browser's side of the social layer: who this player is, and the
// calls to the API. A player is made the first time it's needed (a game
// saves, a screenshot is shared), with a silly name and no sign-up; the
// token lives in localStorage. Signing in with Google ties it to an account
// so progress follows the player to other devices.

import type { GameKey, Save, Summary } from "./games.ts";

/** A player as the API shows them to themselves. */
export interface Player {
  id: string;
  name: string;
  xp: number;
  levels: number;
  completed: number;
  since: number;
  google: boolean;
}

/** A certificate as the API lists it. */
export interface Certificate {
  id: string;
  game: GameKey;
  name: string;
  issued: number;
  stats: unknown;
}

/** A screenshot as the API lists it. */
export interface Shot {
  id: string;
  game: GameKey;
  caption: string;
  url: string;
  image: string;
  created: number;
}

/** GET /api/me: the player, a summary of each game they've a save for, their certificates and screenshots. */
export interface MeData {
  player: Player;
  saves: Partial<Record<GameKey, Summary & { played?: number }>>;
  certificates: Certificate[];
  shots: Shot[];
}

/** One row of a leaderboard. */
export interface BoardRow {
  rank: number;
  id: string;
  name: string;
  xp: number;
  count: number;
  total: number;
  complete: boolean;
  line: string;
}

/** GET /api/leaderboard: the top rows, how many players there are, and you if you're on it. */
export interface Board {
  game: string;
  rows: BoardRow[];
  players: number;
  me: BoardRow | null;
}

/** GET /api/config. */
export interface Config {
  google: string;
  turnstile?: string;
  games: string[];
}

/** A cloud save: the save and what it adds up to. */
export interface CloudSave {
  data: Save | string;
  summary: Summary;
}

const TOKEN = "dq.token";
const PLAYER = "dq.player";

function store(key: string, value: string | null): void {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    // Private windows can refuse storage; the session still works.
  }
}

function load(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function token(): string {
  return load(TOKEN) || "";
}

/** The player as last seen, without asking the server (for drawing the page quickly). */
export function cachedPlayer(): Player | null {
  try {
    return JSON.parse(load(PLAYER) || "null");
  } catch {
    return null;
  }
}

type Listener = (player: Player | null) => void;

const listeners = new Set<Listener>();

/** Calls `fn(player)` whenever the player changes (signs in, renames, signs out). */
export function onPlayer(fn: Listener): () => boolean {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function setPlayer(player: Player | null, newToken?: string | null): void {
  if (newToken !== undefined) store(TOKEN, newToken || null);
  store(PLAYER, player ? JSON.stringify(player) : null);
  for (const fn of listeners) fn(player);
}

export class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

/**
 * Calls the API. `T` is the shape of the answer, which the server decides:
 * each call site names the one it expects.
 */
export async function api<T = unknown>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = {};
  const t = token();
  if (t) headers.Authorization = `Bearer ${t}`;
  let payload: BodyInit | undefined;
  if (body instanceof FormData) payload = body;
  else if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  let res: Response;
  try {
    res = await fetch(path, { method, headers, body: payload });
  } catch {
    throw new ApiError(0, "Couldn't reach the server. Are you offline?");
  }
  let data: (T & { error?: string }) | null = null;
  try {
    data = (await res.json()) as T & { error?: string };
  } catch {
    // An HTML error page from somewhere in between.
  }
  if (!res.ok) {
    if (res.status === 401 && t) setPlayer(null, null);
    throw new ApiError(res.status, data?.error || `The server said ${res.status}.`);
  }
  return data as T;
}

let config: Promise<Config> | null = null;

/** The server's settings: the Google client ID, if sign-in is set up. */
export function getConfig(): Promise<Config> {
  if (!config) config = api<Config>("GET", "/api/config").catch(() => ({ google: "", games: [] }));
  return config;
}

let making: Promise<Player> | null = null;

/** The current player, made on the spot if there isn't one yet. */
export async function ensurePlayer(): Promise<Player | null> {
  if (token()) {
    const cached = cachedPlayer();
    if (cached) return cached;
    try {
      return await refresh();
    } catch (err) {
      if ((err as ApiError).status !== 401) throw err;
    }
  }
  if (!making) {
    making = api<{ token: string; player: Player }>("POST", "/api/players", {}).then(({ token: t, player }) => {
      setPlayer(player, t);
      return player;
    }).finally(() => {
      making = null;
    });
  }
  return making;
}

/** Everything about the signed-in player, or null if there's no player yet. */
export async function me(): Promise<MeData | null> {
  if (!token()) return null;
  try {
    const data = await api<MeData>("GET", "/api/me");
    setPlayer(data.player);
    return data;
  } catch (err) {
    if ((err as ApiError).status === 401) return null;
    throw err;
  }
}

export async function refresh(): Promise<Player | null> {
  const data = await me();
  return data ? data.player : null;
}

export async function rename(name: string): Promise<Player> {
  await ensurePlayer();
  const { player } = await api<{ player: Player }>("PATCH", "/api/me", { name });
  setPlayer(player);
  return player;
}

export async function signOut(): Promise<void> {
  try {
    await api("POST", "/api/auth/logout");
  } finally {
    setPlayer(null, null);
  }
}

export async function deleteAccount(): Promise<void> {
  await api("DELETE", "/api/me");
  setPlayer(null, null);
}

/** Uses a save key (a token copied from another device) on this one. */
export async function useKey(key: string): Promise<Player> {
  const previous = token();
  store(TOKEN, key);
  try {
    const data = await api<MeData>("GET", "/api/me");
    setPlayer(data.player, key);
    return data.player;
  } catch (err) {
    store(TOKEN, previous || null);
    throw err;
  }
}

let gis: Promise<GoogleIdentity> | null = null;

function loadGoogle(): Promise<GoogleIdentity> {
  if (!gis) {
    gis = new Promise<GoogleIdentity>((resolve, reject) => {
      const s = document.createElement("script");
      s.src = "https://accounts.google.com/gsi/client";
      s.async = true;
      s.onload = () => resolve(window.google!);
      s.onerror = () => {
        gis = null;
        reject(new Error("Couldn't load Google sign-in."));
      };
      document.head.append(s);
    });
  }
  return gis;
}

/**
 * Draws Google's own "Sign in with Google" button into `el`, if the server
 * has a client ID. Resolves false when Google sign-in isn't set up. On
 * success the player (merged with this device's progress) is set.
 */
export async function googleButton(
  el: HTMLElement,
  { onSignIn, onError, text = "continue_with" }: { onSignIn?: (player: Player) => void; onError?: (err: Error) => void; text?: string } = {},
): Promise<boolean> {
  const { google: clientId } = await getConfig();
  if (!clientId) return false;
  const google = await loadGoogle();
  google.accounts.id.initialize({
    client_id: clientId,
    auto_select: false,
    cancel_on_tap_outside: true,
    callback: async ({ credential }) => {
      try {
        const { token: t, player } = await api<{ token: string; player: Player }>("POST", "/api/auth/google", { credential });
        setPlayer(player, t || token());
        onSignIn?.(player);
      } catch (err) {
        onError?.(err as Error);
      }
    },
  });
  google.accounts.id.renderButton(el, { theme: "filled_black", size: "large", shape: "pill", text });
  return true;
}

export function profileUrl(player: Player | null): string {
  return player ? `/u/${player.id}` : "/me/";
}
