# Mission Silicon

The fourth Dunder Quest game, being built. It teaches non-technical founders enough about how web apps are built to direct an AI that builds them. The design is in [GAME.md](GAME.md), the curriculum in [CURRICULUM.md](CURRICULUM.md), the homage in [SHOW.md](SHOW.md), and where it stands in [HANDOFF.md](HANDOFF.md).

**This is the prototype: Episode 8, *Viral*, playable end to end.** Aleister Jr. answers a celebrity chef's post with a pull request; you keep or cut its changes, ask it questions, set the dials, and merge. Then Friday night runs: diners pour through what you built, the garage server overheats (or doesn't), and Gerard's postmortem says what went wrong, in the real terms. Fail, and it's take two from the same board.

It's its own Godot 4.7 project, beside `../curb/` and the others. `scripts/export_web.sh` exports it to `/mission-silicon/play/`, beside its page at `/mission-silicon/` (`build_mission_silicon` in `site/build.py`), and CI runs `tests/check.sh` on every push. It isn't on the home page's splash yet.

## How it's built

- `data/pieces.json`: the catalogue of pieces (app servers, the garage server, Postgres, Redis, CDN, queue, model API...) with their capacities, work per kind of request, latencies and costs. Illustrative numbers; the shapes are real.
- `data/season.json`: the season outline (every episode and its curriculum modules) and the built episodes: cast, cold open, brief, budget, starting board, the pull request's cards, the asks, the dials, the live moment (traffic, events, the hotfix, the cast's reactions), the goal, the solution, the postmortem findings, the codex cards and the cliffhanger.
- `sim/plan.gd`: what the player decided (cards kept, questions asked, dials, hotfix answers), turned into the board the simulation runs.
- `sim/sim.gd`: the live moment as a deterministic flow model. Each tick is a simulated minute: queueing below capacity and a backlog above it, the garage server overheating, cache hit rates (x / (1 + x), x = rate × TTL / keys) and staleness, shared caches leaking per-user data, logouts from servers that aren't stateless, Postgres's connection limit, the model provider's rate limit, the bill.
- `scenes/episode.gd`: one script builds any episode from the data. `ui/board.gd` draws the whiteboard and the live traffic, `ui/pr_panel.gd` the pull request, card detail and dials, `ui/dialogue.gd` and `ui/card.gd` the dialogue, title cards, codex and cut to black, `ui/sideways.gd` the "turn your phone sideways" card.
- Laid out at 480×270 like Curb, taps only, every button at least 30×30 and no text under 9 pixels (about 44 and 13 points on a phone held sideways).
- Placeholder art: the cast's close-ups and the backdrops are drawn in code (`ui/portrait.gd`, `ui/backdrop.gd`) until they're generated like the other games'. The title cards are Montserrat ExtraBold (`assets/fonts/Montserrat.ttf`, OFL), trimmed to Latin characters with fonttools' `pyftsubset` to 31 KB; trim any new copy the same way.

## Checks

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/coverage.gd   # COVERAGE result=ok: every curriculum module has an episode
godot --headless --path . --script res://tests/cases.gd      # CASES result=ok: each episode's data proves its lesson
godot --headless --path . res://tests/smoke.tscn             # SMOKE result=ok: everything loads
godot --headless --path . res://tests/bot.tscn               # BOT result=ok: plays every episode through the UI, take one and take two
godot --path . res://tests/bot.tscn -- shots                 # the same, with screenshots into tests/shots/ (needs a window)
bash tests/check.sh                                          # all of it
godot --path . res://tools/site_art.tscn                     # after the shots: the page's screenshots and social card, into site/static/img/
```

`cases.gd` runs the simulation headless for every episode: the solution passes and makes par; Aleister's pull request as proposed fails, and so does doing nothing; flipping any one decision fails the night, costs runway or is marked `free`, and every failure's top finding has a postmortem entry; Ulrich's card matters; and a seeded search (every card combination, every pair of dial changes, 3,000 random plans) finds nothing that passes with more runway than the solution. The bot checks the nights it plays on screen match the headless runs exactly.
