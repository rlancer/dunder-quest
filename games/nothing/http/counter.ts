/**
 * The game's counters in TypeScript: http/http.gd's rules, written a second
 * time, without the game. tests/verify_http.ts serves them from a real HTTP
 * server and holds the game to what comes back, and site/build.ts writes the
 * responses on the game's page with them.
 */

export type Route = { type: "doc" | "collection"; fields?: string[]; methods?: string[] };
export type Counter = { host: string; routes: Record<string, Route>; says?: string; etag?: boolean; if_match?: boolean; later?: boolean; tokens?: Record<string, string[]> };
export type State = { items: Record<string, any>; v: Record<string, number> };
/** A request as the counter sees it: header names in lower case. */
export type Asked = { method: string; path: string; headers: Record<string, string>; body: string };
export type Answer = { status: number; headers: Record<string, string>; body: string | null };

export const REASONS: Record<number, string> = {
  200: "OK", 201: "Created", 202: "Accepted", 204: "No Content", 304: "Not Modified",
  400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed",
  406: "Not Acceptable", 412: "Precondition Failed", 415: "Unsupported Media Type", 428: "Precondition Required",
};
const WITH_BODY = ["POST", "PUT", "PATCH"];
const WRITES = ["POST", "PUT", "PATCH", "DELETE"];

const version = (st: State, key: string) => st.v[key] ?? 1;
const etagOf = (st: State, key: string) => `"v${version(st, key)}"`;
const bump = (st: State, key: string) => { st.v[key] = version(st, key) + 1; };

function allowed(route: Route, item: boolean): string[] {
  if (route.methods) return route.methods;
  if (route.type === "doc") return ["GET", "HEAD", "OPTIONS"];
  return item ? ["GET", "HEAD", "PUT", "PATCH", "DELETE", "OPTIONS"] : ["GET", "HEAD", "POST", "OPTIONS"];
}

/** The counter's answer to `req`, changing `st` as it goes. */
export function respond(counter: Counter, st: State, req: Asked): Answer {
  const json = (status: number, value: unknown, extra: Record<string, string> = {}): Answer =>
    ({ status, headers: { "Content-Type": "application/json", ...extra }, body: JSON.stringify(value) });
  const fail = (status: number, message: string, extra: Record<string, string> = {}) =>
    json(status, { error: counter.says ?? message }, extra);
  const header = (name: string): string | null => req.headers[name] ?? null;
  const method = req.method;
  const parts = req.path.replace(/^\//, "").split("/");
  if (parts.length > 2 || parts[0] === "" || !(parts[0] in counter.routes)) return fail(404, "Not found");
  const name = parts[0];
  const route = counter.routes[name];
  const item = parts.length === 2;
  const items: any[] = st.items[name] ?? [];
  let found = -1;
  if (item) {
    if (route.type === "doc" || !/^-?\d+$/.test(parts[1])) return fail(404, "Not found");
    found = items.findIndex((it) => it.id === Number(parts[1]));
    if (found < 0) return fail(404, "Not found");
  }
  const key = item ? `${name}/${parts[1]}` : name;
  if (counter.tokens && Object.keys(counter.tokens).length) {
    const auth = header("authorization") ?? "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    if (!(token in counter.tokens)) return fail(401, "Who are you?", { "WWW-Authenticate": `Bearer realm="${counter.host}"` });
    if (!counter.tokens[token].includes(WRITES.includes(method) ? "write" : "read")) return fail(403, "Not you.");
  }
  const allow = allowed(route, item);
  if (!allow.includes(method)) return fail(405, "Not here", { Allow: allow.join(", ") });
  if (method === "OPTIONS") return { status: 204, headers: { Allow: allow.join(", ") }, body: null };
  const accept = header("accept");
  if (accept !== null && accept !== "application/json" && accept !== "*/*") return fail(406, "JSON only");
  let body: Record<string, unknown> = {};
  if (WITH_BODY.includes(method)) {
    if (header("content-type") !== "application/json") return fail(415, "Say it in JSON");
    if (req.body === "") return fail(400, "No body");
    let parsed: unknown;
    try { parsed = JSON.parse(req.body); } catch { parsed = undefined; }
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) return fail(400, "That isn't JSON");
    body = parsed as Record<string, unknown>;
    const fields = route.fields ?? [];
    for (const f of Object.keys(body)) if (!fields.includes(f)) return fail(400, `No such field: ${f}`);
    if (method !== "PATCH") for (const f of fields) if (!(f in body)) return fail(400, `Missing field: ${f}`);
  }
  const ifMatch = header("if-match");
  if (item && ["PUT", "PATCH", "DELETE"].includes(method)) {
    if (ifMatch === null && counter.if_match) return fail(428, "Which version?");
    if (ifMatch !== null && ifMatch !== "*" && ifMatch !== etagOf(st, key)) return fail(412, "It changed");
  }
  const tag: Record<string, string> = counter.etag ? { ETag: etagOf(st, key) } : {};
  const ifNone = header("if-none-match");
  if ((method === "GET" || method === "HEAD") && counter.etag && ifNone !== null && (ifNone === etagOf(st, key) || ifNone === "*")) {
    return { status: 304, headers: tag, body: null };
  }
  switch (method) {
    case "GET":
    case "HEAD":
      return json(200, item ? items[found] : items, tag);
    case "POST": {
      const next = Math.max(1, ...items.map((it) => it.id + 1));
      const made: Record<string, unknown> = { id: next };
      for (const f of route.fields ?? []) made[f] = body[f];
      items.push(made);
      st.items[name] = items;
      bump(st, name);
      return json(counter.later ? 202 : 201, made, { Location: `/${name}/${next}` });
    }
    case "PUT":
    case "PATCH": {
      const changed = { ...items[found], ...body };
      items[found] = changed;
      st.items[name] = items;
      bump(st, key);
      bump(st, name);
      return json(200, changed, counter.etag ? { ETag: etagOf(st, key) } : {});
    }
    case "DELETE":
      items.splice(found, 1);
      st.items[name] = items;
      bump(st, name);
      return { status: 204, headers: {}, body: null };
  }
  return fail(405, "Not here", { Allow: allow.join(", ") });
}

/** A slip of cards as the counter sees it. */
export function asked(cards: string[]): Asked {
  const out: Asked = { method: "", path: "", headers: {}, body: "" };
  for (const card of cards) {
    if (["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"].includes(card)) out.method = card;
    else if (card.startsWith("/")) out.path = card;
    else if (card.startsWith("{") || card.startsWith("[")) out.body = card;
    else { const at = card.indexOf(": "); out.headers[card.slice(0, at).toLowerCase()] = card.slice(at + 2); }
  }
  return out;
}

/** The response as it comes back over the wire (the headers the game shows). */
export function wire(a: Answer, method: string): string[] {
  const out = [`HTTP/1.1 ${a.status} ${REASONS[a.status] ?? ""}`];
  for (const name of ["Content-Type", "Location", "ETag", "Allow", "WWW-Authenticate"]) {
    if (name in a.headers && !(name === "Content-Type" && (a.status === 204 || a.status === 304))) out.push(`${name}: ${a.headers[name]}`);
  }
  if (a.body !== null && method !== "HEAD") out.push("", a.body);
  return out;
}
