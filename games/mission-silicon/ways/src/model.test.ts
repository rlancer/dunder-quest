import { expect, test } from "vitest";
import { ASKED, DEPOSIT, GUESSED, ask, book, newWorld, night, readBrief, rebuild, restart, rotate, snoop } from "./model";
import { FIRST_BRIEF } from "./gaps";
import { ERRANDS } from "./trip";

// ------------------------------------------------------------------ One Tap

test("a restart forgets memory and leaves the database alone", () => {
  let w = newWorld(GUESSED);
  for (let i = 0; i < 3; i++) w = book(w).world;
  const r = restart(w);
  expect(r.world.inMemory).toBe(0);
  expect(r.says).toContain("forgot 3 bookings");

  w = newWorld(ASKED);
  for (let i = 0; i < 3; i++) w = book(w).world;
  expect(restart(w).world.inDatabase).toBe(3);
  expect(restart(w).says).toContain("still in the database");
});

test("the phone's word is only believed when the phone sets the price", () => {
  const trusting = book(newWorld(GUESSED), 0);
  expect(trusting.world.till).toBe(0);
  expect(trusting.world.short).toBe(DEPOSIT);
  const checking = book(newWorld(ASKED), 0);
  expect(checking.world.till).toBe(DEPOSIT);
  expect(checking.world.short).toBe(0);
  // An honest phone looks the same either way, which is why nobody notices.
  expect(book(newWorld(GUESSED)).world.till).toBe(book(newWorld(ASKED)).world.till);
});

test("a key in the app is found; moving it doesn't kill the copy; rotating does", () => {
  let w = newWorld(GUESSED);
  expect(ask(w).hops).not.toContain("server");
  w = snoop(w).world;
  expect(w.leaked).toBe(true);
  expect(w.stolen).toBeGreaterThan(0);

  w = rebuild(w, { key: "server" });
  const again = snoop(w);
  expect(again.world.stolen).toBeGreaterThan(w.stolen);
  expect(again.says).toContain("still works");

  w = rotate(again.world).world;
  const after = snoop(w);
  expect(after.world.stolen).toBe(w.stolen);
  expect(after.says).toContain("no key");

  // Rotating while the key is still shipped in the app only buys time.
  let lazy = snoop(newWorld(GUESSED)).world;
  lazy = rotate(lazy).world;
  expect(snoop(lazy).world.leaked).toBe(true);

  expect(ask(newWorld(ASKED)).hops).toContain("server");
  expect(snoop(newWorld(ASKED)).world.stolen).toBe(0);
});

// ----------------------------------------------------------------- The Gaps

test("the brief the player starts with settles nothing, and Thursday fails three ways", () => {
  const r = readBrief(FIRST_BRIEF);
  expect(r.said).toEqual({ store: false, pricer: false, key: false });
  expect(r.build).toEqual(GUESSED);
  expect(night(r.build).filter((o) => !o.ok)).toHaveLength(3);
});

test("each 'say it for me' sentence closes its own gap and no other", () => {
  for (const o of night(GUESSED)) {
    const said = readBrief(`${FIRST_BRIEF} ${o.sentence}`).said;
    for (const t of ["store", "pricer", "key"] as const) expect(said[t], `${o.topic} -> ${t}`).toBe(t === o.topic);
    expect(o.guess).not.toBe("");
  }
  const all = night(GUESSED).map((o) => o.sentence).join(" ");
  expect(readBrief(`${FIRST_BRIEF} ${all}`).build).toEqual(ASKED);
  expect(night(ASKED).every((o) => o.ok && o.guess === "")).toBe(true);
});

test("it understands the ways a person would actually say it", () => {
  const yes: [string, "store" | "pricer" | "key"][] = [
    ["save bookings in a database", "store"],
    ["Use Postgres for the bookings.", "store"],
    ["Bookings go in Supabase", "store"],
    ["The server works out the deposit", "pricer"],
    ["calculate the price on the server", "pricer"],
    ["Never trust the amount the phone sends", "pricer"],
    ["don't trust the client", "pricer"],
    ["The backend checks the total before charging", "pricer"],
    ["Keep the API key on the server", "key"],
    ["The key must never be in the app", "key"],
    ["don't put secrets in the frontend", "key"],
    ["Put the model key in an environment variable", "key"],
    ["keep the key out of the code", "key"],
  ];
  for (const [text, topic] of yes) expect(readBrief(text).said[topic], text).toBe(true);
});

test("it isn't fooled by the wrong thing said confidently", () => {
  const no: [string, "store" | "pricer" | "key"][] = [
    ["Keep bookings in memory, no database needed", "store"],
    ["Don't bother with a database", "store"],
    ["Make it fast", "store"],
    ["The phone works out the deposit", "pricer"],
    ["Build a server and take a $20 deposit", "pricer"],
    ["Put the key in the app", "key"],
    ["Hide the key", "key"],
    ["Don't keep the key on the server, put it in the app", "key"],
  ];
  for (const [text, topic] of no) expect(readBrief(text).said[topic], text).toBe(false);
});

// --------------------------------------------------------------- Field Trip

test("every errand can be run and every answer says something", () => {
  expect(ERRANDS).toHaveLength(3);
  for (const e of ERRANDS) {
    expect(e.prompt.length).toBeGreaterThan(20);
    expect(e.saw.length).toBeGreaterThanOrEqual(2);
    for (const s of e.saw) expect(s.means.length).toBeGreaterThan(40);
    expect(e.terms.length).toBeGreaterThan(0);
  }
});
