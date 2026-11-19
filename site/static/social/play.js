// The social layer on a game's play page: the small toolbar in the corner
// (screenshot, leaderboard, you), the toasts when a level is cleared or a
// certificate earned, and window.DQSocial, the bridge each game's Social
// autoload talks to.
//
// The bridge, called from GDScript through JavaScriptBridge:
//   DQSocial.boot(game, localSaveText) -> text to write over the local save, or ""
//   DQSocial.attach(game, saveText)     the same, when the page was too late for boot()
//   DQSocial.saved(game, saveText)      the save changed; back it up and score it
//   DQSocial.screenshot()               open the composer (a key in the game)
//
// Progress is merged, never replaced: a save from another device adds its
// cleared levels and best times to this one's (see games.js).

import { GAMES, merge, normalize, summarize } from "./games.js";
import { api, cachedPlayer, ensurePlayer, googleButton, onPlayer, profileUrl, rename, token } from "./client.js";
import { openComposer } from "./composer.js";
import { icon } from "./share.js";
import { dialog, h, plural, toast } from "./ui.js";

const game = new URL(import.meta.url).searchParams.get("game") || guessGame();
const def = GAMES[game];

function guessGame() {
  const first = location.pathname.split("/").filter(Boolean)[0];
  return first === "play" ? "dunder-quest" : first;
}

const MARK = `dq.synced.${game}`;
/** What this browser last knew of its own progress, to tell an in-game reset from a stale save. */
function marker() {
  try {
    return JSON.parse(localStorage.getItem(MARK) || "null");
  } catch {
    return null;
  }
}
function setMarker(count) {
  try {
    localStorage.setItem(MARK, JSON.stringify({ count }));
  } catch {}
}

// Ask for the cloud save straight away: the game takes seconds to download,
// so this is nearly always back before the game's Social autoload asks.
let cloud = null; // {data, summary} or null
let cloudReady = false;
let booted = null; // the text the game started on
const cloudFetch = (token() ? api("GET", "/api/saves").then((r) => {
  cloud = r.saves[game] || null;
}).catch(() => {}) : Promise.resolve()).finally(() => {
  cloudReady = true;
  if (booted !== null) lateCloud();
});

let last = null; // the summary of the last save seen
let lastText = "";

/**
 * The game's Social autoload calls this before its progress loads. Returns
 * the save to use when the cloud has progress this browser lacks, else "".
 */
function boot(_game, local) {
  booted = local || "";
  const localSave = local ? normalize(game, local) : null;
  last = summarize(game, localSave);
  lastText = local || "";
  if (!cloudReady || !cloud) return "";
  return mergedText(local) || "";
}

/** The merged save as text if it adds anything to `local`, else null. */
function mergedText(local) {
  const localSave = local ? normalize(game, local) : null;
  const localCount = summarize(game, localSave).count;
  const mark = marker();
  // Fewer levels than this browser last had means the player reset the game on purpose.
  if (localSave && mark && localCount < mark.count) {
    setMarker(localCount);
    return null;
  }
  const merged = merge(game, localSave, cloud.data);
  if (!merged || JSON.stringify(merged) === JSON.stringify(localSave)) return null;
  setMarker(summarize(game, merged).count);
  last = summarize(game, merged);
  return JSON.stringify(merged, null, "\t");
}

/** The cloud answered after the game started: offer to reload if it has more. */
function lateCloud() {
  if (!cloud || booted === null) return;
  const text = mergedText(lastText || booted);
  if (!text) return;
  pendingRestore = text;
  toast("Your progress from another device is ready.", {
    timeout: 0,
    actions: [["Load it", () => {
      try {
        sessionStorage.setItem(`dq.restore.${game}`, pendingRestore);
      } catch {}
      location.reload();
    }]],
  });
}
let pendingRestore = null;

// A reload asked for by lateCloud(): hand the merged save straight to boot().
const restoring = (() => {
  try {
    const t = sessionStorage.getItem(`dq.restore.${game}`);
    sessionStorage.removeItem(`dq.restore.${game}`);
    return t;
  } catch {
    return null;
  }
})();

function bootWithRestore(g, local) {
  if (restoring) {
    booted = local || "";
    const merged = merge(game, local ? normalize(game, local) : null, restoring);
    last = summarize(game, merged);
    lastText = JSON.stringify(merged, null, "\t");
    setMarker(last.count);
    return lastText;
  }
  return boot(g, local);
}

/** The page script loaded after the game had already read its save: watch from here. */
function attach(_game, local) {
  booted = local || "";
  last = summarize(game, local ? normalize(game, local) : null);
  lastText = local || "";
  if (local) saved(game, local);
  if (cloudReady) lateCloud();
}

