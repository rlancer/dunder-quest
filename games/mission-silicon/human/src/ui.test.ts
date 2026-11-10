// A bot plays through the real screen: it taps slips and the things on the
// desk, the way a thumb would, with the clock run by hand.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { Game } from "./ui";

let root: HTMLElement;

vi.setConfig({ testTimeout: 60_000 });

beforeEach(() => {
  localStorage.clear();
  document.body.replaceChildren();
  root = document.createElement("div");
  document.body.append(root);
});

const $ = <T extends HTMLElement = HTMLElement>(sel: string) => root.querySelector<T>(sel);
const $$ = (sel: string) => [...root.querySelectorAll<HTMLElement>(sel)];

function button(text: string): HTMLElement {
  const b = $$("button").find((el) => el.textContent?.includes(text));
  if (!b) throw new Error(`no button "${text}" among: ${$$(".overlay button").map((el) => el.textContent).join(", ")}`);
  return b;
}

/** Tap a slip (pick it up), then tap something on the desk (put it down). */
function carry(slip: HTMLElement, station: string) {
  slip.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, clientX: 10, clientY: 10 }));
  window.dispatchEvent(new PointerEvent("pointerup", { bubbles: true, clientX: 10, clientY: 10 }));
  $(`.station.s-${station}`)!.click();
}

/** Run the clock, with a thumb that acts twice a second. */
function play(game: Game, secs: number, thumb: () => void) {
  let hand = 0;
  for (let t = 0; t < secs && !$(".card.end"); t += 0.1) {
    game.frame(0.1);
    hand -= 0.1;
    if (hand <= 0 && !$(".overlay.on")) {
      thumb();
      hand = 0.5;
    }
  }
}

describe("the screen", () => {
  it("opens on one button, and the first slip arrives within seconds of pressing it", () => {
    const game = new Game(root, true);
    expect($(".card.title")).toBeTruthy();
    expect($$(".card.title button")).toHaveLength(1);
    button("Start your shift").click();
    play(game, 3, () => {});
    expect($$(".slip").length).toBeGreaterThan(0);
    expect($(".station.s-notes")!.classList.contains("on")).toBe(true);
    expect($(".station.s-ledger")!.classList.contains("on")).toBe(false);
    expect($(".talk")!.textContent).toContain("Tonight, the backend is you");
  });

  it("night 1 by hand: notes, the unplugging, the book, three stars", () => {
    const game = new Game(root, true);
    button("Start your shift").click();
    let sawChip = false;
    let sawDark = false;
    let held = false;
    play(game, 200, () => {
      const e = game.engine!;
      sawDark ||= !!$(".dark.on");
      const chip = $(".chip.k-book:not(.watching)");
      sawChip ||= !!chip?.textContent?.includes("sticky notes");
      const book = $(".station.s-ledger.on");
      // Once Gerard's book is on the desk: make the robot watch, then show it.
      if (book && e.rules.book?.[0] === "notes" && !e.held("book")) {
        $<HTMLButtonElement>("button.chip.k-book")!.click();
        held = true;
        return;
      }
      const slip = $(".slip:not(.flying):not(.lost)");
      if (slip) carry(slip, book ? "ledger" : "notes");
    });
    expect(sawChip).toBe(true);
    expect(sawDark).toBe(true);
    expect(held).toBe(true);
    expect($(".card.end")).toBeTruthy();
    expect($$(".star.on")).toHaveLength(3);
    expect($(".card.end")!.textContent).toContain("Database");
    expect(JSON.parse(localStorage.getItem("ms-human")!).carry.rules.book).toEqual(["ledger"]);

    // Straight on to night 2, with the robot as it was left and the things named.
    button("Night 2").click();
    play(game, 3, () => {});
    expect(game.engine!.night).toBe(2);
    expect($(".chip.k-book")!.textContent).toContain("the book");
    expect($(".station.s-ledger")!.classList.contains("named")).toBe(true);
    expect($(".station.s-stamp")!.classList.contains("named")).toBe(false);
    expect($$(".station.on")).toHaveLength(4);
  });

  it("night 1 the fast way: every booking lost, one star, and it says why", () => {
    const game = new Game(root, true);
    button("Start your shift").click();
    play(game, 200, () => {
      const slip = $(".slip:not(.flying):not(.lost)");
      if (slip) carry(slip, "notes");
    });
    expect($$(".star.on")).toHaveLength(1);
    expect($(".row.poor")).toBeTruthy();
    expect($(".door-count")!.textContent).toContain("turned away");
  });

  it("a slip dropped on the wrong thing stays in the pile", () => {
    const game = new Game(root, true);
    game.save.carry = { rules: { book: ["ledger"] }, ttl: false };
    game.start(2);
    play(game, 4, () => {});
    const slip = $(".slip.k-pay")!;
    expect(slip).toBeTruthy();
    carry(slip, "notes");
    expect(game.engine!.inbox.some((s) => String(s.id) === slip.dataset.id)).toBe(true);
    // Still in the hand: the next tap on the desk puts it down.
    $(".station.s-adder")!.click();
    expect(game.engine!.inbox.some((s) => String(s.id) === slip.dataset.id)).toBe(false);
  });

  it("the last screen turns the robot's rules into a brief", () => {
    localStorage.setItem("ms-human", JSON.stringify({
      next: 5, stars: [3, 3, 2, 3], servers: 3,
      carry: { rules: { book: ["ledger"], pay: ["adder"], cancel: ["stamp"], ask: ["notes", "model"], free: ["notes", "ledger"] }, ttl: true },
    }));
    new Game(root, true);
    button("Your brief").click();
    expect($(".card.final")!.textContent).toContain("11 of 12 stars");
    expect($$(".brief li.ok")).toHaveLength(6);
    expect($$(".brief li.no")).toHaveLength(1);
    expect($(".brief li.no")!.textContent).toContain("cancels any table for anyone");
  });
});
