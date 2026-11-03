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

## The premise

You've moved to the Bay Area to launch an AI startup, and you've never written a line of code. Everyone around you seems to have. Your idea is **Forkcast** *(candidate)*, the AI dinner concierge from the curriculum: tell it what kind of evening you want and it finds the restaurant and books the table.

You talk your way into the incubator house, where the loud owner promises to make you a real founder for ten percent of the company. To launch, raise money and survive, you have to learn just enough of everything the curriculum teaches to make the calls. The curriculum's stages are the season's arc, from a landing page with a waitlist to a company in several cities.

- Working title: **The Bay Area** *(candidate)*.

The player is the show's audience surrogate made literal: the non-technical founder in a room full of engineers. That's exactly who the curriculum is for, and it's a very real Bay Area type right now, which is half the joke.

## The AI on the team

The curriculum's core skill is directing an AI that writes the code, and the show's last stretch was about AI that gets too powerful. So the startup's newest hire is an AI coding assistant, and it's the character the player actually directs.

- It's fast, tireless, eager and overconfident (curriculum Module 0). It builds what you ask, which isn't always what you need.
- The human engineers react to it: one is threatened by it, one is quietly using it to do his job, one wants it to rewrite everything in his favourite language.
- The joke runs both ways: you're building an AI product with an AI, and both of them can be confidently wrong (Module 13: hallucination, prompt injection).
- In the finale it proposes rebuilding everything into something far beyond what Forkcast needs, and the player's last lesson is saying no (Capstone: "every box earns its place").

## The cast

Each character is a homage to a show archetype, and each owns a slice of the curriculum: they're the voice the player hears it from. Names are all *(candidate)*.

| Character | Show archetype | Curriculum role |
| --- | --- | --- |
| You, Forkcast's founder | (new) the non-technical founder | The learner |
| **Gus**, the incubator owner | The bombastic house owner who's all bluster and vision | Says every misconception out loud, with total confidence. Each module's "Misconceptions" list is his dialogue; spotting where he's wrong is a core skill. |
| **Hank**, your reluctant CTO | The shy genius founder | Explains how things actually work (Modules 1, 2); a perfectionist who over-engineers, so he's also the voice of premature scaling (9). |
| **Thorne**, the deadpan sysadmin | The deadpan, menacing infrastructure engineer | Servers, hosting, security, distributed failure (8, 10, 11). Trusts nothing; usually right. |
| **Dev**, the app developer | The insecure rival coder | Frontend, React, the language wars with Thorne (3, 4). Chases what's fashionable. |
| **Jordan**, the operations lead | The earnest, anxious business guy from a big company | Process: testing, backups, checklists, privacy, the boring things that save the company (6, 12). |
| **Bix**, the friend who fails upward | The hapless friend promoted for no reason | "It works on my machine"; deploys from his laptop; gets hired by the tech giant anyway (8, 12). |
| **Galen Brightwater**, guru CEO of **Hubbub** | The tech giant's spiritual, ruthless CEO | Buzzwords and anti-patterns: microservices for everything, scale from day one, copy the competitor (9, 10). |
| **The loud investor** *(name TBD)* | The vain, flashy billionaire | Wants features and vanity metrics now; makes cost and runway real (5, 8, 9). |
| **The quiet investor** *(name TBD)* | The strange, calm venture capitalist | Asks the one question that matters: "what's the simplest version that works?" (Capstone checklist). |

The engineers' bickering is a teaching device: on most decisions two of them argue for different options, and the trade-off between them is the lesson (Module 3's dials, Module 7's freshness vs speed, Module 10's consistency vs availability).

## The season: episodes and modules

One or two episodes per stage of the curriculum. Each has a cold open, a problem, the team's plan, and a live moment where the plan meets reality.

| # | Episode | Show trope | Forkcast stage | Modules |
| --- | --- | --- | --- | --- |
| 1 | **Pilot**: you move into the incubator house with an idea and no code | The new arrival in the house | 0 | 0 |
| 2 | **The Whiteboard**: Hank draws the internet for you; the landing page and waitlist go up | The whiteboard explainer | 0 | 1, 2 |
| 3 | **Tabs and Spaces**: the team splits over which language to build in | The engineers' holy war | 1 | 3 |
| 4 | **Demo Day**: the MVP has to find a real table for an investor by Friday | The demo that must not fail | 1 | 4, 5, 13 (first model call) |
| 5 | **The Spreadsheet**: Gus has been keeping the waitlist and bookings in a shared spreadsheet | The founder's bright idea | 1 | 6 (OLTP side) |
| 6 | **Log In**: users want accounts; restaurants want to see only their own bookings | The feature everyone assumed was easy | 2 | 5, 11 |
| 7 | **Launch Party**: going live in front of everyone | The party that goes wrong | 3 | 8, 12 |
| 8 | **Viral**: a celebrity posts about Forkcast; the garage server melts and the AI bill hits five figures | The live-stream crash | 4 | 7, 9 |
| 9 | **The Board Meeting**: the investors want dashboards, and running them slows the app | The board meeting | 5 | 6 (OLAP side) |
| 10 | **Hubbub Dine**: the tech giant clones you, with a hundred engineers and microservices | The giant's copycat product | 6 | 9, 10 |
| 11 | **Charged Twice**: real deposits, restaurants' booking systems, and two parties at one table | The near-death disaster | 6 | 10 |
| 12 | **The Leak**: Bix pasted the model API key somewhere public | The legal threat | 6 | 11 |
| 13 | **The Conference**: the agent books live on stage, and a planted review hijacks it | The pitch-conference finale | 7 | 13 |
| 14 | **Finale**: the AI proposes rebuilding everything; you defend the simple version | The success that could destroy them | All | Capstone |

Every curriculum module appears at least once. Modules 6, 10, 11 and 13 get two episodes each: the first three are the most expensive to get wrong, and 13 is the product itself.

## The game format

A first sketch, to be designed properly later:

- **Plan, then demo.** In each episode the player directs the AI to build or change Forkcast, choosing pieces (a cache here, a queue there, Postgres not a spreadsheet) while the engineers weigh in. Then comes the episode's live moment, a launch, a demo, a traffic spike, where simulated users hit what was built and the consequences play out on screen: pages slow, the cache says a booked table is free, a diner is charged twice.
- **Runway is the score.** Cloud bills, model bills, salaries and mistakes burn the startup's money. Over-engineering burns it as surely as outages do, which teaches the curriculum's "simplest version that works" without saying it.
- **Gus is a trap.** His confident advice is sometimes right, mostly a misconception. The player learns to tell which.
- **Episodes, not levels.** A cold open before the title card, a cliffhanger cut to black at the end, a "previously on" recap when you return. It's pixel art like the other games.
- **The title sequence** is a homage to the show's: a pan across the Bay as startup logos appear, merge and vanish, with Forkcast's appearing, and later Hubbub Dine's, as the season goes on.

## Checks

- **Coverage.** Every curriculum module must map to at least one episode; worth a small test once episodes exist as data, so editing the curriculum flags anything left uncovered.
- **Facts.** Every claim in dialogue must be real (the curriculum's "nothing untrue" rule), with a technical review pass before content is built.
