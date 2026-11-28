import { env } from "cloudflare:workers";
import { FEEDBACK_KINDS, GAMES } from "../../../site/static/social/games.js";

/**
 * The feedback inbox. Players send feedback to the site's Worker
 * (deploy/src/api.ts, POST /api/feedback), which keeps it in the social D1
 * databases, not this app's own: SOCIAL_DB is the live site's,
 * SOCIAL_DB_DEV dev.dunderquest.com's. Only this page reads it.
 */

import type { FeedbackItem, Inbox, Site, Tab } from "../feedback";

/** Spam is kept this long, so a mistake can be undone, then deleted. */
const SPAM_DAYS = 30;

function db(site: Site): D1Database | undefined {
  return site === "dev" ? env.SOCIAL_DB_DEV : env.SOCIAL_DB;
}

const GAME_LIST = Object.entries(GAMES as Record<string, { name: string }>).map(([key, g]) => ({ key, name: g.name }));
const KIND_LIST = Object.entries(FEEDBACK_KINDS as Record<string, string>).map(([key, label]) => ({ key, label }));

const empty = (): Inbox => ({
  ready: false,
  counts: { new: 0, done: 0, spam: 0, all: 0, week: 0, openBugs: 0 },
  rating: { average: null, rated: 0 },
  items: [],
  games: GAME_LIST,
  kinds: KIND_LIST,
});

async function hasTable(d: D1Database): Promise<boolean> {
  const row = await d.prepare("SELECT 1 AS ok FROM sqlite_master WHERE type = 'table' AND name = 'feedback'").first<{ ok: number }>();
  return Boolean(row);
}

/** "Chrome 141, Windows" from a user-agent string: the browser's name, not the whole string. */
export function browserName(agent: string): string {
  if (!agent) return "Unknown";
  const pick = (re: RegExp) => agent.match(re)?.[1];
  const browser =
    (pick(/Edg(?:e|A|iOS)?\/(\d+)/) && `Edge ${pick(/Edg(?:e|A|iOS)?\/(\d+)/)}`) ||
    (pick(/OPR\/(\d+)/) && `Opera ${pick(/OPR\/(\d+)/)}`) ||
    (pick(/SamsungBrowser\/(\d+)/) && `Samsung Internet ${pick(/SamsungBrowser\/(\d+)/)}`) ||
    (pick(/(?:Firefox|FxiOS)\/(\d+)/) && `Firefox ${pick(/(?:Firefox|FxiOS)\/(\d+)/)}`) ||
    (pick(/(?:Chrome|CriOS)\/(\d+)/) && `Chrome ${pick(/(?:Chrome|CriOS)\/(\d+)/)}`) ||
    (pick(/Version\/(\d+)[\d.]* .*Safari/) && `Safari ${pick(/Version\/(\d+)[\d.]* .*Safari/)}`) ||
    agent.split(/[\s/]/)[0];
  const os = /iPhone/.test(agent) ? "iPhone"
    : /iPad/.test(agent) ? "iPad"
    : /Android/.test(agent) ? "Android"
    : /Windows/.test(agent) ? "Windows"
    : /CrOS/.test(agent) ? "ChromeOS"
    : /Mac OS X|Macintosh/.test(agent) ? "macOS"
    : /Linux/.test(agent) ? "Linux"
    : "";
  return os ? `${browser}, ${os}` : browser;
}

type Row = {
  id: string; game: string; kind: string; rating: number | null; message: string; contact: string; page: string;
  context: string; agent: string; player_id: string | null; player_name: string | null; created_at: number; status: string;
};

export async function inbox(site: Site, tab: Tab, game: string, kind: string): Promise<Inbox> {
  const d = db(site);
  if (!d || !(await hasTable(d))) return empty();
  // The site Worker keeps times in seconds.
  const now = Math.floor(Date.now() / 1000);
  // Old spam goes when the inbox is opened: there's no cron to do it.
  await d.prepare("DELETE FROM feedback WHERE status = 'spam' AND created_at < ?").bind(now - SPAM_DAYS * 86_400).run();

  const counts = await d.prepare(
    `SELECT
       SUM(status = 'new') AS new, SUM(status = 'done') AS done, SUM(status = 'spam') AS spam,
       SUM(status != 'spam') AS "all", SUM(status != 'spam' AND created_at >= ?) AS week,
       SUM(status = 'new' AND kind = 'bug') AS openBugs,
       AVG(CASE WHEN status != 'spam' THEN rating END) AS average,
       SUM(status != 'spam' AND rating IS NOT NULL) AS rated
     FROM feedback`,
  ).bind(now - 7 * 86_400).first<Record<string, number | null>>();

  const where: string[] = [];
  const params: unknown[] = [];
  if (tab === "all") where.push("f.status != 'spam'");
  else {
    where.push("f.status = ?");
    params.push(tab);
  }
  if (game === "site") where.push("f.game = ''");
  else if (game) {
    where.push("f.game = ?");
    params.push(game);
  }
  if (kind) {
    where.push("f.kind = ?");
    params.push(kind);
  }
  // The players table is the site Worker's too; it's there whenever feedback is.
  const { results } = await d.prepare(
    `SELECT f.*, p.name AS player_name FROM feedback f LEFT JOIN players p ON p.id = f.player_id
     WHERE ${where.join(" AND ")} ORDER BY f.created_at DESC LIMIT 200`,
  ).bind(...params).all<Row>();

  const games = GAMES as Record<string, { name: string }>;
  const kinds = FEEDBACK_KINDS as Record<string, string>;
  const n = (v: number | null | undefined) => Number(v ?? 0);
  return {
    ready: true,
    counts: {
      new: n(counts?.new), done: n(counts?.done), spam: n(counts?.spam), all: n(counts?.all),
      week: n(counts?.week), openBugs: n(counts?.openBugs),
    },
    rating: { average: counts?.average == null ? null : Number(counts.average), rated: n(counts?.rated) },
    items: results.map((r) => ({
      id: r.id,
      game: r.game,
      gameName: r.game ? games[r.game]?.name ?? r.game : "The site",
      kind: r.kind,
      kindLabel: kinds[r.kind] ?? r.kind,
      rating: r.rating,
      message: r.message,
      contact: r.contact,
      page: r.page,
      context: r.context,
      browser: browserName(r.agent),
      playerId: r.player_id,
      playerName: r.player_name,
      createdAt: r.created_at,
      status: r.status,
    })),
    games: GAME_LIST,
    kinds: KIND_LIST,
  };
}

/** How many are waiting on the live site, for the nav. 0 when there's no table yet. */
export async function newCount(): Promise<number> {
  const d = db("live");
  if (!d || !(await hasTable(d))) return 0;
  const row = await d.prepare("SELECT COUNT(*) AS n FROM feedback WHERE status = 'new'").first<{ n: number }>();
  return row?.n ?? 0;
}

export async function setStatus(site: Site, id: string, status: "new" | "done" | "spam"): Promise<void> {
  const d = db(site);
  if (!d || !(await hasTable(d))) return;
  await d.prepare("UPDATE feedback SET status = ? WHERE id = ?").bind(status, id).run();
}
