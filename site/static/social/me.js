// /me/: your name, your progress in every game, your certificates and
// screenshots, Google sign-in, your save key (to move to another device
// without Google), and deleting it all.

import { avatarSvg } from "./avatar.js";
import { GAMES, ORDER, bestLine } from "./games.js";
import { api, deleteAccount, googleButton, me, rename, signOut, token, useKey } from "./client.js";
import { icon, linkedInCertUrl } from "./share.js";
import { copyText, h, plural } from "./ui.js";

const root = document.getElementById("dq-me");

async function fromHash() {
  // A save key link: /me/#key=<token>
  const m = /key=([\w.-]+)/.exec(location.hash);
  if (!m) return null;
  history.replaceState(null, "", location.pathname);
  try {
    await useKey(m[1]);
    return "That save key worked: this browser now plays as you.";
  } catch (err) {
    return `That save key didn't work (${err.message}).`;
  }
}

function section(title, ...kids) {
  return h("section", {}, h("h2", {}, title), ...kids);
}

function nameForm(player, status) {
  const input = h("input", { name: "name", value: player.name, maxlength: 32, minlength: 2, required: true, "aria-label": "Your name" });
  return h("form.dq-inline", {
    onsubmit: async (e) => {
      e.preventDefault();
      try {
        const p = await rename(input.value);
        status.textContent = `Saved. You're ${p.name} on the boards.`;
      } catch (err) {
        status.textContent = err.message;
      }
    },
  }, h("label", {}, "Your name on the leaderboards and certificates", input), h("button.btn.btn-small", { type: "submit" }, "Save"));
}

function signInBlock(player, status) {
  const box = h("div.dq-google");
  const wrap = h("div", {},
    h("p", {}, player?.google
      ? "You're signed in with Google, so this progress follows you to any device where you sign in."
      : player
        ? "Right now only this browser knows it's you: clear its data and your progress is stranded. Sign in with Google to keep it, and to play on any device. If that account already has progress, the two are merged. We keep no email, name or picture from Google, only an anonymous account number."
        : "Sign in with Google to pick up your progress from another device. We keep no email, name or picture from Google, only an anonymous account number."),
    player?.google ? h("div.dq-actions", {},
      h("button.btn.btn-small.btn-ghost", { type: "button", onclick: async () => { await signOut(); render("Signed out on this browser."); } }, "Sign out here")) : box);
  if (!player?.google) {
    googleButton(box, {
      onSignIn: () => render("Signed in with Google."),
      onError: (err) => (status.textContent = err.message),
    }).then((ok) => {
      if (!ok) box.replaceWith(h("p.dq-fine", {}, "Google sign-in isn't switched on yet. Your save key below does the same job."));
    }).catch(() => box.remove());
  }
  return wrap;
}

function keyBlock(status, hasKey = true) {
  const key = token();
  const link = `${location.origin}/me/#key=${key}`;
  const shown = h("p.dq-key", { hidden: true }, link);
  const input = h("input", { placeholder: "Paste a save key or link", "aria-label": "Save key" });
  return h("div", {},
    hasKey ? h("p", {}, "Your save key does the same without Google: a private link that signs any browser in as you. Keep it like a password: anyone with it can play as you.") : null,
    hasKey ? h("div.dq-actions", {},
      h("button.btn.btn-small.btn-ghost", { type: "button", onclick: () => { shown.hidden = !shown.hidden; } }, "Show my save key"),
      h("button.btn.btn-small.btn-ghost", { type: "button", onclick: async () => { await copyText(link); status.textContent = "Save key link copied. Open it on your other device."; } }, "Copy it")) : null,
    hasKey ? shown : null,
    h("form.dq-inline", {
      onsubmit: async (e) => {
        e.preventDefault();
        const m = /([a-z0-9]{6,16}\.[\w-]{20,})/.exec(input.value);
        if (!m) {
          status.textContent = "That doesn't look like a save key.";
          return;
        }
        if (!confirm("Play as the player in that save key? This browser's current player stays on the server; keep its key if you want it back.")) return;
        try {
          await useKey(m[1]);
          render("Switched to that player.");
        } catch (err) {
          status.textContent = err.message;
        }
      },
    }, h("label", {}, "Have a key from another device?", input), h("button.btn.btn-small", { type: "submit" }, "Use it")));
}

function gamesBlock(saves) {
  return h("div.dq-games", {}, ORDER.map((key) => {
    const def = GAMES[key];
    const s = saves[key] || { count: 0, total: def.levels.length, cleared: [], complete: false };
    return h("article.dq-game-card", { style: { "--accent": def.accent } },
      h("header", {}, h("h3", {}, h("a", { href: def.page }, def.name)), h("span.dq-lang", {}, def.lang)),
      h("div.dq-bar", {}, h("span", { style: { width: `${Math.round((100 * s.count) / s.total)}%` } })),
      h("p.dq-count", {}, `${s.count} of ${s.total} ${def.unit[1]}${s.count && bestLine(key, s) ? ` · ${bestLine(key, s)}` : ""}`),
      h("a.dq-play-link", { href: def.play }, s.complete ? "Play again" : s.count ? "Keep playing" : "Play"));
  }));
}

