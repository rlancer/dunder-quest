// The rules behind all three sketches, with no screen. Each sketch teaches
// the same three things, so they can be compared:
//   store:  bookings kept in the server's memory, or in the database
//   pricer: the deposit worked out on the phone, or on the server
//   key:    the AI model's key shipped in the app, or kept on the server
// The numbers are stage numbers. The shapes are real.

export type Store = "memory" | "database";
export type Pricer = "phone" | "server";
export type KeyPlace = "app" | "server";
export interface Build { store: Store; pricer: Pricer; key: KeyPlace }
export type Topic = keyof Build;

/** What an AI builds when nobody says otherwise: the quickest thing that demos. */
export const GUESSED: Build = { store: "memory", pricer: "phone", key: "app" };
/** What you'd ask for. */
export const ASKED: Build = { store: "database", pricer: "server", key: "server" };
export const DEPOSIT = 20;

// ------------------------------------------------------------------ One Tap

export type Place = "phone" | "server" | "database" | "model" | "stranger";

export interface World {
  build: Build;
  inMemory: number;
  inDatabase: number;
  /** Deposits taken, and how far short of $20 each they fell. */
  till: number;
  short: number;
  /** The model's bill, and how much of it was strangers'. */
  bill: number;
  stolen: number;
  /** Somebody outside has a copy of a key that still works. */
  leaked: boolean;
}

export interface Step { world: World; hops: Place[]; says: string }

export function newWorld(build: Build = GUESSED): World {
  return { build: { ...build }, inMemory: 0, inDatabase: 0, till: 0, short: 0, bill: 0, stolen: 0, leaked: false };
}

export function rebuild(w: World, patch: Partial<Build>): World {
  return { ...w, build: { ...w.build, ...patch } };
}

/** A diner books. `slip` is the deposit the phone's request claims. */
export function book(w: World, slip: number = DEPOSIT): Step & { paid: string } {
  const world = { ...w };
  const hops: Place[] = ["phone", "server"];
  let says: string;
  if (w.build.store === "memory") {
    world.inMemory += 1;
    says = "Booked. The server is remembering it. Nothing is written down.";
  } else {
    world.inDatabase += 1;
    hops.push("database", "server");
    says = "Booked. The server wrote it in the database.";
  }
  hops.push("phone");
  const charged = w.build.pricer === "server" ? DEPOSIT : slip;
  world.till += charged;
  world.short += DEPOSIT - charged;
  let paid: string;
  if (w.build.pricer === "phone") {
    paid = slip < DEPOSIT
      ? `The phone said $${slip} and the server believed it. That table cost you $${DEPOSIT - slip}.`
      : `The phone said $${slip} and the server believed it. Fine, for as long as every phone is honest.`;
  } else {
    paid = slip < DEPOSIT
      ? `The phone said $${slip}. The server ignored that and worked out $${DEPOSIT} from its own price list.`
      : `The server worked out $${DEPOSIT} itself. What the phone said didn't matter.`;
  }
  return { world, hops, says, paid };
}

/** Servers restart every time a change ships. Memory doesn't survive it. */
export function restart(w: World): Step {
  const lost = w.inMemory;
  const world = { ...w, inMemory: 0 };
  let says: string;
  if (lost > 0) says = `The server restarted and forgot ${count(lost, "booking")}. Those diners are still coming.`;
  else if (w.inDatabase > 0) says = `The server restarted. ${w.inDatabase === 1 ? "The booking is" : `All ${w.inDatabase} bookings are`} still in the database.`;
  else says = "The server restarted. Nothing to lose yet: book a table first.";
  return { world, hops: ["server"], says };
}

/** A diner asks the model something. A dollar a question. */
export function ask(w: World): Step {
  const world = { ...w, bill: w.bill + 1 };
  if (w.build.key === "app") {
    return { world, hops: ["phone", "model", "phone"], says: "The phone called the model itself, with the key that's inside the app. $1." };
  }
  return { world, hops: ["phone", "server", "model", "server", "phone"], says: "The phone asked the server. The server called the model with its key. $1." };
}

const HAUL = 25;

/** A stranger opens the app and reads what's in it, then uses what they found. */
export function snoop(w: World): Step {
  const found = w.build.key === "app";
  const leaked = w.leaked || found;
  if (!leaked) {
    return { world: { ...w }, hops: ["stranger", "phone", "stranger"], says: "The stranger read everything in the app. There's no key in it. Nothing to take." };
  }
  const world = { ...w, leaked, bill: w.bill + HAUL, stolen: w.stolen + HAUL };
  const says = found
    ? `The stranger read the key out of the app and asked the model ${HAUL} questions of their own. On your bill.`
    : `The key isn't in the app any more, but the stranger kept a copy, and the copy still works. Another $${HAUL}.`;
  return { world, hops: found ? ["stranger", "phone", "stranger", "model"] : ["stranger", "model"], says };
}

/** Swap the key for a new one. Every copy of the old one stops working. */
export function rotate(w: World): Step {
  const world = { ...w, leaked: false };
  const says = w.build.key === "app"
    ? "New key. The old copies are dead. But the new one is inside the app again, for the next stranger."
    : "New key, kept on the server. The stranger's copy is dead.";
  return { world, hops: ["server", "model"], says };
}

