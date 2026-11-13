// Make It Pop: the screen. Dee's message, her page, the things the AI can
// change about it, and one button: show her.

import { type Job, type Knob, type Page, COLORS, FONTS, JOBS, LABELS, REPAIRS, SIZES, SPOTS, TEMPLATE, done, react, startOf } from "./game";

type Child = Node | string | null | false | undefined;
function h<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Record<string, string | ((e: Event) => void)> = {}, ...kids: Child[]): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (typeof v === "function") el.addEventListener(k, v);
    else el.setAttribute(k, v);
  }
  el.append(...kids.filter((k): k is Node | string => k !== null && k !== false && k !== undefined));
  return el;
}

const DOG = `<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M12 14l10 6h20l10-6 2 22c0 12-10 20-22 20S10 48 10 36z" fill="#b9814d"/><path d="M12 14l8 18-9 6zM52 14l-8 18 9 6z" fill="#7a4f2a"/><ellipse cx="32" cy="42" rx="11" ry="9" fill="#f3e3c8"/><circle cx="24" cy="30" r="3" fill="#221a12"/><circle cx="40" cy="30" r="3" fill="#221a12"/><ellipse cx="32" cy="38" rx="4" ry="3" fill="#221a12"/><path d="M32 41v5m0 0c-2 3-6 3-7 0m7 0c2 3 6 3 7 0" stroke="#221a12" stroke-width="2" fill="none" stroke-linecap="round"/></svg>`;

type Phase = "title" | "vague" | "between" | "clear" | "lesson" | "end";
interface Score { vague: number; clear: number; gaveUp: boolean }

const KNOB_TITLE: Record<Knob, string> = {
  heading: "Name size",
  bg: "Background",
  button: "Button color",
  label: "Button says",
  photo: "Dog picture",
  font: "Lettering",
  repair: "What to fix",
};

export class Game {
  phase: Phase = "title";
  at = 0;
  page: Page = startOf(0);
  said = "";
  scores: Score[] = [];

  constructor(private root: HTMLElement) {
    this.render();
  }

  get job(): Job { return JOBS[this.at]; }
  get score(): Score { return this.scores[this.at]; }

  begin(at = 0): void {
    this.at = at;
    if (at === 0) this.scores = [];
    this.scores[at] = { vague: 0, clear: 0, gaveUp: false };
    this.page = startOf(at);
    this.said = "";
    this.phase = "vague";
    this.render(true);
  }

  set<K extends Knob>(knob: K, value: Page[K]): void {
    this.page = { ...this.page, [knob]: value };
    this.render();
  }

  show(): void {
    const start = startOf(this.at);
    const right = done(this.job, start, this.page);
    if (this.phase === "vague") {
      this.score.vague += 1;
      if (right) {
        this.said = this.score.vague === 1 ? "Yes! How did you know? Honestly I got lucky with you." : "YES. That. Was that so hard?";
        this.phase = "between";
      } else if (this.score.vague >= this.job.patience) {
        this.score.gaveUp = true;
        this.said = `${react(this.job, start, this.page, this.score.vague)} Forget it. My nephew says I'm asking wrong.`;
        this.phase = "between";
      } else {
        this.said = react(this.job, start, this.page, this.score.vague);
      }
    } else if (this.phase === "clear") {
      this.score.clear += 1;
      if (right) {
        this.said = this.score.clear === 1 ? "Perfect. First time." : "There. That's what I said.";
        this.phase = "lesson";
      } else {
        this.said = `${react(this.job, start, this.page, this.score.clear)} Read it again, it's all there.`;
      }
    }
    this.render(this.phase === "lesson");
  }

  again(): void {
    this.page = startOf(this.at);
    this.said = "";
    this.phase = "clear";
    this.render(true);
  }

  next(): void {
    if (this.at + 1 < JOBS.length) this.begin(this.at + 1);
    else {
      this.phase = "end";
      this.render(true);
    }
  }

  // ------------------------------------------------------------ the screen

  private preview(): HTMLElement {
    const p = this.page;
    const page = h("div", { class: `page bg-${p.bg} font-${p.font} photo-${p.photo}`, "aria-label": "Dee's web page" },
      h("div", { class: "page-text" },
        h("div", { class: `page-name size-${p.heading}` }, "Barkside Dog Walking"),
        h("div", { class: "page-tag" }, "Walks, rain or shine."),
        h("span", { class: `page-btn btn-${p.button}` }, LABELS[p.label])),
      h("div", { class: "page-dog" }));
    page.querySelector(".page-dog")!.innerHTML = DOG;
    return page;
  }

  private knob(knob: Knob): HTMLElement {
    const p = this.page;
    const opts: HTMLElement[] = [];
    const opt = (value: Page[Knob], label: string, extra = "") => {
      const on = p[knob] === value;
      opts.push(h("button", { type: "button", class: `opt ${extra}${on ? " on" : ""}`, "aria-pressed": String(on), "data-knob": knob, "data-v": String(value), click: () => this.set(knob, value) }, label));
    };
    if (knob === "heading") SIZES.forEach((s, i) => opt(i, s));
    else if (knob === "bg" || knob === "button") COLORS.forEach((c) => opt(c, c, `sw sw-${c}`));
    else if (knob === "label") LABELS.forEach((l, i) => opt(i, l));
    else if (knob === "photo") SPOTS.forEach((s) => opt(s, s));
    else if (knob === "font") FONTS.forEach((f) => opt(f, f, `font-${f}`));
    else REPAIRS.forEach((r, i) => i > 0 && opt(i, r));
    return h("div", { class: `knob knob-${knob}` }, h("span", { class: "knob-t" }, KNOB_TITLE[knob]), h("div", { class: "opts", role: "group", "aria-label": KNOB_TITLE[knob] }, ...opts));
  }

