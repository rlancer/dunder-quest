# Working in this repo

## Always open a PR

Finish every change by opening a pull request, without being asked: branch off `main`, commit, push, and `gh pr create`. CI deploys every PR to dev.dunderquest.com, which is where changes get reviewed, so a change that's only committed locally can't be seen yet. Never push straight to `main`: it deploys to production.

End with the PR link and a reminder that the preview will be on dev.dunderquest.com once CI finishes.

## Notes go here, not in hidden memory

Anything worth remembering between sessions (decisions, preferences, context) goes in this file, in a PR like any other change, so it can be seen and edited. Don't save it to an agent's private memory store.

## Layout

See [README.md](README.md). The site is built by `site/build.py`. Each game has its own art and trailer tools under `games/<game>/tools/`, run from that game's folder.

## Decisions

- **Generating assets is pre-approved.** Generate art, music and SFX with the `tools/generate_*.py` scripts (OpenRouter key in `.env`), or new scripts like them, without asking first. Generated beats placeholder. Keep trailer and marketing assets out of a game's `assets/`, so the web build stays small.
- **Dunder Quest is a Holy Grail homage.** Python is named after Monty Python. Use winking homage names (the Knight Who Says Mi, Tom the Enchanter, the Bridge of Peril), never the films' real character names, and don't quote at length in visible UI, to stay clear of Python (Monty) Pictures' IP. Hidden eggs (`common/eggs.gd`, listed at /admin/eggs) may quote short lines.
- **Flatmates.js is the second game** (`games/flatmates/`, its own Godot project, page at /flatmates/, game at /flatmates/play/). It teaches JavaScript and is a homage to a Croydon flat-share sitcom. Keep it distinct from Dunder Quest: no quiz duels; the puzzles are scripts that the flatmate you aren't playing runs, and left alone he drifts back to his comfort spot. Use homage names only (Clive, Jazz, Big Ron, Tess from Accounts), never the show's names or lines, and don't name the show in anything public. Its checks are `tests/bot.tscn` and `tests/verify_lessons.mjs`.
- **Curb Your Oxidation is the third game** (`games/curb/`, its own Godot project, page at /curb/, game at /curb/play/). It teaches Rust and is a homage to an LA cringe-comedy series: Rust's borrow checker is the unwritten social contract. Copy the show as closely as possible in everything that is format, tone or trope (the Westside setting, petty etiquette disputes, the improvised-feeling bickering, the hero's squinting stare-downs and suspicious interrogations, black title cards in plain serif, a freeze frame and a bouncy comic-tuba sting at the end of every scene), with exactly three limits: no real people's or characters' names (homage names only: Barry Danvers, Gil and Sharon Greene, Carol, Lamont, Ted Pruitt), no verbatim catchphrases or lines from the show, and no recreation of its theme tune (original music in the same style and instrumentation is fine). Don't name the show in anything public. Keep it distinct from the other two games: no quiz duels and no flatmate running your script; a plan plays in Barry's head first and Sharon interrupts at the line the borrow checker rejects, with the real rustc error code. Never teach anything that isn't real Rust. Its checks are `tests/cases.gd`, `tests/bot.tscn` and `tests/verify_rust.py` (which compiles every plan with rustc; CI runs it).
- **Trailers are YouTube-first.** The 4K master and the YouTube thumbnail are primary. Steam is deferred, so keep the 1080p master Steam-compatible.
- **One YouTube channel for every game:** [@dunderquest](https://www.youtube.com/@dunderquest). Channel art, copy and each video's upload form live on /brand/youtube/ (`build_brand_youtube` in `site/build.py`). Link that channel, not any other.

## Why it's a learning game

Rob is dyslexic and was failing his spelling tests until his dad wrote him a spelling game in BASIC; after that he got 100 on every one. His kids are 5 and 2 (as of October 2026), too young for Python, "but maybe some day". He offered this for launch copy. Use only these facts and don't embellish them (no made-up computer, age or names).
