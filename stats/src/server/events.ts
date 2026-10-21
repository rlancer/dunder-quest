import * as v from "valibot";

/** Every event the game sends, and the fields each one may carry. */
export const EVENT_TYPES = [
  "session_start",
  "stage_start",
  "stage_quit",
  "stage_clear",
  "death",
  "scroll_read",
  "duel_answer",
  "duel_hint",
  "duel_won",
  "duel_downed",
] as const;

export type EventType = (typeof EVENT_TYPES)[number];

const Id = v.pipe(v.string(), v.regex(/^[0-9a-f]{32}$/));
const Label = v.pipe(v.string(), v.maxLength(48));

const Event = v.object({
  type: v.picklist(EVENT_TYPES),
  at: v.pipe(v.number(), v.integer(), v.minValue(0)),
  stage: v.optional(v.pipe(v.number(), v.integer(), v.minValue(0), v.maxValue(99))),
  data: v.optional(
    v.pipe(
      v.record(Label, v.union([v.number(), v.boolean(), Label])),
      v.check((data) => Object.keys(data).length <= 12, "too many fields"),
    ),
    {},
  ),
});

export const Batch = v.object({
  install_id: Id,
  session_id: Id,
  platform: Label,
  version: Label,
  events: v.pipe(v.array(Event), v.minLength(1), v.maxLength(50)),
});

export type Batch = v.InferOutput<typeof Batch>;

/** Largest body accepted, well above a full 50-event batch. */
const MAX_BODY = 32 * 1024;

function cors(request: Request, env: Env): Headers {
  const headers = new Headers({ Vary: "Origin" });
  const origin = request.headers.get("Origin");
  if (origin && env.GAME_ORIGINS.split(",").includes(origin)) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    headers.set("Access-Control-Allow-Headers", "Content-Type");
    headers.set("Access-Control-Max-Age", "86400");
  }
  return headers;
}

/** POST /api/events: a batch from the game. Public, so it trusts nothing. */
export async function handleEvents(request: Request, env: Env): Promise<Response> {
  const headers = cors(request, env);
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405, headers });

  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const { success } = await env.EVENT_LIMITER.limit({ key: ip });
  if (!success) return new Response("Slow down", { status: 429, headers });

  const length = Number(request.headers.get("Content-Length") ?? 0);
  if (length > MAX_BODY) return new Response("Too large", { status: 413, headers });
  const text = await request.text();
  if (text.length > MAX_BODY) return new Response("Too large", { status: 413, headers });

  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return new Response("Bad JSON", { status: 400, headers });
  }
  const parsed = v.safeParse(Batch, body);
  if (!parsed.success) return new Response("Bad batch", { status: 400, headers });

  const batch = parsed.output;
  const now = Date.now();
  const insert = env.DB.prepare(
    `INSERT INTO events (received_at, install_id, session_id, platform, version, type, stage, at, data)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  await env.DB.batch(
    batch.events.map((event) =>
      insert.bind(
        now,
        batch.install_id,
        batch.session_id,
        batch.platform,
        batch.version,
        event.type,
        event.stage ?? null,
        // Game clocks drift; a time far from now is replaced by the arrival time.
        Math.abs(event.at - now) < 86_400_000 ? event.at : now,
        JSON.stringify(event.data),
      ),
    ),
  );
  return new Response(null, { status: 204, headers });
}
