// The Pilot's lesson, proved in its data: each board lets through exactly the
// options that fit Thursday (the web app or the installable web app; renting
// the backend), the sort's right answers are the real ones, Thursday clears
// nine in ten on the web and falls short on native apps, the tech stack hides
// exactly one NEXT_PUBLIC_ key, and the marks follow the picks.

import { describe, expect, test } from "vitest";
import { P, fill, hoursLeft, marks, passes, platform, thursday, type Option, type Req } from "./model";

const budget = P.budget.time;
const fits = P.platforms.filter((p) => passes(p, P.pick.reqs as Req[], budget)).map((p) => p.id);

describe("Decision 1: where it runs", () => {
  test("every platform answers every requirement", () => {
    for (const p of P.platforms) for (const q of P.pick.reqs) expect(p.r, `${p.id} on ${q.id}`).toHaveProperty(q.id);
  });
  test("only the web app and the installable web app fit Thursday", () => {
    expect(fits).toEqual(["web", "pwa"]);
  });
});

describe("Decision 3: build or rent", () => {
  for (const plat of ["web", "pwa"]) {
    test(`after ${plat}, only renting fits the hours left`, () => {
      const left = hoursLeft(plat);
      const ok = P.backend.options.filter((b) => passes(b as Option, P.backend.reqs as Req[], left)).map((b) => b.id);
      expect(ok).toEqual(["baas"]);
      for (const b of P.backend.options) for (const q of P.backend.reqs) expect(b.r).toHaveProperty(q.id);
    });
  }
  test("{left} is filled in", () => {
    expect(fill(P.backend.reqs[0].t, 3)).toBe("Fits the 3 hours left");
  });
});

describe("Decision 2: the sort", () => {
  const want: Record<string, string> = { ui: "front", state: "front", key: "back", fee: "back", who: "back", all: "db", menu: "db" };
  test("each piece belongs where it really lives, and says why for every zone", () => {
    expect(P.sort.pieces.map((p) => p.id).sort()).toEqual(Object.keys(want).sort());
    for (const p of P.sort.pieces) {
      expect(p.z, p.id).toBe(want[p.id]);
      for (const z of P.sort.zones) expect((p.why as Record<string, string>)[z.id], `${p.id} in ${z.id}`).toBeTruthy();
    }
  });
});

describe("Decision 4: the plan", () => {
  test("exactly one line sends the key to the browser, and its fix doesn't", () => {
    const bad = P.plan.lines.filter((l) => "bad" in l && l.bad);
    expect(bad).toHaveLength(1);
    expect(String(bad[0].c)).toContain("NEXT_PUBLIC_");
    expect("fixed" in bad[0] && bad[0].fixed).not.toContain("NEXT_PUBLIC_");
  });
});

describe("Thursday", () => {
  for (const build of ["web", "pwa", "native", "cross"]) {
    test(`${build} ${fits.includes(build) ? "makes" : "misses"} nine in ten`, () => {
      const t = thursday(build);
      expect(t.n).toBe(200);
      expect(t.share >= P.goal_share).toBe(fits.includes(build));
    });
  }
  test("the 4:40 iPhone bug hits someone on the web", () => {
    expect(thursday("web").wrong).toBeGreaterThan(0);
  });
  test("a passing pick and renting fit the hours, and have a record row", () => {
    for (const plat of fits) {
      expect(P.postmortem.platform_rows).toHaveProperty(plat);
      expect(platform(plat)!.h + P.backend.options[1].h).toBeLessThanOrEqual(budget);
    }
    const rows = [...P.postmortem.rows, ...Object.values(P.postmortem.platform_rows)];
    for (const r of rows) expect(r).toHaveLength(P.postmortem.heads.length);
  });
});

describe("The marks", () => {
  test.each([
    ["web", false, { live: true, lean: true, ulrich: true }],
    ["pwa", false, { live: true, lean: false, ulrich: true }],
    ["web", true, { live: true, lean: true, ulrich: false }],
  ] as const)("%s, native tried %s", (build, tried, want) => {
    expect(marks(build, tried)).toEqual(want);
  });
});
