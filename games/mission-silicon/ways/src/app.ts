// Three Ways In: three sketches of how Mission Silicon could teach the same
// three things. The address after # picks one; nothing after it is the menu.

import { art, h } from "./dom";
import { mountGaps } from "./gaps";
import { mountTap } from "./tap";
import { mountTrip } from "./trip";

export const WAYS = [
  { id: "tap", name: "One Tap", verb: "Watch it", pic: "phone", mins: "2 min",
    pitch: "One picture of the app. Flip a switch, send the same tap through, and see what changes." },
  { id: "gaps", name: "The Gaps", verb: "Say it", pic: "robot", mins: "3 min",
    pitch: "Write the brief in your own words. The AI builds exactly that and guesses the rest. Thursday night finds the guesses." },
  { id: "trip", name: "Field Trip", verb: "Do it for real", pic: "key", mins: "10 min, with a real AI",
    pitch: "Three errands to run with the AI you already use. Tell the page what you saw and it tells you what it means." },
] as const;

function menu(root: HTMLElement): void {
  root.replaceChildren(
    h("main", { class: "sheet menu" },
      h("p", { class: "kicker" }, "Mission Silicon · sketches"),
      h("h1", { class: "title" }, "Three Ways In"),
      h("p", { class: "lead" }, "The skill in building with AI is knowing what to ask for and what to check. Here are three ways to pick it up. Each one teaches the same three things: where data lives, who decides the price, and where the secret key goes."),
      h("div", { class: "cards" }, ...WAYS.map((w, i) =>
        h("a", { class: "card", href: `#${w.id}`, "data-way": w.id },
          art(w.pic),
          h("span", { class: "card-verb" }, `${i + 1}. ${w.verb}`),
          h("b", {}, w.name),
          h("span", { class: "card-pitch" }, w.pitch),
          h("span", { class: "card-mins" }, w.mins)))),
      h("p", { class: "fine" }, "Sketches, not finished games: no voices, no score, a few minutes each. Try all three and see which one you'd keep playing."),
    ),
  );
}

export function mountApp(root: HTMLElement, opts: { instant?: boolean } = {}): void {
  const show = () => {
    const way = location.hash.slice(1);
    root.className = `way-${way || "menu"}`;
    if (way === "tap") mountTap(root, opts);
    else if (way === "gaps") mountGaps(root);
    else if (way === "trip") mountTrip(root);
    else menu(root);
    window.scrollTo?.(0, 0);
  };
  window.addEventListener("hashchange", show);
  show();
}
