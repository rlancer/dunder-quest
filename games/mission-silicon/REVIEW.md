# Technical review: Episodes 8 (*Viral*), 9 (*The Board Meeting*), 10 (*Hubbub Dine*) and 11 (*Charged Twice*)

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
