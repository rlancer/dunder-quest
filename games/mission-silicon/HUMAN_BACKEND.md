# The Human Backend: design note

The fourth attempt at Mission Silicon (November 2026), in [human/](human/), at `/mission-silicon/human/`. The earlier three (the storyboard, the sitcom Pilot in `web/`, the Lab on its own branch) are left in place for comparison.

## What was wrong with the first three

In all of them the real verb is "read, then pick one of three". The systems are diagrams you look at. Playing the Pilot's opening again confirmed it: the art is charming, and for the first minute the only thing a thumb can do is press ›.

## Five concepts, and what's wrong with each

**1. Rush hour (flow builder, in the Mini Metro family).** Requests are dots that pour from phones through pipes; you draw the pipes and drop in servers, caches and queues as the dots back up.
- Every ten seconds: drag a part onto a pipe, watch the jam move.
- Fun: jams clearing is satisfying, and it scales to a real endgame.
- Teaches: bottlenecks, caching, queues, scaling. Not trust, secrets or where data lives, which are about *what a request says*, and a dot says nothing.
- Boring when: the parts are a palette, so it's the same "choose from a list", only spatial; and boxes joined by lines is the diagram again. An architecture tower defence is also the first thing anyone would think of.

**2. Break it (you're the attacker).** The AI ships an app; you're paid per way you break it: edit the price on the phone, change the number in the URL, double-tap Pay.
- Every ten seconds: poke a field, see what gives.
- Fun: vandalism is fun.
- Teaches: trust and security well; nothing about speed, cost or scale.
- Boring when: you run out of ideas for what to poke and it becomes a hint hunt. It's also the Lab turned inside out, and the Lab is the attempt Rob liked least.

**3. Number go up (an idle game).** Forkcast grows from ten users to ten million; each power of ten breaks something, and you spend what you've earned on the fix.
- Every ten seconds: tap, buy, watch a number.
- Fun: idle games hook people who don't play games, and they suit a phone.
- Teaches: the order problems arrive in. But a fix you buy is a fix you didn't understand: "Redis, $400" teaches the word and nothing under it.
- Boring when: always, underneath. The verb is a shop.

**4. On call (a night of pages).** Your phone buzzes at 2am; a live dashboard, a group chat, and a few real levers.
- Every ten seconds: read a chat message, read a graph, pull a lever.
- Fun: tension, and the chat can be very funny.
- Teaches: operations vocabulary, monitoring, incident instincts.
- Boring when: it's reading again, and a dashboard is the least playful object in computing. It also assumes you already know what the levers do.

**5. The Human Backend (you are the server).** The AI built a beautiful app and forgot the part that does anything, and it launches tonight. So tonight *you* are the backend: requests land on your desk as paper slips and you deal with each by hand, dragging it to the thing on your desk that can answer it. The AI watches. After you've handled a kind of slip three times, it says "got it" and does that job from then on, exactly the way you did it, at a hundred times the speed.
- Every ten seconds: drag three or four slips, under a queue that's filling, while deciding between the fast thing and the careful thing.
- Fun: it's a diner-dash game with a twist that's funny every time, which is that your own shortcut comes back automated. You stamped deposits without checking because every slip so far was honest; now a robot is stamping "$0 PAID" forty times a minute and Gerard is looking at the till.
- Teaches: whatever the desk is made of. Sticky notes are memory (fast, gone when Ulrich unplugs you to charge his scooter). Gerard's ledger is the database (slow, permanent, and there's only one of it). The number the phone wrote on the slip is the frontend's word for it. The key on the hook is the API key, and handing it over is instant, right up until strangers are spending your money. The player has had each thing in their hands before it gets its real name.
- Boring when: the automation leaves you with nothing to do, or the slips need reading. So slips are an icon and four words, something new always arrives as the robot takes over the old thing, and stretches of watching are capped at a few seconds of something going spectacularly well or badly.

## Why the fifth

It's the only one where the lesson and the joke are the same event. The curriculum's whole thesis (Module 0) is that an AI builds what you let it, fast, and that you need to know what to ask for and what to check. Here that's the game's one rule: **the robot learns your job by watching you do it.** Nothing is marked right or wrong when you do it. Careless and careful handling both become machinery, and the night decides.

It also dissolves the "diagram" problem. By the last night the screen *is* an architecture diagram (clients, load balancer, servers, cache, database, model), but the player built every box out of something they did by hand, and knows what each is for because they remember being it. And it's a real practice: a startup faking its backend with a person is a "Wizard of Oz" or concierge MVP, which is a good first joke for a company whose product is a concierge.

It keeps the house, the cast and Forkcast, because they earn their place: the housemates become parts of the system (Gerard is the database, Ulrich is the outage, then the load balancer; Danesh is server two).

## The slice

Four nights, about three minutes each. Each night adds one kind of slip; everything from earlier nights keeps running, automated the way the player left it.

| Night | You handle | The fast way | What it costs | Real terms, after |
| --- | --- | --- | --- | --- |
| 1 | Bookings | Sticky notes | Ulrich unplugs you; every note is gone and the diners turn up anyway | memory, restart, database |
| 2 | Deposits, then cancellations | Stamp what the slip says | The phone wrote the slip. $0 deposits spread by group chat; a bot cancels tables #1, #2, #3... | request, frontend, server-side check, authorization |
| 3 | Questions for the AI model | Hand the diner the key | Strangers spend on your key, and changing the rule doesn't change the lock. Then notes of old answers save money until the truth changes | API key, rotate, cache, hit, stale, TTL |
| 4 | "What's free tonight?" at launch | Ask the ledger every time | More desks don't help when the queue is at the one book | load balancer, horizontal scaling, bottleneck, read vs write |

Night four is the exam, without a question in it: every rule the player taught on nights one to three runs at launch traffic. Whatever they left careless is now careless at scale.

The game ends by turning the robot's rules into **the brief**: the handful of sentences the player would now put at the top of a request to a real AI ("Bookings are saved in the database, never only in memory", "The server works out every price"...), each one earned by a night, with a copy button.

## What every behaviour is in a real system

- A restart empties memory and leaves the database alone. Servers restart on every deploy.
- A request is written by the client, so any field in it can be a lie; the server recomputes prices and checks ownership from its own records.
- Careful checks that are slow by hand are nearly free for a computer, so there's no speed argument for trusting the client.
- A key shipped to the client is public. Removing it from the next build doesn't revoke it; rotating does, and re-shipping the new one leaks it again.
- Model calls are the slow, metered part; repeated questions can be answered from a cache; a cached answer is stale once the world changes, until it's invalidated or its TTL runs out; losing a cache loses nothing.
- Adding servers raises throughput until the shared database is the bottleneck; reads can be served from copies, and the write still checks the truth, so a stale "free" list costs a "sorry, just went" and never a double booking.
- With more than one server, one can be unplugged and nobody notices.

The numbers (a dollar a question, the seconds each thing takes) are stage numbers. The shapes are real.

## What's not in it

Queues and background jobs, sessions across servers (stateless), deploys and Git, languages. Each has an obvious night (the confirmation email that makes everyone wait; the diner whose second message lands on Danesh's desk), and none is built.
