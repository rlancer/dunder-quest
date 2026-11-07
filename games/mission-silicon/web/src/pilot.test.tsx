// The bot: plays the Pilot through its real screens, as a player would,
// taking one wrong turn at each decision to check it's caught, and ends on
// the marks those picks earn.

import { act, cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MotionGlobalConfig } from "motion/react";
import { afterEach, beforeEach, expect, test } from "vitest";
import { P } from "./model";
import Pilot from "./Pilot";

MotionGlobalConfig.skipAnimations = true;
beforeEach(() => localStorage.clear());
afterEach(cleanup);

const btn = (name: string | RegExp) => screen.findByRole("button", { name });
const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const starts = (s: string) => new RegExp(`^${esc(s)}`);

test("the Pilot plays through, and catches a wrong turn at each decision", { timeout: 30000 }, async () => {
  const u = userEvent.setup();
  render(<Pilot speed={Infinity} />);
  const click = async (name: string | RegExp) => u.click(await btn(name));
  const nextLines = async (n: number) => {
    for (let k = 0; k < n; k++) await click("Next line");
  };

  await click("Start");
  // The cold open: the scene itself is the button.
  for (const l of P.cold_open.lines) {
    await screen.findByText(l.say);
    await click("Next line");
  }
  await click(/Show me/);

  // The map: all four boxes before going on.
  const follow = await btn(/Follow a search/);
  expect((follow as HTMLButtonElement).disabled).toBe(true);
  for (const k of ["device", "server", "db", "model"] as const) await click(starts(P.map.boxes[k].n));
  await nextLines(1);
  await screen.findByText(P.map.done_say.say);
  await u.click(follow);

  for (let k = 1; k < P.steps.list.length; k++) await click(/Next step/);
  await click(/On to the decisions/);

  // Decision 1.
  await nextLines(P.ways.lines.length - 1);
  for (const p of P.platforms) await click(starts(p.n));
  await click(/Pick one/);
  await click(starts("Native apps"));
  await screen.findByText(`Native apps: not for Thursday`);
  expect((await btn(/Lock it in/) as HTMLButtonElement).disabled).toBe(true);
  await click(starts("Web app"));
  await screen.findByText("Fits Thursday", { selector: "h4" });
  await click(/Lock it in/);

  // Decision 2: the key in the app, then the sort.
  await nextLines(P.noserver.lines.length - 1);
  await click(P.noserver.button);
  await screen.findByText(P.noserver.code[P.noserver.key_line]);
  await nextLines(P.noserver.after.length - 1);
  await screen.findByText(P.noserver.stamp.term);
  await click(/So what goes where/);
  const zone = (id: string) => `Put it on: ${P.sort.zones.find((z) => z.id === id)!.h}`;
  const key = P.sort.pieces.find((p) => p.id === "key")!;
  await click(key.t);
  await click(zone("front"));
  await screen.findByText(key.why.front);
  await click(new RegExp(esc(P.sort.take_back)));
  await click(zone("back"));
  for (const p of P.sort.pieces.filter((x) => x.id !== "key")) {
    await click(p.t);
    await click(zone(p.z));
  }
  await screen.findAllByText(P.sort.done);
  await click(/Next decision/);

  // Decision 3: four hours left after the web app.
  await screen.findByText(/took 4 of Aleister's 8 hours\. 4 left/);
  await click(starts(P.backend.options[0].n));
  expect((await btn(/Lock it in/) as HTMLButtonElement).disabled).toBe(true);
  await click(starts(P.backend.options[1].n));
  await click(/Lock it in/);

  // Decision 4: place every line, catch NEXT_PUBLIC_.
  await nextLines(1);
  for (const l of P.plan.lines) {
    const c = typeof l.c === "string" ? l.c : l.c.web;
    await click(starts(c));
  }
  expect((await btn(new RegExp(P.plan.merge)) as HTMLButtonElement).disabled).toBe(true);
  await click(P.plan.fix_button);
  await screen.findByText(P.plan.fixed.say);
  await click(new RegExp(P.plan.merge));

  // Thursday, at once, then the same evening on native apps.
  await screen.findByText(/found a place that fits/);
  await click(/If native apps/);
  await screen.findByText(/^Native apps: \d+% found a place/);
  await click(/Gerard's postmortem/);

  // The marks: live and lean, but native was tried, so not Ulrich's.
  await screen.findByText(new RegExp(esc(P.postmortem.marks.live[0])));
  await screen.findByText(new RegExp(esc(P.postmortem.marks.lean[0])));
  await screen.findByText(new RegExp(esc(P.postmortem.marks.ulrich[1])));
  await click(/Thursday night/);

  for (const l of P.cliffhanger.lines) {
    await screen.findByText(l.say);
    await click("Next line");
  }
  await screen.findByText(P.cliffhanger.next.title);
  await act(async () => {});
  expect(localStorage.getItem("ms-pilot")).toBeNull();
});
