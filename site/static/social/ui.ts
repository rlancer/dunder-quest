// Small UI pieces the social pages and the in-game overlay share: making
// elements, dialogs, toasts, and wiring share buttons.

import { icon } from "./share.ts";

/** What h() can be given as a child: nodes and text, with null, undefined and false skipped. */
export type Child = Node | string | number | boolean | null | undefined;

/**
 * h()'s attributes: `on…` are event listeners, `html` is innerHTML, `style`
 * an object of styles, and anything else an attribute (true is "", and
 * null, undefined and false leave it off).
 */
export interface Attrs {
  [name: string]: unknown;
  html?: string;
  style?: Record<string, string>;
  onclick?: (e: MouseEvent) => unknown;
  onsubmit?: (e: SubmitEvent) => unknown;
  oninput?: (e: Event) => unknown;
  onchange?: (e: Event) => unknown;
}

/** The element's tag name from h()'s "tag.class.class". */
type TagName<T extends string> = T extends `${infer N}.${string}` ? N : T;
/** The element h() makes for a tag: an HTMLInputElement for "input.x", and so on. */
export type Made<T extends string> = TagName<T> extends keyof HTMLElementTagNameMap ? HTMLElementTagNameMap[TagName<T>] : HTMLElement;

/** h("div.cls", {attrs}, ...children): a tiny element builder. */
export function h<T extends string>(tag: T, attrs: Attrs | null = {}, ...children: (Child | Child[])[]): Made<T> {
  const [name, ...classes] = tag.split(".");
  const el = document.createElement(name || "div");
  if (classes.length) el.className = classes.join(" ");
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith("on")) el.addEventListener(k.slice(2).toLowerCase(), v as EventListener);
    else if (k === "html") el.innerHTML = v as string;
    else if (k === "style" && typeof v === "object") Object.assign(el.style, v);
    else el.setAttribute(k, v === true ? "" : String(v));
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el as Made<T>;
}

export function iconEl(name: string, size?: number): HTMLSpanElement {
  const span = document.createElement("span");
  span.className = "dq-icon-wrap";
  span.innerHTML = icon(name, size);
  return span;
}

/** Keys typed in our dialogs stay in them, instead of reaching a game listening on the page. */
function trapKeys(el: HTMLElement): void {
  for (const type of ["keydown", "keyup", "keypress"]) {
    el.addEventListener(type, (e) => {
      if ((e as KeyboardEvent).key === "Escape" && type === "keydown") return;
      e.stopPropagation();
    });
  }
}

/**
 * A modal dialog built on <dialog>. Returns {el, body, close}. `onClose`
 * runs once however it's closed (button, Escape, backdrop).
 */
export function dialog(
  title: string,
  { onClose, wide = false, className = "" }: { onClose?: () => void; wide?: boolean; className?: string } = {},
): { el: HTMLDialogElement; body: HTMLDivElement; close: () => void } {
  const body = h("div.dq-dialog-body");
  const close = () => el.close();
  const el: HTMLDialogElement = h(`dialog.dq-dialog${wide ? ".dq-wide" : ""}${className ? `.${className}` : ""}`, { "aria-label": title },
    h("header.dq-dialog-head", {}, h("h2", {}, title),
      h("button.dq-x", { type: "button", "aria-label": "Close", onclick: close }, "×")),
    body);
  trapKeys(el);
  el.addEventListener("click", (e) => {
    if (e.target === el) close();
  });
  el.addEventListener("close", () => {
    el.remove();
    onClose?.();
  });
  document.body.append(el);
  el.showModal();
  return { el, body, close };
}

let toastBox: HTMLElement | null = null;

/** A message in the corner that goes away by itself; `actions` are [label, fn] buttons. */
export function toast(
  message: string,
  { actions = [], timeout = 6000, kind = "" }: { actions?: [string, () => void][]; timeout?: number; kind?: string } = {},
): () => void {
  if (!toastBox || !toastBox.isConnected) {
    toastBox = h("div.dq-toasts", { role: "status", "aria-live": "polite" });
    document.body.append(toastBox);
  }
  const close = () => {
    item.classList.add("dq-leaving");
    setTimeout(() => item.remove(), 250);
  };
  const item = h(`div.dq-toast${kind ? `.dq-${kind}` : ""}`, {},
    h("p", {}, message),
    actions.length ? h("div.dq-toast-actions", {}, actions.map(([label, fn]) =>
      h("button", { type: "button", onclick: () => { close(); fn(); } }, label))) : null,
    h("button.dq-x", { type: "button", "aria-label": "Dismiss", onclick: close }, "×"));
  toastBox.append(item);
  if (timeout) setTimeout(close, timeout);
  return close;
}

/** Copies text, falling back to a hidden textarea where the async clipboard isn't allowed. */
export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    const area = h("textarea", { style: { position: "fixed", opacity: "0" } }, text);
    document.body.append(area);
    area.select();
    const ok = document.execCommand("copy");
    area.remove();
    return ok;
  }
}

/** Gives the server-rendered share rows their native-share and copy-link buttons. */
export function wireShareRows(root: ParentNode = document): void {
  for (const row of root.querySelectorAll<HTMLElement>(".dq-share:not([data-wired])")) {
    row.dataset.wired = "1";
    const text = row.dataset.shareText;
    const url = row.dataset.shareUrl;
    const native = row.querySelector<HTMLElement>('[data-share="native"]');
    if (native && navigator.share) {
      native.hidden = false;
      native.addEventListener("click", () => navigator.share({ title: document.title, text, url }).catch(() => {}));
    }
    row.querySelector('[data-share="copy"]')?.addEventListener("click", async (e) => {
      const btn = e.currentTarget as HTMLElement;
      const label = btn.querySelector("span")!;
      if (await copyText(url!)) {
        label.textContent = "Copied!";
        setTimeout(() => (label.textContent = "Copy link"), 1800);
      }
    });
  }
}

export function plural(n: number, [one, many]: [string, string]): string {
  return `${n} ${n === 1 ? one : many}`;
}
