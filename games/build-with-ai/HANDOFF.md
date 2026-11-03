# Handoff: the fourth game

To pick this up in a new session, say:

> Read `games/build-with-ai/HANDOFF.md` and continue the fourth game from there.

## Where it stands

Planning only. No game code, no Godot project, no site page yet. Three docs:

- [CURRICULUM.md](CURRICULUM.md): **what** the game teaches. 14 modules and a capstone, for non-technical people building web apps with AI. The standing reference for topics.
- [SHOW.md](SHOW.md): **how** the homage carries it. Premise, cast, a 14-episode season mapped to modules, and a first format sketch.
- This file: decisions so far, what's open, and what to do next.

Read AGENTS.md first as always; its fourth-game entry summarises the rules below, and its other rules (open a PR for every change, notes go in AGENTS.md, asset generation is pre-approved) apply here too.

## Decided

- **Audience and goal.** Non-technical people, would-be founders above all, who want to build with AI. They learn enough to name the parts, read an AI's plan, ask for the right thing and spot classic mistakes. The player never writes code; that's what makes it distinct from the other three games.
- **The homage.** Silicon Valley (HBO). Same limits as Curb Your Oxidation: copy format, tone and tropes closely; homage names only; no verbatim lines; no recreation of the theme tune; don't name the show in anything players or viewers see. The planning docs here do name it and its characters. Leave out the raunchy bits and the ethnic-stereotype gags.
- **Stay close to the show.** Drifting into generic startup comedy is the main risk. SHOW.md ties every character to a named counterpart (Erlich, Richard, Gilfoyle...) and every episode to a specific borrowed set piece; keep it that way, and check each episode against the show before building it.
- **The premise.** You're a non-technical founder who moves into an incubator house to launch an AI startup, Forkcast, an AI dinner concierge that finds and books restaurant tables. Forkcast is also the curriculum's running example; its stages are the season's arc.
- **The AI teammate.** The character the player directs is an eager, overconfident AI coding assistant. The finale is the player telling it no.
- **The curriculum leads.** It can change for teaching reasons; the show follows it, and every module must stay covered by at least one episode.
- **Engine: Godot 4.7**, its own project in `games/build-with-ai/`, like the others, to reuse the web export, CI, bot tests and art and trailer tools. This audience often arrives on a phone from a social post, so keep the web build lean and design for portrait from the start. If phone-first ever becomes the top priority, revisit a web build before game code is written.
- **Notebooks are marimo; React gets its own section.** Both already in the curriculum.

## Open

Everything marked *(candidate)* in SHOW.md, plus:

- **Names.** The game (working title *The Bay Area*), the product (*Forkcast*), the folder (`build-with-ai` is a placeholder; rename it once the game has a name, and update AGENTS.md and these docs), and the cast (Gus, Hank, Thorne, Dev, Jordan, Bix, Galen Brightwater of Hubbub, and the unnamed investors, associate and adult CEO, plus the AI teammate and the garage server it's named after). Check each against the homage rules: winking, never the show's real names.
- **Look and sound.** Palette, accent colour, title-card font (OFL, like Curb's Libre Franklin), and the music direction (original, in the show's glitchy electronic vein).
- **The core loop in detail.** SHOW.md's sketch is "plan with the AI, then a live demo where simulated traffic hits what you built; runway is the score". Undecided: how the player picks and connects pieces, how much the simulation shows, how failure plays out, how Gus's bad advice is presented, what a perfect episode looks like.
- **Portrait or landscape**, and how the planning board fits a phone.
- **Site page and URL** (the others are `/flatmates/` and `/curb/`), and where it sits on the home page splash (Curb leads it).

## Next steps

In order, each as its own PR:

1. **Settle the names and the look** with Rob (the open list above). Cheap to decide now, expensive to change later.
2. **Write the game design doc** (`GAME.md` here): the core loop, the simulation model (requests, servers, caches, queues, databases, failures, runway), the episode data format, the UI on a phone screen, and how each episode's lesson is checked. Walk one episode end to end on paper, probably 8 (*Viral*, Modules 7 and 9), since it exercises the simulation hardest.
3. **Prototype that one episode** in a new Godot project, following Curb's layout: `data/` for the season as data, one scene script that builds every episode from it, `tests/bot.tscn` that plays it through, `tests/smoke.tscn`. Add a coverage test that fails if any curriculum module has no episode.
4. **Wire it into the build**: `scripts/export_web.sh`, CI, and a page in `site/build.py`, once the prototype is worth showing on dev.dunderquest.com.
5. **Technical review of the content**: every claim real, per the curriculum's "nothing untrue" rule.

## Useful references in the repo

- `games/curb/README.md`: the closest model for a homage game's structure (season as data, one scene script, checks).
- `games/curb/tests/` and `games/flatmates/tests/`: bot, smoke, shots and trailer-run scenes to copy.
- `games/dunder-quest/tools/`: the art, music and SFX generators the other games reuse.
- `site/build.py`: the site, including game pages and the brand kit.
