// The Pilot as a show: its scenes are lists of beats in ../data/pilot.json's
// `show`, and this file says what each beat does to the stage. Pilot.tsx
// plays them; Stage.tsx draws the result.
//
// A beat is one of: cut to a set (with the cast in place), someone walking,
// a line, an envelope or key changing hands, a title card, a lesson stamp,
// the whiteboard or the TV turning on, a choice the player makes, or a
// widget (Thursday, Gerard's record). Walks, props, signs, the board and the
// screen happen at once; lines, cards, stamps, choices, widgets and waits
// hold the show until they're done.

import { P } from "./model";

export type Opt = { id: string; label: string; ok?: boolean };
export type Beat = {
  set?: string;
  place?: string;
  cast?: Record<string, number>;
  walk?: string;
  x?: number;
  // Where a walker comes on from ("left", "right"), or where a choice's
  // options come from (ChoiceFrom).
  from?: string;
  who?: string;
  say?: string;
  term?: string;
  mark?: string;
  sign?: Record<string, string | null>;
  prop?: Record<string, string | null>;
  fix?: boolean;
  give?: string;
  to?: string;
  card?: string;
  sub?: string;
  auto?: number;
  stamp?: keyof typeof P.stamps;
  board?: "platforms" | "backend" | null;
  screen?: "code" | "plan" | null;
  choice?: string;
  prompt?: string;
  options?: Opt[];
  piece?: string;
  then?: Record<string, Beat[]>;
  widget?: "thursday" | "record";
  wait?: number;
};
export type ChoiceFrom = "platforms" | "backend" | "code" | "plan" | "zones";

export type Actor = { x: number; enter?: number; face?: 1 | -1 };
export type StageState = {
  set: string;
  place: string;
  actors: Record<string, Actor>;
  signs: Record<string, string>;
  props: Record<string, string>;
  board: "platforms" | "backend" | null;
  screen: "code" | "plan" | null;
  marked: string[];
  fixed: boolean;
  // Bumped on each cut, so the stage remounts its sprites in place instead
  // of walking them across.
  cut: number;
};

export const SCENES = P.show as unknown as { id: string; decision?: number; beats: Beat[] }[];

export const EMPTY: StageState = { set: "movein", place: "", actors: {}, signs: {}, props: {}, board: null, screen: null, marked: [], fixed: false, cut: 0 };

const OFF_LEFT = -15;
const OFF_RIGHT = 115;
// How far apart two people stand to hand something over.
const ARM = 9;

// A beat that holds the show until it's done.
export function holds(b: Beat): boolean {
  return !!(b.say !== undefined || b.card || b.stamp || b.choice || b.widget || b.wait);
}

function face(x: number): 1 | -1 {
  return x < 50 ? 1 : -1;
}

function merge(into: Record<string, string>, from: Record<string, string | null> | undefined): Record<string, string> {
  if (!from) return into;
  const out = { ...into };
  for (const [k, v] of Object.entries(from)) {
    if (v === null) delete out[k];
    else out[k] = v;
  }
  return out;
}

// What a beat does to the stage, at the moment it starts.
export function apply(s: StageState, b: Beat): StageState {
  let n = s;
  if (b.set) {
    const actors: Record<string, Actor> = {};
    for (const [who, x] of Object.entries(b.cast ?? {})) actors[who] = { x, face: face(x) };
    n = { ...n, set: b.set, place: b.place ?? (P.sets as Record<string, string>)[b.set] ?? "", actors, signs: {}, props: {}, cut: n.cut + 1 };
  }
  if (b.walk && b.x !== undefined) {
    const cur = n.actors[b.walk];
    const on = cur && cur.x > OFF_LEFT && cur.x < OFF_RIGHT;
    const enter = on ? undefined : b.from === "left" ? OFF_LEFT : b.from === "right" ? OFF_RIGHT : b.x < 50 ? OFF_LEFT : OFF_RIGHT;
    const start = on ? cur.x : enter!;
    n = { ...n, actors: { ...n.actors, [b.walk]: { x: b.x, enter, face: b.x === start ? (cur?.face ?? face(b.x)) : b.x > start ? 1 : -1 } } };
  }
  if (b.sign) n = { ...n, signs: merge(n.signs, b.sign) };
  if (b.prop) n = { ...n, props: merge(n.props, b.prop) };
  // Marks stay when the board goes off for a flash-forward; each option's
  // id is its own, so the two boards never share one.
  if (b.board !== undefined) n = { ...n, board: b.board };
  if (b.screen !== undefined) n = { ...n, screen: b.screen };
  if (b.mark && !n.marked.includes(b.mark)) n = { ...n, marked: [...n.marked, b.mark] };
  if (b.fix) n = { ...n, fixed: true };
  // A speaker turns to face the others.
  if (b.who && n.actors[b.who]) {
    const me = n.actors[b.who];
    const others = Object.entries(n.actors).filter(([k, a]) => k !== b.who && a.x > 0 && a.x < 100);
    if (others.length) {
      const mid = others.reduce((t, [, a]) => t + a.x, 0) / others.length;
      if (Math.abs(mid - me.x) > 3) n = { ...n, actors: { ...n.actors, [b.who]: { ...me, enter: undefined, face: mid > me.x ? 1 : -1 } } };
    }
  }
  return n;
}

// How long a walk takes, so a handover can wait for it.
export function walkMs(dx: number): number {
  return Math.round(Math.min(2200, 260 + Math.abs(dx) * 22));
}

// A handover becomes beats: the giver walks up, hands it over, walks back.
export function expandGive(s: StageState, b: Beat): Beat[] {
  const giver = s.actors[b.give!];
  const taker = s.actors[b.to!];
  if (!giver || !taker) return [{ prop: { envelope: b.to!, key: s.props.key === b.give ? b.to! : s.props.key ?? null } }];
  const side = taker.x > giver.x ? -1 : 1;
  const near = taker.x + side * ARM;
  const held = Object.keys(s.props).filter((p) => s.props[p] === b.give);
  const pass = Object.fromEntries(held.map((p) => [p, b.to!]));
  return [
    { walk: b.give, x: near },
    { wait: walkMs(near - giver.x) },
    { prop: pass },
    { wait: 250 },
    { walk: b.give, x: giver.x },
    { wait: 200 },
  ];
}
