# Dunder Quest admin

The admin area at `dunderquest.com/admin`: anonymous play stats from the game, the feedback inbox, and the dev notes (debug shortcuts, the save file, test scenes, builds). Only the owner can open it. The brand kit (logo, colors, trailer and social cards) is public, at `dunderquest.com/brand/`.

- **Game side:** `common/telemetry.gd` queues events (stage start, clear, quit, deaths, scrolls read, duel answers and hints) and posts them in batches to `/api/events`. A player is a random install id and nothing else. Players can switch stats off on the title screen. Only exported release builds report; editor and debug runs stay quiet unless `EMBER_TELEMETRY_URL` is set.
- **Server side:** one Cloudflare Worker, built with TanStack Start (Router, Query, Table, Charts) and backed by D1.
  - `dunderquest.com/admin` reaches it through a path route, which takes precedence over the game site on the same host. The app is built with `base: "/admin/"`.
  - `stats.dunderquest.com` is kept for `/api/events`, which shipped game builds post to. Anything else there redirects to `/admin`.
  - `stats.ember-trail.robertlancer.com` does the same for builds from before the game was renamed from Ember Trail. Keep it until those builds stop reporting.
  - `src/server.ts` lets `/api/events` through and requires a Cloudflare Access sign-in for everything else.

## Feedback

`/admin/feedback` is Rob's inbox for what players send from the speech bubble in every game and from `/feedback/` (see `deploy/README.md`). It's private: nothing on the public site shows feedback.

- It reads the site Worker's social databases, not this app's: `SOCIAL_DB` (`dunderquest-social`, the live site) and `SOCIAL_DB_DEV` (`dunderquest-social-dev`), switched with the Live site / dev.dunderquest.com toggle.
- `cf deploy` made those databases by name, so their ids aren't in `wrangler.jsonc`, only the placeholders `SOCIAL_DB_ID` and `SOCIAL_DB_DEV_ID`. CI's "Deploy stats" step looks the ids up with `wrangler d1 list --json`, swaps them in and builds again before `wrangler deploy`. So the API token needs to be able to list D1 databases (D1: Edit covers it).
- Tiles for new items, this week, open bugs and the average rating; New / Done / Spam / All tabs; game and kind filters; and on each card the context (the level the player was up to), the page, the player (linked to their public profile), the browser, a Reply link when they left an email, and Mark done / Spam. The nav shows how many are new on the live site.
- Spam older than 30 days is deleted whenever the page loads. A database with no `feedback` table yet (a fresh local one) shows a note instead.
- Locally, the placeholders are empty local databases. To try the page with data, make the table in one (`npx wrangler d1 execute dunderquest-social --local --command "..."`, with the `feedback` and `players` schema from `deploy/src/db.ts`).

## Run it locally

```sh
cd stats
bun install
cp .dev.vars.example .dev.vars   # skips the Access check on localhost only
bun run db:migrate:local
bun run dev                      # http://localhost:5173/admin/
```

To send real events from the game to it, run Godot with `EMBER_TELEMETRY_URL=http://localhost:5173/api/events`.

## One-time setup

1. **Create the database.** Run `npx wrangler d1 create ember-trail-stats` and paste the printed `database_id` into `wrangler.jsonc`. CI skips the stats deploy until this is done.
2. **Check the API token.** The `CLOUDFLARE_API_TOKEN` secret used by CI needs **D1: Edit** on top of the Workers permissions it already has.
3. **Turn on Zero Trust** in the Cloudflare dashboard and pick a team name. That gives you a team domain such as `yourteam.cloudflareaccess.com`. The free plan covers up to 50 users.
4. **Add a login method** under Zero Trust → Settings → Authentication:
   - **GitHub:** create an OAuth app at github.com/settings/developers.
   - **Google:** create an OAuth client in Google Cloud Console.
   - For both, the callback URL is `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`.
   - One-time PIN (a code sent by email) is on by default and needs no setup, if you'd rather skip OAuth.
5. **Protect the admin area.** In Access → Applications, add a self-hosted application with these destinations: `dunderquest.com/admin`, `stats.dunderquest.com` and `stats.ember-trail.robertlancer.com`:
   - Policy action: **Allow**.
   - Include: **Emails** `robert.lancer@gmail.com`.
   - Copy the application's **Audience (AUD) tag** for step 7.
6. **Leave the game's endpoint open.** Add a second self-hosted application for `stats.dunderquest.com/api/events` and `stats.ember-trail.robertlancer.com/api/events`:
   - Policy action: **Bypass**.
   - Include: **Everyone**.
   - Access picks the most specific path, so the game can post while the rest stays locked.
7. **Tell the Worker.** In `wrangler.jsonc`, set `ACCESS_TEAM_DOMAIN` (for example `yourteam.cloudflareaccess.com`) and `ACCESS_AUD`. Until both are set, the admin area answers 503. The Worker checks the Access token itself as well, so the admin area stays shut even if the Access policy is ever removed.
8. **Check the API token.** The `/admin` path route needs **Workers Routes: Edit** on the `dunderquest.com` zone.
9. Push to `main`. CI applies the migrations and deploys.

To let someone else view the stats, add their email both to the Access policy and to `ALLOWED_EMAILS`.

## Limits worth knowing

- `/api/events` accepts at most 30 requests a minute per IP (`EVENT_LIMITER`). It also rejects any body over 32 KB, any batch over 50 events, and anything that doesn't match the schema in `src/server/events.ts`.
- Each event is one D1 row. A player sends a batch every 10 seconds at most while playing, which is well inside the D1 free tier for a small game.
- Adding a new event type means updating three places: `EVENT_TYPES` in `src/server/events.ts`, the call in the game, and a query in `src/server/stats.server.ts`.
