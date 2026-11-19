// Small UI pieces the social pages and the in-game overlay share: making
// elements, dialogs, toasts, and wiring share buttons.

import { icon } from "./share.js";

/** h("div.cls", {attrs}, ...children): a tiny element builder. */
export function h(tag, attrs = {}, ...children) {
  const [name, ...classes] = tag.split(".");
  const el = document.createElement(name || "div");
  if (classes.length) el.className = classes.join(" ");
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith("on")) el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === "html") el.innerHTML = v;
    else if (k === "style" && typeof v === "object") Object.assign(el.style, v);
    else el.setAttribute(k, v === true ? "" : String(v));
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

export function iconEl(name, size) {
  const span = document.createElement("span");
  span.className = "dq-icon-wrap";
  span.innerHTML = icon(name, size);
  return span;
}

/** Keys typed in our dialogs stay in them, instead of reaching a game listening on the page. */
function trapKeys(el) {
  for (const type of ["keydown", "keyup", "keypress"]) {
    el.addEventListener(type, (e) => {
      if (e.key === "Escape" && type === "keydown") return;
      e.stopPropagation();
    });
  }
}

/**
 * A modal dialog built on <dialog>. Returns {el, body, close}. `onClose`
 * runs once however it's closed (button, Escape, backdrop).
 */
export function dialog(title, { onClose, wide = false, className = "" } = {}) {
  const body = h("div.dq-dialog-body");
  const close = () => el.close();
  const el = h(`dialog.dq-dialog${wide ? ".dq-wide" : ""}${className ? `.${className}` : ""}`, { "aria-label": title },
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

let toastBox = null;

/** A message in the corner that goes away by itself; `actions` are [label, fn] buttons. */
export function toast(message, { actions = [], timeout = 6000, kind = "" } = {}) {
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
export async function copyText(text) {
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
export function wireShareRows(root = document) {
  for (const row of root.querySelectorAll(".dq-share:not([data-wired])")) {
    row.dataset.wired = "1";
    const text = row.dataset.shareText;
    const url = row.dataset.shareUrl;
    const native = row.querySelector('[data-share="native"]');
    if (native && navigator.share) {
      native.hidden = false;
      native.addEventListener("click", () => navigator.share({ title: document.title, text, url }).catch(() => {}));
    }
    row.querySelector('[data-share="copy"]')?.addEventListener("click", async (e) => {
      const btn = e.currentTarget;
      const label = btn.querySelector("span");
      if (await copyText(url)) {
        label.textContent = "Copied!";
        setTimeout(() => (label.textContent = "Copy link"), 1800);
      }
    });
  }
}

export function plural(n, [one, many]) {
  return `${n} ${n === 1 ? one : many}`;
}