function count(n: number, word: string): string {
  return `${n} ${word}${n === 1 ? "" : "s"}`;
}

// ----------------------------------------------------------------- The Gaps

export interface Reading { build: Build; said: Record<Topic, boolean> }

const NOT = /\b(no|not|never|without|don'?t|do not|shouldn'?t|mustn'?t|out of|off)\b/;
const DB = /\b(databases?|data base|postgres\w*|supabase|mysql|sqlite|firebase|firestore|db)\b/;
const SERVER = /\b(servers?|server-side|backend|back end|back-end)\b/;
const PHONE = /\b(phones?|apps?|clients?|browsers?|frontend|front end|front-end|page|code|users?|diners?)\b/;
const MONEY = /\b(prices?|deposits?|totals?|amounts?|charges?|fees?|costs?|pay\w*)\b/;
// A server that's merely mentioned beside a price hasn't been given the job.
const DECIDES = /\b(works? (it |them )?out|work\w* out|calculat\w*|decid\w*|checks?|sets?|comput\w*|verif\w*|validat\w*|itself|server-side|on the (server|backend))\b/;
const SECRET = /\b(keys?|secrets?|tokens?|credentials?)\b/;

/**
 * What a brief, in the player's own words, settles. A sentence counts when it
 * names the right place for the thing; anything it leaves out stays a guess.
 */
export function readBrief(text: string): Reading {
  const said: Record<Topic, boolean> = { store: false, pricer: false, key: false };
  for (const raw of text.toLowerCase().split(/[.!?\n;]+/)) {
    const s = raw.trim();
    if (!s) continue;
    const before = (re: RegExp) => {
      const m = re.exec(s);
      return m ? s.slice(0, m.index) : null;
    };
    // "Save bookings in a database", not "no database".
    const db = before(DB);
    if (db !== null && !NOT.test(db)) said.store = true;
    // "The server works out the deposit", or "never trust the price the phone sends".
    if (MONEY.test(s)) {
      const sv = before(SERVER);
      if (sv !== null && !NOT.test(sv) && DECIDES.test(s)) said.pricer = true;
      if (/\b(never|don'?t|do not) (trust|believe)\b/.test(s) && PHONE.test(s)) said.pricer = true;
    }
    if (/\b(never|don'?t|do not) (trust|believe) (the |what the )?(phone|app|client|browser|frontend)\b/.test(s)) said.pricer = true;
    // "Keep the key on the server", or "the key never goes in the app".
    if (SECRET.test(s)) {
      const sv = before(SERVER) ?? before(/\b(env|environment variables?)\b/);
      if (sv !== null && !NOT.test(sv)) said.key = true;
      const ph = before(PHONE);
      if (ph !== null && NOT.test(ph) && !(sv !== null && NOT.test(sv))) said.key = true;
    }
  }
  return {
    said,
    build: {
      store: said.store ? "database" : GUESSED.store,
      pricer: said.pricer ? "server" : GUESSED.pricer,
      key: said.key ? "server" : GUESSED.key,
    },
  };
}

export interface Outcome {
  topic: Topic;
  ok: boolean;
  time: string;
  /** What happened on the night. */
  what: string;
  /** The gap in the brief, in Aleister's words. Empty when the brief covered it. */
  guess: string;
  /** The words that would have closed it, and a sentence that does. */
  words: string[];
  sentence: string;
}

/** Thursday night, run against whatever the brief produced. */
export function night(build: Build): Outcome[] {
  const w = { diners: 31, cheats: 15, strangers: 212 };
  return [
    {
      topic: "store",
      ok: build.store === "database",
      time: "8:10",
      what: build.store === "database"
        ? `A fix shipped and the server restarted. All ${w.diners} bookings were still in the database.`
        : `A fix shipped and the server restarted. It forgot all ${w.diners} bookings. The diners came anyway.`,
      guess: build.store === "database" ? "" : "You didn't say where bookings are kept. I kept them in the server's memory. It was the fastest.",
      words: ["database"],
      sentence: "Save every booking in a database, never only in memory.",
    },
    {
      topic: "pricer",
      ok: build.pricer === "server",
      time: "8:40",
      what: build.pricer === "server"
        ? `Someone changed their deposit to $0 on their phone. The server charged $${DEPOSIT} anyway.`
        : `Someone changed their deposit to $0 on their phone and told the group chat. ${w.cheats} tables, $${w.cheats * DEPOSIT} short.`,
      guess: build.pricer === "server" ? "" : "You didn't say who works out the deposit. I let the phone do it and had the server take its word.",
      words: ["server", "deposit"],
      sentence: `The server works out the $${DEPOSIT} deposit itself and never trusts an amount the phone sends.`,
    },
    {
      topic: "key",
      ok: build.key === "server",
      time: "9:30",
      what: build.key === "server"
        ? "A stranger went through the app looking for the model's key. It isn't in there."
        : `A stranger found the model's key inside the app. $${w.strangers} of other people's questions, on your bill.`,
      guess: build.key === "server" ? "" : "You didn't say where the model's key goes. I put it in the app, so the phone could call the model directly.",
      words: ["key", "server"],
      sentence: "Keep the AI model's key on the server, never in the app.",
    },
  ];
}
