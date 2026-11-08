// Every line the Pilot speaks aloud, shared by the game (which plays them)
// and tools/voice.ts (which records them). A line is a cast member and the
// words; its file is named from both, so changing the words records it again.

import { P } from "./model";

export type Line = { who: string; say: string };

// FNV-1a, so the game and the tool name a line's file the same way.
function hash(s: string): string {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16).padStart(8, "0");
}

export function voiceKey(l: Line): string {
  return `${l.who}-${hash(l.say)}`;
}

// Every {who, say} in the Pilot's data, once each: the script's lines and
// the reactions a choice plays (code notes, plan claims, sticky notes).
export function allLines(): Line[] {
  const out = new Map<string, Line>();
  const walk = (x: unknown): void => {
    if (Array.isArray(x)) x.forEach(walk);
    else if (x && typeof x === "object") {
      const o = x as Record<string, unknown>;
      if (typeof o.who === "string" && typeof o.say === "string") out.set(voiceKey(o as Line), o as Line);
      else Object.values(o).forEach(walk);
    }
  };
  walk(P);
  return [...out.values()];
}
