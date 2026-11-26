// The images link previews show: a game's certificate of completion, and a
// player's profile card. Both are drawn on a 600x315 grid and saved at 2x,
// the 1200x630 that Facebook, LinkedIn, X and Bluesky all ask for.

import { GAMES, ORDER, XP, formatTime } from "../../site/static/social/games.js";
import { Pixels } from "./png";

type Game = keyof typeof GAMES;

/** Each game's certificate colors, from its own page's palette. */
const THEMES: Record<Game, { bg: string; panel: string; ink: string; title: string; muted: string; accent: string; seal: string; sealInk: string }> = {
  curb: { bg: "#fad41c", panel: "#000000", ink: "#ffffff", title: "#fad41c", muted: "#a8a8a8", accent: "#fad41c", seal: "#fad41c", sealInk: "#000000" },
  "dunder-quest": { bg: "#15122a", panel: "#f4e4c4", ink: "#232849", title: "#232849", muted: "#6b5f88", accent: "#f2b544", seal: "#ff8a3d", sealInk: "#15122a" },
  flatmates: { bg: "#17161f", panel: "#f5ebd6", ink: "#17161f", title: "#17161f", muted: "#6b6a80", accent: "#f7de1f", seal: "#fa6b61", sealInk: "#17161f" },
  prince: { bg: "#171c33", panel: "#f5ebcc", ink: "#120d1a", title: "#242b4a", muted: "#6e6a80", accent: "#e9b949", seal: "#6ec8cc", sealInk: "#120d1a" },
  lieutenant: { bg: "#211a20", panel: "#f5edd6", ink: "#17120f", title: "#2a2019", muted: "#7a6a58", accent: "#f08033", seal: "#99bbdb", sealInk: "#17120f" },
  greedy: { bg: "#3b1f4a", panel: "#ecd9a6", ink: "#2a1710", title: "#2a1710", muted: "#7a5f45", accent: "#e8a13a", seal: "#a3271c", sealInk: "#ecd9a6" },
};

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

