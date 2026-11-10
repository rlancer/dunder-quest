// The simulated Forkcast: a phone, a server, a database and a rented AI
// model, small enough to see all of at once. A Build says how Aleister wired
// it; every action the player can take is a pure function from one World to
// the next, with the messages that crossed the wire (the trace) and what the
// player could see for themselves afterwards (the observations). Nothing here
// says a build is wrong; a build is wrong because of what it does.

export type BookingsAt = "memory" | "storage" | "server" | "db";
export type Check = "phone" | "stricter" | "sealed" | "server";
export type Key = "none" | "app" | "scrambled" | "capped" | "server";
export type Build = { bookings: BookingsAt; check: Check; key: Key };

export type Place = "phone" | "tablet" | "server" | "db" | "ai";
export type Hop = { from: Place; to: Place; text: string; bad?: boolean };
/** ok: true is a test that held, false one that didn't, null neither. */
export type Obs = { id: string; ok: boolean | null; text: string };
export type Booking = { id: number; restaurant: string; party: number };

export type World = {
  build: Build;
  nextId: number;
  /** Bookings the player has made on this build, wherever they ended up. */
  made: number;
  phone: { memory: Booking[]; storage: Booking[] };
  server: { memory: Booking[] };
  db: { bookings: Booking[] };
  ai: { questions: number; answer: string | null };
};

export type Step = { world: World; trace: Hop[]; obs: Obs[] };

export const RESTAURANTS = [
  { id: "nonna", name: "Nonna's", blurb: "Red sauce. Loud family.", seats: 12 },
  { id: "radish", name: "The Gilded Radish", blurb: "Quiet. Extremely vegetarian.", seats: 20 },
  { id: "tako", name: "Tako Taco", blurb: "Octopus tacos. Standing room.", seats: 8 },
] as const;

export const MAX_PARTY = 8;
export const SECRET = "sk-live-F0RKC4ST-9d2e";

export const QUESTIONS = [
  { id: "quiet", ask: "Somewhere quiet for six, one vegetarian", pick: "radish" },
  { id: "loud", ask: "Loud, cheap, and they won't rush us", pick: "nonna" },
] as const;

export function restaurant(id: string) {
  return RESTAURANTS.find((r) => r.id === id) ?? RESTAURANTS[0];
}

export function newWorld(build: Build): World {
  return {
    build,
    nextId: 41,
    made: 0,
    phone: { memory: [], storage: [] },
    server: { memory: [] },
    db: { bookings: [] },
    ai: { questions: 0, answer: null },
  };
}

/** What the diner's phone shows under "Your bookings". */
export function phoneBookings(w: World): Booking[] {
  switch (w.build.bookings) {
    case "memory": return w.phone.memory;
    case "storage": return w.phone.storage;
    case "server": return w.server.memory;
    case "db": return w.db.bookings;
  }
}

/** What the restaurant's tablet shows. It asks the server, so a booking that
 *  never left the phone isn't on it. */
export function tabletBookings(w: World): Booking[] {
  return w.build.bookings === "server" ? w.server.memory : w.build.bookings === "db" ? w.db.bookings : [];
}

export function seatsLeft(w: World, id: string, viewer: "phone" | "tablet"): number {
  const seen = viewer === "phone" ? phoneBookings(w) : tabletBookings(w);
  return restaurant(id).seats - seen.filter((b) => b.restaurant === id).reduce((n, b) => n + b.party, 0);
}

function breaksRules(w: World, id: string, party: number): boolean {
  return !Number.isInteger(party) || party < 1 || party > MAX_PARTY || party > seatsLeft(w, id, "tablet");
}

const LIST: Hop[] = [
  { from: "phone", to: "server", text: "GET /restaurants" },
  { from: "server", to: "db", text: "read restaurants, bookings" },
  { from: "db", to: "server", text: "3 restaurants" },
  { from: "server", to: "phone", text: "200 OK: tonight's tables" },
];

/** The diner books. `edited` is true when the player caught the message on
 *  the wire and let it go again, changed or not: the app's own checks ran
 *  before that, so they don't see what it says now. */
export function book(w: World, id: string, party: number, edited = false): Step {
  const name = restaurant(id).name;
  const at = w.build.bookings;
  if (!edited && (party < 1 || party > MAX_PARTY || party > seatsLeft(w, id, "phone"))) {
    return { world: w, trace: [], obs: [] };
  }
  const booking: Booking = { id: w.nextId, restaurant: id, party };
  const next = { ...w, nextId: w.nextId + 1, made: w.made + 1 };
  const booked: Obs = { id: "book", ok: true, text: "Booked a table. It showed up on your phone." };

  if (at === "memory") {
    return { world: { ...next, phone: { ...w.phone, memory: [...w.phone.memory, booking] } }, trace: [], obs: [booked] };
  }
  if (at === "storage") {
    return { world: { ...next, phone: { ...w.phone, storage: [...w.phone.storage, booking] } }, trace: [], obs: [booked] };
  }

  const sent: Hop = { from: "phone", to: "server", text: `POST /bookings {restaurant: "${name}", party: ${party}}` };
  const bad = breaksRules(w, id, party);
  if (bad && w.build.check === "server") {
    return {
      world: w,
      trace: [sent, { from: "server", to: "phone", text: `400 Refused: a party of ${party} breaks the rules`, bad: true }],
      obs: [{ id: "tamper", ok: true, text: `Sent the server a party of ${party}. It refused.` }],
    };
  }
  const obs = bad
    ? [{ id: "tamper", ok: false, text: `Sent the server a party of ${party}. It said yes.` }]
    : [booked];
  if (at === "server") {
    return {
      world: { ...next, server: { memory: [...w.server.memory, booking] } },
      trace: [sent, { from: "server", to: "phone", text: "200 OK: booked (I'll remember)" }],
      obs,
    };
  }
  return {
    world: { ...next, db: { bookings: [...w.db.bookings, booking] } },
    trace: [
      sent,
      { from: "server", to: "db", text: `INSERT booking #${booking.id}` },
      { from: "db", to: "server", text: "saved" },
      { from: "server", to: "phone", text: `200 OK: booked #${booking.id}` },
    ],
    obs,
  };
}

