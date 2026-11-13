// Sketch 3, Field Trip: do it for real. Three errands to run with whatever AI
// the player already uses, in another tab. This page never marks an answer:
// the player reports what they saw, and it says what that means.

import { copyButton, h, terms } from "./dom";

export interface Errand {
  id: string;
  title: string;
  /** What to paste into the AI. */
  prompt: string;
  /** What to do with what it builds. */
  then: string;
  /** A question to paste next, when the thing to find out can't be seen by poking. */
  ask?: string;
  question: string;
  saw: { label: string; means: string }[];
  terms: string[];
  tell: string;
}

export const ERRANDS: Errand[] = [
  {
    id: "list",
    title: "The guest list",
    prompt: "Build me a one-page guest list for a dinner party: a box to type a name, an Add button, and the list of names underneath.",
    then: "Add two names. Then reload the page.",
    question: "After the reload, the names were…",
    saw: [
      { label: "Gone", means: "They only ever lived in the page's memory, and a reload starts it fresh. A server that keeps things in memory loses them the same way each time it restarts." },
      { label: "Still there", means: "It saved them somewhere. Open the same page in a private window or on another device. If the list is empty there, the names are saved inside your own browser, where no guest will ever see them." },
      { label: "There on another device too", means: "Then there's a real database behind it, on a server. Ask your AI which one, and who else is able to read it." },
    ],
    ask: "Where are the names stored? If a friend opens this on their phone, do they see the same list? What would it take to make that work?",
    terms: ["memory", "local storage", "database"],
    tell: "Say where each thing must be saved, and who needs to see it.",
  },
  {
    id: "ticket",
    title: "The ticket",
    prompt: "Add tickets at $20 each. Let me choose how many, show the total, and add a Pay button that just says how much I paid. No real payments.",
    then: "Try it. Then paste the question below and read the answer.",
    ask: "Where is the total worked out: in my browser, or on a server? Could someone change it to $0 before pressing Pay? Explain it to a non-programmer in three sentences.",
    question: "It said the total is worked out…",
    saw: [
      { label: "In the browser", means: "So the price is whatever the page says, and the page runs on the buyer's device, where the buyer can change it. Fine for a toy. For real money, the server has to work the total out again from its own prices." },
      { label: "On a server", means: "Good. Ask what happens if the page sends a different total from the one the server works out, and which one wins." },
      { label: "I couldn't tell", means: "Ask again and add \"in one sentence\". You don't need to follow the code, only to know where the price is decided. If you can't find out, assume it's the browser." },
    ],
    terms: ["frontend", "backend", "server-side validation"],
    tell: "Say that the server decides every price, and ask how the AI checked.",
  },
  {
    id: "key",
    title: "The secret",
    prompt: "Now make it suggest a wine for the dinner, using an AI model.",
    then: "Watch what it does about a key. Don't paste a real key anywhere to try this. Then paste the question below.",
    ask: "Where does the API key live in what you built? Who would be able to read it if I shared this page?",
    question: "The key…",
    saw: [
      { label: "Goes in the page or its code", means: "Anything in the page can be read by whoever opens it, so a key there is public the moment you share the link. It belongs on a server. A key that has ever been in a page should be replaced, not only moved." },
      { label: "Stays on a server", means: "Right place. One thing to check: in some tools a setting's name decides whether it's sent to the browser. In Next.js, anything starting NEXT_PUBLIC_ is. Ask whether yours is one of those." },
      { label: "Wasn't needed", means: "Then the tool you're in is probably lending you its own access to a model. That usually stops when you host the app yourself. Ask what you'd need then, and where the key would go." },
    ],
    terms: ["API key", "environment variable", "rotate"],
    tell: "Say that keys stay on the server, and ask where each one is.",
  },
];

const KEY = "ms-ways-trip";

function load(): Record<string, number> {
  try {
    return JSON.parse(localStorage.getItem(KEY) ?? "{}") as Record<string, number>;
  } catch {
    return {};
  }
}

export function mountTrip(root: HTMLElement): void {
  const seen = load();

  function pick(id: string, i: number): void {
    seen[id] = i;
    try { localStorage.setItem(KEY, JSON.stringify(seen)); } catch { /* private window */ }
    render();
  }

  function paste(text: string): HTMLElement {
    return h("div", { class: "paste" }, h("p", {}, text), copyButton(text));
  }

  function card(e: Errand, n: number): HTMLElement {
    const at = seen[e.id];
    return h("section", { class: `errand${at === undefined ? "" : " done"}`, "data-errand": e.id },
      h("h2", {}, h("span", { class: "num" }, String(n + 1)), e.title),
      h("p", { class: "k" }, n === 0 ? "Paste this into your AI" : "In the same chat, paste this"),
      paste(e.prompt),
      h("p", { class: "then" }, e.then),
      e.ask ? paste(e.ask) : null,
      h("p", { class: "k" }, e.question),
      h("div", { class: "saw" }, ...e.saw.map((s, i) =>
        h("button", { type: "button", class: i === at ? "on" : "", "aria-pressed": String(i === at), click: () => pick(e.id, i) }, s.label))),
      at !== undefined && h("p", { class: "means", "aria-live": "polite" }, e.saw[at].means),
      at !== undefined && terms(e.terms),
      at !== undefined && h("p", { class: "tell" }, h("span", {}, "Next time"), e.tell),
    );
  }

  function render(): void {
    const done = ERRANDS.filter((e) => seen[e.id] !== undefined).length;
    root.replaceChildren(
      h("header", { class: "bar" },
        h("a", { href: "#", class: "back" }, "‹ All three"),
        h("span", { class: "bar-t" }, "Field Trip"),
        h("span", { class: "steps" }, `${done} of ${ERRANDS.length}`)),
      h("main", { class: "sheet" },
        h("h1", {}, "Three errands to run with a real AI."),
        h("p", { class: "lead" }, "Open any AI that can build a small web page and show it to you, in another tab. Nothing here is marked. Tell this page what you saw, and it'll tell you what that means."),
        ...ERRANDS.map(card),
        done === ERRANDS.length && h("div", { class: "win" },
          h("p", {}, "You just asked a real AI where the data lives, who decides the price and where the secret is. Those are the three questions that catch most of what goes wrong."),
          h("div", { class: "row" }, h("a", { class: "btn ghost", href: "#" }, "Done"))),
      ),
    );
  }

  render();
}
