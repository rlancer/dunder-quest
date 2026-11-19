// The leaderboards page (/leaderboards/): every game's board and the
// overall one, in tabs, plus the latest certificates. The home page's small
// board (#dq-mini-board) is the overall top five.

import { avatarSvg } from "./avatar.js";
import { GAMES, ORDER } from "./games.js";
import { api, cachedPlayer } from "./client.js";
import { h } from "./ui.js";

function rows(board, me) {
  return h("ol.dq-board", {}, board.rows.map((r) => h(`li${me && r.id === me.id ? ".dq-me" : ""}`, {},
    h("span.dq-rank", {}, `#${r.rank}`),
    h("a.dq-name", { href: `/u/${r.id}` }, h("span", { html: avatarSvg(r.id, 18) }), r.name),
    h("span.dq-progress", { title: `${r.count} of ${r.total} levels` }, board.game === "all" ? `${r.xp.toLocaleString()} XP` : `${r.count}/${r.total}`),
    h("span.dq-line", {}, board.game === "all" ? `${r.count}/${r.total}` : `${r.complete ? "★ " : ""}${r.line}`))));
}

async function renderBoard(panel, game) {
  panel.replaceChildren(h("p.dq-fine", {}, "Loading…"));
  try {
    const board = await api("GET", `/api/leaderboard?game=${game}&limit=50`);
    const me = cachedPlayer();
    const def = GAMES[game];
    const how = game === "all"
      ? "Ranked by XP: 100 a level, 400 for finishing a game, 10 a collectible."
      : `Ranked by ${def.unit[1]} cleared, then ${def.best === "tries" ? "fewest tries" : "fastest total time"}.`;
    const kids = [h("div.dq-board-head", {}, h("span", {}, how), h("span", {}, `${board.players} ${board.players === 1 ? "player" : "players"}`))];
    if (!board.rows.length) {
      kids.push(h("p", { style: { padding: "0 10px" } }, "Nobody here yet. ", h("a", { href: game === "all" ? "/" : def.play }, "Play"), " and it's yours."));
    } else {
      kids.push(rows(board, me));
    }
    if (board.me && !board.rows.some((r) => r.id === board.me.id)) {
      kids.push(h("p.dq-mine", { style: { padding: "0 10px" } }, `You: #${board.me.rank} of ${board.players}.`));
    }
    if (game !== "all") kids.push(h("p", { style: { padding: "0 10px" } }, h("a.btn.btn-small", { href: def.play }, `Play ${def.name}`)));
    panel.replaceChildren(...kids);
  } catch (err) {
    panel.replaceChildren(h("p", {}, err.message));
  }
}

const page = document.getElementById("dq-boards");
if (page) {
  const keys = ["all", ...ORDER];
  const label = (k) => (k === "all" ? "Overall" : GAMES[k].name);
  const panel = h("div.dq-board-panel", { role: "tabpanel", id: "dq-board-panel" });
  const tabs = h("div.dq-tabs", { role: "tablist" }, keys.map((k) => h("button", {
    type: "button", role: "tab", "data-game": k, "aria-controls": "dq-board-panel",
    onclick: () => {
      history.replaceState(null, "", k === "all" ? location.pathname : `#${k}`);
      select(k);
    },
  }, label(k))));
  function select(k) {
    for (const b of tabs.children) b.setAttribute("aria-selected", String(b.dataset.game === k));
    renderBoard(panel, k);
  }
  page.replaceChildren(tabs, panel);
  const start = location.hash.slice(1);
  select(keys.includes(start) ? start : "all");

  const feed = document.getElementById("dq-feed");
  if (feed) {
    api("GET", "/api/feed").then(({ certificates }) => {
      if (!certificates.length) {
        feed.replaceChildren(h("p.dq-fine", {}, "No certificates yet. Finish a game to be the first."));
        return;
      }
      feed.replaceChildren(...certificates.map((c) => h("a", { href: `/c/${c.id}` },
        h("img", { src: `/c/${c.id}.png`, alt: `${c.name}'s ${GAMES[c.game].name} certificate`, width: 600, height: 315, loading: "lazy" }),
        `${c.name} · ${GAMES[c.game].name}`)));
    }).catch(() => feed.replaceChildren());
  }
}

const mini = document.getElementById("dq-mini-board");
if (mini) {
  api("GET", "/api/leaderboard?game=all&limit=5").then((board) => {
    if (!board.rows.length) {
      mini.replaceChildren(h("p", {}, "The board is empty. Clear a level in any game and you're on it."));
      return;
    }
    mini.replaceChildren(rows(board, cachedPlayer()));
  }).catch(() => mini.replaceChildren());
}
