// What the Feedback page and its server functions share (src/server/feedback.server.ts).

export const SITES = ["live", "dev"] as const;
export type Site = (typeof SITES)[number];
export const STATUSES = ["new", "done", "spam", "all"] as const;
export type Tab = (typeof STATUSES)[number];

export type FeedbackItem = {
  id: string;
  game: string;
  gameName: string;
  kind: string;
  kindLabel: string;
  rating: number | null;
  message: string;
  contact: string;
  page: string;
  context: string;
  browser: string;
  playerId: string | null;
  playerName: string | null;
  /** Seconds since 1970, as the site Worker keeps it. */
  createdAt: number;
  status: string;
};

export type Inbox = {
  /** False when the database has no feedback table yet (a fresh local DB, or nothing deployed). */
  ready: boolean;
  counts: { new: number; done: number; spam: number; all: number; week: number; openBugs: number };
  rating: { average: number | null; rated: number };
  items: FeedbackItem[];
  games: { key: string; name: string }[];
  kinds: { key: string; label: string }[];
};

