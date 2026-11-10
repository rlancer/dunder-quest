// Each night has to prove its own lesson: the careful way gets through it,
// the fast way doesn't, and the difference is the thing the night is about.
// The players are in bots.ts.

import { describe, expect, it } from "vitest";
import { playAll, playNight } from "./bots";
import { Engine, type Ev, type Kind, ROUTES, type StationId, tally } from "./engine";
import { LINES, RULE_NAME, TERMS, brief } from "./lines";

const careful = playAll("careful");
const lazy = playAll("lazy");
const learner = playAll("learner");

describe("every night ends", () => {
  it.each([[careful], [lazy], [learner]])("for each kind of player", (nights) => {
    for (const e of nights) {
      expect(e.done).toBe(true);
      expect(e.t).toBeGreaterThan(35);
      expect(e.t).toBeLessThan(150);
    }
  });

  it("with nobody at the desk at all, once the first night has been shown", () => {
    for (let n = 2; n <= 4; n++) {
      const e = new Engine(n);
      for (let i = 0; i < 20 * 300 && !e.done; i++) e.step(0.05);
      expect(e.done).toBe(true);
    }
    // The first night waits for a first move: it's where the game is learned.
    const first = new Engine(1);
    for (let i = 0; i < 20 * 120; i++) first.step(0.05);
    expect(first.phase).toBe("solo");
  });

  it("the same way twice", () => {
    const again = playAll("learner");
    expect(again.map((e) => e.stats)).toEqual(learner.map((e) => e.stats));
  });
});

describe("night 1: where a booking is kept", () => {
  it("loses every booking on a note when the plug is pulled", () => {
    const e = lazy[0];
    expect(e.rules.book).toEqual(["notes"]);
    expect(e.bookings.every((b) => b.where === "lost")).toBe(true);
    expect(tally(e).stars).toBe(1);
  });

  it("keeps every booking that was written in the book", () => {
    const e = careful[0];
    expect(e.rules.book).toEqual(["ledger"]);
    const second = e.bookings.filter((b) => b.no > e.mark);
    expect(second.length).toBeGreaterThan(20);
    expect(second.every((b) => b.where === "ledger")).toBe(true);
    expect(tally(e).stars).toBe(3);
  });

  it("nobody escapes the first unplugging: there's no book yet", () => {
    for (const e of [careful[0], lazy[0]]) {
      expect(e.bookings.filter((b) => b.no <= e.mark).every((b) => b.where === "lost")).toBe(true);
    }
  });
});

describe("night 2: the slip is written on the diner's phone", () => {
  it("stamping takes less than it's owed, and frees strangers' tables", () => {
    const s = lazy[1].stats;
    expect(s.cheats).toBeGreaterThan(8);
    expect(s.taken).toBeLessThan(s.owed * 0.7);
    expect(s.stolen).toBeGreaterThan(5);
    expect(tally(lazy[1]).stars).toBe(1);
  });

  it("working it out, and asking the book whose table it is, loses nothing", () => {
    const s = careful[1].stats;
    expect(s.cheats).toBe(0);
    expect(s.caught).toBeGreaterThan(3);
    expect(s.taken).toBe(s.owed);
    expect(s.stolen).toBe(0);
    expect(s.refused).toBeGreaterThan(5);
    expect(tally(careful[1]).stars).toBe(3);
  });

  it("fixing it late costs something, and less than never", () => {
    const s = learner[1].stats;
    expect(learner[1].rules.pay).toEqual(["adder"]);
    expect(learner[1].rules.cancel).toEqual(["ledger"]);
    expect(s.cheats).toBeGreaterThan(0);
    expect(s.cheats).toBeLessThan(lazy[1].stats.cheats);
  });
});

