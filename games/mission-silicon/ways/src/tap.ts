// Sketch 1, One Tap: watch it. One picture of the app, a switch that changes
// how it's built, and buttons that send something through it. No score and
// nothing to get wrong: you flip the switch and see what the same tap does.

import { art, h, sleep, terms, toggle } from "./dom";
import { type Place, type Step, type World, DEPOSIT, ask, book, newWorld, rebuild, restart, rotate, snoop } from "./model";

interface Scene { title: string; lead: string; terms: string[]; tell: string }

const SCENES: Scene[] = [
  {
    title: "Where does a booking live?",
    lead: "Book a few tables. Then restart the server, which happens every time a change ships.",
    terms: ["memory", "database", "deploy"],
    tell: "Save every booking in a database, never only in memory.",
  },
  {
    title: "Who decides the price?",
    lead: "The deposit is $20. Drag what the phone says it is, then send the booking.",
    terms: ["client", "request", "server-side check"],
    tell: "The server works out every price itself and never trusts an amount the phone sends.",
  },
  {
    title: "Where is the key?",
    lead: "The AI model charges a dollar a question, to whoever holds the key. Let a stranger look around.",
    terms: ["API key", "environment variable", "rotate"],
    tell: "Keep the AI model's key on the server, never in the app. If it has ever been in the app, replace it.",
  },
];

