# Technical review: Episodes 1 (*Pilot*), 2 (*The Whiteboard*), 3 (*Tabs and Spaces*), 4 (*Demo Day*), 5 (*The Spreadsheet*), 6 (*Log In*), 7 (*Launch Party*), 8 (*Viral*), 9 (*The Board Meeting*), 10 (*Hubbub Dine*), 11 (*Charged Twice*), 12 (*The Leak*), 13 (*The Conference*) and 14 (*Finale*)

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
| 40 servers | Every one talks to the same database | True | PG |
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

# Episode 10 (*Hubbub Dine*)

The same pass for Episode 10, done before it merged: every technical claim a player can see in its entry in `data/season.json`, the new piece and work in `data/pieces.json`, the new bubbles and badges in `ui/board.gd`, the live panel's new line, and the behaviours it added to `sim/sim.gd`, against CURRICULUM.md Modules 9 and 10. Same rule: simplify, never falsify. Reviewed November 2026.

## Sources

| Key | Source |
| --- | --- |
| GCA | [Rate limiting overview](https://docs.cloud.google.com/armor/docs/rate-limiting-overview), Google Cloud Armor: rate-based rules protect applications from a large volume of requests and stop any one client exhausting resources, so other clients aren't affected; clients keyed by IP (among others); over the limit, deny with `429 Too Many Requests` (recommended); set the threshold around the 99th percentile of real traffic and raise it if legitimate traffic is blocked |
| 429 | [429 Too Many Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/429), MDN (as Episode 8) |
| MSA | [Microservices architecture style](https://learn.microsoft.com/en-us/azure/architecture/guide/architecture-styles/microservices), Azure Architecture Center: services a small team can build and deploy independently; more moving parts than the equivalent monolith; interservice communication; a long chain of service dependencies adds latency; harder to test; a container orchestrator such as Kubernetes runs them |
| SLO | [Defining reliability targets](https://learn.microsoft.com/en-us/azure/well-architected/reliability/metrics), Azure Well-Architected Framework: a composite SLO is the product of the contributing components' (99.95% × 99.99999% ≈ 99.95%) |
| MF | [MonolithFirst](https://martinfowler.com/bliki/MonolithFirst.html), Martin Fowler: don't start a new project with microservices; almost all successful microservice stories began as a monolith that got too big |
| W3C | [Inaccessibility of CAPTCHA](https://www.w3.org/TR/turingtest/), W3C: CAPTCHAs often prevent people with disabilities from completing the task, and can be circumvented by algorithms or crowd-sourced solving |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| A scraper's requests miss the cache | True (simplified) | A scraper walking every restaurant, time and party size asks for keys diners rarely touch. "Never" rather than "rarely" is the simplification; it can only make the scraper look slightly worse |
| A per-client limit lets each client through up to the limit; the rest are turned away with a 429 | True | GCA, 429. Sixty clients at 1,500 a minute against a limit of L a minute lets 60 × L a minute through |
| Turning a request away costs a fiftieth of answering it | True as illustration | Rejecting at the front door skips the app's work and the database; the ratio is illustrative |
| A limit under what a busy diner does (thirty a minute) turns away a share of diners | True | GCA: set the threshold above real traffic's peak, or it blocks legitimate traffic. The share (30% of diner traffic comes from busy moments) is illustrative |
| More app servers behind the load balancer add capacity in proportion | True | As Episode 8 (AZ). Four servers carry the solution's peak at about 80% |
| Microservices: each request crosses a number of network calls; each adds latency and work and fails 1 time in 100; success is the product | True (simplified) | SLO: composite availability is the product of its parts; MSA: chains of calls add latency, interservice communication adds work. Real failures are often correlated, and well-built services can degrade gracefully (MSA's "fault isolation"); the game models a straightforward chain with no fallbacks, which is what Ulrich's card describes |
| A CAPTCHA stops 90% of the scraper and makes 15% of searches and bookings give up | True as illustration | W3C: some real people can't pass them, and bots and paid solvers get through some. The percentages are illustrative |
| Episodes 8 and 9 unchanged | Checked | All new behaviours are off unless the episode configures `live.scraper`, `live.services` or `live.captcha`: Episode 8's solution is still 14.941, Episode 9's 12.856 |

## Episode 10 text

### Cold open, brief, cliffhanger

Narrative (Galen's keynote, the two hundred and twelve microservices, Mack's departure, Ulrich's tea, the deposits). The brief's numbers match the data: the goal is nineteen bookings in twenty (`goal`).

### Pull request cards and takes

| Card | Claim | Verdict | Change |
| --- | --- | --- | --- |
| More servers | More servers behind the load balancer; six is double what we have | True | |
| More servers, Veronica | Six is double the server bill for an unmeasured night | **Fixed** in draft | Drafted as "double the bill", which is false for the whole bill (3 to 6 × $150 is +$450 on about $81k). Now "double the server bill" |
| Clone the clone | Copy every announced feature | Narrative; too long to fit, so never judged on the night | |
| 8 services | Eight services calling each other over the network, on a container cluster | True | MSA |
| 8 services, Gilroy | Every arrow is a network call, any call can fail, a booking needs eight to work | True | SLO; `services.hops.book` is 8 |
| 8 services, Ulrich | Hubbub has two hundred and twelve; eight is humble | Narrative; the night judges it | |
| Rate limit API | Count each client's requests at the front door and turn away the excess with a 429 | True | GCA, 429 |
| Rate limit API, Danesh | Some diners tap through thirty restaurants a minute | True as illustration (`scraper.diner_peak`) | |
| Add CAPTCHAs | A puzzle before each search and booking; bots hate it | True (W3C); Veronica's "people hate it too" is True | |
| Shard by city, Gilroy | The database isn't tonight's problem | True: it stays under a quarter of its capacity on the solution's night | |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Who's calling our API? | True | Sixty machines at 1,500 a minute each, as `live.scraper` |
| Where's the bottleneck? | True | Episode 9's peak: the app at about 45%, the database at under a tenth. "Three servers carry about thirty thousand, four about forty" holds with HubbubBot rate-limited (three are full at about 30,000, four at about 41,000), and the line hedges "if HubbubBot doesn't eat them first" |
| What if one service fails? | True | 0.99⁸ = 0.923; one in thirteen is 7.7% (SLO) |
| What will this cost at 10x traffic? | True | $150 a small server, $4,000 the cluster (`pieces.json`) |
| Make it bot-proof / Make it web-scale (decoys) | Narrative | Judged by the night: diners give up; overbuilt |

### Dials, hotfix, live moment

| Item | Verdict | Change |
| --- | --- | --- |
| App servers four to eight; rate limit 10, 100 or 1,000 a minute per client | True | The dial's labels read "10 a minute" and so on |
| Hotfix: two more app servers when Hubbub Dine falls over, at {monthly} | True | The price is worked out from the board, as Episode 8's |
| Corner lines (HubbubBot eating the servers, Danesh's 429, a booking lost between services, the fork puzzle) | True or Narrative | |
| Banners | True | Match `live.diners` and `live.scraper` (the scraper starts at 6pm) |
| Bubbles: "HubbubBot flood", "429s for diners!", "Service call failed", "Gave up at CAPTCHA"; badges "100/min", "CAPTCHA"; the app box's "8 services" | True | |
| Live panel: "HubbubBot N/s, M let in" | True | The simulation's arriving and admitted scrape rates |

### Postmortem findings

| Tag | Verdict | Notes |
| --- | --- | --- |
| scraper, "no rate limit, or one set too high" | True | Fires both without a limit and at 1,000 a minute; "too much of that got through" is true in both |
| limit_too_tight | **Fixed** in draft | Drafted as "ten a minute stopped HubbubBot"; ten a minute still lets ten a second through. Now "slowed HubbubBot to a trickle" |
| service_chain | True | SLO |
| captcha | True | W3C |
| app_overload, db_overload, rate_limited, overbuilt | True | As Episode 8 (this episode's app_overload says "Where's the bottleneck? Add a server.", since its servers are already stateless) |

### Codex cards and sources

| Card | Verdict | Change |
| --- | --- | --- |
| Rate limiting | True | Every part is in GCA: per-client caps, 429, protecting other clients from one that would exhaust resources, and setting the threshold above real traffic so legitimate users aren't blocked. Not "per IP" in the card, since GCA keys by other things too |
| Monolith and microservices | True | Every part is in MSA: small teams build and deploy services independently; more moving parts than the equivalent monolith; services communicate over the network; a long chain adds latency; harder to test. Drafted with "start with one app", which is MF's advice, not MSA's; the card now says only "one app is simpler" (MSA), and MF backs the postmortem's "keep this one app until we measure a problem" |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| HubbubBot: asks for every restaurant's tables at every time and party size; nobody else asks for those, so the cache never has them | True (simplified, as above) |

## CURRICULUM.md, Modules 9 and 10

| Claim | Verdict |
| --- | --- |
| Rate limiting: capping how many requests one user or bot can make, to protect everyone else | True (GCA) |
| "Microservices scale better" is a misconception; start with a monolith | True (MF, MSA) |
| Monoliths vs microservices: one app is easier to build, test and debug; services let large teams move independently at the price of the distributed problems appearing between them | True (MSA) |

No curriculum text changed.


# Episode 11 (*Charged Twice*)

The same pass for Episode 11, done before it merged: every technical claim a player can see in its entry in `data/season.json`, the new piece in `data/pieces.json`, the new bubbles, badges and box in `ui/board.gd`, the live panel's and the postmortem's new lines, and the behaviours it added to `sim/sim.gd`, against CURRICULUM.md Module 10 (and Module 6's transactions). Same rule: simplify, never falsify. Reviewed November 2026.

## Sources

| Key | Source |
| --- | --- |
| SE | [Advanced error handling](https://docs.stripe.com/error-low-level), Stripe: network errors include timeouts; a connection might close before the client receives a response, and you might not know whether the request was executed; retry with the same idempotency key and parameters, which prevents the retry creating a second object; a new key can start a second operation; results of keyed requests are cached and replayed (`Idempotent-Replayed: true`); keys can be derived from a user-attached object to guard against double submissions |
| SI | [Idempotent requests](https://docs.stripe.com/api/idempotent_requests), Stripe API reference: the client generates the key; Stripe saves the first response for a key and returns it to retries, including errors |
| PGA | [Data consistency checks at the application level](https://www.postgresql.org/docs/current/applevel-consistency.html), PostgreSQL docs: with concurrent transactions in Read Committed, checks don't work correctly "without some help"; to protect a row against concurrent updates use `SELECT FOR UPDATE` (or an actual update), which blocks other transactions until the holder commits or rolls back |
| PGL | [Explicit locking](https://www.postgresql.org/docs/current/explicit-locking.html), PostgreSQL docs: `FOR UPDATE` locks the rows; other transactions trying to lock or change them wait until the current transaction ends, then get the updated row |
| EC | [Eventually consistent](https://www.allthingsdistributed.com/2008/12/eventually_consistent.html), Werner Vogels: copies return the latest value only eventually; the "inconsistency window"; under a network partition, consistency and availability can't both be had (CAP); conflicting writes are possible when write sets don't overlap |
| GP | [Gossip protocol](https://en.wikipedia.org/wiki/Gossip_protocol), Wikipedia: news spreads to every node in time logarithmic in the network's size |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| A scripted share of payment calls time out; half of those had actually gone through | True (simplified) | SE: a timeout leaves the outcome unknown. The shares (one in a hundred to one in seventeen; half succeeded) are illustrative, scripted per episode, not caused by our load |
| Retries off: a timeout is reported as failed, so the diners whose charge went through paid for a booking we said failed | True | SE ("you might not know whether Stripe received or executed the request"). Real apps would reconcile afterwards with webhooks; the game charges the refund and apology as an incident cost, which is what reconciling would find |
| Retries on without a key: the ones that went through are charged twice | True | SE: a new request (a new key, or none) can start a second operation |
| Retries on with a key: no second charge; the retry gets the first result | True | SE, SI |
| A retried call fails only if both tries time out (t²) | True (simplified) | Treats the two tries as independent; real faults cluster, which would make a retry less helpful, not unsafe |
| A backup provider charges again on a timeout, even with keys | True | Keys are kept per provider account (SI: "the server uses [the key] to recognise subsequent retries"); a different company has never seen them |
| Double bookings at h²w/H: quadratic in the traffic on hot tables | True | For Poisson arrivals at λ = h/H per table and a gap w, a second party arrives inside the gap at rate ≈ λ·w per booking, so h·λ·w = h²w/H for small λw. "Hot" (a quarter of bookings, forty contested tables) is illustrative |
| The deposit call inside the gap widens it to about a second and a half | True | Check, then wait for an outside call, then write: the gap is the wait. Holding the row first is the curriculum's "taking the deposit and holding the last table must both happen, or neither" |
| A transaction holding the table's row closes the race | True | PGA, PGL. Strictly it's the row lock (`SELECT ... FOR UPDATE`) or a unique constraint inside the transaction that closes it, not the word "transaction"; the card says "lock the table's row inside a transaction" |
| ForkNet: the gap is log₂(phones) rounds of gossip (half a second each), seven seconds at sixteen thousand phones, and a transaction on one phone doesn't stop another | True (simplified) | GP (logarithmic spread), EC (the inconsistency window; conflicting writes when write sets don't overlap). Real decentralised designs can add consensus to avoid this, at the cost of availability (EC's CAP point); ForkNet, as Ricky built it in a night, doesn't |
| ForkNet loses one booking in twenty to phones that drop off | True as illustration | Phones going offline mid-gossip is the point; the share is illustrative |
| Expected counts are rounded to whole people for the goal | True (simplified) | A third of a double booking means, most likely, nobody: with few trials, rare events often don't happen at all, which is why staging misses the race. Staging at a tenth of the traffic sees a hundredth of the race (quadratic) and a tenth of the double charges (linear), so it catches the charges and misses the race |
| Episodes 8, 9 and 10 unchanged | Checked | All new behaviours are off unless the episode configures `live.payments` or `live.race`: the solutions are still 14.941, 12.856 and 13.113 |

## Episode 11 text

### Cold open, brief, cliffhanger

Narrative (the trattoria, the fax modem, HubbubBot stopping, ForkNet on five phones, the leaked key and the lawsuit that set up Episode 12). Gilroy's "five phones, one room, one wifi" is the misconception "it worked when I tested it", which the night bears out. The brief's numbers match the data: twenty-dollar deposits are story (the simulation doesn't use the amount), sixteen thousand diners at the peak (`live.diners`).

### Pull request cards and takes

| Card | Claim | Verdict | Change |
| --- | --- | --- | --- |
| Take deposits | A deposit through the payment provider for bookings at the forty; on a timeout, ask again | True | |
| Take deposits, Gilroy | Some calls won't come back; some come back late, which is worse | True | SE: a late or lost reply leaves the outcome unknown |
| ForkNet | Every phone keeps a copy and gossips each booking to the phones near it | True (as a description of the proposal) | |
| ForkNet, Ricky | Nothing in the middle means nothing in the middle can go down | Narrative; true as far as it goes, and the night judges what it misses | |
| ForkNet, Gilroy | Copies disagree until the gossip catches up; two phones can both say yes to the last table | True | EC |
| ForkCoin | Deposits in our own cryptocurrency | Narrative; too long to fit, never judged on the night | |
| Deposit IDs | One number per deposit, the same on every ask, so the provider can tell it's already taken that one | True | SE, SI. The key must be the same across retries of one deposit and different between deposits (SE: derived from the booking, or a random UUID kept with it) |
| Deposit IDs, Ulrich | Aviato's bank never took a payment twice | Narrative | |
| Deposit IDs, Danesh | The provider already gives every charge its own ID | True, and the point: that ID comes back in the reply, which is what a timeout loses. Said in GAME.md and the asks, not on the card, so the judgement stays the player's | |
| Hold the table | Check and hold in one step, a transaction, before the deposit; release it if the deposit fails | True | PGA, PGL |
| Hold the table, Ricky | Check, wait a second and a half for the money, then book | True (`payments.latency` 1.5 s) | |
| Backup provider, Gilroy | The second provider has never heard of the first one's deposits | True | |
| Shard by city, Gilroy | The database is fine; the network to everyone else isn't | True: the database stays well under capacity on the solution's night | |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| What if this is sent twice? | True | SE: unknown outcome on a timeout; retrying without the key can charge twice; with it, the first answer comes back |
| What if the provider is down? | True | Matches `payments.timeouts` (0.01, 0.02, 0.06) and `succeeded` (0.5). "It won't be down, it'll be slow" is the episode's script; the curriculum's partial-failure point holds either way |
| Can two people book the last table? | True | "Grows with the square of the traffic on the busy tables" is the sim's h²w/H |
| What will this cost at 10x traffic? | True as illustration | About 90¢ a twenty-dollar deposit is in the range of card fees (a few percent plus a fixed amount); $40 a wrong charge and $150 a comp are illustrative |
| Make it never fail / Make it web-scale (decoys) | Narrative | Judged by the night |

### Dials, hotfix, live moment

| Item | Verdict | Change |
| --- | --- | --- |
| On a timeout: give up or try again | True | |
| Hotfix: stop retrying "so nobody gets charged twice" | True as offered (Aleister's misconception, and the night judges it) | With the key, retries were safe; turning them off makes timeouts unknown-outcome failures |
| Corner lines (charged twice, charged for nothing, both providers, two parties at table twelve, ForkNet in a tunnel) | True or Narrative | |
| Banners | True | Match `live.diners` and `payments.timeouts` (slow from 8pm, caught up by 9:20) |
| Bubbles "Charged twice!", "Timed out. Paid?", "Charged at both!", "Same table twice!", "Phones disagree!"; badges "retry", "retry + key", "no retry", "backup", "txn", "ForkNet"; the Payments box | True | |
| Live panel: "Charged wrongly N", "Tables booked twice N" (in place of the AI bill); postmortem's "Charged wrongly / Booked twice" line | True | The simulation's running totals, rounded to whole people as the goal is |

### Postmortem findings

| Tag | Verdict | Notes |
| --- | --- | --- |
| no_deposits | Narrative | |
| double_charge, "retries without an idempotency key" | True | SE |
| timeout_unknown, "a timeout means you don't know" | True | SE; the curriculum's own misconception, "errors mean it didn't happen" |
| backup_provider, "failover without idempotency" | True | |
| double_booking, "a race condition; the fix is a transaction" | True | PGA, PGL (the transaction with the row lock, as the card says) |
| forknet, "eventual consistency: copies agree later, not now" | True | EC, GP |
| app_overload, db_overload, rate_limited, overbuilt | True | As Episode 10 |

### Codex cards and sources

| Card | Verdict | Change |
| --- | --- | --- |
| Retries and idempotency | True | Every part is in SE: a timeout may leave the request executed with the reply lost; a repeat without the key can do it again; the same key on every retry makes the server recognise it and replay the first result. First drafted with the API reference (SI) as its source, which doesn't say a timed-out request may have succeeded; SE does, so the card cites SE |
| Race conditions and transactions | True | PGA: checks fail under concurrent transactions without help, and `SELECT FOR UPDATE` blocks the others until the holder commits; PGL: they wait until the transaction ends. Drafted as "the second booking waits, then finds it taken"; the second half depends on the booking updating the row, so the card now stops at "has to wait until the first is done" |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| Payments: another company's computers, which take deposits for us; we ask over the network and wait | True |

## CURRICULUM.md, Modules 10 and 6

| Claim | Verdict |
| --- | --- |
| A request that times out might have failed, or succeeded with only the reply lost | True (SE) |
| An idempotency key lets a server recognise "I've already done this one" | True (SE, SI) |
| Two users book the last table at the same moment and both are told yes; fixes are transactions and locks, or checking-and-reserving in one step | True (PGA, PGL) |
| Eventual consistency: copies agree soon, not instantly | True (EC) |
| "If it worked when I tested it, it works" is a misconception; distributed bugs depend on timing and load | True: the race is quadratic in load, so staging at a tenth sees a hundredth |
| Transactions: taking the deposit and holding the last table must both happen, or neither (Module 6) | True; the episode's card holds the table first and releases it if the deposit fails, which is that guarantee across a database and an outside service (the outside call can't be inside the database's transaction, so it's done as hold, charge, then confirm or release) |

No curriculum text changed.

# Episode 12 (*The Leak*)

The same pass for Episode 12, done before it merged: every technical claim a player can see in its entry in `data/season.json`, the new pieces in `data/pieces.json`, the new boxes, badges and bubbles in `ui/board.gd`, the live panel's and the postmortem's new lines, and the behaviours it added to `sim/sim.gd`, against CURRICULUM.md Module 11 (and Module 2's Git and packages). Same rule: simplify, never falsify. Reviewed November 2026.

## Sources

| Key | Source |
| --- | --- |
| GH | [Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository), GitHub Docs: if you committed a secret, "as a first step you need to revoke and/or rotate that secret"; once it's rotated, rewriting the history "may not be warranted"; the commits "may still be accessible elsewhere"; you can't remove the data from other users' clones; if the commit exists in any forks it stays accessible there; rewriting history has numerous side effects |
| OW | [A01:2021 Broken Access Control](https://top10.owasp.org/2021/A01_2021-Broken_Access_Control/index.html), OWASP Top 10: "viewing or editing someone else's account, by providing its unique identifier (insecure direct object references)"; access control "is only effective in trusted server-side code"; access controls "should enforce record ownership"; the example attacker who changes the `acct` parameter in the URL |
| OS | [Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html), OWASP: exposed keys "should undergo immediate revocation"; restarting the application "does not itself revoke stolen credentials"; secrets in code leave commit history; environment variables are a weaker option than a secrets manager |
| VT | [Env variables and modes](https://vite.dev/guide/env-and-mode), Vite: variables with the public prefix "will be exposed in client-side source code after Vite bundling" and "should not contain sensitive information such as API keys" |
| REG | [AI code suggestions sabotage software supply chain](https://www.theregister.com/2025/04/12/ai_code_suggestions_sabotage_supply_chain/), The Register, April 2025: models "suggest code that incorporates software packages that don't exist"; attackers can create a malicious package under a hallucinated name; rerunning a prompt ten times, 43% of hallucinated packages came back every time; the name "slopsquatting" |
| PH | [We Have a Package for You!](https://arxiv.org/abs/2406.10279), Spracklen et al., arXiv: hallucinated packages at least 5.2% of suggestions for commercial models, 21.7% for open ones; 205,474 unique hallucinated names; "a persistent and systemic phenomenon" |
| NPM | [scripts](https://docs.npmjs.com/cli/v11/using-npm/scripts), npm Docs: `preinstall`, `install` and `postinstall` scripts run on `npm install` |
| AR | As Episode 8: provider rate limits apply to the account the key belongs to, and calls past them get 429 |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| Strangers with our key call the provider directly and we pay for every call | True | That's what a stolen API key is. The usage numbers (300 a minute growing to 600 on the old key; 600 to 900 after the scanning bot; 300 to 900 from the package's author) are illustrative; $360 an hour matches the cliffhanger's $4k overnight |
| The old key keeps working, wherever it's been copied, until it's rotated; deleting the file, scrubbing the history or making the repository private doesn't stop it | True | GH (rotate first; copies in clones and forks stay), OS (immediate revocation; restarting doesn't revoke) |
| A key in the app's code is public, and a scanning bot finds it at a scripted tick | True (simplified) | VT (bundled into client-side code; never API keys). Bots scanning public code and app files for keys is the curriculum's own misconception ("nobody will bother attacking my little app"); the tick (7:30pm) is scripted |
| A malicious package's install script sends the server's settings, keys included, to its author | True (simplified) | NPM (install scripts run arbitrary commands on install, with the installing process's environment); REG (malicious packages under hallucinated names). Harvesting environment variables is a common payload of malicious packages; the game's package is invented |
| Strangers' calls count against our rate limit | True | AR: the limit belongs to the key's account, whoever makes the calls. With tonight's numbers it only bites in the worst plans |
| Switching our AI search off doesn't stop the strangers | True | They don't go through our app |
| A bot counting through booking numbers reads every booking that exists unless there's an ownership check; with the check, "not found" for almost no work | True | OW (IDOR, record ownership, the `acct` example). Four in five numbers existing is illustrative |
| A leak of diners' bookings costs a lawyer ($60k) | True as illustration | GDPR breach handling (Episode 8's GDPR row); the amount is illustrative |
| The firewall does nothing tonight | True (simplified) | A WAF matches known attack patterns. A request for booking 41023 is an ordinary request; a stolen key is used at the provider, not at our door. Real WAFs can add rate rules that slow enumeration; they can't tell whose booking is whose, which only the app knows (OW: access control belongs in server-side code) |
| Episodes 8 to 11 unchanged | Checked | All new behaviours are off unless the episode configures `live.leak` or `live.idor`, or the config has `ai_off`; with no strangers the rate-limit sum is the same as before. The solutions are still 14.941, 12.856, 13.113 and 12.343 |

## Episode 12 text

### Cold open, brief, cliffhanger

Narrative (the law firm, Melon on Hubbub's roof, the cousin who does parking appeals, Gilroy in the printer). Melon's mistake is real and common: a key in a README and in the app's code (VT). "I deleted the file on Sunday, so that's fixed" is the episode's misconception, said by a character and judged by the night. The lawsuit's claim (written on a Hubbub laptop) and its collapse (the Git history shows who wrote each line) are story; that Git records the author and date of every commit is true. The brief's numbers match the data: sixteen thousand diners (`live.diners`), one day (8 hours).

### Pull request cards and takes

| Card | Claim | Verdict | Change |
| --- | --- | --- | --- |
| Hide the key | Out of the app's code into the server's settings; only our server talks to the model | True | VT. The card says "the server's settings" rather than "an environment variable": OS prefers a secrets manager to environment variables, and either is on the server |
| Hide the key, Aleister | "Leak fixed!" | Narrative (Aleister's misconception, judged by the night) | |
| Hide the key, Ricky | Every phone that opens Forkcast downloads the key | True | VT |
| Hide the key, Gilroy | Tuesday's code still has it, and so does everyone who copied it | True | GH |
| Scrub the history | Rewrite every version to take the key out, then replace the repository | True as a description | GH describes the tools and the steps |
| Scrub the history, Gilroy | Every fork, clone and bot that copied it keeps its copy | True | GH (forks, clones) |
| Scrub the history, time | 6 hours | True as illustration | GH lists the side effects and the coordination (collaborators, forks, support for cached views); it doesn't fit beside the fixes, and isn't needed once the key is rotated |
| Key-safe package | A package that "encrypts our keys automatically" | Narrative (Aleister's pitch); the package is invented | No package by that name was on npm when this was written (the registry returned 404, November 2026) |
| Key-safe package, Gilroy | Every package is a stranger's code running next to our keys | True | Curriculum Module 2 ("more dependencies is free" is a misconception) |
| Rewrite it all | A clean-room rewrite in 40 hours | Narrative; too long to fit, never judged on the night | |
| Rotate the key | A new key, and the old one switched off at the provider so it stops working wherever it's been copied | True | GH, OS |
| Rotate the key, Danesh | Everything using the key needs the new one at once, or it breaks | True | OS (rotation should be quick, preferably automated) |
| Check who owns it | Check a booking belongs to whoever's asking; if not, answer as if it doesn't exist | True | OW. Answering "not found" rather than "forbidden" is a common choice so as not to confirm the number exists; either is a correct check |
| Check who owns it, Gilroy | The number in the link is the only lock | True | OW |
| Go private | Making the repository private so nobody can see the key, and keeping the key | Ulrich's misconception (curriculum Module 11: "it's a private repo, so the key is safe") | |
| Go private, Gerard | It would stop anyone new from finding it there | True, and only that | |
| Firewall everything, Gilroy | Asking for booking 41023 looks exactly like asking for 41022; the people on our key never come near our servers | True | |
| Shard by city, Gilroy | Nobody's attacking the database | True: it stays under capacity all night | |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Where are the secrets stored? | True | Deleting a file is a new commit and the old ones keep it (GH); the key is in the app (VT); a key works until switched off (OS) |
| Can a diner see someone else's booking? | True | OW's `acct` example, with a booking number |
| What does this package do? | True (the package and its history are invented) | REG: models suggest nonexistent packages, often the same ones again (43% every time in ten runs), and attackers can publish under those names; NPM: install scripts run on install |
| What will this cost at 10x traffic? | True as illustration | A stolen key's usage doesn't depend on our traffic; $360 an hour and $60k are illustrative |
| Make it unhackable / Make it web-scale (decoys) | Narrative | Judged by the night |

### Dials, hotfix, live moment

| Item | Verdict | Change |
| --- | --- | --- |
| No dials | | |
| Hotfix: switch AI search off "to be safe" | True as offered (Aleister's misconception, and the night judges it) | The strangers use the key at the provider; only rotating stops them |
| Corner lines (the fantasy novel on our key, the bot reading the key out of the app in nine seconds, the package posting the key, someone counting booking numbers, Chaz, Melon on the roof) | Narrative, or true as above | |
| Banners | True | Match `live.leak` (the scanning bot at 7:30pm) and `live.idor` (from 8:20pm) |
| Bubbles "Strangers on old key!", "Key read from app!", "Sent our key away!", "Someone else's booking!", "AI search off"; badges "key in app", "owner check", "WAF"; Melon's repo box ("public repo", "now private"); the keysafe package box; the Model API's "old key" / "new key" | True | |
| Live panel: "Strangers' calls N/min", "Bookings read N" (in place of the bookings count); postmortem's "Strangers' calls / Bookings read" line | True | The simulation's running numbers |

### Postmortem findings

| Tag | Verdict | Notes |
| --- | --- | --- |
| leaked_key, "a leaked secret: rotate it" | True | GH, OS |
| key_in_app, "anything in the frontend is public" | True | VT; curriculum Module 4 |
| fake_package, "a hallucinated package (slopsquatting)" | True | REG, PH |
| idor, "broken access control (an insecure direct object reference)" | True | OW |
| ai_off, "revoke the key, not the feature" | True | |
| rate_limited, now "strangers' calls on our key counted against our cap" | True | AR |
| app_overload, db_overload, overbuilt | True | As Episode 11 |

### Codex cards and sources

| Card | Verdict | Change |
| --- | --- | --- |
| A leaked key: rotate it first | True | Every part is in GH: rotate first; removing it from history may not be warranted once rotated; forks and other users' clones keep the commits. "Deleting it from the code isn't enough" is GH's premise (the data stays in the history until it's rewritten). Drafted with "anything in the app is public" too; GH doesn't say that, so it moved to the postmortem finding (sourced to VT) |
| Authorization on every request | True | OW: IDOR by changing an identifier; checks in server-side code; record ownership |
| Packages your AI made up | True | REG: nonexistent packages suggested, repeated names (43% every time), attackers can publish malicious packages under them. Drafted with Wikipedia's slopsquatting article as the source; it doesn't mention malicious packages or repetition, so the card cites REG |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| Melon's repo: his copy of the code on GitHub, open to anyone, with every version of every file he pushed | True |
| keysafe-autoguard: a stranger's code, installed on our server and run with its settings | True (NPM) |
| Firewall: $500 a month | Illustrative |

## CURRICULUM.md, Modules 11 and 2

| Claim | Verdict |
| --- | --- |
| Secrets live in environment variables or a secrets manager, never in code, never in Git, never in the frontend; anything in the frontend is public | True (OS, VT, GH) |
| Authorization on every request; the most common real-world flaw is reading another user's data by changing a number in the URL | True (OW: broken access control is A01, the top category) |
| AI tools sometimes invent package names that don't exist, and attackers register those names | True (REG, PH) |
| "Nobody will bother attacking my little app": bots scan the internet automatically | True; the scripted scanning bot plays it |
| "It's a private repo, so the key is safe": repos get shared, made public or leaked | True; Ulrich's card plays it (and GH: copies already made stay) |
| Git keeps a save history of the whole project (Module 2) | True; the episode's theme: the history keeps the key, and the same history settles the lawsuit |

No curriculum text changed.

# Episode 13 (*The Conference*)

The same pass for Episode 13, done before it merged: every technical claim a player can see in its entry in `data/season.json`, the new pieces in `data/pieces.json`, the new boxes, badges and bubbles in `ui/board.gd`, the live panel's and the postmortem's new lines, and the behaviours it added to `sim/sim.gd`, against CURRICULUM.md Module 13. Same rule: simplify, never falsify. In particular, nothing in the episode claims any defence makes prompt injection impossible. Reviewed November 2026.

## Sources

| Key | Source |
| --- | --- |
| LLM01 | [LLM01:2025 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/), OWASP GenAI Security Project: indirect injection when an LLM "accepts input from external sources, such as websites or files"; "it is unclear if there are fool-proof methods of prevention"; mitigations include "separate and clearly denote untrusted content", restricting the model's privileges "to the minimum necessary", human approval for high-risk actions, and constraining behaviour in the system prompt |
| LLM06 | [LLM06:2025 Excessive Agency](https://genai.owasp.org/llmrisk/llm062025-excessive-agency/), OWASP: excessive functionality, permissions and autonomy; "limit the extensions that LLM agents are allowed to call to only the minimum necessary"; execute "in the context of that specific user"; "utilise human-in-the-loop control to require a human to approve high-impact actions"; the example of a malicious email that tricks a mail assistant into forwarding data |
| RAG | [What is RAG?](https://aws.amazon.com/what-is/retrieval-augmented-generation/), AWS: LLMs can present "false information when it does not have the answer"; RAG references "an authoritative knowledge base outside of its training data sources before generating a response"; embeddings in a vector database; "a more cost-effective approach to introducing new data" than retraining; documents and embeddings kept current |
| SPOT | [Defending Against Indirect Prompt Injection Attacks With Spotlighting](https://arxiv.org/abs/2403.14720), Hines et al. (Microsoft), arXiv 2024: marking external text so the model can tell it from instructions cut attack success from above 50% to below 2% in their GPT experiments, with minimal effect on the task |
| AR | As Episode 8: provider rate limits per minute; calls past them get 429 |
| AP | As Episode 8: prompt caching covers the prompt's unchanged prefix |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| Without the menus, a share of answers about dishes and allergies are made up, as confident as the rest | True (simplified) | RAG (false information when it doesn't have the answer). One in seven is illustrative |
| Retrieval cuts made-up answers a long way, not to nothing | True | RAG grounds answers in the documents; it doesn't guarantee them (retrieval can miss, and the model can still misread). One in a hundred is illustrative |
| A bigger model, or a second AI checking, cuts it only a little | True (simplified) | Neither has tonight's menus; a checker without the source can't verify a dish. The factors (0.7, 0.5) are illustrative |
| Retrieved menus make every prompt longer, and prompt caching doesn't cover them | True | They differ for every question, so they aren't part of the cached prefix (AP). The +20% of the call price is illustrative |
| The index lives in our Postgres and adds a small search per answer; $20 a month | True as illustration | pgvector-style embeddings in Postgres (curriculum Module 6's "start with Postgres"); the monthly figure stands for making the embeddings and is illustrative |
| An agent job is several model calls, none from the answer cache | True | An agent loops: model, tool, result, model again; each step depends on what the tools just returned. Three calls is illustrative |
| Four agents talking to each other, or a second AI checking every answer, multiply the calls and can run past the rate limit | True | AR. The multiples are illustrative |
| A planted review is read by a share of answers about that restaurant, more just after the demo | True as illustration | Indirect injection through content the model reads (LLM01). The shares are illustrative |
| Of answers that read it, one in two follow it; one in fifty with what it reads marked as data; never none | True | SPOT's numbers (above 50%, below 2%); LLM01 ("unclear if there are fool-proof methods"). The game never shows the marked rate as zero: the solution's night still has about 2,300 steered answers and 229 steered jobs, shown on the live panel and the postmortem |
| A steered job pays a deposit nobody chose unless the diner must confirm, and nearly all diners say no | True (simplified) | LLM06 and LLM01: human approval for high-impact actions. One in five hundred approving anyway is illustrative; it's why the solution's expected count is under one (0.46, which rounds to nobody), not zero |
| With every tool, a steered job cancels other diners' bookings at that restaurant (up to the 120 it has), and only not having the tool prevents it | True | LLM06: excessive functionality and permissions; act in the user's context. This diner's confirmation can't cover other diners' bookings |
| Asking before every step loses a third of the diners; asking before paying, a few | True as illustration | Confirmation fatigue is real; the shares are illustrative |
| The biggest model doesn't change how often the review works | True (simplified) | No source shows bigger models reliably resist injection; LLM01 treats it as unsolved for all models |
| Episodes 8 to 12 unchanged | Checked | All new behaviours are off unless the episode configures `live.agent`, `live.grounding` or `live.injection`, or the config has `checker`; the new dictionary entries add zero. The solutions are still 14.941, 12.856, 13.113, 12.343 and 11.924 |

## Episode 13 text

### Cold open, brief, cliffhanger

Narrative (the conference, Galen's flawless demo that books Hubbub's own cafeteria, the standing ovation, Melon's deleted repository, Ulrich supervising, the bin by the judges' table, the sixty cities, Forkcast Infinite). No real conference is named. The brief's numbers match the data: fourteen thousand diners (`live.diners`), one night (8 hours). Aleister's "every tool, so it's never stuck" is the episode's misconception, judged by the night.

### Pull request cards and takes

| Card | Claim | Verdict | Change |
| --- | --- | --- | --- |
| Let it book | An agent searches, checks tables and books by itself, with every tool our app has | True as a description | LLM06 |
| Let it book, Gilroy | Every tool means the admin tools: cancel anyone's booking, refund anything, for whoever's typing | True | LLM06 (excessive functionality, a high-privilege identity) |
| 4 agents | Four agents talking to each other | Narrative (Danesh's fashion); judged by the night | |
| 4 agents, Gilroy | Four agents is four times the model calls | True as illustration | Each agent's turn is a call |
| Own model | Train our own model on every menu | Narrative; too long to fit | |
| Own model, Veronica | Menus change every week; you'd retrain every Tuesday | True | RAG: retrieval is the cheaper way to add new data and keep it current |
| Ask first | It shows the diner what it's about to do and waits for a yes | True | LLM06, LLM01 (human approval) |
| Ask first, Danesh | Every tap, we lose people | True of asking at every step; the dial is the lesson | |
| Look it up first | Keep every menu in an index; find the right ones and answer from those | True | RAG |
| Look it up first, Ricky | Its memory has never seen tonight's menus | True | A model's training data ends before tonight |
| Look it up first, Danesh | Longer prompts, more tokens, more money | True | |
| Own tools only | Only the diner's own tools: search, check, book for the diner asking | True | LLM06 (minimum extensions, the user's context) |
| Own tools only, Gilroy | Don't give a chatbot a key you wouldn't give a stranger at the door | True | Curriculum Module 13 ("don't give a chatbot powers you wouldn't give an anonymous customer") |
| Reviews are data | Wrap what it reads in markers; tell it that what's inside is information, never orders | True | LLM01 ("separate and clearly denote untrusted content"); SPOT |
| Reviews are data, Ricky | Our instructions and a stranger's review arrive as the same kind of words | True (simplified) | The model reads one stream of text |
| Reviews are data, Gilroy | It helps a lot; it doesn't make it safe; nothing makes it safe | True | SPOT (a lot); LLM01 (no fool-proof prevention) |
| Second AI checks, Gilroy | Twice the calls, past our limit; the checker hasn't seen the menus | True | AR |
| Shard by city, Gilroy | The database is idling | True: under an eighth of capacity all night | |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Where do its answers come from? | True | Training data doesn't include tonight's menus; a model guesses fluently (RAG); retrieval is the fix |
| What can this agent do if someone tricks it? | True | LLM06 (anything its tools allow); LLM01 (text it reads can carry instructions); Ricky's "much harder, not impossible" matches SPOT and LLM01 |
| What will it do without asking? | True | With deposit-taking tools and no approval step, an agent can pay (LLM06, excessive autonomy) |
| What will this cost at 10x traffic? | True as illustration | Agents make several calls a job; retrieved text adds tokens; $40 and $150 as in Episode 11 |
| Make it never wrong / Make it web-scale (decoys) | Narrative | Judged by the night |

### Dials, hotfix, live moment

| Item | Verdict | Change |
| --- | --- | --- |
| Dial "asks the diner before": every step, or paying or sending | True as a trade-off | |
| Hotfix: switch to the biggest model, "harder to fool" | True as offered (Aleister's misconception, curriculum Module 13: "a bigger model fixes it"), and the night judges it | |
| Corner lines (the hall told Forkcast is closing, the bookings at Nonna's cancelled, a table for twelve in Daly City, the nut-free pesto, "May I search?", the rate limit, Chaz) | Narrative, or true as above | |
| Banners | True | Match `live.injection` (the review from 6pm) and `live.diners` |
| Bubbles "Made-up menu!", "Obeyed a review!", "Paid, unasked!", "Bookings cancelled!", "Asked too often"; the Agent box ("all tools" / "3 tools", "Agents x4"), its badges "asks: all", "asks: pay", "as data", "checker"; the Menus index box | True | |
| Live panel: "Made-up answers", "Jobs fooled by review", "Done without asking"; the postmortem's "Made up / Fooled / Unasked" line | True | The simulation's running numbers. "Jobs fooled" stays above zero on the solution's night, on purpose |
| The clock says Thursday | True | `live.day` |

### Postmortem findings

| Tag | Verdict | Notes |
| --- | --- | --- |
| no_agent, "an AI agent: a model that uses tools" | True | Curriculum Module 13 |
| hallucination, "ground it with retrieval (RAG)" | True | RAG |
| prompt_injection | True | LLM01 |
| no_confirm, "human in the loop: confirm before paying or sending" | True | LLM06, LLM01 |
| excess_agency, "excessive agency; the fix is least privilege" | True | LLM06 is named Excessive Agency |
| confirm_fatigue | True | |
| big_model, "a bigger model isn't the fix" | True | Curriculum Module 13's misconception |
| ai_bill, "tokens and cost"; rate_limited, now naming agents and the checker | True | AR |
| app_overload, db_overload, overbuilt | True | As Episode 12 |

### Codex cards and sources

| Card | Verdict | Change |
| --- | --- | --- |
| Grounding: retrieval (RAG) | True | Every part is in RAG: false information stated confidently, retrieval from an authoritative source before answering, cheaper than retraining, kept current |
| Agents and least privilege | True | LLM06: minimum extensions and permissions, the user's context, human approval for high-impact actions |
| Prompt injection | True | LLM01: indirect injection from content the model reads; separate untrusted content, least privilege, human approval; no fool-proof prevention, which the card's last line says plainly |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| Agent: asks the model what to do, uses one of our app's tools, looks at the result, asks again | True |
| Menu index: menus and allergy notes as embeddings in our Postgres, $20 a month | True; the cost is illustrative |

## CURRICULUM.md, Module 13

| Claim | Verdict |
| --- | --- |
| Models make things up; design for it: show sources, keep a human in the loop | True (RAG) |
| RAG finds the relevant documents first, then gives them to the model | True (RAG) |
| Agents loop: think, use a tool, look at the result, repeat; give tools the least power they need | True (LLM06) |
| Prompt injection: text the model reads can contain instructions that hijack it; don't give a chatbot powers you wouldn't give an anonymous customer | True (LLM01, LLM06) |
| "A bigger model fixes it": better context usually helps more | True; the hotfix plays it |

No curriculum text changed.

# Episode 14 (*Finale*)

The same pass for the Finale, done before it merged: every technical claim a player can see in its entry in `data/season.json`, the board's new badge and sub-line and bubble, the live panel and the postmortem, and the three small additions to `sim/sim.gd`, against CURRICULUM.md's Capstone. Same rule: **simplify, never falsify**. Most of the episode's claims were reviewed with the episodes they come from (8 to 13); the rows below are what's new, or what the finale says differently. Reviewed November 2026.

## Sources

| Key | Source |
| --- | --- |
| YAGNI | [Yagni](https://martinfowler.com/bliki/Yagni.html), Martin Fowler: don't build a presumed future capability "until it's necessary"; the cost of build, the cost of delay (what you didn't build meanwhile) and the cost of carry (the added complexity), and the cost of repair |
| GHCA | [Responsible use of GitHub Copilot coding agent](https://docs.github.com/en/copilot/responsible-use/copilot-coding-agent), GitHub Docs: the agent works in its own branch and "can only push to a single branch"; it "may generate code that appears to be valid but may not actually be semantically or syntactically correct"; "you should review all outputs generated by the agent thoroughly prior to merging" and "carefully review and test generated code" |
| AR | As Episode 8: provider rate limits per minute, 429 past them. Anthropic's page also says limits rise as an account moves up usage tiers, and higher custom limits can be requested |
| Earlier keys | AZ, PG, PGI, MDN, 12F (Episode 8), the OLTP/OLAP and alerting sources (Episode 9), the rate-limiting and microservices sources (Episode 10), Stripe and PostgreSQL (Episode 11), GitHub, OWASP A01 and The Register (Episode 12), LLM01, LLM06, RAG and SPOT (Episode 13) |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| Every earlier behaviour on in one night, each as its own episode configured it | True as a combination | They are independent in the flow model: each reads only its own keys of `live` and adds its own load or harm. Nothing new interacts that didn't before (the scraper and the agent share the app's capacity; strangers and the agent share the model's limit, as in Episodes 12 and 13) |
| A higher rate limit multiplies the provider's cap | True (simplified) | AR: limits rise with usage tiers or on request. Tripled is illustrative; the game charges nothing for it, since tiers are reached by past spend, not a fee |
| Phones calling the model skip our app's work for searches | True | The search request no longer passes through our servers; the key must then be in the app (curriculum Modules 4 and 13: "your backend calls it, never the frontend") |
| A kept hotfix can carry its own finding, named first | True as bookkeeping | It caused what follows it on the night |
| A hotfix's needs can be boxes already on the board | True as bookkeeping | The finale's copy-job rerun needs alerts, which are on the board, not a card |
| The finale's numbers: 64,000 diners at the peak, sixty cities, the provider at two thirds of a tripled limit | True as illustration | The shapes are the season's; the scale is the story's |
| Episodes 8 to 13 unchanged | Checked | `limit_x`, `direct_ai` and hotfix `tag` are absent from every earlier episode, and every earlier hotfix need is a card; their solutions are still 14.941, 12.856, 13.113, 12.343, 11.924 and 11.097 |

## The capstone check

| Claim | Verdict | Notes |
| --- | --- | --- |
| Every box on the board earns its place against the night's replay | True of the simulation | `cases.gd` removes each of eighteen parts the season added and replays the night; every one fails it with a finding. The game says this only of this night's replay, not of every app: CURRICULUM.md's honest version ("stage 1 Forkcast is one app on one host... and that's correct") still stands, and the lesson card says to add each box when a real problem asks for it |
| Search across plans | Checked | Twelve cards and two hotfixes would be 8,192 combinations; the 16-hour budget leaves only the ones that fit (two cards never fit, and the 10- and 12-hour cards exclude each other), so the exhaustive part stays small, and the episode's checks run in about 40 seconds. No cap was needed |

## Finale text

### Cold open, brief, flash-forward

Narrative (Walter in the house, the TV diagram, the robe, eleven minutes of silence, sixty cities on Friday, the documentary ten years later and everyone's fates, End of season). Aleister's "I'll run it myself, no pull requests" is the episode's misconception, judged by the autofix hotfix. Ricky's "nobody can check anything it does at that speed" is true in spirit (GHCA: review before merging). The brief's numbers match the data: sixteen hours, 114.5 hours proposed, sixty cities. Gerard's "every box on our board is there because something went wrong without it" is what the capstone check proves for this night.

### Pull request cards and takes

| Card | Claim | Verdict | Change |
| --- | --- | --- | --- |
| Infinite servers, Gilroy | A booking crosses eight services, any can fail; twelve servers want 120 connections, we have 100 | True | Episode 10's chain; Episode 8's 10 per server against Postgres's 100 (PG) |
| Infinite servers, Danesh | It scales by itself | True of autoscaling clusters; judged by the night | |
| Sixty shards, Gilroy | The database hasn't been the problem since the index; more diners, not more kinds of data | True of this night | It peaks at a little over half its capacity |
| Live everything, Veronica | The board asked for an hour old | True | Episode 9's goal |
| Biggest model, Veronica | Five times the price; the menus already make it right | True as illustration | Episode 13 (grounding, not size, fixed the made-up menus) |
| Swarm, Gilroy | Four times the model calls | True as illustration | Episode 13 |
| ForkNet, Gilroy | Sixty cities of phones disagreeing | True | Episode 11 (eventual consistency) |
| Phones call the AI | Searches are half our servers' work; skip the middle and we need fewer | True of the simulation | Search is 1.5 of about 2.9 units of app work per diner |
| Phones call the AI, Gilroy | The key goes in the app, and the app goes on every phone | True | Episode 12; curriculum Module 4 ("anything in the frontend is public") |
| Own model, Veronica | We look the menus up already, and it works | True | RAG |
| Every region | Three copies, so a region can go down | True as a description; too big to fit | |
| Every region, Gerard | Three copies that have to agree about every table | True (simplified) | Multi-region writes need replication and agreement (curriculum Module 10, consistency) |
| AI limit x3, Ulrich | Call the provider and have the limit raised | True | AR (limits rise with tiers or on request) |
| AI limit x3, Danesh | A bigger limit is a bigger bill if strangers get the key | True | The limit also caps runaway spend |
| More servers, Veronica | Ten is what a nervous person picks; how many does Friday need? | True; seven carry it | |
| Backup provider, Gilroy | The second provider hasn't heard of the first one's deposits | True | Episode 11 |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| What's the simplest version that works? | True | Capstone checklist question 5; the answer (the board we have, plus more of the same servers) is what the night shows |
| Where's the bottleneck? | True of the simulation | One small server carries about ten thousand diners flat out (a third at 3,500); seven peak at nine tenths |
| What will this cost at 10x traffic? | True of the simulation | About twice the limit at the peak without the raise; Forkcast Infinite adds about $9,000 a month (cluster $4,000, eight more servers $1,200, shards $800, stream $3,000) |
| How do we undo a bad change? | True | Curriculum Module 2 (pull requests, rolling back) and Module 12 (review); GHCA |
| Where are the secrets? | True | Episode 12's fixes |
| Decoys | Narrative | Judged by the night |

### Dials, hotfixes, live moment

| Item | Verdict | Change |
| --- | --- | --- |
| Dial: app servers five to ten, default ten | True as a trade-off | |
| Hotfix: the copy job broke on the é in San José; handle it and rerun | True as illustration | Accented characters breaking a job that assumes plain ASCII is a classic encoding bug, Episode 9's emoji again |
| Hotfix: let Aleister fix it live, no pull request, by deleting the two slowest steps | True as offered (the misconception), and the night judges it | The hold and the ownership check do add work; removing them is what an AI optimising for speed, unreviewed, might do. GHCA: review before merging |
| Corner lines, banners | Narrative, or true as in their episodes | Banners match `live` |
| Board: HubbubBot top left, "3x limit" on the model, "calls AI" on the diners, bubble "Changed live, unreviewed!" | True | |
| Board: "Big model" as the model's label, "ForkNet" as the diners' sub-line, "sharded" as Postgres's (all three were badges or "Postgres x3" before; moved so a full board doesn't overflow) | True | "x3" was wrong for sixty shards |
| Live panel: diners, page speed, errors, bookings, AI bill, HubbubBot | True | The simulation's running numbers |

### Postmortem findings

| Tag | Verdict | Notes |
| --- | --- | --- |
| unreviewed, "unreviewed changes in production" | True | GHCA; curriculum Module 12 (code review) |
| key_in_app, "anything in the frontend is public" | True | As Episode 12 |
| too_many_connections, service_chain, forknet, backup_provider, double_charge, double_booking, idor, leaked_key, rate_limited (now naming the provider's limit), scraper, prompt_injection, hallucination, excess_agency, no_confirm, silent_failure, stale_numbers, olap_on_oltp, no_queue, no_cdn, no_cache, full_scan, stateless, app_overload, db_overload, big_model, overbuilt | True | As in the episodes they come from, reworded for sixty cities |

### Codex cards and sources

| Card | Verdict | Change |
| --- | --- | --- |
| Every box earns its place | True | YAGNI: don't build it until it's necessary; the cost of building, the delay to what's needed now, the complexity carried. "Ship the simplest version that works; add the next box when a real problem asks for it" is YAGNI's advice in the curriculum's words |
| Review what your AI ships | True | GHCA: code that looks valid may not be correct; the agent pushes to its own branch; review and test thoroughly before merging. "Don't let it change the live app by itself" follows from the agent's single-branch push access |

## CURRICULUM.md, Capstone

| Claim | Verdict |
| --- | --- |
| Every box earns its place by solving a problem Forkcast actually had | True of the season, and checked in the simulation for the finale's night |
| The honest version: stage 1 is one app, one host, one Postgres and a model call, and that's correct | True; unchanged |
| The checklist (who, what data, who may see what, failure, simplest version, how will I know, secrets, undo) | True; five of its questions are the finale's asks or its answers |

# Episodes 1 (*Pilot*) and 2 (*The Whiteboard*)

The same pass for the first two episodes, done before they merged: every technical claim a player can see in their entries in `data/season.json`, the new pieces in `data/pieces.json`, the board's new boxes, sub-lines, badges and bubbles, the live panel and the postmortem, and the additions to `sim/sim.gd`, against CURRICULUM.md's Modules 0, 1 and 2. Same rule: **simplify, never falsify**. Reviewed November 2026.

## Sources

| Key | Source |
| --- | --- |
| CCBP | [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices), Anthropic: give the agent a way to verify its work (tests, screenshots, expected output); be specific up front, naming who and what and the edge cases; have it interview you and write a spec before it builds; a vague request makes it fill gaps with guesses |
| MDNSS | [Introduction to the server side](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Server-side/First_steps/Introduction), MDN: browsers send HTTP requests to servers, which send responses; a static site returns the same hard-coded content for a URL, a dynamic site builds responses when asked, usually from a database; storing what users send needs server-side code |
| GIT | [About Version Control](https://git-scm.com/book/en/v2/Getting-Started-About-Version-Control), Pro Git: version control records changes so you can recall specific versions later, compare changes and revert a file or the whole project to a previous state |
| KA | Cunningham, Ederer and Ma, [*Killer Acquisitions*](https://doi.org/10.1086/712506), Journal of Political Economy 129(3), 2021: incumbents "may acquire innovative targets solely to discontinue the target's innovation projects and preempt future competition" (abstract read via OpenAlex; the publisher's page refuses automated fetches) |
| SPEED | [Why does speed matter?](https://web.dev/articles/why-speed-matters), web.dev: the BBC lost an extra 10% of users for every additional second its site took to load |
| Earlier keys | MDN (caching), AZ, 12F (Episode 8); GitHub's docs (Episode 12); GHCA (Episode 14) |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| Nothing built (`host: none`, or the sale kept) means nobody is served | True | |
| The share of requests a concierge answers well depends on whether it's checking against a written spec, and how much of one | True as illustration | CCBP: specific instructions and a spec are what close the gap between the request and the build. 30% on one line and 95% on one page are the story's numbers; fifty pages fit as well as one but cost six hours (the shape is diminishing returns, not "longer is worse") |
| The photo feed answers no request | True | It has nowhere to type one |
| A dynamic page loads our server for every view; a static page loads none of our servers | True | MDNSS. The static host is charged nothing, as the free tiers of the common static hosts are, at this traffic |
| A static page with no form service and no backend loses every sign-up | True | MDNSS: storing what a user sends needs server-side code; a form service is someone else's |
| Password accounts lose three in ten at the step | True as illustration | Each extra step is a place to give up; the share is the story's |
| A heavy video adds seconds to each page and loses people | True as illustration | SPEED |
| A bad change, undone by a rollback in two minutes if there's a commit from just before it; by hand in an hour and a half if not; and a rollback to a commit from before the site existed takes the site away | True | GIT: you can only revert to a saved version |
| A rollback needs Git on the board, and is offered two minutes after the break | True as bookkeeping | |
| Episodes 8 to 14 unchanged | Checked | Every new behaviour is off unless an episode configures `live.landing`, `live.fit` or a `host` of `none`; their solutions are still 14.941, 12.856, 13.113, 12.343, 11.924, 11.097 and 10.857 |

## Pilot text

### Cold open, brief, flash-forward, cliffhanger

Narrative. Galen's offer and Walter's investment are the pilot's choice; the roof is where Hubbub puts people it pays to do nothing. Walter's "Where's the waitlist?" sets up Episode 2.

### Pull request cards and takes

| Claim | Verdict | Notes |
| --- | --- | --- |
| Photo feed: built from "something with food and friends", the common thing | True | CCBP: a vague request gets filled in with guesses, often the common case |
| Photo feed: "every photo kept forever", a hundred dollars a month and growing | True as illustration | Storage is billed by the amount kept |
| Video stories, Forkcast Everything | Narrative | Too big to fit; the decoy is handing the decision to the AI |
| Ask Forkcast: a box, a model and a list of restaurants | True (simplified) | Curriculum Module 13 |
| Spell it out: a spec, every suggestion checked against all of the request | True | CCBP: write a spec; give it something to check its work against |
| Sell out (to Hubbub); Ricky: why pay for an idea unless you want nobody to build it | True | KA |
| Postmortem `sold`: "an acquisition to shelve a rival (a 'killer acquisition')" | True | KA. The game doesn't say this is why every acquisition happens, only this one |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| What do you think Forkcast is? | True | CCBP: ask the AI what it understood before it builds |
| What will Walter's diners ask it? | True | CCBP: name who it's for and what they'll do; the edge cases go in the spec |
| What will this cost? A couple of cents a question | True as illustration | Model prices per request are in cents at this size; $217 for the night |
| You decide (decoy) | Narrative | Judged by the night |

### Postmortem findings and codex cards

| Item | Verdict | Notes |
| --- | --- | --- |
| wrong_thing, vague, nothing_built, overbuilt | True | CCBP |
| Card: Say what you want built | True | CCBP: be specific; say who, what and what done looks like; have it interview you until it could write a spec |
| Card: Check what it built | True | CCBP: "give Claude a way to verify its work"; it stops when the work looks done. "Try it yourself the way a real user would" is the same advice for someone who doesn't write tests |

## The Whiteboard text

### Pull request cards and takes

| Claim | Verdict | Notes |
| --- | --- | --- |
| Landing page built fresh for every visitor from the database | True | MDNSS (dynamic) |
| Backend: builds the same page forty thousand times | True of this plan | |
| Postgres at $400 a month, for a list of emails | True as illustration | A managed database at a size Aleister picked; small ones cost far less, which is Gilroy's point |
| Accounts: a password and email check, to wait | True | |
| Phone apps: the app stores take days to review | True (simplified) | Review times vary; first submissions often take a day or more |
| Static site: plain files, built once, on a host that copies them to servers near everyone | True | MDNSS; the common static hosts serve through a CDN (Episode 8's CDN) |
| Form service: someone else's backend for one box | True | MDNSS: the sign-up still needs server-side code, just not ours |
| Use Git: commits, history on GitHub, go back to any of them | True | GIT |
| Just undo it (Ulrich, wrong); Gilroy: it remembers what sites are usually like, not ours | True | Curriculum Module 2's misconception: without version control there may be nothing to undo to |
| Launch video; postmortem "every extra second a page takes to open loses more of the people waiting for it" | Fixed | It said pages over three seconds lose people; the hard cutoff wasn't supported by a source I could read. Now SPEED's shape |
| Accounts postmortem: "every extra step is a place to give up" | Fixed | It said every extra step loses people, as a rule |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Does this need a backend? Static, plus somewhere to keep the sign-ups | True | Curriculum Module 1's line; MDNSS |
| How do we undo a bad change? Aleister edits the live site directly | True as the problem | GIT |
| Draw me how it works: client, request in HTTP, DNS like a phone book, response; dining room, kitchen, reservations book | True (simplified) | MDNSS; the restaurant analogy is the curriculum's |
| What will Saturday look like? A third of forty thousand, with the party, about fourteen thousand | Fixed | It said a third was fourteen thousand; a third is 13,333 |
| One small server builds about a hundred pages a second; fourteen thousand people is about a hundred and forty a second | True as illustration | The simulation's numbers: each visitor loads about a page a minute and a half |
| Make it look impressive (decoy) | Narrative | |

### Dials, hotfix, live moment, postmortem, codex cards

| Item | Verdict | Notes |
| --- | --- | --- |
| Dial: commit once a day or before every change | True as a trade-off | GIT |
| Hotfix: roll back to the last commit | True | |
| Postmortem: landing_overload, no_page, no_server, nowhere_to_sign_up, no_git, rollback_skipped, commit_often, rolled_back | True | MDNSS, GIT |
| Postmortem: bad_change, "an unreviewed change in production" | True | GHCA (Episode 14) |
| Card: Client and server | True | MDNSS |
| Card: Static or dynamic | True | MDNSS |
| Card: Version control | True | GIT. "Commit before each change" is advice, not Git's rule |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| visitors, prototype, feed, landing, backend, signups_db, form, git | True; plain-words descriptions match the cards |

## CURRICULUM.md, Modules 0, 1 and 2

| Claim | Verdict |
| --- | --- |
| Most AI failures are the wrong thing built well, from a vague request | True as the curriculum's framing; CCBP |
| Client and server, request and response, static and dynamic | True; MDNSS |
| "I'll just ask the AI to undo it" is a misconception without version control | True; GIT |

# Episodes 3 (*Tabs and Spaces*) and 4 (*Demo Day*)

The same pass for Episodes 3 and 4, done before they merged: every technical claim a player can see in their entries in `data/season.json`, the new pieces and the language table in `data/pieces.json`, the board's new boxes, sub-lines, badges and bubbles, the live panel and the postmortem, and the additions to `sim/sim.gd`, against CURRICULUM.md's Modules 3, 4, 5 and 13. Same rule: **simplify, never falsify**. The language lesson was written to the stricter rule in the handoff: no language is called simply better, and types are never said to prevent all bugs. Reviewed November 2026.

## Sources

| Key | Source |
| --- | --- |
| TSB | [The Basics](https://www.typescriptlang.org/docs/handbook/2/basic-types.html), TypeScript Handbook: a static type checker finds bugs "before our code runs"; `user.location` on an object without it is an error ("Property 'location' does not exist"); typos are among the bugs it catches; plain JavaScript returns `undefined` for a missing property instead of throwing ("non-exception failures"); "TypeScript catches a lot of legitimate bugs" (a lot, not all) |
| LRL | Giagnorio, Martin-Lopez and Bavota, [*Enhancing Code Generation for Low-Resource Languages: No Silver Bullet*](https://arxiv.org/abs/2501.19085), ICPC 2025: LLMs learn languages from their training data; for niche languages with scarce training data, "poorer code generation performance as compared to high-resource languages" |
| MAR | [marimo docs](https://docs.marimo.io/): run a cell and marimo reactively runs all dependent cells; notebooks are stored as pure Python `.py` files; executable as a script, deployable as an app; designed for data |
| ZIG | [Zig downloads](https://ziglang.org/download/): the latest release is 0.17.1, before version 1.0 |
| MDNF | [Client-side form validation](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Forms/Form_validation), MDN: client-side validation "is too easy to bypass"; always validate on the server, including security checks; "Never trust data passed to your server from the client"; a malicious user "can still alter the network request" |
| VT | As Episode 12: Vite, variables bundled into client-side code "should not contain sensitive information such as API keys" |
| RWD | [Responsive design](https://developer.mozilla.org/en-US/docs/Learn_web_development/Core/CSS_layout/Responsive_Design), MDN: make pages render well on all screen sizes; a single-column layout for phones first, then wider layouts, is "mobile first" design |
| Earlier keys | AR (rate limits, Episode 8), AP (tokens and prompt caching, Episode 8), OS and GH (Episode 12) |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| The AI makes some logic mistakes in every language; they reach the night whatever the language, and types don't stop them | True | TSB says a lot of bugs, not all; a wrong rule (the wrong night) type-checks fine. 1.5% of requests is illustrative |
| More mistakes in a language the AI has seen little of (Zig five times as many, Rust one and a half) | True (simplified) | LRL: worse code generation where training data is scarce. The multipliers are the story's. Rust is far more common than Zig but less common than TypeScript in public code, so a small factor; the game never says the AI writes Rust badly, only that it's slower to get through its compiler |
| Type-shaped mistakes (a misspelt field) reach the night in a dynamic language and are stopped before running by a static type checker | True | TSB (`location`, typos, JavaScript's silent `undefined`). Python raises an error at run time instead of carrying on; the game's notebook-as-app counts both as a failed request. Python's optional type hints with a checker would catch them too; the game doesn't offer that option and doesn't claim otherwise |
| A backend in a different language from the TypeScript web app adds mistakes at the boundary; one TypeScript codebase can share one definition of a booking | True (simplified) | Two hand-written definitions of the same request can drift, and no compiler checks one against the other; shared types (or a schema with generated code) are the usual fix. The 4% is the story's |
| Rust and Zig do the same work with less of the server, and it makes no difference at two hundred diners | True | Curriculum Module 3's misconception, "fast languages make fast apps"; the model's two seconds dominate a search (Episode 8's model latency) |
| Rust takes six more hours, Zig two | True as illustration | Curriculum Module 3: quick to write against quick to run, and Rust's steeper learning curve; the hours are the story's |
| A notebook running the app stops when the laptop it's open on closes | True of this plan | A notebook open on a laptop runs on that laptop. marimo notebooks can also be deployed as apps (MAR); the card is a notebook on Veronica's laptop, and the finding says "on the computer it's open on" rather than claiming notebooks can't serve |
| Walter's question answered by the notebook in an hour, or the investor page in seven | True as illustration | MAR (designed for data) |
| A fee worked out in the app is whatever the phone sends; edits from a scripted tick, spreading through the room | True | MDNF. The shares (a twentieth to a third) are the story's |
| Hiding the price box changes nothing | True | MDNF: the request can be altered whatever the page shows; curriculum Module 4's misconception |
| A fee worked out on the server ignores edits | True | MDNF |
| A desktop layout loses four in ten bookings from phones | True as illustration | RWD. The share is the story's |
| The key in the app is read by a scanning bot and used on our bill | True | As Episode 12 (VT); only the app's code is exposed here, no history and no package |
| Episodes 1, 2 and 8 to 14 unchanged | Checked | Every new behaviour is off unless an episode configures `live.code`, `live.tamper` or `live.mobile`. Not calling the model when nothing is built now applies to every episode, not just those with `live.fit`; only Episode 1 has a night with nothing built. The garage's overload findings now leave out requests lost to bugs, which only Episode 3 has. Runways to nine places: 13.318880000, 12.649255493, 14.940986471, 12.855844240, 13.113089652, 12.342914808, 11.924450744, 11.096754439 and 10.857063317, before and after |

## Tabs and Spaces text

### Cold open, brief, cliffhanger

Narrative. Danesh's and Gilroy's pitches for Zig and Rust are opinions, and the episode judges them. Tabs against spaces is a style preference with no right answer, which is the joke. "When it rains, people book more" is the story's chart, not a claim about restaurants.

### Pull request cards and takes

| Claim | Verdict | Notes |
| --- | --- | --- |
| Write the backend: search, tables, bookings, the model calls | True | Curriculum Module 5 |
| Gilroy: Rust's compiler checks everything before it runs | Narrative | "Everything" is too strong as a fact, so it stays Gilroy's boast, and the game's own line (his answer to the language ask) says "whole kinds of mistakes", which is true |
| Web app: TypeScript with React, what the AI writes best because it's seen most of it | True | LRL (the other way round); curriculum Module 4: React is what AI tools build with by default |
| Ricky: TypeScript turns into JavaScript, which every browser runs | True | Curriculum Module 3 (the first draft said the browser runs this half; browsers run the JavaScript it becomes) |
| Investor page, A language each | Narrative | Too long to fit |
| Notebook: marimo, Python, a file in Git | True | MAR (plain `.py` files) |
| Ricky: Python is where the data tools are; a notebook is for a question, not for running the app | True | Curriculum Module 3 |
| Notebook it (Ulrich, wrong); Gilroy: a lab bench, and this one is Veronica's laptop | True of this plan | See the shapes table |
| Biggest server; Gilroy: Aleister uses about three percent of itself | True | The simulation's garage runs at about 3% in the solution |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Which language? Ricky: a booking written down once for both halves; what Aleister has seen most | True | Curriculum Module 3's rules of thumb (one language front and back; popular, boring tools); LRL |
| Aleister: Zig isn't at version one yet, so it keeps changing | True | ZIG (0.17.1). Releases before 1.0 make breaking changes; the line doesn't quantify them |
| What do types catch? `booking.partySise` stopped before it runs; plain JavaScript runs it and the party size is missing | True | TSB |
| Gilroy: types don't catch a booking for the wrong night | True | A logic error type-checks |
| Can we answer Walter's question? A notebook job | True | Curriculum Module 3 |
| Where does the time go? Two seconds, nearly all of it the model; our code takes milliseconds | True as illustration | The model's latency is Episode 8's; a model call taking seconds and app code milliseconds is the usual shape |

### Dials, live moment, postmortem, codex cards

| Item | Verdict | Notes |
| --- | --- | --- |
| Dial: Zig, Rust, JavaScript, TypeScript, with build hours | True as illustration | See the shapes table |
| Postmortem: no_frontend, no_backend | True | Curriculum Module 1 |
| Postmortem: notebook_app, "a notebook used as a backend" | True of this plan | Worded about this notebook on this laptop |
| Postmortem: type_bugs, "type errors found only when it runs" | True | TSB |
| Postmortem: unfamiliar, "far less Zig to learn from than TypeScript"; Zig's compiler caught the type mistakes | True | LRL; Zig is statically typed |
| Postmortem: boundary | True (simplified) | See the shapes table |
| Postmortem: logic_bugs, "types don't catch everything"; finding them takes tests | True | TSB says a lot; curriculum Module 12 |
| Postmortem: overbuilt, "a fast server doesn't make a fast app" | True of this night | Curriculum Module 3's misconception |
| Card: Types | True | TSB, each clause |
| Card: Pick a language the AI knows | True | LRL |
| Card: Notebooks | True | MAR, each clause |

## Demo Day text

### Cold open, brief, cliffhanger

Narrative. The bags, Chaz and his fax machines, Walter's yes. Gerard's spreadsheet sets up Episode 5.

### Pull request cards and takes

| Claim | Verdict | Notes |
| --- | --- | --- |
| Booking fee: charged by card through a payment provider; the app works out the fee and tells the server what to charge | True as the problem | Curriculum Module 5 (third-party services); MDNF |
| Straight to AI: one less hop, and the key goes in the app so the phone can use it | True | A browser calling a provider directly needs a credential in the browser; VT |
| Voice concierge | Narrative | Too long to fit |
| Price on server: the server works out the fee from the booking and ignores what the app says | True | MDNF; curriculum Module 5, "the backend is where the rules live" |
| Hide it (Ulrich, wrong); Gilroy: hidden from the screen, not from the code on their phone | True | MDNF; curriculum Module 4's misconception |
| Biggest AI model: five times the price per answer | True as illustration | As Episode 8 |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Who decides the price? Anyone can open the developer tools and change what it sends | True | MDNF ("alter the network request"); every desktop browser has developer tools |
| Where's the model key? Bots read new apps' code for keys all day | True (simplified) | As Episode 12's key_in_app row |
| Will it work on a phone? Mobile first | True | RWD |
| What does each answer cost? Tokens in and out; about two cents | True as illustration | AP: models bill per token; the price is the game's |

### Dials, live moment, postmortem, codex cards

| Item | Verdict | Notes |
| --- | --- | --- |
| Dial: desktop or mobile first | True as a trade-off | RWD |
| Postmortem: no_fee | Narrative | |
| Postmortem: price_in_app, "trusting the client" | True | MDNF |
| Postmortem: hidden_price, "hiding isn't security"; hiding a button changes what people see, not what they can do | True | MDNF |
| Postmortem: key_in_app | True | VT; as Episode 12 |
| Postmortem: not_mobile | True | RWD |
| Card: Never trust the frontend | True | MDNF: easy to bypass, the request can be altered, validate on the server. "Prices included" applies the rule to Forkcast |
| Card: No keys in the app | True | VT: bundled into client-side code; never API keys |
| Card: Mobile first | True | RWD, both definitions |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| front, mvp, notebook | True; the notebook's "change one cell and the cells that depend on it run again" is MAR |
| languages (typed, familiar, work_x) | True as illustration: TypeScript, Rust and Zig are statically typed, JavaScript and Python dynamically; the factors are the story's |

## CURRICULUM.md, Modules 3, 4, 5 and 13

| Claim | Verdict |
| --- | --- |
| Static types catch a lot of AI mistakes automatically | True; TSB ("a lot") |
| AI assistants are better in popular languages because they've seen more of them | True; LRL |
| marimo: reactive, plain Python files, can become an app | True; MAR |
| Hiding a button keeps people out (misconception) | True as a misconception; MDNF |
| The backend calls the model, never the frontend, so the key stays secret | True; VT |

# Episodes 5 (*The Spreadsheet*) and 6 (*Log In*)

The same pass for Episodes 5 and 6, done before they merged: every technical claim a player can see in their entries in `data/season.json`, the new pieces in `data/pieces.json`, the board's new boxes, sub-lines, badges and bubbles, the live panel and the postmortem, and the additions to `sim/sim.gd`, against CURRICULUM.md's Modules 5, 6 and 11. Same rule: **simplify, never falsify**. Reviewed November 2026; every source below was fetched for this pass.

## Sources

| Key | Source |
| --- | --- |
| PGT | [Transactions](https://www.postgresql.org/docs/current/tutorial-transactions.html), PostgreSQL tutorial: a transaction "bundles multiple steps into a single, all-or-nothing operation"; "the intermediate states between the steps are not visible to other concurrent transactions"; "when multiple transactions are running concurrently, each one should not be able to see the incomplete changes made by others" |
| SRE | [Data Integrity: What You Read Is What You Wrote](https://sre.google/sre-book/data-integrity/), Google's *Site Reliability Engineering*: "No one really wants to make backups; what people really want are restores"; "you only know that you can recover your recent state if you actually do so"; "replication and redundancy are not recoverability"; "a corrupt database row or errant delete are pushed to all of your copies" |
| BOLA | [API1:2023 Broken Object Level Authorization](https://api-security.owasp.org/editions/2023/en/0xa1-broken-object-level-authorization), OWASP API Security Top 10: attackers manipulate "the ID of an object that is sent within the request"; Scenario 1 swaps shop names in the URL to read thousands of stores' sales data; check access "in every function that uses an input from the client to access a record in the database" |
| PWS | [Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), OWASP: "Passwords should never be stored in plain text"; salting protects against "pre-computing hashes using rainbow tables or database-based lookups"; MD5 and SHA-1 "were designed to be fast" and are poor choices; use "strong, slow hashing algorithms such as Argon2id, bcrypt, or PBKDF2" |
| CS | [Credential Stuffing Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Credential_Stuffing_Prevention_Cheat_Sheet.html), OWASP: credential stuffing is "testing username/password pairs obtained from the breach of another site", relying on password reuse; defences include multi-factor authentication, limiting a client's request rate, checking new passwords against breached password datasets, and bot detection |
| NIST | [SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html), NIST Digital Identity Guidelines: verifiers "SHALL NOT impose other composition rules" and "SHALL NOT require subscribers to change passwords periodically"; compare new passwords against a blocklist of commonly used, expected or compromised ones; passwords "SHALL be salted and hashed"; a rate-limiting mechanism "that effectively limits the number of failed authentication attempts" |
| SQLI | [SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html), OWASP: "SQL injection occurs when untrusted data becomes part of a query's SQL syntax"; prepared statements "treat bound values as data rather than SQL syntax" |
| Earlier keys | The race (Episode 11), IDOR and the lawyer (Episode 12) |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| A spreadsheet written by "read the sheet for the next empty row, then write there" loses a booking when two land inside the gap; the later write wins | True of this code | It's the lost-update shape of any read-then-write with nothing holding the data in between. The card and the ask describe this code, Aleister's, not every way of writing to a spreadsheet (a spreadsheet's own append call is safer); the misconception the episode answers is curriculum Module 6's "a spreadsheet is a database, until two people edit it at once" |
| The gap grows with the rows already in the sheet | True (simplified) | Reading the whole sheet takes longer the bigger it is. A second plus 0.05 ms a row is illustrative |
| The share written over is 1 − e^(−b × gap ÷ tabs) | True | The chance another Poisson arrival lands inside the gap. Forty tabs divide the rate per tab, so collisions are rarer and still happen |
| The last table goes twice through Episode 11's race, with the spreadsheet's gap; in Postgres the gap is Episode 11's fifty milliseconds and the night's expected double bookings round to nobody | True (simplified) | As Episode 11 (h²w/H). The finding says a database narrows the gap from seconds to milliseconds, not that it closes it; Episode 11 closes it with a transaction. `tag_min` keeps a night whose expected count is a fifth of a booking from naming the finding; the expected comps are still on the bill |
| A database writes each booking whole and doesn't let one write wipe out another | True | PGT (all-or-nothing, concurrent changes not seen half done). Postgres runs each statement as its own transaction |
| A scripted deletion of the restaurants by the AI, tidying up test data | Narrative, and a real kind of incident | An AI agent with database access deleting production data has happened; the game shows one way, without naming any company |
| A backup restored before comes back in fifteen minutes; one never restored is empty (it copied the test database) | True of this backup | SRE: you only know you can restore by doing it. The game doesn't say every untested backup is empty; the finding says this one had been copying the wrong database and nobody knew |
| A live copy deletes them too | True | SRE: an errant delete is pushed to all copies; replication isn't recoverability |
| Rebuilt from the AI's memory: back in ten minutes with a third of the tables made up | True (simplified) | A model asked to recreate data it doesn't have fills gaps with what's plausible (Episode 13's grounding, curriculum Module 13); the share is the story's. Module 6's misconception "the AI can fix my data later" |
| Bots try email and password pairs leaked from another site; a share work because of reuse; a home-made login with no limit lets every one in; a login service stops nearly all | True (simplified) | CS. "Nearly all": the service's pass-through is one in five thousand, a tenth of an account all night here, not zero |
| A home-made login that builds its query from what's typed hands over the users table | True of this code | SQLI. The finding is about Aleister's login, and says proven login code doesn't build queries that way |
| The stolen table is readable as stored: as typed, all; a fast unsalted hash, nine in ten by lookup; a slow salted hash, none that night | True (simplified) | PWS: salts defeat precomputed lookups; fast hashes are cheap to attack; slow ones are costly per guess. The shares are the story's; "none that night" is a statement about one night, and the slow-hash plan still fails for the stolen accounts and the stolen table |
| A login service keeps the passwords itself | True | That's the product (curriculum Modules 5 and 11: "better still, use an auth provider and don't store them at all") |
| Password rules make a third of the focus group give up | True as illustration | NIST: no composition rules or periodic changes. The share is the story's |
| A restaurant changes the number in the address bar and reads another restaurant's bookings, without the ownership check | True | BOLA, Scenario 1 (shops in the URL). Episode 12's `live.idor`, with its own `guard` and `needs` |
| Every other episode unchanged | Checked | Every new behaviour is off unless an episode configures `live.sheet`, `live.wipe` or `live.login`; `guard` defaults to `owner_check`, `needs` to nothing, `tag_min` to zero. All eleven runways match to nine places (see HANDOFF.md) |

## The Spreadsheet text

### Cold open, brief, cliffhanger

Narrative. Gerard's teal, Ulrich feeling his bookings, the man from Daly City and his mother, Gerard's archived spreadsheet. Ricky's question in the cold open is the episode's ask.

### Pull request cards and takes

| Claim | Verdict | Notes |
| --- | --- | --- |
| One tab each: fewer bumps; Ricky: still nothing stopping two landing on one row | True | See the shapes table |
| Nightly backups, kept off Aleister; Gilroy: never restored, it's a file | True | SRE |
| Own database | Narrative | Too long to fit |
| Postgres on Aleister: each booking written whole, two at once don't write over each other | True | PGT |
| Ricky: tables, keys, a schema; nothing typed out twice | True | Curriculum Module 6 |
| Restore drill: restore onto a spare database and check | True | SRE |
| Live copy: copies every change; Gilroy: including the ones you'll regret | True | SRE |
| Keep it (the sheet; Ulrich, wrong): a spreadsheet is a database | True as a misconception | Curriculum Module 6 |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| What if two people book at once? Gilroy's reading of Aleister's code; Ricky: that's what a database is for | True | See the shapes table; PGT |
| Have we ever restored a backup? A backup you've never restored is a hope | True | SRE; curriculum Module 6's own line |
| Show me the schema first: three tables pointing at each other; a name changed once | True | Curriculum Module 6 (keys instead of copies) |
| Make sure we never lose anything (decoy) | Narrative | |

### Hotfix, live moment, postmortem, codex cards

| Item | Verdict | Notes |
| --- | --- | --- |
| Hotfix: put the restaurants back from memory | True as the trap | See the shapes table |
| Postmortem: overwritten, "lost updates: a spreadsheet isn't a database" | True | |
| Postmortem: double_booking, "a race condition"; milliseconds in a database, not a second or more | True | As Episode 11 |
| Postmortem: no_backup, untested_backup, copy_not_backup, restored | True | SRE |
| Postmortem: ai_rebuilt, "an AI fills gaps with what's likely" | True | Curriculum Module 0 and 13 |
| Card: Transactions | True | PGT, each clause; "that's what lets many people book at once" applies it to Forkcast |
| Card: Test your backups | True | SRE, both halves |
| Card: A copy isn't a backup | True | SRE |

## Log In text

### Cold open, brief, cliffhanger

Narrative. The fitness app is unnamed and made up. Gilroy: every leaked password is tried on every login on the internet today; true in spirit (CS: bots test breached pairs against other sites), and it's his line. Ulrich's buttons are the joke; the card doesn't claim the buttons are why it works.

### Pull request cards and takes

| Claim | Verdict | Notes |
| --- | --- | --- |
| Accounts: the passwords as typed, so Aleister can email them back | True as the problem | PWS. A site that can email you your password is storing it readably |
| Danesh: logins are a solved problem; Gilroy: solved by other people | Narrative, and true | Curriculum Module 5 |
| Forkcast ID | Narrative | Too long to fit |
| Login service (Ulrich, right): keeps the passwords, limits guesses, checks for leaked ones, sends resets | True | Curriculum Module 5; CS lists the defences such services offer. The $100 a month is illustrative |
| Veronica: a hundred a month, forever | True as a trade-off | |
| Check the owner: answer as if it doesn't exist | True | BOLA; as Episode 12 |
| Danesh: normal people don't know the address bar is there | Narrative | Curriculum Module 5's misconception, "users won't call my API directly"; the night disproves it |
| Password rules; Veronica's pizza line | True as the trap | NIST |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| Who can see each restaurant's bookings? Change the seven to an eight | True | BOLA |
| What stops someone guessing passwords? Reuse; a limit, a leaked-password check, two-factor | True | CS; NIST |
| How are the passwords stored? Slow salted hash like bcrypt; fast like plain SHA-256 looked up in tables made in advance | True | PWS (SHA-256 isn't named there, but it's a fast general-purpose hash of the same family as SHA-1; unsalted, it's open to precomputed lookups) |
| How does it remember I'm logged in? A session, a random number in a cookie; or a signed token, a JWT | True | Curriculum Module 5 |
| Make it unhackable (decoy) | Narrative | |

### Dials, live moment, postmortem, codex cards

| Item | Verdict | Notes |
| --- | --- | --- |
| Dial: as typed, fast hash, slow and salted (+1h); no effect with the service | True | PWS |
| Postmortem: idor | True | BOLA |
| Postmortem: stuffing, "credential stuffing" | True | CS |
| Postmortem: sql_injection | True | SQLI |
| Postmortem: plain_passwords | True | PWS |
| Postmortem: fast_hash, "hashed is not the same as safe" | True | PWS |
| Postmortem: pw_rules, "the standard now says not to demand symbols or regular changes" | True | NIST |
| Postmortem: no_login | Narrative | |
| Card: Check the owner, every time | True | BOLA (check in every function that takes a record's ID) |
| Card: Never store passwords as typed | True | PWS, each clause |
| Card: Password rules that work | True | NIST, each clause |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| sheet, bookings_db | True; see the shapes table and PGT |
| backups, live_copy | True; SRE. The prices are illustrative |
| auth_service, home_login | True; curriculum Module 5 |

## CURRICULUM.md, Modules 5, 6 and 11

| Claim | Verdict |
| --- | --- |
| Files and spreadsheets break when two people write at once | True as the shape; see the shapes table |
| Transactions: all together or not at all | True; PGT |
| Backups, tested by actually restoring one | True; SRE |
| Authentication against authorization | True; BOLA |
| Prefer an established auth service or library over a home-made login | True; CS and PWS list what a home-made login has to get right |
| Passwords stored hashed, never as text | True; PWS, NIST |
| Authorization on every request; changing a number in the URL | True; BOLA |

# Episode 7 (*Launch Party*)

The same pass for Episode 7, done before it merged: every technical claim a player can see in its entry in `data/season.json`, the new pieces in `data/pieces.json`, the board's new boxes, sub-lines, badges and bubbles, the live panel and the postmortem, and the additions to `sim/sim.gd`, against CURRICULUM.md's Modules 8 and 12. Same rule: **simplify, never falsify**. Reviewed November 2026; every source below was fetched for this pass.

## Sources

| Key | Source |
| --- | --- |
| CI | [Continuous Integration](https://martinfowler.com/articles/continuousIntegration.html), Martin Fowler: "works on my machine" is a well-known phrase for a reason, and a clean build catches what a local one misses; anyone should be able to "bring in a clean machine, check the sources out of the repository, issue a single command"; self-testing code is "a necessary prerequisite"; set up the test environment "to be as exact a mimic of our production environment as possible", since "every difference results in a risk that what happens under test won't happen in production"; with automated deploys, "automated rollback", to "quickly go back to the last known good state" |
| TC | [TestCoverage](https://martinfowler.com/bliki/TestCoverage.html), Martin Fowler: coverage "is of little use as a numeric statement of how good your tests are"; "high coverage numbers are too easy to reach with low quality testing", tests without assertions being the extreme; it's useful for "finding untested parts of a codebase" |
| SEN | [Usage](https://docs.sentry.io/platforms/javascript/usage/), Sentry JavaScript SDK docs: the SDK "automatically reports errors, uncaught exceptions, and unhandled rejections"; an error the code handles itself is reported by passing it to `captureException()` |
| Earlier keys | VT (a key in the frontend is public; Episode 12), YAGNI (Episode 14), GIT (Episodes 1 and 2) |

## The simulation's new shapes

| Shape | Verdict | Notes |
| --- | --- | --- |
| Deployed from a laptop, a change goes out as it is, with that laptop's settings; nothing runs the tests or tries it first, and there's no earlier build to go back to | True (simplified) | CI ("works on my machine"; a clean machine from the repository). "No earlier build" is true of Melon's copying-up, not of every laptop deploy; the finding says so of his |
| Melon's copy has the model key in the app, so it'd work on his machine; bots read it within the hour | True of this copy | VT, as Episode 12. The copy, not laptops in general, carries the key; the board's `deploy.laptop` override is Melon's |
| Tests stop a change that breaks what they check, and only that: 212 tests that open the home page let a broken booking through | True | TC (high counts with low-quality tests); CI (a test suite catches what it's written to catch) |
| A broken save that still says "Booked!" is silent: no error is thrown, so nothing reports it, and it's found when diners turn up | True (simplified) | A bug that returns success throws nothing for error tracking to catch (SEN reports errors and unhandled exceptions). Thirty minutes until someone says so is the story's |
| Staging with the host's settings stops a change that breaks on the host's settings | True | CI (mimic production; every difference is a risk) |
| A bug only real data shows (an apostrophe in a restaurant's name) gets past tests and staging with made-up data | True | A classic; CI's "every difference results in a risk" covers data as well as settings. The finding says to test with realistic data and to track errors for what still gets through |
| With error tracking, a loud break is heard in two minutes; without, in thirty, from a guest | True (simplified) | SEN (reported automatically as it happens). The minutes are illustrative |
| An app that catches every error and shows "Enjoy the party!" reports nothing, even with tracking | True of this code | SEN: a handled error is reported only if the code passes it on (`captureException`). The finding's advice is a friendly page that still reports |
| From CI, a rollback to the last build takes two minutes; a fix written live takes forty | True (simplified) | CI (automated rollback to the last known good state). The minutes are the story's |
| A second region gets a bad deploy too, and costs another host | True | A deploy goes to every region it's configured for; redundancy protects against a region failing, not against shipping a bug. The postmortem calls it over-engineering for one night (YAGNI) |
| Kubernetes takes twenty hours | Narrative | Too long to fit, as other episodes' too-big cards |
| Every other episode unchanged | Checked | `live.deploy` is off unless an episode configures it; the `"noticed"` hotfix tick only applies to a hotfix that says so; the pieces' monthly costs only count when their keys are on. All thirteen other runways match to nine places (see HANDOFF.md) |

## Text

### Cold open, brief, cliffhanger

Narrative. The ice sculpture, Melon's card, Gerard's balloons. Melon's "it works on my machine" is the misconception the episode answers (CI). Gilroy's line about the host's first bill sets up Episode 8.

### Pull request cards and takes

| Claim | Verdict | Notes |
| --- | --- | --- |
| Go live: a platform host runs the code, with a managed Postgres beside it | True | Curriculum Module 8. The $700 a month is illustrative |
| Tests: 212, all passing; Gilroy: nobody's asked what they check | True as the trap | TC |
| Deploy from CI: a clean machine builds from Git, runs the tests, deploys that build, keeps the last one | True | CI |
| Staging: same host, same settings, made-up diners; pages opened before it goes live | True | CI. $100 a month is illustrative |
| Error tracking: unhandled errors, on phones and the server, sent as they happen, with where | True | SEN (the JavaScript SDK; server SDKs do the same). $30 a month is illustrative |
| Kubernetes: scales to millions | Narrative | Aleister's overreach; it doesn't fit the night |
| Second region: it can never go down; Gilroy: a bad deploy goes to both | True | See the shapes table |
| No errors (Ulrich, wrong): catch everything, say "Enjoy the party!" | True as the trap | SEN |

### Asks

| Ask | Verdict | Notes |
| --- | --- | --- |
| How does the code get onto the host? Melon's three-week-old copy; Ricky: CI | True | CI |
| What do the tests check? Each opens the home page; a test should book a table and look it up | True | TC |
| Where do we try a change before diners see it? Staging | True | CI |
| How will we know if something breaks? Error tracking, before a diner tells us | True | SEN |
| What will this cost at 10x the traffic? The host is flat; the AI is per question, about nine thousand tonight; ten times the diners is ten times the AI bill | True | As earlier episodes: a per-request model bill scales with use. Tonight's model bill in the simulation is $8.7k |
| Make sure it never goes down (decoy) | Narrative | It adds the second region |

### Dials, hotfix, live moment, postmortem, codex cards

| Item | Verdict | Notes |
| --- | --- | --- |
| Dial: tests check "page opens" or "a booking" (+1h) | True | TC |
| Hotfix: roll back to the last good build, or Aleister writes a fix live | True | CI |
| Postmortem: laptop_deploy | True | CI |
| Postmortem: key_in_app, "anything in the frontend is public" | True | VT; as Episode 12 |
| Postmortem: no_tests, "a regression, with no tests"; wrong_tests, "tests that check the wrong thing" | True | TC; CI |
| Postmortem: no_staging, real_data | True | CI |
| Postmortem: no_tracking, errors_hidden ("show a friendly error page, and still report every error") | True | SEN |
| Postmortem: rollback, no_rollback ("roll back first, then fix") | True | CI |
| Postmortem: garage_melt, overbuilt | True | As Episodes 8 and 14 |
| Card: Deploy from CI, not a laptop | True | CI, each clause ("tries it somewhere set up like production": the production mimic) |
| Card: Check what the tests check | True | TC |
| Card: Hear about errors first | True | SEN, both halves |

### `data/pieces.json`

| Piece | Verdict |
| --- | --- |
| platform | True; curriculum Module 8 |
| laptop, ci | True; CI |
| staging | True; CI. The price is illustrative |
| tracking | True; SEN. The price is illustrative |
| region | True; see the shapes table. The price is illustrative |

## CURRICULUM.md, Modules 8 and 12

| Claim | Verdict |
| --- | --- |
| Deploy from a pipeline, not a laptop; what's in Git is what's live | True; CI |
| Staging before production | True; CI |
| Rollback to the last good build | True; CI |
| Tests that check the right thing; many passing tests can check little | True; TC |
| Error tracking, so you hear before your users tell you | True; SEN |
