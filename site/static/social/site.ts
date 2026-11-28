// The social layer on the site's own pages: share buttons, the bits only a
// page's owner sees (rename a certificate, delete a screenshot), you in the
// site bar, and the /me/, /leaderboards/ and /feedback/ pages, which load their own
// modules.

import { avatarSvg } from "./avatar.ts";
import { api, cachedPlayer, onPlayer, type Player } from "./client.ts";
import { h, wireShareRows } from "./ui.ts";

wireShareRows();

// You, in the site bar: your avatar and name, linking to /me/. Only once
// there's a player; before that nobody needs reminding they haven't got one.
const bar = document.querySelector("header.bar");
let you: HTMLAnchorElement | null = null;
function showYou(player: Player | null): void {
  if (!bar) return;
  if (!player) {
    you?.remove();
    you = null;
    return;
  }
  if (!you) {
    you = h("a.dq-you", { href: "/me/" });
    bar.querySelector(":scope > .btn") ? bar.querySelector(":scope > .btn")!.before(you) : bar.append(you);
  }
  if (location.pathname === "/me/") you.setAttribute("aria-current", "page");
  you.title = `${player.name}: your progress`;
  you.setAttribute("aria-label", `You: ${player.name}. Your progress`);
  you.innerHTML = `${avatarSvg(player.id, 24)}<span class="dq-you-name"></span>`;
  you.querySelector(".dq-you-name")!.textContent = player.name;
}
showYou(cachedPlayer());
onPlayer(showYou);

// Owner-only controls on a certificate, profile or screenshot page.
const owner = document.body.dataset.owner;
const me = cachedPlayer();
if (owner && me && me.id === owner) {
  for (const el of document.querySelectorAll<HTMLElement>(".dq-owner")) el.hidden = false;
}

const rename = document.querySelector<HTMLFormElement>("form.dq-rename");
rename?.addEventListener("submit", async (e) => {
  e.preventDefault();
  const status = rename.querySelector(".dq-status")!;
  try {
    await api("PATCH", `/api/certificates/${rename.dataset.cert}`, { name: (rename.elements.namedItem("name") as HTMLInputElement).value });
    status.textContent = "Saved. Reloading…";
    location.reload();
  } catch (err) {
    status.textContent = (err as Error).message;
  }
});

document.querySelector("[data-dq-delete-shot]")?.addEventListener("click", async (e) => {
  if (!confirm("Delete this screenshot? Its link will stop working.")) return;
  try {
    await api("DELETE", `/api/shots/${(e.currentTarget as HTMLElement).dataset.dqDeleteShot}`);
    location.href = "/me/";
  } catch (err) {
    alert((err as Error).message);
  }
});

document.querySelector("[data-dq-print]")?.addEventListener("click", () => print());

if (document.getElementById("dq-me")) import("./me.ts");
const feedbackRoot = document.getElementById("dq-feedback");
if (feedbackRoot) {
  import("./feedback.ts").then(({ feedbackForm }) => {
    feedbackForm(feedbackRoot, { game: new URLSearchParams(location.search).get("game") || "", kind: "idea" });
  });
}
if (document.getElementById("dq-boards") || document.getElementById("dq-mini-board")) import("./boards.ts");
if (document.querySelector("[data-dq-resume]")) import("./resume.ts");