export function longDate(seconds: number): string {
  const d = new Date(seconds * 1000);
  return `${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

/** A pixel star, drawn from rows so it reads at any size. */
function star(p: Pixels, cx: number, cy: number, hex: string): void {
  const rows = ["....#....", "....#....", "...###...", "#########", ".#######.", "..#####..", "..##.##..", ".##...##.", ".#.....#."];
  rows.forEach((row, y) => [...row].forEach((c, x) => c === "#" && p.dot(cx - 4 + x, cy - 4 + y, hex)));
}

/** The corner flourish: a stepped L with a jewel in it. */
function corner(p: Pixels, x: number, y: number, dx: number, dy: number, hex: string, jewel: string): void {
  for (let i = 0; i < 14; i++) {
    p.dot(x + dx * i, y, hex);
    p.dot(x + dx * i, y + dy, hex);
    p.dot(x, y + dy * i, hex);
    p.dot(x + dx, y + dy * i, hex);
  }
  p.rect(Math.min(x + dx * 4, x + dx * 6), Math.min(y + dy * 4, y + dy * 6), 3, 3, jewel);
}

/** Bump when the certificate's design changes, so images cached in D1 are drawn again. */
export const CERT_DESIGN = 2;

export type CertData = { id: string; game: string; name: string; issued: number; stats: { levels: number; time: number; tries: number; collected: number; collectMax: number } };

export async function certificatePng(cert: CertData, host: string): Promise<Uint8Array> {
  const game = cert.game as Game;
  const def = GAMES[game];
  const t = THEMES[game];
  const p = new Pixels(600, 315, t.bg);
  const W = 600;
  // The panel, its double rule and its corners.
  p.rect(12, 12, W - 24, 291, t.panel);
  p.frame(18, 18, W - 36, 279, 2, t.accent);
  p.frame(23, 23, W - 46, 269, 1, t.accent);
  corner(p, 28, 28, 1, 1, t.accent, t.seal);
  corner(p, W - 29, 28, -1, 1, t.accent, t.seal);
  corner(p, 28, 286, 1, -1, t.accent, t.seal);
  corner(p, W - 29, 286, -1, -1, t.accent, t.seal);

  p.text("DUNDER QUEST", W / 2, 34, t.muted, 1, "center");
  p.text("Certificate of Completion", W / 2, 50, t.title, p.fit("Certificate of Completion", 470, 3), "center");
  p.text("This certifies that", W / 2, 100, t.muted, 1, "center");
  const nameScale = p.fit(cert.name, 440, 4);
  const nameY = 116 + (4 - nameScale) * 6;
  p.text(cert.name, W / 2, nameY, t.ink, nameScale, "center");
  p.rect(W / 2 - 170, 174, 340, 1, t.accent);
  const unit = def.unit[1];
  // In words: at this size the pixel font's 5 reads as an S.
  const words = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"];
  const n = def.levels.length;
  p.text(`finished all ${words[n] || n} ${unit} of`, W / 2, 180, t.muted, 1, "center");
  p.text(def.name, W / 2, 196, t.title, p.fit(def.name, 440, 2), "center");
  const facts: string[] = [`learning ${def.lang}`];
  const s = cert.stats;
  if (def.best === "tries" && s.tries) facts.push(`${s.tries} tries`);
  if (def.best === "time" && s.time) facts.push(`total time ${formatTime(s.time)}`);
  if (def.collectible && s.collectMax) facts.push(`${s.collected}/${s.collectMax} ${def.collectible[1]}`);
  p.text(facts.join("  •  "), W / 2, 230, t.ink, 1, "center");

  // Date on the left, the address on the right, the seal between.
  p.text(longDate(cert.issued), 46, 266, t.ink, 1, "left");
  p.rect(46, 282, 150, 1, t.muted);
  p.text(`${host}/c/${cert.id}`, W - 46, 266, t.ink, 1, "right");
  p.rect(W - 196, 282, 150, 1, t.muted);
  p.disc(W / 2, 272, 19, t.accent);
  p.disc(W / 2, 272, 16, t.seal);
  star(p, W / 2, 272, t.sealInk);
  return p.png(2);
}

export type CardPlayer = { name: string; xp: number; levels: number; completed: number };
export type CardGame = { game: string; count: number; total: number; complete: boolean };

/** A player's progress in every game, as bars, with their XP. */
export async function profilePng(player: CardPlayer, games: CardGame[], host: string): Promise<Uint8Array> {
  const p = new Pixels(600, 315, "#15122a");
  p.rect(10, 10, 580, 295, "#232849");
  p.frame(14, 14, 572, 287, 2, "#4a4f86");
  p.text("DUNDER QUEST  •  PLAYER", 32, 28, "#b0a9d0", 1);
  p.text(player.name, 32, 48, "#f4e4c4", p.fit(player.name, 536, 4));
  const total = ORDER.reduce((n, g) => n + GAMES[g as Game].levels.length, 0);
  const line = `${player.xp.toLocaleString("en-US")} XP  •  ${player.levels} of ${total} levels  •  ${player.completed} ${player.completed === 1 ? "game" : "games"} finished`;
  p.text(line, 32, 106, "#f2b544", p.fit(line, 536, 2));
  // One row per game, closer together as games are added, clear of the address line at 276.
  const step = Math.min(24, Math.floor(126 / ORDER.length));
  let y = 140;
  for (const key of ORDER) {
    const def = GAMES[key as Game];
    const g = games.find((x) => x.game === key) ?? { game: key, count: 0, total: def.levels.length, complete: false };
    p.text(p.measure(def.name, 1) > 160 ? def.short : def.name, 32, y, "#f4e4c4", 1);
    p.text(def.lang, 200, y, "#b0a9d0", 1);
    const bx = 270;
    const bw = 230;
    p.rect(bx, y + 3, bw, 10, "#15122a");
    if (g.count) p.rect(bx, y + 3, Math.max(4, Math.round((bw * g.count) / g.total)), 10, g.complete ? "#7be08a" : def.accent);
    if (g.complete) star(p, 518, y + 8, "#7be08a");
    p.text(g.complete ? "done" : `${g.count}/${g.total}`, g.complete ? 528 : 512, y, g.complete ? "#7be08a" : "#b0a9d0", 1);
    y += step;
  }
  p.text(`${host}  •  free games that teach you to code`, 300, 276, "#b0a9d0", 1, "center");
  return p.png(2);
}

export { XP };