describe("night 3: the key, and copies of answers", () => {
  it("a key handed out is spent by strangers until the lock changes", () => {
    expect(lazy[2].stats.strangers).toBeGreaterThan(200);
    expect(lazy[2].key.leaked).toBe(true);
    expect(careful[2].stats.strangers).toBe(0);
    expect(learner[2].stats.strangers).toBeGreaterThan(0);
    expect(learner[2].stats.strangers).toBeLessThan(lazy[2].stats.strangers / 4);
    expect(learner[2].key.leaked).toBe(false);
  });

  it("changing the rule alone doesn't stop the spending", () => {
    const e = new Engine(3, careful[1].carry());
    const drive = (secs: number, to?: StationId) => {
      for (let i = 0; i < secs * 20; i++) {
        e.step(0.05);
        const ask = e.inbox.find((s) => s.kind === "ask");
        if (to && ask && i % 10 === 0) e.send(ask.id, to);
      }
    };
    drive(12, "key");
    expect(e.rules.ask).toEqual(["key"]);
    drive(8);
    expect(e.key.leaked).toBe(true);
    e.hold("ask", 30);
    drive(12, "model");
    expect(e.rules.ask).toEqual(["model"]);
    const before = e.stats.strangers;
    drive(4);
    expect(e.key.leaked).toBe(true);
    expect(e.stats.strangers).toBeGreaterThan(before + 10);
    e.rotateKey();
    drive(2);
    const after = e.stats.strangers;
    drive(4);
    expect(e.key.leaked).toBe(false);
    expect(e.stats.strangers).toBe(after);
  });

  it("notes of old answers cut the bill", () => {
    const paid = (e: Engine) => e.stats.bill - e.stats.strangers;
    expect(careful[2].stats.hits).toBeGreaterThan(25);
    expect(paid(careful[2])).toBeLessThan(paid(lazy[2]) / 2);
  });

  it("a note goes on saying what was true until it's torn off or times out", () => {
    const e = new Engine(3, careful[1].carry());
    e.cache = true;
    e.on.notes = true;
    const ask = () => {
      const slip = { id: 9000 + e.stats.spawned++, kind: "ask" as Kind, who: { name: "T", face: "d1" }, born: e.t, due: e.t + 99, tried: [], topic: "cosy" as const };
      e.inbox.push(slip);
      return slip.id;
    };
    e.send(ask(), "model");
    for (let i = 0; i < 60; i++) e.step(0.05);
    expect(e.notes.some((n) => n.type === "answer" && n.value === "Nonna's")).toBe(true);
    e.truth.cosy = "Luna";
    e.send(ask(), "notes");
    expect(e.stats.stale).toBe(1);
    e.setTtl(true);
    for (let i = 0; i < 20 * 9; i++) e.step(0.05);
    expect(e.notes.some((n) => n.type === "answer" && n.topic === "cosy" && n.value === "Nonna's")).toBe(false);
  });

  it("losing every note loses nothing, if bookings are in the book", () => {
    expect(careful[2].stats.lost).toBe(0);
    expect(lazy[2].stats.lost).toBeGreaterThan(10);
  });
});

describe("night 4: launch", () => {
  it("the careful robot holds at launch traffic", () => {
    const e = careful[3];
    const t = tally(e);
    expect(e.servers).toBeGreaterThan(1);
    expect(e.stats.outage).toBe(false);
    expect(e.stats.ok / (e.stats.ok + e.stats.angry)).toBeGreaterThan(0.9);
    expect(t.stars).toBe(3);
  });

  it("every shortcut from earlier nights comes back at once", () => {
    const s = lazy[3].stats;
    expect(s.ok / (s.ok + s.angry)).toBeLessThan(0.7);
    expect(s.lost).toBeGreaterThan(5);
    expect(s.strangers).toBeGreaterThan(100);
    expect(s.outage).toBe(true);
    expect(tally(lazy[3]).stars).toBe(1);
  });

  it("more desks don't help while every question goes to the one book", () => {
    const run = (cached: boolean) => {
      const carry = careful[2].carry();
      carry.rules.free = cached ? ["notes", "ledger"] : ["ledger"];
      const e = new Engine(4, carry);
      for (let i = 0; i < 3; i++) e.addServer();
      for (let i = 0; i < 20 * 300 && !e.done; i++) e.step(0.05);
      return e.stats.ok / (e.stats.ok + e.stats.angry);
    };
    expect(run(false)).toBeLessThan(0.7);
    expect(run(true)).toBeGreaterThan(0.88);
  });

  it("one desk unplugged is an outage; one of several isn't", () => {
    const carry = careful[2].carry();
    carry.rules.free = ["notes", "ledger"];
    const alone = new Engine(4, carry);
    for (let i = 0; i < 20 * 300 && !alone.done; i++) alone.step(0.05);
    expect(alone.stats.outage).toBe(true);
    expect(careful[3].stats.outage).toBe(false);
  });
});

