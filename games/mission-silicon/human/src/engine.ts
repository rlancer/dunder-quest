// The Human Backend's rules, with no screen attached: slips arrive, the
// player (or the robot that watched them) sends each to something on the
// desk, and the night answers back. Deterministic for a given seed, so the
// tests can play every night through. The numbers are stage numbers; the
// behaviours are how real systems behave (see ../../HUMAN_BACKEND.md).

import { LINES } from "./lines";

export type Kind = "book" | "pay" | "cancel" | "ask" | "free";
export type StationId = "notes" | "ledger" | "stamp" | "adder" | "model" | "key";
export type Who = "ulrich" | "gerard" | "gilroy" | "danesh" | "ricky" | "aleister" | "nonna" | "bot" | string;
export type Topic = "cosy" | "family" | "vegan" | "party";

/** What each kind of slip can be dropped on. */
export const ROUTES: Record<Kind, StationId[]> = {
  book: ["notes", "ledger"],
  pay: ["stamp", "adder"],
  cancel: ["stamp", "ledger"],
  ask: ["key", "model", "notes"],
  free: ["ledger", "notes"],
};

/** Seconds a station takes by hand and for the robot, and how many it queues.
 * The careful things are slow by hand and nearly free for a machine. */
export const TIME: Record<StationId, { hand: number; robot: number; cap: number }> = {
  notes: { hand: 0, robot: 0, cap: 0 },
  stamp: { hand: 0, robot: 0, cap: 0 },
  key: { hand: 0, robot: 0, cap: 0 },
  ledger: { hand: 1.3, robot: 0.45, cap: 4 },
  adder: { hand: 1.0, robot: 0.12, cap: 6 },
  model: { hand: 2.0, robot: 0.9, cap: 4 },
};

export const DINERS = [
  { name: "Dana", face: "d1" },
  { name: "Walt", face: "d2" },
  { name: "Kenji", face: "d3" },
  { name: "Rosa", face: "d4" },
  { name: "Fern", face: "d5" },
  { name: "Harjit", face: "d6" },
  { name: "Spike", face: "d7" },
  { name: "Leila", face: "d8" },
];

export const TOPICS: Record<Topic, string> = {
  cosy: "Somewhere cosy?",
  family: "Big family table?",
  vegan: "Good vegan food?",
  party: "Birthday spot?",
};

export const TTL = 8;
export const DEPOSIT = 5;
/** Seconds between the robot's moves, per desk. A hand that helps is worth having. */
const ROBOT_GAP = 0.45;
/** A slip lies in the pile this long before the robot takes it, so a hand can get there first. */
const ROBOT_WAIT = 0.5;

export type Slip = {
  id: number;
  kind: Kind;
  who: { name: string; face: string };
  born: number;
  due: number;
  /** Bounced off these already. */
  tried: StationId[];
  party?: number;
  /** The total the diner's phone wrote on the slip. */
  claimed?: number;
  cheat?: boolean;
  /** Cancel: the table number, and whether a bot is counting through them. */
  no?: number;
  bot?: boolean;
  topic?: Topic;
};

export type Note =
  | { id: number; type: "booking"; booking: number; face: string; at: number }
  | { id: number; type: "answer"; topic: Topic; value: string; at: number }
  | { id: number; type: "free"; ver: number; at: number };

export type Booking = {
  no: number;
  name: string;
  face: string;
  where: "notes" | "ledger" | "lost" | "cancelled" | "stolen";
  at: number;
  arrived?: boolean;
};

type Job = { slip?: Slip; note?: Note; by: "hand" | "robot"; left: number };

export type Ev =
  | { t: "spawn"; slip: Slip }
  | { t: "gone"; slip: Slip; why: "timeout" | "full" | "power" }
  | { t: "sent"; slip: Slip; station: StationId; by: "hand" | "robot" }
  | { t: "bounce"; slip: Slip; station: StationId; why: "wrong" | "busy" | "miss" }
  | { t: "reply"; slip: Slip; station: StationId; mood: "ok" | "bad" | "meh" | "sly"; text: string; by: "hand" | "robot" }
  | { t: "note+"; note: Note }
  | { t: "note-"; note: Note; why: "flush" | "tear" | "ttl" | "wipe" }
  | { t: "learned"; kind: Kind; rule: StationId[] }
  | { t: "watching"; kind: Kind }
  | { t: "bark"; who: Who; text: string }
  | { t: "text"; who: Who; name: string; text: string }
  | { t: "station"; id: StationId }
  | { t: "warn"; secs: number }
  | { t: "unplug"; total: boolean }
  | { t: "power" }
  | { t: "arrive"; name: string; face: string; ok: boolean; text: string }
  | { t: "door"; seated: number; turned: number }
  | { t: "money"; amount: number; station: StationId | "strangers" | "desks" }
  | { t: "pulse"; what: string; on: boolean }
  | { t: "sign"; text: string }
  | { t: "stranger" }
  | { t: "keycut" }
  | { t: "phase"; id: string }
  | { t: "servers"; n: number }
  | { t: "end" };

export type Stats = {
  ok: number;
  angry: number;
  booked: number;
  lost: number;
  kept: number;
  owed: number;
  taken: number;
  cheats: number;
  caught: number;
  stolen: number;
  refused: number;
  bill: number;
  strangers: number;
  stale: number;
  hits: number;
  meh: number;
  desks: number;
  outage: boolean;
  spawned: number;
};

const newStats = (): Stats => ({
  ok: 0, angry: 0, booked: 0, lost: 0, kept: 0, owed: 0, taken: 0, cheats: 0, caught: 0, stolen: 0,
  refused: 0, bill: 0, strangers: 0, stale: 0, hits: 0, meh: 0, desks: 0, outage: false, spawned: 0,
});

export type Rules = Partial<Record<Kind, StationId[]>>;
/** What carries from one night to the next: the robot, as the player left it. */
export type Carry = { rules: Rules; ttl: boolean };

export const NIGHTS = [
  { title: "Soft launch", sub: "Night 1" },
  { title: "Deposits", sub: "Night 2" },
  { title: "The Model", sub: "Night 3" },
  { title: "Launch night", sub: "Night 4" },
];