let uploadTimer = 0;
let uploading = Promise.resolve();
let uploadedText = "";

/**
 * The game saved (or started with a save): score it against the last one,
 * then back it up. A save with nothing cleared yet doesn't make a player.
 */
function saved(_game, text) {
  if (!text) return;
  const save = normalize(game, text);
  if (!save) return;
  const now = summarize(game, save);
  let fresh = [];
  if (text !== lastText) {
    const before = last || summarize(game, null);
    fresh = now.cleared.filter((id) => !before.cleared.includes(id));
    if (fresh.length) celebrate(fresh[fresh.length - 1], now);
    lastText = text;
    last = now;
    setMarker(now.count);
  }
  if (text === uploadedText) return;
  if (!token() && now.count === 0) return;
  if (cloud && JSON.stringify(normalize(game, cloud.data)) === JSON.stringify(save)) {
    uploadedText = text;
    return;
  }
  clearTimeout(uploadTimer);
  uploadTimer = setTimeout(() => {
    uploading = uploading.then(() => upload(text)).catch(() => {});
  }, fresh.length ? 200 : 2500);
}

let welcomed = false;

async function upload(text) {
  const firstTime = !token();
  await ensurePlayer();
  const res = await api("PUT", `/api/saves/${game}`, { data: text });
  uploadedText = text;
  cloud = { data: res.data, summary: res.summary };
  updateChip(res.player);
  if (res.certificate?.fresh) certificateEarned(res.certificate);
  else if (firstTime && !welcomed && res.summary.count) {
    welcomed = true;
    toast(`You're on the leaderboard as ${res.player.name}${res.rank ? `, #${res.rank} in ${def.short}` : ""}.`, {
      timeout: 9000,
      actions: [["Change name", () => openAccount()], ["See the board", () => openBoard()]],
    });
  }
}

function celebrate(id, now) {
  const level = def.levels.find((l) => l.id === id);
  if (!level || now.complete) return; // a finished game gets the certificate instead
  toast(`Cleared “${level.name}”: ${level.lesson}. ${now.count} of ${now.total} ${def.unit[1]}.`, {
    kind: "win",
    timeout: 8000,
    actions: [["Share a screenshot", () => screenshot()]],
  });
}

function certificateEarned(cert) {
  const url = `/c/${cert.id}`;
  const { body, close } = dialog("You earned a certificate!", { className: "dq-cert-dialog", onClose: focusGame });
  const name = h("input", { value: cert.name, maxlength: 32, minlength: 2, "aria-label": "Name on the certificate" });
  const status = h("p.dq-status", { role: "status" });
  const img = h("img.dq-cert-img", { src: `${url}.png?t=${Date.now()}`, alt: `Your ${def.name} certificate`, width: 1200, height: 630 });
  body.append(
    h("p", {}, `You finished every ${def.unit[0]} of ${def.name}. That's real ${def.lang}.`),
    img,
    h("form.dq-inline", {
      onsubmit: async (e) => {
        e.preventDefault();
        try {
          await api("PATCH", `/api/certificates/${cert.id}`, { name: name.value });
          img.src = `${url}.png?t=${Date.now()}`;
          status.textContent = "Saved.";
        } catch (err) {
          status.textContent = err.message;
        }
      },
    }, h("label", {}, "Name on it ", name), h("button.dq-btn", { type: "submit" }, "Save")),
    status,
    h("div.dq-actions", {},
      h("a.dq-btn.dq-primary", { href: url, target: "_blank" }, "View and share it"),
      h("button.dq-btn", { type: "button", onclick: close }, "Keep playing")),
  );
}

// ---- The toolbar ----

let chip;

function updateChip(player) {
  if (!chip) return;
  chip.querySelector(".dq-chip-name").textContent = player ? player.name : "Sign in";
  chip.title = player ? `${player.name} · ${player.xp} XP` : "Sign in to keep your progress";
}

function canvas() {
  return document.getElementById("canvas") || document.querySelector("canvas");
}

function focusGame() {
  canvas()?.focus();
}

function context() {
  const s = last || summarize(game, null);
  const id = s.cleared[s.cleared.length - 1];
  return { level: def.levels.find((l) => l.id === id), complete: s.complete };
}

function screenshot() {
  const c = canvas();
  if (!c) return;
  openComposer(c, game, context(), { onClose: focusGame });
}