describe("the robot", () => {
  const book = (e: Engine) => {
    const slip = e.inbox.find((s) => s.kind === "book");
    return slip?.id ?? -1;
  };
  const until = (e: Engine, test: () => boolean) => {
    for (let i = 0; i < 2000 && !test(); i++) e.step(0.05);
  };

  it("does what it saw three times", () => {
    const e = new Engine(1);
    for (let i = 0; i < 3; i++) {
      until(e, () => book(e) > 0);
      e.send(book(e), "notes");
    }
    expect(e.rules.book).toEqual(["notes"]);
  });

  it("changes its mind after three running done another way, and not before", () => {
    const e = new Engine(1);
    for (let i = 0; i < 3; i++) {
      until(e, () => book(e) > 0);
      e.send(book(e), "notes");
    }
    until(e, () => e.phase === "retrain");
    for (let i = 0; i < 2; i++) {
      e.hold("book");
      until(e, () => book(e) > 0);
      e.send(book(e), "ledger");
      until(e, () => e.queues.ledger.length === 0);
    }
    expect(e.rules.book).toEqual(["notes"]);
    expect(e.streak.book).toBe(2);
    e.hold("book");
    until(e, () => book(e) > 0);
    e.send(book(e), "ledger");
    until(e, () => e.queues.ledger.length === 0);
    expect(e.rules.book).toEqual(["ledger"]);
  });

  it("leaves a kind alone while it's watching", () => {
    const e = new Engine(2, careful[0].carry());
    until(e, () => !!e.rules.pay || e.inbox.some((s) => s.kind === "book"));
    e.hold("book", 5);
    const id = book(e);
    for (let i = 0; i < 40; i++) e.step(0.05);
    expect(e.inbox.some((s) => s.id === id)).toBe(true);
    for (let i = 0; i < 100; i++) e.step(0.05);
    expect(e.inbox.some((s) => s.id === id)).toBe(false);
  });

  it("can't be sent a slip the thing on the desk has no use for", () => {
    const e = new Engine(2, careful[0].carry());
    until(e, () => e.inbox.some((s) => s.kind === "pay"));
    const pay = e.inbox.find((s) => s.kind === "pay")!;
    expect(e.send(pay.id, "notes")).toBe(false);
    expect(e.inbox).toContain(pay);
  });
});

describe("the words", () => {
  it("every rule the robot can learn has a name and a line", () => {
    for (const kind of Object.keys(ROUTES) as Kind[]) {
      for (const station of ROUTES[kind]) {
        expect(RULE_NAME[`${kind}:${station}`], `${kind}:${station}`).toBeTruthy();
        expect(LINES[`learn_${kind}_${station}` as keyof typeof LINES], `${kind}:${station}`).toBeTruthy();
      }
    }
  });

  it("every line said is short enough to read with a thumb busy", () => {
    const said = new Set<string>();
    const seen = (events: Ev[]) => {
      for (const ev of events) if (ev.t === "bark" || ev.t === "text") said.add(ev.text);
    };
    for (const style of ["careful", "lazy", "learner"] as const) {
      for (let n = 1; n <= 4; n++) {
        const e = new Engine(n, n > 1 ? (style === "lazy" ? lazy : careful)[n - 2].carry() : undefined);
        for (let i = 0; i < 20 * 300 && !e.done; i++) {
          e.step(0.05);
          seen(e.drain());
        }
      }
    }
    expect(said.size).toBeGreaterThan(10);
    for (const line of said) {
      expect(line.length, line).toBeLessThanOrEqual(100);
      expect(line, line).not.toMatch(/\{|\}|undefined/);
    }
  });

  it("each night names what was handled, and the brief is earned line by line", () => {
    expect(TERMS).toHaveLength(4);
    const good = brief(careful[3].rules, careful[3].ttl, careful[3].servers);
    const bad = brief(lazy[3].rules, lazy[3].ttl, lazy[3].servers);
    expect(good.every((l) => l.ok)).toBe(true);
    expect(bad.every((l) => !l.ok)).toBe(true);
  });

  it("playNight gives the same night as playAll", () => {
    expect(playNight(1, "careful").stats).toEqual(careful[0].stats);
  });
});
