# deploy

`cf deploy` puts `build/site` on Cloudflare (`cloudflare.config.ts`): `--mode dev` is dev.dunderquest.com, `--mode production` is dunderquest.com. CI does both (see `.github/workflows/deploy.yml`).

The site is static, except for the paths in `runWorkerFirst` (`/api/*`, `/u/*`, `/c/*`, `/s/*`), which go to the Worker in `src/`: the social layer.

## The social layer

Leaderboards, cloud saves, certificates and screenshot sharing for every game, with no sign-up.

- **Players are anonymous.** The first time someone clears a level, the play page makes a player with a silly name (`POST /api/players`) and keeps its token in localStorage. The server keeps only the token's SHA-256. The `/me/` page renames them, shows a **save key** (a link that signs another browser in as them) and deletes everything.
- **Google sign-in is optional** and off until `GOOGLE_CLIENT_ID` in `cloudflare.config.ts` is set. The Worker checks Google's ID token itself (RS256 against Google's keys) and keeps only the account number (`sub`): no email, name or picture. Signing in on a second device merges that device's progress into the account.
- **Saves are each game's own save file.** Each game's `Social` autoload (`core/social.gd`, Dunder Quest's `common/social.gd`) reads its save file once a second and hands it to `window.DQSocial` (`site/static/social/play.js`), which uploads it. On load it merges in the cloud copy first, so progress follows the player. The server merges too (`site/static/social/games.js`, shared by both sides): every level cleared anywhere counts, along with the best time, fewest tries and most collectibles.
- **XP:** 100 a level, 400 for finishing a game, 10 a collectible. The overall board ranks by XP; each game's board by levels, then time or tries, then who got there first.
- **Certificates** are issued by the server when a save shows every level cleared. `/c/<id>` is the page (Open Graph image, Add to LinkedIn, download, print), `/c/<id>.png` the image. The Worker draws it itself (`cards.ts`, `png.ts`, with the pixel font in `font.ts` from `tools/make_font.py`) and caches it in D1. Bump `CERT_DESIGN` in `cards.ts` when the design changes.
- **Screenshots:** the camera on every play page (or F9) frames the game in a 1200×630 card with a caption. It can be shared or downloaded as it is, or uploaded for a link (`/s/<id>`) whose preview is the card.
- **Profiles:** `/u/<id>`, with a progress card as its image.

### API

| | |
| --- | --- |
| `GET /api/config` | Whether Google sign-in is on, and its client ID |
| `POST /api/players` | Make an anonymous player; returns its token |
| `GET /api/me`, `PATCH /api/me`, `DELETE /api/me` | The player with their saves, certificates and screenshots; rename; delete it all |
| `POST /api/auth/google`, `POST /api/auth/logout` | Sign in with a Google ID token; revoke this token |
| `GET /api/saves`, `PUT /api/saves/:game` | Every cloud save; upload one (returns the merged save and any new certificate) |
| `GET /api/leaderboard?game=&limit=` | A board (no `game` for the overall one), with your own place |
| `GET /api/feed` | The latest certificates |
| `PATCH /api/certificates/:id` | Change the name on your certificate |
| `POST /api/shots`, `DELETE /api/shots/:id` | Upload a screenshot (form data: `image`, `game`, `caption`); delete one |

Making players and uploading screenshots are rate-limited (`WRITE_LIMITER`, 20 a minute from one address). A player keeps at most 200 screenshots of up to 1.5 MB.

### Storage

D1: `dunderquest-social-dev` and `dunderquest-social`, made by `cf deploy` the first time. The Worker makes its own tables (`src/db.ts`), so there are no migrations to run. A new column needs an `ALTER TABLE` on both databases, since `CREATE TABLE IF NOT EXISTS` won't add it.

### Moderation

Names go through a small blocklist (`src/names.ts`). Anything else is hidden by hand, from the D1 console in the Cloudflare dashboard or `wrangler d1 execute dunderquest-social --remote --command "..."`:

```sql
UPDATE players SET hidden = 1 WHERE id = '...';   -- off every board, profile, certificate and screenshot
UPDATE shots SET hidden = 1 WHERE id = '...';     -- one screenshot
```

### Running it locally

```bash
bun site/build.ts build/site
bun deploy/dev.ts
```

That serves `build/site` and the Worker on http://localhost:8788, with D1 played by bun:sqlite in `build/social-dev.sqlite`. To try a game there, export it to the web first (`bash scripts/export_web.sh`). Set `GOOGLE_CLIENT_ID` in the environment to try sign-in (the client needs `http://localhost:8788` as an authorised origin).

`bun test test` (from this folder) runs the API's tests; CI runs them too.

### Turning on Google sign-in

1. In the Google Cloud console, make an OAuth client ID of type **Web application**.
2. Authorised JavaScript origins: `https://dunderquest.com`, `https://dev.dunderquest.com`, `http://localhost:8788`. No redirect URIs are needed.
3. Put the client ID (it isn't a secret) in `GOOGLE_CLIENT_ID` at the top of `cloudflare.config.ts`.
