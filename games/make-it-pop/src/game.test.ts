import { expect, test } from "vitest";
import { type Knob, type Page, COLORS, FIRST, JOBS, REPAIRS, REWRITE, collateral, done, missing, react, startOf } from "./game";

test("each job starts where the last one ended, and its target is a real change", () => {
  expect(startOf(0)).toEqual(FIRST);
  JOBS.forEach((job, i) => {
    const start = startOf(i);
    expect(done(job, start, start), job.id).toBe(false);
    expect(missing(job, start).length, job.id).toBe(Object.keys(job.target).length);
    expect(done(job, start, { ...start, ...job.target }), job.id).toBe(true);
    for (const k of Object.keys(job.target) as Knob[]) expect(job.knobs, job.id).toContain(k);
  });
});

test("doing the job and something extra isn't doing the job", () => {
  const job = JOBS[0];
  const start = startOf(0);
  const page: Page = { ...start, ...job.target, bg: "navy" };
  expect(collateral(job, start, page)).toEqual(["bg"]);
  expect(done(job, start, page)).toBe(false);
  expect(react(job, start, page, 1)).toContain("background");
});

test("Dee's replies never give the answer away, but do say hotter or colder", () => {
  const [pop, nicer, pro, ramble, broken] = JOBS;
  const s0 = startOf(0);
  expect(react(pop, s0, s0, 1)).toContain("didn't change anything");
  expect(react(pop, s0, { ...s0, heading: 2 }, 1)).toContain("Closer");
  expect(react(pop, s0, { ...s0, heading: 0 }, 1)).toContain("opposite");

  const s1 = startOf(1);
  for (const c of COLORS) {
    if (c === "green" || c === s1.button) continue;
    expect(react(nicer, s1, { ...s1, button: c }, 1)).not.toContain("green");
  }

  const s2 = startOf(2);
  expect(react(pro, s2, { ...s2, font: "typewriter" }, 1)).toContain("ransom");
  expect(react(pro, s2, { ...s2, button: "navy" }, 1)).toContain("button");

  const s3 = startOf(3);
  expect(react(ramble, s3, { ...s3, photo: "left", label: 1 }, 1)).toBe("That's 2 of them. I said 4 things.");

  const s4 = startOf(4);
  expect(react(broken, s4, { ...s4, repair: 1 }, 1)).toBe("Still broken.");
  expect(react(broken, s4, { ...s4, repair: REWRITE }, 1)).toContain("all different");
  expect(REPAIRS[broken.target.repair!]).toContain("phones");
});

test("the request said properly names every part of the target", () => {
  const words: Record<string, string[]> = {
    pop: ["name", "big", "anything else"],
    nicer: ["button", "green"],
    pro: ["lettering", "plain", "Keep"],
    ramble: ["left", "Book a walk", "sky", "smaller"],
    broken: ["phone", "Book a walk", "expected", "openForm"],
  };
  for (const job of JOBS) for (const w of words[job.id]) expect(job.clear.join(" "), job.id).toContain(w);
  // The ramble holds all four asks too; it's the telling that's the trouble.
  for (const w of ["left", "Book a walk", "sky blue", "smaller"]) expect(JOBS[3].vague).toContain(w);
  expect(JOBS[3].clear).toHaveLength(4);
});

test("guessing a color blind fits inside Dee's patience", () => {
  expect(JOBS[1].patience).toBeGreaterThanOrEqual(COLORS.length - 1);
});
