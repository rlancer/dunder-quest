// "Welcome back": the panel a returning player sees on the home page and on
// each game's page, where most visits land. It says who they are, where they
// left off and what's next, with one button to carry on. A visitor without a
// player sees nothing, so the pages stay as they are for newcomers.
//
// Markup: <div data-dq-resume="any|<game>" data-dq-btn="btn" hidden></div>.
// "any" (the home page) picks the game they played last; a game's own page
// talks about that game. data-dq-btn is the page's own button class, so the
// button matches the page's theme. The panel brings its own styles, since
// the game pages don't load social.css.

import { avatarSvg } from "./avatar.js";
import { GAMES, ORDER } from "./games.js";
import { api, me, token } from "./client.js";
import { h } from "./ui.js";

const STYLE = `
.dq-resume { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; margin: 18px 0 0; padding: 12px 14px;
  background: rgba(10, 8, 22, 0.62); border: 1px solid rgba(255, 255, 255, 0.18); border-radius: 12px;
  color: #f4e4c4; font: 16px/1.4 "Atkinson Hyperlegible", system-ui, sans-serif; max-width: 640px; }
.dq-resume[hidden] { display: none; }
.dq-resume .dq-avatar { width: 40px; height: 40px; flex: none; image-rendering: pixelated; }
.dq-resume-text { flex: 1 1 280px; margin: 0; }
.dq-resume-text b { color: inherit; }
.dq-resume-text small { display: block; margin-top: 2px; opacity: 0.8; font-size: 0.88rem; }
.dq-resume-text a { color: inherit; }
.dq-resume-go { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
`;

function styles() {
  if (document.getElementById("dq-resume-style")) return;
  document.head.append(h("style", { id: "dq-resume-style" }, STYLE));
}

/** The first level not cleared yet, or null when the game's finished. */
function nextLevel(key, s) {
  return GAMES[key].levels.find((l) => !(s?.cleared || []).includes(l.id)) || null;
}

/**
 * A game to try next: going round the site's order from the one after
 * `except` (as the certificate dialog does), the first not started, else
 * the first not finished.
 */
function suggestion(saves, except) {
  const from = ORDER.indexOf(except) + 1;
  const round = [...ORDER.slice(from), ...ORDER.slice(0, from)].filter((k) => k !== except);
  return round.find((k) => !saves[k]?.count) || round.find((k) => !saves[k]?.complete) || null;
}

function button(el, href, label) {
  return h(`a.${(el.dataset.dqBtn || "btn").split(" ").join(".")}`, { href }, label);
}

function render(el, data, rank) {
  const { player, saves, certificates } = data;
  const where = el.dataset.dqResume;
  const hello = h("b", {}, `Welcome back, ${player.name}.`);
  const standing = player.xp > 0
    ? h("small", {}, `${player.xp.toLocaleString()} XP${rank ? ` · #${rank.rank} of ${rank.players} overall` : ""} · `, h("a", { href: "/me/" }, "your progress"))
    : h("small", {}, h("a", { href: "/me/" }, "Your progress"));
  let line;
  const go = [];
  const key = where === "any"
    ? ORDER.filter((k) => saves[k]?.count && !saves[k].complete).sort((a, b) => (saves[b].played || 0) - (saves[a].played || 0))[0]
    : where;
  const def = GAMES[key];
  const s = key ? saves[key] : null;
  const next = suggestion(saves, key);
  if (def && s?.complete) {
    const cert = certificates.find((c) => c.game === key);
    line = cert
      ? [` You finished ${def.name}: `, h("a", { href: `/c/${cert.id}` }, "see your certificate"), "."]
      : ` You finished ${def.name}.`;
    if (next) go.push(button(el, GAMES[next].play, `Next: learn ${GAMES[next].lang} in ${GAMES[next].name}`));
  } else if (def && s?.count) {
    const lvl = nextLevel(key, s);
    line = ` ${s.count} of ${s.total} ${def.unit[1]} of ${def.name} cleared.${lvl ? ` Next up: ${lvl.name} (${lvl.lesson}).` : ""}`;
    go.push(button(el, def.play, where === "any" ? `Continue ${def.short}` : "Continue"));
  } else if (def) {
    // A game they haven't started, on its own page.
    line = ` Clear a ${def.unit[0]} here and it adds to your XP.`;
  } else if (next) {
    // The home page, with nothing in progress: point at a game to start.
    line = ` Ready for another? ${GAMES[next].name} teaches ${GAMES[next].lang}.`;
    go.push(button(el, GAMES[next].play, `Play ${GAMES[next].name}`));
  } else {
    line = " You've finished every game. Thank you for playing!";
  }
  el.replaceChildren(...[
    h("span", { html: avatarSvg(player.id, 40) }),
    h("p.dq-resume-text", {}, hello, line, standing),
    go.length ? h("div.dq-resume-go", {}, go) : null,
  ].filter(Boolean));
  el.classList.add("dq-resume");
  el.hidden = false;
}

const panels = document.querySelectorAll("[data-dq-resume]");
if (panels.length && token()) {
  styles();
  Promise.all([me(), api("GET", "/api/leaderboard?game=all&limit=1").catch(() => null)]).then(([data, board]) => {
    if (!data) return;
    // A rank cheers you on near the top; near the bottom it's just discouraging.
    const good = board?.me && (board.me.rank <= 10 || board.me.rank <= board.players / 2);
    const rank = good ? { rank: board.me.rank, players: board.players } : null;
    for (const el of panels) render(el, data, rank);
  }).catch(() => {});
}
