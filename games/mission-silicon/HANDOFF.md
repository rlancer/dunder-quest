# Handoff: the fourth game

To pick this up in a new session, say:

> Read `games/mission-silicon/HANDOFF.md` and continue the fourth game from there.

## Where it stands

**A playable prototype of Episode 8 (*Viral*)**, as its own Godot project here, with its checks passing (see [README.md](README.md)). It isn't in the web build or on the site yet. Art is placeholder (cast close-ups and backdrops drawn in code; no music or SFX), and the title cards use Libre Franklin ExtraBold until Montserrat's files are added to `assets/fonts/`. Names, look, orientation and the game design are settled. Four docs:

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
3. **Wire it into the build**: an `export_presets.cfg` (copy Curb's, exporting to `build/site/mission-silicon/play/`), `scripts/export_web.sh`, `tests/check.sh` in CI, and a page at `/mission-silicon/` in `site/build.py`, so it can be played on dev.dunderquest.com.
4. **Real assets**: Montserrat ExtraBold in `assets/fonts/`, the cast painted and the backdrops generated like Curb's (`tools/`), and the glitchy electronic music and stings. Then play it on a phone held sideways.
5. **Technical review of the content**: every claim real, per the curriculum's "nothing untrue" rule. The lesson cards carry a `source` each.
6. **The next episodes**: walk each on paper in GAME.md like Episode 8 (the season sketch is there), then add it to `data/season.json`. The simulation's behaviours table lists what later episodes will need that isn't built yet (retries, races, analytics on the live database, leaked keys, authorization, the agent).

## Useful references in the repo

- `games/curb/README.md`: the closest model for a homage game's structure (season as data, one scene script, checks).
- `games/curb/tests/` and `games/flatmates/tests/`: bot, smoke, shots and trailer-run scenes to copy.
- `games/dunder-quest/tools/`: the art, music and SFX generators the other games reuse.
- `site/build.py`: the site, including game pages and the brand kit.