  private dee(...kids: Child[]): HTMLElement {
    return h("div", { class: "dee" }, h("span", { class: "dee-face", "aria-hidden": "true" }, "D"), h("div", { class: "bubble" }, h("b", { class: "who" }, "Dee"), ...kids));
  }

  private tally(s: Score): string {
    const v = s.gaveUp ? `${s.vague} tries, and she gave up` : s.vague === 1 ? "1 try (a lucky guess)" : `${s.vague} tries`;
    return `What she typed: ${v}. Said properly: ${s.clear === 1 ? "1 try" : `${s.clear} tries`}.`;
  }

  render(toTop = false): void {
    const kids: Child[] = [];
    const bar = (right: string) => h("header", { class: "bar" }, h("span", { class: "logo" }, "Make It Pop"), h("span", { class: "bar-r" }, right));

    if (this.phase === "title") {
      kids.push(
        h("main", { class: "sheet title" },
          h("h1", {}, "Make It Pop"),
          h("p", { class: "pitch" }, "You're the AI."),
          h("p", {}, "Dee has a web page for her dog-walking business. She'll tell you what to change. You change it, then show her."),
          h("p", {}, "She knows exactly what she wants. She will not be saying it."),
          h("button", { class: "go", type: "button", "data-act": "start", click: () => this.begin() }, "Start"),
          h("p", { class: "fine" }, "Five jobs, about five minutes. Works on a phone.")));
    } else if (this.phase === "end") {
      const v = this.scores.reduce((n, s) => n + s.vague, 0);
      const c = this.scores.reduce((n, s) => n + s.clear, 0);
      const copy = h("button", { class: "go ghost", type: "button", "data-act": "copy" }, "Copy it");
      copy.addEventListener("click", () => {
        void navigator.clipboard?.writeText(TEMPLATE).catch(() => {});
        copy.textContent = "Copied";
      });
      kids.push(bar("Done"),
        h("main", { class: "sheet end" },
          h("h1", {}, "Now swap seats."),
          h("div", { class: "totals" },
            h("div", {}, h("b", {}, String(v)), h("span", {}, "tries from what Dee typed")),
            h("div", {}, h("b", {}, String(c)), h("span", {}, "tries once she said it properly"))),
          h("p", {}, "Same jobs, same AI. The only thing that changed was the request. When you ask an AI to build something, you're Dee, and it's guessing the way you just did."),
          h("ol", { class: "rules" }, ...JOBS.map((j) => h("li", {}, j.rule))),
          h("p", { class: "k" }, "To paste above your next request"),
          h("pre", { class: "template" }, TEMPLATE),
          h("div", { class: "row" }, copy, h("button", { class: "go ghost", type: "button", "data-act": "replay", click: () => this.begin() }, "Play again"))));
    } else {
      const job = this.job;
      const clear = this.phase === "clear" || this.phase === "lesson";
      const playing = this.phase === "vague" || this.phase === "clear";
      const tries = clear ? this.score.clear : this.score.vague;
      kids.push(bar(`Job ${this.at + 1} of ${JOBS.length}`));
      const main = h("main", { class: "sheet" });
      main.append(
        this.dee(
          clear && h("span", { class: "tag" }, "Second attempt"),
          clear ? h("ul", { class: "lines" }, ...job.clear.map((l) => h("li", {}, l))) : h("p", {}, job.vague)),
        this.preview());
      if (this.said) main.append(h("div", { class: "reply", "aria-live": "polite" }, this.dee(h("p", {}, this.said))));
      if (playing) {
        main.append(
          h("div", { class: "knobs" }, ...job.knobs.map((k) => this.knob(k))),
          h("div", { class: "dock" },
            h("span", { class: "tries" }, tries ? `${tries} ${tries === 1 ? "try" : "tries"} so far` : "Change what you think she means"),
            h("button", { class: "go", type: "button", "data-act": "show", click: () => this.show() }, "Show Dee")));
      } else if (this.phase === "between") {
        main.append(h("div", { class: "dock" }, h("span", { class: "tries" }, "Same job, from the start"),
          h("button", { class: "go", type: "button", "data-act": "again", click: () => this.again() }, "Let her say it again")));
      } else {
        main.append(
          h("section", { class: "lesson" },
            h("p", { class: "k" }, `Rule ${this.at + 1}`),
            h("h2", {}, job.rule),
            h("p", {}, job.why),
            h("p", { class: "tally" }, this.tally(this.score))),
          h("div", { class: "dock" }, h("span", { class: "tries" }),
            h("button", { class: "go", type: "button", "data-act": "next", click: () => this.next() }, this.at + 1 < JOBS.length ? "Next job" : "Finish")));
      }
      kids.push(main);
    }
    this.root.replaceChildren(...kids.filter((k): k is Node => !!k));
    if (toTop) window.scrollTo?.(0, 0);
  }
}
