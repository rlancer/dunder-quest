// The social layer on the site's own pages: share buttons, the bits only a
// page's owner sees (rename a certificate, delete a screenshot), you in the
// site bar, and the /me/ and /leaderboards/ pages, which load their own
// modules.

import { avatarSvg } from "./avatar.js";
import { api, cachedPlayer, onPlayer } from "./client.js";
import { h, wireShareRows } from "./ui.js";

wireShareRows();

// You, in the site bar: your avatar and name, linking to /me/. Only once
// there's a player; before that nobody needs reminding they haven't got one.
const bar = document.querySelector("header.bar");
let you = null;
function showYou(player) {
  if (!bar) return;
  if (!player) {
    you?.remove();
    you = null;
    return;
  }
  if (!you) {
    you = h("a.dq-you", { href: "/me/" });
    bar.querySelector(":scope > .btn") ? bar.querySelector(":scope > .btn").before(you) : bar.append(you);
  }
  if (location.pathname === "/me/") you.setAttribute("aria-current", "page");
  you.title = `${player.name}: your progress`;
  you.setAttribute("aria-label", `You: ${player.name}. Your progress`);
  you.innerHTML = `${avatarSvg(player.id, 24)}<span class="dq-you-name"></span>`;
  you.querySelector(".dq-you-name").textContent = player.name;
}
showYou(cachedPlayer());
onPlayer(showYou);

// Owner-only controls on a certificate, profile or screenshot page.
const owner = document.body.dataset.owner;
const me = cachedPlayer();
if (owner && me && me.id === owner) {
  for (const el of document.querySelectorAll(".dq-owner")) el.hidden = false;
}

const rename = document.querySelector("form.dq-rename");
rename?.addEventListener("submit", async (e) => {
  e.preventDefault();
  const status = rename.querySelector(".dq-status");
  try {
    await api("PATCH", `/api/certificates/${rename.dataset.cert}`, { name: rename.elements.name.value });
    status.textContent = "Saved. Reloading…";
    location.reload();
  } catch (err) {
    status.textContent = err.message;
  }
});

document.querySelector("[data-dq-delete-shot]")?.addEventListener("click", async (e) => {
  if (!confirm("Delete this screenshot? Its link will stop working.")) return;
  try {
    await api("DELETE", `/api/shots/${e.currentTarget.dataset.dqDeleteShot}`);
    location.href = "/me/";
  } catch (err) {
    alert(err.message);
  }
});

document.querySelector("[data-dq-print]")?.addEventListener("click", () => print());

if (document.getElementById("dq-me")) import("./me.js");
if (document.getElementById("dq-boards") || document.getElementById("dq-mini-board")) import("./boards.js");
