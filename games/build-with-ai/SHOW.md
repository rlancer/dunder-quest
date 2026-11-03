# The show: working the homage into the curriculum

The fourth game is a homage to a Bay Area startup sitcom: a shy coder's app becomes a company, run out of a loud founder's incubator house, chased by a guru-led tech giant and a parade of absurd investors, and nearly killed every season by its own success.

[CURRICULUM.md](CURRICULUM.md) is the reference for **what** the game teaches: the topics, in order, and the running example (Forkcast). This doc is **how** the show carries it: who's who, what each episode is, and which module each one covers. The curriculum can change, but it changes for teaching reasons; the show follows it and every module stays covered.

Nothing here is final. Names marked *(candidate)* are placeholders to decide.

## Ground rules

Same approach as Curb Your Oxidation, adapted:

- **Copy the format, tone and tropes closely.** The incubator house, the garage server rack, the pitch-conference stage, the tech giant's campus, the bickering engineers, the deadpan insults, the founder who throws up before big moments, the investor meetings that go sideways, success that's always about to destroy the company.
- **Three limits.** No real people's or characters' names (homage names only). No verbatim catchphrases or lines from the show. No recreation of its theme tune; original music in the same glitchy, electronic style is fine.
- **Don't name the show in anything public**: the game, the site, the trailers, the video descriptions. In this repo it's "the show".
- **Leave out what doesn't suit a broad, non-technical audience**: the raunchy set pieces and the gags built on national or ethnic stereotypes.
- **Stay distinct from the other three games**: no quiz duels (Dunder Quest), no character running a script you wrote (Flatmates.js), no plan-in-your-head interrupted at the failing line, and no freeze frame with a tuba sting (Curb Your Oxidation). The player doesn't write code.

## Why the show isn't named here

This repo is public, so these docs follow the same rule as the game: the show is described, never named, and neither are its characters (Curb's and Flatmates' docs do the same). That makes it easy to drift into a generic startup comedy, so everything below is tied to specific, recognisable things from the show: each character's counterpart and signature habits, and each episode's borrowed set piece. If a scene could be in any office comedy, it's too far away; push it back toward the show.

## The premise

You've moved to the Bay Area to launch an AI startup, and you've never written a line of code. Everyone around you seems to have. Your idea is **Forkcast** *(candidate)*, the AI dinner concierge from the curriculum: tell it what kind of evening you want and it finds the restaurant and books the table.

You talk your way into the incubator house, where the loud owner promises to make you a real founder for ten percent of the company. To launch, raise money and survive, you have to learn just enough of everything the curriculum teaches to make the calls. The curriculum's stages are the season's arc, from a landing page with a waitlist to a company in several cities.

- Working title: **The Bay Area** *(candidate)*.

The player is the show's audience surrogate made literal: the non-technical founder in a room full of engineers. That's exactly who the curriculum is for, and it's a very real Bay Area type right now, which is half the joke.

## The AI on the team

The curriculum's core skill is directing an AI that writes the code, and the show's last stretch was about AI that gets too powerful. So the startup's newest hire is an AI coding assistant, and it's the character the player actually directs.

- It's a homage to the show's late-season AI: the one the deadpan sysadmin built on his garage server, which "fixed" every bug by deleting the code. Thorne built ours too, on his garage server, and it's named after it *(name candidate)*.
- It's fast, tireless, eager and overconfident (curriculum Module 0). It builds what you ask, which isn't always what you need.
- The human engineers react to it: one is threatened by it, one is quietly using it to do his job, one wants it to rewrite everything in his favourite language.
- The joke runs both ways: you're building an AI product with an AI, and both of them can be confidently wrong (Module 13: hallucination, prompt injection).
- In the finale it proposes rebuilding everything into something far beyond what Forkcast needs, and the player's last lesson is saying no (Capstone: "every box earns its place").

## The cast

Each character is a close homage to one of the show's, keeping their look, habits and relationships, and each owns a slice of the curriculum: they're the voice the player hears it from. Names are all *(candidate)*.

