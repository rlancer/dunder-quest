// The browser's side of the social layer: who this player is, and the
// calls to the API. A player is made the first time it's needed (a game
// saves, a screenshot is shared), with a silly name and no sign-up; the
// token lives in localStorage. Signing in with Google ties it to an account
// so progress follows the player to other devices.

const TOKEN = "dq.token";
const PLAYER = "dq.player";

function store(key, value) {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    // Private windows can refuse storage; the session still works.
  }
}

function load(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function token() {
  return load(TOKEN) || "";
}

/** The player as last seen, without asking the server (for drawing the page quickly). */
export function cachedPlayer() {
  try {
    return JSON.parse(load(PLAYER) || "null");
  } catch {
    return null;
  }
}

const listeners = new Set();

/** Calls `fn(player)` whenever the player changes (signs in, renames, signs out). */
export function onPlayer(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function setPlayer(player, newToken) {
  if (newToken !== undefined) store(TOKEN, newToken || null);
  store(PLAYER, player ? JSON.stringify(player) : null);
  for (const fn of listeners) fn(player);
}

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function api(method, path, body) {
  const headers = {};
  const t = token();
  if (t) headers.Authorization = `Bearer ${t}`;
  let payload;
  if (body instanceof FormData) payload = body;
  else if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  let res;
  try {
    res = await fetch(path, { method, headers, body: payload });
  } catch {
    throw new ApiError(0, "Couldn't reach the server. Are you offline?");
  }
  let data = null;
  try {
    data = await res.json();
  } catch {
    // An HTML error page from somewhere in between.
  }
  if (!res.ok) {
    if (res.status === 401 && t) setPlayer(null, null);
    throw new ApiError(res.status, data?.error || `The server said ${res.status}.`);
  }
  return data;
}

let config = null;

/** The server's settings: the Google client ID, if sign-in is set up. */
export function getConfig() {
  if (!config) config = api("GET", "/api/config").catch(() => ({ google: "", games: [] }));
  return config;
}

let making = null;

/** The current player, made on the spot if there isn't one yet. */
export async function ensurePlayer() {
  if (token()) {
    const cached = cachedPlayer();
    if (cached) return cached;
    try {
      return await refresh();
    } catch (err) {
      if (err.status !== 401) throw err;
    }
  }
  if (!making) {
    making = api("POST", "/api/players", {}).then(({ token: t, player }) => {
      setPlayer(player, t);
      return player;
    }).finally(() => {
      making = null;
    });
  }
  return making;
}

/** Everything about the signed-in player, or null if there's no player yet. */
export async function me() {
  if (!token()) return null;
  try {
    const data = await api("GET", "/api/me");
    setPlayer(data.player);
    return data;
  } catch (err) {
    if (err.status === 401) return null;
    throw err;
  }
}

export async function refresh() {
  const data = await me();
  return data ? data.player : null;
}

export async function rename(name) {
  await ensurePlayer();
  const { player } = await api("PATCH", "/api/me", { name });
  setPlayer(player);
  return player;
}

export async function signOut() {
  try {
    await api("POST", "/api/auth/logout");
  } finally {
    setPlayer(null, null);
  }
}

export async function deleteAccount() {
  await api("DELETE", "/api/me");
  setPlayer(null, null);
}

/** Uses a save key (a token copied from another device) on this one. */
export async function useKey(key) {
  const previous = token();
  store(TOKEN, key);
  try {
    const data = await api("GET", "/api/me");
    setPlayer(data.player, key);
    return data.player;
  } catch (err) {
    store(TOKEN, previous || null);
    throw err;
  }
}

let gis = null;

function loadGoogle() {
  if (!gis) {
    gis = new Promise((resolve, reject) => {
      const s = document.createElement("script");
      s.src = "https://accounts.google.com/gsi/client";
      s.async = true;
      s.onload = () => resolve(window.google);
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
export async function googleButton(el, { onSignIn, onError, text = "continue_with" } = {}) {
  const { google: clientId } = await getConfig();
  if (!clientId) return false;
  const google = await loadGoogle();
  google.accounts.id.initialize({
    client_id: clientId,
    auto_select: false,
    cancel_on_tap_outside: true,
    callback: async ({ credential }) => {
      try {
        const { token: t, player } = await api("POST", "/api/auth/google", { credential });
        setPlayer(player, t || token());
        onSignIn?.(player);
      } catch (err) {
        onError?.(err);
      }
    },
  });
  google.accounts.id.renderButton(el, { theme: "filled_black", size: "large", shape: "pill", text });
  return true;
}

export function profileUrl(player) {
  return player ? `/u/${player.id}` : "/me/";
}
