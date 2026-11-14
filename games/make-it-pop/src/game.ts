// Make It Pop: the rules, with no screen.
//
// The player is the AI. Dee has a web page for her dog-walking business and
// asks for changes, badly. Each of the five jobs is played twice: first from
// what Dee typed, then from the same request said properly. The difference in
// tries is the lesson, and the five lessons together are how to ask a real AI.

export const COLORS = ["cream", "pink", "sky", "navy", "green", "orange"] as const;
export type Color = (typeof COLORS)[number];
export const SIZES = ["small", "medium", "large", "huge"] as const;
export const LABELS = ["Click here", "Book a walk", "Submit", "Woof"] as const;
export const SPOTS = ["left", "top", "right"] as const;
export type Spot = (typeof SPOTS)[number];
export const FONTS = ["fancy", "plain", "typewriter"] as const;
export type Font = (typeof FONTS)[number];
export const REPAIRS = [
  "Nothing yet",
  "Fix the lettering not loading",
  "Fix the picture not showing",
  "Fix the Book button on phones",
  "Fix the layout on laptops",
  "Fix the colors in dark mode",
  "Rewrite the whole page",
] as const;
export const REWRITE = REPAIRS.length - 1;

/** Everything about Dee's page the AI can change. */
export interface Page {
  heading: number;
  bg: Color;
  button: Color;
  label: number;
  photo: Spot;
  font: Font;
  repair: number;
}
export type Knob = keyof Page;

/** What Dee calls each thing. */
export const NAMES: Record<Knob, string> = {
  heading: "name",
  bg: "background",
  button: "button color",
  label: "button words",
  photo: "dog picture",
  font: "lettering",
  repair: "repair",
};

export const FIRST: Page = { heading: 1, bg: "cream", button: "pink", label: 0, photo: "right", font: "fancy", repair: 0 };

export interface Job {
  id: string;
  /** What Dee typed. */
  vague: string;
  /** The same request, said properly. One entry per line. */
  clear: string[];
  target: Partial<Page>;
  /** The knobs the AI is offered for this job. */
  knobs: Knob[];
  /** Tries before Dee gives up and says it again. */
  patience: number;
  rule: string;
  why: string;
}

const DESIGN: Knob[] = ["heading", "bg", "button", "label", "photo", "font"];

export const JOBS: Job[] = [
  {
    id: "pop",
    vague: "Make it pop.",
    clear: ["Make the name at the top as big as it goes.", "Don't change anything else."],
    target: { heading: 3 },
    knobs: DESIGN,
    patience: 5,
    rule: "Say which thing.",
    why: "\"It\" was the name at the top. Only Dee knew that.",
  },
  {
    id: "nicer",
    vague: "The button needs a nicer color.",
    clear: ["Make the button green."],
    target: { button: "green" },
    knobs: DESIGN,
    patience: 5,
    rule: "Say exactly what you want.",
    why: "\"Nicer\" is five wrong colors and one right one. A color, a number or an example is one.",
  },
  {
    id: "pro",
    vague: "Make it look more professional.",
    clear: ["Change the lettering to the plain one.", "Keep the colors, the sizes and where everything is."],
    target: { font: "plain" },
    knobs: DESIGN,
    patience: 5,
    rule: "Say what to leave alone.",
    why: "Asked to improve something, an AI will happily improve the parts you liked.",
  },
  {
    id: "ramble",
    vague: "OK so my sister saw it and she says the dog should be on the left, which, fine, and honestly the button should say Book a walk because Click here is what scams say, did I tell you about the scam, anyway the background, I'm thinking sky blue like the van, oh and the name one size smaller, it's shouting.",
    clear: ["1. Move the dog picture to the left.", "2. Make the button say Book a walk.", "3. Make the background sky blue.", "4. Make the name one size smaller."],
    target: { photo: "left", label: 1, bg: "sky", heading: 2 },
    knobs: DESIGN,
    patience: 4,
    rule: "One ask per line.",
    why: "Four asks in one breath is how one gets dropped. In a list, each can be ticked off.",
  },
  {
    id: "broken",
    vague: "It's broken. Fix it.",
    clear: ["On my phone, I tap Book a walk and nothing happens.", "On my laptop it works.", "I expected the booking form to open.", "The phone shows: \"openForm is not defined\"."],
    target: { repair: 3 },
    knobs: ["repair"],
    patience: 4,
    rule: "Say what you did, what you expected and what happened. Paste the error.",
    why: "\"Broken\" could be six things. The error message names one.",
  },
];

/** The page each job starts from: the one before it, done right. */
export function startOf(job: number): Page {
  let page = { ...FIRST };
  for (let i = 0; i < job; i++) page = { ...page, ...JOBS[i].target, repair: 0 };
  return page;
}

/** The parts of the request not yet done. */
export function missing(job: Job, page: Page): Knob[] {
  return (Object.keys(job.target) as Knob[]).filter((k) => page[k] !== job.target[k]);
}

/** Things changed that nobody asked for. */
export function collateral(job: Job, start: Page, page: Page): Knob[] {
  return (Object.keys(page) as Knob[]).filter((k) => !(k in job.target) && page[k] !== start[k]);
}

export function done(job: Job, start: Page, page: Page): boolean {
  return missing(job, page).length === 0 && collateral(job, start, page).length === 0;
}

const LIKED: Partial<Record<Knob, string>> = {
  heading: "Why is the name a different size? Put it back.",
  bg: "Not the background! I chose that background.",
  button: "I love that button color. Put it back.",
  label: "Who told you to change what the button says?",
  photo: "The dog was fine where he was.",
  font: "What happened to my lettering? Put it back.",
};

const NOT_NICER = ["Not that one.", "Nicer than that.", "No. Nicer.", "That's worse, if anything.", "Still no."];

/** What Dee says to an attempt that isn't right. `n` is which try this was, from 1. */
export function react(job: Job, start: Page, page: Page, n: number): string {
  const extra = collateral(job, start, page);
  const left = missing(job, page);
  const untouched = (Object.keys(page) as Knob[]).every((k) => page[k] === start[k]);
  if (untouched) return "You didn't change anything. I can tell.";

  if (job.id === "ramble") {
    const asked = Object.keys(job.target).length;
    const got = asked - left.length;
    if (extra.length) return `${LIKED[extra[0]]} And that's ${got} of the things I asked for.`;
    return got === 0 ? "None of that is what I said." : `That's ${got} of them. I said ${asked} things.`;
  }
  if (job.id === "broken") {
    return page.repair === REWRITE ? "Now it's all different and it's still broken." : "Still broken.";
  }
  if (extra.length) return LIKED[extra[0]] ?? `Why is the ${NAMES[extra[0]]} different?`;
  if (job.id === "pop") {
    return page.heading > start.heading ? "Ooh. Closer. More." : "That's the opposite of pop.";
  }
  if (job.id === "pro" && page.font === "typewriter") return "That's a ransom note. More professional, I said.";
  return NOT_NICER[(n - 1) % NOT_NICER.length];
}

/** How to ask, in the order the game taught it. */
export const TEMPLATE = [
  "Change: (which thing)",
  "Make it: (exactly what, with a number, a color or an example)",
  "Leave alone: (everything you like as it is)",
  "One ask per line.",
  "If it's broken: what I did, what I expected, what happened, and the error message.",
].join("\n");
