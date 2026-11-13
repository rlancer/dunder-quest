// Sketch 2, The Gaps: say it. The player writes the brief in their own words,
// Aleister Jr. builds exactly that and guesses the rest, and Thursday night
// shows which guesses were wrong. The fix is always a sentence.

import { copyButton, h, terms } from "./dom";
import { type Outcome, night, readBrief } from "./model";

const aleister = new URL("../../assets/portraits/aleister.png", import.meta.url).href;

export const FIRST_BRIEF = "Build an app where diners book a restaurant table and pay a $20 deposit. They can ask an AI model for suggestions.";

const TERMS: Record<Outcome["topic"], string[]> = {
  store: ["memory", "database"],
  pricer: ["client", "server-side check"],
  key: ["API key", "environment variable"],
};

export function mountGaps(root: HTMLElement): void {
  let take = 0;
  let results: Outcome[] | null = null;
  const box = h("textarea", { class: "brief", rows: "6", "aria-label": "Your brief to Aleister Jr.", spellcheck: "false" });
  box.value = FIRST_BRIEF;
  box.addEventListener("input", () => {
    if (results) { results = null; render(); box.focus(); }
  });

  function run(): void {
    take += 1;
    results = night(readBrief(box.value).build);
    render();
  }

  function add(sentence: string): void {
    box.value = `${box.value.trim()} ${sentence}`;
    results = null;
    render();
  }

  function line(): string {
    if (!results) {
      return take === 0
        ? "Tell me what to build. I'll build exactly that, tonight. Anything you don't mention, I'll decide. I'm very decisive."
        : "Updated brief. Love it. Say when.";
    }
    const bad = results.filter((r) => !r.ok).length;
    if (bad === 0) return "Thursday held. Honestly I'd have built it this way from the start, if anyone had asked.";
    if (bad === 3) return "It demoed beautifully. Thursday was a different kind of evening.";
    return `Better. ${bad === 1 ? "One thing" : "Two things"} you still didn't mention, so I decided.`;
  }

  function row(r: Outcome): HTMLElement {
    return h("li", { class: `out ${r.ok ? "ok" : "bad"}`, "data-topic": r.topic },
      h("span", { class: "out-time" }, r.time),
      h("div", { class: "out-body" },
        h("p", { class: "out-what" }, r.what),
        !r.ok && h("p", { class: "out-guess" }, h("img", { src: aleister, alt: "Aleister Jr." }), r.guess),
        !r.ok && h("p", { class: "out-fix" },
          "Close the gap in your own words above",
          h("span", { class: "out-words" }, " (it listens for ", ...r.words.flatMap((w, i) => [i ? " and " : "", h("b", {}, w)]), ")"),
          ", or ",
          h("button", { class: "link", type: "button", "data-say": r.topic, click: () => add(r.sentence) }, "say it for me"),
          "."),
        r.ok && take > 0 && terms(TERMS[r.topic])));
  }

  function render(): void {
    const done = results?.every((r) => r.ok) ?? false;
    root.replaceChildren(
      h("header", { class: "bar" },
        h("a", { href: "#", class: "back" }, "‹ All three"),
        h("span", { class: "bar-t" }, "The Gaps"),
        h("span", { class: "steps" }, take ? `Take ${take}` : "")),
      h("main", { class: "sheet" },
        h("h1", {}, "An AI builds what you say, and guesses the rest."),
        h("div", { class: "speech" }, h("img", { src: aleister, alt: "" }), h("p", {}, h("b", {}, "Aleister Jr. "), line())),
        h("label", { class: "brief-label" }, "Your brief", box),
        !done && h("div", { class: "row" },
          h("button", { class: "btn", type: "button", "data-act": "run", click: run }, take ? "Rebuild and run Thursday again" : "Build it and run Thursday night")),
        results && h("ol", { class: "outs" }, ...results.map(row)),
        done && h("div", { class: "win" },
          h("p", {}, take === 1
            ? "First take. You already knew what to say."
            : `It took ${take} takes, and every fix was a sentence. None of it was code.`),
          h("p", {}, "Those sentences work on a real AI too. Put them at the top of your next request."),
          h("div", { class: "row" }, copyButton(box.value.trim(), "Copy the brief"), h("a", { class: "btn ghost", href: "#" }, "Done"))),
      ),
    );
  }

  render();
}
