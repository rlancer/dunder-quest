# Game design: Mission Silicon

The design doc for the fourth game, written from [CURRICULUM.md](CURRICULUM.md) (what it teaches) and [SHOW.md](SHOW.md) (how the homage carries it). It settles the core loop, the simulation, the episode data, the phone screen and the checks, then walks Episode 8 (*Viral*) through end to end on paper, and Episodes 9, 10 and 11 after it. The numbers here are first-pass values for the prototype to tune; the shapes (what makes what slower, costlier or wrong) are meant to be final.

## The loop in one paragraph

Each episode, something happens to Forkcast (a demo, a launch, a viral post) and Aleister Jr., the AI teammate, answers it with a **pull request**: a short list of changes drawn on the whiteboard as dashed boxes. The player reviews it the way the curriculum says a founder should: **keep or cut** each change, **ask** Aleister the questions from the curriculum's "What to tell your AI" lines, and **set the one dial** on any box that has one, while the engineers argue over each change and Ulrich slaps his own idea onto the pile. Then the player **merges**, and the episode's **live moment** runs: simulated diners pour in and hit what was built, and the consequences play out on the board. Gerard's **postmortem** says what happened and why, with the real terms. If the live moment failed, it's take two from the same board; if it held, the episode ends on a cliffhanger cut to black.

## What the player does, and doesn't

