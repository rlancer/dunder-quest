# Game design: Mission Silicon

The design doc for the fourth game, written from [CURRICULUM.md](CURRICULUM.md) (what it teaches) and [SHOW.md](SHOW.md) (how the homage carries it). It settles the core loop, the simulation, the episode data, the phone screen and the checks, then walks Episode 8 (*Viral*) through end to end on paper. The numbers here are first-pass values for the prototype to tune; the shapes (what makes what slower, costlier or wrong) are meant to be final.

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
| **Cache** | Redis, CDN, model-answer cache | Per data row: a TTL and a scope (shared, per user, off). For a row with request rate λ over K distinct keys and TTL T, the hit rate is x / (1 + x), with x = λT / K (the exact result for a TTL cache with random arrivals). Hits skip everything behind the cache | |
| **Staleness** | Cache rows of data that changes | If each key changes at rate μ, the share of hits that are out of date is 1 − (1 − e^(−μT)) / (μT). A stale "free" table that's actually taken gives the diner "sorry, just taken" at booking time | `stale_tables` |
| **Shared per-user data** | A cache row of per-user data with shared scope | Every hit shows one diner another's data. Fails the goal outright | `cache_leak` |
| **Sessions** | App servers | Sessions in server memory with more than one server behind the load balancer: each request lands on a server that doesn't know the diner with probability 1 − 1/N, logging them out | `stateless` |
| **Connection limit** | Database | Each app server holds a pool of 10 connections; Postgres allows 100 by default. Servers beyond the limit get errors on every database call | `too_many_connections` |
| **Rate limit** | Model API, payment provider | Calls above the provider's per-minute limit fail with HTTP 429 | `rate_limited` |
| **Queue** | Queue + worker | Requests that can wait cost the app almost nothing to enqueue; a worker drains them at its own rate. The backlog shows as a literal line of tiny diners | `no_queue` (when a spike hit without one) |
| **Load balancer** | Appears by itself when a box has more than one server | Splits load evenly | |
| **Autoscale** | App servers, serverless | Server count follows load between a min and a max, with a warm-up delay | |
| **Network faults** | Outside services, scripted per episode | A share of calls time out; of those, a share actually succeeded and only the reply was lost | `timeout_unknown` |
| **Retries** | Calls to outside services | Off: timeouts are failures. On: a retry repeats the call, so the ones that had succeeded happen twice. On with an idempotency key: repeats are recognised and ignored | `double_charge` |
| **Race** | Booking the last table | Check-then-book in two steps lets two parties get the same table, at a rate that grows with the square of booking traffic on hot tables. A transaction closes the gap | `double_booking` |
| **Analytics on the live database** | Database | Dashboard queries are huge scans; run on the main database they take capacity from bookings | `olap_on_oltp` |
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
| **CDN for photos and pages** | Aleister | 1h | +$50 | Photos, scripts and pages served from the edge, not the app | Danesh for; Gerard asks what happens when a menu changes (it's fine: an hour's TTL on menus) |
| **Queue sign-ups and welcome emails** | Aleister | 3h | +$50 | The 8pm sign-up burst no longer hits the app head-on (password hashing is deliberately slow, and the email is a slow outside call) | Gerard for, earnestly; Danesh: nobody needs their welcome email this second |
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
| 8:00pm | 180 | **The chef posts again.** 24,000 diners, and a third of the night's 50,000 sign-ups in half an hour. Without the queue, sign-ups swamp the app. Without the AI cache, searches pass the provider's limit and fail with 429s, and the bill races |
| 8:00pm | 180 | **Hotfix**, the moment the post lands. Aleister: "Traffic just doubled! Add another app server? It's $300 a month." It helps only if sessions are in Redis (otherwise diners start getting logged out) and only if the database isn't the real bottleneck |
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
- Episodes 1 to 7 and 9 to 14 in detail (walk each like Episode 8 first).
- Whether there's a hub between episodes (the house) or just a season screen of episode thumbnails, as on a streaming service.
- The title sequence's company list (from the handoff).
- Music cues: the sting, the planning loop, the live-moment track that intensifies with load.
