# Handoff: the fourth game

To pick this up in a new session, say:

> Read `games/mission-silicon/HANDOFF.md` and continue the fourth game from there.

## Where it stands

**A playable prototype of Episodes 8 (*Viral*) and 9 (*The Board Meeting*)**, as its own Godot project here, with its checks passing in CI (see [README.md](README.md)). It's in the web build, playable at `/mission-silicon/play/` with a page at `/mission-silicon/`, but not on the home page's splash yet. The cast close-ups and backdrops are generated pixel art, the music and stings are original glitchy electronic, and the title cards are in Montserrat ExtraBold. Names, look, orientation and the game design are settled. Four docs:

- [CURRICULUM.md](CURRICULUM.md): **what** the game teaches. 14 modules and a capstone, for non-technical people building web apps with AI. The standing reference for topics.
- [SHOW.md](SHOW.md): **how** the homage carries it. Premise, cast, a 14-episode season mapped to modules.
- [GAME.md](GAME.md): **how it plays**. The core loop, the simulation, the episode data, the phone screen, the checks, and Episode 8 (*Viral*) walked through end to end on paper.
- This file: decisions so far, what's open, and what to do next.

Read AGENTS.md first as always; its fourth-game entry summarises the rules below, and its other rules (open a PR for every change, notes go in AGENTS.md, asset generation is pre-approved) apply here too.

## Decided

- **Audience and goal.** Non-technical people, would-be founders above all, who want to build with AI. They learn enough to name the parts, read an AI's plan, ask for the right thing and spot classic mistakes. The player never writes code; that's what makes it distinct from the other three games.
- **The homage.** Silicon Valley (HBO). Same limits as Curb Your Oxidation: copy format, tone and tropes closely; homage names only; no verbatim lines; no recreation of the theme tune; don't name the show in anything players or viewers see. The planning docs here do name it and its characters. Leave out the raunchy bits and the ethnic-stereotype gags.
- **Stay close to the show.** Drifting into generic startup comedy is the main risk. SHOW.md ties every character to a named counterpart (Erlich, Richard, Gilfoyle...) and every episode to a specific borrowed set piece; keep it that way, and check each episode against the show before building it.
- **The title: Mission Silicon.** The show's title turned around, as Curb Your Oxidation twists its show's. The incubator house is a run-down Victorian in the Mission, "mission" is the tech giant's favourite word, and it sounds like a real neighbourhood. Folder `games/mission-silicon/`, site page `/mission-silicon/`, game at `/mission-silicon/play/`. A web search found nothing else by that name (not a trademark check).
- **The premise.** You're a non-technical founder who moves into an incubator house to launch an AI startup, **Forkcast**, an AI dinner concierge that finds and books restaurant tables. Forkcast is also the curriculum's running example; its stages are the season's arc.
- **The cast.** Winking names, like Curb's (Larry David, Barry Danvers): a similar sound or the same initials, never the real name. Full table in SHOW.md.

  | The show | Mission Silicon |
  | --- | --- |
  | Erlich Bachman, incubator owner | Ulrich Bachner |
  | Richard Hendricks, the founder | Ricky Henley, your reluctant CTO |
  | Bertram Gilfoyle, sysadmin | Gilroy (surname only, like the show; also a Bay Area town) |
  | Dinesh Chugtai, rival coder | Danesh Chaudhry |
  | Jared Dunn, operations | Gerard Dunlop |
  | Nelson "Big Head" Bighetti | Wilson "Melon" Mellini |
  | Gavin Belson of Hooli | Galen Brightwater of Hubbub |
  | Russ Hanneman, loud investor | Chaz Haverman |
  | Peter Gregory of Raviga, quiet investor | Walter Gregorian of Ravello Capital |
  | Monica Hall, the associate | Veronica Hale |
  | Jack Barker, the adult CEO | Mack Barlow |
  | Anton and Son of Anton | Aleister, the garage server, and Aleister Jr., the AI teammate (Anton was named after an occultist; so is Aleister) |
  | Pied Piper | Forkcast |

- **The AI teammate.** The character the player directs is Aleister Jr., an eager, overconfident AI coding assistant. The finale is the player telling it no.
- **The look: startup green.** An off-white and slate UI with one bright green accent, `#2BB673`, in the vein of the show's startup-logo green. Title cards in Montserrat ExtraBold (OFL, close to the show's geometric sans; put the font files in the game's `assets/fonts/` like Curb's Libre Franklin). Music: original glitchy electronic, bitcrushed synths and a drum machine, never the show's theme. Pixel art like the other games.
- **Landscape**, like the other three games. Phone players are likely (they arrive from social posts), so keep the web build lean, keep text and tap targets big enough for a phone held sideways, and show a "turn your phone sideways" card when it's held upright.
- **The curriculum leads.** It can change for teaching reasons; the show follows it, and every module must stay covered by at least one episode.
- **Engine: Godot 4.7**, its own project in `games/mission-silicon/`, like the others, to reuse the web export, CI, bot tests and art and trailer tools.
- **Notebooks are marimo; React gets its own section.** Both already in the curriculum.
- **The core loop** (details in GAME.md): Aleister Jr. answers each episode's problem with a pull request; the player keeps or cuts each change, asks it the curriculum's "What to tell your AI" questions and sets a few dials, never wiring or writing code; then merges, and a live moment runs simulated diners through what was built. Nothing is marked right or wrong when chosen; only the live moment and Gerard's postmortem judge. Nothing is timed. A failed live moment is a scene, then take two.
- **Runway is the score; time is the plan's budget.** Each episode starts from its own bank and board (no carry-over). Three marks: Live (goal held), Lean (runway at par), Ulrich (his card judged right; he's right about a third of the time).
- **The simulation is a deterministic flow model**, so tests can enumerate every plan. Its numbers are illustrative; its shapes (queueing, cache hit rate and staleness, connection limits, retries without idempotency keys) are real.
- **Each episode's data proves its own lesson**: the solution passes, Aleister's PR as proposed fails, every lesson-bearing decision changes the result, and no plan passes much cheaper than the solution.

