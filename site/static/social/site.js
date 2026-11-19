// The social layer on the site's own pages: share buttons, the bits only a
// page's owner sees (rename a certificate, delete a screenshot), the
// "Your profile" link, and the /me/ and /leaderboards/ pages, which load
// their own modules.

import { api, cachedPlayer, onPlayer } from "./client.js";
import { wireShareRows } from "./ui.js";

wireShareRows();

function profileLinks(player) {
  for (const a of document.querySelectorAll("a[data-dq-me]")) {
    a.href = player ? `/u/${player.id}` : "/me/";
  }
}
profileLinks(cachedPlayer());
onPlayer(profileLinks);

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
