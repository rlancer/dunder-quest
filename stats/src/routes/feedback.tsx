import { useQueryClient, useSuspenseQuery } from "@tanstack/react-query";
import { Link, createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Stat } from "../components/Stat";
import { FeedbackSearch, type FeedbackFilters, inboxQuery, markFeedback } from "../data";
import type { FeedbackItem } from "../feedback";

// Rob's inbox for what players send from the speech bubble in every game and
// from /feedback/. It's private: players never see each other's feedback.
export const Route = createFileRoute("/feedback")({
  validateSearch: FeedbackSearch,
  loaderDeps: ({ search }) => ({ site: search.site, tab: search.tab, game: search.game, kind: search.kind }),
  loader: ({ context, deps }) => context.queryClient.ensureQueryData(inboxQuery(deps)),
  component: Feedback,
});

/** The short label on a card's badge, and its class (colors in styles.css). */
const BADGE: Record<string, string> = { bug: "Broken", stuck: "Stuck", idea: "Idea", praise: "Liked", other: "Other" };

function when(seconds: number): string {
  const ago = Date.now() / 1000 - seconds;
  if (ago < 90) return "Just now";
  if (ago < 3600) return `${Math.round(ago / 60)} minutes ago`;
  if (ago < 7200) return "1 hour ago";
  if (ago < 86_400) return `${Math.round(ago / 3600)} hours ago`;
  if (ago < 2 * 86_400) return "Yesterday";
  if (ago < 7 * 86_400) return `${Math.floor(ago / 86_400)} days ago`;
  return new Date(seconds * 1000).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

function Feedback() {
  const filters = Route.useSearch();
  const { data } = useSuspenseQuery(inboxQuery(filters));
  const navigate = Route.useNavigate();
  const set = (patch: Partial<FeedbackFilters>) => navigate({ search: (s) => ({ ...s, ...patch }) });
  const tabs: [FeedbackFilters["tab"], string][] = [
    ["new", `New (${data.counts.new})`],
    ["done", "Done"],
    ["spam", `Spam (${data.counts.spam})`],
    ["all", "All"],
  ];

  return (
    <div className="fb">
      <div className="title-row">
        <h1>Feedback</h1>
        <div className="range" role="group" aria-label="Which site">
          <Link to="." search={(s) => ({ ...s, site: "live" })} className={filters.site === "live" ? "active" : ""} aria-pressed={filters.site === "live"}>
            Live site
          </Link>
          <Link to="." search={(s) => ({ ...s, site: "dev" })} className={filters.site === "dev" ? "active" : ""} aria-pressed={filters.site === "dev"}>
            dev.dunderquest.com
          </Link>
        </div>
      </div>

      {!data.ready ? (
        <p className="empty">
          No feedback table in this database yet. The site's Worker makes it the first time anyone sends feedback, or this
          app isn't bound to that database (SOCIAL_DB, SOCIAL_DB_DEV in wrangler.jsonc).
        </p>
      ) : (
        <>
          <div className="stats fb-stats">
            <Stat label="New" value={data.counts.new} />
            <Stat label="This week" value={data.counts.week} />
            <Stat label="Open bugs" value={data.counts.openBugs} />
            <Stat
              label="Average rating"
              value={data.rating.average == null ? "—" : data.rating.average.toFixed(1)}
              note={data.rating.rated ? `of 5, ${data.rating.rated} rated` : "nobody's rated it yet"}
            />
          </div>

          <div className="fb-filters">
            <div role="tablist" aria-label="Status" className="fb-tabs">
              {tabs.map(([key, label]) => (
                <button key={key} type="button" role="tab" aria-selected={filters.tab === key} onClick={() => set({ tab: key })}>
                  {label}
                </button>
              ))}
            </div>
            <label className="fb-select">
              Game
              <select value={filters.game} onChange={(e) => set({ game: e.target.value })}>
                <option value="">All games</option>
                <option value="site">The site</option>
                {data.games.map((g) => (
                  <option key={g.key} value={g.key}>
                    {g.name}
                  </option>
                ))}
              </select>
            </label>
            <label className="fb-select">
              Kind
              <select value={filters.kind} onChange={(e) => set({ kind: e.target.value })}>
                <option value="">All kinds</option>
                {data.kinds.map((k) => (
                  <option key={k.key} value={k.key}>
                    {k.label}
                  </option>
                ))}
              </select>
            </label>
          </div>

          {data.items.length === 0 ? (
            <p className="empty">{filters.tab === "new" ? "Nothing new. Inbox zero." : "Nothing here."}</p>
          ) : (
            data.items.map((item) => <Card key={item.id} item={item} filters={filters} />)
          )}
        </>
      )}

      <p className="hint">Spam is kept for 30 days, then deleted. Feedback from a player who deletes their progress is deleted with it.</p>
    </div>
  );
}

function Card({ item, filters }: { item: FeedbackItem; filters: FeedbackFilters }) {
  const queryClient = useQueryClient();
  const [busy, setBusy] = useState(false);
  const mark = async (status: "new" | "done" | "spam") => {
    setBusy(true);
    try {
      await markFeedback({ data: { site: filters.site, id: item.id, status } });
      await queryClient.invalidateQueries({ queryKey: ["feedback"] });
      await queryClient.invalidateQueries({ queryKey: ["feedback-new"] });
    } finally {
      setBusy(false);
    }
  };
  const playerHost = filters.site === "dev" ? "https://dev.dunderquest.com" : "https://dunderquest.com";
  const subject = `Re: your feedback on ${item.gameName === "The site" ? "Dunder Quest" : item.gameName}`;
  const quoted = item.message.split("\n").map((l) => `> ${l}`).join("\n");
  const reply = `mailto:${encodeURIComponent(item.contact)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(`\n\n${quoted}`)}`;
  const looksLikeEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(item.contact);

  return (
    <article className={`fb-card${item.status === "done" ? " fb-done" : ""}`}>
      <div className="fb-head">
        <span className={`fb-kind fb-kind-${BADGE[item.kind] ? item.kind : "other"}`} title={item.kindLabel}>
          {BADGE[item.kind] ?? "Other"}
        </span>
        <b>{item.gameName}</b>
        <span className="fb-stars" aria-label={item.rating ? `${item.rating} out of 5` : "Not rated"}>
          {item.rating ? "★".repeat(item.rating) + "☆".repeat(5 - item.rating) : "Not rated"}
        </span>
        <span className="fb-when" title={new Date(item.createdAt * 1000).toISOString()}>
          {when(item.createdAt)}
        </span>
      </div>
      <p className="fb-message">{item.message}</p>
      <dl className="fb-meta">
        <div>
          <dt>Context</dt>
          <dd>{item.context || "none"}</dd>
        </div>
        <div>
          <dt>Page</dt>
          <dd>{item.page || "unknown"}</dd>
        </div>
        <div>
          <dt>From</dt>
          <dd>
            {item.playerId ? (
              <a href={`${playerHost}/u/${item.playerId}`} target="_blank" rel="noreferrer">
                {item.playerName ?? item.playerId}
              </a>
            ) : (
              "Guest"
            )}
          </dd>
        </div>
        <div>
          <dt>Browser</dt>
          <dd>{item.browser}</dd>
        </div>
      </dl>
      <div className="fb-actions">
        {item.contact ? (
          looksLikeEmail ? (
            <a className="fb-reply" href={reply}>
              Reply to {item.contact}
            </a>
          ) : (
            <span className="fb-contact">Left: {item.contact}</span>
          )
        ) : null}
        {item.status === "new" ? (
          <button type="button" disabled={busy} onClick={() => mark("done")}>
            Mark done
          </button>
        ) : (
          <button type="button" disabled={busy} onClick={() => mark("new")}>
            Move back to New
          </button>
        )}
        {item.status !== "spam" ? (
          <button type="button" disabled={busy} onClick={() => mark("spam")}>
            Spam
          </button>
        ) : null}
      </div>
    </article>
  );
}
