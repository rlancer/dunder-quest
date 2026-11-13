// The few DOM helpers the three sketches share.

type Child = Node | string | null | false | undefined;

export function h<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Record<string, string | boolean | ((e: Event) => void)> = {},
  ...kids: Child[]
): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (typeof v === "function") el.addEventListener(k, v);
    else if (v === true) el.setAttribute(k, "");
    else if (v !== false) el.setAttribute(k, v);
  }
  el.append(...kids.filter((k): k is Node | string => k !== null && k !== false && k !== undefined));
  return el;
}

export function art(name: string, cls = ""): HTMLImageElement {
  return h("img", { src: `./art/${name}.png`, alt: "", class: cls });
}

/** The real word for the thing just seen, shown only after it's been seen. */
export function terms(words: string[]): HTMLElement {
  return h("p", { class: "terms" }, h("span", { class: "terms-k" }, "Real terms"), ...words.map((w) => h("b", {}, w)));
}

export function copyButton(text: string, label = "Copy"): HTMLButtonElement {
  const b = h("button", { class: "btn ghost copy", type: "button" }, label);
  b.addEventListener("click", () => {
    void navigator.clipboard?.writeText(text).catch(() => {});
    b.textContent = "Copied";
    setTimeout(() => (b.textContent = label), 1500);
  });
  return b;
}

/** Two-way switch. Reads as a sentence: "The server keeps bookings [in its head | in the database]". */
export function toggle<T extends string>(
  lead: string,
  options: [T, string][],
  value: T,
  set: (v: T) => void,
): HTMLElement {
  return h("div", { class: "switch" },
    h("span", { class: "switch-lead" }, lead),
    h("span", { class: "switch-opts", role: "group", "aria-label": lead },
      ...options.map(([v, label]) =>
        h("button", { type: "button", class: v === value ? "on" : "", "aria-pressed": String(v === value), "data-v": v, click: () => set(v) }, label))),
  );
}

export const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