function mulberry(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class Engine {
  t = 0;
  phase = "";
  pt = 0;
  done = false;
  events: Ev[] = [];
  inbox: Slip[] = [];
  notes: Note[] = [];
  bookings: Booking[] = [];
  rules: Rules;
  /** The last few stations the player's own hand used for each kind. */
  seen: Partial<Record<Kind, StationId[]>> = {};
  /** How many times running the player has done it differently from the robot. */
  streak: Partial<Record<Kind, number>> = {};
  /** The robot leaves a kind alone until this time, to watch how the player does it. */
  holdTo: Partial<Record<Kind, number>> = {};
  on: Record<StationId, boolean> = { notes: false, ledger: false, stamp: false, adder: false, model: false, key: false };
  queues: Record<"ledger" | "adder" | "model", Job[]> = { ledger: [], adder: [], model: [] };
  stats = newStats();
  till = 0;
  ttl: boolean;
  ttlOffered = false;
  /** Notes can hold answers (night 3 on). */
  cache = false;
  truth: Record<Topic, string> = { cosy: "Nonna's", family: "Luna", vegan: "Green Fig", party: "Big Sal's" };
  freeVer = 0;
  key = { leaked: false, at: 0, cutting: 0, everLeaked: false };
  servers = 1;
  /** Seconds of darkness left after an unplug. */
  dark = 0;
  /** Seconds the first desk stays off when the others carry on. */
  deskOff = 0;
  inboxCap = 6;
  private rng: () => number;
  private nextId = 1;
  private nextNo = 1;
  private cd: number[] = [0, 0, 0, 0];
  private acc: Record<string, number> = {};
  private once = new Set<string>();
  private arrivals: Booking[] = [];
  private arriveGap = 0;
  private lastHand = -9;
  private botNo = 1;
  private strangerTick = 0;
  private cancelling = new Set<number>();
  /** Bookings before this number already had their evening (night 1's first crash). */
  private arrivedTo = 0;
  /** The last booking taken before night 1's first unplugging. */
  mark = 0;

  constructor(public night: number, carry: Carry = { rules: {}, ttl: false }, seed = 7) {
    this.rules = structuredClone(carry.rules);
    this.ttl = carry.ttl;
    this.rng = mulberry(seed * 1000 + night);
    const on = (...ids: StationId[]) => ids.forEach((id) => (this.on[id] = true));
    if (night === 1) on("notes");
    if (night === 2) on("notes", "ledger", "stamp", "adder");
    if (night >= 3) {
      on("notes", "ledger", "stamp", "adder", "model", "key");
      // A robot that was never shown a careful way keeps the careless one.
      this.rules.book ??= ["notes"];
      this.rules.pay ??= ["stamp"];
      this.rules.cancel ??= ["stamp"];
    }
    if (night >= 2) this.rules.book ??= ["notes"];
    if (night === 4) {
      this.cache = true;
      this.ttlOffered = true;
      this.rules.ask ??= ["model"];
    }
    if (night > 1) {
      // The afternoon's bookings are already in, wherever this robot keeps them.
      const where = this.rules.book![0] as "notes" | "ledger";
      for (let i = 0; i < 24; i++) {
        const d = this.diner();
        this.bookings.push({ no: this.nextNo++, name: d.name, face: d.face, where, at: 0 });
        if (where === "notes") this.notes.push({ id: this.nextId++, type: "booking", booking: this.nextNo - 1, face: d.face, at: 0 });
      }
    }
    this.go(night === 1 ? "solo" : night === 2 ? "pay-teach" : night === 3 ? "ask-teach" : "free-teach");
  }

  carry(): Carry {
    return { rules: structuredClone(this.rules), ttl: this.ttl };
  }

  // ---------------------------------------------------------------- actions

  /** Send a slip to something on the desk. False if it stayed where it was. */
  send(id: number, station: StationId, by: "hand" | "robot" = "hand"): boolean {
    const slip = this.inbox.find((s) => s.id === id);
    if (!slip || this.dark > 0) return false;
    const allowed = this.on[station] && ROUTES[slip.kind].includes(station)
      && !(station === "notes" && slip.kind !== "book" && !this.cache);
    if (!allowed) {
      if (by === "hand") this.emit({ t: "bounce", slip, station, why: "wrong" });
      return false;
    }
    if (by === "hand") this.lastHand = this.t;
    if (station === "notes" && slip.kind !== "book") {
      const note = this.lookup(slip);
      if (!note) {
        if (!slip.tried.includes("notes")) slip.tried.push("notes");
        if (by === "hand") this.emit({ t: "bounce", slip, station, why: "miss" });
        return false;
      }
    }
    const time = TIME[station];
    if (time.cap) {
      const q = this.queues[station as "ledger"];
      if (q.length >= time.cap) {
        if (by === "hand") this.emit({ t: "bounce", slip, station, why: "busy" });
        return false;
      }
      this.take(slip);
      q.push({ slip, by, left: this.secs(slip.kind, station, by) });
      this.emit({ t: "sent", slip, station, by });
      return true;
    }
    this.take(slip);
    this.emit({ t: "sent", slip, station, by });
    this.resolve(slip, station, by);
    return true;
  }

  /** Tap a rule: the robot stops doing that kind for a few seconds and watches. */
  hold(kind: Kind, secs = 6) {
    if (!this.rules[kind]) return;
    this.holdTo[kind] = this.t + secs;
    this.emit({ t: "watching", kind });
  }

  held(kind: Kind): boolean {
    return (this.holdTo[kind] ?? 0) > this.t;
  }

  /** How long a station takes. Slow by hand, until the robot knows that way
   * for that kind of slip; then it does the legwork whoever drops it there. */
  secs(kind: Kind, station: StationId, by: "hand" | "robot"): number {
    return by === "robot" || this.rules[kind]?.includes(station) ? TIME[station].robot : TIME[station].hand;
  }

  /** Drag a sticky note onto the ledger: write it down properly. */
  flush(noteId: number): boolean {
    const note = this.notes.find((n) => n.id === noteId);
    if (!note || note.type !== "booking" || !this.on.ledger || this.dark > 0) return false;
    if (this.queues.ledger.length >= TIME.ledger.cap) return false;
    this.notes = this.notes.filter((n) => n !== note);
    this.queues.ledger.push({ note, by: "hand", left: this.rules.book?.[0] === "ledger" ? TIME.ledger.robot : TIME.ledger.hand * 0.6 });
    // Writing a note into the book is showing him the book.
    if (this.rules.book?.[0] === "notes") this.streak.book = 0;
    this.emit({ t: "note-", note, why: "flush" });
    return true;
  }

  /** Tear a note off the board. */
  tear(noteId: number) {
    const note = this.notes.find((n) => n.id === noteId);
    if (!note || note.type === "booking") return;
    this.notes = this.notes.filter((n) => n !== note);
    this.emit({ t: "note-", note, why: "tear" });
  }

  setTtl(on: boolean) {
    this.ttl = on;
    this.emit({ t: "pulse", what: "ttl", on: false });
  }

  /** Have Gilroy cut a new key: the old one stops working everywhere. */
  rotateKey() {
    if (this.key.cutting > 0) return;
    this.key.cutting = 1.4;
  }

  /** Sit a housemate at an empty desk. */
  addServer() {
    if (this.servers >= 4) return;
    this.servers++;
    this.inboxCap = 6 + 2 * (this.servers - 1);
    this.emit({ t: "servers", n: this.servers });
    this.emit({ t: "pulse", what: "couch", on: false });
  }

  // ------------------------------------------------------------------ clock

  step(dt: number) {
    if (this.done) return;
    this.t += dt;
    this.pt += dt;
    if (this.dark > 0) {
      this.dark -= dt;
      if (this.dark <= 0) this.emit({ t: "power" });
    }
    if (this.deskOff > 0) this.deskOff -= dt;
    this.direct(dt);
    if (this.dark > 0) return;
    this.work(dt);
    this.robot(dt);
    this.expire();
    this.leak(dt);
    this.parade(dt);
  }

  drain(): Ev[] {
    const out = this.events;
    this.events = [];
    return out;
  }

  // --------------------------------------------------------------- internals

  private emit(e: Ev) {
    this.events.push(e);
  }

  private go(phase: string) {
    this.phase = phase;
    this.pt = 0;
    this.emit({ t: "phase", id: phase });
  }

  private first(key: string): boolean {
    if (this.once.has(key)) return false;
    this.once.add(key);
    return true;
  }

  /** True once, the first time the phase clock passes `at`. */
  private at(at: number, key: string): boolean {
    return this.pt >= at && this.first(`${this.phase}:${key}`);
  }

  private bark(who: Who, key: keyof typeof LINES, vars: Record<string, string | number> = {}) {
    let text: string = LINES[key];
    for (const [k, v] of Object.entries(vars)) text = text.replace(`{${k}}`, String(v));
    this.emit({ t: "bark", who, text });
  }

  private text(who: Who, name: string, key: keyof typeof LINES) {
    this.emit({ t: "text", who, name, text: LINES[key] });
  }

  private take(slip: Slip) {
    this.inbox = this.inbox.filter((s) => s !== slip);
  }

  private diner() {
    return DINERS[Math.floor(this.rng() * DINERS.length)];
  }

  private spawn(kind: Kind, extra: Partial<Slip> = {}, patience = 12): Slip | null {
    const slip: Slip = {
      id: this.nextId++, kind, who: this.diner(), born: this.t, due: this.t + patience, tried: [], ...extra,
    };
    this.stats.spawned++;
    if (this.inbox.length >= this.inboxCap) {
      this.stats.angry++;
      this.emit({ t: "spawn", slip });
      this.emit({ t: "gone", slip, why: "full" });
      return null;
    }
    this.inbox.push(slip);
    this.emit({ t: "spawn", slip });
    return slip;
  }

  private spawnPay(cheat = false, patience = 12) {
    const party = 2 + Math.floor(this.rng() * 4) * 2;
    if (cheat) {
      const who = this.stats.cheats + this.stats.caught === 0 ? { name: "Danesh", face: "danesh" } : this.diner();
      return this.spawn("pay", { who, party: 8, claimed: 0, cheat: true }, patience);
    }
    return this.spawn("pay", { party, claimed: party * DEPOSIT }, patience);
  }

  private spawnCancel(bot = false, patience = 12) {
    if (bot) {
      const no = this.botNo++;
      return this.spawn("cancel", { who: { name: "HubbubBot", face: "bot" }, no, bot: true }, patience);
    }
    const mine = this.bookings.filter((b) => (b.where === "ledger" || b.where === "notes") && !this.cancelling.has(b.no));
    if (!mine.length) return null;
    const b = mine[Math.floor(this.rng() * mine.length)];
    this.cancelling.add(b.no);
    return this.spawn("cancel", { who: { name: b.name, face: b.face }, no: b.no }, patience);
  }

  private spawnAsk(patience = 12) {
    const topics = Object.keys(TOPICS) as Topic[];
    return this.spawn("ask", { topic: topics[Math.floor(this.rng() * topics.length)] }, patience);
  }

  /** A steady trickle: `rate` slips a second of whatever `make` makes. */
  private flow(key: string, rate: number, dt: number, make: () => unknown) {
    this.acc[key] = (this.acc[key] ?? 0) + rate * dt;
    while (this.acc[key] >= 1) {
      this.acc[key] -= 1;
      make();
    }
  }

  /** While the player is showing the robot a new kind: one at a time, unhurried. */
  private handFlow(kind: Kind, make: () => unknown, gap = 1.3) {
    const waiting = this.inbox.filter((s) => s.kind === kind).length;
    const last = this.acc[`hand:${kind}`] ?? -9;
    if (waiting < 2 && this.t - last >= gap) {
      this.acc[`hand:${kind}`] = this.t;
      make();
    }
  }

  private lookup(slip: Slip): Note | undefined {
    if (slip.kind === "ask") return this.notes.find((n) => n.type === "answer" && n.topic === slip.topic);
    if (slip.kind === "free") return this.notes.find((n) => n.type === "free");
    return undefined;
  }

  private addNote(note: Note) {
    this.notes.push(note);
    this.emit({ t: "note+", note });
  }

  private money(amount: number, station: StationId | "strangers" | "desks") {
    this.till += amount;
    this.emit({ t: "money", amount, station });
  }

  private reply(slip: Slip, station: StationId, mood: "ok" | "bad" | "meh" | "sly", text: string, by: "hand" | "robot") {
    if (mood === "bad") this.stats.angry++;
    else this.stats.ok++;
    if (mood === "meh") this.stats.meh++;
    this.emit({ t: "reply", slip, station, mood, text, by });
  }

  private resolve(slip: Slip, station: StationId, by: "hand" | "robot") {
    const s = this.stats;
    switch (slip.kind) {
      case "book": {
        const b: Booking = { no: this.nextNo++, name: slip.who.name, face: slip.who.face, where: station as "notes" | "ledger", at: this.t };
        this.bookings.push(b);
        s.booked++;
        if (station === "notes") this.addNote({ id: this.nextId++, type: "booking", booking: b.no, face: b.face, at: this.t });
        this.reply(slip, station, "ok", `Table #${b.no}`, by);
        break;
      }
      case "pay": {
        const due = slip.party! * DEPOSIT;
        s.owed += due;
        if (station === "stamp") {
          s.taken += slip.claimed!;
          this.money(slip.claimed!, station);
          if (slip.cheat) {
            s.cheats++;
            this.reply(slip, station, "sly", "Paid $0", by);
          } else this.reply(slip, station, "ok", `Paid $${slip.claimed}`, by);
        } else {
          s.taken += due;
          this.money(due, station);
          if (slip.cheat) {
            s.caught++;
            this.reply(slip, station, "meh", `$${due}, actually`, by);
          } else this.reply(slip, station, "ok", `Paid $${due}`, by);
        }
        break;
      }
      case "cancel": {
        const b = this.bookings.find((x) => x.no === slip.no && (x.where === "ledger" || x.where === "notes"));
        if (station === "stamp") {
          if (b) {
            b.where = slip.bot ? "stolen" : "cancelled";
            if (slip.bot) s.stolen++;
            this.dropNote(b.no);
          }
          this.reply(slip, station, slip.bot ? "sly" : "ok", `#${slip.no} freed`, by);
        } else if (slip.bot) {
          s.refused++;
          this.reply(slip, station, "meh", "Not your table", by);
        } else {
          if (b) {
            b.where = "cancelled";
            this.dropNote(b.no);
          }
          this.reply(slip, station, "ok", `#${slip.no} freed`, by);
        }
        break;
      }
      case "ask": {
        const topic = slip.topic!;
        if (station === "key") {
          // Their phone asks the model itself, on our key, which it now holds.
          s.bill += 1;
          this.money(-1, "model");
          if (!this.key.leaked) {
            this.key.leaked = true;
            this.key.everLeaked = true;
            this.key.at = this.t;
          }
          this.reply(slip, station, "ok", `Try ${this.truth[topic]}`, by);
        } else if (station === "model") {
          s.bill += 1;
          this.money(-1, "model");
          if (this.cache) {
            this.notes = this.notes.filter((n) => !(n.type === "answer" && n.topic === topic));
            this.addNote({ id: this.nextId++, type: "answer", topic, value: this.truth[topic], at: this.t });
          }
          this.reply(slip, station, "ok", `Try ${this.truth[topic]}`, by);
        } else {
          const note = this.lookup(slip) as Extract<Note, { type: "answer" }>;
          s.hits++;
          if (note.value !== this.truth[topic]) {
            s.stale++;
            this.reply(slip, station, "bad", `Try ${note.value}`, by);
            if (s.stale % 2 === 1) this.emit({ t: "arrive", name: slip.who.name, face: slip.who.face, ok: false, text: `${note.value}: full` });
          } else this.reply(slip, station, "ok", `Try ${note.value}`, by);
          if (by === "hand") this.hit("ask");
        }
        break;
      }
      case "free": {
        if (station === "ledger") {
          if (this.cache) {
            this.notes = this.notes.filter((n) => n.type !== "free");
            this.addNote({ id: this.nextId++, type: "free", ver: this.freeVer, at: this.t });
          }
          this.reply(slip, station, "ok", "3 places free", by);
        } else {
          const note = this.lookup(slip) as Extract<Note, { type: "free" }>;
          s.hits++;
          // An old list sends them to a table that's gone. The ledger still
          // has the last word when they try to book it, so it's a sorry, not
          // a double booking.
          if (note.ver !== this.freeVer) this.reply(slip, station, "meh", "Oh. Just went", by);
          else this.reply(slip, station, "ok", "3 places free", by);
          if (by === "hand") this.hit("free");
        }
        break;
      }
    }
    const fromNote = station === "notes" && slip.kind !== "book";
    if (by === "hand" && !fromNote) this.teach(slip.kind, station);
  }

  private dropNote(booking: number) {
    const note = this.notes.find((n) => n.type === "booking" && n.booking === booking);
    if (note) {
      this.notes = this.notes.filter((n) => n !== note);
      this.emit({ t: "note-", note, why: "tear" });
    }
  }

  /** The robot watches. With no rule yet, three by hand and it does what it
   * saw most. With one, three running done some other way change its mind. */
  private teach(kind: Kind, station: StationId) {
    const seen = (this.seen[kind] ??= []);
    seen.push(station);
    if (seen.length > 3) seen.shift();
    const rule = this.rules[kind];
    const cached = rule?.[0] === "notes" && kind !== "book";
    const base = cached ? rule![1] : rule?.[0];
    if (!rule) {
      if (seen.length < 3) return;
      const count = (id: StationId) => seen.filter((x) => x === id).length;
      let best = seen[seen.length - 1];
      for (const id of seen) if (count(id) > count(best)) best = id;
      this.setRule(kind, [best]);
    } else if (station === base) {
      this.streak[kind] = 0;
    } else {
      const n = (this.streak[kind] = seen.at(-2) === station || !this.streak[kind] ? (this.streak[kind] ?? 0) + 1 : 1);
      if (n >= 3) this.setRule(kind, cached ? ["notes", station] : [station]);
      else this.hold(kind, 4);
    }
  }

  /** Answering from a note by hand, twice, shows the robot to look there first. */
  private hit(kind: Kind) {
    const rule = this.rules[kind];
    if (rule?.[0] === "notes" || rule?.[0] === "key") return;
    const key = `hits:${kind}`;
    this.acc[key] = (this.acc[key] ?? 0) + 1;
    if (this.acc[key] >= 2) this.setRule(kind, ["notes", ...(rule ?? [kind === "ask" ? "model" : "ledger"] as StationId[])]);
  }

  private setRule(kind: Kind, rule: StationId[]) {
    this.rules[kind] = rule;
    this.streak[kind] = 0;
    this.holdTo[kind] = 0;
    this.emit({ t: "learned", kind, rule });
    this.bark("aleister", `learn_${kind}_${rule[0]}` as keyof typeof LINES);
  }

  private work(dt: number) {
    for (const station of ["ledger", "adder", "model"] as const) {
      const q = this.queues[station];
      if (!q.length) continue;
      q[0].left -= dt;
      if (q[0].left > 0) continue;
      const job = q.shift()!;
      if (job.slip) this.resolve(job.slip, station, job.by);
      else if (job.note?.type === "booking") {
        const b = this.bookings.find((x) => x.no === (job.note as { booking: number }).booking);
        if (b && b.where === "notes") b.where = "ledger";
      }
    }
  }

  private robot(dt: number) {
    for (let i = 0; i < this.servers; i++) {
      this.cd[i] -= dt;
      if (this.cd[i] > 0 || (i === 0 && this.deskOff > 0)) continue;
      for (const slip of this.inbox) {
        const rule = this.rules[slip.kind];
        if (!rule || this.t - slip.born < ROBOT_WAIT || this.held(slip.kind)) continue;
        if (rule.some((station) => this.send(slip.id, station, "robot"))) {
          this.cd[i] = ROBOT_GAP;
          break;
        }
      }
    }
  }

  private expire() {
    for (const slip of [...this.inbox]) {
      if (this.t < slip.due) continue;
      this.take(slip);
      this.stats.angry++;
      if (slip.kind === "cancel" && !slip.bot) this.cancelling.delete(slip.no!);
      this.emit({ t: "gone", slip, why: "timeout" });
    }
    if (!this.ttl) return;
    for (const note of [...this.notes]) {
      if (note.type === "booking" || this.t - note.at < TTL) continue;
      this.notes = this.notes.filter((n) => n !== note);
      this.emit({ t: "note-", note, why: "ttl" });
    }
  }

  /** A key that's out is out: strangers spend on it until the lock changes. */
  private leak(dt: number) {
    const k = this.key;
    if (k.cutting > 0) {
      k.cutting -= dt;
      if (k.cutting <= 0) {
        k.leaked = false;
        this.emit({ t: "keycut" });
        this.emit({ t: "pulse", what: "key", on: false });
      }
    }
    if (!k.leaked || this.t - k.at < 4) return;
    const rate = Math.min(9, 2 + (this.t - k.at - 4) * 0.6);
    this.stats.strangers += rate * dt;
    this.stats.bill += rate * dt;
    this.till -= rate * dt;
    this.strangerTick -= dt;
    if (this.strangerTick <= 0) {
      this.strangerTick = 0.7;
      this.emit({ t: "stranger" });
      this.emit({ t: "money", amount: -Math.round(rate * 0.7), station: "strangers" });
    }
  }

  private unplug() {
    const total = this.servers < 2;
    this.emit({ t: "unplug", total });
    // Whatever was only in memory is gone, whichever desk it was on.
    for (const note of this.notes) this.emit({ t: "note-", note, why: "wipe" });
    this.notes = [];
    for (const b of this.bookings) {
      if (b.where === "notes") {
        b.where = "lost";
        this.stats.lost++;
      }
    }
    if (!total) {
      this.deskOff = 5;
      return;
    }
    this.dark = 2.4;
    this.stats.outage = this.night === 4;
    for (const slip of this.inbox) this.emit({ t: "gone", slip, why: "power" });
    this.stats.angry += this.night === 4 ? this.inbox.length : 0;
    this.inbox = [];
    for (const q of Object.values(this.queues)) q.length = 0;
  }

  /** Diners turn up at Nonna's, a few at a time, and find out. */
  private startArrivals() {
    const due = this.bookings.filter((b) => b.no > this.arrivedTo && b.where !== "cancelled");
    this.arrivedTo = this.nextNo - 1;
    for (const b of due) if (b.where === "ledger" || b.where === "notes") this.stats.kept++;
    // Show the unhappy ones first among a dozen, so a bad night reads as one.
    const bad = due.filter((b) => b.where === "lost" || b.where === "stolen");
    const good = due.filter((b) => b.where === "ledger" || b.where === "notes");
    this.arrivals = [...bad.slice(0, 7), ...good.slice(0, 12 - Math.min(7, bad.length))];
    this.arrivals.sort((a, b) => a.no - b.no);
    this.emit({ t: "door", seated: good.length, turned: bad.length });
    this.arriveGap = 0.4;
  }

  private parade(dt: number) {
    if (!this.arrivals.length) return;
    this.arriveGap -= dt;
    if (this.arriveGap > 0) return;
    this.arriveGap = 0.32;
    const b = this.arrivals.shift()!;
    const ok = b.where === "ledger" || b.where === "notes";
    this.emit({
      t: "arrive", name: b.name, face: b.face, ok,
      text: ok ? `Table #${b.no}` : b.where === "stolen" ? "Cancelled?!" : "No booking?!",
    });
  }

  private get parading() {
    return this.arrivals.length > 0;
  }

  private end() {
    this.done = true;
    this.emit({ t: "end" });
  }

  // -------------------------------------------------------------- the nights

  private direct(dt: number) {
    if (this.night === 1) this.night1(dt);
    else if (this.night === 2) this.night2(dt);
    else if (this.night === 3) this.night3(dt);
    else this.night4(dt);
  }

  private book = (patience = 12) => this.spawn("book", { party: 2 + Math.floor(this.rng() * 3) * 2 }, patience);

  /** Night 1: bookings. Notes are fast; Ulrich needs the socket. */
  private night1(dt: number) {
    const p = this.pt;
    switch (this.phase) {
      case "solo":
        if (this.at(0.4, "hello")) this.bark("ulrich", "n1_hello");
        if (p > 1.2) this.handFlow("book", () => this.book(60));
        if (this.rules.book) this.go("boom");
        break;
      case "boom":
        // More than the robot can clear alone: a hand that helps keeps the pile down.
        this.flow("book", Math.min(3.2, 1.8 + p * 0.2), dt, this.book);
        if (this.at(1.5, "press")) this.bark("ulrich", "n1_press");
        if (this.at(6.5, "warn")) {
          this.bark("ulrich", "n1_scooter");
          this.emit({ t: "warn", secs: 4 });
        }
        if (p >= 10.5) {
          this.unplug();
          this.mark = this.nextNo - 1;
          this.go("dark1");
        }
        break;
      case "dark1":
        if (this.at(2.6, "arrive")) {
          this.startArrivals();
          this.text("d1", "Dana", "n1_text1");
        }
        if (this.at(5, "nonna")) this.text("nonna", "Nonna", "n1_text2");
        if (p > 3 && !this.parading && this.at(0, "ledger")) {
          this.on.ledger = true;
          this.emit({ t: "station", id: "ledger" });
          this.bark("gerard", "n1_ledger");
          this.emit({ t: "pulse", what: "chip:book", on: true });
          this.go("retrain");
        }
        break;
      case "retrain":
        this.flow("book", 1, dt, this.book);
        if (this.rules.book?.[0] === "notes" && !this.streak.book && this.at(10, "nudge")) this.bark("gerard", "n1_nudge");
        if (this.rules.book?.[0] === "ledger" || p > 22) {
          this.emit({ t: "pulse", what: "chip:book", on: false });
          this.go("boom2");
        }
        break;
      case "boom2":
        this.flow("book", Math.min(2.8, 1.4 + p * 0.08), dt, this.book);
        if (this.at(18, "warn")) {
          this.bark("ulrich", "n1_scooter2");
          this.emit({ t: "warn", secs: 5 });
        }
        if (p >= 23) {
          this.unplug();
          this.go("dark2");
        }
        break;
      case "dark2":
        if (this.at(2.6, "arrive")) {
          const lost = this.bookings.filter((b) => b.no > this.arrivedTo && b.where === "lost").length;
          this.startArrivals();
          if (lost > 2) this.text("nonna", "Nonna", "n1_text3");
          else this.bark("gerard", "n1_kept");
        }
        if (p > 3.2 && !this.parading && this.at(0, "end")) this.end();
        break;
    }
  }

  /** Deposits, with the cheats that start once a first one has been seen to work. */
  private pays(dt: number, rate: number) {
    const s = this.stats;
    this.acc.payT = (this.acc.payT ?? 0) + dt;
    this.acc.cheatDue ??= 4;
    this.flow("pay", rate, dt, () => {
      const due = this.acc.payT >= this.acc.cheatDue;
      if (due) this.acc.cheatDue = this.acc.payT + 2.5;
      const spread = s.cheats > 0 && this.rng() < Math.min(0.7, 0.25 + 0.1 * s.cheats);
      this.spawnPay(due || spread);
    });
    if (s.cheats >= 1 && this.first("t-danesh")) this.text("danesh", "Danesh", "n2_text1");
    if (s.cheats >= 3 && this.first("b-light")) {
      this.bark("gerard", "n2_light");
      this.emit({ t: "pulse", what: "chip:pay", on: true });
    }
    if (s.caught >= 1 && this.first("t-caught")) this.text("danesh", "Danesh", "n2_text2");
    if (s.caught >= 2 && this.rules.pay?.[0] === "adder" && this.first("b-caught")) {
      this.bark("gilroy", s.cheats ? "n2_fixed" : "n2_never");
      this.emit({ t: "pulse", what: "chip:pay", on: false });
    }
  }

  /** Night 2: the slip says what the phone wants it to say. */
  private night2(dt: number) {
    const p = this.pt;
    const s = this.stats;
    this.flow("a:book", 0.4, dt, this.book);
    switch (this.phase) {
      case "pay-teach":
        if (this.at(0.4, "hello")) this.bark("gerard", "n2_hello");
        if (p > 1.5) this.handFlow("pay", () => this.spawnPay(false, 60));
        if (!this.rules.pay && p > 30) this.setRule("pay", ["stamp"]);
        if (this.rules.pay) this.go("pay-run");
        break;
      case "pay-run":
        // The robot has the deposits; the next thing lands on the desk while they go wrong.
        this.pays(dt, 1.2);
        if (this.at(3, "cancel")) this.bark("gerard", "n2_cancel");
        if (p > 3.5) this.handFlow("cancel", () => this.spawnCancel(false, 60), 1.5);
        if (!this.rules.cancel && p > 30) this.setRule("cancel", ["stamp"]);
        if (this.rules.cancel && p > 12) this.go("bot");
        else if (this.rules.cancel) this.flow("cancel", 0.35, dt, () => this.spawnCancel());
        break;
      case "bot": {
        // The bot first, then the dinner rush on top: more than the robot clears alone.
        const rush = p > 15;
        if (rush) this.flow("r:book", 0.3, dt, this.book);
        this.pays(dt, rush ? 1.6 : 1.2);
        this.flow("cancel", rush ? 0.5 : 0.35, dt, () => this.spawnCancel());
        if (p > 3 && p < 14) this.flow("bot", 1.3, dt, () => this.spawnCancel(true, 9));
        if (p > 22 && p < 30) this.flow("bot", 0.8, dt, () => this.spawnCancel(true, 9));
        if (this.at(15, "rush")) this.emit({ t: "sign", text: "Dinner rush!" });
        if (s.stolen >= 3 && this.first("b-loop")) {
          this.bark("gilroy", "n2_loop");
          this.emit({ t: "pulse", what: "chip:cancel", on: true });
        }
        if (s.refused >= 3 && this.rules.cancel?.[0] === "ledger" && this.first("b-refused")) {
          this.bark("gilroy", s.stolen ? "n2_stopped" : "n2_goodbook");
          this.emit({ t: "pulse", what: "chip:cancel", on: false });
        }
        if (this.at(34, "arrive")) {
          if (this.rules.pay?.[0] === "stamp" && s.cheats > 5) this.bark("gilroy", "n2_donation");
          this.emit({ t: "pulse", what: "chip:cancel", on: false });
          this.emit({ t: "pulse", what: "chip:pay", on: false });
          for (const slip of this.inbox) this.emit({ t: "gone", slip, why: "power" });
          this.inbox = [];
          this.startArrivals();
          if (s.stolen > 0) this.text("d4", "Rosa", "n2_text3");
        }
        if (p > 35.5 && !this.parading) this.end();
        break;
      }
    }
  }

  /** Night 3: the model costs money, the key is a secret, and copies go off. */
  private night3(dt: number) {
    const p = this.pt;
    const s = this.stats;
    const k = this.key;
    this.flow("a:book", 0.3, dt, this.book);
    this.flow("a:pay", 0.3, dt, () => this.spawnPay(this.rng() < 0.15));
    this.flow("a:cancel", 0.06, dt, () => this.spawnCancel());
    const rule = this.rules.ask?.[0];
    const base = this.rules.ask?.at(-1);
    const asks = (rate = 1.3) => this.flow("ask", rate, dt, () => this.spawnAsk());
    switch (this.phase) {
      case "ask-teach":
        if (this.at(0.4, "hello")) this.bark("aleister", "n3_hello");
        if (this.at(4.5, "key")) this.bark("gilroy", "n3_key");
        if (p > 1.5) this.handFlow("ask", () => this.spawnAsk(60), 1.5);
        if (!rule && p > 30) this.setRule("ask", ["model"]);
        if (rule) this.go("ask-run");
        break;
      case "ask-run":
        asks();
        if (k.leaked && this.t - k.at > 6 && this.first("b-leak")) {
          this.bark("gilroy", "n3_leak");
          this.emit({ t: "pulse", what: "chip:ask", on: true });
          this.emit({ t: "pulse", what: "key", on: true });
        }
        if (k.leaked && base !== "key" && this.once.has("b-leak")) {
          if (this.acc.ruleAt === undefined) this.emit({ t: "pulse", what: "chip:ask", on: false });
          this.acc.ruleAt ??= p;
        }
        if (k.leaked && this.acc.ruleAt !== undefined && p > this.acc.ruleAt + 3.5 && this.first("b-lock")) this.bark("gilroy", "n3_lock");
        if (k.everLeaked && !k.leaked && base === "key" && this.first("b-again")) this.bark("gilroy", "n3_again");
        if (k.everLeaked && !k.leaked && base !== "key" && this.first("b-cost")) {
          this.bark("gerard", "n3_cost", { n: Math.round(s.strangers) });
          this.acc.next = p + 3;
        }
        if (!k.everLeaked) this.acc.next ??= p + 9;
        if ((this.acc.next !== undefined && p > this.acc.next) || p > 40) {
          this.emit({ t: "pulse", what: "chip:ask", on: false });
          this.go("cache");
        }
        break;
      case "cache":
        if (this.at(0, "on")) {
          this.cache = true;
          this.emit({ t: "station", id: "notes" });
          this.bark("ricky", "n3_same");
          this.emit({ t: "pulse", what: "notes", on: true });
        }
        asks(1.5);
        if (rule !== "notes" && this.at(11, "nudge")) this.bark("ricky", "n3_nudge");
        if (rule === "notes" && this.acc.cachedAt === undefined) {
          this.acc.cachedAt = p;
          this.emit({ t: "pulse", what: "notes", on: false });
        }
        if ((this.acc.cachedAt !== undefined && p > this.acc.cachedAt + 7) || p > 26) {
          this.emit({ t: "pulse", what: "notes", on: false });
          this.go("stale");
        }
        break;
      case "stale": {
        if (this.at(0, "full")) {
          this.truth.cosy = "Luna";
          this.freeVer++;
          this.emit({ t: "sign", text: "Nonna's: FULL" });
          this.text("nonna", "Nonna", "n3_text1");
        }
        asks(1.5);
        const old = this.notes.some((n) => n.type === "answer" && n.value !== this.truth[n.topic]);
        // A robot that never reads the notes can't be caught out by one.
        if (rule !== "notes" && p > 6) this.go("stale2");
        if (s.stale >= 3 && old && this.first("b-old")) {
          this.bark("gilroy", "n3_old");
          this.emit({ t: "pulse", what: "stale", on: true });
        }
        if (!old && p > 4 && this.first("offer")) {
          this.emit({ t: "pulse", what: "stale", on: false });
          this.ttlOffered = true;
          if (rule === "notes") {
            this.bark("gilroy", "n3_ttl");
            this.emit({ t: "pulse", what: "ttl", on: true });
          }
          this.acc.staleEnd = p + 5;
        }
        if ((this.acc.staleEnd !== undefined && p > this.acc.staleEnd) || p > 24) {
          this.ttlOffered = true;
          this.emit({ t: "pulse", what: "stale", on: false });
          this.go("stale2");
        }
        break;
      }
      case "stale2":
        asks(1.5);
        if (this.at(4, "oven")) {
          this.truth.family = "Big Sal's";
          this.freeVer++;
          this.emit({ t: "sign", text: "Luna: oven's out" });
        }
        if (this.at(11, "warn")) {
          this.bark("ulrich", "n3_scooter");
          this.emit({ t: "warn", secs: 3 });
          this.emit({ t: "pulse", what: "ttl", on: false });
        }
        if (this.at(14, "unplug")) {
          const before = s.lost;
          this.unplug();
          this.acc.lostNow = s.lost - before;
        }
        if (this.at(17.5, "copies")) this.bark("gerard", this.acc.lostNow ? "n3_notcopies" : "n3_copies");
        if (p > 24) this.end();
        break;
    }
  }

  /** Night 4: everything the robot was taught, at launch traffic. */
  private night4(dt: number) {
    const p = this.pt;
    const s = this.stats;
    const rule = this.rules.free?.[0];
    const mix = (rate: number, cheats = 0.1) => {
      this.flow("m:book", rate * 0.15, dt, this.book);
      this.flow("m:pay", rate * 0.13, dt, () => this.spawnPay(this.rng() < cheats));
      this.flow("m:ask", rate * 0.14, dt, () => this.spawnAsk());
      this.flow("m:cancel", rate * 0.03, dt, () => this.spawnCancel());
      if (rule) this.flow("m:free", rate * 0.55, dt, () => this.spawn("free"));
      else this.handFlow("free", () => this.spawn("free", {}, 30), 1.2);
    };
    if (this.servers > 1) {
      const wages = (this.servers - 1) * 0.5 * dt;
      s.desks += wages;
      this.till -= wages;
    }
    const jam = this.queues.ledger.length >= TIME.ledger.cap;
    this.acc.jam = jam ? (this.acc.jam ?? 0) + dt : 0;
    this.acc.full = this.inbox.length >= this.inboxCap - 1 ? (this.acc.full ?? 0) + dt : 0;
    if (this.phase !== "free-teach" && this.phase !== "finale") {
      if (this.acc.full > 2 && this.servers === 1 && this.acc.jam < 1 && this.first("b-desk")) this.bark("danesh", "n4_desk");
      if (this.acc.jam > 3 && rule === "ledger" && this.first("b-pages")) {
        this.bark("gerard", "n4_pages");
        this.emit({ t: "pulse", what: "chip:free", on: true });
      }
      if (this.acc.jam > 5 && this.once.has("b-pages") && this.servers >= 2 && this.first("b-queue")) {
        this.bark("gilroy", "n4_queue", { n: this.servers });
      }
      if (rule === "notes" && this.once.has("b-pages") && this.first("b-better")) {
        this.bark("gerard", "n4_better");
        this.emit({ t: "pulse", what: "chip:free", on: false });
      }
      if (rule === "notes" && !this.ttl && s.meh > 12 && this.first("b-shelf")) {
        this.bark("gilroy", "n4_shelf");
        this.emit({ t: "pulse", what: "ttl", on: true });
      }
    }
    switch (this.phase) {
      case "free-teach":
        if (this.at(0.4, "hello")) this.bark("ulrich", "n4_hello");
        mix(0.9);
        if (!rule && p > 30) this.setRule("free", ["ledger"]);
        if (rule) this.go("ramp1");
        break;
      case "ramp1":
        if (this.at(0.5, "out")) {
          this.bark("ulrich", "n4_out");
          this.emit({ t: "pulse", what: "couch", on: true });
        }
        mix(Math.min(6, 2.2 + p * 0.25));
        if (p > 17) this.go("ramp2");
        break;
      case "ramp2":
        mix(Math.min(9, 6 + p * 0.2));
        if (this.at(3, "full")) {
          this.freeVer++;
          this.emit({ t: "sign", text: "Nonna's: FULL" });
        }
        if (this.at(19, "warn")) {
          this.bark("ulrich", "n4_fog");
          this.emit({ t: "warn", secs: 3 });
        }
        if (p > 22) {
          const before = s.lost;
          this.unplug();
          this.acc.lostNow = s.lost - before;
          this.go("chaos");
        }
        break;
      case "chaos":
        mix(8, 0.35);
        if (this.at(3.5, "noticed")) {
          this.bark(s.outage ? "gilroy" : "gerard", s.outage ? "n4_outage" : this.acc.lostNow ? "n3_notcopies" : "n4_nobody");
        }
        if (p > 5 && p < 14) this.flow("bot", 1.4, dt, () => this.spawnCancel(true, 8));
        if (this.at(9, "full")) this.freeVer++;
        if (this.at(21, "verdict")) {
          const clean = !s.cheats && !s.stolen && !s.strangers && !s.outage && !s.lost;
          this.bark("gilroy", clean ? "n4_clean" : "n4_dirty");
        }
        if (p > 24) {
          for (const slip of this.inbox) this.emit({ t: "gone", slip, why: "power" });
          this.inbox = [];
          this.startArrivals();
          this.go("finale");
        }
        break;
      case "finale":
        if (p > 1 && !this.parading && this.at(0, "end")) this.end();
        break;
    }
  }
}

// ------------------------------------------------------------------ results

export type Tally = { stars: number; rows: { label: string; value: string; good: boolean }[] };

export function tally(e: Engine): Tally {
  const s = e.stats;
  const rows: Tally["rows"] = [];
  let stars = 3;
  const row = (label: string, value: string, good: boolean) => rows.push({ label, value, good });
  const worse = (n: number) => (stars = Math.min(stars, n));
  if (e.night === 1) {
    const second = e.bookings.filter((b) => b.no > e.mark);
    const kept = second.filter((b) => b.where === "ledger").length;
    const first = e.bookings.length - second.length;
    row("Bookings lost to the first unplugging", String(first), false);
    row("Bookings that survived the second", `${kept} of ${second.length}`, kept === second.length);
    if (kept < second.length) worse(kept >= second.length * 0.6 ? 2 : 1);
  } else if (e.night === 2) {
    const short = Math.round(s.owed - s.taken);
    row("Deposits collected", `$${Math.round(s.taken)} of $${Math.round(s.owed)}`, short === 0);
    row("Tables cancelled by a stranger", String(s.stolen), s.stolen === 0);
    if (short > 0) worse(short <= s.owed * 0.2 ? 2 : 1);
    if (s.stolen > 0) worse(s.stolen <= 4 ? 2 : 1);
  } else if (e.night === 3) {
    row("Spent by strangers on your key", `$${Math.round(s.strangers)}`, s.strangers < 1);
    row("The Model's bill for your diners", `$${Math.round(s.bill - s.strangers)}`, s.hits > 20);
    row("Answered free, from a note", String(s.hits), s.hits > 20);
    row("Diners sent somewhere full", String(s.stale), s.stale <= 6);
    if (s.strangers >= 1) worse(s.strangers < 60 ? 2 : 1);
    if (s.stale > 6) worse(s.stale <= 14 ? 2 : 1);
    if (s.hits <= 20) worse(2);
    if (s.lost) {
      row("Bookings lost to the scooter", String(s.lost), false);
      worse(1);
    }
  } else {
    const pct = Math.round((100 * s.ok) / Math.max(1, s.ok + s.angry));
    row("Diners answered", `${pct}%`, pct >= 90);
    if (pct < 90) worse(pct >= 70 ? 2 : 1);
    const short = Math.round(s.owed - s.taken);
    row("Deposits missing", `$${short}`, short === 0);
    row("Tables cancelled by a stranger", String(s.stolen), s.stolen === 0);
    row("Bookings lost when the plug went", String(s.lost), s.lost === 0);
    if (s.strangers >= 1) row("Spent by strangers on your key", `$${Math.round(s.strangers)}`, false);
    if (s.outage) row("Forkcast went dark", "every diner mid-tap", false);
    row("Extra desks", `${e.servers - 1} ($${Math.round(s.desks)})`, true);
    if (short > 0 || s.stolen > 0 || s.lost > 0 || s.strangers >= 1 || s.outage) worse(pct >= 70 ? 2 : 1);
  }
  return { stars, rows };
}