## Open

Everything still marked *(candidate)* in SHOW.md, the open list at the end of GAME.md, plus:

- **The title sequence's company list.** SHOW.md plans a San Francisco flyover parodying the show's intro with today's AI companies under their real names (decided: real names, companies only, as pixel-art signs drawn for the game, never people's names). The final list is open.
- **Where it sits on the home page splash** (Curb leads it; this joins Dunder Quest and Flatmates.js as a card once it's playable).

## Next steps

In order, each as its own PR:

1. ~~**Write the game design doc**~~: done, [GAME.md](GAME.md).
2. ~~**Prototype Episode 8**~~: done. The simulation, the data, one scene script, and the checks (`tests/cases.gd`, `coverage.gd`, `smoke.tscn`, `bot.tscn`, all run by `tests/check.sh`). Tuning it against `cases.gd` changed a few numbers in GAME.md's walk-through (two small servers plus a one-server hotfix; par 14.9), and GAME.md now has the results table.
3. ~~**Wire it into the build**~~: done. `export_presets.cfg`, a block in `scripts/export_web.sh`, `tests/check.sh` in CI, and a page at `/mission-silicon/` (`build_mission_silicon` in `site/build.py`, styled by `site/static/mission-silicon.css`), whose screenshots and social card `tools/site_art.tscn` paints from the bot's shots. Rerun it when the look changes.
4. ~~**Real assets**~~: done. Montserrat ExtraBold, the cast's close-ups and the backdrops (`tools/art.py`), and the music and stings (`tools/music.py`, played by `core/sound.gd`); see the README. Played through to a postmortem in a browser at a phone held sideways (812×375). That turned up three older bugs, now fixed: full-screen controls were zero-sized, so taps didn't move the dialogue on; Pixelify Sans's "fi" ligature drew as an "A"; and the title's subtitle sat off centre. The web pack went from 153 KB to 1.9 MB, mostly music. New episodes will need their own backdrops: add a prompt to `SCENES` in `tools/art.py`.
5. ~~**Technical review of the content**~~: done for Episode 8, logged claim by claim in [REVIEW.md](REVIEW.md). No simulation number changed; the text fixes were the queue (it deferred password hashing, which would put plain-text passwords in a queue; now it's the welcome emails), the CDN (photos and scripts, not pages), the hotfix's price (now worked out from the chosen server size), the codex cards' absolutes, and a few finding lines that weren't true in every plan. Each new episode gets the same pass before it merges: add its rows to REVIEW.md, and give each lesson card a `source` that supports every part of it.
6. **The next episodes**, one PR each: walk it on paper in GAME.md like Episodes 8 and 9 (the season sketch is there), add any simulation behaviours to `sim/sim.gd`, add it to `data/season.json`, make `tests/cases.gd` prove it (and the bot play it), add its rows to REVIEW.md, and generate any new faces or backdrops with `tools/art.py`.
   - ~~**Episode 9, *The Board Meeting***~~: done. Dashboards on the live database against a data warehouse (Module 6's OLAP side), and Module 8's on-premises box and monitoring. Ulrich is right for the first time (the analytics database: "you don't do the accounts at the front desk"); Mack Barlow's box is the too-big card; the asks add error alerts, and only with alerts does Aleister offer the hotfix when the 8pm copy job breaks. New behaviours: dashboard load on the primary, a replica or a column-store warehouse; booking latency (a booking waits the database's full latency); pipeline freshness and a scripted failure. New faces Mack and Walter, a boardroom backdrop. `cases.gd` also checks continuity now (each board starts where the last solution ended), and `CASES_EP=9` runs one episode's checks. The title screen lists every built episode. Solution 12.856 months, par 12.85.
   - **Next: Episode 10, *Hubbub Dine*** (Modules 9 and 10). Hubbub clones Forkcast with microservices and hundreds of engineers (the show's Nucleus) and its demo collapses beside yours; Hubbub's scraper hammers Forkcast, so the trap is no rate limit on our own API. It needs Galen Brightwater's face, a Hubbub campus or keynote-stage backdrop, and new behaviours: a rate limit on our endpoints (a scraper kind of request), and a chain of service calls where each hop adds latency and a failure in one fails the request (the distributed-systems half). Mack's leak in Episode 9's cliffhanger sets it up.
   - Still to build after that: retries and idempotency keys, races on the last table (11), leaked keys and a hallucinated package (12), the agent and prompt injection (13), the finale (14), and Episodes 1 to 7.

## Useful references in the repo

- `games/curb/README.md`: the closest model for a homage game's structure (season as data, one scene script, checks).
- `games/curb/tests/` and `games/flatmates/tests/`: bot, smoke, shots and trailer-run scenes to copy.
- `games/dunder-quest/tools/`: the art, music and SFX generators the other games reuse.
- `site/build.py`: the site, including game pages and the brand kit.