| Character | The show's counterpart, and what to keep | Curriculum role |
| --- | --- | --- |
| You, Forkcast's founder | New: the non-technical founder the show only ever laughed at, now the hero | The learner |
| **Gus**, the incubator owner | The bombastic owner of the incubator in his suburban ranch house, who takes ten percent of every startup living there. Coasting on one startup he sold years ago; robe, bare feet, grand pronouncements, branding obsessions; a mentor who's as likely to sabotage you as help. | Says every misconception out loud, with total confidence. Each module's "Misconceptions" list is his dialogue; spotting where he's wrong is a core skill. |
| **Hank**, your reluctant CTO | The shy genius founder: stammers in pitches, throws up before big moments, stubborn about doing things the right way, and pushed into leading when he'd rather code. Here he's who you'd be if you could code. | Explains how things actually work (Modules 1, 2); a perfectionist who over-engineers, so he's also the voice of premature scaling (9). |
| **Thorne**, the deadpan sysadmin | The long-haired, menacing systems engineer with a cheerful interest in the dark arts, who built and named the server in the garage and holds everyone in contempt, his rival coder most of all. | Servers, hosting, security, distributed failure (8, 10, 11). Trusts nothing; usually right. Built the AI teammate. |
| **Dev**, the app developer | The rival coder: vain, insecure, forever one-upped by the sysadmin, briefly famous and then humiliated. Their trading of insults is the house's background noise. (Keep the rivalry, not the show's nationality jokes.) | Frontend, React, the language wars with Thorne (3, 4). Chases what's fashionable. |
| **Jordan**, the operations lead | The earnest refugee from the tech giant: devoted to the founder, unnervingly calm, cheerfully mentioning a bleak past, fond of odd corporate team exercises and very thorough spreadsheets. | Process: testing, backups, checklists, privacy, the boring things that save the company (6, 12). |
| **Bix**, the friend who fails upward | The founder's sweet, hapless best friend, who's poached by the giant, paid to do nothing on its roof, and keeps landing jobs he's not qualified for. | "It works on my machine"; deploys from his laptop; gets hired by the tech giant anyway (8, 12). |
| **Galen Brightwater**, guru CEO of **Hubbub** | The tech giant's CEO: a spiritual adviser at his elbow, speeches about making the world a better place, a copycat of your product built by hundreds of engineers, whole teams fired on a whim, and a lawsuit claiming he owns your idea. | Buzzwords and anti-patterns: microservices for everything, scale from day one, copy the competitor (9, 10, 11). |
| **The loud investor** *(name TBD)* | The brash billionaire who made his fortune putting radio on the internet: flashy car with doors that open upward, obsessed with how many billions he has, wants growth now and revenue never. | Vanity metrics and burn; makes cost and runway real (5, 8, 9). |
| **The quiet investor** *(name TBD)* | The socially strange visionary VC: long silences, odd fixations, sudden insight. | Asks the one question that matters: "what's the simplest version that works?" (Capstone checklist). |
| **The associate** *(name TBD)* | The investor's sharp, sceptical associate who believes in the founder when no one else does. | Fundraising and money sense: runway, cost, what investors actually check (5, 8). |
| **The adult CEO** *(name TBD)* | The veteran executive the board installs over the founder, who wants to stop building the product and sell a hardware box instead. | One episode (9): on-premises box vs the cloud (8), and dashboards that measure the wrong thing (6). |

The engineers' bickering is a teaching device: on most decisions two of them argue for different options, and the trade-off between them is the lesson (Module 3's dials, Module 7's freshness vs speed, Module 10's consistency vs availability).

## The season: episodes and modules

One or two episodes per stage of the curriculum. Each has a cold open, a problem, the team's plan, and a live moment where the plan meets reality.

Each episode borrows a specific set piece from the show; the right-hand column says which, so the homage can be checked.

