// Names show on public leaderboards that children read, so a name with a
// swear word in it is refused. This is a short list on purpose: it catches
// the obvious, and a name that slips through can be hidden by hand
// (`UPDATE players SET hidden = 1 WHERE id = ...`, see deploy/README.md).

import { cleanName } from "../../site/static/social/games.js";

// Base64, so the source does not read as a list of swear words.
const BLOCKED = [
  "ZnVjaw==", "c2hpdA==", "Yml0Y2g=", "Y3VudA==", "ZGljaw==", "cGlzcw==", "Y29jaw==", "d2Fuaw==", "c2x1dA==", "d2hvcmU=", "bmlnZ2Vy", "bmlnZ2E=", "ZmFnZ290", "ZmFn", "c3BpYw==", "Y2hpbms=", "a2lrZQ==", "cmV0YXJk", "cG9ybg==", "c2V4", "cGVuaXM=", "dmFnaW5h", "cmFwZQ==", "YXNzaG9sZQ==", "YmFzdGFyZA==", "d2Fua2Vy", "Ym9vYg==", "aGl0bGVy", "bmF6aQ==", "YXNz", "ZG9uZw==", "Y3Vt", "dHdhdA==", "cHJpY2s=",
].map((w) => atob(w));

// Common look-alike swaps, so "sh1t" reads as "shit".
const LEET: Record<string, string> = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i" };

function flatten(name: string): string {
  return name.toLowerCase().replace(/[013457@$!]/g, (c) => LEET[c]).replace(/[^a-z]/g, "");
}

// Words that contain a blocked one innocently ("class", "Scunthorpe"...): only
// the short, ambiguous entries are matched as whole words.
const WHOLE_WORD = new Set(["ass", "fag", "sex", "cum", "dong", "spic", "rape", "cock", "dick", "boob", "twat"]);

/** The name, cleaned, or "" if it isn't allowed. */
export function allowedName(raw: unknown): string {
  const name = cleanName(raw);
  if (!name) return "";
  const flat = flatten(name);
  const words = name.toLowerCase().split(/[^a-z0-9@$!]+/).map(flatten);
  for (const bad of BLOCKED) {
    if (WHOLE_WORD.has(bad)) {
      if (words.includes(bad)) return "";
    } else if (flat.includes(bad)) {
      return "";
    }
  }
  return name;
}