- **Reviews, asks, tunes; never writes code and never wires.** Aleister draws every box and every connection. Dragging wires on a phone is fiddly, and the skill the curriculum teaches is reading and steering a plan, not drawing one.
- **Nothing is marked right or wrong when it's chosen.** No ticks, no buzzers, no "correct!". Only the live moment and the postmortem judge, and they judge the whole plan. That's what keeps keep-or-cut from becoming a quiz (Dunder Quest's territory), and it's how real decisions feel.
- **Nothing is timed.** The planning board waits as long as the player likes, and the live moment pauses for every decision. Reading speed is never the challenge.
- **Mistakes are funny, not fatal.** A failed live moment is a scene (the garage server smoking, a diner charged twice, Ulrich on the phone to a reporter), followed by take two. The company never dies mid-season.

## The episode, step by step

1. **Cold open.** A short dialogue scene in the house, the garage or wherever the episode starts, before the title. Sets up the problem the show's way: something is about to go wrong.
2. **Title card.** The episode's name in Montserrat ExtraBold, green on off-white, over a glitchy sting.
3. **The brief.** One or two lines from whoever owns the problem (Veronica for money, Gilroy for servers...) and the stakes, drawn as the episode's three meters: **runway**, **time** and the **live moment's goal** ("Survive Friday night: up all night, pages under 3 seconds, nobody sees anyone else's bookings").
4. **The pull request.** Aleister proposes. The board shows Forkcast as it stands, with the proposed changes ghosted in dashed green. The PR panel lists the changes, each with what it is in plain words, its real name, the time it takes to build and what it adds to the monthly bill. Ulrich's idea arrives as one more card, stamped with his face.
5. **Review.** In any order, as often as they like:
   - **Keep or cut** each card. Tapping a card opens it: two of the engineers argue it in a line each (the trade-off is the lesson), and the card's numbers.
   - **Ask.** A list of questions (the Ask Aleister button), worded as the curriculum's "What to tell your AI" lines. Asking makes Aleister or an engineer answer with a fact (how often tonight's tables change, where the bottleneck is), and sometimes Aleister adds a better card. A couple of the questions are bad ones that Ulrich would ask ("Make it web-scale"); Aleister cheerfully obeys those too, adding the overkill they invite. That's Module 0's lesson in miniature: it builds what you ask.
   - **Dials.** Tapping a box on the board opens its settings: at most a few steppers (how many servers, how long the cache keeps tonight's tables, what happens on a timeout).
   - **Staging** (from Episode 7, when Module 8 introduces it): a quick run at a tenth of the traffic, showing a summary. It's honest, and it's honestly limited: races and cache staleness hide at low load, which is Module 10's misconception made playable.
6. **Merge.** Disabled while the kept cards don't fit the time left ("I'll have the Kubernetes cluster ready by... a week on Tuesday"). Merging is how every change ships, all season, so Module 2's pull requests are taught by doing.
7. **The live moment.** The board becomes a live diagram; see [The live moment](#the-live-moment). It can stop for a **hotfix**: Aleister offers one emergency change mid-crisis, keep or cut, with the simulation paused.
8. **Postmortem.** Gerard's thorough spreadsheet: the night by the numbers, then up to three findings, each pinned to the box it happened in, with the plain explanation, the real term and the line to tell your AI next time. Then the marks, or "take two".
9. **Lesson card and cliffhanger.** The episode's concept for the codex (plain words first, real name second), then the last beat of the episode and a cut to black. Next episode opens with a five-second "previously on".

An episode should run 6 to 10 minutes: a phone session.

## Runway, time and the marks

- **Runway is the score.** Shown as months: money in the bank over monthly burn. Salaries set the base burn; every kept box adds its monthly cost; the live moment spends money (model calls, per-use hosting, refunds, incidents) and earns a little (a booking fee). Over-engineering shortens runway exactly as outages do, so "the simplest version that works" is the cheapest without anyone saying it.
- **Time is the plan's budget.** Each card costs build time (hours or days, per episode). Kept cards must fit before the live moment. Time is what stops the player from simply keeping everything.
- **The live moment's goal** is two to four plain conditions per episode (up the whole time, pages under 3 seconds at peak, no private data leaked, nine bookings in ten succeed). All must hold to pass.
- **Each episode starts fresh.** Its data sets the bank, the burn and the board (which matches the previous episode's ending; a test checks it). Runway doesn't carry over, so one bad episode can't make a later one unwinnable, and every episode can be played and tested alone. The season screen shows each episode's best runway.
- **Three marks** per episode, judged on the run that passes:
  - **Live**: the goal held.
  - **Lean**: runway at or above the episode's par, which is set just under the authored solution's.
  - **Ulrich**: his card was kept if he was right and cut if he wasn't. He's right about a third of the time across the season, so the mark is earned by judgement, not by always cutting him.
  
  A perfect episode is all three. Whether the season also shows a made-up show-style metric with a homage name (the show had its own fake compression score) is open.

## Ulrich, the engineers and Aleister

- **Ulrich's card** comes with his face on it, a confident line and no hint either way: same colour, same layout as Aleister's cards. It always comes from the module's misconceptions list when he's wrong, and his being right sometimes is what forces the player to think.
- **The engineers' takes**: each card has two short lines from two of the cast, for and against. They follow SHOW.md's roles (Gilroy distrusts, Danesh chases fashion, Ricky over-engineers, Gerard asks about the boring failure). Both lines are true; the trade-off between them is the lesson.
- **Aleister Jr.** is eager, fast and overconfident. Its PR is never all wrong and never all right: usually a couple of good changes, one good change with a bad default, and one or two overkill changes it's very excited about. The finale's PR is the whole capstone diagram at once, and the job is cutting it back.

## The simulation

It has to be explainable (every outcome traces to a box and a reason the postmortem can name), deterministic (the same plan always gives the same night, so tests can enumerate plans), cheap (thousands of plans a second in a test) and true in its shapes. So it's a **flow model**, not individual requests: each tick it works out how much of each kind of request reaches each box, and what that does. The dots on screen are a picture of the flow, not the thing simulated.

### Time

One tick is one simulated minute. A live moment is usually 360 ticks (six hours of evening) played at 4 ticks a second, so 90 seconds, pausable, with a 2× button.

### Traffic

- Each episode gives **diners online** over time as keyframes (`[[0, 500], [90, 3000], [150, 12000], ...]`), with **events** that change it (the second post doubles it).
- Each **request kind** has a per-diner rate per minute and a route. The kinds in play depend on the episode: `browse` (open the app: pages, photos, menus), `tables` (tonight's free tables near me), `search` (ask the AI concierge), `book`, `my_bookings`, `signup`, and later `dashboard`, `pay`, `webhook`, `scrape` and `agent`.
- Some kinds **can wait** (`signup`'s welcome email, `webhook` processing): they're allowed through a queue. The others need an answer while the diner waits.

### Boxes

Every box on the board is a **piece** from a catalogue (`data/pieces.json`). A piece has:

- **capacity**: work it can do per second; **work** per request kind (an unindexed search of every booking is far more work than an indexed one);
- **base latency**, and per-call latency for outside services;
- **monthly cost**, and **per-use cost** (model calls, serverless runs, CDN traffic);
- optional **behaviours**, below.

Each tick, for each box: load = the sum over request kinds of (requests reaching it × work per request); utilisation `u` = load / capacity.

- **Below capacity**, the box's latency is `base / (1 − u)`: fine at half load, five times slower at 80%, terrible near 100%. That's the real shape of a queue (the textbook single-server queue), and why "it was fine yesterday" turns into "it's crawling" so fast.
- **Over capacity**, the excess builds a backlog, adding backlog / capacity seconds of waiting; past the box's backlog limit, requests time out and become errors.
- A request's latency is the sum along its route. Diners abandon as latency climbs (a smooth curve from 2 seconds), and abandoned bookings are lost revenue.

### Behaviours

Each is a few lines of code, a real effect, and a postmortem tag.

| Behaviour | Pieces | What it does | Tag |
| --- | --- | --- | --- |
| **Overheat** | The garage server | Above 80% for 20 ticks it shuts down for 30, failing everything routed through it | `garage_melt` |
| **Scan cost grows** | Database, per unindexed query | Work per request grows with rows in the table, which grow with bookings during the night | `full_scan` |
| **Cache** | Redis, CDN, model-answer cache | Per data row: a TTL and a scope (shared, per user, off). For a row with request rate λ over K distinct keys and TTL T, the hit rate is x / (1 + x), with x = λT / K (the exact result for a TTL cache with random arrivals and evenly popular keys; real traffic is skewed toward a few popular keys, which only raises the hit rate). Hits skip everything behind the cache | |
| **Staleness** | Cache rows of data that changes | If each key changes at rate μ, the share of hits that are out of date is 1 − (1 − e^(−μT)) / (μT). A stale "free" table that's actually taken gives the diner "sorry, just taken" at booking time | `stale_tables` |
| **Shared per-user data** | A cache row of per-user data with shared scope | Every hit shows one diner another's data. Fails the goal outright | `cache_leak` |
| **Sessions** | App servers | Sessions in server memory with more than one server behind the load balancer: each request lands on a server that doesn't know the diner with probability 1 − 1/N, logging them out | `stateless` |
| **Connection limit** | Database | Each app server holds a pool of 10 connections; Postgres allows 100 by default. Servers beyond the limit get errors on every database call | `too_many_connections` |
| **Rate limit** | Model API, payment provider | Calls above the provider's per-minute limit fail with HTTP 429 | `rate_limited` |
| **Scraper and our own rate limit** (built, Episode 10) | Load balancer, app servers | A scraper's machines each ask for tonight's tables many times a minute, with combinations the cache never holds. A per-client limit lets each through up to the limit and turns the rest away with a 429 for almost no work; set under what a busy diner does (thirty a minute), it turns away a share of real diners too. A CAPTCHA stops most of the scraper and makes some diners give up | `scraper`, `limit_too_tight`, `captcha` |
| **Service chain** (built, Episode 10) | Microservices on a cluster | Each kind of request crosses a number of network calls between services (a booking eight). Each call adds latency and work and fails now and then (1 in 100), and a request needs every call on its path, so success is the product: 0.99⁸ ≈ 92% | `service_chain` |
| **Queue** | Queue + worker | Requests that can wait cost the app almost nothing to enqueue; a worker drains them at its own rate. The backlog shows as a literal line of tiny diners | `no_queue` (when a spike hit without one) |
| **Load balancer** | Appears by itself when a box has more than one server | Splits load evenly | |
| **Autoscale** | App servers, serverless | Server count follows load between a min and a max, with a warm-up delay | |
| **Network faults** (built, Episode 11) | The payment provider, scripted per episode | Each booking at a deposit restaurant calls the provider (`pay`). A scripted share of calls time out (keyframes over the night); of those, a share actually succeeded and only the reply was lost. Timeouts happen at the same rate on a quiet night, so staging sees a tenth as many | `timeout_unknown` |
| **Retries** (built, Episode 11) | Calls to the payment provider | Off: timeouts are reported as failures, so the ones that had succeeded charge diners for tables they're told they didn't get. On: a retry repeats the call, so the ones that had succeeded charge twice. On with an idempotency key: the provider recognises the repeat and answers with the first result. A backup provider can't recognise another provider's keys | `timeout_unknown`, `double_charge`, `backup_provider` |
| **Race** (built, Episode 11) | Booking the last table | Check-then-book in two steps lets two parties get the same table: with hot-table bookings arriving at h a second over H tables and a gap of w seconds, at h²w/H, so it grows with the square of the traffic and a tenth of the load shows a hundredth of it. Waiting for the deposit inside the gap widens it. A transaction that holds the table closes it. On a decentralised copy across phones the gap is log₂(phones) rounds of gossip, whatever the database does, and phones that drop off lose bookings | `double_booking`, `forknet` |
| **Analytics on the live database** (built, Episode 9) | Database, replica, warehouse | Dashboard queries are huge scans (screens × tiles / refresh, each a scan of every stored row). On the main database they take capacity from bookings, and a booking waits the database's full latency; on a read replica they swamp the copy instead; on a warehouse, stored by column, each is a small share of the work | `olap_on_oltp`, `replica_slow`, `too_many_tiles` |
| **Pipeline freshness** (built, Episode 9) | Warehouse | The board's numbers are as old as the last good copy: hourly, nightly or streamed. A scripted copy failure stays broken until a hotfix fixes it, and the hotfix is only offered with alerts | `silent_failure`, `stale_numbers` |
| **Secret exposure** | Wherever a key lives | A key in the frontend or a public repository is found by a scanning bot at a scripted tick, after which unknown usage runs up the bill | `leaked_key` |
| **Authorization** | Endpoints | Without an ownership check, a curious diner (or a bot) changing the number in the URL reads others' bookings | `idor` |
| **Grounding and tools** | The AI concierge | Without retrieval over real menus, a share of answers are made up; an agent with a powerful tool and no confirmation step can be steered by injected text in a review | `hallucination`, `prompt_injection` |

### Money

- Monthly cost of every box adds to the burn. Per-use costs accrue during the live moment, at the episode's prices.
- Model calls: a price per call, mostly the long fixed part of the prompt (instructions plus restaurant context). **Prompt caching** bills that unchanged part at a fraction of the normal rate (as little as a tenth with some providers); the **answer cache** skips the call entirely on a hit.
- Incidents cost money where they really would: refunds for double charges, a lawyer after a leak.
- Runway after the episode = (bank − the night's costs + the night's revenue) / (base burn + the new monthly costs).

### Honest numbers

The game's prices, capacities and rates are illustrative: plausible, rounded, chosen to make the lesson readable, and never presented as quotes. The codex says so once. The shapes are real: which way each change moves each number, and roughly how much. The technical review (next steps) checks both.

## The live moment

The same board, now running. Three layers of detail:

1. **Always visible.** Diners (tiny pixel phones) at the left sending dots along the wires; each box's heat bar, green to red; at the top, **diners online**, **page speed** (real term: latency), **errors** and **runway** ticking down live. The clock runs across the top: "Friday 5:00pm" to "11:00pm".
2. **Bubbles.** When a behaviour fires, a short bubble pins to the box with the real term: "Database: full table scan", "Cache: stale table!", "429: model rate limit", "Logged out?!", "Too many connections". Diners' complaints float up from the left ("It said the table was free").
3. **Tap a box** for its numbers: utilisation, hit rate, backlog, cost so far. Tapping pauses.

A corner panel cuts to the cast reacting, triggered by what the simulation is doing (Gilroy in the garage with a fan, Ricky pacing, Chaz texting a bigger number every minute). Event banners announce the episode's beats ("The chef posted again").

If everything is failing for 10 ticks straight, the live moment ends early: cut to black, "Forkcast is down", straight to the postmortem.

## The episode data

The season is data, like Curb's `data/scenes.json`, and one scene script builds every episode from it.

- `data/pieces.json`: the catalogue of pieces: capacities, work per request kind, latencies, costs, behaviours, art and plain-words descriptions.
- `data/season.json`: the cast and every episode.

An episode, abbreviated (Episode 8 in full is in the walk-through below):

```json
{
  "id": 8, "title": "Viral", "stage": 4, "modules": [7, 9],
  "borrowed": "The live stream that goes huge while Anton overheats in the garage",
  "cold_open": [{"who": "ricky", "say": "..."}],
  "brief": [{"who": "veronica", "say": "..."}],
  "budget": {"bank": 1200000, "burn": 80000, "time": 18, "time_unit": "hours", "par": 14.9},
  "board": {"boxes": [{"id": "garage", "piece": "garage_server", "roles": ["app", "db"]}], "settings": {}},
  "pr": {"title": "Make Forkcast web-scale", "cards": [
    {"id": "cloud", "by": "aleister", "label": "Move to the cloud", "term": "managed hosting",
     "plain": "...", "time": 4, "changes": [...],
     "takes": [{"who": "gilroy", "say": "..."}, {"who": "ricky", "say": "..."}]},
    {"id": "forty", "by": "ulrich", "ulrich_right": false, "...": "..."}
  ]},
  "asks": [{"id": "bottleneck", "text": "Where's the bottleneck?", "decoy": false,
            "reply": [{"who": "aleister", "say": "..."}], "adds": ["index"]}],
  "live": {"ticks": 360, "clock": ["17:00", "23:00"],
           "diners": [[0, 500], [90, 3000], [150, 12000], [180, 12000], [181, 24000], [330, 4000], [360, 1500]],
           "kinds": {"browse": 2.0, "tables": 0.5, "search": 0.3, "my_bookings": 0.1, "book": 0.002},
           "signups": {"total": 50000, "bursts": [[180, 0.3]]},
           "events": [{"tick": 180, "banner": "The chef posted again"}],
           "hotfixes": [{"id": "one_more", "tick": 180, "say": "..."}]},
  "goal": [{"metric": "down_ticks", "max": 5}, {"metric": "peak_latency", "max": 3.0},
           {"metric": "leaks", "max": 0}, {"metric": "booking_success", "min": 0.9}],
  "solution": {"keep": ["cloud", "cache", "cdn", "queue", "index", "ai_cache"], "dials": {"...": "..."}, "hotfix": {"one_more": true}},
  "postmortem": {"garage_melt": {"plain": "...", "term": "...", "tell_ai": "..."}},
  "lesson": {"plain": "...", "term": "...", "source": "..."},
  "cliffhanger": [{"who": "chaz", "say": "..."}]
}
```

Every claim a lesson card or postmortem finding makes carries a `source` (a doc link) for the technical review.

## The screen

Laid out at 480×270 like Curb (`canvas_items` stretch, integer scaling, pixel art nearest-neighbour, text drawn at the window's own resolution). On a phone held sideways one game pixel is about 1.4 points, so:

- **Tap targets at least 30×30** game pixels (about 44 points, the usual phone minimum).
- **Body text at least 9** game pixels (about 13 points). That gives roughly 34 characters a line in the PR panel, so card labels stay under 22 characters and plain-words lines under two lines.
- No hover, no drag, no long-press: taps only. Everything also works with a mouse and keys.
- Held upright, a "turn your phone sideways" card covers everything.

Planning:

```
+--------------------------------------------------------------------------------+
| VIRAL      Runway 14.8 mo                                       Time 12.5 / 18h  |  20
+-----------------------------------------------+--------------------------------+
|  diners    edge      app          data        | Make Forkcast web-scale        |
|                                               |  Move to the cloud   4h  KEEP  |
|  [phones]->[ CDN ]->[ App x1 ]-->[ Postgres ] |  Kubernetes         40h  CUT   |
|                      |      \                 |  Add a cache         2h  KEEP  |
|                  [ Redis ]  [ Model API ]     |  CDN for photos      1h  KEEP  |
|                  [ Queue ]->[ Worker ]        |  Rewrite in Rust     8h  CUT   |
|                                               |  [U] Forty servers   1h  CUT   |
+-----------------------------------------------+--------------------------------+
| [ The PR ] [ Ask Aleister ]                     [ Staging ] [    MERGE    ]  |  34
+--------------------------------------------------------------------------------+
   board 300 x 216                                  PR panel 180 x 216
```

- Tapping a card swaps the list for its detail (the takes, the numbers, a big KEEP/CUT switch, a back arrow). Tapping a box swaps it for the box's dials (◀ value ▶ steppers). Ask Aleister swaps it for the questions. (The prototype first had the questions as a strip of chips along the bottom; they overflowed the width, so they live in the panel.)
- Dialogue uses Curb's arrangement: a bubble with a close-up portrait, tap to advance.
- Live, the PR panel becomes the cast corner and the event feed, and the bottom strip becomes pause, 2× and the clock.

## How each episode's lesson is checked

The authored data must prove its own lesson, the way Curb's starting picks must hit their error code. For every episode, by running the simulation headless:

1. **The solution passes**: it meets the goal and reaches par.
2. **Aleister's PR as proposed fails** (the goal, par or the time limit), and so does doing nothing.
3. **Every lesson-bearing decision matters**: flipping any one decision in the solution (a card, a dial, the hotfix) either fails the goal or par, or is marked `free` in the data, and when it fails, the postmortem tag it raises is one the episode explains. So every finding Gerard can read out is backed by the simulation.
4. **Ulrich's card does what the data says**: keeping it when he's wrong (or cutting it when he's right) costs the goal or par.
5. **No cheap way round**: across every combination of cards, dials and the hotfix (a few thousand runs; the flow model makes that a second or two), nothing passes with runway more than a small margin above the solution's. If the search finds a cheaper pass, either the lesson has a hole or the solution isn't the simplest; both are worth knowing.
6. **Continuity**: each episode's starting board is the previous episode's solution, or the data says what changed in the cold open and why.

And across the game:

- **Coverage**: every curriculum module 0 to 13, and the capstone, has at least one episode (`modules` in the data), read against CURRICULUM.md's headings so a curriculum edit flags gaps.
- **Determinism**: the same plan gives the identical night twice.
- **Layout**: every tappable control is at least 30×30 and no text is under 9 pixels, on every screen the bot visits.
- **The bot** (`tests/bot.tscn`) plays every episode through the real UI, first with Aleister's PR as proposed (and watches it fail into the postmortem), then the solution.

## Episode 8 on paper: *Viral*

Stage 4, Modules 7 (caching) and 9 (scaling). Borrowed set piece: the live stream that goes huge while the garage server overheats and the team scrambles to keep it alive. Every line below is a placeholder to show the beat; the real lines get written with the episode.

### Continuity

Episode 7 ends with Forkcast on a platform host with managed Postgres, deployed by CI. Episode 8's cold open undoes it: Gilroy, offended by paying anyone for hosting, moved everything to Aleister, his garage server, overnight. That's in character, and it gives the episode its set piece and its starting board.

### Cold open

Thursday, 11pm. A celebrity chef with nine million followers has posted that Forkcast found her a table in thirty seconds. Ricky wakes the house, then throws up. Sign-ups are pouring in. Everyone runs to the garage, where Aleister is roaring and hot to the touch; Gilroy has a desk fan on it and is not apologising. Ulrich is already on the phone telling a reporter the idea was his.

Title card: **VIRAL**.

### Brief

Veronica: the chef posts again tomorrow evening, right in the Friday dinner rush, to an audience that's awake this time. Eighteen hours. Gilroy: the garage won't survive it.

- **Budget**: $1.2M in the bank, $80k a month, so 15.0 months of runway. 18 hours to build.
- **Goal**: up all night (no more than 5 minutes down), pages under 3 seconds at the peak, nobody sees anyone else's bookings, nine bookings in ten succeed, nineteen searches in twenty get an answer.

### The starting board

Diners' phones → **Aleister** (garage server, running the app and Postgres together; sessions in memory; no index on bookings) → **Model API** (one call per search, no caching).

### Aleister's pull request: "Make Forkcast web-scale"

| Card | By | Time | Monthly | What it really does | The takes |
| --- | --- | --- | --- | --- | --- |
| **Move to the cloud**: one app server (M) and managed Postgres | Aleister | 4h | +$700 | Off the garage, room to grow, sessions movable to Redis | Gilroy against (pride, and the bill); Ricky for (the garage is on fire) |
| **Kubernetes**: twelve microservices on a cluster | Aleister | 40h | +$4,000 | Can't be done in 18 hours, and wouldn't help: one team, one app | Ricky for (it's how Hubbub does it); Gilroy against (twelve things to break instead of one) |
| **Add a cache** (Redis): one hour for everything | Aleister | 2h | +$100 | Takes load off the database, but its defaults are wrong: tonight's tables go stale, and "My bookings" is shared | Danesh for (speed); Gilroy: a cache is a machine for telling people things that used to be true |
| **CDN for photos** | Aleister | 1h | +$50 | Photos and scripts served from the edge, not the app (the pages themselves still come from the app: they hold per-diner data) | Danesh for; Gerard asks what happens when a restaurant changes its photos (it's fine: they can be an hour old) |
| **Queue sign-up work**: welcome emails and other chores | Aleister | 3h | +$50 | The 8pm sign-up burst no longer hits the app head-on (sending each welcome email is a slow outside call that would hold a server; the password is still hashed in the request, since a queue must never hold plain-text passwords) | Gerard for, earnestly; Danesh: nobody needs their welcome email this second |
| **Rewrite booking in Rust** | Aleister | 8h | -$100 | Faster code where the time isn't spent: the app is waiting on the database. Keeping it leaves no time for the fixes the asks turn up | Danesh for (it's what serious people use); Gilroy: you'd be rewriting the part that's waiting |
| **Forty servers** | Ulrich (wrong) | 1h | +$6,000 | 40 servers × 10 connections = 400, against Postgres's 100: most of them get "too many connections". And sessions are still in memory | Ulrich: Hubbub has forty thousand; Ricky can't get a word in |

Ulrich's line is the Module 9 misconception: more servers means faster.

### The asks

| Ask | Answer | Effect |
| --- | --- | --- |
| **Where's the bottleneck?** | Aleister measures last night: the database is at 100%, almost all of it on "free tables near me tonight", which reads every booking ever made | Adds **Add an index** (0.5h, free): the query stops growing with the table |
| **How stale can this be?** | Ricky and Gilroy: menus change about daily; tonight's tables change every couple of minutes; "My bookings" is per person | Just facts: what the cache dials should be |
| **Is this cache per user or shared?** | Aleister: shared, for everything. Including "My bookings". A pause. Gerard recalls, calmly, a previous employer where this happened | Just facts: the scope column matters |
| **What will this cost at 10x the traffic?** | Veronica: the model calls are four fifths of the bill, and the provider caps calls per minute | Adds **Cache AI answers** (2h, +$0 and cheaper calls): popular questions answered from the cache, and prompt caching on the long fixed prompt |
| **Make it web-scale.** (decoy) | Aleister, delighted | Adds **Shard the database by city** (12h, +$800): a last resort for a problem Forkcast doesn't have |
| **Use the smartest model.** (decoy) | Aleister, delighted | Adds **Upgrade to the biggest model**: five times the price per call, twice the wait |

### The dials

- **App servers**: count 1 to 8 (a load balancer appears above 1), size S, M or L; **sessions**: in server memory or in Redis (needs the cache; 1h).
- **Cache rows** (with the cache kept): for each of *menus and photos*, *tonight's tables* and *my bookings*, a TTL (off, 10s, 30s, 1 min, 10 min, 1h) and a scope (shared or per user).

### The live moment: Friday, 5pm to 11pm

| Clock | Tick | What happens |
| --- | --- | --- |
| 5:00pm | 0 | 500 diners, quiet. Gilroy's fan if the garage is still in use |
| 6:30pm | 90 | Dinner rush: 3,000 diners. On the garage, Aleister overheats around here and goes down for half an hour, then again |
| 7:30pm | 150 | 12,000 diners. Without the index, the database creeps toward 100% as bookings pile up, then times out. Without the CDN, the app drowns in photos |
| 8:00pm | 180 | **The chef posts again.** 24,000 diners, and fifteen thousand of the night's 50,000 sign-ups in twenty minutes. Without the queue, sign-ups swamp the app. Without the AI cache, searches pass the provider's limit and fail with 429s, and the bill races |
| 8:00pm | 180 | **Hotfix**, the moment the post lands. Aleister: "Traffic just doubled! Add another app server? It's $150 a month." (the price of one more server at the size chosen) It helps only if sessions are in Redis (otherwise diners start getting logged out) and only if the database isn't the real bottleneck |
| 9:00 to 10:30pm | 240 to 330 | Plateau, then falling off. Stale tables show up as "sorry, just taken" at booking time, more with a longer TTL. A shared "My bookings" row leaks from the first hit |
| 11:00pm | 360 | 1,500 diners. End |

The solution's night: two small app servers carry the evening at about half capacity, and the hotfix's third carries the doubled load. The index takes the tables query from the biggest load on the database to a small one (tonight's tables cache poorly: there are too many different searches), and the cache takes the menus (an hour) off it entirely. Tonight's tables cache for 30 seconds or less; my bookings per user or off. The AI cache keeps searches under the provider's limit and the night's model bill near $3k instead of five figures.

These are the prototype's results, from `tests/cases.gd`:

| Plan | Result |
| --- | --- |
| Do nothing | The garage melts in the dinner rush and keeps melting: fails everything but the leak |
| Aleister's PR as proposed | 59 hours: can't merge |
| Aleister's PR minus Kubernetes | 19 hours: still can't merge |
| Minus Kubernetes and Rust (the bot's take one) | Fits, and fails: the cache leaks "My bookings" at its defaults, the forty servers run out of connections, and diners get logged out |
| The solution, but stay in the garage | Holds until the post, then the garage melts: fails |
| Keep Ulrich's forty servers | Too many connections: fails, and $6k a month |
| The solution: cloud with two small servers, cache (menus an hour, tables 30 seconds, my bookings per user), CDN, queue, index, AI cache, sessions in Redis, hotfix kept | 14.94 months of runway; par 14.9 |
| The solution without the index | The database scans: fails "9 in 10 bookings" and "19 in 20 searches" |
| The solution without the hotfix | The app maxes out after the post: fails "pages under 3 seconds" |
| The solution with tonight's tables cached for ten minutes or an hour | Too many "sorry, just taken": fails "9 in 10 bookings" |
| Three, four or five servers, or medium ones | Passes, with less runway: misses Lean |

### Postmortem

Gerard's spreadsheet: diners served, page speed at the peak, errors, phantom tables, private data shown to the wrong people (hopefully zero), the night's model bill, booking revenue, runway. Then up to three findings in order of damage, for example:

> **The database read every booking ever made, every time someone looked for a table.** It got slower as the night went on because every new booking made the next search longer. *Real term: a full table scan; the fix is an index.* Tell your AI: "Where's the bottleneck?" and "Add an index for this query."

Marks: Live, Lean (14.9 months or better), Ulrich (cut the forty servers).

### Lesson card and cliffhanger

Two codex cards: **Cache** (a nearby copy of an answer; how stale can it be, and whose is it?) and **Scaling** (find the bottleneck first; bigger server, more servers, stateless; most apps never need much of it).

Cliffhanger: Sunday morning, the house asleep. Chaz bursts in having seen the numbers: he wants a screen with every one of those 50,000 users on it, updating every hour, in the boardroom, by Monday. Cut to black. (Episode 9: dashboards on the live database.)

### Checking it against the show

The garage server overheating while the audience explodes, the team crowded around it, the sysadmin's grim custodianship of his machine, the founder throwing up, the loud owner taking credit with the press, the loud investor arriving with a bigger number: all from the show's episode, rearranged, with original lines. If a fan wouldn't recognise it, it's drifted.

## Episode 9 on paper: *The Board Meeting*

Stage 5, Modules 6 (the OLAP side: warehouses and pipelines) and 8 (hosting and operating it: on-premises against the cloud, monitoring and alerts). Borrowed set piece: the founder pushed out as CEO by his own board, and the adult CEO they bring in, who wants to stop building the platform and sell a box. The lines are in `data/season.json`.

### Continuity

Episode 8 ended with Chaz demanding a screen of every user, updating every hour, in the boardroom by Monday. The starting board is Episode 8's solution with its hotfix: cloud, three small app servers with sessions in Redis, the cache (menus an hour, tables 30 seconds, my bookings per user), the CDN, the queue, the index and the AI cache. `cases.gd` now checks that (continuity, check 6). No cold-open change is needed.

### Cold open

Monday, 9am, Ravello Capital's boardroom (a new backdrop). Chaz wants his screen. Walter, after a long silence: the board has voted; Forkcast needs an experienced CEO. Veronica introduces Mack Barlow, who has run four companies (one was a boat). Ulrich voted yes twice, once as a board member and once, heavily, as your mentor. You're Head of Product now; you keep the robot. Mack's vision: a dashboard on every screen, live, and a box. People can hold a box.

Title card: **THE BOARD MEETING** (the top bar says BOARD MEETING, the episode's `short` name).

### Brief

Mack: the board comes back Friday night to watch the dinner rush on the big screen, with box prospects. Veronica: a normal busy Friday, fifteen thousand diners at the peak, and the bookings have to keep working while the board watches.

- **Budget**: $1.1M in the bank, $85k a month (Mack isn't cheap), so 12.8 months of runway with the board as it stands. 20 hours to build.
- **Goal**: up all night, bookings under 3 seconds, nine bookings in ten succeed, the board's screen works (19 tile refreshes in 20 answered), and its numbers are never more than an hour old (Chaz's "every hour").

### Aleister's pull request: "Dashboards for everyone"

| Card | By | Time | Monthly | What it really does | The takes |
| --- | --- | --- | --- | --- | --- |
| **Board dashboard**: forty live tiles on six screens, straight from the database, every minute | Aleister | 3h | — | Needed: the goal is the board's screen. But every tile is a scan of everything Forkcast has stored, and six screens ask forty of them every minute: 240 huge questions a minute on the database taking the bookings | Chaz for (can it be forty-one?); Gerard: every tile is a question, every screen, every minute |
| **Biggest database**: Postgres at eight times the size | Aleister | 1h | +$2,800 | Vertical scaling. It works: the dashboard's load fits. And it costs eight times as much, every month, for a screen | Danesh for; Veronica: it'd work, and it's $3,200 a month forever |
| **Read replica**: a live copy just for the dashboard | Aleister | 2h | +$400 | Keeps the dashboard off the bookings (true), but it's the same kind of database: the scans swamp it and the board's screen times out | Ricky for (that part's real); Gilroy: same huge questions, same slow answers, now in a second place |
| **The Forkcast Box**: a server in every restaurant's back office | Mack | 40h | — | On-premises hardware: two hundred servers to install, power, patch and fix in restaurant basements. Can't be built in 20 hours, and the product isn't a box | Mack: you can hold a box; Ricky: two hundred servers in two hundred basements, with our hands |
| **Analytics database**: copy the bookings hourly to a database built for big questions, and point the dashboard there | Ulrich (right) | 4h | +$300 | A data warehouse and an hourly batch pipeline. It stores by column, so a tile reads a sliver of the data a row store would, on a machine that isn't taking bookings. Hourly copies meet "an hour old" | Ulrich: you don't do the accounts at the front desk; Gilroy: he's right, write down the date |

Ulrich's card is right this time (his first in the prototype; across the season he should be right about a third of the time), for a borrowed reason: it's the curriculum's own front desk and accountant's office. Mack's box is Module 8's on-premises trap, and the episode's Kubernetes: too big to fit.

### The asks

| Ask | Answer | Effect |
| --- | --- | --- |
| **Is this OLTP or OLAP work?** | Ricky: the app's tiny jobs are OLTP, the front desk; every tile is a huge question across everything, OLAP, the accountant's office. Gilroy: 240 of those a minute, on the database that takes the bookings | Just facts: the tiles belong somewhere else |
| **How fresh do the numbers need to be?** | Walter, after a silence: the board meets four times a year. Veronica: Chaz asked for hourly; an hour old is plenty | Just facts: hourly copies are enough, nightly aren't |
| **How will we know if it breaks?** | Aleister: someone will mention it? Gerard: at a previous company they found the payroll job had stopped when the pay stopped | Adds **Error alerts** (1h, +$30): error tracking on the app and every scheduled job |
| **What will this cost at 10x the traffic?** | Veronica: the biggest database costs eight times as much whatever the traffic, forever; the dashboard asks the same questions at any traffic | Just facts |
| **Make it real-time.** (decoy) | Aleister, delighted | Adds **Real-time stream** (10h, +$3,000, needs the analytics database): every booking streamed in as it happens |
| **Make it huge.** (decoy) | Aleister: Chaz's favourite word | Adds **Two hundred tiles**: five times the questions |

### The dials

- **Analytics database: copy every** hour (the card's default) or night.

That's the only dial. Refresh rate and screens are fixed by the dashboard card; the lesson is where the questions go, not how often they're asked.

### The live moment: Friday, 5pm to 11pm

| Clock | Tick | What happens |
| --- | --- | --- |
| 5:00pm | 0 | 2,000 diners. The board is watching the big screen. With the dashboard on the live database, bookings already wait behind its scans |
| 6:30 to 7:30pm | 90 to 150 | The rush builds to 15,000 diners. On the replica, the board's screen says "Loading" all night. With two hundred tiles, the analytics database turns tiles away |
| 8:00pm | 180 | **The 8pm copy job fails**: a restaurant put a noodle emoji in its name. With alerts, Aleister offers the **hotfix**: handle it and rerun. Without alerts, nobody knows, and the board's numbers stop at 7pm. Chaz asks whether they broke time |
| 9:00 to 11:00pm | 240 to 360 | Easing off to 2,000. With nightly copies, the screen has shown 3am's numbers all evening |

The solution's night: the app and the database carry Friday at under half capacity, as in Episode 8; the dashboard's 240 tile questions a minute go to the analytics database, where reading by column makes them a fortieth of the work, at about a quarter of its capacity; the hourly copy keeps the numbers under an hour old, and when it breaks at 8pm the alert brings the hotfix.

These are the results from `tests/cases.gd`:

| Plan | Result |
| --- | --- |
| Do nothing | Bookings are fine; there's no dashboard: fails "the board's screen works" |
| Aleister's PR as proposed | 50 hours: can't merge |
| Minus the box (the bot's take one) | Fits, and fails: the analytics database takes the tiles, but nobody's watching the copy job, so the numbers stop at 7pm (and it pays for the biggest database and a replica it doesn't need: 12.40 months) |
| Dashboard on the live database (cut the analytics database) | Bookings at 20 seconds, one in ten works, and a quarter of the tiles answer: fails three goals |
| On the replica | Bookings fine; the replica drowns and the screen times out: fails |
| The biggest database instead of the analytics database | Passes, at 12.45 months: misses Lean by $2,800 a month |
| The solution: dashboard, analytics database copying hourly, error alerts, hotfix kept | 12.856 months of runway; par 12.85 |
| The solution plus the replica | Passes, at 12.80: misses Lean |
| The solution plus the real-time stream | Passes, at 12.42: misses Lean |
| The solution without alerts, or with the hotfix cut | The copy job stays broken: numbers 239 minutes old, fails |
| Copying nightly | Numbers from 3am all night: fails |
| Two hundred tiles | The analytics database answers 80% of them: fails "the board's screen works" |

### Postmortem

New findings: no dashboard; OLAP work on the OLTP database ("The board's dashboard slowed down the bookings"); the replica that couldn't answer; two hundred tiles; the copy job that broke and stayed broken; the board watching last night's numbers. The generic ones (database or app servers maxed out, rate limits, overbuilt) carry over from Episode 8.

Marks: Live, Lean (12.85 months or better), Ulrich (keep the analytics database).

### Lesson cards and cliffhanger

Two codex cards: **OLTP and OLAP** (the front desk and the accountant's office; big questions go to a data warehouse kept up to date in regular batches) and **Monitoring and alerts** (once it's live you can't watch every screen and job; alerts tell you before customers, or the board, do).

Cliffhanger: Saturday morning, the kitchen. Mack: Hubbub called, they loved the dashboard, and asked a lot of questions about how Forkcast works; he answered all of them, in detail, with slides. Gilroy: you what. Ricky is going to be sick. (Episode 10: Hubbub Dine.)

### Checking it against the show

The show's season 2 to 3 turn: the board removes the founder as CEO, an affable, grey-haired veteran salesman takes over, keeps the founder on in a lesser title, and steers the company toward selling a physical box instead of the platform; the engineers are appalled and the founder is sidelined in his own company. Here: Walter's silence and the vote, Ulrich voting against you and claiming a heavy heart, Mack keeping you on as Head of Product, the box, Gilroy's flat "A box." The board watching numbers on a big screen nods to the show's obsession with vanity metrics in front of investors. Mack leaking the product to Hubbub is ours, not the show's, and sets up the next episode's clone (the show's Nucleus). If a fan wouldn't recognise the board scene and the box, it's drifted; they would.

## Episode 10 on paper: *Hubbub Dine*

Stage 6, Modules 9 (scaling: rate limiting, horizontal scaling to a measured need, "microservices scale better" as the misconception) and 10 (distributed systems: monoliths against microservices, and why a chain of network calls fails more often than one program). Borrowed set piece: Hooli's Nucleus, the copycat built by hundreds of engineers that collapses at its big launch, and Gavin Belson on stage with his spiritual adviser. The lines are in `data/season.json`.

### Continuity

Episode 9 ended with Mack telling Hubbub how Forkcast works, with slides. The starting board is Episode 9's solution with its hotfix: cloud, three small app servers with sessions in Redis, the cache, the CDN, the queue, the index, the AI cache, and the board's dashboard on the analytics database copying hourly, with error alerts (the copy job fixed). Nothing on the board changes, so `changed` is empty and `cases.gd`'s continuity check passes as it stands. The budget does change: the board lets Mack go in the cold open (the show's Jack Barker is ousted and Richard reinstated), so the burn drops back to $80k.

The board gains a box that isn't ours: **HubbubBot**, Hubbub's scraper, drawn at the bottom left and wired to the load balancer (`"scraper": true` on the board; Episode 11 can drop it with `changed`).

### Cold open

Wednesday, 10am, Hubbub's keynote hall (a new backdrop: a glossy stage, a giant gradient screen, a zen garden and a bonsai). Galen Brightwater, serene, in cashmere, prayer beads at his wrist, announces Hubbub Dine: four hundred engineers, two hundred and twelve microservices, live this Friday at six, when he'll book the whole hall a table on stage. Danesh: that's literally Forkcast. Ricky: why does he know our restaurants? Gilroy: a man with silver hair and a boat gave him the slides. Veronica: the board let Mack go this morning; you're CEO again. Ulrich has had tea with Galen's spiritual adviser, who says Forkcast needs microservices. Gerard has brought a bag for Ricky; he brings a bag to everything now.

Title card: **HUBBUB DINE**.

### Brief

Veronica: Friday at six a million people watch Galen's keynote with a dinner app open, and some will try ours. Bookings have to work while the internet compares the two: nineteen in twenty, not nine in ten.

- **Budget**: $1.05M in the bank, $80k a month, so 12.9 months of runway on the board as it stands. 16 hours to build.
- **Goal**: up all night, pages under 3 seconds, nineteen bookings in twenty work, nineteen searches in twenty answered.

### Aleister's pull request: "Beat Hubbub tonight"

| Card | By | Time | Monthly | What it really does | The takes |
| --- | --- | --- | --- | --- | --- |
| **More servers**, set to six | Aleister | 0.5h | +$150 a server | Horizontal scaling: needed, with a bad default. Its dial runs from four to eight; Aleister picked six, double what we have, for a night nobody has measured | Danesh for (spare everything); Veronica: how many is "everyone"? |
| **Clone the clone**: voice booking, loyalty, a metaverse table | Aleister | 30h | — | Feature parity with a copycat. Can't be built in 16 hours, and it wouldn't keep the site up | Danesh: it's basically poetry; Gerard's previous company copied a rival into the ground |
| **8 services**: microservices on a container cluster | Ulrich (wrong) | 12h | +$4,000 | Every request now crosses several network calls between services. A booking crosses eight; each works 99 times in 100, so all eight together work about 92 times in 100, and every call adds a little delay and a little work | Ulrich: two hundred and twelve for Hubbub, eight is humble; Gilroy: every arrow is a network call, and any call can fail |
| **Rate limit API** (from an ask) | Aleister | 1h | — | Counts each client's requests at the front door and turns away the excess with a 429. Aleister's default, a thousand a minute per client, lets most of the scraper through | Gilroy for (sixty machines, a fair share each); Danesh: some diners tap through thirty restaurants a minute |

Ulrich is wrong this time, which leaves him right once in three across the prototype, as the season wants. His card is Module 9's misconception, "microservices scale better", and he got it from the competitor's guru: SHOW.md gives Galen "microservices for everything, copy the competitor".

### The asks

| Ask | Answer | Effect |
| --- | --- | --- |
| **Who's calling our API?** | Gilroy: since the keynote, sixty machines in one cloud, each asking for tonight's tables about fifteen hundred times a minute, calling themselves HubbubBot. Ricky: that's how Hubbub Dine knows the city | Adds **Rate limit API** (1h, free) |
| **Where's the bottleneck?** | Aleister: last Friday the app servers were at half capacity at the peak, the database at a tenth. Ricky: three servers carry about thirty thousand diners, four about forty, if HubbubBot doesn't eat them first. Veronica: if Hubbub Dine falls over, its audience comes here, thirty-five thousand at once | Just facts: four servers |
| **What if one service fails?** | Gilroy: a booking through eight services needs all eight; at ninety-nine in a hundred each, that's about ninety-two. Gerard: and somebody has to work out where | Just facts: the chain multiplies |
| **What will this cost at 10x traffic?** | Veronica: $150 a server, $4,000 for the cluster, and every HubbubBot request is one we pay to answer | Just facts |
| **Make it bot-proof.** (decoy) | Aleister, delighted | Adds **Add CAPTCHAs** (2h): a puzzle before every search and booking. It stops most of the scraper, and some diners give up |
| **Make it web-scale.** (decoy) | Aleister: you remembered! | Adds **Shard by city** (12h, +$800), Episode 8's decoy again: the database is at a fraction of its capacity |

### The dials

- **App servers** (with the card): four to eight; Aleister's default six.
- **Rate limit, per client** (with the card, on the load balancer): 10, 100 or 1,000 requests a minute; Aleister's default 1,000.

### The live moment: Friday, 5pm to 11pm

| Clock | Tick | What happens |
| --- | --- | --- |
| 5:00pm | 0 | 3,000 diners. Galen's keynote starts at six |
| 6:00pm | 60 | **Hubbub Dine goes live, and so does HubbubBot**: sixty machines at 1,500 requests a minute each, 1,500 a second for tonight's tables, every one a combination nobody else asks for, so the cache never has it. Without a rate limit the app servers drown at once |
| 7:00pm | 120 | 15,000 diners, as last Friday |
| 8:00pm | 180 | **Hubbub Dine falls over on stage.** Its audience comes to Forkcast: 34,000 diners by 8:15. **Hotfix**: Aleister offers two more app servers ($300 a month). Four servers already carry it; three don't |
| 8:00 to 10:30pm | 180 to 330 | The plateau. With microservices, one booking in thirteen fails somewhere between the services. With the limit at ten a minute, busy diners get 429s. With CAPTCHAs, diners give up |
| 11:00pm | 360 | 3,000 diners. End |

The solution's night: the rate limit at a hundred a minute lets each of HubbubBot's sixty machines through a hundred times a minute, a hundred requests a second in all, and turns the other 1,400 a second away at the door for almost no work; real diners, at a few requests a minute and thirty at the most, never meet it. Four small servers carry the 34,000 at about 80%. Bookings work 98.8% of the time, pages stay under half a second.

These are the results from `tests/cases.gd`:

| Plan | Result |
| --- | --- |
| Do nothing | HubbubBot swamps three servers from 6pm: down for 235 minutes, fails everything |
| Aleister's PR as proposed | 42.5 hours: can't merge |
| Minus the clone (the bot's take one) | Fits, and fails: six servers, no rate limit and microservices. The scraper swamps the app after the surge, and the service chain fails bookings (60% work). 12.35 months |
| No rate limit, six servers | HubbubBot and the surge max the app out: pages at 5 seconds, fails |
| No rate limit, seven or eight servers | Passes, at 13.04 or 13.02: paying $450 to $600 a month to serve Hubbub's scraper. Misses Lean |
| Rate limit cut from the solution | The scraper: down for 95 minutes, fails |
| Rate limit at 1,000 a minute | 1,000 scrapes a second get through: the app maxes out at the surge, fails |
| Rate limit at 10 a minute | HubbubBot stops, and so do busy diners: 79% of bookings work, fails |
| Keep Ulrich's microservices | One booking in thirteen fails between services, and the extra calls max out the app: 67% of bookings, fails, and $4,000 a month (12.41) |
| CAPTCHAs | The scraper mostly stops; 15% of searches and bookings give up: fails |
| Three servers (cut the servers card) | Fine until Hubbub Dine falls over, then maxed out: fails |
| The solution: rate limit at 100 a minute, four app servers, hotfix cut | 13.113 months of runway; par 13.11 |
| Five, six, seven or eight servers, or the hotfix kept, or three servers plus the hotfix | Passes, with less runway: misses Lean |
| The solution plus shards | Passes, at 12.99: misses Lean |

### Postmortem

New findings: Hubbub's scraper swamped the app servers ("no rate limit, or one set too high"); the rate limit turned away real diners; bookings failed somewhere between the services ("microservices: every call between them can fail"); diners gave up at the CAPTCHA. The generic ones (app servers or database maxed out, the model provider's rate limit, overbuilt) carry over.

Marks: Live, Lean (13.11 months or better), Ulrich (cut the microservices).

### Lesson cards and cliffhanger

Two codex cards: **Rate limiting** (cap each client's requests a minute and turn the rest away with a 429, so one greedy client can't use up the app for everyone; set the cap above what your busiest real users do) and **Monolith and microservices** (small services let separate teams build and deploy alone, at the price of more moving parts, calls over the network, delay that adds up along a chain, harder testing; one app is simpler).

Cliffhanger: Saturday morning, the kitchen. Veronica: forty restaurants left Hubbub Dine last night and signed with Forkcast, on one condition: deposits, real money, through their own booking systems, so no-shows pay, by next Friday. Gilroy: money, moving between computers that don't trust each other, over a network. Twice. Gerard: I'll get the bag. (Episode 11: Charged Twice.)

### Checking it against the show

Season 2's Nucleus: Gavin Belson pours hundreds of Hooli engineers into a copy of Pied Piper, announces it with messianic grandeur, and it collapses at launch, while the small team's product holds. Here: Galen's keynote, his spiritual adviser (unseen, but having tea with Ulrich, who fits right in), the copycat with two hundred and twelve microservices, the boast about booking the hall a table live on stage, and the on-stage collapse while Forkcast stays up. The board ousting the adult CEO and restoring the founder is the show's arc too (Jack Barker's exit). Hubbub learning the product from Mack, and scraping it, are ours, built on the show's idea that Hooli copies by brute force. Ricky not quite throwing up, with Gerard now carrying a bag everywhere, is the running gag moved on a step. If a fan wouldn't recognise Galen's keynote and the collapse, it's drifted; they would.

## Episode 11 on paper: *Charged Twice*

Stage 6, Module 10 (distributed systems: the unreliable network, partial failure, retries and idempotency, race conditions, consistency), with Module 6's transactions doing the fixing. Borrowed set piece: PiperNet, the founder's decentralised internet spread across thousands of phones, which works beautifully in a room and badly at scale. The lines are in `data/season.json`.

### Continuity

Episode 10 ended with forty restaurants leaving Hubbub Dine for Forkcast on one condition: deposits, by Friday. The starting board is Episode 10's solution with its hotfix cut: cloud, four small app servers with sessions in Redis, the cache, the CDN, the queue, the index, the AI cache, the board's dashboard on the analytics database copying hourly, error alerts, and the rate limit at a hundred a minute per client. One thing changes: HubbubBot leaves the board (`"changed": ["scraper"]`), and Gerard says why in the cold open: it stopped on Saturday, and Hubbub Dine is "pausing to reimagine". The rate limit stays; with no scraper it turns nobody away.

### Cold open

Monday, 6pm, a trattoria in North Beach, at the host stand (a new backdrop: checked tablecloths, candles in bottles, a beige booking-system box under the stand). Veronica has brought the team to meet one of the forty owners: be normal. Gilroy admires the booking system's fax modem. Ricky hasn't slept: he has everyone put their phones on the table and shows them ForkNet, where every phone keeps its own copy of tonight's tables and passes each booking to the phones nearby, with no servers in the middle. Danesh books table nine on his phone and it appears on Gerard's; it's actually beautiful. Gilroy: five phones, one room, one wifi; Friday is sixteen thousand phones on buses and in tunnels. Ulrich has been saying "decentralised" for years, mostly at parties, and will take his ten percent in ForkNet. Ricky: it worked every single time.

Title card: **CHARGED TWICE**.

### Brief

Veronica: Friday the forty go live with deposits, twenty dollars a head, taken when you book and kept if you don't show; a normal busy Friday, sixteen thousand diners at the peak; nobody pays twice and nobody gets a table someone else already has. Aleister has a plan called Take Their Money (working title), and payments can't fail now: it made them retry until they work.

- **Budget**: $1.0M in the bank, $80k a month, so 12.3 months of runway on the board as it stands. 12 hours to build.
- **Goal**: up all night, pages under 3 seconds, nineteen bookings in twenty work, deposits go through (19 in 20), nobody charged wrongly (twice, or for a booking we said failed), and no table booked twice.

### Aleister's pull request: "Take deposits by Friday"

| Card | By | Time | Monthly | What it really does | The takes |
| --- | --- | --- | --- | --- | --- |
| **Take deposits**, retrying on a timeout | Aleister | 3h | 90¢ a deposit | Needed: the goal is the deposits. Each one is a call to the payment provider over the network, and its default is to ask again when the provider doesn't answer in time. Some of the calls that time out went through, so a plain retry charges those diners twice | Veronica for (this is the business now); Gilroy: some calls won't come back, and some will come back late, which is worse |
| **ForkNet**: tonight's tables on the diners' phones | Ricky | 6h | — | A decentralised network: every phone keeps a copy and gossips each booking to its neighbours. A booking takes log₂(phones) rounds to reach everyone, seven seconds at sixteen thousand phones, and in that window two phones can both sell the last table, whatever the database does; phones that drop into a tunnel lose bookings | Ricky: it worked on all five phones, every time; Gilroy: the copies disagree until the gossip catches up |
| **ForkCoin**: deposits in our own cryptocurrency | Aleister | 24h | — | The episode's too-big card. Can't be built in 12 hours, and the restaurants asked for dollars | Danesh: if we have a coin, I'm early; Veronica: dollars |
| **Deposit IDs**: one number per deposit, the same on every try | Ulrich (right) | 1h | — | An idempotency key. The provider remembers each key and answers a repeat with the first result instead of charging again | Ulrich: at Aviato every payment had a reference number; Danesh: the provider already gives every charge an ID (true, but it comes back in the answer, which is the part that gets lost) |
| **Hold the table** (from an ask) | Aleister | 1h | — | Check the table is free and hold it in one transaction before taking the deposit; let it go if the deposit fails. Closes the race | Ricky: anyone can slip into that second and a half; Gerard's two weddings in one hall |

Ulrich is right this time, his second in four, which keeps him near a third across the season if he's wrong in the next two. It's a real judgement: his line is a boast about Aviato, Danesh's objection sounds sensible, and only the asks show why a number of our own matters. ForkNet is the misconception the episode is built on: spreading it over more computers doesn't make it more reliable, it makes the copies disagree.

### The asks

| Ask | Answer | Effect |
| --- | --- | --- |
| **What if this is sent twice?** | Aleister: then it sends it again. Gilroy: when a call times out we don't know if it worked; some did, and only the answer was lost; retry those and the provider takes the deposit twice. Ricky: unless every deposit carries its own key, the same one on every retry | Just facts: Ulrich's numbers are an idempotency key |
| **What if the provider is down?** | Gilroy: it won't be down, it'll be slow: one call in a hundred early, one in fifty in the rush, one in seventeen at the peak. Veronica: about half of those went through anyway, so telling them it failed means they paid for a table we say they haven't got | Just facts: giving up on a timeout is wrong too |
| **Can two people book the last table?** | Ricky: we check, wait for the deposit, then book; two parties in that gap both get it. Gilroy: almost never on a quiet night; it grows with the square of the traffic on the busy tables | Adds **Hold the table** (1h) |
| **What will this cost at 10x traffic?** | Veronica: ninety cents a deposit; every wrong charge about forty dollars (refund, support, apology); every party turned away a hundred and fifty (dinner on us) | Just facts |
| **Make it never fail.** (decoy) | Aleister, delighted | Adds **Backup provider** (2h, +$100): on a timeout, charge through a second provider, which has never seen our first provider's keys, so a timed-out deposit that went through is taken again |
| **Make it web-scale.** (decoy) | Aleister: our tradition | Adds **Shard by city** (12h): doesn't fit beside the deposits |

### The dials

- **Payments: on a timeout** (with the deposits card): give up, or try again (Aleister's default).

### The live moment: Friday, 5pm to 11pm

| Clock | Tick | What happens |
| --- | --- | --- |
| 5:00pm | 0 | 3,000 diners. Deposits are live at the forty; four in ten bookings take one. One deposit call in a hundred times out |
| 6:00 to 7:00pm | 60 to 120 | The rush builds to 16,000 diners. One call in fifty times out. Without a key, every retried timeout that had gone through is a second charge; with retries off, a charge for a table we said failed. Without the hold, two parties check the same last table inside the second and a half we spend waiting for the deposit |
| 8:00pm | 180 | **The payment provider is slow**: one call in seventeen times out for fifty minutes. **Hotfix**: Aleister offers to stop retrying until it calms down, "so nobody gets charged twice". It's the misconception "errors mean it didn't happen": with the key, the retries were safe, and turning them off charges diners for tables they're told they didn't get |
| 8:20 to 10pm | 200 to 300 | The plateau. On ForkNet, bookings gossip for seven seconds across sixteen thousand phones, the last tables sell several times over, and a twentieth of bookings vanish into tunnels |
| 11:00pm | 360 | 3,000 diners. End |

The solution's night: deposits with retries and Ulrich's numbers, and the table held in a transaction before the money moves. Of about 6,500 deposits, about 190 time out and are retried; the provider recognises the ninety-four that had gone through and answers them with the first result. The app servers peak at about a third of their capacity and the database under a tenth. Nobody is charged twice, no table is sold twice, and 99.9% of deposits go through.

These are the results from `tests/cases.gd`:

| Plan | Result |
| --- | --- |
| Do nothing | No deposits: the forty restaurants walk. Fails |
| Aleister's PR as proposed | 34 hours: can't merge |
| Minus ForkCoin (the bot's take one) | Fits, and fails: ForkNet books 151 tables twice and loses one booking in twenty (94% work). 12.06 months |
| The solution without Ulrich's numbers | Retries charge 94 diners twice: fails, 12.30 |
| The solution with retries off ("give up") | 94 diners charged for tables we said they didn't get: fails, 12.30 |
| The solution with the hotfix kept | Retries off from 8pm: 64 charged for nothing: fails, 12.31 |
| The solution plus the backup provider | 94 charged by both providers: fails, 12.28 |
| The solution without the hold (cut the transaction) | 34 tables booked twice: fails, 12.28 |
| **Staging** (a tenth of the traffic) without the hold | Passes: a hundredth of the double bookings, a third of one, which rounds to nobody. That's Module 10's "it worked when I tested it" |
| Staging without Ulrich's numbers | Fails: nine diners charged twice. Timeouts happen at the same rate on a quiet night, there are just fewer of them; staging catches this one and misses the race |
| Shards | 12 hours on top of the deposits: can't merge |
| The solution: deposits retrying with Ulrich's numbers, hold the table, hotfix cut | 12.343 months of runway; par 12.34 |

### Postmortem

New findings: no deposits; diners charged twice ("retries without an idempotency key"); diners who paid for tables we said they didn't get ("a timeout means you don't know"); charged by both providers ("failover without idempotency"); two parties at one table ("a race condition; the fix is a transaction"); ForkNet's phones disagreeing ("eventual consistency: copies agree later, not now"). The generic ones (app servers or database maxed out, the model provider's rate limit, overbuilt) carry over. The spreadsheet adds a line: charged wrongly, booked twice.

Marks: Live, Lean (12.34 months or better), Ulrich (keep his deposit IDs).

### Lesson cards and cliffhanger

Two codex cards: **Retries and idempotency** (a timed-out request may have worked with only the answer lost, so asking again can do it twice; an idempotency key, the same on every retry, lets the server spot the repeat and return the first result) and **Race conditions and transactions** (separate check and book steps let two people both be told yes; lock the row in a transaction while you check and book, and the second waits).

Cliffhanger: Saturday morning, the kitchen. Gerard: every deposit taken once, every table sat once, and a spreadsheet of the spreadsheet. Veronica: then why is the AI bill four thousand dollars since midnight? Gilroy: someone's using our model key; Melon put it in a public repository on Tuesday, with a helpful README. Veronica: and Hubbub's lawyers have sent forty pages; page one says Forkcast belongs to them. Ricky is going to be sick. (Episode 12: The Leak.)

### Checking it against the show

Seasons 4 and 5's PiperNet: Richard's vision of a new internet with no servers, running on everyone's phones, demonstrated to friends where it works perfectly, and the engineers' dread of what it does at scale (in the show, nodes dropping off and a takeover once someone controls enough of the network). Here: Ricky up all night, the phones on the table, Danesh won over against his will, Gilroy's flat arithmetic about buses and tunnels, Ulrich claiming a share of an idea that isn't his. ForkCoin is the show's season 5 coin offering, moved forward. The double charges and the last table are ours, built on the show's running idea that the product works in the demo and breaks in the world. If a fan wouldn't recognise Ricky's phones on the table, it's drifted; they would.

## How the loop covers the season

Every episode uses the same loop; what changes is which pieces, asks, behaviours and goals it switches on. A first sketch, to be walked on paper like Episode 8 before each is built:

| # | Episode | The PR's trap | What the live moment tests |
| --- | --- | --- | --- |
| 1 | Pilot | Built from a vague request: a food-photo social network instead of a concierge | Walter's test diner asks for "quiet for six on Friday". Also the pilot's choice: Galen's buyout ends in a flash-forward of you paid to do nothing on Hubbub's roof, then "take two" |
| 2 | The Whiteboard | A full backend and database for a landing page | Waitlist sign-ups during Ulrich's party; a bad change with and without Git to roll back |
| 3 | Tabs and Spaces | Each box's language: Danesh's fashionable pick, Gilroy's fast one | Build time to the deadline, bugs the AI makes in less common languages, types catching them; Veronica's question as a marimo notebook job |
| 4 | Demo Day | The price rule and the model key in the frontend | The investor's assistant changes the price in the browser; the demo on a phone |
| 5 | The Spreadsheet | Ulrich's spreadsheet kept as the database | Two hosts booking at once lose a booking; a backup that's never been restored |
| 6 | Log In | A home-made login; no ownership check on bookings | The focus group: a curious diner changes the number in the URL |
| 7 | Launch Party | Deploying from Melon's laptop | A bad change mid-party; staging, tests and error tracking catch it, or don't |
| 8 | Viral | Above | Above |
| 9 | The Board Meeting | Dashboards on the live database; Mack's box | Friday bookings crawl while the board refreshes its dashboards |
| 10 | Hubbub Dine | Microservices because Hubbub has them; no rate limit | Hubbub's clone demos beside yours and collapses; Hubbub's scraper |
| 11 | Charged Twice | Retries without idempotency keys; check-then-book | Staging passes; at Friday volume, timeouts and races charge and book twice |
| 12 | The Leak | The key in the frontend bundle and the Git history; a package Aleister invented | A scanning bot finds the key; the bill and the lawsuit |
| 13 | The Conference | An agent with every tool and no confirmation; no grounding | Live on stage: a planted review hijacks the agent |
| 14 | Finale | The whole capstone diagram at once | The season's traffic replayed: every box must earn its place |

## Prototype layout

Following Curb's (step 2 of the handoff):

- `data/pieces.json`, `data/season.json` (Episode 8 first).
- `sim/`: the flow model in plain GDScript with no scene dependencies, so tests run it headless.
- `scenes/episode.gd`: one script that builds any episode from the data: cold open, title card, board, PR, live moment, postmortem.
- `ui/`: the board, the PR panel, dialogue, the live overlay, the sideways card.
- `tests/smoke.tscn` (every episode loads), `tests/cases.gd` (the per-episode checks above, including the full search), `tests/coverage.gd`, `tests/bot.tscn`.

## Still open

- The show-style score with a homage name, or just the marks.
- Episodes 1 to 7 and 12 to 14 in detail (walk each like Episodes 8 to 11 first).
- Whether there's a hub between episodes (the house) or just a season screen of episode thumbnails, as on a streaming service.
- The title sequence's company list (from the handoff).
- Music cues: the sting, the planning loop, the live-moment track that intensifies with load.
