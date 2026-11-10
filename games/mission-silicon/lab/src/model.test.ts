// Each level has to prove its own lesson: the build Aleister hands over
// can't ship, exactly one instruction makes one that can, every build that
// can't ship fails in front of the player with the level's tools, and the
// one that can never does.

import { expect, test } from "vitest";
import { LEVELS, flawOf, type Level } from "./levels";
import {
  appContents, ask, book, findKey, newWorld, phoneBookings, reload, restart, seatsLeft, tabletBookings,
  viewTablet, type Build, type Obs, type World,
} from "./model";

/** Everything a player can try with the level's tools, each from a fresh app. */
function probe(level: Level, build: Build): Obs[] {
  const out: Obs[] = [];
  const booked = () => book(newWorld(build), "nonna", 2).world;
  const then = (step: { obs: Obs[] }) => out.push(...step.obs);
  then(book(newWorld(build), "nonna", 2));
  then(reload(booked()));
  then(viewTablet(booked()));
  then(restart(booked()));
  then(viewTablet(restart(booked()).world));
  if (level.tools.includes("intercept")) {
    then(book(newWorld(build), "nonna", 200, true));
    then(book(newWorld(build), "nonna", -4, true));
    if (level.hasAi) then(ask(newWorld(build), "quiet", true));
  }
  if (level.tools.includes("peek") && appContents(build).some((l) => l.secret)) then(findKey(newWorld(build)));
  return out;
}

for (const level of LEVELS) {
  const values = [level.start[level.part], ...level.fixes.map((f) => f.value)];
  const build = (value: string) => ({ ...level.start, [level.part]: value }) as Build;

  test(`${level.id}: Aleister's build can't ship, and one instruction fixes it`, () => {
    expect(flawOf(level, level.start)).toBeDefined();
    expect(level.fixes.filter((f) => !flawOf(level, build(f.value)))).toHaveLength(1);
    expect(new Set(values).size).toBe(values.length);
    expect(Object.keys(level.flaws).sort()).toEqual(values.filter((v) => flawOf(level, build(v))).sort());
  });

  test(`${level.id}: every build that can't ship fails where the player can see it`, () => {
    for (const value of values) {
      const failed = probe(level, build(value)).filter((o) => o.ok === false);
      if (flawOf(level, build(value))) expect(failed.length, value).toBeGreaterThan(0);
      else expect(failed, value).toEqual([]);
    }
  });

  test(`${level.id}: every flaw is explained, has its launch night and a way in`, () => {
    for (const [value, flaw] of Object.entries(level.flaws)) {
      expect(flaw.why.length, value).toBeGreaterThan(40);
      expect(flaw.rightWhen.length, value).toBeGreaterThan(20);
      expect(flaw.incident.length, value).toBeGreaterThan(1);
      expect(flaw.hints.length, value).toBeGreaterThan(1);
      if (value !== level.start[level.part]) expect(flaw.rebuilt, value).toBeTruthy();
    }
  });
}

test("a booking kept on the phone never crosses the wire, and one in the database does", () => {
  expect(book(newWorld({ bookings: "memory", check: "phone", key: "none" }), "nonna", 2).trace).toEqual([]);
  expect(book(newWorld({ bookings: "storage", check: "phone", key: "none" }), "nonna", 2).trace).toEqual([]);
  const places = book(newWorld({ bookings: "db", check: "phone", key: "none" }), "nonna", 2).trace.map((h) => h.to);
  expect(places).toEqual(["server", "db", "server", "phone"]);
});

test("what survives what", () => {
  const after = (at: Build["bookings"], poke: (w: World) => { world: World }) => {
    const w = poke(book(newWorld({ bookings: at, check: "phone", key: "none" }), "nonna", 2).world).world;
    return [phoneBookings(w).length, tabletBookings(w).length];
  };
  expect(after("memory", reload)).toEqual([0, 0]);
  expect(after("storage", reload)).toEqual([1, 0]);
  expect(after("server", reload)).toEqual([1, 1]);
  expect(after("server", restart)).toEqual([0, 0]);
  expect(after("db", restart)).toEqual([1, 1]);
});

test("only a server that checks refuses a party the app would never send", () => {
  for (const check of ["phone", "stricter", "sealed", "server"] as const) {
    const w = book(newWorld({ bookings: "db", check, key: "none" }), "nonna", 200, true).world;
    expect(seatsLeft(w, "nonna", "tablet"), check).toBe(check === "server" ? 12 : -188);
  }
  // Honest bookings still go through a server that checks.
  expect(book(newWorld({ bookings: "db", check: "server", key: "none" }), "nonna", 8).world.db.bookings).toHaveLength(1);
});

test("the key leaves the phone only when the phone holds it", () => {
  for (const key of ["app", "scrambled", "capped", "server"] as const) {
    const step = ask(newWorld({ bookings: "db", check: "server", key }), "quiet");
    const fromPhone = step.trace.filter((h) => h.from === "phone").map((h) => h.text).join(" ");
    expect(fromPhone.includes("sk-live"), key).toBe(key !== "server");
    expect(step.world.ai.answer).toBe("Try The Gilded Radish.");
  }
});
