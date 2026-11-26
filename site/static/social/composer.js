// The screenshot composer: catch the game's canvas, frame it as a 1200x630
// card with a caption (the size every network's link preview uses), and
// share it: the phone's own share sheet with the image attached, a download,
// a copied image, or a link to a page on the site whose preview is the card.

import { GAMES } from "./games.js";
import { api, ensurePlayer } from "./client.js";
import { NETWORKS, icon } from "./share.js";
import { copyText, dialog, h, toast } from "./ui.js";

const CARD_W = 1200;
const CARD_H = 630;
/** Every game draws a 480x270 screen, scaled up by a whole number and centred. */
const NATIVE_W = 480;
const NATIVE_H = 270;

/**
 * The game's screen at its own 480x270, cut out of the canvas's letterboxing.
 * The page asks WebGL to keep its last frame (see the play page's head), so
 * the canvas can be read at any moment.
 */
export function grabNative(canvas) {
  const W = canvas.width;
  const H = canvas.height;
  const scale = Math.min(W / NATIVE_W, H / NATIVE_H);
  const whole = Math.max(1, Math.floor(scale));
  const s = scale >= 1 ? whole : scale;
  const w = Math.round(NATIVE_W * s);
  const h = Math.round(NATIVE_H * s);
  const out = document.createElement("canvas");
  out.width = NATIVE_W;
  out.height = NATIVE_H;
  const ctx = out.getContext("2d");
  ctx.imageSmoothingEnabled = s < 1;
  ctx.drawImage(canvas, Math.floor((W - w) / 2), Math.floor((H - h) / 2), w, h, 0, 0, NATIVE_W, NATIVE_H);
  return out;
}

/** True if a canvas came back blank (WebGL cleared it before we looked). */
function isBlank(canvas) {
  const data = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data;
  for (let i = 0; i < data.length; i += 4 * 97) if (data[i] || data[i + 1] || data[i + 2]) return false;
  return true;
}

const crispCache = new WeakMap();

/** Native pixels blown up crisply: big with no smoothing, then down to size smoothly. */
function crisp(native, w, h) {
  const hit = crispCache.get(native);
  if (hit && hit.width === w && hit.height === h) return hit;
  const big = document.createElement("canvas");
  big.width = NATIVE_W * 5;
  big.height = NATIVE_H * 5;
  const b = big.getContext("2d");
  b.imageSmoothingEnabled = false;
  b.drawImage(native, 0, 0, big.width, big.height);
  const out = document.createElement("canvas");
  out.width = w;
  out.height = h;
  const o = out.getContext("2d");
  o.imageSmoothingEnabled = true;
  o.imageSmoothingQuality = "high";
  o.drawImage(big, 0, 0, w, h);
  crispCache.set(native, out);
  return out;
}

