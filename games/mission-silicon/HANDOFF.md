# Handoff: the fourth game

To pick this up in a new session, say:

> Read `games/mission-silicon/HANDOFF.md` and continue the fourth game from there.

## Where it stands

Planning only. No game code, no Godot project, no site page yet. Names, look and orientation are settled. Three docs:

- [CURRICULUM.md](CURRICULUM.md): **what** the game teaches. 14 modules and a capstone, for non-technical people building web apps with AI. The standing reference for topics.
- [SHOW.md](SHOW.md): **how** the homage carries it. Premise, cast, a 14-episode season mapped to modules, and a first format sketch.
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

## Open

Everything still marked *(candidate)* in SHOW.md, plus:

- **The title sequence's company list.** SHOW.md plans a San Francisco flyover parodying the show's intro with today's AI companies under their real names (decided: real names, companies only, as pixel-art signs drawn for the game, never people's names). The final list is open.
- **The core loop in detail.** SHOW.md's sketch is "plan with the AI, then a live demo where simulated traffic hits what you built; runway is the score". Undecided: how the player picks and connects pieces, how much the simulation shows, how failure plays out, how Ulrich's bad advice is presented, what a perfect episode looks like, and how the planning board lays out on a landscape phone screen.
- **Where it sits on the home page splash** (Curb leads it; this joins Dunder Quest and Flatmates.js as a card once it's playable).

## Next steps

In order, each as its own PR:

1. **Write the game design doc** (`GAME.md` here): the core loop, the simulation model (requests, servers, caches, queues, databases, failures, runway), the episode data format, the UI on a landscape phone screen, and how each episode's lesson is checked. Walk one episode end to end on paper, probably 8 (*Viral*, Modules 7 and 9), since it exercises the simulation hardest.
2. **Prototype that one episode** in a new Godot project, following Curb's layout: `data/` for the season as data, one scene script that builds every episode from it, `tests/bot.tscn` that plays it through, `tests/smoke.tscn`. Add a coverage test that fails if any curriculum module has no episode.
3. **Wire it into the build**: `scripts/export_web.sh`, CI, and a page at `/mission-silicon/` in `site/build.py`, once the prototype is worth showing on dev.dunderquest.com.
4. **Technical review of the content**: every claim real, per the curriculum's "nothing untrue" rule.

## Useful references in the repo

- `games/curb/README.md`: the closest model for a homage game's structure (season as data, one scene script, checks).
- `games/curb/tests/` and `games/flatmates/tests/`: bot, smoke, shots and trailer-run scenes to copy.
- `games/dunder-quest/tools/`: the art, music and SFX generators the other games reuse.
- `site/build.py`: the site, including game pages and the brand kit.
