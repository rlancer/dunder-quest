# Flatmates.js

A Dunder Quest game that teaches JavaScript. Two mismatched flatmates share Flat 5B in Croydon: Clive, an uptight credit-office worker who can't jump much, and Jazz, a would-be rock god who jumps high and does little else. Tab swaps whose head you're in, and each one's inner voice runs along the top of the screen.

Left to himself, the flatmate you aren't playing drifts back to his comfort zone (Jazz to a sofa, Clive to an armchair). The only way to keep him somewhere useful is to write his script. Laptops around each stage open his to-do list as real JavaScript with blanks to fill. Run it, and he does it while you play the other one.

It's an homage to a certain Croydon flat-share sitcom. Names and jokes are winks, not the show's own characters or lines.

Played at **dunderquest.com/flatmates/**. It's its own Godot 4.7 project; the Python game one folder up ignores this folder.

## The stops

| # | Stage | JavaScript | The puzzle |
|---|---|---|---|
| 1 | Flat 5B | Calling methods | `jazz.walk(7)` onto the doormat; walk, jump, walk over the hole in the hall |
| 2 | Croydon Credit | Variables & strings | `` `${desk}${ext}` `` for the keypad; `lift.goTo(2)`, not `"2"` |
| 3 | Band Practice | Loops | four strums lift the speakers (`i < 4`, not `<=`); `for...of` over every amp |
| 4 | The Stag Do | Events & callbacks | `bell.addEventListener("ring", ...)` moves Jazz to the second gate's plate |
| 5 | East Croydon | Timers & the event loop | `setTimeout` presses the barrier button on time; `setTimeout(..., 0)` logs last |
| 6 | The Wedding | async & await | `await clive.reach(altar)` before the march; `await Promise.all` before the car goes |

## How it's built

- `script/`: a small JavaScript runtime. A `JsProgram` is statements kept as data, with blanks; it renders as the code the laptop shows (and as plain JS for Node), and `JsRunner` runs it with JavaScript's ordering: the script's own lines first, then timers, listeners and `await`s. A flatmate's methods add steps to his to-do list and return promises.
- `actors/flatmate.gd`: the platformer controller (coyote time, jump buffer, apex hang, as in the Python game) and the to-do list.
- `props/`: plates, doors, lifts, switches, keypad, amps, laptops, the way out.
- `stages/stage.gd`: swapping heads, drifting home, falls and Wi-Fi-router checkpoints, inner-voice cards, results. `stage_1.gd` to `stage_6.gd` lay out each stop.
- `data/lessons.json`: the inner-voice lesson cards.
- Art: `tools/paint.py` paints the flatmates, tiles and strum by hand; `tools/scenery.py` and `tools/music.py` generate the backdrops, title art and music through the Python game's generators (`../tools/`). `tools/og.py` makes the share card.

## Checks

```sh
godot --headless --path . --import
godot --headless --path . res://tests/smoke.tscn   # every scene loads
godot --headless --path . res://tests/bot.tscn     # BOT result=ok: plays all six, wrong answers first
node tests/check_sources.mjs                       # the bot's solved scripts parse as JS
node tests/verify_lessons.mjs                      # LESSONS result=ok: every card prints what it says
godot --path . res://tests/shots.tscn              # screenshots into tests/shots/ (needs a window)
```

## Export

`scripts/export_web.sh` (CI) exports the Web preset to `build/site/flatmates/`, tags the page for link previews (`site/build.py --flatmates`) and gzips the engine to fit Cloudflare's file limit.