async function openBoard() {
  const { body } = dialog(`${def.name} leaderboard`, { onClose: focusGame });
  body.append(h("p.dq-status", {}, "Loading…"));
  try {
    const board = await api("GET", `/api/leaderboard?game=${game}&limit=10`);
    body.textContent = "";
    if (!board.rows.length) {
      body.append(h("p", {}, `Nobody's on the board yet. Clear a ${def.unit[0]} and it's yours.`));
    } else {
      const me = cachedPlayer();
      body.append(h("ol.dq-board", {}, board.rows.map((r) => h(`li${me && r.id === me.id ? ".dq-me" : ""}`, {},
        h("span.dq-rank", {}, `#${r.rank}`),
        h("a.dq-name", { href: `/u/${r.id}`, target: "_blank" }, r.name),
        h("span.dq-progress", {}, `${r.count}/${r.total}`),
        h("span.dq-line", {}, r.complete ? `★ ${r.line}` : r.line)))));
      if (board.me && !board.rows.some((r) => r.id === board.me.id)) {
        body.append(h("p.dq-mine", {}, `You're #${board.me.rank} of ${board.players}.`));
      }
    }
    body.append(h("p", {}, h("a", { href: `/leaderboards/#${game}`, target: "_blank" }, "Every leaderboard")));
  } catch (err) {
    body.textContent = err.message;
  }
}

async function openAccount() {
  const player = cachedPlayer();
  const { body, close } = dialog(player ? "You" : "Keep your progress", { onClose: focusGame });
  const status = h("p.dq-status", { role: "status" });
  const name = h("input", { value: player?.name || "", maxlength: 32, minlength: 2, placeholder: "Your name on the boards", "aria-label": "Your name" });
  body.append(
    h("p", {}, player
      ? `${player.xp} XP so far. Your progress is saved to the cloud as you play.`
      : `Your progress saves to this browser as you play, and to the cloud from your first clear, with a silly name you can change. Nothing to sign up for.`),
    h("form.dq-inline", {
      onsubmit: async (e) => {
        e.preventDefault();
        try {
          const p = await rename(name.value);
          updateChip(p);
          status.textContent = "Saved.";
        } catch (err) {
          status.textContent = err.message;
        }
      },
    }, h("label", {}, "Name ", name), h("button.dq-btn", { type: "submit" }, "Save")),
    status,
  );
  const google = h("div.dq-google");
  if (!player?.google) {
    body.append(h("p.dq-fine", {}, "Sign in with Google to play on another device and keep your progress. We keep no email or name from Google."), google);
    googleButton(google, {
      onSignIn: (p) => {
        updateChip(p);
        status.textContent = `Signed in. Welcome, ${p.name}!`;
      },
      onError: (err) => (status.textContent = err.message),
    }).then((ok) => {
      if (!ok) google.remove();
    }).catch(() => google.remove());
  }
  body.append(h("div.dq-actions", {},
    h("a.dq-btn", { href: profileUrl(player), target: "_blank" }, "Your profile"),
    h("a.dq-btn", { href: "/me/", target: "_blank" }, "Settings"),
    h("button.dq-btn", { type: "button", onclick: close }, "Back to the game")));
}

function toolbar() {
  chip = h("button.dq-tool.dq-chip", { type: "button", onclick: openAccount }, h("span", { html: icon("user") }), h("span.dq-chip-name", {}, "Sign in"));
  const bar = h("div.dq-toolbar", { role: "toolbar", "aria-label": "Share and leaderboards" },
    h("button.dq-tool", { type: "button", title: "Screenshot (F9)", "aria-label": "Take a screenshot to share", onclick: screenshot }, h("span", { html: icon("camera") })),
    h("button.dq-tool", { type: "button", title: "Leaderboard", "aria-label": "Leaderboard", onclick: openBoard }, h("span", { html: icon("trophy") })),
    chip);
  document.body.append(bar);
  updateChip(cachedPlayer());
  onPlayer(updateChip);
  // Fade the bar while playing; any mouse movement brings it back.
  let idle = 0;
  const wake = () => {
    bar.classList.remove("dq-idle");
    clearTimeout(idle);
    idle = setTimeout(() => bar.classList.add("dq-idle"), 3500);
  };
  addEventListener("pointermove", wake, { passive: true });
  addEventListener("pointerdown", wake, { passive: true });
  wake();
  // F9 anywhere takes a screenshot; the games don't use it.
  addEventListener("keydown", (e) => {
    if (e.key === "F9") {
      e.preventDefault();
      screenshot();
    }
  }, true);
}

if (def) {
  window.DQSocial = { boot: bootWithRestore, attach, saved, screenshot, version: 1 };
  toolbar();
}
