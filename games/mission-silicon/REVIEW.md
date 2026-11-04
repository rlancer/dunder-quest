# Technical review: Episode 8 (*Viral*)

Handoff step 5. Every technical claim a player can see in Episode 8 (`data/season.json`, `data/pieces.json`, the board's bubbles and the screens' fixed text), plus the CURRICULUM.md modules it covers (7, Caching; 9, Scaling), checked against the curriculum's rule: **simplify, never falsify**. The simulation's numbers are illustrative; only their shapes have to be real. Reviewed November 2026.

Verdicts: **True** (stands as written), **Fixed** (was wrong or misleading; changed), **Narrative** (a character's opinion or the story, not a claim the game makes; checked that the game doesn't endorse anything false).

## Sources

| Key | Source |
| --- | --- |
| MDN | [HTTP caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Caching), MDN: fresh and stale, `max-age`, private vs shared caches, personalised responses need `private` |
| AZ | [Design to scale out](https://learn.microsoft.com/en-us/azure/architecture/guide/design-principles/scale-out), Azure Architecture Center: identify bottlenecks first ("if your backend database is the bottleneck, it won't help to add more web servers"), avoid session stickiness and in-memory session state, offload emails to async work, queues absorb spikes |
| 12F | [VI. Processes](https://12factor.net/processes), The Twelve-Factor App: stateless processes; session state in a time-expiring store such as Redis; sticky sessions should never be relied on |
| PG | [Connections and authentication](https://www.postgresql.org/docs/current/runtime-config-connection.html), PostgreSQL docs: `max_connections` "is typically 100"; at most that many connections at once, last few reserved for superusers |
| PGI | [Indexes](https://www.postgresql.org/docs/current/indexes-intro.html), PostgreSQL docs: without an index the system scans the whole table; an index finds matching rows directly |
| PGB | [PgBouncer](https://www.pgbouncer.org/), a connection pooler for PostgreSQL |
| AP | [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching), Anthropic: cache reads at 0.1x base input price (less on some models), the cached part is the prompt's prefix and must match exactly |
| AR | [Rate limits](https://platform.claude.com/docs/en/api/rate-limits), Anthropic: limits per minute (requests and tokens), exceeding them returns HTTP 429; prompt caching raises effective throughput |
| 429 | [429 Too Many Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/429), MDN |
| GDPR | [GDPR Article 4(12)](https://gdpr-info.eu/art-4-gdpr/): a personal data breach includes accidental unauthorised disclosure of personal data |
| TTL | Jung, Berger, Balakrishnan, *Modeling TTL-based Internet caches*, IEEE INFOCOM 2003: per-key hit rate λT/(1+λT) under Poisson arrivals |

## The simulation's shapes (GAME.md, sim/sim.gd)

| Shape | Verdict | Notes |
| --- | --- | --- |
| Latency `base / (1 − u)` below capacity, backlog above | True | The M/M/1 response-time curve; standard queueing |
| Cache hit rate x/(1+x), x = λT/K | True, doc **Fixed** | Exact for a TTL cache filled on a miss with Poisson arrivals and evenly popular keys (TTL). GAME.md now says "evenly popular keys" and that real, skewed traffic only raises the hit rate |
| Stale share 1 − (1 − e^(−μT))/(μT) | True | Hits fall evenly over the TTL window; each key changes as a Poisson process at μ; averaging P(changed by age a) over a ∈ [0, T] gives this |
| Shared copy of per-user data leaks on every hit | True | MDN: personalised responses belong in a private cache; same for an app cache whose key leaves out the user |
| Sessions in memory, N servers: logged out with probability 1 − 1/N | True | With even (non-sticky) balancing. AZ and 12F both say keep sessions out of server memory |
| 10 connections per server against Postgres's 100 | True | PG: default typically 100 (managed hosts often size it by instance memory; the game's text now says "our Postgres") |
| Calls above a per-minute cap fail with 429 | True | AR, 429. Real providers also cap tokens per minute; the game counts calls only, a lossy but not false simplification |
| Prompt caching bills the fixed part at a tenth | True | AP: 0.1x on most models (cache writes cost 1.25x, ignored here since the cache stays warm all night) |
| Scan cost grows with rows; an index makes it constant | True | PGI (an index lookup grows very slowly, roughly log n; "constant" is fine at this scale) |
| Garage server overheats and shuts down | True | Thermal shutdown is a real protective behaviour of server hardware |

## Episode 8 text

### Cold open, brief, cliffhanger

All Narrative (the viral post, the garage, sign-up counts). Nothing technical claimed beyond "the garage won't make it", which the simulation bears out.

### Pull request cards (`plain`) and takes

| Card | Claim | Verdict | Change |
| --- | --- | --- | --- |
| Move to the cloud | Rent an app server and managed Postgres | True | |
| Kubernetes | Twelve services on a container cluster | True (as a description of the proposal); Ricky's and Gilroy's takes Narrative, and the game judges against it | |
| Add a cache | "the database isn't asked the same thing twice" | **Fixed** | A TTL cache still asks once per key per TTL. Now "over and over" |
| Add a cache, takes | Danesh: caches make everything faster | Narrative | The misconception the curriculum names; Gilroy rebuts it and the night punishes it |
| CDN | "Serve photos, scripts and pages from servers near each diner" | **Fixed** | Forkcast's pages hold per-diner data, and the simulation only moves photos and scripts off the app. Now "photos and scripts". Gerard's take was about menus going stale on the CDN; now about photos |
| Queue sign-ups | Queue "new sign-ups"; Gerard: password hashing is slow on purpose, so queue it | **Fixed** | Hashing is deliberately slow (true), but deferring it to a worker means putting plain-text passwords in a queue, which is a security mistake, and the account wouldn't exist until the worker ran. The slow, deferrable work is the welcome email, an outside call that holds a server (AZ: "tasks like sending emails" are what to offload). Label now "Queue sign-up work"; text, Gerard's take, the corner line and the postmortem finding now about welcome emails. The simulation's numbers are unchanged |
| Rewrite in Rust | Rust is fast; Gilroy: the app is waiting on the database | True | AZ (bottlenecks); the bottleneck ask shows the database at 100% |
| Forty servers | Every one talks to the same database | True | PG |
| Add an index | Index on bookings by restaurant and night, so it doesn't read every booking | True | PGI. Ricky's "like the index in a book" is the docs' own analogy |
| Cache AI answers | Answer cache plus prompt caching, "the long fixed part of each prompt billed at a fraction" | **Fixed** (tightened) | AP: only an identical prefix is cached. Now "the long fixed start of each prompt" |
| Shard by city | Split the database by city | True; Aleister's and Gerard's takes Narrative | |
| Biggest model | Five times the price per answer | True as illustration | Top-tier models have cost around five times mid-tier per token |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Where's the bottleneck? | True | Full scan of every booking; index is the fix (PGI, AZ) |
| How stale can this be? | True | Matches the data: menus 0.04 changes an hour (about daily), tables 30 an hour (every two minutes), my bookings per person |
| Is this cache per user or shared? | True | MDN |
| What will this cost at 10x? | True | Providers cap calls a minute (AR). "Four fifths of the bill" is Narrative |
| Make it web-scale / Use the smartest model (decoys) | Narrative | The game judges them as overbuilt |

### Dials, hotfix, live moment

| Item | Verdict | Change |
| --- | --- | --- |
| Sessions in memory or in Redis | True | 12F names Redis for session state |
| TTL options, shared or per user | True | |
| Hotfix: "add another app server? It's $300 a month." | **Fixed** | The server added is the size already chosen; at the solution's small size it's $150, so the line was wrong in the winning plan. The line now carries `{monthly}`, filled in by `scenes/episode.gd` from what keeping the hotfix adds to the bill |
| Banners (12,000 diners, the post, easing off) | True | Match `live.diners` |
| Corner: stale tables, "People are booking tables that were booked a minute ago" | **Fixed** | A stale table fails at booking time ("sorry, just taken"); they don't get it. Now "People keep picking tables that went a minute ago." |
| Corner: "Fifteen thousand sign-ups, all hashing passwords at once." | **Fixed** | Now "all waiting on welcome emails" (see the queue card) |
| Other corner lines | True or Narrative | Forty servers × 10 vs 100 connections is PG; 429s is AR |
| Bubbles (`ui/board.gd`): "Full table scan", "Too many connections", "429: rate limited", "Logged out?!" | True | PG's own error is "too many clients already"; "too many connections" is the common name (MySQL's literal one). Kept |
| Staging: "Some problems only show up at full load." | True | |

### Postmortem findings

| Tag | Verdict | Change |
| --- | --- | --- |
| garage_melt (single point of failure) | True | |
| full_scan | True | PGI; Postgres calls it a sequential scan, "full table scan" is the general term |
| no_cache | True | |
| db_overload, title "The database ran out of room." | **Fixed** | "Room" reads as disk space; the problem is throughput. Now "The database couldn't keep up." |
| app_overload, "When the chef posted again, traffic doubled and the app servers couldn't keep up." | **Fixed** | The finding also fires for plans that overload before the post (one small server, say), where it was untrue. Now "More traffic arrived than the app servers could handle, so pages crawled and then failed." |
| no_cdn ("photos and scripts are most of what a page weighs") | True | Images and JavaScript dominate page weight on the web |
| no_queue | **Fixed** | Was about deferring password hashing; now the welcome email, a slow call to an email service holding a server |
| stale_tables | True | |
| cache_leak, "the first person's page was handed to everyone after them" | **Fixed** | With a TTL the copy expires and the next diner's page takes over. Now "one diner's page was handed to everyone who came next". "That's a data breach": True (GDPR) |
| stateless | True | 12F, AZ |
| too_many_connections, "Postgres allows a hundred" | **Fixed** | A default, and managed hosts often set it otherwise: now "our Postgres allows a hundred". Term now also names the real fix, "a connection pooler shares them" (PGB; the curriculum's Module 9 covers pooling). Tell-your-AI kept: the lesson is Ulrich's forty servers |
| rate_limited (429) | True | AR, 429 |
| ai_bill, big_model, overbuilt | True | Fire only when the bill really is five figures, the big model was kept, or the plan passed below par |

### Codex cards and sources

| Card | Verdict | Change |
| --- | --- | --- |
| Cache: "per-user data never goes in a shared cache" | **Fixed** | Redis is shared by every server, and per-user data in it is fine when keyed by user (the solution does exactly that). Now "per-user data is cached per user, never shared". Source MDN: works, supports freshness, staleness and private vs shared |
| Scaling: load balancing "only works if they're stateless" | **Fixed** | Sticky sessions do make it work, badly; the true rule is that any server should be able to take any request. Now "kept stateless so any of them can take any request". Source changed from 12F (stateless only) to AZ, which supports every part of the card: bottleneck first, scale out, no stickiness |

### `data/pieces.json` (shown when a box is tapped)

| Piece | Verdict | Change |
| --- | --- | --- |
| Load balancer, "Hands each request to whichever server is free." | **Fixed** | Balancers use round robin, least connections and others; the simulation splits evenly. Now "Hands each request to one of the servers, spreading the load." |
| Redis, "so the database isn't asked twice" | **Fixed** | Now "again and again" (as the cache card) |
| CDN, "photos and pages on servers near every diner" | **Fixed** | Now "photos and scripts on servers close to diners" |
| Model API, "paid per call" | **Fixed** | Model APIs bill by the token (AP, curriculum Module 13). Now "paid by the token"; the simulation's per-call price stands for an average call's tokens |
| Others (garage, app server, Postgres, queue, diners) | True | |

## CURRICULUM.md, Modules 7 and 9

| Claim | Verdict | Change |
| --- | --- | --- |
| Where caches live; hit and miss; TTL and invalidation | True | MDN |
| "A user's bookings: never in a shared cache" | **Fixed** | Now "cached per user or not at all, never as one shared copy" |
| Prompt caching, "a cheaper rate for a long prompt that's sent again unchanged" | **Fixed** | Now "the long start of a prompt" (AP: prefix) |
| Misconceptions: caching isn't free speed; often an index is the fix | True | |
| Latency vs throughput; vertical and horizontal scaling; load balancer; stateless servers; read replicas; sharding; connection pooling; autoscaling; rate limiting | True | AZ, 12F, PG |
| "Bottleneck: usually the database, then the network, rarely the language" | True (hedged) | AZ: stateful parts are the most likely bottleneck |
| Queues smooth spikes: "accept sign-ups into a queue instantly and process them steadily" | **Fixed** | Same problem as the card: now "accept each sign-up quickly and put its slow follow-up work (the welcome email, setting things up) on a queue" |
| A single decent server with an indexed Postgres handles more than most new apps see; start with a monolith | True (opinion, widely held, hedged with "most") | |

## Simulation and tests

No number changed, so the results table in GAME.md stands (solution 14.94 months, par 14.9) and `tests/check.sh` passes. GAME.md's walk-through was brought in line with the text changes (the queue and CDN rows, the hotfix price, "fifteen thousand sign-ups in twenty minutes" to match `signups.bursts`, which had said "a third in half an hour").

## Left open

- GAME.md says "the codex says once" that numbers are illustrative; the game doesn't yet show that line anywhere. Worth adding when the codex screen exists.
- GAME.md's decoy row says the biggest model has "twice the wait"; the simulation doesn't model model latency. Design-doc only.