/** Close the app and open it again: the app's memory starts empty. */
export function reload(w: World): Step {
  const had = phoneBookings(w).length > 0;
  const world = { ...w, phone: { ...w.phone, memory: [] }, ai: { ...w.ai, answer: null } };
  const obs: Obs[] = !had ? [] : phoneBookings(world).length > 0
    ? [{ id: "reload", ok: true, text: "Closed and reopened the app. The booking was still there." }]
    : [{ id: "reload", ok: false, text: "Closed and reopened the app. The booking was gone." }];
  return { world, trace: LIST, obs };
}

/** Restart the server, as every update and every crash does. */
export function restart(w: World): Step {
  const had = tabletBookings(w).length > 0;
  const world = { ...w, server: { memory: [] } };
  const obs: Obs[] = !had
    ? [{ id: "restart", ok: null, text: "Restarted the server. Nothing changed: it wasn't holding any bookings." }]
    : tabletBookings(world).length > 0
      ? [{ id: "restart", ok: true, text: "Restarted the server. Every booking was still there." }]
      : [{ id: "restart", ok: false, text: "Restarted the server. Every booking was gone." }];
  return { world, trace: [], obs };
}

/** Look at the restaurant's tablet. */
export function viewTablet(w: World): Step {
  const mine = phoneBookings(w).length;
  const theirs = tabletBookings(w).length;
  const obs: Obs[] = mine === 0 ? [] : theirs >= mine
    ? [{ id: "tablet", ok: true, text: "The restaurant's tablet shows the booking too." }]
    : [{ id: "tablet", ok: false, text: "Your phone says booked. The restaurant's tablet shows nothing." }];
  return {
    world: w,
    trace: [
      { from: "tablet", to: "server", text: "GET /tonight" },
      { from: "server", to: "tablet", text: `200 OK: ${theirs} booking${theirs === 1 ? "" : "s"}` },
    ],
    obs,
  };
}

/** True when the phone itself holds the AI key, so its questions carry it. */
export function keyOnPhone(b: Build): boolean {
  return b.key === "app" || b.key === "scrambled" || b.key === "capped";
}

/** The message the phone sends when the diner asks the concierge. */
export function askMessage(w: World, question: string): Hop {
  return keyOnPhone(w.build)
    ? { from: "phone", to: "ai", text: `POST /answer {key: "${SECRET}", question: "${question}"}` }
    : { from: "phone", to: "server", text: `POST /ask {question: "${question}"}` };
}

/** Ask the concierge. `watched` is true when the player caught the message
 *  on the wire and read it. */
export function ask(w: World, qid: string, watched = false): Step {
  const q = QUESTIONS.find((x) => x.id === qid) ?? QUESTIONS[0];
  const answer = `Try ${restaurant(q.pick).name}.`;
  const world = { ...w, ai: { questions: w.ai.questions + 1, answer } };
  const first = askMessage(w, q.ask);
  const obs: Obs[] = [{ id: "ask", ok: true, text: "Asked Forkcast for a table. It picked one." }];
  if (keyOnPhone(w.build)) {
    if (watched) obs.push({ id: "wire-key", ok: false, text: "Caught the question on its way out. The secret key rides along with it." });
    return { world, trace: [first, { from: "ai", to: "phone", text: `200 OK: "${answer}"` }], obs };
  }
  if (watched) obs.push({ id: "wire-key", ok: true, text: "Caught the question on its way out. No key in it." });
  return {
    world,
    trace: [
      first,
      { from: "server", to: "ai", text: `POST /answer {key: "sk-live-…", question: …}` },
      { from: "ai", to: "server", text: `200 OK: "${answer}"` },
      { from: "server", to: "phone", text: `200 OK: "${answer}"` },
    ],
    obs,
  };
}

export type Line = { text: string; secret?: boolean };

/** Everything that ships to the phone, as whoever holds the phone can read it. */
export function appContents(b: Build): Line[] {
  const lines: Line[] = [
    { text: "screens/  Home, Book, My bookings" },
    { text: "pictures/  logo.png, nonna.jpg, radish.jpg" },
    { text: 'const GREETING = "Hungry?"' },
    { text: `const MAX_PARTY = ${MAX_PARTY}` },
  ];
  if (b.key === "app" || b.key === "capped") {
    lines.splice(3, 0, { text: `const AI_KEY = "${SECRET}"`, secret: true });
  } else if (b.key === "scrambled") {
    lines.splice(3, 0, { text: 'const AI_KEY = unscramble("Zx9$-qT0!-b4RR-e2d9")', secret: true });
  } else if (b.key === "server") {
    lines.splice(3, 0, { text: 'const ASK_URL = "/ask"  // our own server' });
  }
  return lines;
}

/** The player opened the app up and read it. */
export function peek(w: World): Step {
  const obs: Obs[] = appContents(w.build).some((l) => l.secret)
    ? []
    : [{ id: "peek", ok: true, text: "Looked inside the app. No secrets in it." }];
  return { world: w, trace: [], obs };
}

/** The player tapped the line with the key on it. */
export function findKey(w: World): Step {
  const text = w.build.key === "scrambled"
    ? "Looked inside the app. The key is in there, with the step that unscrambles it."
    : "Looked inside the app. The secret key is sitting in it.";
  return { world: w, trace: [], obs: [{ id: "peek", ok: false, text }] };
}
