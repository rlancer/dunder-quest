// Players made of code, for the tests: one who does everything the careful
// way, one who always takes the fast way, and one who takes the fast way
// until somebody complains.

import { type Carry, Engine, type Kind, type StationId } from "./engine";

export type Style = "careful" | "lazy" | "learner";

const FAST: Record<Kind, StationId> = { book: "notes", pay: "stamp", cancel: "stamp", ask: "key", free: "ledger" };
const SAFE: Record<Kind, StationId> = { book: "ledger", pay: "adder", cancel: "ledger", ask: "model", free: "ledger" };

/** One move, if the bot has a hand free. */
export function move(e: Engine, style: Style, pulsing: Set<string>): boolean {
  const careful = style === "careful";
  // Kinds whose rule this player wants changed, and so handles personally.
  const fixing = new Set<Kind>();
  if (style !== "lazy") {
    for (const kind of Object.keys(e.rules) as Kind[]) {
      const base = e.rules[kind]!.at(-1)!;
      const bad = base === FAST[kind] && kind !== "free" && (kind !== "book" || e.on.ledger);
      if (bad && (careful || pulsing.has(`chip:${kind}`) || e.streak[kind])) fixing.add(kind);
    }
    for (const kind of fixing) {
      if (!e.held(kind)) {
        e.hold(kind);
        return true;
      }
    }
    if (e.key.leaked && e.rules.ask?.at(-1) !== "key" && e.key.cutting <= 0) {
      e.rotateKey();
      return true;
    }
    if (e.ttlOffered && !e.ttl && (careful || pulsing.has("ttl"))) {
      e.setTtl(true);
      return true;
    }
    const old = e.notes.find((n) => n.type === "answer" && n.value !== e.truth[n.topic]);
    if (old && (careful || pulsing.has("stale"))) {
      e.tear(old.id);
      return true;
    }
    if (e.night === 4 && e.servers < 4 && e.inbox.length >= e.inboxCap - 2) {
      e.addServer();
      return true;
    }
    const note = e.notes.find((n) => n.type === "booking");
    if (note && e.on.ledger && e.flush(note.id)) return true;
  }
  // The new thing first, then lend the robot a hand with the pile.
  const mine = (k: Kind) => !e.rules[k] || fixing.has(k);
  const order = [...e.inbox].sort((a, b) => Number(mine(b.kind)) - Number(mine(a.kind)));
  for (const slip of order) {
    const k = slip.kind;
    const wantNotes = (k === "ask" || k === "free") && style !== "lazy" && e.cache && !slip.tried.includes("notes");
    if (wantNotes && e.send(slip.id, "notes")) return true;
    const rule = e.rules[k]?.at(-1);
    let to = careful || fixing.has(k) ? SAFE[k] : rule && style === "learner" ? rule : FAST[k];
    if (!e.on[to]) to = "notes";
    if (e.send(slip.id, to)) return true;
  }
  return false;
}

/** Play one night to its end. A hand moves about twice a second. */
export function playNight(night: number, style: Style, carry?: Carry, seed = 7): Engine {
  const e = new Engine(night, carry, seed);
  const pulsing = new Set<string>();
  let hand = 0;
  for (let i = 0; i < 20 * 400 && !e.done; i++) {
    e.step(0.05);
    for (const ev of e.drain()) {
      if (ev.t === "pulse") ev.on ? pulsing.add(ev.what) : pulsing.delete(ev.what);
    }
    hand -= 0.05;
    if (hand <= 0 && move(e, style, pulsing)) hand = 0.5;
  }
  return e;
}

export function playAll(style: Style, seed = 7): Engine[] {
  const nights: Engine[] = [];
  let carry: Carry | undefined;
  for (let n = 1; n <= 4; n++) {
    const e = playNight(n, style, carry, seed);
    carry = e.carry();
    nights.push(e);
  }
  return nights;
}
