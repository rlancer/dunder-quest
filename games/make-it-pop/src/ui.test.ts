// A bot plays the whole game through the real screen: it guesses wrong from
// what Dee typed, then does the job from what she says the second time.

import { beforeEach, expect, test } from "vitest";
import { type Knob, JOBS, startOf } from "./game";
import { Game } from "./ui";

let root: HTMLElement;
let game: Game;
const $ = (sel: string) => root.querySelector<HTMLElement>(sel);
const press = (sel: string) => {
  const el = $(sel);
  expect(el, sel).toBeTruthy();
  el!.click();
};
const turn = (knob: Knob, v: unknown) => press(`[data-knob="${knob}"][data-v="${v}"]`);

beforeEach(() => {
  document.body.innerHTML = '<div id="root"></div>';
  root = document.getElementById("root")!;
  game = new Game(root);
});

test("the title says who you are", () => {
  expect(root.textContent).toContain("You're the AI.");
  press('[data-act="start"]');
  expect($(".bubble")!.textContent).toContain("Make it pop.");
});

test("a bot guesses wrong, hears it said properly, and gets all five", () => {
  press('[data-act="start"]');
  JOBS.forEach((job, i) => {
    expect($(".bar-r")!.textContent).toBe(`Job ${i + 1} of 5`);
    const start = startOf(i);
    // From what she typed: show her nothing, then run out her patience.
    for (let n = 0; n < job.patience; n++) {
      expect($(".tag"), job.id).toBeNull();
      press('[data-act="show"]');
    }
    expect($(".reply")!.textContent).toContain("asking wrong");
    press('[data-act="again"]');
    expect($(".tag")!.textContent).toBe("Second attempt");
    expect(game.page).toEqual(start);
    // Said properly: one try.
    for (const [k, v] of Object.entries(job.target)) turn(k as Knob, v);
    press('[data-act="show"]');
    expect($(".lesson h2")!.textContent).toBe(job.rule);
    expect($(".tally")!.textContent).toContain(`${job.patience} tries, and she gave up`);
    expect($(".tally")!.textContent).toContain("Said properly: 1 try.");
    press('[data-act="next"]');
  });
  const totals = [...root.querySelectorAll(".totals b")].map((b) => b.textContent);
  expect(totals).toEqual([String(JOBS.reduce((n, j) => n + j.patience, 0)), "5"]);
  expect($(".template")!.textContent).toContain("Leave alone");
  expect(root.querySelectorAll(".rules li")).toHaveLength(5);
  press('[data-act="replay"]');
  expect($(".bar-r")!.textContent).toBe("Job 1 of 5");
});

test("a lucky guess is called one, and the page shows what was changed", () => {
  press('[data-act="start"]');
  turn("heading", 3);
  expect($(".page-name")!.className).toContain("size-3");
  press('[data-act="show"]');
  expect($(".reply")!.textContent).toContain("lucky");
  press('[data-act="again"]');
  turn("heading", 3);
  turn("bg", "navy");
  press('[data-act="show"]');
  expect($(".reply")!.textContent).toContain("background");
  expect($(".lesson")).toBeNull();
  turn("bg", "cream");
  press('[data-act="show"]');
  expect($(".tally")!.textContent).toBe("What she typed: 1 try (a lucky guess). Said properly: 2 tries.");
});
