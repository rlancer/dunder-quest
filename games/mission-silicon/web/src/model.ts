// Episode 1, the Pilot's rules, apart from its screens so model.test.ts can
// check them: which options fit Thursday's requirements, the 200 testers and
// what happens to each on a build, the feed beside the meter, and the marks.
// Everything it reads is in ../data/pilot.json.

import pilot from "../../data/pilot.json";

export const P = pilot;

export type Mark = "y" | "p" | "n";
export type Req = { id: string; t: string; must?: boolean; later?: boolean };
export type Option = { id: string; n: string; h: number; r: Record<string, string[]> };
export type Platform = (typeof pilot.platforms)[number];
export type Outcome = "fit" | "near" | "wrong" | "none";
export type Tester = { at: number; ok: boolean };
export type Counts = Record<Outcome, number> & { n: number; share: number };
export type FeedItem = { at: number; kind: string; t: string };

export function platform(id: string): Platform | undefined {
  return pilot.platforms.find((p) => p.id === id);
}

// An option fits when every requirement Thursday must have is a yes, and it
// fits the hours. "partly" is fine only for what isn't a must.
export function passes(option: Option | undefined, reqs: Req[], hours: number): boolean {
  if (!option || option.h > hours) return false;
  return reqs.every((q) => {
    if (q.later) return true;
    const r = option.r[q.id]?.[0] ?? "n";
    return r !== "n" && !(q.must && r !== "y");
  });
}

// Hours left for the backend once the platform is built.
export function hoursLeft(platformId: string): number {
  return pilot.budget.time - (platform(platformId)?.h ?? 0);
}

// mulberry32, as the storyboard has it.
function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// The 200 testers: when each arrives (minutes after 4pm) and whether the
// restaurant list has a place that fits them, seeded so every play and every
// test sees the same Thursday.
let _testers: Record<string, Tester[]> | null = null;
export function testers(): Record<string, Tester[]> {
  if (_testers) return _testers;
  const t = pilot.thursday;
  const rand = rng(t.seed);
  const out: Record<string, Tester[]> = {};
  for (const dev of t.devices) {
    const list: Tester[] = [];
    for (let i = 0; i < dev.count; i++) {
      const at = Math.floor(rand() * t.minutes);
      const ok = rand() < t.ok_share;
      list.push({ at, ok });
    }
    list.sort((a, b) => a.at - b.at);
    out[dev.id] = list;
  }
  return (_testers = out);
}

// One tester's evening on a build: "none" if their device can't open it,
// "wrong" if the iPhone bug got them before the fix landed, else "fit" or
// "near" (a near miss: nothing on the list quite fit).
export function outcome(build: string, dev: string, who: Tester): Outcome {
  const t = pilot.thursday;
  const p = platform(build);
  if (dev === "laptop" && !p?.laptops) return "none";
  const fix = p?.fix ?? 0;
  const fixAt = fix > 0 ? t.bug + fix : Infinity;
  if (dev === "iphone" && who.at >= t.bug && who.at < fixAt) return "wrong";
  return who.ok ? "fit" : "near";
}

// Thursday on a build, up to a minute (the whole test by default).
export function thursday(build: string, upto: number = pilot.thursday.minutes): Counts {
  const c = { fit: 0, near: 0, wrong: 0, none: 0, n: 0, share: 0 };
  const all = testers();
  for (const dev of pilot.thursday.devices) {
    for (const who of all[dev.id]) {
      if (who.at < upto) {
        c[outcome(build, dev.id, who)]++;
        c.n++;
      }
    }
  }
  c.share = c.n > 0 ? c.fit / c.n : 0;
  return c;
}

// The feed beside the meter, up to a minute.
export function feed(build: string, m: number): FeedItem[] {
  const f = pilot.thursday.feed;
  const p = platform(build);
  const out: FeedItem[] = [];
  if (!p?.laptops) out.push(f.no_laptops);
  if (m >= f.bug.at) out.push(f.bug);
  if ((p?.fix ?? 0) > 0 && m >= f.fixed.at) out.push(f.fixed);
  if ((p?.fix ?? 0) === 0 && m >= f.review.at) out.push(f.review);
  return out;
}

// The marks. Live: nine in ten found a place. Lean: only what Thursday
// needed (the plain web app; reminders aren't Thursday's). Ulrich: never
// picked native apps for show.
export function marks(build: string, triedNative: boolean) {
  const live = thursday(build).share >= pilot.goal_share;
  return { live, lean: live && build === pilot.lean_platform, ulrich: live && !triedNative };
}

// "{left}" in the backend's words, filled in with the hours left.
export function fill(s: string, left: number): string {
  return s.replaceAll("{left}", String(left));
}

export function clock(m: number): string {
  const [h0, m0] = pilot.thursday.clock;
  const total = h0 * 60 + m0 + Math.floor(m);
  const h = Math.floor(total / 60) % 12 || 12;
  return `${h}:${String(total % 60).padStart(2, "0")}`;
}