function certsBlock(certs) {
  if (!certs.length) return h("p", {}, "Finish a game to earn its certificate, with your name on it, ready for LinkedIn.");
  return h("div.dq-feed", {}, certs.map((c) => {
    const def = GAMES[c.game];
    const url = `${location.origin}/c/${c.id}`;
    return h("div", {},
      h("a", { href: `/c/${c.id}` }, h("img", { src: `/c/${c.id}.png`, alt: `${def.name} certificate`, width: 600, height: 315, loading: "lazy" })),
      h("p", { style: { margin: "6px 0" } }, h("a", { href: `/c/${c.id}` }, def.name)),
      h("a.dq-share-btn", { href: linkedInCertUrl({ name: `${def.name}: ${def.lang}`, issued: c.issued, url, id: c.id }), target: "_blank", rel: "noopener", html: `${icon("linkedin")}<span>Add to LinkedIn</span>` }));
  }));
}

function shotsBlock(shots) {
  if (!shots.length) return h("p", {}, "Press the camera in the corner of any game (or F9) to frame a screenshot with a caption and share it.");
  return h("div.dq-shots", {}, shots.map((s) => h("figure", {},
    h("a", { href: s.url }, h("img", { src: s.image, alt: s.caption || "Screenshot", loading: "lazy" })),
    h("figcaption", {}, h("span", {}, s.caption || GAMES[s.game].name),
      h("button", {
        type: "button",
        onclick: async (e) => {
          if (!confirm("Delete this screenshot? Its link will stop working.")) return;
          await api("DELETE", `/api/shots/${s.id}`);
          e.target.closest("figure").remove();
        },
      }, "Delete")))));
}

async function render(message = "") {
  root.replaceChildren(h("p.dq-fine", {}, "Loading…"));
  let data;
  try {
    data = await me();
  } catch (err) {
    root.replaceChildren(h("p", {}, err.message));
    return;
  }
  const status = h("p.dq-status", { role: "status" }, message);
  if (!data) {
    root.replaceChildren(
      status,
      section("Not playing yet",
        h("p", {}, "You don't have a player on this browser yet. One is made for you, with a silly name, the first time you clear a level in any game. Nothing to sign up for."),
        h("div.dq-actions", {}, h("a.btn", { href: "/curb/play/" }, "Play Curb Your Oxidation"), h("a.btn.btn-ghost", { href: "/" }, "All games"))),
      section("Already playing somewhere else?", signInBlock(null, status), keyBlock(status, false)),
    );
    return;
  }
  const { player, saves, certificates, shots } = data;
  // Not signed in, the sign-in and save key come first: it's the one thing
  // that can lose a player's progress. Signed in, it's a setting at the end.
  const keep = section(player.google ? "Your devices" : "Keep your progress", signInBlock(player, status), keyBlock(status));
  if (!player.google) keep.classList.add("dq-card", "dq-keep");
  root.replaceChildren(...[
    h("div.dq-me-head", {}, h("span", { html: avatarSvg(player.id, 64) }),
      h("div", {}, h("h1", {}, player.name),
        h("p.dq-stats", {}, h("b", {}, player.xp.toLocaleString()), " XP · ", h("b", {}, String(player.levels)), " levels · ",
          h("b", {}, String(player.completed)), ` ${player.completed === 1 ? "game" : "games"} finished`))),
    h("p.dq-fine", {}, "Only you see this page. Others see ", h("a", { href: `/u/${player.id}` }, "your public profile"),
      ": your name, progress and certificates."),
    status,
    player.google ? null : keep,
    section("Your games", gamesBlock(saves)),
    section("Certificates", certsBlock(certificates)),
    section("Screenshots", shotsBlock(shots)),
    section("Your name", nameForm(player, status)),
    player.google ? keep : null,
    section("Delete your player",
      h("p", {}, plural(player.levels, ["level", "levels"]) + " and everything else here can go. Your progress stays in each game on this browser either way."),
      h("div.dq-actions", {},
        h("button.btn.btn-small.btn-ghost.dq-danger", {
          type: "button",
          onclick: async () => {
            if (!confirm("Delete your player, scores, certificates and screenshots from Dunder Quest? This can't be undone.")) return;
            await deleteAccount();
            render("Deleted. Everything's gone from the server.");
          },
        }, "Delete everything"))),
  ].filter(Boolean));
}

fromHash().then((msg) => render(msg || ""));
