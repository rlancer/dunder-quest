// A bot plays each sketch through its real screen.

import { beforeEach, expect, test } from "vitest";
import { mountApp } from "./app";

let root: HTMLElement;
const $ = <T extends HTMLElement>(sel: string) => root.querySelector<T>(sel)!;
const tick = () => new Promise<void>((r) => setTimeout(r, 0));
async function press(sel: string): Promise<void> {
  const el = $(sel);
  expect(el, sel).toBeTruthy();
  el.click();
  await tick();
  await tick();
}
async function open(way: string): Promise<void> {
  location.hash = way;
  window.dispatchEvent(new Event("hashchange"));
  await tick();
}

beforeEach(async () => {
  localStorage.clear();
  document.body.innerHTML = '<div id="root"></div>';
  root = document.getElementById("root")!;
  location.hash = "";
  mountApp(root, { instant: true });
  await tick();
});

test("the menu offers all three", () => {
  expect([...root.querySelectorAll(".card")].map((c) => c.getAttribute("href"))).toEqual(["#tap", "#gaps", "#trip"]);
});

test("One Tap: the same tap, both ways, in all three scenes", async () => {
  await open("tap");
  await press('[data-act="book"]');
  await press('[data-act="book"]');
  expect($('[data-node="server"]').textContent).toContain("remembering 2");
  await press('[data-act="restart"]');
  expect($(".says").textContent).toContain("forgot 2 bookings");
  expect($(".terms").textContent).toContain("database");
  await press('[data-v="database"]');
  await press('[data-act="book"]');
  await press('[data-act="restart"]');
  expect($(".says").textContent).toContain("still in the database");

  await press('[data-act="next"]');
  const range = $<HTMLInputElement>('input[type="range"]');
  range.value = "0";
  range.dispatchEvent(new Event("input"));
  expect($('[data-node="phone"]').textContent).toContain("says $0");
  await press('[data-act="send"]');
  expect($(".says").textContent).toContain("believed it");
  expect($(".says").textContent).toContain("$20 short");
  await press('[data-v="server"]');
  await press('[data-act="send"]');
  expect($(".says").textContent).toContain("ignored that");

  await press('[data-act="next"]');
  await press('[data-act="snoop"]');
  expect($('[data-node="model"]').textContent).toContain("bill $25");
  await press('[data-v="server"]');
  await press('[data-act="snoop"]');
  expect($(".says").textContent).toContain("still works");
  await press('[data-act="rotate"]');
  await press('[data-act="snoop"]');
  expect($(".says").textContent).toContain("Nothing to take");
  expect($('[data-node="model"]').textContent).toContain("bill $50");
});

test("The Gaps: three gaps, closed by typing one and being told two", async () => {
  await open("gaps");
  await press('[data-act="run"]');
  expect(root.querySelectorAll(".out.bad")).toHaveLength(3);

  const box = $<HTMLTextAreaElement>("textarea");
  box.value += " Save the bookings in a database.";
  box.dispatchEvent(new Event("input"));
  await press('[data-act="run"]');
  expect(root.querySelectorAll(".out.bad")).toHaveLength(2);
  expect($('[data-topic="store"]').className).toContain("ok");

  await press('[data-say="pricer"]');
  await press('[data-act="run"]');
  await press('[data-say="key"]');
  await press('[data-act="run"]');
  expect(root.querySelectorAll(".out.ok")).toHaveLength(3);
  expect($(".win").textContent).toContain("4 takes");
  expect($(".steps").textContent).toBe("Take 4");
});

test("Field Trip: reporting what you saw explains it, and is remembered", async () => {
  await open("trip");
  expect(root.querySelectorAll(".errand")).toHaveLength(3);
  expect(root.querySelector(".means")).toBeNull();
  await press('[data-errand="list"] .saw button');
  expect($('[data-errand="list"] .means').textContent).toContain("memory");
  await press('[data-errand="ticket"] .saw button');
  await press('[data-errand="key"] .saw button:nth-child(2)');
  expect($(".win")).toBeTruthy();
  expect($(".steps").textContent).toBe("3 of 3");

  await open("");
  await open("trip");
  expect(root.querySelectorAll(".errand.done")).toHaveLength(3);
});
