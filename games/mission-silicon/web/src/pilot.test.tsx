// The bot: watches the Pilot through its real screens, as a player would,
// tapping through lines and cards, making one wrong pick at each kind of
// choice to check it's caught (and comes back), and ends on the marks those
// picks earn.

import { act, cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MotionGlobalConfig } from "motion/react";
import { afterEach, beforeEach, expect, test } from "vitest";
import { P } from "./model";
import Pilot, { optionsFor, type Picks } from "./Pilot";
import { SCENES, type Beat } from "./show";

MotionGlobalConfig.skipAnimations = true;
beforeEach(() => localStorage.clear());
afterEach(cleanup);

const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const starts = (s: string) => new RegExp(`^${esc(s)}`);
const choices = new Map(SCENES.flatMap((s) => s.beats.filter((b) => b.choice).map((b) => [b.prompt!, b] as const)));
// The one wrong pick per kind of choice; everything else is picked right.
const WRONG: Record<string, string> = { handoff: "gilroy", platform: "native", code: "4", "sort:key": "front", backend: "own", plan: "1" };

test("the Pilot plays through, and catches a wrong pick at each kind of choice", { timeout: 60000 }, async () => {
  const u = userEvent.setup();
  render(<Pilot speed={Infinity} />);
  const q = (name: string | RegExp) => screen.queryByRole("button", { name });
  const picks: Picks = { platform: "web", tried: [], backend: "", triedBackend: [], misplaced: 0, fixed: false };
  const made: string[] = [];
  const seen = new Set<string>();

  await u.click(screen.getByRole("button", { name: "Start" }));
  let ended = false;
  for (let step = 0; step < 800 && !ended; step++) {
    await act(async () => {
      await new Promise((r) => setTimeout(r, 0));
    });
    if (screen.queryByText("Play the Pilot again")) {
      ended = true;
      break;
    }
    if (screen.queryByText(/Native apps: not this time/)) seen.add("misses-shown");
    const heading = screen.queryByText("Your call") && screen.getByRole("heading", { level: 2 }).textContent;
    const beat: Beat | undefined = heading ? choices.get(heading) : undefined;
    if (beat) {
      const key = `${beat.choice}${beat.piece ? ":" + beat.piece : ""}`;
      const opts = optionsFor(beat, picks);
      const wrong = WRONG[key] && !seen.has(key) ? opts.find((o) => o.id === WRONG[key]) : undefined;
      if (WRONG[key]) expect(wrong?.ok ?? false, `${key}: ${WRONG[key]} should be wrong`).toBe(false);
      const opt = wrong ?? opts.find((o) => o.ok)!;
      seen.add(key);
      made.push(`${key}=${opt.id}`);
      if (beat.from === "platforms" || beat.from === "backend") await u.click(screen.getByRole("button", { name: opt.label }));
      else await u.click(screen.getByRole("button", { name: starts(opt.label.trim()) }));
      if (beat.from === "platforms" && opt.ok) picks.platform = opt.id;
      if (wrong && beat.from === "platforms") {
        // The flash-forward, then the board again, with why it missed.
        await screen.findByText("FLASH-FORWARD");
      }
      continue;
    }
    const back = q(/Back to the house/);
    if (back) {
      if ((back as HTMLButtonElement).disabled) continue;
      if (!seen.has("native-thursday")) {
        seen.add("native-thursday");
        await u.click(q(/If native apps/)!);
        await screen.findByText(/^Native apps: \d+% found a place/);
      }
      await u.click(back);
      continue;
    }
    const go = q("Next line") ?? q("Go on") ?? q(/Show me/) ?? q(/^Go on/);
    if (go) await u.click(go);
  }
  expect(ended, `stuck after ${made.join(", ")}`).toBe(true);
  expect(seen.has("misses-shown")).toBe(true);
  // Every choice in the script came up, and each wrong pick was taken.
  for (const k of Object.keys(WRONG)) expect(made, k).toContain(`${k}=${WRONG[k]}`);
  expect(made.filter((m) => m.startsWith("sort:"))).toHaveLength(P.sort.pieces.length + 1);
  expect(localStorage.getItem("ms-pilot")).toBeNull();
});

test("the record's marks follow the picks", { timeout: 60000 }, async () => {
  // Straight to the postmortem with web, native tried: live and lean, not Ulrich's.
  const scene = SCENES.findIndex((s) => s.id === "postmortem");
  localStorage.setItem("ms-pilot", JSON.stringify({ scene, picks: { platform: "web", tried: ["native", "web"], backend: "baas", triedBackend: ["baas"], misplaced: 0, fixed: true } }));
  const u = userEvent.setup();
  render(<Pilot speed={Infinity} />);
  await u.click(screen.getByRole("button", { name: "Continue" }));
  await u.click(await screen.findByRole("button", { name: "Next line" }));
  await screen.findByText(new RegExp(esc(P.postmortem.marks.live[0])));
  await screen.findByText(new RegExp(esc(P.postmortem.marks.lean[0])));
  await screen.findByText(new RegExp(esc(P.postmortem.marks.ulrich[1])));
});