function wrapLines(ctx, text, width, maxLines) {
  const lines = [];
  for (const para of text.split("\n")) {
    let line = "";
    for (const word of para.split(/\s+/).filter(Boolean)) {
      const next = line ? `${line} ${word}` : word;
      if (line && ctx.measureText(next).width > width) {
        lines.push(line);
        line = word;
      } else line = next;
    }
    if (line) lines.push(line);
  }
  if (lines.length > maxLines) {
    lines.length = maxLines;
    let last = lines[maxLines - 1];
    while (last && ctx.measureText(`${last}…`).width > width) last = last.slice(0, -1);
    lines[maxLines - 1] = `${last.trimEnd()}…`;
  }
  return lines;
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

const FONT = "'Pixelify Sans', 'Atkinson Hyperlegible', system-ui, sans-serif";

/** Pixelify Sans draws "fi" and "fl" as ligatures that read as other letters; a zero-width non-joiner keeps them apart. */
const unligature = (s) => s.replace(/f(?=[fil])/g, "f‌");

/** The share card: the screen, cropped to 1200x630, with the caption and the game over it. */
export function drawCard(native, game, caption, { frame = true } = {}) {
  const def = GAMES[game];
  const out = document.createElement("canvas");
  out.width = CARD_W;
  out.height = CARD_H;
  const ctx = out.getContext("2d");
  // 16:9 into 1200x630 (1.9:1): fill the width and lose a sliver top and bottom.
  const shotH = Math.round((CARD_W * NATIVE_H) / NATIVE_W);
  ctx.drawImage(crisp(native, CARD_W, shotH), 0, Math.round((CARD_H - shotH) / 2));
  if (!frame) return out;
  const text = unligature(caption.trim());
  ctx.textRendering = "optimizeSpeed";
  ctx.font = `700 46px ${FONT}`;
  const lines = text ? wrapLines(ctx, text, CARD_W - 112, 3) : [];
  const shade = 120 + lines.length * 56;
  const grad = ctx.createLinearGradient(0, CARD_H - shade - 60, 0, CARD_H);
  grad.addColorStop(0, "rgba(8,6,16,0)");
  grad.addColorStop(0.35, "rgba(8,6,16,0.72)");
  grad.addColorStop(1, "rgba(8,6,16,0.94)");
  ctx.fillStyle = grad;
  ctx.fillRect(0, CARD_H - shade - 60, CARD_W, shade + 60);
  ctx.fillStyle = "#ffffff";
  ctx.textBaseline = "alphabetic";
  ctx.shadowColor = "rgba(0,0,0,0.6)";
  ctx.shadowOffsetY = 3;
  lines.forEach((line, i) => ctx.fillText(line, 56, CARD_H - 82 - (lines.length - 1 - i) * 56));
  ctx.shadowColor = "transparent";
  ctx.font = `600 26px ${FONT}`;
  ctx.fillStyle = def.accent;
  const host = location.host.startsWith("localhost") ? "dunderquest.com" : location.host;
  ctx.fillText(unligature(`${host}${def.page.replace(/\/$/, "")}  ·  learn ${def.lang} free in your browser`), 56, CARD_H - 34);
  // The game's name in a tag, top left.
  ctx.font = `700 24px ${FONT}`;
  const tag = def.name.toUpperCase();
  const tw = ctx.measureText(tag).width + 36;
  roundRect(ctx, 32, 28, tw, 46, 10);
  ctx.fillStyle = def.accent;
  ctx.fill();
  ctx.fillStyle = def.ink;
  ctx.fillText(tag, 50, 60);
  return out;
}

/** PNG if it's small enough for the server, else a good JPEG. */
async function encode(canvas) {
  const png = await new Promise((r) => canvas.toBlob(r, "image/png"));
  if (png && png.size <= 1_400_000) return png;
  return new Promise((r) => canvas.toBlob(r, "image/jpeg", 0.9));
}

/** A few captions to start from, about where the player is. */
function suggestions(game, context) {
  const def = GAMES[game];
  const level = context.level;
  const out = [];
  if (context.complete) out.push(`I finished ${def.name} and learned ${def.lang}!`);
  if (level) out.push(`Just cleared “${level.name}” in ${def.name}. Today's lesson: ${level.lesson}.`);
  const flavour = {
    curb: "Me vs. the borrow checker. The borrow checker is winning. Learning Rust in Curb Your Oxidation.",
    "dunder-quest": "On a very silly quest for the Grail, learning Python one scroll at a time.",
    flatmates: "My flatmate is running my JavaScript. What could possibly go wrong?",
    prince: "Turning back time with git reset. Learning Git in Prince of Versions.",
    lieutenant: "Just one more question… solving murders with SQL in Just One More JOIN.",
    greedy: "New sheriff in Backslash Ridge, where everybody is named Hobson. Learning regex in The Good, the Bad and the Greedy.",
    shell: "Every station is a command and the pass is a pipe. Learning the command line in Yes, Shell!",
  }[game];
  out.push(flavour);
  out.push(`Learning ${def.lang} with a free pixel-art game.`);
  return [...new Set(out)].slice(0, 4);
}

/**
 * Opens the composer on a fresh capture of `canvas`. `context` says where the
 * player is ({level, complete}) for the suggested captions. `onClose` runs
 * when it's dismissed (the play page gives the game its focus back).
 */
export function openComposer(canvas, game, context = {}, { onClose } = {}) {
  const def = GAMES[game];
  const native = grabNative(canvas);
  if (isBlank(native)) {
    toast("Couldn't catch the screen that time. Try again in a moment.");
    onClose?.();
    return;
  }
  const ideas = suggestions(game, context);
  let caption = ideas[0];
  let frame = true;
  let blob = null;
  let shared = null; // {id, url, image} once uploaded

  const { body, close } = dialog("Share a screenshot", { wide: true, onClose, className: "dq-composer" });
  const preview = h("canvas.dq-preview", { width: CARD_W, height: CARD_H, "aria-label": "The card as it will be shared" });
  const area = h("textarea.dq-caption", { maxlength: 280, rows: 3, "aria-label": "Caption", oninput: () => { caption = area.value; shared = null; redraw(); } }, caption);
  const chips = h("div.dq-chips", {}, ideas.map((idea) => h("button", {
    type: "button", onclick: () => { area.value = idea; caption = idea; shared = null; redraw(); },
  }, idea.length > 48 ? `${idea.slice(0, 46)}…` : idea)));
  const frameBox = h("input", { type: "checkbox", checked: true, onchange: () => { frame = frameBox.checked; shared = null; redraw(); } });
  const status = h("p.dq-status", { role: "status" });

  function redraw() {
    const card = drawCard(native, game, caption, { frame });
    preview.getContext("2d").drawImage(card, 0, 0);
    blob = null;
  }

  async function getBlob() {
    if (!blob) blob = await encode(preview);
    return blob;
  }

  const fileName = () => `${def.short.replace(/[^\w]+/g, "-").toLowerCase()}-${Date.now().toString(36)}.${blob?.type === "image/jpeg" ? "jpg" : "png"}`;
  const shareText = () => `${caption.trim()} ${def.tag}`.trim();

  async function upload() {
    if (shared) return shared;
    status.textContent = "Making a link…";
    await ensurePlayer();
    const form = new FormData();
    form.set("game", game);
    form.set("caption", caption.trim());
    const b = await getBlob();
    form.set("image", new File([b], fileName(), { type: b.type }));
    shared = await api("POST", "/api/shots", form);
    shared.full = `${location.origin}${shared.url}`;
    status.textContent = "";
    linkOut.value = shared.full;
    linkRow.hidden = false;
    return shared;
  }

  async function run(fn) {
    try {
      await fn();
    } catch (err) {
      status.textContent = err.message || "That didn't work.";
    }
  }

  // Open the network's window first (so the popup isn't blocked), then point it at the link.
  function shareTo(build) {
    const win = window.open("about:blank", "_blank");
    if (win) win.opener = null;
    upload().then((s) => {
      const url = build(shareText(), s.full);
      if (win) win.location.href = url;
      else location.href = url;
    }).catch((err) => {
      win?.close();
      status.textContent = err.message || "That didn't work.";
    });
  }

  const linkOut = h("input.dq-link", { readonly: true, "aria-label": "Link to this screenshot", onclick: (e) => e.target.select() });
  const linkRow = h("div.dq-link-row", { hidden: true }, linkOut,
    h("button.dq-btn", { type: "button", onclick: () => run(async () => { await copyText(linkOut.value); status.textContent = "Link copied."; }) }, "Copy"));

  const canShareFiles = (() => {
    try {
      return Boolean(navigator.canShare?.({ files: [new File([""], "x.png", { type: "image/png" })] }));
    } catch {
      return false;
    }
  })();

  const actions = h("div.dq-actions", {},
    canShareFiles ? h("button.dq-btn.dq-primary", {
      type: "button",
      onclick: () => run(async () => {
        const b = await getBlob();
        const file = new File([b], fileName(), { type: b.type });
        await navigator.share({ files: [file], text: `${shareText()} ${location.origin}${def.page}` }).catch((e) => {
          if (e.name !== "AbortError") throw e;
        });
      }),
    }, h("span", { html: icon("share") }), "Share…") : null,
    h("button.dq-btn", {
      type: "button",
      onclick: () => run(async () => {
        const b = await getBlob();
        const a = h("a", { href: URL.createObjectURL(b), download: fileName() });
        a.click();
        setTimeout(() => URL.revokeObjectURL(a.href), 4000);
      }),
    }, h("span", { html: icon("download") }), "Download"),
    window.ClipboardItem ? h("button.dq-btn", {
      type: "button",
      onclick: () => run(async () => {
        // Clipboards take PNG only.
        const png = await new Promise((r) => preview.toBlob(r, "image/png"));
        await navigator.clipboard.write([new ClipboardItem({ "image/png": png })]);
        status.textContent = "Image copied. Paste it into a post.";
      }),
    }, "Copy image") : null,
    h("button.dq-btn", { type: "button", onclick: () => run(async () => { const s = await upload(); await copyText(s.full); status.textContent = "Link copied. Its preview is this card."; }) },
      h("span", { html: icon("link") }), "Get a link"));

  const networks = h("div.dq-networks", {}, h("span.dq-label", {}, "Post to"),
    NETWORKS.filter(([k]) => k !== "email").map(([key, label, build]) =>
      h(`button.dq-net.dq-share-${key}`, { type: "button", title: `Post on ${label}`, "aria-label": `Post on ${label}`, onclick: () => shareTo(build) },
        h("span", { html: icon(key, 20) }))));

  body.append(
    h("div.dq-composer-grid", {},
      h("div.dq-preview-wrap", {}, preview),
      h("div.dq-composer-side", {},
        h("label.dq-label", {}, "Caption"), area, chips,
        h("label.dq-check", {}, frameBox, " Caption and game name on the picture"),
        actions, networks, linkRow, status,
        h("p.dq-fine", {}, "A link makes a page on dunderquest.com with this picture as its preview. You can delete it from your profile."))),
  );
  redraw();
  area.focus();
  area.select();
  return close;
}
