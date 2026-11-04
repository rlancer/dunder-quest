# Technical review: Episodes 8 (*Viral*) and 9 (*The Board Meeting*)

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

---

# Episode 9 (*The Board Meeting*)

The same pass for Episode 9, done before it merged: every technical claim a player can see in its entry in `data/season.json`, the new pieces in `data/pieces.json`, the new bubbles in `ui/board.gd`, and the behaviours it added to `sim/sim.gd`, against CURRICULUM.md Modules 6 (the OLAP side) and 8. Same rule: simplify, never falsify. Reviewed November 2026.

## Sources

| Key | Source |
| --- | --- |
| OLAP | [What's the difference between OLAP and OLTP?](https://aws.amazon.com/compare/the-difference-between-olap-and-oltp/), AWS: OLTP stores and updates transactional data in high volumes, in milliseconds; OLAP is for complex analysis and reporting; OLAP data lives in a data warehouse or lake, updated by periodically processing data in large batches |
| IBM | [OLAP vs. OLTP](https://www.ibm.com/think/topics/olap-vs-oltp), IBM: OLTP is many simple transactions; OLAP is complex analysis, typically from a data warehouse that OLTP systems feed |
| COL | [Columnar storage](https://docs.aws.amazon.com/redshift/latest/dg/c_columnar_storage_disk_mem_mgmnt.html), Amazon Redshift docs: row storage is optimal for OLTP; warehouse queries read a few columns of very many rows, so a column store reads a fraction of the data (5 of 100 columns is about 5%), less again with per-column compression |
| RR | [Read replicas](https://aws.amazon.com/rds/features/read-replicas/), Amazon RDS: route read queries to a replica to reduce load on the source; replicas are updated by asynchronous replication on every change |
| SRE | [Monitoring distributed systems](https://sre.google/sre-book/monitoring-distributed-systems/), Google SRE book: monitoring and alerting let a system tell you when it's broken; an alert is a notification meant for a human; error rate is one of the golden signals |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| Dashboard load = screens × tiles / refresh, each a scan of every stored row | True | A dashboard runs each tile's query at each refresh, per viewer unless results are shared. Result caches would cut this; the card says each screen asks again, and the model matches the system it describes |
| On the main database, the scans take capacity from bookings | True | The curriculum's Module 6 example; OLTP and OLAP compete for the same CPU and disk, which is why they're kept apart (IBM, OLAP) |
| A booking waits the database's full latency (new `book_page`) | True | A booking writes; no cache stands in front of a write. Applied as the worse of page and booking time, so it can only make Episode 8's failing plans fail harder; Episode 8's solution is unchanged (14.941) |
| Read replica: the primary's capacity, takes the dashboard, leaves bookings alone | True | RR. Replica lag isn't modelled; the replica fails here on throughput, which is true at this load |
| The warehouse does a fortieth of a row store's work per tile | True as illustration | COL: 5 of 100 columns is about 5% of the data, before compression; 2.5% is within that range |
| Vertical scaling: eight times the capacity for eight times the price | True as illustration | Cloud database sizes roughly double CPU and price per step; $400 to $3,200 is three steps |
| Freshness = minutes since the last good copy: hourly, nightly at 3am, or streamed | True | OLAP (periodic batches). The copy's own read load on the primary (an hour's new rows) is small and not modelled |
| A failed copy job stays failed until fixed and rerun | True | A batch job that breaks on bad input fails every run until the input or the job is fixed |
| The fix is only offered with alerts | True (simplified) | SRE: alerting is how a system tells a human it's broken. Someone might notice anyway; the game simplifies to "nobody did in time", and the finding claims only that nobody fixed it |

## Episode 9 text

### Cold open, brief, cliffhanger

Narrative (the vote, Mack, the box, Hubbub's questions). The brief's numbers match the data: fifteen thousand diners at the peak (`live.diners`).

### Pull request cards and takes

| Card | Claim | Verdict | Change |
| --- | --- | --- | --- |
| Board dashboard | Forty tiles on the boardroom screen and the board's laptops, straight from the database, every minute | True: `live.dashboard` is 40 tiles, 6 screens, 60 s | |
| Board dashboard, Gerard | Every tile is a question, every screen, every minute | True | |
| Biggest database | Eight times the power for eight times the price | True as illustration | |
| Biggest database, Veronica | $3,200 a month | True | 8 × $400 in `pieces.json` |
| Read replica | A live copy for the dashboard, so its questions don't slow bookings | True | RR |
| Read replica, Gilroy | Same kind of database, same slow answers | True | COL: the replica is a row store, built for OLTP |
| The Forkcast Box | Sell restaurants a server for the back office | True as a description (on-premises hardware, Module 8); takes Narrative | |
| Analytics database | Copy hourly into a separate database built for big questions | True | OLAP, COL |
| Analytics database, Ulrich | "You don't do the accounts at the front desk" | True | The curriculum's front desk and accountant's office |
| Error alerts | Track errors in the app and every scheduled job, message us when one fails | True | SRE |
| Error alerts, Danesh | Alerts are for people who write bugs | Narrative | The night punishes cutting alerts |
| Real-time stream | Every booking streamed as it happens, on a managed event-streaming cluster | True | A real pattern (change data capture into a streaming platform); the price is illustrative |
| Two hundred tiles | Five times the questions | True | |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Is this OLTP or OLAP work? | True | OLAP, IBM. "240 a minute" is 40 tiles × 6 screens, every minute |
| How fresh do the numbers need to be? | Narrative | Walter's answer, not a rule |
| How will we know if it breaks? | True | SRE; Gerard's payroll story is Narrative |
| What will this cost at 10x traffic? | True | The bigger database's price doesn't depend on traffic, nor does the dashboard's question count; each question grows with rows, as the line says |
| Make it real-time / Make it huge (decoys) | Narrative | Judged by the night: overbuilt, and too many tiles |

### Dials, hotfix, live moment

| Item | Verdict | Change |
| --- | --- | --- |
| Copy every hour or night | True | |
| Hotfix: the 8pm copy failed on a noodle emoji in a restaurant's name | True | Unexpected characters breaking a batch job is a classic failure |
| Corner lines (bookings waiting behind the screen, the replica's "Loading", nine bookings on 3am numbers, the screen stuck at seven) | True or Narrative | A 3am copy holds almost none of Friday evening's bookings |
| Banners | True | Match `live.diners` and the 8pm copy |
| Bubbles: "Board's dashboard!", "Timing out", "Too many tiles", "Copy job failed", "3am numbers" | True | "Too many tiles", not "200 tiles!", since it fires for any tile count the warehouse can't answer |
| Live panel: "Board's numbers N min old" | True | The simulation's age |

### Postmortem findings

| Tag | Verdict | Notes |
| --- | --- | --- |
| no_dashboard | True | |
| olap_on_oltp | True | OLAP, IBM, the curriculum |
| replica_slow, "a read replica is still an OLTP database" | True (simplified) | A replica is a copy of the same row-store database (COL); analytics on a replica works at small scale, which the finding doesn't deny |
| too_many_tiles | True | |
| silent_failure | True | Says "nobody fixed it and ran it again", true both without alerts and with the hotfix cut (not "nobody knew", which is false in the second) |
| stale_numbers, "at 3am" | True | `pipeline.nightly_at` is 840 minutes before 5pm |
| db_overload, app_overload, rate_limited, overbuilt | True | As Episode 8 |

### Codex cards and sources

| Card | Verdict | Change |
| --- | --- | --- |
| OLTP and OLAP | **Fixed** in draft | Drafted as "filled by a regular copy job called a pipeline"; the source supports periodic batches but never says "pipeline". Now "kept up to date by copying new data across in regular batches". Every part is in OLAP |
| Monitoring and alerts | True | SRE. "Ideally before your customers" is hedged |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| Board: each tile a question, asked at every refresh | True |
| Replica: a read-only copy that follows every change | True (RR) |
| Analytics: stores each column together, reads only what it needs, filled by a copy job | True (COL) |

## CURRICULUM.md, Modules 6 and 8

| Claim | Verdict |
| --- | --- |
| OLTP the front desk, OLAP the accountant's office; OLAP on the OLTP database slows the app; warehouses store by column; ETL or ELT; data lakes | True (OLAP, IBM, COL) |
| Logs, monitoring, alerts: "alerts tell you before customers do" | True (SRE; hedge-worthy, but a goal, not a promise) |
| Misconceptions: "Deploying is a one-off", "It's live, so it's done" | True |

No curriculum text changed.