| # | Episode | Forkcast stage | Modules | Borrowed from the show |
| --- | --- | --- | --- | --- |
| 1 | **Pilot**: you move into the incubator house with an idea and no code | 0 | 0 | The pilot's choice: the giant's CEO offers to buy the idea outright on day one, while the strange VC offers a small investment to build it yourself. You turn down the money. |
| 2 | **The Whiteboard**: Hank draws the internet for you; the landing page and waitlist go up | 0 | 1, 2 | The house's late-night whiteboard sessions, and the founder failing to explain the product in one sentence. |
| 3 | **Tabs and Spaces**: the team splits over which language to build in | 1 | 3 | The tabs-versus-spaces fight that nearly ends a relationship. |
| 4 | **Demo Day**: the MVP has to find a real table for an investor by Friday | 1 | 4, 5, 13 (first model call) | The founder throwing up before the pitch, and the investor meeting that goes sideways. |
| 5 | **The Spreadsheet**: Gus has been keeping the waitlist and bookings in a shared spreadsheet | 1 | 6 (OLTP side) | The incubator owner's "help": a branding obsession and a bright idea that nearly sinks the company. |
| 6 | **Log In**: users want accounts; restaurants want to see only their own bookings | 2 | 5, 11 | The focus group of ordinary people who can't work out the brilliant product the engineers love. |
| 7 | **Launch Party**: going live in front of everyone | 3 | 8, 12 | The absurdly lavish startup launch party paid for with money they don't have. |
| 8 | **Viral**: a celebrity posts about Forkcast; the garage server melts and the AI bill hits five figures | 4 | 7, 9 | The live stream that goes huge while the garage server overheats and the team scrambles to keep it alive. |
| 9 | **The Board Meeting**: the investors want dashboards that slow the app, and the board installs an adult CEO | 5 | 6 (OLAP side), 8 | The founder pushed out of his own company, and the new CEO who wants to sell a box. |
| 10 | **Hubbub Dine**: the tech giant clones you, with hundreds of engineers and microservices | 6 | 9, 10 | The giant's copycat platform, built by a huge team, that collapses at its big demo. |
| 11 | **Charged Twice**: real deposits, restaurants' booking systems, and two parties at one table | 6 | 10 | The pivot to a network spread across thousands of devices, and how badly it can go wrong at scale. |
| 12 | **The Leak**: Bix pasted the model API key somewhere public, and Hubbub sues | 6 | 11 | The giant's lawsuit claiming it owns the product, and the sysadmin's casual hacking. |
| 13 | **The Conference**: the agent books live on stage, and a planted review hijacks it | 7 | 13 | The startup conference finale: the giant demos first, and the team pulls something together overnight. |
| 14 | **Finale**: the AI proposes rebuilding everything; you defend the simple version | All | Capstone | The series finale: the AI too powerful to release, the team sabotaging their own launch, and a documentary-style flash-forward years later. |

Every curriculum module appears at least once. Modules 6, 8, 10, 11 and 13 get two episodes each: data, hosting, distributed failure and security are the most expensive to get wrong, and 13 is the product itself.

## The game format

A first sketch, to be designed properly later. It's built in **Godot 4.7** like the other three games, as its own project in `games/build-with-ai/`, so it reuses the repo's web export, CI, bot tests and art and trailer tools. This audience is the likeliest of the four to arrive on a phone from a social post, so keep the web build lean and design for a portrait screen from the start. If phone-first ever becomes the top priority, revisit a web build (TypeScript, React or a 2D library) before any game code is written, not after.

- **Plan, then demo.** In each episode the player directs the AI to build or change Forkcast, choosing pieces (a cache here, a queue there, Postgres not a spreadsheet) while the engineers weigh in. Then comes the episode's live moment, a launch, a demo, a traffic spike, where simulated users hit what was built and the consequences play out on screen: pages slow, the cache says a booked table is free, a diner is charged twice.
- **Runway is the score.** Cloud bills, model bills, salaries and mistakes burn the startup's money. Over-engineering burns it as surely as outages do, which teaches the curriculum's "simplest version that works" without saying it.
- **Gus is a trap.** His confident advice is sometimes right, mostly a misconception. The player learns to tell which.
- **Episodes, not levels.** A cold open before the title card, a cliffhanger cut to black at the end, a "previously on" recap when you return. It's pixel art like the other games.
- **The title sequence** is a homage to the show's: a pan across the Bay as startup logos appear, merge and vanish, with Forkcast's appearing, and later Hubbub Dine's, as the season goes on.

## Checks

- **Closeness.** Every episode names the show's set piece it borrows, and every character keeps the counterpart's signature habits and relationships. Before an episode is built, check it against the show: if a fan wouldn't recognise where it came from, it's drifted.
- **Coverage.** Every curriculum module must map to at least one episode; worth a small test once episodes exist as data, so editing the curriculum flags anything left uncovered.
- **Facts.** Every claim in dialogue must be real (the curriculum's "nothing untrue" rule), with a technical review pass before content is built.
