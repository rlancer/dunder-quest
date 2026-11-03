# Curriculum: how software gets built (for people building with AI)

Working title for the fourth game. This is the curriculum only; the game gets planned from it later. Nothing here is a game design decision yet, apart from the notes in [For the game](#for-the-game) at the end.

## Who it's for

People who aren't programmers and want to build things, mostly web apps, by working with an AI coding assistant. Founders, designers, product managers, analysts, small-business owners, curious parents.

They don't need to write code. The AI does that. What they lack is the map: the names of the pieces, what each one is for, where things usually go wrong, and which questions to ask. Without the map they can't tell a good plan from a bad one, can't describe what they want, and can't tell when the AI is confidently building the wrong thing.

## What "enough" means

By the end, a learner can:

1. **Name the parts** of a typical web app (frontend, backend, database, cache, hosting) and say what each one does, in plain words.
2. **Read an AI's plan** and follow it: "a Next.js frontend on Vercel, a FastAPI backend, Postgres with a Redis cache" should mean something.
3. **Ask for the right thing**: describe a feature in terms of where its data lives, who's allowed to see it, and what happens when it fails.
4. **Spot the classic mistakes**: secret keys in the frontend, no backups, building for a million users on day one, a spreadsheet pretending to be a database.
5. **Know the trade-offs exist** even when they can't make the call alone: why you'd pick Go over Python, a warehouse over your main database, a cache over a faster server.

Explicitly out of scope: writing code by hand, algorithms, data structures beyond "list" and "table", computer science theory, and any one framework in depth.

## How it teaches

- **One app, growing.** Every module adds to the same running example (below), so each concept arrives when the app needs it, not as a list of definitions.
- **Analogies first, real names second.** Each concept gets an everyday picture, then the term the AI will actually use. The real term always appears, because the learner will meet it.
- **Every concept answers "so what?"** What breaks if you don't know this, and what to say to your AI.
- **Misconceptions are named.** Each module lists the wrong beliefs it's correcting.
- **Nothing untrue.** Simplify, never falsify. If a simplification is lossy, say so ("roughly", "usually").

## The running example: Crumb

Crumb is a pre-order app for a neighbourhood bakery. Customers order bread online for Saturday pickup. It starts tiny and grows into a chain across a city, then a country, so it hits every topic in a natural order.

| Stage | What Crumb needs | Modules |
| --- | --- | --- |
| 0. A web page | The bakery's hours and menu, online | 1, 2 |
| 1. Taking orders | A form, somewhere to keep orders | 4, 5, 6 |
| 2. Accounts | Customers log in, see past orders; staff see everything | 5, 11 |
| 3. Going live | A real domain, always on, updates without breaking | 8, 12 |
| 4. Saturday rush | 2,000 people at 7am; the site slows down | 7, 9 |
| 5. "What sells?" | The owner wants sales reports without slowing the shop | 6 |
| 6. Ten bakeries | Several shops, shared stock, a delivery partner | 9, 10 |
| 7. AI features | "Suggest a loaf", a support chatbot | 13 |

---

## Module 0: Building with AI, the job you're actually doing

**Goal:** Reframe the learner's role. They're not the typist; they're the person who decides what gets built and checks that it was.

Key ideas:
- An AI assistant is a fast, tireless, very well-read junior developer who never says "I don't know" and has no memory of your project beyond what it can see.
- Your job is the one a product owner and an architect share: decide what, decide roughly how, check the result.
- Most AI failures aren't bad code. They're the wrong thing built well, because the request was vague or the AI assumed something.
- You don't need to know how to do it. You need to know **what exists**, so you can ask for it, and **what can go wrong**, so you can check for it.

Misconceptions:
- "If it runs, it's done." Running on your laptop and working for real users are different things (Module 8).
- "The AI knows best." It knows what's common, which is a good default, but it doesn't know your users, your budget or your data.

---

## Module 1: The shape of a web app

**Goal:** One mental picture of what happens when someone opens a website, that every later module hangs on.

Concepts:
- **Client and server.** Your browser (the client) asks; a computer somewhere (the server) answers. Analogy: a customer at a counter and a kitchen out back.
- **Request and response.** Every click that fetches something is a request; the reply is a response. They're written in **HTTP**, a standard format both sides agree on. **HTTPS** is the same, sealed in an envelope nobody along the way can read.
- **URL and DNS.** A URL is an address (`https://crumb.example/menu`). **DNS** is the phone book that turns the name `crumb.example` into the numeric address of a server (an **IP address**).
- **Frontend, backend, database.** The three-layer picture:
  - Frontend: what runs in the user's browser or phone. The shop floor.
  - Backend: what runs on the server. The kitchen and the till.
  - Database: where the information is kept for good. The order book in the safe.
- **API.** The menu of requests a backend accepts, with the exact form each one takes. Analogy: the order slip format the kitchen will accept. Apps talk to each other through APIs too (payments, maps, email, AI models).
- **JSON.** The most common format for data going back and forth: readable labelled values, like `{"loaf": "sourdough", "qty": 2}`.
- **Static vs dynamic.** A static site sends the same files to everyone (Crumb stage 0). A dynamic site builds the answer per request, from the database (stage 1 onward).

Misconceptions:
- "The website is on my computer." Only a copy of the frontend is; everything else stays on the server.
- "Frontend and backend are different apps I have to buy." They're roles; one project can contain both.

What to tell your AI: "This is a static site; no backend needed yet" saves a lot of unnecessary machinery.

---

## Module 2: What code is, and the tools around it

**Goal:** Demystify the words that show up in every AI conversation about code.

Concepts:
- **Source code** is text: instructions in a **programming language**, readable by people, turned into something a computer runs.
- **Compiled vs interpreted** (roughly): compiled languages are translated into machine instructions ahead of time, like translating a whole book before printing; interpreted ones are translated as they run, like a live interpreter. Compiled usually runs faster; interpreted is usually quicker to change. Many modern languages blur this line, which is fine to say.
- **Runtime.** The thing that runs your code: Node.js runs JavaScript on a server; the browser runs it on the client; Python has its own.
- **Libraries, packages, frameworks.** Nobody writes everything. A **library** is someone else's code you call (a date formatter). A **framework** is a skeleton you fill in, which calls your code (React, Django). A **package manager** fetches them (npm, pip). Your project's list of these is its **dependencies**.
- **The terminal** (command line): typing instructions to the computer instead of clicking. AI tools use it constantly; the learner should not be scared of it.
- **Version control (Git).** A save history for a whole project, with the ability to go back, try things on a **branch**, and merge them in. **GitHub** hosts Git projects online. A **pull request** is a proposed change, open for review before it's merged. This is the single most important safety net when an AI is editing your code.
- **Environment variables and config.** Settings that live outside the code, like which database to use. Secrets (API keys, passwords) go here, never in the code itself (Module 11).

Misconceptions:
- "More dependencies is free." Each one is someone else's code you now depend on: bugs, security holes, abandonment.
- "I'll just ask the AI to undo it." Without version control, there may be nothing to undo to.

What to tell your AI: "Commit before each change", "work on a branch", "explain what this package does and why we need it."

---

## Module 3: The language map

**Goal:** Know the main languages by what they're for, so a stack an AI proposes makes sense, and so the learner can push back when it doesn't fit.

### The trade-offs languages are making

Every language sits somewhere on a few dials. Teach the dials, then place the languages on them:

- **Quick to write vs quick to run.** Python and JavaScript let you get something working fast; Go, Rust, C++ run faster and use less memory.
- **Types: checked early vs checked late.** In a **statically typed** language (TypeScript, Go, Rust, Java), the tools check that you're not putting a word where a number goes before the program runs. In a **dynamically typed** one (Python, JavaScript) you find out when it runs. Static types catch a lot of AI mistakes automatically, which matters more when you're not reading every line.
- **Who cleans up memory.** Most languages clean up automatically (**garbage collection**): easy, with occasional pauses. C and C++ make you do it by hand: fast, and a classic source of crashes and security bugs. Rust checks your cleanup rules when it compiles: fast and safe, harder to learn.
- **Where it can run.** Only browsers run JavaScript natively (plus **WebAssembly**, a compact format that other languages like Rust can compile to). Phones prefer their own languages. Servers run anything.
- **Ecosystem.** How many libraries, answers, and examples exist. AI assistants are noticeably better in popular languages because they've seen more of them.

### The languages

| Language | Best at | Where Crumb might use it |
| --- | --- | --- |
| **HTML** | The structure and content of a page. Describes, doesn't compute; usually not counted as a programming language. | Every page |
| **CSS** | How a page looks: layout, colours, fonts, phone vs desktop. | Every page |
| **JavaScript** | The only programming language every browser runs; also runs servers (Node.js). | Making the order form interactive |
| **TypeScript** | JavaScript with static types added; turns into JavaScript before running. The default for serious web work now. | The whole web app, front and back |
| **Python** | Readable, huge ecosystem for data, science, AI and automation; solid for backends (Django, FastAPI). | Sales analysis, the AI features, maybe the backend |
| **SQL** | Asking questions of a database ("all orders for Saturday, by loaf"). Not a general-purpose language, but the one that outlives every other. | Every database query |
| **Go** | Simple, fast, built for network services that handle many requests at once; compiles to one file that's easy to deploy. Much cloud infrastructure (Docker, Kubernetes) is written in it. | A high-traffic ordering service at stage 6 |
| **Rust** | Speed close to C/C++ without its memory bugs. Systems, performance-critical services, WebAssembly, developer tools (many new JavaScript and Python tools are written in Rust). Steeper learning curve. | Probably nowhere, and that's a lesson too |
| **Java, Kotlin, C#** | Large, long-lived business systems; Android (Kotlin); Windows and games in Unity (C#). Stable, fast, very widely employed. | If a big partner's systems use them |
| **Swift / Kotlin** | Native iPhone (Swift) and Android (Kotlin) apps. | A Crumb phone app, if a website isn't enough |
| **C, C++** | Operating systems, browsers, game engines, devices with tiny chips. Maximum control and speed. | Inside the tools Crumb uses, never written by Crumb |
| **Shell (Bash, PowerShell)** | Gluing commands together, automation, scripts that deploy things. | The deploy script |
| **PHP, Ruby** | Older web workhorses still running much of the web (WordPress is PHP; Ruby on Rails powers many startups). | If Crumb started as a WordPress site |

### Notebooks

A **notebook** is a document mixing code, its output, charts and notes, run a piece at a time. It's the analyst's lab bench: brilliant for exploring data and explaining findings, wrong for running a live app. Crumb's owner asking "which loaves sell on rainy days?" is a notebook job; taking orders is not.

The curriculum uses **marimo**, a Python notebook that's a good fit for building with AI:

- **Reactive.** Change one cell and every cell that depends on it reruns, like a spreadsheet. Older notebooks let you run cells in any order and end up showing results that no longer match the code; marimo doesn't.
- **Plain Python files.** A marimo notebook is a `.py` file, so it lives in Git (Module 2) with readable diffs, and an AI assistant can read and edit it like any other code.
- **Becomes an app.** The same notebook can run as a script, or be served as a small interactive web app with sliders and charts, which is handy for giving the owner a sales dashboard without building a frontend.

Learners will also see **Jupyter** (the long-standing standard, files ending `.ipynb`) and Google Colab; same idea, and worth recognising by name.

### Rules of thumb for AI builders

- One language across front and back (TypeScript) means fewer moving parts.
- Python when the work is data, analysis or AI.
- Reach for Go or Rust when you've measured a performance or cost problem, not before.
- Pick popular, "boring" tools; the AI is better at them and help is easier to find.

Misconceptions:
- "Java and JavaScript are related." Only by name.
- "Fast languages make fast apps." Most slow apps are slow because of the database or the network, not the language (Modules 6, 7, 9).
- "I need to learn a language first." Not to build with AI; you need to know which one fits.

---

## Module 4: The frontend

**Goal:** Understand what the user actually touches, and the main choices in building it.

Concepts:
- **HTML, CSS, JavaScript** as structure, style and behaviour. Analogy: the walls, the paint, the electrics.
- **The DOM.** The browser's live model of the page, which JavaScript changes to update what you see without reloading.
- **Components.** Modern frontends are built from reusable pieces (a "loaf card", an "order button"), each owning its look and behaviour. **React** is the most common framework for this; Vue, Svelte and Angular are others.
- **State.** What the page currently remembers: what's in the basket, whether the menu is open. Most frontend bugs are state bugs ("the basket says 3, the total says 2").
- **Rendering on the client vs the server.** A **single-page app** builds pages in the browser (snappy once loaded). **Server-side rendering** sends ready-made pages (faster first load, better for search engines). Frameworks like Next.js mix both. Teach this as a dial, not a war.
- **Responsive design.** One site that works on a phone and a desktop.
- **Accessibility.** Building so people using screen readers, keyboards or zoom can use it. It's also often a legal requirement.
- **Web app vs native app.** A web app runs in the browser, one codebase, updates instantly. A native app is installed from an app store, with better access to the phone, and two codebases (or a cross-platform tool like React Native or Flutter). Start on the web unless there's a reason.
- **Build step.** Frontend code is usually bundled and shrunk before it's shipped (tools like Vite). Why the AI talks about "building" a site.

Misconceptions:
- "Hiding a button keeps people out." The frontend runs on the user's machine; they can change anything there. Every real rule lives on the backend (Module 5, 11).
- "The design is the app." It's one layer; a beautiful form that saves nothing is a picture.

What to tell your AI: "Mobile first", "make it accessible", "use our existing components."

---

## Module 5: The backend

**Goal:** Know what the server side does, and the vocabulary for asking for it.

Concepts:
- **The backend is where the rules live.** Prices, stock, who can see what, what counts as a valid order. The frontend asks; the backend decides.
- **Routes and endpoints.** Each kind of request has an address: `POST /orders` places one, `GET /orders/42` reads one. **REST** is the most common style for designing these; **GraphQL** lets the frontend ask for exactly the fields it wants. Both are fine.
- **HTTP methods and status codes.** GET reads, POST creates, PUT/PATCH updates, DELETE removes. Responses carry a code: 200 OK, 404 not found, 401/403 not allowed, 500 the server broke. Knowing these makes error messages readable.
- **Authentication vs authorization.** Authentication: who are you? (logging in.) Authorization: what are you allowed to do? (customers see their orders; staff see everyone's.) Different problems; both needed.
- **Sessions and tokens.** How the server remembers you're logged in between requests: a session cookie, or a signed token (like a **JWT**). Prefer an established auth service or library over a home-made login.
- **Third-party services.** Payments (Stripe), email, maps, login with Google: called through their APIs. **Webhooks** are the reverse: their server calls yours when something happens ("payment succeeded").
- **Background jobs and queues.** Work that shouldn't make the user wait (sending the confirmation email, resizing photos) goes on a **queue** and a **worker** does it soon after. Analogy: the cashier takes your order and passes the ticket to the kitchen; you don't stand at the till while the bread bakes.
- **Scheduled jobs (cron).** Things that run on a timer: "close orders at 6pm Friday."
- **Backend-as-a-service.** Products like Supabase and Firebase bundle a database, logins and storage, so a small app may need very little custom backend. A good fit for many AI-built apps; know that it's a trade (less control, some lock-in).

Misconceptions:
- "The backend is just the database." The database stores; the backend decides.
- "Users won't call my API directly." Anyone can; tools make it trivial. Check everything on the server.

What to tell your AI: "Validate this on the server", "who is allowed to do this?", "what happens if the payment webhook arrives twice?" (Module 10.)

---

## Module 6: Data and databases

**Goal:** The deepest module, because data outlives everything else. A frontend can be rewritten in a week; lost or tangled data can't be.

### Why a database

- Files and spreadsheets break when two people write at once, when there's lots of data, or when you need to ask complicated questions fast. A database is built for exactly those.

### Relational databases (SQL)

- Data lives in **tables** (customers, orders, loaves) of **rows** and **columns**, with a **schema** declaring what each column holds.
- Tables point at each other with **keys** (an order row holds a customer's id) instead of copying data, so a change happens in one place.
- **SQL** is how you ask: `SELECT loaf, COUNT(*) FROM orders WHERE day = 'Saturday' GROUP BY loaf`.
- **Transactions.** A group of changes that happen all together or not at all. Taking payment and reserving the last croissant must both happen, or neither. **ACID** is the name for these guarantees.
- **Indexes.** Like a book's index: make finding rows fast, at a small cost when writing. Missing indexes are the most common reason an app gets slow as it grows.
- **Migrations.** Versioned, repeatable changes to the schema ("add a phone column"), kept in Git with the code. Never hand-edit production's structure.
- **Postgres** is the sensible default; MySQL and SQLite (a database in a single file, great for small apps) are also common.

### Other kinds (NoSQL and friends)

Teach these as tools shaped for particular jobs, not as rivals to SQL:

| Kind | Shape | Good for | Examples |
| --- | --- | --- | --- |
| Document | Flexible JSON-like records | Data whose shape varies | MongoDB, Firestore |
| Key-value | A giant dictionary: key in, value out, very fast | Caches, sessions, counters | Redis, DynamoDB |
| Search | Text indexed for fuzzy search and ranking | "sourdo" finds "sourdough" | Elasticsearch, OpenSearch |
| Vector | Stores meaning as lists of numbers to find "similar" things | AI search and recommendations (Module 13) | pgvector, Pinecone |
| Time series | Measurements over time | Metrics, sensors | TimescaleDB, InfluxDB |
| Graph | Things and the links between them | Social networks, fraud | Neo4j |

Rule of thumb: start with Postgres; it can do most of these passably, and add a specialist when you've outgrown it.

### OLTP vs OLAP

The key distinction this module builds to:

- **OLTP (online transaction processing):** the shop till. Lots of small, fast reads and writes: place this order, update that stock count. Your app's main database.
- **OLAP (online analytical processing):** the accountant's office. Few, huge questions across everything: sales by loaf by month by shop, for three years. Built to scan millions of rows quickly.
- Running big OLAP questions on the OLTP database slows the shop down (Crumb stage 5: the owner's report makes Saturday ordering crawl).
- So data is copied into a **data warehouse** (BigQuery, Snowflake, Redshift, or DuckDB for small jobs) built for analysis, often storing data by column instead of by row so it can scan one column fast. The copying is a **pipeline**, called **ETL** or **ELT** (extract, transform, load, in one order or the other).
- A **data lake** keeps raw files of every kind cheaply, to be organised later.
- This is where marimo notebooks and Python come back (Module 3): analysts point them at the warehouse, not the live app.

### Keeping data safe

- **Backups**, tested by actually restoring one. A backup you've never restored is a hope.
- **Personal data**: collect only what you need; know where it is (Module 11).

Misconceptions:
- "A spreadsheet is a database." Until two people edit it at once.
- "NoSQL is the modern one." It's a different shape, not a newer version.
- "The AI can fix my data later." Bad data structure is the most expensive thing to change after launch.

What to tell your AI: "Show me the schema before writing code", "use a migration", "add an index for this query", "is this OLTP or OLAP work?"

---

## Module 7: Caching

**Goal:** Understand the single most common performance fix, and its famous catch.

Concepts:
- **A cache keeps a copy of an answer close by so you don't have to work it out again.** Analogy: the baker keeps the day's best-seller on the counter instead of fetching it from the back each time.
- **Where caches live**, from nearest the user to furthest:
  - **Browser cache**: the user's own machine keeps images and files.
  - **CDN** (content delivery network, like Cloudflare): copies of your files on servers around the world, so a user in Sydney isn't fetching from London.
  - **Application cache**: the backend keeps recent answers in memory or in **Redis**, so it doesn't re-ask the database.
  - **Database cache**: the database keeps hot data in memory itself.
- **Hit and miss.** A hit finds the answer in the cache; a miss has to fetch it. The **hit rate** is what makes a cache worth it.
- **Stale data and invalidation.** A copy can go out of date: the cache says "3 croissants left" after they've sold. Fixes: a **TTL** (time to live: forget after 60 seconds), or clearing the cached copy whenever the real data changes. Deciding when a copy is too old to trust is famously one of the hard problems in computing.
- **What's safe to cache.** The menu: yes, for minutes. Today's stock: for seconds, maybe. A user's basket or their account page: never in a shared cache, or one customer sees another's.

Misconceptions:
- "Caching is free speed." It's speed paid for with the risk of wrong answers.
- "Add a cache first." Often a missing index (Module 6) is the real fix.

What to tell your AI: "How stale can this be?", "is this cache per user or shared?"

---

## Module 8: Getting it online: hosting and deployment

**Goal:** The gap between "works on my laptop" and "works for everyone, all the time".

Concepts:
- **Local vs production.** Your laptop is a workshop; **production** is the shop that's open to the public. Usually there's a **staging** (or preview) copy in between to check changes first.
- **Where code can run**, from most hands-on to least:
  - A **server** or **virtual machine** you rent and manage (a computer in a data centre).
  - **Containers** (Docker): your app packed with everything it needs, so it runs the same everywhere. **Kubernetes** runs many containers; most small apps don't need it.
  - **Platform-as-a-service** (Render, Railway, Fly.io, Heroku): give it your code, it runs it.
  - **Serverless** (AWS Lambda, Cloudflare Workers, Vercel functions): code runs only when a request comes in, scales by itself, billed per use. "Serverless" still has servers; you just don't manage them.
  - **Static hosting** for sites with no backend.
- **The big clouds** (AWS, Google Cloud, Azure) offer all of the above and hundreds more; powerful, and easy to get lost or overspend in.
- **Domains, DNS, HTTPS** in practice: buy a domain, point its DNS at your host, get a certificate (usually automatic now).
- **CI/CD.** Continuous integration: every change is automatically built and tested. Continuous deployment: changes that pass go live automatically. With an AI making many changes, this is the safety rail.
- **Logs, monitoring, alerts.** Once it's live you can't see the user's screen; logs and error tracking (Sentry) are how you find out what broke. Alerts tell you before customers do.
- **Cost.** Usage-based billing can spike: a loop that calls a paid API, a bot hammering the site. Set budget alerts.

Misconceptions:
- "Deploying is a one-off." It happens every change; making it boring and automatic is the point.
- "It's live, so it's done." Live is when operating it starts.

What to tell your AI: "Set up a staging environment", "deploy from CI, not my laptop", "add error tracking", "what will this cost at 10x the traffic?"

---

## Module 9: Scaling

**Goal:** What happens when lots of people show up, and the honest news that most apps never need much of this.

Concepts:
- **Latency vs throughput.** Latency: how long one request takes. Throughput: how many you can handle per second. A bakery can be quick per customer and still have a queue out the door.
- **Find the bottleneck first.** Measure before fixing. It's usually the database, then the network, rarely the language.
- **Vertical scaling:** a bigger server. Simple, has a ceiling, and often the right first move.
- **Horizontal scaling:** more servers sharing the work, behind a **load balancer** that hands each request to one of them. Like opening more tills.
- **Stateless servers.** For horizontal scaling, any server must be able to handle any request, so nothing important can live only in one server's memory (put sessions in the database or Redis). Analogy: any cashier can serve any customer because the order book is shared, not in one cashier's head.
- **Scaling the database** is the hard part:
  - **Read replicas**: copies that handle reads, while one main database handles writes. Replicas lag slightly behind (Module 10).
  - **Sharding**: splitting data across several databases (each bakery's orders on its own). Powerful, complex, a last resort.
  - **Connection pooling**: databases can only hold so many conversations at once; a pool shares them.
- **CDNs and caches** take load off everything behind them (Module 7).
- **Queues smooth spikes.** At 7am Saturday, accept orders into a queue instantly and process them steadily, instead of falling over (Module 5).
- **Autoscaling.** Adding and removing servers automatically with demand (serverless does this for you).
- **Rate limiting.** Capping how many requests one user or bot can make, to protect everyone else.

Misconceptions:
- "Build it to scale from day one." Premature scaling is a classic way to never launch. A single decent server with a well-indexed Postgres handles far more than most new apps will ever see.
- "Microservices scale better." They let big teams work separately; they add a lot of problems (Module 10). Start with one app (a **monolith**).

What to tell your AI: "Keep this simple until we measure a problem", "make the servers stateless", "where's the bottleneck?"

---

## Module 10: Distributed systems, why many computers are hard

**Goal:** Give the learner the instincts behind the strangest bugs: the ones that happen only sometimes, only under load, only when two things happen at once.

As soon as Crumb has more than one computer (a backend and a database, ten shops, a delivery partner), it's a distributed system.

Concepts:
- **The network is unreliable.** Messages get lost, delayed, duplicated or arrive out of order. A request that times out might have failed, or might have succeeded and only the reply got lost. You often can't tell which.
- **Partial failure.** One part breaks while the rest keeps going. The payment service is down; the website is fine. The system must decide what to do: retry, wait, show a message, fall back.
- **Retries and idempotency.** If you retry, you might do the thing twice: charge twice, order twice. An **idempotent** operation is safe to repeat (setting stock to 5 rather than subtracting 1). An **idempotency key** lets a server recognise "I've already done this one."
- **Race conditions.** Two customers buy the last croissant at the same moment; both are told yes. Fixes: transactions and locks in the database (Module 6), or checking-and-reserving in one step.
- **Consistency.** Do all copies agree right now? With replicas and caches, they can disagree briefly. **Eventual consistency** means they'll agree soon, not instantly: the shop in one district sees a stock count a second out of date.
- **The CAP trade-off** (simplified): when the network between two parts breaks, each part must either keep answering with possibly stale data (stay available) or refuse until it can confirm (stay consistent). You can't have both during the break. Which is right depends on the data: a menu can be a bit stale; a bank balance shouldn't be.
- **Time and ordering.** Different computers' clocks disagree slightly, so "which happened first?" is harder than it sounds.
- **Monoliths vs microservices.** One app is easier to build, test and debug. Splitting into many services lets large teams move independently, at the price of every problem above appearing between them. For an AI-assisted solo builder, a monolith is almost always right.
- **Observability.** With many parts, you need **logs**, **metrics** and **traces** (following one request across every service) to know what happened.

Misconceptions:
- "If it worked when I tested it, it works." Distributed bugs depend on timing and load; they hide in testing.
- "Errors mean it didn't happen." A timeout means you don't know.

What to tell your AI: "What happens if this request is sent twice?", "what if the payment provider is down?", "can two people buy the last one?"

---

## Module 11: Security and privacy

**Goal:** The mistakes that end projects, and the habits that prevent them. AI-generated code makes some of these more likely, because it's produced fast and read less.

Concepts:
- **Secrets stay secret.** API keys and passwords live in environment variables or a secrets manager, never in code, never in Git, never in the frontend. Anything in the frontend is public (Module 4).
- **Never trust input.** Everything from users can be hostile:
  - **SQL injection**: input crafted to run as a database command. Prevented by parameterised queries, which modern libraries do by default.
  - **XSS (cross-site scripting)**: input crafted to run as code in other users' browsers. Prevented by escaping output; frameworks mostly do this.
- **Authorization on every request** (Module 5). The most common real-world flaw is letting user A read user B's data by changing a number in the URL.
- **Passwords** are stored **hashed** (scrambled one-way), never as text. Better still, use an auth provider and don't store them at all.
- **HTTPS everywhere.**
- **Least privilege.** Every key, account and service gets only the access it needs. The frontend's database key can't delete tables.
- **Dependencies are a risk.** Packages can be abandoned, buggy or malicious. Keep them updated; be wary of obscure ones an AI suggests (AI tools sometimes invent package names that don't exist, and attackers register those names).
- **Personal data and the law.** Collect only what you need, know where it's stored, let people delete it. Laws like GDPR apply depending on where your users are.
- **AI-specific risks** (pointer to Module 13): prompt injection, and sending private data to third-party AI services.

Misconceptions:
- "Nobody will bother attacking my little app." Bots scan the whole internet automatically, all day.
- "It's a private repo, so the key is safe." Repos get shared, made public, or leaked.

What to tell your AI: "Where are the secrets stored?", "check that users can only access their own data", "review this for security issues."

---

## Module 12: Quality: testing, debugging and reviewing

**Goal:** How to know the AI's work is right, when you can't read every line.

Concepts:
- **Tests** are code that checks code:
  - **Unit tests** check one small piece ("the price of 2 loaves with a discount is right").
  - **Integration tests** check pieces together ("placing an order saves it to the database").
  - **End-to-end tests** drive the real app like a user would, in a browser.
- **Tests are your spec.** Describe behaviour as tests ("ordering after Friday 6pm is refused") and you have a checkable definition of done that the AI can run.
- **Types and linters** catch whole classes of mistakes automatically (Module 3).
- **Reading errors.** Error messages and **stack traces** name what went wrong and where. Paste the whole thing to the AI, not a summary.
- **Debugging** is the scientific method: reproduce, form a guess, test it, narrow down. "It doesn't work" is not a bug report; "when I order two loaves, the total shows one" is.
- **Code review.** Reading a change before it goes in. With AI, review the plan and the tests closely, and ask the AI to explain any part you don't follow.
- **Small changes.** Small, frequent, reviewed changes beat one giant one. They're easier to check and easier to undo (Module 2).

Misconceptions:
- "The AI wrote tests, so it's tested." Check the tests test the right thing; an AI can write a test that always passes.
- "No errors means no bugs."

What to tell your AI: "Write a failing test first", "explain this change", "what could this break?"

---

## Module 13: AI inside your app

**Goal:** Using AI models as a part of what you build, not just as the builder.

Concepts:
- **Calling a model.** AI models are used through an API like any other service (Module 5): send text (and images), get text back. Your backend calls it, never the frontend, so the key stays secret.
- **Tokens, context and cost.** Models read and write in **tokens** (word fragments). You pay per token, and each model has a **context window**, a limit on how much it can read at once. Long conversations and big documents cost more.
- **Models make things up.** Answers can sound right and be wrong (**hallucination**). Design for it: show sources, keep a human in the loop for anything that matters.
- **Embeddings and RAG.** An **embedding** turns text into numbers that capture meaning, so "rye" and "dark bread" end up close together. Stored in a vector database (Module 6). **RAG** (retrieval-augmented generation) finds the relevant documents first, then gives them to the model, so Crumb's chatbot answers from Crumb's actual allergy info, not a guess.
- **Tools and agents.** Models can be given **tools** (look up an order, check stock) and decide when to use them. An **agent** loops: think, use a tool, look at the result, repeat. Powerful; give tools the least power they need.
- **Prompt injection.** Text the model reads (a customer message, a web page) can contain instructions that try to hijack it. Treat model output as untrusted, and don't give a chatbot powers you wouldn't give an anonymous customer.
- **Privacy.** Know what data you're sending to an AI provider and what they do with it.

Misconceptions:
- "The AI feature is the hard part." The data, permissions and failure handling around it are.
- "A bigger model fixes it." Better context usually helps more.

What to tell your AI: "Call the model from the backend", "ground answers in our documents", "what can this agent do if someone tricks it?"

---

## Capstone: Crumb, the whole picture

The learner assembles Crumb's final architecture from everything above and can explain each part:

```
 Customers' browsers / phones
            |
           CDN  (cached menu, images)
            |
      Load balancer
       /    |    \
   App servers (stateless, TypeScript)  ---- Auth provider
       |      \         \                ---- Payments (webhooks)
       |     Redis      Queue --> Workers (emails, stock sync)
       |    (cache)
   Postgres (main, OLTP) --> read replicas
       |
   Pipeline (ELT)
       |
   Data warehouse (OLAP) --> owner's dashboards, analysts' marimo notebooks

   AI assistant: backend --> model API, with RAG over the menu and allergy docs
   Around it all: Git, CI/CD, staging, logs, alerts, backups
```

And the honest version: stage 1 Crumb is one app on one host with one Postgres database, and that's correct. Every box above earns its place by solving a problem Crumb actually had.

### Questions to ask before building anything

A checklist the learner keeps:

1. Who uses it, and roughly how many?
2. What data does it keep, and where does that data live?
3. Who is allowed to see and change what?
4. What happens when something fails: a payment, the network, a duplicate request?
5. What's the simplest version that works?
6. How will I know it's working once it's live?
7. Where are the secrets?
8. How do I undo a bad change?

---

## Glossary (starter)

A plain-words definition for every bolded term above, to grow into an in-game codex. Starter set:

| Term | Plain words |
| --- | --- |
| API | The menu of requests a service accepts |
| Backend | The part of an app running on a server, where the rules live |
| Cache | A nearby copy of an answer, to skip redoing work |
| CDN | Copies of your files on servers worldwide, close to users |
| CI/CD | Automatic building, testing and deploying of every change |
| Database | The organised, permanent store of an app's information |
| DNS | The internet's phone book, from names to server addresses |
| Frontend | The part of an app running on the user's device |
| Idempotent | Safe to do twice; the second time changes nothing |
| Load balancer | The host who seats each request at a free server |
| OLAP | Big analytical questions over lots of data |
| OLTP | Many small, fast reads and writes; the live app's work |
| Schema | The declared shape of the data |
| Transaction | Changes that happen all together or not at all |

---

## For the game

Notes for the next pass, not decisions:

- **It must stay distinct from the other three games** (see AGENTS.md): no quiz duels (Dunder Quest), no character running your script (Flatmates.js), no plan-plays-out-then-gets-interrupted (Curb Your Oxidation). And unlike the others it doesn't teach one language, and the player doesn't write code.
- **Crumb's growth is a natural campaign.** Each stage is a level; the player's app (or whatever the homage equivalent becomes) faces the stage's problem live: the Saturday rush, the owner's slow report, the double-charged customer.
- **The concepts are spatial, which suits a builder/management game.** Users flowing in, requests travelling to servers, a database as a vault, a cache as a shelf, a queue as a literal queue. Placing, connecting and tuning pieces, then watching traffic hit them, would make trade-offs felt rather than told: a cache that goes stale, a single server that melts, a retry that charges twice.
- **The player directs an AI builder character.** It mirrors the real skill being taught: describing what you want, then checking the result. The assistant could be eager and occasionally overconfident (suggesting Kubernetes for a bake sale) and the player learns to say no.
- **Natural puzzle shapes per module:** pick the right language for a job card (3); choose OLTP or OLAP for a request (6); set a TTL that's fresh enough and fast enough (7); survive a traffic spike with a budget (9); make a flaky network not double-charge (10); find the leaked key (11).
- **Every claim checked.** Like `verify_rust.py` for Curb, the game's facts should have a check; at minimum this curriculum gets a technical review pass before content is built from it.