export function mountTap(root: HTMLElement, opts: { instant?: boolean } = {}): void {
  let world: World = newWorld();
  let scene = 0;
  let slip = DEPOSIT;
  let says = "";
  let acted = false;
  let busy = false;

  const dia = h("div", { class: "dia" });
  const dot = h("i", { class: "dot" });
  // Made once, so a drag isn't interrupted by the screen being redrawn.
  const range = h("input", { type: "range", min: "0", max: String(DEPOSIT), step: "5", value: String(DEPOSIT), "aria-label": "The deposit the phone says" });
  const slipLabel = h("b", {}, `$${DEPOSIT}`);
  range.addEventListener("input", () => {
    slip = Number(range.value);
    slipLabel.textContent = `$${slip}`;
    renderDia();
  });

  async function fly(hops: Place[]): Promise<void> {
    if (opts.instant || hops.length === 0) return;
    const box = dia.getBoundingClientRect();
    for (let i = 0; i < hops.length; i++) {
      const node = dia.querySelector<HTMLElement>(`[data-node="${hops[i]}"]`);
      if (!node) continue;
      const r = node.getBoundingClientRect();
      dot.style.transition = i === 0 ? "none" : "";
      dot.style.transform = `translate(${r.left - box.left + r.width / 2 - 9}px, ${r.top - box.top + r.height / 2 - 9}px)`;
      dot.classList.add("show");
      node.classList.add("lit");
      await sleep(i === 0 ? 60 : 420);
      node.classList.remove("lit");
    }
    dot.classList.remove("show");
  }

  async function act(step: Step, text = step.says, reveals = true): Promise<void> {
    if (busy) return;
    busy = true;
    root.classList.add("busy");
    await fly(step.hops);
    world = step.world;
    says = text;
    acted = acted || reveals;
    busy = false;
    root.classList.remove("busy");
    render();
  }

  function go(n: number): void {
    scene = n;
    says = "";
    acted = false;
    world = newWorld(world.build);
    slip = DEPOSIT;
    render();
  }

  function node(id: Place, name: string, pic: string, ...lines: (string | false)[]): HTMLElement {
    return h("div", { class: "node", "data-node": id },
      art(pic), h("b", {}, name), ...lines.filter((l): l is string => !!l).map((l) => h("span", {}, l)));
  }

  function renderDia(): void {
    const b = world.build;
    const keyHere = (where: string) => (scene === 2 && b.key === where ? "holds the key" : false);

    dia.replaceChildren(
      node("phone", "Phone", "phone", "the app", scene === 1 && `says $${slip}`, keyHere("app")),
      node("server", "Server", "robot",
        scene === 0 && (b.store === "memory" ? `remembering ${world.inMemory}` : "remembering 0"),
        scene === 1 && `till $${world.till}`,
        keyHere("server")),
      node("database", "Database", "ledger", scene === 0 ? `${world.inDatabase} written down` : "bookings"),
      scene === 2 ? node("stranger", "Stranger", "stranger", world.leaked ? "has a key" : "no key") : h("div", { class: "node ghost" }),
      node("model", "AI model", "model", scene === 2 ? `bill $${world.bill}` : "$1 a question"),
      h("div", { class: "node ghost" }),
      dot,
    );
  }

  function render(): void {
    const s = SCENES[scene];
    const b = world.build;
    renderDia();
    range.value = String(slip);
    slipLabel.textContent = `$${slip}`;

    const controls = h("div", { class: "controls" });
    if (scene === 0) {
      controls.append(
        toggle("The server keeps bookings", [["memory", "in its head"], ["database", "in the database"]], b.store, (v) => { world = rebuild(world, { store: v }); render(); }),
        h("div", { class: "row" },
          h("button", { class: "btn", type: "button", "data-act": "book", click: () => { void act(book(world), undefined, false); } }, "Book a table"),
          h("button", { class: "btn warn", type: "button", "data-act": "restart", click: () => void act(restart(world)) }, "Restart the server")),
      );
    } else if (scene === 1) {
      controls.append(
        h("label", { class: "slip" }, h("span", {}, "The phone says the deposit is"), slipLabel, range),
        toggle("The deposit is worked out", [["phone", "on the phone"], ["server", "on the server"]], b.pricer, (v) => { world = rebuild(world, { pricer: v }); render(); }),
        h("div", { class: "row" },
          h("button", { class: "btn", type: "button", "data-act": "send", click: () => { const r = book(world, slip); void act(r, r.paid); } }, "Send the booking")),
      );
    } else {
      controls.append(
        toggle("The model's key lives", [["app", "in the app"], ["server", "on the server"]], b.key, (v) => { world = rebuild(world, { key: v }); render(); }),
        h("div", { class: "row" },
          h("button", { class: "btn", type: "button", "data-act": "ask", click: () => void act(ask(world), undefined, false) }, "A diner asks"),
          h("button", { class: "btn warn", type: "button", "data-act": "snoop", click: () => void act(snoop(world)) }, "A stranger looks"),
          world.leaked && h("button", { class: "btn ghost", type: "button", "data-act": "rotate", click: () => void act(rotate(world)) }, "Change the key")),
      );
    }

    const short = scene === 1 && world.short > 0 ? ` So far you're $${world.short} short.` : "";
    root.replaceChildren(
      h("header", { class: "bar" },
        h("a", { href: "#", class: "back" }, "‹ All three"),
        h("span", { class: "bar-t" }, "One Tap"),
        h("span", { class: "steps" }, `${scene + 1} of ${SCENES.length}`)),
      h("main", { class: "sheet" },
        h("h1", {}, s.title),
        h("p", { class: "lead" }, s.lead),
        dia,
        h("p", { class: `says${says ? "" : " empty"}`, "aria-live": "polite" }, says ? says + short : "Flip the switch either way and try the same thing again."),
        controls,
        acted && terms(s.terms),
        acted && h("p", { class: "tell" }, h("span", {}, "To tell your AI"), s.tell),
        h("nav", { class: "pager" },
          scene > 0 ? h("button", { class: "btn ghost", type: "button", "data-act": "prev", click: () => go(scene - 1) }, "‹ Back") : h("span"),
          scene < SCENES.length - 1
            ? h("button", { class: "btn ghost", type: "button", "data-act": "next", click: () => go(scene + 1) }, "Next ›")
            : h("a", { class: "btn ghost", href: "#" }, "Done")),
      ),
    );
  }

  render();
}
